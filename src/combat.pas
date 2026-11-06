{ Combat loop, initiative selection and manual-control menus. }

{$O+,F+}
unit Combat;

interface

uses Types, C_Time, C_Npc, C_Cond, GDConsts, GDVars, Crt, CombatAi, CombatSt, GameTime, Magic, C_Keys, C_Class,
  C_Status, C_Ifc, C_Gbvm, C_Dir, Blit, CbtMap, CbtActs, CharHlp, FxEngine, ViewChar, MenuCore, GameIo, Border;

{ Runs a battle. Each round counts the teams, runs each creature's round-start setup, clears the GBVM surprise flag,
  lets the creatures act in initiative order and then ends the round, which decides whether the battle goes on. A battle
  with an empty side ends at once. Afterwards the combat state is released. }
procedure CombatMain;

implementation

const
  { Extended scan codes }
  KEY_ALT_Q = #16;
  KEY_ALT_R = #19;

procedure NextCreature(var next: Types.PCharRecord); forward;

procedure CreatureAction(creature: Types.PCharRecord); forward;

procedure ManualControl(creature: Types.PCharRecord); forward;

procedure CombatMenu(creature: Types.PCharRecord; var ch: Char); forward;

procedure EndOfRound(var done: Boolean); forward;

procedure MoveMenu(creature: Types.PCharRecord; var done: Boolean); forward;

procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean); forward;

procedure DoneMenu(creature: Types.PCharRecord; var done: Boolean); forward;

function BandageDying(bandage: Boolean): Boolean; forward;

procedure SpeedMenu; forward;

procedure TurnOnAuto(creature: Types.PCharRecord); forward;

{ Releases the combat state: frees the stinking-cloud list, the arena and the move-icon sheet, restores the noncombat
  palette and points the spell-target handler back at the noncombat menu. }
procedure CombatDoneCleanup;
var
  p: Types.PStinkRec;
  { Unused in this version; see the other implementations of this routine. }
  nodeCount: Integer;
begin
  while GDVars.stinkHead <> nil do begin
    p := GDVars.stinkHead^.next;
    FreeMem(GDVars.stinkHead, SizeOf(Types.TStinkRec));
    GDVars.stinkHead := p;
  end;
  FreeMem(GDVars.arenaPtr, SizeOf(Types.TArena));
  GDVars.arenaPtr := nil;
  Blit.FreePic(GDVars.moveIconSheet);
  CbtMap.SetNoncombatPalette;
  @GDVars.spellHandlers.castTargets := @Magic.NoncombatCastTargetMenu;
end;

procedure CombatMain;
var
  done: Boolean;
  creature: Types.PCharRecord;
begin
  GDVars.ifcState := C_Ifc.IN_COMBAT;
  @GDVars.spellHandlers.castTargets := @CbtActs.SelectCombatTargets;
  CombatSt.CombatStart;
  done := False;
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) then
    done := True;
  while not done do begin
    CharHlp.CountTeams;
    creature := GDVars.creatureList;
    while creature <> nil do begin
      CbtActs.BeginRound(creature);
      creature := creature^.nextCharAddr;
    end;
    GDVars.zone1^[C_Gbvm.SURPRISE] := 0;
    Combat.NextCreature(creature);
    while creature <> nil do begin
      Combat.CreatureAction(creature);
      Combat.NextCreature(creature);
    end;
    Combat.EndOfRound(done);
  end;
  Combat.CombatDoneCleanup;
end;

{ Picks the creature that acts next: the highest initiative, ties going to the higher 1d100 roll and, on a full tie, to
  the later creature in the list.
  @param(next Receives the creature, or nil when no creature has initiative left.) }
procedure NextCreature(var next: Types.PCharRecord);
var
  best: Byte;
  bestRoll: Byte;
  roll: Byte;
  p: Types.PCharRecord;
begin
  best := 0;
  bestRoll := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    roll := FxEngine.RollDice(1, 100);
    if p^.combatAddr^.initiative > best then
      bestRoll := roll;
    if (p^.combatAddr^.initiative >= best) and (roll >= bestRoll) then begin
      bestRoll := roll;
      best := p^.combatAddr^.initiative;
      next := p;
    end;
    p := p^.nextCharAddr;
  end;
  { No positive initiative: no next turn }
  if best = 0 then
    next := nil;
