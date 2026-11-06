{ Combat AI: movement, equipment, spell selection, morale and automatic actions. }

{$O+,F+}
unit CombatAi;

interface

uses Types, C_Item, C_Npc, C_Terr, C_Cond, GDConsts, GDVars, Crt, MenuCore, CbtActs, ViewChar, FxEngine, C_Effect,
  C_Equip, C_Class, C_Status, C_Gbvm, C_Dir, C_Spell, C_Keys, CharHlp, Magic, Pathing, CbtMap, TextRend, GameIo;

{ Runs one AI-controlled turn: checks the keyboard (space returns the party to manual control), rerolls the approach
  pattern, checks morale, then tries in order an item's spell, a spell readied earlier, turning undead and a new spell,
  and otherwise re-equips and runs the move-and-attack loop. The pattern is rerolled when unset, after a sweep pattern
  or on 1 turn in 4: 1 in 8 picks a sweep pattern (5 or 6), else 1 to 4.
  @param(creature The creature.) }
procedure CombatAiControl(creature: Types.PCharRecord);

implementation

function TurnUndeadAi(creature: Types.PCharRecord): Boolean; forward;

function DecideCastSpell(creature: Types.PCharRecord; spell, minPri: Byte): Boolean; forward;

function SelectItemToUse(creature: Types.PCharRecord): Boolean; forward;

function SelectSpellToCast(creature: Types.PCharRecord): Boolean; forward;

function AiCanStep(creature: Types.PCharRecord; attempt, baseDir: Byte; var edge: Boolean): Boolean; forward;

procedure AiMoveStep(creature: Types.PCharRecord); forward;

function AiMoveAttack(creature: Types.PCharRecord): Boolean; forward;

function FinishRound(creature: Types.PCharRecord): Boolean; forward;

function CheckKeystroke(creature: Types.PCharRecord): Boolean; forward;

function CheckMorale(creature: Types.PCharRecord): Boolean; forward;

function CalcWeaponPriority(creature: Types.PCharRecord; item: Types.PItemRec): Byte; forward;

procedure EquipWeaponAndArmor(creature: Types.PCharRecord); forward;

procedure CombatAiControl(creature: Types.PCharRecord);
var
  stance: Byte;
  done: Boolean;
begin
  done := CombatAi.CheckKeystroke(creature);
  MenuCore.ClearBottomLine;
  CharHlp.ClearMessageWindow;
  if creature^.enabled = 0 then
    done := CharHlp.EndActions(creature);
  stance := creature^.combatAddr^.aiStance;
  { Reroll when unset, after a sweep pattern or on 1 turn in 4; a 1d8 roll of 8 picks sweep pattern 5..6, else 1..4 }
  if (stance = 0) or (stance > 4) or (FxEngine.RollDice(1, 4) = 1) then begin
    stance := FxEngine.RollDice(1, 8);
    if stance = 8 then
      stance := FxEngine.RollDice(1, 2) + 4
    else
      stance := FxEngine.RollDice(1, 4);
  end;
  creature^.combatAddr^.aiStance := stance;
  if not done then
    done := CombatAi.CheckMorale(creature);
  if (creature^.combatAddr^.fleeing <> 0) and (creature^.combatAddr^.turned = 0) then
    CharHlp.PrintCreatureMessage(creature, 'flees in panic', 10, True);
  if done then
    Exit;
  if CombatAi.SelectItemToUse(creature) then
    done := CharHlp.EndActions(creature)
  else if creature^.combatAddr^.spellCast > 0 then begin
    { A spell readied earlier resolves this segment. Combat's manual path zeroes spellCast before casting; here
      CharHlp.EndActions below does it }
    Magic.CastSpell(creature^.combatAddr^.spellCast, True, True, done);
    done := CharHlp.EndActions(creature);
  end else if CombatAi.TurnUndeadAi(creature) then
    done := CharHlp.EndActions(creature)
  else if CombatAi.SelectSpellToCast(creature) then
    done := True
  else begin
    CombatAi.EquipWeaponAndArmor(creature);
    done := CombatAi.CheckKeystroke(creature);
    while not done do
      if CbtActs.AcquireTarget(creature, 255, 1, 0)
         and (creature^.combatAddr^.initiative > 0) then
        done := CombatAi.AiMoveAttack(creature)
      else
        done := CombatAi.FinishRound(creature);
  end;
end;

{ Turns undead when the creature is a cleric that has not tried this battle and a turnable undead target exists.
  @param(creature The creature.)
  @returns(True when it turned undead.) }
function TurnUndeadAi(creature: Types.PCharRecord): Boolean;
var
  tgt: Pointer;
