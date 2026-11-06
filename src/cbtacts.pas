{ Combat movement, attacks, aiming and spell targeting. }
{$O+,F+}
unit CbtActs;

interface

uses Types, C_Item, C_Terr, C_Cond, GDConsts, GDVars, Crt, SoundDrv, GameIo, TextRend, Border,
  CharHlp, MenuCore, Pathing, CbtMap, ViewChar, Magic, FxEngine, C_Effect, C_Equip, C_Keys, C_Class, C_Status, C_Gbvm,
  C_Dir, C_Sound, C_Spell;

{ Resets a creature for a new round: the combat record's casting and attack flags, its current attacks (then the
  secondary attacks, after the condition-18 effects), its sweep budget (its attack level), its initiative and its
  movement. Initiative is 1d6 plus the Dexterity missile adjustment, at least 1, less 6 when the creature's side is
  surprised, and 0 for a disabled creature or a result outside 0..20.
  @param(creature The creature starting the round.) }
procedure BeginRound(creature: Types.PCharRecord);

{ Computes a creature's movement in half-steps: its current movement plus, for the party, the zone's movement modifier
  (a result outside 1..96 becomes 1), doubled and then adjusted by its condition-18 effects, which run with the movement
  flag set.
  @param(creature The creature whose movement is computed.)
  @returns(The movement in half-steps.) }
function CalcCreatureMovement(creature: Types.PCharRecord): Byte;

{ Rolls an attack phase's damage dice plus bonus into pendingDamage, multiplied by the thief level div 4 + 2 on a
  backstab, clears the element mask and fires the attacker's and defender's weapon-damage effects.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @param(phase The attack phase, 1 or 2.) }
procedure CalcWeaponDamage(attacker, defender: Types.PCharRecord; phase: Byte);

{ Prints an attack's message and deals its damage. Any damage stops the defender casting this round and loses a spell it
  was casting; a defender that goes down loses its 0-hit-point effects, runs its 0-hit-point effects and is marked as
  downed when still disabled.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @param(manner 1 from behind, 2 a backstab, 3 slaying a helpless defender; otherwise a plain attack.)
  @param(damage The damage dealt.)
  @param(shownDamage The damage shown.)
  @param(isHit True on a hit.) }
procedure ProcessAttackResult(attacker, defender: Types.PCharRecord; manner, damage, shownDamage: Byte; isHit: Boolean);

{ Moves a creature one cell in combat: it pays 2 half-moves, 3 on a diagonal (with too few left its movement drops to 0
  and it stays), its icon moves, its flanking counts clear, the step sound plays and guarding enemies attack. A mover
  left disabled or helpless loses the rest of its movement.
  @param(creature The creature.)
  @param(direction The direction, 0 to 7.) }
procedure CombatMoveCreature(creature: Types.PCharRecord; direction: Byte);