end;

{ Runs one creature's turn: clears its flanking counts and guard, fires its turn-start effects and, while it still has
  initiative, lets the AI (quick-fight) or the player act, then redraws its cell to erase the cursor. A creature marked
  to act again at once (initiative 20) is set back to 19.
  @param(creature The creature.) }
procedure CreatureAction(creature: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  initiative: Integer;
begin
  creature^.combatAddr^.flankCount := 0;
  creature^.combatAddr^.flankSpread := 0;
  creature^.combatAddr^.guarding := 0;
  { turn-start effects, among them those that leave the creature helpless }
  FxEngine.TriggerEffectsWithCondition(C_Cond.TURN_START, creature);
  if creature^.combatAddr^.initiative <= 0 then
    Exit;
  { Initiative 20 marks a creature that switched between manual and AI control mid-turn (Alt-Q here, space in CombatAi)
    so that it acts again at once; clear the mark }
  if creature^.combatAddr^.initiative = 20 then
    creature^.combatAddr^.initiative := 19;
  GDVars.curChar := creature;
  CbtMap.DisplayMapViewCentered(creature, 2, True);
  CharHlp.RecalcStats(creature);
  CharHlp.CombatPrintCreatureInfo(creature);
  FxEngine.TriggerEffectsWithCondition(C_Cond.ACTION_START, creature);
  if creature^.combatAddr^.initiative > 0 then
    if creature^.quickfight <> 0 then
      CombatAi.CombatAiControl(creature)
    else
      Combat.ManualControl(creature);
  CbtMap.RedrawArenaCell(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature));
end;

{ Runs the player's turn for a creature: a spell begun earlier resolves now; otherwise the combat menu runs until an
  action ends the turn. Space puts each creature that is not an NPC back under manual control, Alt-Q puts everyone on
  quick-fight and lets this creature act again at once under the AI, Alt-M toggles quick magic and Alt-X tries the STING
  cheat. A disabled creature just ends its actions.
  @param(creature The creature.) }
procedure ManualControl(creature: Types.PCharRecord);
var
  ch: Char;
  done: Boolean;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  aimInfo: array[1..3] of Byte;
  aimTgt: Pointer;
  spell: Byte;
begin
  if creature^.enabled <> 0 then begin
    if creature^.combatAddr^.spellCast > 0 then begin
      { a spell begun earlier (CbtActs.CastSpellCombat) resolves now }
      spell := creature^.combatAddr^.spellCast;
      creature^.combatAddr^.spellCast := 0;
      Magic.CastSpell(spell, False, True, done);
      done := CharHlp.EndActions(creature);
    end else begin
      done := False;
      while not done do begin
        Combat.CombatMenu(creature, ch);
        case ch of
          'M': Combat.MoveMenu(creature, done);
          'V': begin
                 ViewChar.ViewCharMenu(done);
                 CbtActs.RecalcAttacksLeft(creature);
                 if not done then
                   CharHlp.DisplayCombatInterface;
               end;
          'A': CbtActs.CombatAimMenu(creature, 255, 1, 0, done, aimTgt);
          'U': begin
                 ViewChar.UseItemMenu(done);
                 CbtActs.RecalcAttacksLeft(creature);
                 if not done then
                   CharHlp.DisplayCombatInterface;
               end;
          'C': CbtActs.CastSpellCombat(0, 0, done);
          'T': begin
                 CbtActs.CombatTurnUndead(creature);
                 done := CharHlp.EndActions(creature);
               end;
          'Q': begin
                 Combat.TurnOnAuto(creature);
                 MenuCore.ClearBottomLine;
                 GameIo.DiscardPendingKeys;
                 Delay(200);
                 done := True;
                 CombatAi.CombatAiControl(creature);
               end;
          'D': Combat.DoneMenu(creature, done);
          { Alt-M scan code: toggle quick magic }
          C_Keys.ALT_M: begin
                      GDVars.quickMagic := GDVars.quickMagic = False;
                      if GDVars.quickMagic then
                        CharHlp.PrintBottomLine('Magic On')
                      else
                        CharHlp.PrintBottomLine('Magic Off');
                    end;
          { every non-NPC creature back to manual control }
          ' ': begin
                 p := GDVars.creatureList;
                 while p <> nil do begin
                   { creatures with the NPC flag (high bit of npc) stay on quick-fight }
                   if p^.npc < C_Npc.NON_PLAYER then
                     p^.quickfight := 0;
                   p := p^.nextCharAddr;
                 end;
               end;
          { Alt-Q scan code: everyone to quick-fight; this creature acts again at once under the AI }
          Combat.KEY_ALT_Q: begin
                      creature^.combatAddr^.initiative := 20;
                      p := GDVars.creatureList;
                      while p <> nil do begin
                        Combat.TurnOnAuto(p);
                        p := p^.nextCharAddr;
                      end;
                      MenuCore.ClearBottomLine;
                      Delay(200);
                      done := True;
                    end;
          { Alt-X scan code: the STING cheat }
          C_Keys.ALT_X: if CbtActs.VictoryCheat then begin
                      CbtMap.DisplayMapViewCentered(creature, 3, False);
                      done := True;
                    end else
                      CharHlp.PrintBottomLine('That doesn''t work');
        end;
        if not done then begin
          CbtMap.DisplayMapViewCentered(creature, 2, True);
          CharHlp.CombatPrintCreatureInfo(creature);
        end;
      end;
    end;
  end else
    done := CharHlp.EndActions(creature);