begin
  if (creature^.combatAddr^.usedTurnUndead = 0)
     and (creature^.classLevels[C_Class.CLERIC_LEVEL] > 0)
     and CbtActs.FindTurnUndeadTarget(creature, tgt) then begin
    TurnUndeadAi := True;
    CbtActs.CombatTurnUndead(creature);
  end else
    TurnUndeadAi := False;
end;

{ Decides whether the AI should use a spell, memorized or an item's. Its AI priority must reach minPri. A spell that is
  not offensive, other than Cure Light Wounds, always qualifies, as does Cure Light Wounds with someone to cure.
  Anything else needs an enemy within the spell's range and, for an area spell, no candidate aim point whose area takes
  in someone who is not an enemy.
  @param(creature The caster.)
  @param(spell The spell.)
  @param(minPri The lowest AI priority accepted.)
  @returns(True when the spell should be used.) }
function DecideCastSpell(creature: Types.PCharRecord; spell, minPri: Byte): Boolean;
var
  tgt: Pointer;
  cnt: Byte;
  j: Byte;

  { Tells whether an area spell aimed at a cell would take in someone not on the current character's enemy team. }
  function AreaHitsNonEnemy(x, y: ShortInt; spell: Byte): Boolean;
  var
    i: Byte;
  begin
    AreaHitsNonEnemy := False;
    Pathing.BuildTargetList(x, y, GDConsts.spellTable[spell].aiRadius, 255, 1, GDVars.arenaPtr);
    for i := 1 to GDVars.targetCount do
      if GDVars.creatureArr[GDVars.targetList[i].idx]^.hostile
         <> CharHlp.EnemyTeam(GDVars.curChar) then
        AreaHitsNonEnemy := True;
  end;

begin
  DecideCastSpell := False;
  if GDConsts.spellTable[spell].aiPriority < minPri then
    Exit;
  if ((spell <> C_Spell.CURE_LIGHT_WOUNDS) and (GDConsts.spellTable[spell].offensive = 0))
     or ((spell = C_Spell.CURE_LIGHT_WOUNDS) and CbtActs.FindCureTarget(creature, tgt)) then
    { buff or heal: no aiming }
    DecideCastSpell := True
  else begin
    cnt := CharHlp.CountTargets(creature, Magic.CalcSpellRange(spell));
    if cnt > 0 then
      if GDConsts.spellTable[spell].aiRadius = 0 then
        DecideCastSpell := True
      else begin
        { Reject the spell if any candidate aim point would also catch a non-enemy }
        for j := 1 to cnt do
          if AreaHitsNonEnemy(GDVars.arenaLoc[GDVars.potentialTargets[j]].x,
                              GDVars.arenaLoc[GDVars.potentialTargets[j]].y, spell) then
            Exit;
        DecideCastSpell := True;
      end;
  end;
end;

{ Uses an equipped item's spell when the creature may use items, an enemy team remains and there is no antimagic. Over
  1d7 passes the lowest AI priority accepted falls from 7, and the first equipped item that is not readable, has a
  special below $80 and a spell DecideCastSpell accepts is used. Item effects above 56 map to the spell entries 23
  lower.
  @param(creature The creature.)
  @returns(True when an item was used.) }
function SelectItemToUse(creature: Types.PCharRecord): Boolean;
var
  lowPri: Byte;
  roll: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Integer;
  { Unused in this version; see the other implementations of this routine. }
  slot: Byte;
  effect: Byte;
  { Unused in this version; see the other implementations of this routine. }
  baseItem: Pointer;
  item: Types.PItemRec;
  chosen: Types.PItemRec;
  used: Boolean;
begin
  SelectItemToUse := False;
  chosen := nil;
  lowPri := 7;
  roll := FxEngine.RollDice(1, 7);
  if (creature^.combatAddr^.itemUseAllowed <> 0)
     and (GDVars.teamCount[CharHlp.EnemyTeam(creature)] > 0)
     and (GDVars.zone0^.antimagic = 0) then
    for i := 1 to roll do begin
      item := creature^.itemsAddr;
      while (item <> nil) and (chosen = nil) do begin
        effect := item^.effect;
        slot := GDVars.baseItems[item^.itemType].slot;
        if (not Magic.ItemReadable(item))
           and (item^.special < $80)
           and (item^.equipped <> 0)
           and (effect > 0) then begin
          { Item effects 80..90 map to spell entries 57..67; 56 is the last real spell id }
          if effect > 56 then
            effect := effect - 23;
          if CombatAi.DecideCastSpell(creature, effect, lowPri) then
            chosen := item;
        end;
        item := item^.next;
      end;
      Dec(lowPri);
    end;
  if chosen <> nil then begin
    ViewChar.UseItem(chosen, used);
    SelectItemToUse := True;
  end;
end;

{ Chooses and casts a spell for an NPC, or for a party member while quick magic is on, when an enemy team remains and
  the creature may cast. The choice is among its memorized spells, those still being memorized included. Over 1d7 passes
  the lowest AI priority accepted falls from 7, with three random picks a pass; the first spell DecideCastSpell accepts
  is cast.
  @param(creature The creature.)
  @returns(The casting's result: True when the creature's actions are over.) }
function SelectSpellToCast(creature: Types.PCharRecord): Boolean;
var
  list: array[0..20] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellRec: Pointer;
  lowPri: Byte;
  roll: Byte;
  ext: Boolean;
  tries: Byte;
  inner: Byte;
  count: Byte;
  k: Byte;
  spell: Byte;
  chosen: Byte;
begin
  count := 0;
  if creature^.combatAddr^.castAllowed <> 0 then
    for k := 0 to SizeOf(creature^.memorizedSpells) div SizeOf(creature^.memorizedSpells[0]) - 1 do
      if creature^.memorizedSpells[k] > 0 then begin
        list[count] := creature^.memorizedSpells[k];
        Inc(count);
      end;
  chosen := 0;
  lowPri := 7;
  roll := FxEngine.RollDice(1, 7);
  tries := 1;
  if count > 0 then
    { NON_PLAYER set }
    if (creature^.npc > $7F) or GDVars.quickMagic then
      if GDVars.teamCount[CharHlp.EnemyTeam(creature)] > 0 then
        while (tries <= roll) and (chosen = 0) do begin
          inner := 1;
          { three picks per pass }
          while (inner < 4) and (chosen = 0) do begin
            k := FxEngine.RollDice(1, count) - 1;
            spell := list[k];
            if CombatAi.DecideCastSpell(creature, spell, lowPri) then
              chosen := spell;
            Inc(inner);
          end;
          Dec(lowPri);
          Inc(tries);
        end;
  if chosen > 0 then
    CbtActs.CastSpellCombat(chosen, 1, ext)
  else
    ext := False;
  SelectSpellToCast := ext;
end;

{ Tells whether a creature can step in one of its fallback directions. A step off the map fails and sets edge, and an
  occupied cell fails. The step costs 2 (straight) or 3 (diagonal) times the terrain cost and must fit in the movement
  left. A stinking cloud is avoided unless the creature is animated, already coughing, or immune through either poison
  immunity.
  @param(creature The creature.)
  @param(attempt The fallback, 1 to 5, through the approach pattern's direction offsets.)
  @param(baseDir The direction wanted.)
  @param(edge Receives True when the step leads off the map.)
  @returns(True when the creature can step there.) }
function AiCanStep(creature: Types.PCharRecord; attempt, baseDir: Byte; var edge: Boolean): Boolean;
var
  effect: Types.PEffectRec;
  dirAdj: Byte;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  stepCost: Byte;
begin
  edge := False;
  AiCanStep := False;
  dirAdj := GDConsts.aiDirOffsets[creature^.combatAddr^.aiStance, attempt];
  dir := (baseDir + dirAdj) mod 8;
  CbtMap.ProbeDirection(creature, dir, crIdx, terrIdx);
  if terrIdx = 0 then begin
    { off the map: flee chance }
    edge := True;
    Exit;
  end;
  if crIdx <> 0 then
    { a creature blocks the cell }
    Exit;
  if GDConsts.terrainInfo[terrIdx].cost >= creature^.combatAddr^.movement then
    Exit;
  stepCost := 2;
  { diagonal: doubled metric 3 }
  if Odd(dir) then
    stepCost := 3;
  stepCost := stepCost * GDConsts.terrainInfo[terrIdx].cost;
  if terrIdx = C_Terr.TERRAIN_STINK_CLOUD then
    if (not CharHlp.HasEffect(creature, C_Effect.ANIMATE_DEAD, effect)) and
        (not CharHlp.HasEffect(creature, C_Effect.STINKING_CLOUD_COUGH, effect))
       and (not CharHlp.HasEffect(creature, C_Effect.NO_PARALYSIS_POISON, effect))
       and (not CharHlp.HasEffect(creature, C_Effect.NO_CHARM_POISON, effect)) then
      stepCost := creature^.combatAddr^.movement + 1;
  if creature^.combatAddr^.movement >= stepCost then
    AiCanStep := True;
end;

{ Takes one AI movement step: toward the locked target, or in the flee direction, trying up to five fallback directions
  from the approach pattern. A fleeing creature that reaches the map's edge tries to flee. Reversing or finding no way
  counts as stuck: the pattern changes, then the target is dropped, then the creature stops moving. A magic-user that is
  not fleeing does not walk. Note: hostiles flee along the party's facing, and north gives northwest and south gives
  southeast, so the direction is not always a cardinal one.
  @param(creature The creature.) }
procedure AiMoveStep(creature: Types.PCharRecord);
var
  dir: Byte;
  adjDir: Byte;
  attempt: Byte;
  edge: Boolean;
  done: Boolean;
begin
  TextRend.DisplayString(0, 24, LightGreen,
                         'Move/Attack, Move Left = ' + CharHlp.ByteToString(creature^.combatAddr^.movement div 2) +
                           ' ');
  if CombatAi.CheckKeystroke(creature) then
    Exit;
  { A mage that is not fleeing does not walk }
  if (creature^.combatAddr^.movement div 2 > 0)
     and (creature^.combatAddr^.initiative > 0)
     and ((creature^.combatAddr^.fleeing <> 0) or (creature^.charClass <> C_Class.MAGE)) then begin
    if creature^.combatAddr^.fleeing = 0 then
      dir := CbtActs.DirTowardTarget(creature, creature^.combatAddr^.other)
    else begin
      creature^.combatAddr^.aiStance := FxEngine.RollDice(1, 2);
      { Hostiles flee along the party's facing (C_Dir 0, 2, 4, 6). Note: north gives 7 (NW) and south gives 3 (SE), so
        the result is not always a cardinal direction. }
      dir := GDVars.partyPos.facing - Word((GDVars.partyPos.facing + 2) mod 4) div 2;
      if creature^.hostile = 0 then
        { allies flee the other way }
        dir := dir + 4;
      dir := dir mod 8;
    end;
    edge := False;
    done := False;
    attempt := 1;
    while (attempt < 6) and (not done)
          and (not CombatAi.AiCanStep(creature, attempt, dir, edge)) do
      if (creature^.combatAddr^.fleeing <> 0) and edge then
        done := CbtActs.AttemptFlee(creature)
      else
        Inc(attempt);
    if done then
    { fled off the map }
    begin
      creature^.combatAddr^.movement := 0;
      creature^.combatAddr^.fleeing := 0;
      done := CharHlp.EndActions(creature);
    end else begin
      adjDir := (dir + GDConsts.aiDirOffsets[creature^.combatAddr^.aiStance, attempt])
                mod 8;
      { nothing walkable }
      if (attempt = 6)
         { reversing }
         or (GDVars.lastMoveDir = (adjDir + 4) mod 8) then begin
        Inc(GDVars.stuckCount);
        creature^.combatAddr^.aiStance := creature^.combatAddr^.aiStance mod 6 + 1;
        if GDVars.stuckCount > 1 then begin
          creature^.combatAddr^.other := nil;
          if GDVars.stuckCount > 2 then begin
            creature^.combatAddr^.movement := 0;
            done := True;
          end else if not CbtActs.AcquireTarget(creature, 255, 1, 0) then
            done := CombatAi.FinishRound(creature);
        end;
      end;
      if attempt < 6 then
        GDVars.lastMoveDir := adjDir
      else
        done := True;
    end;
    { flee and step paths rejoin }
    if not done then begin
      CbtMap.SetCreatureFacing(creature, adjDir, 0, 0);
      CbtActs.AttacksOfOpportunity(creature, creature^.combatAddr^.direction);
      if creature^.enabled = 0 then
        done := CharHlp.EndActions(creature)
      else begin
        CbtActs.CombatMoveCreature(creature, creature^.combatAddr^.direction);
        if creature^.enabled = 0 then
          done := CharHlp.EndActions(creature);
        FxEngine.ConsiderTerrainEffects(creature);
      end;
    end;
  end else
    done := CombatAi.FinishRound(creature);
end;

{ Runs the AI's move-and-attack loop: a fleeing creature spends its movement; otherwise it attacks a target within its
  weapon's range, re-equips when it holds a missile weapon with an enemy beside it, or moves toward a target. The loop
  gives up after 20 passes. Note: the locked target can be nil and is read before the check for nil.
  @param(creature The creature.)
  @returns(True when the creature can no longer act.) }
function AiMoveAttack(creature: Types.PCharRecord): Boolean;
var
  done: Boolean;
  inRange: Boolean;
  canAct: Boolean;
  weaponRange: Byte;
  range: Word;
  cnt: Byte;
  pick: Byte;
  weapon: Types.PItemRec;
  target: Types.PCharRecord;
  tx: ShortInt;
  ty: ShortInt;
  loopCount: Byte;
begin
  GDVars.lastMoveDir := C_Dir.CENTER;
  GDVars.stuckCount := 0;
  GDVars.aiMoveState := 0;
  loopCount := 0;
  canAct := True;
  done := False;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MONSTER_SPECIAL, creature);
  if creature^.combatAddr^.initiative = 0 then
    canAct := False;
  while (not done) and canAct do begin
    { A fleeing creature spends all its remaining movement. fleeing is tested only before the inner loop starts. }
    if creature^.combatAddr^.fleeing <> 0 then
      while (creature^.combatAddr^.movement > 0)
            and (creature^.combatAddr^.initiative > 0)
            and (creature^.combatAddr^.initiative < 20) do
        CombatAi.AiMoveStep(creature);
    if (creature^.combatAddr^.initiative = 0)
       or (creature^.combatAddr^.initiative = 20) then
      canAct := False
    else
      done := False;
    if (not done) and canAct then begin
      Inc(loopCount);
      { runaway-turn guard }
      if loopCount > 20 then begin
        done := True;
        canAct := CombatAi.FinishRound(creature) = False;
      end;
      inRange := False;
      weaponRange := 1;
      if creature^.equipped[C_Equip.WEAPON] <> nil then
        weaponRange := GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].range - 1;
      if (weaponRange = 0) or (weaponRange = 255) then
        weaponRange := 1;
      { Note: other may be nil, and is dereferenced before the nil check below. }
      target := creature^.combatAddr^.other;
      if (target^.enabled = 0) or (target^.hostile = 0) then
        target := nil;
      if target <> nil then
        if CbtActs.CanTarget(creature, target) then begin
          tx := CbtMap.CombatCellX(target);
          ty := CbtMap.CombatCellY(target);
          range := weaponRange;
          if Pathing.WalkLine(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), tx, ty, range,
                              GDVars.arenaPtr) then
            if range div 2 <= weaponRange then
              inRange := True;
        end;
      if not inRange then begin
        cnt := CharHlp.CountTargets(creature, weaponRange);
        if cnt = 0 then begin
          if CbtActs.AcquireTarget(creature, 255, 0, 0) then
            { approach }
            CombatAi.AiMoveStep(creature)
          else
            done := CombatAi.FinishRound(creature);
        end else begin
          pick := FxEngine.RollDice(1, cnt);
          target := GDVars.creatureArr[GDVars.potentialTargets[pick]];
          if CharHlp.HasRangedWeapon(creature)
             and (not CharHlp.HasThrowableWeapon(creature))
             and (CharHlp.CountTargets(creature, 1) > 0) then begin
            { pure missile weapon with an enemy adjacent: re-equip }
            CombatAi.EquipWeaponAndArmor(creature);
            done := True;
          end else if (CharHlp.CalcDistance(creature, target) = 1)
                  or CbtActs.CanTarget(creature, target) then
            inRange := True;
        end;
      end;
      if inRange then
        CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2,
                          CbtActs.DirTowardTarget(creature, target));
      if inRange then begin
        if CbtActs.SweepAttack(creature, target) then
          done := CharHlp.EndActions(creature)
        else begin
          CbtActs.NoteAttackDirection(creature, target);
          weapon := nil;
          if CharHlp.HasRangedWeapon(creature) then begin
            inRange := CharHlp.FindDamagingRangedWeapon(creature, weapon);
            if CharHlp.HasThrowableWeapon(creature) then
              if CharHlp.CalcDistance(creature, target) = 1 then
                { adjacent: melee the throwable }
                weapon := nil;
          end;
          CbtActs.MakeAttack(creature, target, False, weapon, done);
          if done then
            canAct := False
          else if target^.enabled = 0 then
            done := True;
        end;
      end;
    end;
  end;
  AiMoveAttack := canAct = False;