{ Gives each enemy adjacent to a creature before a step, but not after it, one free attack on the mover, made as from
  behind, while the mover stays up. Helpless enemies, enemies an effect forbids to attack, and enemies draining blood or
  holding with a bite are skipped. An enemy with no initiative left that has already been attacked this round needs the
  mover in the five directions in front of it. The attack uses the enemy's highest phase with attacks left, granting one
  attack when that phase has no attacks left, and the enemy's own target is kept.
  @param(creature The creature about to move.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure AttacksOfOpportunity(creature: Types.PCharRecord; direction: Byte);

{ Tries to flee. It succeeds automatically with no enemy in the target list, and otherwise when the creature's movement
  in whole steps beats the fastest enemy's, or on 1 in 2 when they tie. Success takes the creature out of play as
  running, with 'Got Away'; failure prints 'Escape is blocked'. The creature's actions end either way.
  @param(creature The creature fleeing.)
  @returns(The result of ending its actions.) }
function AttemptFlee(creature: Types.PCharRecord): Boolean;

{ Sets a creature's current attacks for the round. It starts from the weapon's rate of fire (at least 2) when it has a
  ranged weapon with ammunition, else from its base attacks, both in half-attacks; applies its condition-18 effects and
  AttacksFromRate, and caps a ranged weapon by its ammunition. Once an attack has been made, the result replaces the
  current attacks when it is below the previous count (in melee, below twice it). Note: otherwise the current attacks
  keep the base attacks value, in half-attacks, rather than the previous count.
  @param(creature The creature whose attacks are recalculated.) }
procedure RecalcAttacksLeft(creature: Types.PCharRecord);

{ Converts half-attacks to attacks: adds 1 on odd rounds, then halves.
  @param(rate The rate in half-attacks.)
  @returns(The whole attacks for this round.) }
function AttacksFromRate(rate: Byte): Byte;

{ Sweeps level-0 enemies. When the defender is an adjacent level-0 enemy, the attacker's sweep budget exceeds its
  current attacks, and more adjacent level-0 enemies stand around it than it has current attacks, the attacker makes one
  attack on each of up to its sweep budget of them, the defender first.
  @param(att The creature attacking.)
  @param(def The enemy chosen to attack.)
  @returns(True if the attacker swept.) }
function SweepAttack(att, def: Types.PCharRecord): Boolean;

{ Checks whether effects let one creature attack another. True when the target is the attacker itself, False when the
  target is nil. Otherwise the target's condition-1 effects run, then, unless they vetoed, the attacker's condition-0
  effects with the target as its temporary target; an effect vetoes by setting the targeting veto flag.
  @param(attacker The creature that would attack.)
  @param(target The creature it would attack, or nil.)
  @returns(True when the attack is allowed.) }
function CanTarget(attacker, target: Types.PCharRecord): Boolean;

{ Turns undead: one d20 roll against the turning table, applied to up to 1d12 undead, lowest level first, until one
  resists. A turned undead flees; one the table destroys is gone. The cleric's actions end.
  @param(creature The cleric.) }
procedure CombatTurnUndead(creature: Types.PCharRecord);

{ Finds the lowest-level unturned undead in the target list (any range); equal levels keep the earlier one, and undead
  of level 13 or more are never picked.
  @param(creature The creature turning undead.)
  @param(target Receives the undead found, or nil.)
  @returns(True if a target was found.) }
function FindTurnUndeadTarget(creature: Types.PCharRecord; var target: Pointer): Boolean;

{ Records an attack on a defender for flanking: the defender's count of attackers goes up, and the angle between its
  facing and the attack's direction (0..4) is added to its spread, mod 8.
  @param(attacker The attacker.)
  @param(defender The defender.) }
procedure NoteAttackDirection(attacker, defender: Types.PCharRecord);

{ Makes an attack. The defender turns to face the attacker, unless from behind or already attacked three times, and the
  attacker turns and strikes, a missile flying for a missile weapon and for a readied sling. With attacks left the
  attacks are rolled; the missile or thrown weapon then loses the first-phase attacks from its quantity, and goes once
  used up, a used-up thrown weapon other than a spiritual hammer dropping into the treasure. Note: the readied weapon is
  read without a check for nil.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @param(fromBehind True for an attack from behind.)
  @param(weapon The missile or thrown weapon, or nil for melee.)
  @param(done Receives True when the attacker's actions are over.) }
procedure MakeAttack(attacker, defender: Types.PCharRecord; fromBehind: Boolean; weapon: Types.PItemRec;
                     var done: Boolean);

{ Raises a defense value for range. With a ranged weapon the band is (range - 1) div 3 steps; a defender more than one
  band away adds 2 and more than two bands away 3 more. A weapon of range 3 or less has a band of 0, so any distance
  adds both. Melee adds nothing.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(armorClass The defense value, raised in place.) }
procedure ApplyRangePenalty(attacker, defender: Types.PCharRecord; var armorClass: Byte);

{ Finds a Cure Light Wounds target in the creature's own cell or the eight around it. Candidates are the wounded ally
  with the fewest hit points (the creature itself, checked last, also wins whenever below half its maximum) and the last
  downed body, not dead, stoned or gone, found on a corpse cell. The body wins unless no body was found or the ally has
  7 hit points or fewer.
  @param(creature The caster.)
  @param(tgt Receives the target, or nil.)
  @returns(True if a target was found.) }
function FindCureTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;

{ Picks a spell's targets in combat, as the cast-target handler during combat, by the low nibble of the spell's area: 0
  the caster; 15 the picked creature (a bare cell gets an area of radius 0); 8 to 14 each creature within area and 7 of
  the picked cell; 1 to 7 (area and 3) + 1 picks of single creatures.
  @param(spell The spell.)
  @param(b True for the AI's choice.)
  @param(cast Receives True when targets were picked.) }
procedure SelectCombatTargets(spell: Byte; b: Boolean; var cast: Boolean);

{ Picks (from the spell menu, when no spell is given) and checks a spell, rejecting those not allowed in combat. A
  casting delay (the casting time div 3) of 0 casts it at once and ends the caster's actions; otherwise the caster
  'Begins Casting': the spell is recorded as being cast and initiative drops by the delay (to at least 1), so it
  resolves on a later action. Note: after an immediate cast, the result is the True of ending the caster's actions,
  whatever the cast itself reported.
  @param(spell The spell to cast, or 0 to choose one from the menu.)
  @param(ai 0 redraws the combat screen first; passed on to the cast as its computer-controlled flag.)
  @param(cast Set True when a spell was cast or begun, False otherwise.) }
procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);

{ Confirms an attack on an ally; enemies and quick-fighting attackers pass unasked. Yes sets the attacked-allies flags,
  each okay NPC turns hostile and drops its target, and the teams are recounted.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @returns(True when the attack goes ahead.) }
function CheckAttackAlly(attacker, defender: Types.PCharRecord): Boolean;

{ Runs target selection: cycling through the targets, manual aiming and confirmation; targets the creature may not
  attack are skipped.
  @param(creature The attacker.)
  @param(range The range in cells; 255 for the readied weapon's range less 1 (1 unarmed).)
  @param(weaponMode 1 for weapon attacks, 0 for spells.)
  @param(groundOk Nonzero to allow a bare cell.)
  @param(done Receives True when a target was taken.)
  @param(tgt Receives the target, a TAimTarget passed untyped.) }
procedure CombatAimMenu(creature: Types.PCharRecord; range, weaponMode, groundOk: Byte; var done: Boolean; var tgt);

{ Tells whether an attack is a backstab: a thief in leather or no armor, with a club, dagger, broad, long or short sword
  or no weapon, against a defender attacked more than once this round and facing away from it.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @returns(True for a backstab.) }
function IsBackstab(attacker, defender: Types.PCharRecord): Boolean;

{ Finds the first direction whose cone holds the other creature's cell.
  @param(creature The creature looking.)
  @param(other The creature looked at.)
  @returns(The direction, 0 to 7; 0 for the same cell.) }
function DirTowardTarget(creature, other: Types.PCharRecord): Byte;

{ Builds the missile icon for a weapon's type and flies it from the attacker to the defender between the ranged-attack
  sounds, with sound auto-stop off meanwhile.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @param(weapon The missile or thrown weapon.) }
procedure AnimateMissile(attacker, defender: Types.PCharRecord; weapon: Types.PItemRec);

{ Sets the hostiles' hit-point percentage: the enabled hostiles' current hit points as a percentage of the hostiles'
  combined maximum hit points, disabled ones included, rounded down to a multiple of five; it is left unchanged when
  there are no hostiles. Note: the totals are Words multiplied by 20, so above 3276 hit points the percentage wraps. }
procedure UpdateHostileHpPercent;

{ Finds the fastest enabled enemy's movement in whole steps, with no range or line-of-sight check.
  @param(creature The creature whose enemies are checked.)
  @returns(The highest enemy movement, in whole steps.) }
function HighestEnemyMovement(creature: Types.PCharRecord): Byte;

{ Makes sure a creature has a locked target. A lock is kept, without a range check, unless forceNew is set or the target
  is now an ally, disabled or forbidden by CanTarget. Otherwise it makes up to 20 random picks among the enemies in
  range, dropping forbidden ones; when that fails a second pass repeats it, with terrain no longer blocking unless
  forceNew, and there relaxed accepts a pick without CanTarget.
  @param(creature The creature.)
  @param(range The range in cells.)
  @param(relaxed Nonzero to accept a second-pass pick without CanTarget.)
  @param(forceNew Nonzero to drop the lock and keep terrain blocking.)
  @returns(True when the creature has a target.) }
function AcquireTarget(creature: Types.PCharRecord; range, relaxed, forceNew: Byte): Boolean;

{ Rakes with the rear claws, as the handler of the rear-claw effect: when both main attacks hit and the locked target is
  still up, two 2d4 secondary attacks follow, then the creature's actions end.
  @param(creature The creature.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure RearClawRake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Bites and holds, as the handler of the bite-hold effect. While the hold lasts, each trigger is one 3d4 bite on the
  victim as from behind, ending the creature's actions, and a victim that drops ends the hold. On removal, or when
  either side is down, the victim is freed and the hold is removed unless it is already being removed.
  @param(creature The creature.)
  @param(p The hold effect's node; its strength is the victim's combat slot.)
  @param(removed True when the effect is being removed.) }
procedure BiteAndHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Wins the battle by cheating, when the first command-line argument is STING: each hostile drops dead, each creature's
  actions end and the view is redrawn.
  @returns(True when the cheat worked.) }
function VictoryCheat: Boolean;

implementation

const
  { Sound-effect ids }
  SND_RANGED_START = 2;
  SND_MISS = 5;
  SND_RANGED_END = 8;

type
  { Target-selection result. }
  TAimTarget = record
    { the creature (nil = bare cell) }
    cr: Pointer;
    { Arena cell. }
    x: ShortInt;
    y: ShortInt;
    { reserved }
    yTail: Byte;
  end;
  TTurnLevel = (TurnLevel0, TurnLevel1, TurnLevel2, TurnLevel3, TurnLevel4, TurnLevel5, TurnLevel6, TurnLevel7,
                TurnLevel8, TurnLevel9, TurnLevel10, TurnLevel11, TurnLevel12, TurnLevel13);

procedure GuardersAttack(creature: Types.PCharRecord); forward;

procedure RollAttacks(att, def: Types.PCharRecord; fromBehind: Boolean; var done: Boolean); forward;

function SelectSpellTarget(spellId: Byte; aiControlled: Boolean; groundOk: Byte;
                           var target: TAimTarget): Boolean; forward;

function AimTargetMenu(cur, tgt: Types.PCharRecord; range, weaponMode, ground: Byte): Char; forward;

procedure ConfirmAttackTarget(cur, tgt: Types.PCharRecord; weaponMode: Byte; var done: Boolean;
                              var sel: TAimTarget); forward;

procedure ManualAimCursor(cur, underCursor: Types.PCharRecord; range, weaponMode, ground: Byte; var done: Boolean;
                          var sel: TAimTarget); forward;

procedure BeginRound(creature: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
  with creature^.combatAddr^ do begin
    spellCast := 0;
    castAllowed := 1;
    itemUseAllowed := 1;
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.RecalcAttacksLeft(creature);
    GDVars.attackOrMoveX2 := creature^.attacks2;
    GDVars.calculatingMovement := 0;
    FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
    creature^.curAttacks2 := CbtActs.AttacksFromRate(GDVars.attackOrMoveX2);
    sweepBudget := creature^.attackLevel;
    if creature^.enabled <> 0 then begin
      initiative := FxEngine.RollDice(1, 6) + CharHlp.DexMissileAdjust(creature);
      if initiative < 1 then
        initiative := 1;
      { Surprise mask: bit 0 for the party, bit 1 for monsters }
      if Byte((creature^.hostile + 1) and Integer(GDVars.zone1^[C_Gbvm.SURPRISE])) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then
        initiative := 0;
    end else
      initiative := 0;
  end;
  creature^.combatAddr^.movement := CbtActs.CalcCreatureMovement(creature);
end;

function CalcCreatureMovement(creature: Types.PCharRecord): Byte;
var
  movement: Byte;
begin
  movement := creature^.movementCur;
  if creature^.hostile = 0 then
    movement := movement + GDVars.zone1^[C_Gbvm.PARTY_MOVE_MODIFIER];
  GDVars.calculatingMovement := 1;
  if (movement < 1) or (movement > 96) then
    movement := 1;
  GDVars.attackOrMoveX2 := movement * 2;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
  GDVars.calculatingMovement := 0;
  CalcCreatureMovement := GDVars.attackOrMoveX2;
end;

procedure CalcWeaponDamage(attacker, defender: Types.PCharRecord; phase: Byte);
begin
  GDVars.pendingDamage := attacker^.curModA[phase]
      + FxEngine.RollDamageDice(attacker^.curRollsA[phase], attacker^.curDiceA[phase]);
  { pendingDamage is a Byte, so this test never holds }
  if GDVars.pendingDamage < 0 then
    GDVars.pendingDamage := 0;
  if CbtActs.IsBackstab(attacker, defender) then
    GDVars.pendingDamage := GDVars.pendingDamage * (attacker^.classLevels[C_Class.THIEF_LEVEL] div 4 + 2);
  GDVars.elementMask := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.WEAPON_DAMAGE_ATTACKER, attacker);
  FxEngine.TriggerEffectsWithCondition(C_Cond.WEAPON_DAMAGE_DEFENDER, defender);
end;

procedure ProcessAttackResult(attacker, defender: Types.PCharRecord; manner, damage, shownDamage: Byte; isHit: Boolean);
var
  row: Byte;
  message: String[80];
begin
  case manner of
    2: message := '-Backstabs-';
    3: message := 'slays helpless';
  else
    message := 'Attacks';
  end;
  CharHlp.PrintCreatureMessage(attacker, message, 10, False);
  row := 12;
  CharHlp.DisplayCreatureName(defender, 23, row, False);
  Inc(row);
  if manner = 1 then
    message := '(from behind) '
  else
    message := '';
  if isHit then begin
    if manner = 3 then
      message := 'with one cruel blow'
    else begin
      message := message + 'Hitting for ' + CharHlp.ByteToString(shownDamage);
      if shownDamage = 1 then
        message := message + ' point '
      else
        message := message + ' points ';
      message := message + 'of damage';
    end;
    CharHlp.InflictDamage(defender, damage);
  end else
    message := message + 'and Misses';
  TextRend.DisplayMessageWindow(23, row, 38, row + 3, LightGreen, True, message);
  row := GDVars.curRow + 1;
  if damage > 0 then begin
    defender^.combatAddr^.castAllowed := 0;
    if defender^.combatAddr^.spellCast > 0 then begin
      TextRend.PauseOnly;
      CharHlp.PrintCreatureMessage(defender, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(defender^.combatAddr^.spellCast);
      defender^.combatAddr^.spellCast := 0;
    end else
      TextRend.PauseOnly;
  end else
    TextRend.PauseOnly;
  if defender^.enabled = 0 then begin
    CharHlp.PrintCreatureMessage(defender, 'goes down', row, False);
    Inc(row, 2);
    if defender^.status = C_Status.DYING then
      TextRend.DisplayString(23, row, LightGreen, 'and is Dying');
    if defender^.status in [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE] then
      CharHlp.PrintCreatureMessage(defender, 'is killed', row, False);
    Inc(row, 2);
    FxEngine.RemoveEffectsHp0(defender);
    FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, defender);
    if defender^.enabled = 0 then
      CbtMap.CreatureDowned(defender)
    else
      TextRend.PauseOnly;
  end;
  CharHlp.ClearMessageWindow;
end;

{ Lets guarding enemies strike a creature that moved next to them: each adjacent enemy that is guarding and not helpless
  spends its guard on one free attack, while the mover stays up.
  @param(creature The creature that moved.) }
procedure GuardersAttack(creature: Types.PCharRecord);
var
  count: Byte;
  index: Byte;
  guarder: Types.PCharRecord;
  done: Boolean;
begin
  count := CharHlp.CountTargets(creature, 1);
  for index := 1 to count do
    if creature^.enabled <> 0 then begin
      guarder := GDVars.creatureArr[GDVars.potentialTargets[index]];
      if (guarder^.combatAddr^.guarding <> 0) and (not CharHlp.IsHelpless(guarder)) then begin
        CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2, C_Dir.CENTER);
        guarder^.combatAddr^.guarding := 0;
        CbtActs.NoteAttackDirection(guarder, creature);
        CbtActs.MakeAttack(guarder, creature, False, nil, done);
      end;
    end;
end;

procedure CombatMoveCreature(creature: Types.PCharRecord; direction: Byte);
var
  moveCost: Byte;
  slot: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
begin
  if Odd(direction) then
    moveCost := 3
  else
    moveCost := 2;
  if moveCost > creature^.combatAddr^.movement then begin
    creature^.combatAddr^.movement := 0;
    Exit;
  end;
  Dec(creature^.combatAddr^.movement, moveCost);
  slot := CbtMap.CombatSlot(creature);
  x := GDVars.arenaLoc[slot].x;
  y := GDVars.arenaLoc[slot].y;
  nx := x + GDConsts.dirDx[direction];
  ny := y + GDConsts.dirDy[direction];
  { moveCost is reused as the ScrollView delta: 1 under manual control, 3 under quickfight }
  moveCost := 1;
  if creature^.quickfight <> 0 then begin
    moveCost := 3;
    if not CbtMap.ViewCoordsValid(nx - GDVars.arenaPtr^.ox, ny - GDVars.arenaPtr^.oy) then
      CbtMap.ScrollView(x, y, 2, C_Dir.CENTER);
  end;
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  GDVars.arenaLoc[slot].x := nx;
  GDVars.arenaLoc[slot].y := ny;
  CbtMap.BuildArenaArrays;
  CbtMap.ScrollView(nx, ny, moveCost, C_Dir.CENTER);
  { flanking accumulators reset }
  creature^.combatAddr^.flankCount := 0;
  creature^.combatAddr^.flankSpread := 0;
  SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
  CbtActs.GuardersAttack(creature);
  if (creature^.enabled = 0) or CharHlp.IsHelpless(creature) then
    creature^.combatAddr^.movement := 0;
end;

procedure AttacksOfOpportunity(creature: Types.PCharRecord; direction: Byte);
var
  candidates: array[1..12] of Byte;
  effect: Types.PEffectRec;
  stillAdjacent: Boolean;
  attacked: Boolean;
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  candidateCount: Byte;
  countAfter: Byte;
  scanPos: Byte;
  index: Byte;
  phasePos: Byte;
  phase: Byte;
  facingScan: Byte;
  attacker: Types.PCharRecord;
  savedTarget: Types.PCharRecord;
begin
  FillChar(candidates, SizeOf(candidates), 0);
  slot := CbtMap.CombatSlot(creature);
  candidateCount := CharHlp.CountTargets(creature, 1);
  if candidateCount = 0 then
    Exit;
  for index := 1 to candidateCount do
    candidates[index] := GDVars.potentialTargets[index];
  { probe: step the icon, recount, step back }
  Inc(GDVars.arenaLoc[slot].x, GDConsts.dirDx[direction]);
  Inc(GDVars.arenaLoc[slot].y, GDConsts.dirDy[direction]);
  countAfter := CharHlp.CountTargets(creature, 1);
  Dec(GDVars.arenaLoc[slot].x, GDConsts.dirDx[direction]);
  Dec(GDVars.arenaLoc[slot].y, GDConsts.dirDy[direction]);
  { enemies still adjacent after the step get no free attack }
  for index := 1 to candidateCount do begin
    stillAdjacent := False;
    for scanPos := 1 to countAfter do
      if GDVars.potentialTargets[scanPos] = candidates[index] then
        stillAdjacent := True;
    if stillAdjacent then
      candidates[index] := 0;
  end;
  for index := 1 to candidateCount do
    if candidates[index] > 0 then
      if creature^.enabled <> 0 then begin
        attacked := False;
        attacker := GDVars.creatureArr[candidates[index]];
        if not CharHlp.IsHelpless(attacker) then
          if CbtActs.CanTarget(attacker, creature) then
            if not CharHlp.HasEffect(attacker, C_Effect.BLOOD_DRAIN, effect) then
              if not CharHlp.HasEffect(attacker, C_Effect.BITE_HOLD, effect) then
                for facingScan := attacker^.combatAddr^.direction + 6
                    to attacker^.combatAddr^.direction + 10 do
                  if not attacked then
                    if (attacker^.combatAddr^.initiative > 0)
                       or (attacker^.combatAddr^.flankCount = 0)
                       or
                         Pathing.IsDirToward(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker),
                                             CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                             facingScan mod 8) then begin
                      phase := 1;
                      if attacker^.attacks = 0 then
                        phase := 2;
                      { the two attack phases }
                      for phasePos := 1 to 2 do
                        if attacker^.curAttacksArr[phasePos] > 0 then
                          phase := phasePos;
                      if attacker^.curAttacksArr[phase] = 0 then
                        attacker^.curAttacksArr[phase] := 1;
                      attacker^.combatAddr^.attackPhase := phase;
                      savedTarget := attacker^.combatAddr^.other;
                      CbtActs.MakeAttack(attacker, creature, True, nil, GDVars.doneRoundFlag);
                      attacked := True;
                      attacker^.combatAddr^.other := savedTarget;
                      if creature^.enabled <> 0 then
                        CharHlp.CombatPrintCreatureInfo(creature);
                    end;
      end;
end;

function AttemptFlee(creature: Types.PCharRecord): Boolean;
var
  hasEscaped: Boolean;
  enemyMove: Byte;
  creatureMove: Byte;
begin
  hasEscaped := False;
  if CharHlp.CountTargets(creature, 255) = 0 then
    hasEscaped := True
  else begin
    creatureMove := CbtActs.CalcCreatureMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < creatureMove then
      hasEscaped := True
    else if enemyMove = creatureMove then
      if FxEngine.RollDice(1, 2) = 1 then
        hasEscaped := True;
  end;
  if hasEscaped then
    FxEngine.PutOutOfPlayWithStatus(creature, C_Status.RUNNING, 'Got Away')
  else
    CharHlp.PrintBottomLine('Escape is blocked');
  AttemptFlee := CharHlp.EndActions(creature);
end;

procedure RecalcAttacksLeft(creature: Types.PCharRecord);
var
  attacks: Byte;
  previous: Byte;
  ammoLimit: Byte;
  rate: Byte;
  ranged: Boolean;
  weapon: Types.PItemRec;
begin
  ranged := False;
  previous := creature^.curAttacks;
  creature^.curAttacks := creature^.attacks;
  if CharHlp.HasRangedWeapon(creature) and CharHlp.FindDamagingRangedWeapon(creature, weapon) then begin
    ranged := True;
    rate := GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].rateOfFire;
    if rate < 2 then
      rate := 2;
    GDVars.attackOrMoveX2 := rate;
  end else
    GDVars.attackOrMoveX2 := creature^.curAttacks;
  GDVars.calculatingMovement := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
  attacks := CbtActs.AttacksFromRate(GDVars.attackOrMoveX2);
  if ranged then
    if weapon <> nil then begin
      ammoLimit := 1;
      if weapon <> nil then
        if weapon^.quantity > ammoLimit then
          ammoLimit := weapon^.quantity;
      if ammoLimit < attacks then
        { ammo-limited }
        attacks := ammoLimit;
    end;
  if (creature^.combatAddr^.madeAttack = 0) or (attacks < previous)
     or ((creature^.combatAddr^.madeAttack <> 0) and (attacks < previous * 2) and (not ranged)) then
    creature^.curAttacks := attacks;
end;

function AttacksFromRate(rate: Byte): Byte;
var
  adjusted: Byte;
begin
  adjusted := rate;
  if Odd(GDVars.roundCounter) then
    Inc(adjusted);
  AttacksFromRate := adjusted div 2;
end;

function SweepAttack(att, def: Types.PCharRecord): Boolean;
var
  cnt: Byte;
  weak: Byte;
  i: Byte;
  defIdx: Byte;
  p: Types.PCharRecord;
begin
  SweepAttack := False;
  if att^.curAttacks >= att^.combatAddr^.sweepBudget then
    Exit;
  if def^.levelHighest <> 0 then
    Exit;
  if CharHlp.CalcDistance(att, def) <> 1 then
    Exit;
  cnt := CharHlp.CountTargets(att, 1);
  weak := 0;
  for i := 1 to cnt do begin
    p := GDVars.creatureArr[GDVars.potentialTargets[i]];
    if p = def then
      defIdx := i;
    if p^.levelHighest = 0 then
      Inc(weak);
  end;
  if weak <= att^.curAttacks then
    Exit;
  if weak > att^.combatAddr^.sweepBudget then
    weak := att^.combatAddr^.sweepBudget;
  CharHlp.PrintCreatureMessage(att, 'sweeps', 10, True);
  { def becomes the first sweep target }
  p := GDVars.creatureArr[GDVars.potentialTargets[1]];
  if p <> def then begin
    GDVars.potentialTargets[defIdx] := GDVars.potentialTargets[1];
    GDVars.potentialTargets[1] := CbtMap.CombatSlot(def);
  end;
  for i := 1 to cnt do
    if weak > 0 then
      if GDVars.creatureArr[GDVars.potentialTargets[i]]^.levelHighest = 0 then begin
        p := GDVars.creatureArr[GDVars.potentialTargets[i]];
        CbtActs.NoteAttackDirection(att, p);
        att^.curAttacks := 1;
        CbtActs.MakeAttack(att, p, False, nil, GDVars.doneRoundFlag);
        Dec(weak);
      end;
  SweepAttack := True;
end;

function CanTarget(attacker, target: Types.PCharRecord): Boolean;
var
  savedTarget: Types.PCharRecord;
begin
  CanTarget := False;
  if target = nil then
    Exit;
  if attacker = target then begin
    CanTarget := True;
    Exit;
  end;
  GDVars.suppressTargeting := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.TARGET_VETO, target);
  if GDVars.suppressTargeting = 0 then begin
    savedTarget := attacker^.combatAddr^.other;
    attacker^.combatAddr^.other := target;
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACKER_VETO, attacker);
    attacker^.combatAddr^.other := savedTarget;
  end;
  CanTarget := GDVars.suppressTargeting = 0;