end;

{ Builds the combat command menu from what the creature can do and runs it until an accepted key arrives. Note: the
  extended-key flag is kept in hasSpell; Alt-R is accepted but nothing acts on it.
  @param(creature The creature.)
  @param(ch Receives the command key.) }
procedure CombatMenu(creature: Types.PCharRecord; var ch: Char);
var
  menu: String[40];
  i: Byte;
  hasSpell: Boolean;
begin
  FxEngine.TriggerEffectsWithCondition(C_Cond.ACTION_START, creature);
  menu := '';
  if creature^.combatAddr^.movement > 0 then
    menu := menu + 'Move ';
  menu := menu + 'View Aim ';
  if creature^.numberOfItems > 0 then
    menu := menu + 'Use ';
  hasSpell := False;
  for i := 0 to SizeOf(creature^.memorizedSpells) div SizeOf(creature^.memorizedSpells[0]) - 1 do
    if creature^.memorizedSpells[i] > 0 then
      hasSpell := True;
  if hasSpell and (creature^.combatAddr^.castAllowed <> 0)
     and (GDVars.zone0^.antimagic = 0) then
    menu := menu + 'Cast ';
  if (creature^.classLevels[C_Class.CLERIC_LEVEL] > 0)
     and (creature^.combatAddr^.usedTurnUndead = 0) then
    menu := menu + 'Turn ';
  menu := menu + 'Quick Done';
  { hasSpell doubles as MenuHorizontal's extended-key flag: an extended key other than Alt-Q, Alt-R, Alt-X or Alt-M
    becomes NONE and is rejected. Alt-R is accepted here, but ManualControl has no arm for it. }
  repeat
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, hasSpell);
    if hasSpell then
      if not (ch in [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, C_Keys.ALT_X, C_Keys.ALT_M]) then
        ch := C_Keys.NONE;
  until ch in [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, ' ', C_Keys.ALT_X, C_Keys.ALT_M, 'A', 'C', 'D', 'M', 'Q',
               'T', 'U', 'V'];
end;

{ Ends a round: advances the clock one minute, fires the round-end and terrain effects, bleeds dying creatures (dead at
  10 below), warns when a party member is dying, and ends the battle when a side is empty, unless the party won and the
  player chooses to continue (not asked while suppressContinuePrompt is set).
  @param(done Receives True when the battle is over; left as it was otherwise.) }
procedure EndOfRound(var done: Boolean);
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  status: Byte;
  cnt: Byte;