end;

{ Ends a creature's round: a helpless creature, one with a ranged weapon or one out of initiative ends its actions, any
  other guards.
  @param(creature The creature.)
  @returns(True.) }
function FinishRound(creature: Types.PCharRecord): Boolean;
begin
  CharHlp.ClearMessageWindow;
  if CharHlp.IsHelpless(creature)
     or CharHlp.HasRangedWeapon(creature)
     or (creature^.combatAddr^.initiative = 0) then
    FinishRound := CharHlp.EndActions(creature)
  else
    FinishRound := CharHlp.Guard(creature);
end;

{ Handles a key pressed during an AI turn: Alt-M toggles quick magic, space returns each creature that is neither an NPC
  nor animated to manual control, and Alt-X tries the STING cheat. Pending keys are discarded afterwards. Note: the key
  is tested whether or not the extended-key prefix came first, so an unprefixed 2 also toggles quick magic and an
  unprefixed hyphen also tries the cheat.
  @param(creature The creature.)
  @returns(True when space put the creature itself back under manual control, which marks it to act again at once.) }
function CheckKeystroke(creature: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
  ch: Char;
begin
  CheckKeystroke := False;
  if KeyPressed then begin
    ch := GameIo.ReadGameKey;
    if ch = #0 then
      { this second call can consume later pending bytes too }
      ch := GameIo.ReadGameKey;
    case ch of
      C_Keys.ALT_M:
        begin
          GDVars.quickMagic := GDVars.quickMagic = False;
          if GDVars.quickMagic then
            CharHlp.PrintBottomLine('Magic On')
          else
            CharHlp.PrintBottomLine('Magic Off');
        end;
      { Space: everyone manual }
      ' ':
        begin
          p := GDVars.creatureList;
          while p <> nil do begin
            { NON_PLAYER clear }
            if (p^.npc < C_Npc.NON_PLAYER) and (p^.status <> C_Status.ANIMATED) then
              p^.quickfight := 0;
            p := p^.nextCharAddr;
          end;
          if creature^.quickfight = 0 then begin
            creature^.combatAddr^.initiative := 20;
            CheckKeystroke := True;
          end;
        end;
      { result ignored }
      C_Keys.ALT_X:
        if CbtActs.VictoryCheat then
          begin end;
    end;
  end;
  GameIo.DiscardPendingKeys;
end;

{ Checks a creature's morale against the hit points it has lost and then, for hostiles, against the group's remaining
  hit points; effects adjust the morale for each check. A failed check makes it flee when it is twice as fast as each
  enemy, and otherwise surrender when its Intelligence is 6 or more. A turned creature flees, and party members never
  check.
  @param(creature The creature.)
  @returns(True when the creature surrendered.) }
function CheckMorale(creature: Types.PCharRecord): Boolean;
var
  enemyMove: Byte;
  { Unused in this version; see the other implementations of this routine. }
  moraleSave: Byte;
begin
  CheckMorale := False;
  creature^.combatAddr^.fleeing := 0;
  { Removes BITE_HOLD and BLOOD_DRAIN }
  FxEngine.RemoveAiEffects(creature);
  if creature^.combatAddr^.turned <> 0 then begin
    creature^.combatAddr^.fleeing := 1;
    CharHlp.PrintCreatureMessage(creature, 'is forced to flee', 10, True);
    Exit;
  end;
  { NON_PLAYER clear }
  if creature^.npc <= $7F then
    { PCs never check morale }
    Exit;
  { packed morale rating }
  GDVars.curMorale := (creature^.npc and C_Npc.MORALE_MASK) * 2;
  if GDVars.curMorale > 102 then
    { 0 is the fail sentinel: both checks below require morale <> 0 }
    GDVars.curMorale := 0;
  { Effects adjust morale here: Bless +5, Curse -5 floored at 0 (so a curse below 5 fails both checks), Charm sets 100
    and flips the creature's side on its first call. Bless and Curse also adjust the attack roll. }
  FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, creature);
  if (GDVars.curMorale >= 100 - creature^.hpCur * 100 div creature^.hpMax)
     and (GDVars.curMorale <> 0) then
    { own-HP check holds }
    Exit;
  moraleSave := GDVars.curMorale;
  GDVars.curMorale := GDVars.hostileHpPct;
  { the same effect adjustments, now to the group figure }
  FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, creature);
  if (GDVars.curMorale >= 100 - GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD])
     and (GDVars.curMorale <> 0)
     and (creature^.hostile <> 0) then
    { group check holds (hostiles) }
    Exit;
  enemyMove := CbtActs.HighestEnemyMovement(creature);
  if enemyMove <= CbtActs.CalcCreatureMovement(creature) div 2 then begin
    { fast enough to get away: flee in panic }
    creature^.combatAddr^.fleeing := 1;
    FxEngine.RemoveEffect(creature, C_Effect.BITE_HOLD, nil);
    FxEngine.RemoveEffect(creature, C_Effect.BLOOD_DRAIN, nil);
  end else if creature^.intCur > 5 then begin
    { Int 6+ creatures give up instead }
    FxEngine.PutOutOfPlayWithStatus(creature, C_Status.UNCONSCIOUS, 'Surrenders');
    CheckMorale := CharHlp.EndActions(creature);
  end;