end;

procedure CombatTurnUndead(creature: Types.PCharRecord);
var
  roll: Byte;
  affectedLeft: Byte;
  minimumLeft: Byte;
  needed: ShortInt;
  turnedAny: Boolean;
  stop: Boolean;
  target: Pointer;
  tableColumn: ShortInt;
begin
  CharHlp.PrintCreatureMessage(creature, 'turns undead...', 10, False);
  MenuCore.ClearBottomLine;
  TextRend.PauseOnly;
  turnedAny := False;
  stop := False;
  creature^.combatAddr^.usedTurnUndead := 1;
  minimumLeft := 6;
  affectedLeft := FxEngine.RollDice(1, 12);
  roll := FxEngine.RollDice(1, 20);
  case TTurnLevel(creature^.classLevels[C_Class.CLERIC_LEVEL]) of
    TurnLevel1..TurnLevel8: tableColumn := creature^.classLevels[C_Class.CLERIC_LEVEL];
    TurnLevel9..TurnLevel13: tableColumn := 9;
  else
    tableColumn := 10;
  end;
  while CbtActs.FindTurnUndeadTarget(creature, target) and (affectedLeft > 0)
        and (stop = False) do begin
    needed := GDConsts.turnTable[Types.PCharRecord(target)^.levelUndead, tableColumn];
    if roll >= Abs(needed) then begin
      turnedAny := True;
      CbtMap.DisplayMapViewCentered(Types.PCharRecord(target), 3, False);
      CharHlp.CombatPrintCreatureInfo(Types.PCharRecord(target));
      if needed > 0 then begin
        Types.PCharRecord(target)^.combatAddr^.turned := 1;
        CharHlp.PrintNameStringAnim(Types.PCharRecord(target), True, 'is turned');
      end else begin
        CharHlp.PrintCreatureMessage(Types.PCharRecord(target), 'Is destroyed', 10, False);
        CbtMap.CreatureDowned(Types.PCharRecord(target));
        Types.PCharRecord(target)^.status := C_Status.GONE;
        Types.PCharRecord(target)^.enabled := 0;
      end;
      if minimumLeft > 0 then
        Dec(minimumLeft);
      Dec(affectedLeft);
      if affectedLeft = 0 then
        if minimumLeft > 0 then
          if needed < 0 then
            { extend while below six successes }
            Inc(affectedLeft);
      CharHlp.ClearMessageWindow;
    end else
      stop := True;
  end;
  if not turnedAny then
    CharHlp.PrintBottomLine('Nothing Happens...');
  CharHlp.CountTeams;
  GDVars.doneRoundFlag := CharHlp.EndActions(creature);
  CharHlp.ClearMessageWindow;