begin
  { one minute (tUnit 1) }
  GameTime.AdvanceTime(1, C_Time.MINUTES);
  Inc(GDVars.roundCounter);
  CbtActs.UpdateHostileHpPercent;
  p := GDVars.creatureList;
  cnt := 1;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_Cond.ROUND_END, p);
    FxEngine.ConsiderTerrainEffects(p);
    if p^.status = C_Status.DYING then begin
      Inc(p^.combatAddr^.overkill);
      if p^.combatAddr^.overkill > 9 then
        { dead at -10 }
        p^.status := C_Status.DEAD_STATUS;
    end;
    Inc(cnt);
    p := p^.nextCharAddr;
  end;
  if Combat.BandageDying(False) then
    CharHlp.PrintBottomLine('Your Teammate is Dying');
  CharHlp.CountTeams;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, C_Dir.CENTER);
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) then
    done := True;
  if (GDVars.teamCount[0] > 0) and (GDVars.teamCount[1] = 0)
     and (GDVars.suppressContinuePrompt = 0) then
    if MenuCore.YesNoMenu('Continue Battle:', LightMagenta, LightGreen, White) = 'Y' then
      done := False;
end;

{ Moves a creature cell by cell with the direction keys while it has at least two half-moves left. Stepping into a
  creature attacks it, stepping off the arena offers to flee, and Escape undoes the whole move. Each step draws free
  attacks from the enemies it leaves and the effects of the new cell.
  @param(creature The creature.)
  @param(done Receives True when the creature's actions are over.) }
procedure MoveMenu(creature: Types.PCharRecord; var done: Boolean);
var
  savedMove: Byte;
  savedDir: Byte;
  startX: ShortInt;
  startY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  slot: Integer;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  ch: Char;
begin
  savedMove := creature^.combatAddr^.movement;
  savedDir := creature^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(creature);
  startY := CbtMap.CombatCellY(creature);
  ch := ' ';
  done := False;
  dir := C_Dir.CENTER;
  while (creature^.combatAddr^.movement > 1) and (ch <> C_Keys.NONE)
        and (ch <> C_Keys.ENTER) do begin
    Border.ClearBox(24, 24, 39, 24);
    ch :=
      MenuCore.MenuHorizontal('Move/Attack, Move Left = ' + CharHlp.ByteToString(creature^.combatAddr^.movement div 2) +
      ' ', '', LightGreen, LightGreen, White, True, False, GDVars.doneRoundFlag);
    case ch of
      { Escape: undo }
      C_Keys.NONE: begin
                  creature^.combatAddr^.movement := savedMove;
                  CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(creature));
                  { Put it back on its start cell; the turn ends if that cell is no longer free }
                  done := CbtMap.IsValidCreatureLoc(creature, startX, startY, False) = False;
                  CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 0, C_Dir.CENTER);
                  creature^.combatAddr^.direction := savedDir;
                  dir := C_Dir.CENTER;
                end;
      C_Keys.UP: dir := C_Dir.NORTH;
      C_Keys.PAGE_UP: dir := C_Dir.NORTHEAST;
      C_Keys.RIGHT: dir := C_Dir.EAST;
      C_Keys.PAGE_DOWN: dir := C_Dir.SOUTHEAST;
      C_Keys.DOWN: dir := C_Dir.SOUTH;
      C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
      C_Keys.LEFT: dir := C_Dir.WEST;
      C_Keys.HOME: dir := C_Dir.NORTHWEST;
    else
      dir := C_Dir.CENTER;
    end;
    if dir < C_Dir.CENTER then begin
      CbtMap.SetCreatureFacing(creature, dir, 0, 0);
      CbtMap.ProbeDirection(creature, dir, crIdx, terrIdx);
      if crIdx > 0 then
        Combat.MeleeAttack(creature, GDVars.creatureArr[crIdx], done)
      else if terrIdx = 0 then begin
        case MenuCore.YesNoMenu('Flee:', LightMagenta, LightGreen, White) of
          'Y': done := CbtActs.AttemptFlee(creature);
          'N': done := False;
        end;
      end else if GDConsts.terrainInfo[terrIdx].cost > creature^.combatAddr^.movement then
        CharHlp.PrintBottomLine('Blocked')
      else begin
        { free attacks from the enemies this step leaves }
        CbtActs.AttacksOfOpportunity(creature, dir);
        if creature^.enabled = 0 then
          done := CharHlp.EndActions(creature)
        else begin
          CbtActs.CombatMoveCreature(creature, dir);
          if creature^.enabled = 0 then
            done := CharHlp.EndActions(creature);
          FxEngine.ConsiderTerrainEffects(creature);
          if CharHlp.IsHelpless(creature) then
            done := CharHlp.EndActions(creature);
        end;
      end;
    end;
  end;
  if creature^.combatAddr^.movement < 2 then
    creature^.combatAddr^.movement := 0;