end;

{ Scores a weapon for EquipWeaponAndArmor: its damage dice product, 8 per plus, 2 per damage bonus (holy water against
  an undead target scores 8), 2 per extra shot for a launcher and 3 for a one-handed weapon. It scores 0 when it needs
  more than three hands, for an aligned weapon of another alignment, for the Javelin of Lightning and when cursed.
  @param(creature The creature.)
  @param(item The weapon.)
  @returns(The score.) }
function CalcWeaponPriority(creature: Types.PCharRecord; item: Types.PItemRec): Byte;
var
  pri: Byte;
  base: Types.TBaseItemRec;
begin
  base := GDVars.baseItems[item^.itemType];
  pri := base.dmgSmDice * base.dmgSmRolls;
  if item^.plus > 0 then
    pri := pri + item^.plus * 8;
  if base.dmgSmMod > 0 then
    pri := pri + base.dmgSmMod * 2;
  if (item^.itemType = C_Item.HOLY_WATER_VIAL)
     and (creature^.combatAddr^.other <> nil)
     and (creature^.combatAddr^.other^.levelUndead > 0) then
    pri := 8;
  { launcher: +2 per rateOfFire point above 1 }
  if (base.props and C_Item.PROP_FIRES_AMMO) > 0 then
    pri := pri + (base.rateOfFire - 1) * 2;
  if base.hands <= 1 then
    pri := pri + 3;
  if base.hands + creature^.handsEquipped > 3 then
    { not enough hands }
    pri := 0;
  { aligned weapon }
  if item^.special = C_Effect.ALIGNED_WEAPON then
    if (item^.effect and $F) <> creature^.alignment then
      pri := 0;
  { Javelin of Lightning }
  if item^.effect = 83 then
    pri := 0;
  if item^.cursed <> 0 then
    pri := 0;
  CalcWeaponPriority := pri;