end;

function FindTurnUndeadTarget(creature: Types.PCharRecord; var target: Pointer): Boolean;
var
  count: Byte;
  index: Byte;
  bestLevel: ShortInt;
  candidate: Types.PCharRecord;
begin
  bestLevel := 13;
  target := nil;
  count := CharHlp.CountTargets(creature, 255);
  FindTurnUndeadTarget := False;
  for index := 1 to count do begin
    candidate := GDVars.creatureArr[GDVars.potentialTargets[index]];
    if (candidate^.combatAddr^.turned = 0) and (candidate^.levelUndead > 0)
       and (candidate^.levelUndead < bestLevel) then begin
      bestLevel := candidate^.levelUndead;
      target := candidate;
      FindTurnUndeadTarget := True;
    end;
  end;
end;

{ Resolves an attacker's remaining attacks on a defender. A helpless defender is slain with one blow and each attack is
  spent. Otherwise the large-target dice apply against a large defender, and the defense is the rear armor class less 2
  for a backstab, or the rear armor class from behind (fromBehind, or flanked by more than one attacker with the
  attacker at its back and a flank spread above 4). Range penalties are added and the attacks rolled from the attack
  phase down to 1 until the defender drops; the sweep budget is spent.
  @param(att The attacker.)
  @param(def The defender.)
  @param(fromBehind True for an attack from behind.)
  @param(done Receives True when the attacker has no attacks left, which ends its actions.) }
procedure RollAttacks(att, def: Types.PCharRecord; fromBehind: Boolean; var done: Boolean);
var
  base: Types.TBaseItemRec;
  anyHit: Boolean;
  defDowned: Boolean;
  behind: Boolean;
  defense: Byte;
  phase: Byte;
  startPhase: Byte;
  atkType: Byte;
  behindIdx: ShortInt;
begin
  behind := fromBehind;
  done := False;
  GDVars.hitsMade[1] := 0;
  GDVars.hitsMade[2] := 0;
  GDVars.attacksMade[1] := 0;
  GDVars.attacksMade[2] := 0;
  anyHit := False;
  defDowned := False;
  GDVars.pendingDamage := 0;
  att^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(def) then begin
    SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.IMPACT]);
    while att^.curAttacksArr[att^.combatAddr^.attackPhase] = 0 do
      { may run below the array bound }
      Dec(att^.combatAddr^.attackPhase);
    Inc(GDVars.attacksMade[att^.combatAddr^.attackPhase]);
    CbtActs.ProcessAttackResult(att, def, 3, def^.hpCur + 5, 1, True);
    FxEngine.RemoveInvisibility(att);
    { the two attack phases }
    for phase := 1 to 2 do
      att^.curAttacksArr[phase] := 0;
    anyHit := True;
    done := True;
  end else begin
    if (att^.equipped[C_Equip.WEAPON] <> nil)
       and ((def^.iconDimensions > $80) or (def^.iconDimensions and 7 > 1)) then begin
      { large target: swap in the large-damage dice }
      base := GDVars.baseItems[att^.equipped[C_Equip.WEAPON]^.itemType];
      att^.curRollsA[1] := base.dmgLgRolls;
      att^.curDiceA[1] := base.dmgLgDice;
      att^.curModA[1] := att^.curModA[1] - base.dmgSmMod
          + base.dmgLgMod;
    end;
    CharHlp.RecalcStats(def);
    FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, def);
    behindIdx := 0;
    if CbtActs.IsBackstab(att, def) then
      defense := def^.acBehind - 2
    else begin
      if def^.combatAddr^.flankCount > 1 then
        if (CbtActs.DirTowardTarget(att, def) = def^.combatAddr^.direction)
           and (def^.combatAddr^.flankSpread > 4) then
          behind := True;
      if behind then
        behindIdx := 1;
      defense := def^.acCurArr[behindIdx];
    end;
    CbtActs.ApplyRangePenalty(att, def, defense);
    atkType := 0;
    if behind then
      atkType := 1;
    if CbtActs.IsBackstab(att, def) then
      atkType := 2;
    startPhase := att^.combatAddr^.attackPhase;
    { the downto's own entry guard covers startPhase < 1 }
    for phase := startPhase downto 1 do
      while (att^.curAttacksArr[phase] > 0)
            and (defDowned = False) do begin
        Dec(att^.curAttacksArr[phase]);
        att^.combatAddr^.attackPhase := phase;
        Inc(GDVars.attacksMade[phase]);
        if FxEngine.AttackRoll(att, def, defense) or CharHlp.IsHelpless(def) then begin
          Inc(GDVars.hitsMade[phase]);
          SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.IMPACT]);
          anyHit := True;
          CbtActs.CalcWeaponDamage(att, def, phase);
          CbtActs.ProcessAttackResult(att, def, atkType, GDVars.pendingDamage, GDVars.pendingDamage, True);
          if def^.enabled <> 0 then
            { COND_HIT_PHASE_1/2 }
            FxEngine.TriggerEffectsWithCondition(phase + 1, att);
          if def^.enabled = 0 then
            defDowned := True;
        end;
      end;
    if not anyHit then begin
      SoundDrv.SoundCommand(GDConsts.soundIds.combat[CbtActs.SND_MISS]);
      CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
    end;
    done := True;
    { the two attack phases }
    for phase := 1 to 2 do
      if att^.curAttacksArr[phase] > 0 then
        done := False;
    { sweep budget spent }
    att^.combatAddr^.sweepBudget := 0;
  end;
  if done then
    done := CharHlp.EndActions(att);