end;

{ Makes MoveMenu's attack on a creature in the way, refused with a ranged weapon that cannot be thrown. Once an attack
  on an ally is confirmed, the target is locked, and a sweep is tried before a normal attack.
  @param(att The attacker.)
  @param(def The creature attacked.)
  @param(done Receives True when the attacker's actions are over; left as it was when the attack is refused.) }
procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean);
begin
  if CharHlp.HasRangedWeapon(att) and not CharHlp.HasThrowableWeapon(att) then
    CharHlp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(att, def) then begin
    att^.combatAddr^.other := def;
    if CbtActs.SweepAttack(att, def) then
      done := True
    else begin
      CbtActs.NoteAttackDirection(att, def);
      CbtActs.MakeAttack(att, def, False, nil, done);
    end;
  end;
end;

{ Runs the Done menu: Guard (with a melee or throwable weapon), Delay, Quit, Bandage (while a party member is dying),
  Speed and Exit.
  @param(creature The creature.)
  @param(done Receives True when the creature's actions are over.) }
procedure DoneMenu(creature: Types.PCharRecord; var done: Boolean);
var
  menu: String[40];
  ch: Char;
begin
  done := False;
  menu := '';
  if not CharHlp.HasRangedWeapon(creature) or CharHlp.HasThrowableWeapon(creature) then
    menu := menu + 'Guard ';
  menu := menu + 'Delay Quit ';
  if Combat.BandageDying(False) then
    menu := menu + 'Bandage ';
  menu := menu + 'Speed Exit';
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, False, False,
                                  GDVars.doneRoundFlag);
    case ch of
      'G': done := CharHlp.Guard(creature);
      { Delay: act again later this round, at initiative 1 }
      'D': begin
             creature^.combatAddr^.initiative := 1;
             done := True;
           end;
      'Q': done := CharHlp.EndActions(creature);
      'B': begin
             done := Combat.BandageDying(True);
             { Bandage result is overwritten }
             done := CharHlp.EndActions(creature);
           end;
      'S': Combat.SpeedMenu;
    end;
  end;
end;

{ Looks for dying party members; with bandage set, the first one found is bandaged to unconscious.
  @param(bandage True to bandage the first dying party member.)
  @returns(True when a party member is dying.) }
function BandageDying(bandage: Boolean): Boolean;
var
  p: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpc = 0) and (p^.hostile = 0)
       and (p^.status = C_Status.DYING) then begin
      found := True;
      if bandage then begin
        p^.status := C_Status.UNCONSCIOUS;
        p^.combatAddr^.overkill := 0;
        CharHlp.PrintCreatureMessage(p, 'is bandaged', 10, True);
        { Stop bandaging; keep scanning }
        bandage := False;
      end;
    end;
    p := p^.nextCharAddr;
  end;
  BandageDying := found;
end;

{ Runs the game-speed menu: Slower (below 9) raises gameDelay, Faster (above 0) lowers it, until Exit or Escape. }
procedure SpeedMenu;
var
  menu: String[40];
  query: String[40];
  ch: Char;
begin
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) do
  begin
    query := 'GameSpeed (' + CharHlp.ByteToString(GDVars.gameDelay) + ') :';
    menu := ' ';
    if GDVars.gameDelay < 9 then
      menu := menu + 'Slower ';
    if GDVars.gameDelay > 0 then
      menu := menu + 'Faster ';
    menu := menu + 'Exit';
    ch := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, False, False,
                                  GDVars.doneRoundFlag);
    case ch of
      'S': Inc(GDVars.gameDelay);
      'F': Dec(GDVars.gameDelay);
    end;
  end;
end;

{ Puts a creature on quick-fight, dropping a locked target on its own side.
  @param(creature The creature.) }
procedure TurnOnAuto(creature: Types.PCharRecord);
begin
  creature^.quickfight := 1;
  if (creature^.combatAddr^.other <> nil)
     and (creature^.combatAddr^.other^.hostile = creature^.hostile) then begin
    creature^.combatAddr^.other := nil;
  end;
end;

begin
end.