end;

{ Re-equips a creature with its best usable weapon (CalcWeaponPriority; its unarmed damage sets the bar for melee) and
  its best shield (plus + 1). The ranged pick wins when it scores above half the melee score, has ammunition, and is a
  true ranged weapon or no enemy is beside the creature. Cursed items are never swapped out; with too many hands in use
  the shield, or else the weapon, is unreadied. The creature's information is redrawn when anything changed.
  @param(creature The creature.) }
procedure EquipWeaponAndArmor(creature: Types.PCharRecord);
var
  bestRanged: Types.PItemRec;
  bestMelee: Types.PItemRec;
  bestShield: Types.PItemRec;
  item: Types.PItemRec;
  ammo: Types.PItemRec;
  bestRangedPri: Byte;
  bestMeleePri: Byte;
  bestShieldPri: Byte;
  pri: Byte;
  itType: Byte;
  props: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hands: Byte;
  needSwap: Boolean;
  changed: Boolean;
  trueRanged: Boolean;
  hasAmmo: Boolean;
begin
  { stop counting the current weapon/shield hands }
  if creature^.equipped[C_Equip.WEAPON] <> nil then
    creature^.handsEquipped := creature^.handsEquipped
        - GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].hands;
  if creature^.equipped[C_Equip.SHIELD] <> nil then
    creature^.handsEquipped := creature^.handsEquipped
        - GDVars.baseItems[creature^.equipped[C_Equip.SHIELD]^.itemType].hands;
  bestRanged := nil;
  bestMelee := nil;
  bestShield := nil;
  bestRangedPri := 1;
  bestMeleePri := creature^.unarmedDiceA[1] * creature^.unarmedRollsA[1];
  if creature^.unarmedModA[1] > 0 then
    bestMeleePri := bestMeleePri + creature^.unarmedModA[1] * 2;
  bestShieldPri := 0;
  item := creature^.itemsAddr;
  while item <> nil do begin
    itType := item^.itemType;
    { weapon slot }
    if GDVars.baseItems[itType].slot = C_Equip.WEAPON then
      if (GDVars.baseItems[itType].classMask and creature^.itemLimits) <> 0 then begin
        pri := CombatAi.CalcWeaponPriority(creature, item);
        if ((GDVars.baseItems[itType].props and C_Item.PROP_FIRES_AMMO) <> 0)
           or ((GDVars.baseItems[itType].props and C_Item.PROP_THROWN) <> 0) then
          if pri > bestRangedPri then begin
            bestRanged := item;
            bestRangedPri := pri;
          end;
        if (GDVars.baseItems[itType].props and C_Item.PROP_FIRES_AMMO) = 0 then
          if pri > bestMeleePri then begin
            bestMelee := item;
            bestMeleePri := pri;
          end;
      end;
    { shield slot }
    if GDVars.baseItems[itType].slot = C_Equip.SHIELD then
      if (GDVars.baseItems[itType].classMask and creature^.itemLimits) > 0 then begin
        if item^.plus >= 0 then
          pri := item^.plus + 1
        else
          pri := 0;
        if pri > bestShieldPri then begin
          bestShield := item;
          bestShieldPri := pri;
        end;
      end;
    item := item^.next;
  end;
  { trueRanged: range > 1 and both PROPS_THROWABLE bits (thrown, Strength bonus); such a weapon is picked even with an
    enemy adjacent }
  if (bestRanged <> nil)
     and (GDVars.baseItems[bestRanged^.itemType].range > 1)
     and
       ((GDVars.baseItems[bestRanged^.itemType].props and
         C_Item.PROPS_THROWABLE) = C_Item.PROPS_THROWABLE) then
    trueRanged := True
  else
    trueRanged := False;
  hasAmmo := False;
  ammo := nil;
  props := 0;
  if bestRanged <> nil then begin
    props := GDVars.baseItems[bestRanged^.itemType].props;
    if (props and C_Item.PROP_THROWN) <> 0 then
      { thrown: is its own ammo }
      ammo := bestRanged;
    if (props and C_Item.PROP_FIRES_AMMO) <> 0 then begin
      if (props and C_Item.PROP_ARROWS) <> 0 then
        ammo := creature^.equipped[C_Equip.ARROW];
      if (props and C_Item.PROP_QUARRELS) <> 0 then
        ammo := creature^.equipped[C_Equip.BOLT];
    end;
  end;
  { props = $A exactly (PROP_FIRES_AMMO + ITEM_PROP_DEX_MISSILE, no arrow, quarrel or thrown bit): a launcher with no
    ammo to look up counts as supplied }
  if (ammo <> nil) or (props = $A) then
    hasAmmo := True;
  { pick the weapon }
  if (bestRanged <> nil)
     and (bestRangedPri > bestMeleePri div 2)
     and hasAmmo
     and (trueRanged or (CharHlp.CountTargets(creature, 1) = 0)) then
    item := bestRanged
  else
    item := bestMelee;
  changed := False;
  needSwap := True;
  if creature^.equipped[C_Equip.WEAPON] <> nil then
    if (creature^.equipped[C_Equip.WEAPON] = item) or (creature^.equipped[C_Equip.WEAPON]^.cursed <> 0) then
      needSwap := False;
  if needSwap then begin
    if creature^.equipped[C_Equip.WEAPON] <> nil then
      ViewChar.ToggleReadyItem(creature^.equipped[C_Equip.WEAPON]);
    CharHlp.RecalcStats(creature);
    if creature^.equipped[C_Equip.SHIELD] <> nil then
      if creature^.equipped[C_Equip.SHIELD]^.cursed = 0 then
        creature^.handsEquipped := creature^.handsEquipped
            - GDVars.baseItems[creature^.equipped[C_Equip.SHIELD]^.itemType].hands;
    if item <> nil then
      ViewChar.ToggleReadyItem(item);
    changed := True;
  end;
  CharHlp.RecalcStats(creature);
  CbtActs.RecalcAttacksLeft(creature);
  needSwap := True;
  if creature^.equipped[C_Equip.SHIELD] <> nil then
    if (creature^.equipped[C_Equip.SHIELD] = bestShield)
       or (creature^.equipped[C_Equip.SHIELD]^.cursed <> 0) then
      needSwap := False;
  if creature^.handsEquipped > 2 then begin
    { Over-handed: drop the shield, or the chosen weapon when there is no shield or the shield is cursed }
    if (creature^.equipped[C_Equip.SHIELD] = nil) or
        (creature^.equipped[C_Equip.SHIELD]^.cursed <> 0) then begin
      ViewChar.ToggleReadyItem(item);
      changed := True;
    end else begin
      ViewChar.ToggleReadyItem(creature^.equipped[C_Equip.SHIELD]);
      changed := True;
    end;
  end else if (creature^.handsEquipped < 2) and needSwap then begin
    if creature^.equipped[C_Equip.SHIELD] <> nil then
      ViewChar.ToggleReadyItem(creature^.equipped[C_Equip.SHIELD]);
    CharHlp.RecalcStats(creature);
    if bestShield <> nil then
      ViewChar.ToggleReadyItem(bestShield);
    changed := True;
  end;
  CharHlp.RecalcStats(creature);
  if changed then
    CharHlp.CombatPrintCreatureInfo(creature);
end;

begin
end.