end;

procedure NoteAttackDirection(attacker, defender: Types.PCharRecord);
var
  angle: Byte;
  attackDirection: Byte;
begin
  Inc(defender^.combatAddr^.flankCount);
  attackDirection := CbtActs.DirTowardTarget(defender, attacker);
  angle := (attackDirection - defender^.combatAddr^.direction + 8) mod 8;
  if angle > 4 then
    angle := 8 - angle;
  defender^.combatAddr^.flankSpread := (defender^.combatAddr^.flankSpread + angle) mod 8;
end;

procedure MakeAttack(attacker, defender: Types.PCharRecord; fromBehind: Boolean; weapon: Types.PItemRec;
                     var done: Boolean);
var
  thrownCopy: Types.PItemRec;
  savedCharacter: Types.PCharRecord;
  direction: Byte;
begin
  if (defender^.combatAddr^.flankCount < 3) and (not fromBehind) then begin
    direction := CbtActs.DirTowardTarget(defender, attacker);
    if CbtMap.CombatIconVisible(defender, 0) then
      CbtMap.SetCreatureFacing(defender, direction, 0, 0)
    else
      defender^.combatAddr^.direction := direction;
  end;
  direction := CbtActs.DirTowardTarget(attacker, defender);
  CharHlp.CombatPrintCreatureInfo(attacker);
  CbtMap.SetCreatureFacing(attacker, direction, 1, 0);
  attacker^.combatAddr^.other := defender;
  Delay(100);
  if weapon <> nil then
    CbtActs.AnimateMissile(attacker, defender, weapon);
  { Note: no nil check on the equipped weapon. Base item 47 is the sling. }
  if attacker^.equipped[C_Equip.WEAPON]^.itemType = 47 then
    CbtActs.AnimateMissile(attacker, defender, attacker^.equipped[C_Equip.WEAPON]);
  done := True;
  if (attacker^.curAttacks > 0) or (attacker^.curAttacks2 > 0) then begin
    savedCharacter := GDVars.curChar;
    GDVars.curChar := attacker;
    CbtActs.RollAttacks(attacker, defender, fromBehind, done);
    if weapon <> nil then begin
      if weapon^.quantity > 0 then
        Dec(weapon^.quantity, GDVars.attacksMade[1]);
      if weapon^.quantity = 0 then
        if CharHlp.HasThrowableWeapon(attacker) and (weapon^.special <> C_Effect.SPIRITUAL_HAMMER_GONE) then begin
          { the expended thrown weapon drops into the loot pile }
          GetMem(thrownCopy, SizeOf(Types.TItemRec));
          Move(weapon^, thrownCopy^, SizeOf(Types.TItemRec));
          thrownCopy^.next := GDVars.treasureItems;
          GDVars.treasureItems := thrownCopy;
          thrownCopy^.equipped := 0;
          CharHlp.RemoveItem(attacker, weapon);
          GDVars.lastMissileItem := thrownCopy;
        end else
          CharHlp.RemoveItem(attacker, weapon);
    end;
    CharHlp.RecalcStats(attacker);
    GDVars.curChar := savedCharacter;
  end;
  if done then
    done := CharHlp.EndActions(attacker);
  if CbtMap.CombatIconVisible(attacker, 0) then begin
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 1, 1);
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 0, 0);
  end;
end;

procedure ApplyRangePenalty(attacker, defender: Types.PCharRecord; var armorClass: Byte);
var
  band: ShortInt;
  distance: ShortInt;
begin
  distance := CharHlp.CalcDistance(attacker, defender);
  if CharHlp.HasRangedWeapon(attacker) then
    band := (GDVars.baseItems[attacker^.equipped[C_Equip.WEAPON]^.itemType].range - 1)
        div 3
  else
    band := distance;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 2;
  end;
  if distance - band > 0 then begin
    distance := distance - band;
    { cumulative with the first +2 }
    armorClass := armorClass + 3;
  end;
end;

function FindCureTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;
var
  best: Pointer;
  nx: ShortInt;
  ny: ShortInt;
  downIdx: Byte;
  bestHp: Byte;
  d: Byte;
  j: Byte;
  crIdx: Byte;
  terrIdx: Byte;
begin
  best := nil;
  downIdx := 0;
  bestHp := 255;
  { 8 = CENTER; own cell included }
  for d := 0 to 8 do begin
    nx := CbtMap.CombatCellX(creature) + GDConsts.dirDx[d];
    ny := CbtMap.CombatCellY(creature) + GDConsts.dirDy[d];
    CbtMap.GetArenaContents(nx, ny, crIdx, terrIdx);
    if crIdx > 0 then begin
      { the var param is the scratch }
      tgt := GDVars.creatureArr[crIdx];
      if Types.PCharRecord(tgt)^.hostile = creature^.hostile then
        if Types.PCharRecord(tgt)^.hpCur < Types.PCharRecord(tgt)^.hpMax then
          if (Types.PCharRecord(tgt)^.hpCur < bestHp)
             or ((tgt = creature) and (Types.PCharRecord(tgt)^.hpCur < Types.PCharRecord(tgt)^.hpMax div 2)) then begin
            best := tgt;
            bestHp := Types.PCharRecord(tgt)^.hpCur;
          end;
    end else if terrIdx = C_Terr.TERRAIN_CORPSE then
      for j := 1 to GDVars.downedCount do
        if GDVars.downed[j].cr <> nil then
          if not (GDVars.downed[j].cr^.status in
                  [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE]) then
            if GDVars.downed[j].x = nx then
              if GDVars.downed[j].y = ny then
                downIdx := j;
  end;
  if (bestHp < 8) or (downIdx = 0) then
    tgt := best
  else
    tgt := GDVars.downed[downIdx].cr;
  if tgt <> nil then
    FindCureTarget := True
  else
    FindCureTarget := False;
end;

{ Picks one spell target. Under manual control the aim menu picks it in spell mode and it becomes the locked target.
  Under the AI a spell that is not offensive targets the caster (Cure Light Wounds the cure target); an offensive one
  makes up to 20 AcquireTarget picks, refusing one with a non-enemy within the spell's AI radius, or one already
  helpless when the spell's effect makes it helpless. Success sets targetX and targetY.
  @param(spellId The spell.)
  @param(aiControlled True for the AI's choice.)
  @param(groundOk 1 to allow a bare cell.)
  @param(target Receives the target; cleared on failure.)
  @returns(True when a target was picked.) }
function SelectSpellTarget(spellId: Byte; aiControlled: Boolean; groundOk: Byte; var target: TAimTarget): Boolean;
var
  found: Boolean;
  acceptable: Boolean;
  candidate: Types.PCharRecord;
  i: Byte;
  tries: Byte;
begin
  found := False;
  if not aiControlled then begin
    CbtActs.CombatAimMenu(GDVars.curChar, Magic.CalcSpellRange(spellId), 0, groundOk, found, target);
    GDVars.curChar^.combatAddr^.other := target.cr;
  end else begin
    if GDConsts.spellTable[spellId].offensive = 0 then begin
      target.cr := GDVars.curChar;
      if (spellId <> C_Spell.CURE_LIGHT_WOUNDS) or CbtActs.FindCureTarget(GDVars.curChar, target.cr) then begin
        target.x := CbtMap.CombatCellX(target.cr);
        target.y := CbtMap.CombatCellY(target.cr);
        found := True;
      end;
    end else begin
      tries := 20;
      while (tries > 0) and (found = False) do begin
        acceptable := True;
        if CbtActs.AcquireTarget(GDVars.curChar, Magic.CalcSpellRange(spellId), 0, 1) then begin
          candidate := GDVars.curChar^.combatAddr^.other;
          if GDConsts.spellTable[spellId].aiRadius > 0 then begin
            Pathing.BuildTargetList(CbtMap.CombatCellX(candidate), CbtMap.CombatCellY(candidate),
                                    GDConsts.spellTable[spellId].aiRadius, 255, 1, GDVars.arenaPtr);
            for i := 1 to GDVars.targetCount do
              if GDVars.creatureArr[GDVars.targetList[i].idx]^.hostile
                 <> CharHlp.EnemyTeam(GDVars.curChar) then
                acceptable := False;
          end;
          if CharHlp.IsHelpless(candidate) then
            { 4 is the last index of helplessFx }
            for i := 1 to 4 do
              if GDConsts.spellTable[spellId].effect = GDConsts.helplessFx[i] then
                acceptable := False;
          if acceptable then begin
            target.cr := GDVars.curChar^.combatAddr^.other;
            target.x := CbtMap.CombatCellX(target.cr);
            target.y := CbtMap.CombatCellY(target.cr);
            found := True;
          end;
        end;
        Dec(tries);
      end;
    end;
  end;
  if found then begin
    SelectSpellTarget := True;
    GDVars.targetX := target.x;
    GDVars.targetY := target.y;
  end else begin
    SelectSpellTarget := False;
    FillChar(target, SizeOf(target), 0);
  end;
end;

procedure SelectCombatTargets(spell: Byte; b: Boolean; var cast: Boolean);
var
  remaining: Byte;
  k: Byte;
  j: Byte;
  sel: TAimTarget;
  dup: Boolean;
begin
  cast := True;
  GDVars.spellTargetCount := 0;
  GDVars.multiTarget := 0;
  GDVars.targetX := CbtMap.CombatCellX(GDVars.curChar);
  GDVars.targetY := CbtMap.CombatCellY(GDVars.curChar);
  case GDConsts.spellTable[spell].area and $F of
    0:
      { self only }
      begin
        GDVars.spellTargets[1] := GDVars.curChar;
        GDVars.spellTargetCount := 1;
      end;
    15:
      { the picked creature, or an area at the picked cell }
      begin
        if CbtActs.SelectSpellTarget(spell, b, 0, sel) then begin
          if GDVars.curChar^.combatAddr^.other <> nil then begin
            GDVars.spellTargets[1] := GDVars.curChar^.combatAddr^.other;
            GDVars.spellTargetCount := 1;
          end else begin
            { (area and $F) shr 4 is always 0: a zero radius }
            Pathing.BuildTargetList(GDVars.targetX, GDVars.targetY,
                                    (GDConsts.spellTable[spell].area and $F) shr 4, 255, 1, GDVars.arenaPtr);
            for k := 1 to GDVars.targetCount do
              GDVars.spellTargets[k] := GDVars.creatureArr[GDVars.targetList[k].idx];
            GDVars.spellTargetCount := GDVars.targetCount;
            GDVars.multiTarget := 1;
          end;
        end else
          cast := False;
      end;
    8..14:
      { fixed radius, ground OK }
      begin
        if CbtActs.SelectSpellTarget(spell, b, 1, sel) then begin
          Pathing.BuildTargetList(GDVars.targetX, GDVars.targetY, GDConsts.spellTable[spell].area and 7, 255, 1,
                                  GDVars.arenaPtr);
          for k := 1 to GDVars.targetCount do
            GDVars.spellTargets[k] := GDVars.creatureArr[GDVars.targetList[k].idx];
          GDVars.spellTargetCount := GDVars.targetCount;
          GDVars.multiTarget := 1;
        end else
          cast := False;
      end;
  else
    { 1..7: (area and 3) + 1 individual targets }
    begin
      remaining := (GDConsts.spellTable[spell].area and 3) + 1;
      k := 0;
      while remaining > 0 do begin
        if CbtActs.SelectSpellTarget(spell, b, 0, sel) then begin
          dup := False;
          for j := 1 to k do
            if GDVars.spellTargets[j] = sel.cr then
              dup := True;
          if not dup then begin
            Inc(k);
            GDVars.spellTargets[k] := sel.cr;
            Dec(remaining);
          end else if not b then
            CharHlp.PrintBottomLine('Already been targeted')
          else
            Dec(remaining);
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(GDVars.spellTargets[k]),
                                 CbtMap.CombatCellY(GDVars.spellTargets[k]));
        end else
          Dec(remaining);
      end;
      GDVars.spellTargetCount := k;
      if k = 0 then
        cast := False;
    end;
  end;
end;

procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);
var
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  castTime: Byte;
  idx: Integer;
  notEmpty: Boolean;
  caster: Types.PCharRecord;
begin
  caster := GDVars.curChar;
  notEmpty := True;
  idx := -1;
  cast := False;
  spellId := spell;
  if spellId = C_Spell.NO_SPELL then
    spellId := ViewChar.SpellMenu(0, 1, idx, notEmpty);
  if spellId > C_Spell.NO_SPELL then
    if GDConsts.spellTable[spellId].whenCast = 0 then begin
      CharHlp.PrintBottomLine('Camp Only Spell');
      spellId := C_Spell.NO_SPELL;
    end;
  if ai = 0 then begin
    CharHlp.DisplayCombatInterface;
    CbtMap.DisplayMapViewCentered(caster, 3, True);
    CharHlp.CombatPrintCreatureInfo(caster);
  end;
  if spellId > C_Spell.NO_SPELL then begin
    castTime := GDConsts.spellTable[spellId].castTime div 3;
    if castTime = 0 then begin
      Magic.CastSpell(spellId, Boolean(ai), True, cast);
      cast := CharHlp.EndActions(caster);
    end else begin
      cast := True;
      CharHlp.PrintCreatureMessage(caster, 'Begins Casting', 10, True);
      caster^.combatAddr^.spellCast := spellId;
      if caster^.combatAddr^.initiative > castTime then
        Dec(caster^.combatAddr^.initiative, castTime)
      else
        caster^.combatAddr^.initiative := 1;
    end;
  end;
end;

function IsBackstab(attacker, defender: Types.PCharRecord): Boolean;
var
  weapon: Types.PItemRec;
  armor: Types.PItemRec;
  weaponType: Byte;
  canBackstab: Boolean;
begin
  canBackstab := False;
  weapon := attacker^.equipped[C_Equip.WEAPON];
  if weapon <> nil then
    weaponType := weapon^.itemType;
  armor := attacker^.equipped[C_Equip.ARMOR];
  if attacker^.classLevels[C_Class.THIEF_LEVEL] > 0 then
    { base item 50, Leather Armor }
    if (armor = nil) or (armor^.itemType = 50) then
      { Club, Dagger }
      if (weapon = nil) or (weaponType = 7) or (weaponType = 8)
         { 35..37 = Broad/Long/Short Sword }
         or ((weaponType > 34) and (weaponType < 38)) then
        canBackstab := True;
  if canBackstab and (defender^.combatAddr^.flankCount > 1)
     and (CbtActs.DirTowardTarget(attacker, defender) = defender^.combatAddr^.direction) then
    IsBackstab := True
  else
    IsBackstab := False;
end;

function DirTowardTarget(creature, other: Types.PCharRecord): Byte;
var
  dir: Byte;
  x1: ShortInt;
  y1: ShortInt;
  x2: ShortInt;
  y2: ShortInt;
begin
  x1 := CbtMap.CombatCellX(creature);
  y1 := CbtMap.CombatCellY(creature);
  x2 := CbtMap.CombatCellX(other);
  y2 := CbtMap.CombatCellY(other);
  dir := 0;
  while not Pathing.IsDirToward(x1, y1, x2, y2, dir) do
    Inc(dir);
  DirTowardTarget := dir;
end;

procedure AnimateMissile(attacker, defender: Types.PCharRecord; weapon: Types.PItemRec);
var
  missileCellBase: Byte;
  frames: Byte;
  direction: Byte;
  pace: Byte;
  imageSize: Word;
begin
  direction := CbtActs.DirTowardTarget(attacker, defender);
  frames := 1;
  pace := 10;
  missileCellBase := 13;
  imageSize := GDVars.moveIconSheet^.imgSize;
  if GDVars.videoMode = Types.Ega then
    imageSize := imageSize div 4;
  case weapon^.itemType of
    { straight-flying missiles: Dart, Javelin, Quarrel, Spear and Arrow }
    9, 21, 28, 31, 73:
      if Odd(direction) then begin
        if (direction = C_Dir.SOUTHEAST) or (direction = C_Dir.SOUTHWEST) then
          CharHlp.CopyIconFacing(missileCellBase + 1, 1, 0, direction = C_Dir.SOUTHWEST)
        else
          CharHlp.CopyIconFacing(missileCellBase + 1, 0, 0, direction = C_Dir.NORTHWEST);
      end else
        CharHlp.CopyIconFacing(missileCellBase + direction mod 4, direction div 4, 0, False);
    { spinning thrown weapons: Hand Axe, Club, Hammer }
    2, 7, C_Item.HAMMER:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 3);
        frames := 4;
        pace := 50;
      end;
    { holy water / oil flask }
    C_Item.HOLY_WATER_VIAL, C_Item.FLASK_OF_OIL:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 4);
        frames := 4;
        pace := 50;
      end;
  else begin
      { base item 47, Sling }
      if weapon^.itemType = 47 then
        Inc(missileCellBase);
      CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, False);
      CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, False);
      frames := 2;
      pace := 20;
    end;
  end;
  SoundDrv.SoundSetAutoStop(0);
  SoundDrv.SoundCommand(GDConsts.soundIds.combat[CbtActs.SND_RANGED_START]);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker),
                                  CbtMap.CombatCellX(defender), CbtMap.CombatCellY(defender), frames, pace);
  SoundDrv.SoundCommand(GDConsts.soundIds.combat[CbtActs.SND_RANGED_END]);
  SoundDrv.SoundSetAutoStop(10);
end;

procedure UpdateHostileHpPercent;
var
  maximumTotal: Word;
  hitPointTotal: Word;
  combatant: Types.PCharRecord;
begin
  maximumTotal := 0;
  hitPointTotal := 0;
  combatant := GDVars.creatureList;
  while combatant <> nil do begin
    if combatant^.hostile = 1 then begin
      if combatant^.enabled <> 0 then
        hitPointTotal := hitPointTotal + combatant^.hpCur;
      maximumTotal := maximumTotal + combatant^.hpMax;
    end;
    combatant := combatant^.nextCharAddr;
  end;
  if maximumTotal > 0 then
    GDVars.hostileHpPct := hitPointTotal * 20 div maximumTotal * 5;
end;

function HighestEnemyMovement(creature: Types.PCharRecord): Byte;
var
  highest: Byte;
  movement: Byte;
  combatant: Types.PCharRecord;
begin
  highest := 0;
  combatant := GDVars.creatureList;
  while combatant <> nil do begin
    if (CharHlp.EnemyTeam(creature) = combatant^.hostile) and (combatant^.enabled <> 0) then begin
      movement := CbtActs.CalcCreatureMovement(combatant) div 2;
      if movement > highest then
        highest := movement;
    end;
    combatant := combatant^.nextCharAddr;
  end;
  HighestEnemyMovement := highest;
end;

function CheckAttackAlly(attacker, defender: Types.PCharRecord): Boolean;
var
  combatant: Types.PCharRecord;
begin
  if (CharHlp.EnemyTeam(defender) = attacker^.hostile) or (attacker^.quickfight <> 0) then
    CheckAttackAlly := True
  else if MenuCore.YesNoMenu('Attack Ally: ', LightMagenta, LightGreen, White) <> 'Y' then
    CheckAttackAlly := False
  else begin
    CheckAttackAlly := True;
    GDVars.attackedAllies := 1;
    GDVars.zone1^[C_Gbvm.ATTACKED_ALLIES] := 1;
    combatant := GDVars.creatureList;
    while combatant <> nil do begin
      { NPC flag (high bit) set }
      if (combatant^.status = C_Status.OKAY) and (combatant^.npc > $7F) then begin
        combatant^.hostile := 1;
        combatant^.combatAddr^.other := nil;
      end;
      combatant := combatant^.nextCharAddr;
    end;
    CharHlp.CountTeams;
  end;
end;

{ Runs one round of the aim menu on a target: the view centers on it, the range shows in weapon mode, and Target is
  offered when it is in range (a weapon attack needs another creature, and a ranged weapon damaging ammunition and
  either no enemy beside the attacker or a throwable weapon), with Next, Prev, Manual, Center and Exit.
  @param(cur The attacker.)
  @param(tgt The target.)
  @param(range The range in cells.)
  @param(weaponMode 1 for a weapon attack, 0 for a spell.)
  @param(ground Unused.)
  @returns(The menu key.) }
function AimTargetMenu(cur, tgt: Types.PCharRecord; range, weaponMode, ground: Byte): Char;
var
  menu: String[40];
  ext: Boolean;
  weapon: Types.PItemRec;
  dist: Byte;
  { Unused in this version; see the other implementations of this routine. }
  dir: Byte;
begin
  menu := '';
  dist := CharHlp.CalcDistance(cur, tgt);
  dir := CbtActs.DirTowardTarget(cur, tgt);
  if weaponMode <> 0 then
    TextRend.DisplayString(0, 23, LightGreen, 'Range = ' + CharHlp.ByteToString(dist) + '  ');
  if dist <= range then begin
    if weaponMode = 0 then
      menu := 'Target '
    else if cur <> tgt then begin
      if not CharHlp.HasRangedWeapon(cur) then
        menu := 'Target '
      else if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
        if (CharHlp.CountTargets(cur, 1) = 0) or CharHlp.HasThrowableWeapon(cur) then
          menu := 'Target ';
    end;
  end;
  menu := 'Next Prev Manual ' + menu + 'Center Exit';
  CbtMap.DisplayMapViewCentered(tgt, 3, True);
  CharHlp.CombatPrintCreatureInfo(tgt);
  AimTargetMenu := MenuCore.MenuHorizontal('Aim:', menu, LightMagenta, LightGreen, White, False, False,
                                           ext);
end;

{ Confirms an aim selection: weapon mode 1 makes a weapon attack, anything else selects a spell target. A weapon attack
  on an ally needs CheckAttackAlly's consent, otherwise the selection is cleared and the done flag is False. The attack
  tries a sweep first; a throwable ranged weapon used at distance 1 strikes as melee.
  @param(cur The creature aiming.)
  @param(tgt The creature chosen.)
  @param(weaponMode 1 for a weapon attack.)
  @param(done False when the attack was declined; otherwise True or the attack's result.)
  @param(sel Receives the target and its cell; cleared when declined.) }
procedure ConfirmAttackTarget(cur, tgt: Types.PCharRecord; weaponMode: Byte; var done: Boolean;
                              var sel: TAimTarget);
var
  { Unused in this version; see the other implementations of this routine. }
  targetDir: Byte;
  weapon: Types.PItemRec;
begin
  weapon := nil;
  done := True;
  if weaponMode = 1 then
    if not CbtActs.CheckAttackAlly(cur, tgt) then
      done := False;
  if done then begin
    sel.cr := tgt;
    sel.x := CbtMap.CombatCellX(tgt);
    sel.y := CbtMap.CombatCellY(tgt);
    GDVars.arenaPtr^.cursorOn := False;
    CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 3, C_Dir.CENTER);
    if weaponMode = 1 then begin
      if CbtActs.SweepAttack(cur, tgt) then
        done := CharHlp.EndActions(cur)
      else begin
        CbtActs.NoteAttackDirection(cur, tgt);
        if CharHlp.HasRangedWeapon(cur) then
          if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
            if CharHlp.HasThrowableWeapon(cur) then
              if CharHlp.CalcDistance(cur, tgt) = 1 then
                weapon := nil;
        CbtActs.MakeAttack(cur, tgt, False, weapon, done);
      end;
    end;
  end else
    FillChar(sel, SizeOf(sel), 0);
end;

{ Runs the free aiming cursor: the direction keys move a cell cursor, kept inside the arena, from a creature's cell; the
  line of sight and the range are checked, and Target or Enter takes a valid cell (a weapon attack goes through
  ConfirmAttackTarget); Center centers the view and Exit or Escape gives up. A bare cell is valid only when ground is
  set.
  @param(cur The attacker.)
  @param(underCursor The creature the cursor starts on.)
  @param(range The range in cells.)
  @param(weaponMode 1 for a weapon attack, 0 for a spell.)
  @param(ground Nonzero to allow a bare cell.)
  @param(done Receives True when a target was taken.)
  @param(sel Receives the target; cleared when none.) }
procedure ManualAimCursor(cur, underCursor: Types.PCharRecord; range, weaponMode, ground: Byte; var done: Boolean;
                          var sel: TAimTarget);
var
  menu: String[40];
  ch: Char;
  weapon: Types.PItemRec;
  dir: Byte;
  j: Byte;
  wx: ShortInt;
  wy: ShortInt;
  cx: ShortInt;
  cy: ShortInt;
  crIdx: Byte;
  terrIdx: Byte;
  dist: Word;
  valid: Boolean;
begin
  FillChar(sel, SizeOf(sel), 0);
  cx := CbtMap.CombatCellX(underCursor);
  cy := CbtMap.CombatCellY(underCursor);
  ch := ' ';
  dir := C_Dir.CENTER;
  done := False;
  GDVars.arenaPtr^.cursorOn := True;
  GDVars.arenaPtr^.cursorSize := 1;
  while not (ch in [C_Keys.NONE, C_Keys.ENTER, 'E', 'T']) do
  begin
    CbtMap.ScrollView(cx, cy, 3, dir);
    Inc(cx, GDConsts.dirDx[dir]);
    Inc(cy, GDConsts.dirDy[dir]);
    if cx < 0 then
      cx := 0;
    if cy < 0 then
      cy := 0;
    if cx > 49 then
      cx := 49;
    if cy > 24 then
      cy := 24;
    CbtMap.GetArenaContents(cx, cy, crIdx, terrIdx);
    GameIo.DiscardPendingKeys;
    valid := False;
    dist := 255;
    wx := cx;
    wy := cy;
    if Pathing.WalkLine(CbtMap.CombatCellX(cur), CbtMap.CombatCellY(cur), wx, wy, dist, GDVars.arenaPtr) then begin
      valid := True;
      if weaponMode <> 0 then
        TextRend.DisplayString(0, 23, LightGreen, 'Range = ' + CharHlp.WordToString(dist div 2) + '  ');
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    dist := dist div 2;
    underCursor := nil;
    if valid then begin
      if crIdx > 0 then
        underCursor := GDVars.creatureArr[crIdx]
      else if terrIdx = C_Terr.TERRAIN_CORPSE then
        for j := 1 to GDVars.downedCount do
          if GDVars.downed[j].x = cx then
            if GDVars.downed[j].y = cy then
              underCursor := GDVars.downed[j].cr;
    end;
    if underCursor <> nil then
      CharHlp.CombatPrintCreatureInfo(underCursor)
    else
      Border.ClearBox(23, 1, 38, 21);
    if (range < dist) or (GDConsts.terrainInfo[terrIdx].cost = 255) then
      valid := False;
    if underCursor <> nil then begin
      if not CbtActs.CanTarget(cur, underCursor) then
        valid := False;
      if weaponMode = 1 then
        if (cur = underCursor)
           or ((crIdx = 0) and (terrIdx = C_Terr.TERRAIN_CORPSE)) then
          valid := False
        else if CharHlp.HasRangedWeapon(cur) then
          if (not CharHlp.FindDamagingRangedWeapon(cur, weapon)) or
              ((CharHlp.CountTargets(cur, 1) > 0) and (not CharHlp.HasThrowableWeapon(cur))) then
            valid := False;
    end else if ground = 0 then
      valid := False;
    menu := 'Center Exit';
    if valid then
      menu := 'Target ' + menu;
    ch := MenuCore.MenuHorizontal('(Use Cursor keys) ', menu, LightMagenta, LightGreen, White, True, False,
                                  GDVars.doneRoundFlag);
    case ch of
      C_Keys.ENTER, 'T':
        begin
          GDVars.arenaPtr^.cursorOn := False;
          if valid then begin
            sel.x := cx;
            sel.y := cy;
            if underCursor <> nil then
              sel.cr := underCursor
            else
              sel.cr := nil;
            if weaponMode = 1 then
              CbtActs.ConfirmAttackTarget(cur, sel.cr, weaponMode, done, sel)
            else
              done := True;
          end;
          if (valid = False) or (done = False) then begin
            CbtMap.RedrawArenaCell(cx, cy);
            done := False;
            FillChar(sel, SizeOf(sel), 0);
          end;
        end;
      C_Keys.UP: dir := C_Dir.NORTH;
      C_Keys.PAGE_UP: dir := C_Dir.NORTHEAST;
      C_Keys.RIGHT: dir := C_Dir.EAST;
      C_Keys.PAGE_DOWN: dir := C_Dir.SOUTHEAST;
      C_Keys.DOWN: dir := C_Dir.SOUTH;
      C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
      C_Keys.LEFT: dir := C_Dir.WEST;
      C_Keys.HOME: dir := C_Dir.NORTHWEST;
      C_Keys.NONE, 'E':
        begin
          CbtMap.RedrawArenaCell(cx, cy);
          FillChar(sel, SizeOf(sel), 0);
          done := False;
        end;
      'C':
        begin
          CbtMap.ScrollView(cx, cy, 0, C_Dir.CENTER);
          dir := C_Dir.CENTER;
        end;
    else
      dir := C_Dir.CENTER;
    end;
  end;
end;

procedure CombatAimMenu(creature: Types.PCharRecord; range, weaponMode, groundOk: Byte; var done: Boolean; var tgt);
var
  targets: array[1..72] of Types.TCombatTarget;
  effRange: Byte;
  tgtCount: Byte;
  curIdx: Byte;
  skipStep: ShortInt;
  menuStep: ShortInt;
  curX: ShortInt;
  curY: ShortInt;
  nextX: ShortInt;
  nextY: ShortInt;
  p: Types.PCharRecord;
  ch: Char;

  { Build the parent routine's aiming list from targets within range 127. }
  procedure BuildAimTargets(c: Types.PCharRecord);
  var
    i: Byte;
  begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(c), CbtMap.CombatCellY(c), 127, 255, CbtMap.GetIconSize(c),
                            GDVars.arenaPtr);
    tgtCount := GDVars.targetCount;
    for i := 1 to tgtCount do
      targets[i] := GDVars.targetList[i];
  end;

  { Moves the aim through the target list, wrapping, flying the cursor there when animate is set. }
  function AdvanceAimTarget(step: ShortInt; animate: Boolean): Types.PCharRecord;
  var
    { Unused in this version; see the other implementations of this routine. }
    previousTarget: Pointer;
  begin
    if animate then begin
      curX := GDVars.arenaLoc[targets[curIdx].idx].x;
      curY := GDVars.arenaLoc[targets[curIdx].idx].y;
    end else
      CbtMap.RedrawArenaCell(curX, curY);
    Inc(curIdx, step);
    if curIdx = 0 then
      curIdx := tgtCount;
    if curIdx > tgtCount then
      curIdx := 1;
    AdvanceAimTarget := GDVars.creatureArr[targets[curIdx].idx];
    nextX := GDVars.arenaLoc[targets[curIdx].idx].x;
    nextY := GDVars.arenaLoc[targets[curIdx].idx].y;
    if animate then begin
      CharHlp.CombatAnimateMovingIcon(curX, curY, nextX, nextY, 1, 0);
      curX := nextX;
      curY := nextY;
    end;
  end;

begin
  { the aim cursor icon }
  CharHlp.CopyIconFacing(25, 0, 0, False);
  FillChar(tgt, SizeOf(TAimTarget), 0);
  done := False;
  effRange := range;
  if effRange = 255 then
    if creature^.equipped[C_Equip.WEAPON] <> nil then
      effRange := GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].range - 1
    else
      effRange := 1;
  if (effRange = 0) or (effRange = 255) then
    effRange := 1;
  BuildAimTargets(creature);
  curIdx := 1;
  skipStep := 0;
  p := AdvanceAimTarget(skipStep, True);
  skipStep := 1;
  ch := ' ';
  while (done = False) and (not (ch in [C_Keys.NONE, 'E'])) do
  begin
    if not CbtActs.CanTarget(creature, p) then
      p := AdvanceAimTarget(skipStep, False)
    else begin
      ch := CbtActs.AimTargetMenu(creature, p, effRange, weaponMode, groundOk);
      case ch of
        'N':
          begin
            skipStep := 1;
            menuStep := 1;
          end;
        'P':
          begin
            skipStep := -1;
            menuStep := -1;
          end;
        'M':
          begin
            CbtActs.ManualAimCursor(creature, p, effRange, weaponMode, groundOk, done, TAimTarget(tgt));
            CharHlp.CopyIconFacing(25, 0, 0, False);
            BuildAimTargets(creature);
            menuStep := 0;
          end;
        'T':
          begin
            CbtActs.ConfirmAttackTarget(creature, p, weaponMode, done, TAimTarget(tgt));
            CharHlp.CopyIconFacing(25, 0, 0, False);
            BuildAimTargets(creature);
            menuStep := 0;
          end;
        'C':
          begin
            CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), 0, C_Dir.CENTER);
            menuStep := 0;
          end;
      end;
      CbtMap.RedrawArenaCell(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p));
      p := AdvanceAimTarget(menuStep, (done = False) and (not (ch in [C_Keys.NONE, 'E'])));
    end;
  end;
  if weaponMode <> 0 then
    Border.ClearBox(0, 23, 39, 23);
end;

function AcquireTarget(creature: Types.PCharRecord; range, relaxed, forceNew: Byte): Boolean;
var
  cnt: Byte;
  tries: Byte;
  pick: Byte;
  second: Boolean;
  found: Boolean;
  pass: Boolean;
  p: Types.PCharRecord;
begin
  pass := False;
  found := False;
  second := False;
  p := creature^.combatAddr^.other;
  { Drop the lock when forceNew is set or the locked target is no longer valid; a nil lock skips the checks }
  if (forceNew <> 0) or
      ((p <> nil) and
       ((p^.hostile = creature^.hostile) or (p^.enabled = 0) or (not CbtActs.CanTarget(creature, p)))) then
    creature^.combatAddr^.other := nil;
  if creature^.combatAddr^.other <> nil then
    found := True;
  while (not found) and (not second) do begin
    second := pass;
    if pass and (forceNew = 0) then
      GDVars.arenaPtr^.distMode := 1;
    tries := 20;
    cnt := CharHlp.CountTargets(creature, range);
    while (tries > 0) and (not found) and (cnt > 0) do begin
      Dec(tries);
      pick := FxEngine.RollDice(1, cnt);
      if GDVars.potentialTargets[pick] > 0 then begin
        p := GDVars.creatureArr[GDVars.potentialTargets[pick]];
        if ((relaxed <> 0) and (GDVars.arenaPtr^.distMode <> 0))
           or CbtActs.CanTarget(creature, p) then begin
          found := True;
          creature^.combatAddr^.other := p;
        end else begin
          GDVars.potentialTargets[pick] := 0;
          { pick is reused as the index: do any targets remain? }
          for pick := 1 to cnt do
            if GDVars.potentialTargets[pick] > 0 then
              found := True;
          if found then
            found := False
          else
            cnt := 0;
        end;
      end;
    end;
    if not pass then
      pass := True;
  end;
  GDVars.arenaPtr^.distMode := 0;
  AcquireTarget := found;
end;

procedure RearClawRake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
begin
  if GDVars.hitsMade[1] = 2 then
    if creature^.combatAddr^.other^.enabled <> 0 then begin
      creature^.combatAddr^.attackPhase := 2;
      creature^.curAttacks2 := 2;
      creature^.curRollsA[2] := 2;
      creature^.curDiceA[2] := 4;
      creature^.curAttacks := 0;
      CharHlp.PrintCreatureMessage(creature, 'Rakes...', 10, True);
      CbtActs.MakeAttack(creature, creature^.combatAddr^.other, False, nil, done);
      done := CharHlp.EndActions(creature);
    end;
end;

procedure BiteAndHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
begin
  GDVars.otherCreature := GDVars.creatureArr[Types.PEffectRec(p)^.strength];
  if removed or (creature^.enabled = 0) or (GDVars.otherCreature^.enabled = 0) then begin
    FxEngine.RemoveEffect(GDVars.otherCreature, C_Effect.IMMOBILE, nil);
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_Effect.BITE_HOLD, p);
    end;
  end else begin
    creature^.curAttacks := 1;
    creature^.curAttacks2 := 0;
    creature^.curRollsA[1] := 3;
    creature^.curDiceA[1] := 4;
    CbtActs.MakeAttack(creature, GDVars.otherCreature, True, nil, done);
    done := CharHlp.EndActions(creature);
    if GDVars.otherCreature^.enabled = 0 then
      FxEngine.RemoveEffect(creature, C_Effect.BITE_HOLD, p);
  end;
end;

function VictoryCheat: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  p: Types.PCharRecord;
begin
  VictoryCheat := False;
  if ParamStr(1) <> 'STING' then
    Exit;
  VictoryCheat := True;
  CharHlp.PrintBottomLine('The Gods intervene!');
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.hostile = 1 then begin
      p^.enabled := 0;
      p^.status := C_Status.DEAD_STATUS;
      GDVars.arenaLoc[CbtMap.CombatSlot(p)].size := 0;
    end;
    done := CharHlp.EndActions(p);
    p := p^.nextCharAddr;
  end;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, C_Dir.CENTER);
end;

begin
end.
