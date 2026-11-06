{ Effect dispatch and active-effect lists, attack rolls, saving throws, damage, healing and revival. }
{$O+,F+}
unit FxEngine;

interface

uses Types, C_Terr, C_Save, C_Cond, GDConsts, GDVars, Blit, TextRend, CharHlp, Pathing, CbtMap,
  C_Effect, C_Status, C_Ifc, C_Dir, C_Gbvm;

{ Calls the handler of an effect through the effect handler table.
  @param(effId The effect, 1 to 139.)
  @param(creature The creature the effect concerns.)
  @param(p The item or effect node the handler concerns.)
  @param(removed True when the item is being unreadied or the effect removed.) }
procedure CallEffectHandler(effId: Byte; creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Removes an effect node from a creature's list: the node given, or else the first node of the effect (nothing happens
  when there is none). When the node's onRemove flag is set, the effect's handler is called first with removed set; the
  node is then unlinked and freed.
  @param(creature The creature.)
  @param(effId The effect.)
  @param(eff The node to remove, or nil for the first node of the effect.) }
procedure RemoveEffect(creature: Types.PCharRecord; effId: Byte; eff: Pointer);

{ Fires on one creature each effect registered under a condition (TriggerEffect), auras included.
  @param(cond The condition, 0 to 19: the constants of C_Cond and the COND_ constants of this unit.)
  @param(creature The creature.) }
procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCharRecord);

{ Checks an enabled creature standing in a stinking cloud, unless it is already coughing or helpless, animated, or
  immune through either poison immunity. A saving throw against paralyzation makes it start to cough for a minute; a
  failed one leaves it helpless with nausea for 1d4+1 minutes. The effect's handler is then called at once with the node
  last looked up, whether or not the effect was added.
  @param(creature The creature.) }
procedure ConsiderTerrainEffects(creature: Types.PCharRecord);

{ Rolls an attack that has no attacking creature: a d20, where 1 always misses and 20 counts as 100, adjusted by the
  defender's condition-16 effects.
  @param(defender Creature attacked.)
  @param(sixtyMinusThac0 The attack's to-hit value, 60 minus its THAC0.)
  @returns(True when the adjusted roll is not negative and the roll plus the to-hit value exceeds the defender's armor
    class.) }
function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;

{ Rolls an attack. The attacker loses its invisibility, and the d20 goes into attackRoll: 1 misses and 20 becomes 100.
  Then the attacker's attack-roll effects and the defender's attack-roll defense effects run, and the to-hit adjustment
  in the GBVM is added: the party's for an attacker on the party's side, the monsters' otherwise.
  @param(attacker The attacker.)
  @param(defender The creature attacked.)
  @param(sixtyMinusAc 60 minus the defender's armor class.)
  @returns(True on a hit: the roll still at least 0 and the roll plus the attacker's THAC0 value and the adjustment at
    least sixtyMinusAc.) }
function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;

{ Rolls a saving throw; the d20 goes into saveRoll. A 1 always fails and a 20 always succeeds. Otherwise the roll takes
  the creature's save bonus and the modifier, saveType is set from the parameter, the creature's saving-throw effects
  run, and the save succeeds when the roll reaches the creature's saving throw.
  @param(creature The creature.)
  @param(saveType The saving throw, 0 to 4.)
  @param(modifier Added to the roll.)
  @returns(True when the save succeeds.) }
function RollSavingThrow(creature: Types.PCharRecord; saveType, modifier: ShortInt): Boolean;

{ Rolls a number of dice and adds them up.
  @param(n Number of dice; 0 rolls nothing.)
  @param(sides Faces per die.)
  @returns(The sum, kept in a Byte, so a total above 255 wraps.) }
function RollDice(n, sides: Byte): Byte;

{ Rolls damage dice, recording the number of dice for the resistances.
  @param(n Number of dice.)
  @param(sides Faces per die.)
  @returns(The sum, as RollDice returns it.) }
function RollDamageDice(n, sides: Byte): Byte;

{ Adds an effect node to the end of a creature's effect list. It neither checks for a node already there nor calls the
  effect's handler.
  @param(creature The creature.)
  @param(effId The effect.)
  @param(minutes Its duration in minutes; 0 for a permanent effect.)
  @param(strength Its strength.)
  @param(onRemove True to call the effect's handler when it is removed.) }
procedure AddEffect(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);

{ Takes an enabled creature out of play: centers the map on it, prints a message after its name, disables it and sets
  its status. Its hit points drop to 0 unless it fled (running). Its icon is erased from the combat map and taken off
  the arena, and when its actions end the effects that end at 0 hit points are removed.
  @param(creature The creature.)
  @param(status Its new status.)
  @param(msg The message.) }
procedure PutOutOfPlayWithStatus(creature: Types.PCharRecord; status: Byte; msg: Types.TStr40);

{ Removes each invisibility effect from a creature.
  @param(creature The creature.) }
procedure RemoveInvisibility(creature: Types.PCharRecord);

{ Removes the first node of each effect that ends at 0 hit points (hpZeroEffects).
  @param(creature The creature.) }
procedure RemoveEffectsHp0(creature: Types.PCharRecord);

{ Removes the first node of each effect the AI clears at the start of its round (aiRoundRemoveEffects).
  @param(creature The creature.) }
procedure RemoveAiEffects(creature: Types.PCharRecord);

{ Cures a creature of an effect: when it has the effect, prints that it is cured and removes the node.
  @param(creature The creature.)
  @param(effId The effect.)
  @returns(True when the creature had the effect.) }
function RemoveEffectWithMessage(creature: Types.PCharRecord; effId: Byte): Boolean;

{ Encodes a Strength as an effect strength: 18 with exceptional Strength becomes the exceptional value + 1 (1..101), any
  other base Strength becomes the base + 100.
  @param(baseStr Base Strength.)
  @param(excStr Exceptional Strength, read when the base Strength is 18.)
  @returns(The encoded Strength.) }
function StrengthModifier(baseStr, excStr: Byte): Byte;

{ Decodes an effect's strength byte, bit 7 aside, into Strength: up to 101 is Strength 18 with exceptional Strength of
  the value less 1, above it Strength of the value less 100 with no exceptional Strength.
  @param(effect The Strength effect.)
  @param(baseStr Receives Strength.)
  @param(excStr Receives exceptional Strength.) }
procedure StrengthEffectToStrength(effect: Types.PEffectRec; var baseStr, excStr: Byte);

{ Applies a new Strength from a Strength effect. A Strength below the creature's current one changes nothing. Otherwise
  the first active Strength effect (Enlarge or Strength, bit 7 of its strength clear), when there is one, is superseded:
  it is given the creature's current Strength, marked with bit 7. The new Strength is set and the stats recomputed.
  @param(creature The creature.)
  @param(baseStr The new Strength.)
  @param(excStr The new exceptional Strength.)
  @param(effStrength Receives the Strength to restore when the new effect ends: the superseded effect's stored Strength,
    or else the creature's old Strength; for a weaker Strength, the new Strength marked with bit 7.)
  @returns(True when the new Strength was applied.) }
function AdjustForNewStrength(creature: Types.PCharRecord; baseStr, excStr: Byte; var effStrength: Byte): Boolean;

{ Deals damage other than a weapon's. The damage goes into pendingDamage and the creature's nonweapon-damage effects
  run; after a successful save the reduction cancels or halves it. Damage left over is printed with its element (fire,
  cold, electricity, acid, or magic when no other element bit is set) and dealt; in combat the creature can no longer
  cast this round and loses a spell it was casting. A creature the damage disables goes down, is dying or is killed; in
  combat the effects that end at 0 hit points are removed, its 0-hit-point effects run and it is marked as downed when
  it is still disabled.
  @param(creature The creature.)
  @param(damage The damage.)
  @param(saveReduction 1 to cancel the damage after a successful save, 2 to halve it.)
  @param(saved True when the creature saved.) }
procedure InflictNonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean);

{ Adds an effect with an immunity check and a message. The effect is refused, the creature unaffected, when one of its
  immunity effects clears pendingEffectId, or when it saved against an effect the save negates. Otherwise a node of the
  same effect is removed first when it is timed and the new duration is longer, or when the new effect is permanent; in
  any other case the new node is added beside it.
  @param(creature The creature.)
  @param(effId The effect.)
  @param(minutes Its duration in minutes; 0 for a permanent effect.)
  @param(strength Its strength.)
  @param(onRemove True to call the effect's handler when it is removed.)
  @param(saveNegates True when a successful save negates the effect.)
  @param(saved True when the creature saved.)
  @param(msg Printed after the creature's name; empty for none.) }
procedure AddEffectWithMessage(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveNegates, saved: Boolean; msg: Types.TStr40);

{ Heals a creature that is okay, animated, unconscious or dying, up to its maximum hit points. Mummy rot blocks the
  healing unless bypassRot is set and the creature is wounded; bypassRot at full hit points heals nothing either. A
  disabled dying creature becomes unconscious, and outside combat a disabled unconscious creature wakes through the
  heal-wake effect's handler.
  @param(creature The creature.)
  @param(hp The hit points to restore.)
  @param(bypassRot True to heal through mummy rot.)
  @returns(True when the creature was healed.) }
function RestoreHitPoints(creature: Types.PCharRecord; hp: Byte; bypassRot: Boolean): Boolean;

{ Revives a creature on its cell when the cell takes it, which in combat also places it there. It comes back okay and
  enabled with the hit points given; in combat the map centers on it. A hostile creature stands up and grins, any other
  gets back up, and the teams are counted again.
  @param(creature The creature.)
  @param(hp Its hit points.)
  @returns(True when the creature was revived.) }
function ReviveDeadCreature(creature: Types.PCharRecord; hp: Byte): Boolean;

implementation

const
  { Conditions TriggerEffectsWithCondition checks effects under }
  { a hit landed in attack phase 1 }
  COND_HIT_PHASE_1 = 2;
  { a hit landed in attack phase 2 }
  COND_HIT_PHASE_2 = 3;
  { before the saving-throw reduction }
  COND_NONWEAPON_DAMAGE = 6;
  { Clear pendingEffectId to suppress the effect. }
  COND_EFFECT_IMMUNITY = 9;
  COND_ATTACK_ROLL_ATT = 10;
  COND_SAVING_THROW = 12;
  COND_ATTACK_ROLL_DEF = 16;

procedure CallEffectHandler(effId: Byte; creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.effectFns[effId](creature, p, removed);
end;

procedure RemoveEffect(creature: Types.PCharRecord; effId: Byte; eff: Pointer);
var
  prev: Types.PEffectRec;
  p: Types.PEffectRec;
begin
  p := eff;
  if p = nil then begin
    p := creature^.effectsAddr;
    while (p <> nil) and (p^.id <> effId) do
      p := p^.next;
  end;
  if p = nil then Exit;
  if Types.PEffectRec(p)^.onRemove then
    FxEngine.CallEffectHandler(effId, creature, p, True);
  if creature^.effectsAddr = p then
    creature^.effectsAddr := p^.next
  else begin
    prev := creature^.effectsAddr;
    while (prev <> nil) and (prev^.next <> p) do
      prev := prev^.next;
    prev^.next := p^.next;
  end;
  FreeMem(p, SizeOf(Types.TEffectRec));
end;

{ Fires one effect on a creature: calls its handler when the creature has the effect, or, for the aura effects Silence
  15', Protection from Evil 10', Protection from Good 10' and Prayer, when a creature carrying it has this one in range
  (6 cells for Prayer, else 1; outside combat any carrier counts). The handler gets the node found: the creature's own,
  or the carrier's for an aura. The range test builds a target list, and the caller's target list is kept around it.
  @param(creature The creature.)
  @param(effId The effect.) }
procedure TriggerEffect(creature: Types.PCharRecord; effId: Byte);
var
  save: array[1..72] of Types.TCombatTarget;
  p: Types.PCharRecord;
  effect: Types.PEffectRec;
  found: Boolean;
  i: Byte;
  range: Byte;
begin
  found := False;
  p := GDVars.creatureList;
  if CharHlp.HasEffect(creature, effId, effect) then
    found := True
  else if effId in [C_Effect.SILENCE, C_Effect.PROTECTION_FROM_EVIL_RADIUS, C_Effect.PROTECTION_FROM_GOOD_RADIUS,
                    C_Effect.PRAYER] then begin
    Move(GDVars.targetList, save, SizeOf(GDVars.targetList));
    while (p <> nil) and not found do begin
      if CharHlp.HasEffect(p, effId, effect) then begin
        if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
          if effId = C_Effect.PRAYER then
            range := 6
          else
            range := 1;
          Pathing.BuildTargetList(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), range, 255, CbtMap.GetIconSize(p),
                                  GDVars.arenaPtr);
          for i := 1 to GDVars.targetCount do
            if GDVars.targetList[i].idx = CbtMap.CombatSlot(creature) then
              found := True;
        end else
          found := True;
      end;
      p := p^.nextCharAddr;
    end;
    Move(save, GDVars.targetList, SizeOf(GDVars.targetList));
  end;
  if found then
    FxEngine.CallEffectHandler(effId, creature, effect, False);
end;

procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Types.PEffectRec;
begin
  case cond of
    C_Cond.ATTACKER_VETO: FxEngine.TriggerEffect(creature, C_Effect.GAZE_BLOCK);
    C_Cond.TARGET_VETO: begin
      FxEngine.TriggerEffect(creature, 63); FxEngine.TriggerEffect(creature, C_Effect.BLINKING);
      FxEngine.TriggerEffect(creature, C_Effect.INVISIBLE); FxEngine.TriggerEffect(creature,
          C_Effect.DUST_OF_DISAPPEARANCE);
    end;
    FxEngine.COND_HIT_PHASE_1: begin
      FxEngine.TriggerEffect(creature, C_Effect.DRAIN_ONE); FxEngine.TriggerEffect(creature,
                                                                                   C_Effect.DRAIN_TWO);
      FxEngine.TriggerEffect(creature, C_Effect.ROT_TOUCH); FxEngine.TriggerEffect(creature,
          C_Effect.GHOUL_PARALYSIS);
      FxEngine.TriggerEffect(creature, C_Effect.FIRE_TOUCH); FxEngine.TriggerEffect(creature,
          C_Effect.ACID_SQUIRT);
      FxEngine.TriggerEffect(creature, C_Effect.BLOOD_ATTACH); FxEngine.TriggerEffect(creature,
          C_Effect.REAR_CLAW_RAKE);
      FxEngine.TriggerEffect(creature, C_Effect.BITE_ATTACH);
    end;
    FxEngine.COND_HIT_PHASE_2: begin
      FxEngine.TriggerEffect(creature, C_Effect.POISON_ATTACK); FxEngine.TriggerEffect(creature,
          C_Effect.WEAK_POISON_ATTACK);
      FxEngine.TriggerEffect(creature, C_Effect.MILD_POISON_ATTACK); FxEngine.TriggerEffect(creature,
          C_Effect.KREEN_PARALYSIS);
      FxEngine.TriggerEffect(creature, C_Effect.GHOUL_PARALYSIS); FxEngine.TriggerEffect(creature,
          C_Effect.DRIDER_PARALYSIS);
      FxEngine.TriggerEffect(creature, C_Effect.STRONG_POISON_ATTACK); FxEngine.TriggerEffect(creature,
          C_Effect.FIRE_TOUCH);
      FxEngine.TriggerEffect(creature, C_Effect.DRAIN_ONE); FxEngine.TriggerEffect(creature,
                                                                                   C_Effect.DRAIN_TWO);
      FxEngine.TriggerEffect(creature, C_Effect.ROT_TOUCH);
    end;
    C_Cond.WEAPON_DAMAGE_ATTACKER: begin
      FxEngine.TriggerEffect(creature, C_Effect.ENFEEBLED); FxEngine.TriggerEffect(creature,
          C_Effect.UNDEAD_SLAYER);
      FxEngine.TriggerEffect(creature, C_Effect.FLAME_TONGUE);
    end;
    C_Cond.WEAPON_DAMAGE_DEFENDER: begin
      FxEngine.TriggerEffect(creature, C_Effect.MIRROR_IMAGE); FxEngine.TriggerEffect(creature,
          C_Effect.PROTECTION_FROM_MISSILES);
      FxEngine.TriggerEffect(creature, C_Effect.KREEN_DODGE); FxEngine.TriggerEffect(creature,
          C_Effect.BOULDER_DODGE);
      FxEngine.TriggerEffect(creature, C_Effect.TROLL_HEAL); FxEngine.TriggerEffect(creature,
          C_Effect.HALF_PIERCING);
      FxEngine.TriggerEffect(creature, C_Effect.HALF_MAGICAL); FxEngine.TriggerEffect(creature,
          C_Effect.NEED_MAGIC);
      FxEngine.TriggerEffect(creature, C_Effect.SILVER_MAGIC); FxEngine.TriggerEffect(creature,
          C_Effect.NEED_SILVER);
      FxEngine.TriggerEffect(creature, C_Effect.HALF_BASHING); FxEngine.TriggerEffect(creature, 60);
      FxEngine.TriggerEffect(creature, C_Effect.MUMMY_FIRE); FxEngine.TriggerEffect(creature,
          C_Effect.HOLY_WATER);
    end;
    FxEngine.COND_NONWEAPON_DAMAGE: begin
      FxEngine.TriggerEffect(creature, C_Effect.EFREETI_FIRE); FxEngine.TriggerEffect(creature,
          C_Effect.RING_OF_FIRE_RESISTANCE);
      FxEngine.TriggerEffect(creature, C_Effect.MUMMY_FIRE); FxEngine.TriggerEffect(creature, 60);
      FxEngine.TriggerEffect(creature, C_Effect.IMMUNE_MAGIC_MISSILE); FxEngine.TriggerEffect(creature,
          C_Effect.RESIST_COLD);
      FxEngine.TriggerEffect(creature, C_Effect.RESIST_FIRE); FxEngine.TriggerEffect(creature,
          C_Effect.STRONG_MAGIC_RESISTANCE);
      FxEngine.TriggerEffect(creature, C_Effect.WEAK_MAGIC_RESISTANCE); FxEngine.TriggerEffect(creature,
                                                                                               C_Effect.NO_FIRE);
      FxEngine.TriggerEffect(creature, C_Effect.HALF_ELECTRICITY); FxEngine.TriggerEffect(creature,
                                                                                          C_Effect.HALF_COLD);
      FxEngine.TriggerEffect(creature, C_Effect.SHIELD); FxEngine.TriggerEffect(creature, C_Effect.HALF_FIRE);
      FxEngine.TriggerEffect(creature, C_Effect.TROLL_HEAL); FxEngine.TriggerEffect(creature,
          C_Effect.MIRROR_IMAGE);
    end;
    C_Cond.TURN_START: begin
      FxEngine.TriggerEffect(creature, C_Effect.SNAKE_CHARM); FxEngine.TriggerEffect(creature,
                                                                                     C_Effect.PARALYSIS);
      FxEngine.TriggerEffect(creature, C_Effect.SLEEP); FxEngine.TriggerEffect(creature, C_Effect.HELPLESS);
    end;
    C_Cond.COMBAT_START: begin
      FxEngine.TriggerEffect(creature, C_Effect.CAN_FIGHT_ON); FxEngine.TriggerEffect(creature,
          C_Effect.DRAGON_FEAR);
      FxEngine.TriggerEffect(creature, C_Effect.MUMMY_FEAR); FxEngine.TriggerEffect(creature,
                                                                                    C_Effect.DISPLACED);
      FxEngine.TriggerEffect(creature, C_Effect.CAMOUFLAGE); FxEngine.TriggerEffect(creature,
          C_Effect.RING_OF_INVISIBILITY);
    end;
    FxEngine.COND_EFFECT_IMMUNITY: begin
      FxEngine.TriggerEffect(creature, C_Effect.STRONG_MAGIC_RESISTANCE); FxEngine.TriggerEffect(creature,
          C_Effect.WEAK_MAGIC_RESISTANCE);
      FxEngine.TriggerEffect(creature, C_Effect.ELF_RESISTANCE); FxEngine.TriggerEffect(creature,
          C_Effect.NO_SLEEP_CHARM);
      FxEngine.TriggerEffect(creature, C_Effect.NO_PARALYSIS); FxEngine.TriggerEffect(creature,
                                                                                      C_Effect.NO_COLD);
      FxEngine.TriggerEffect(creature, C_Effect.NO_PARALYSIS_POISON); FxEngine.TriggerEffect(creature,
                                                                                             C_Effect.NO_FIRE);
      FxEngine.TriggerEffect(creature, C_Effect.HALF_ELF_RESISTANCE); FxEngine.TriggerEffect(creature,
          C_Effect.NO_CHARM_POISON);
    end;
    FxEngine.COND_ATTACK_ROLL_ATT: begin
      FxEngine.TriggerEffect(creature, C_Effect.BLESS); FxEngine.TriggerEffect(creature, C_Effect.CURSE);
      FxEngine.TriggerEffect(creature, C_Effect.BLIND); FxEngine.TriggerEffect(creature,
          C_Effect.BESTOW_CURSE);
      FxEngine.TriggerEffect(creature, C_Effect.PRAYER); FxEngine.TriggerEffect(creature,
          C_Effect.UNDEAD_SLAYER);
      FxEngine.TriggerEffect(creature, C_Effect.FLAME_TONGUE); FxEngine.TriggerEffect(creature,
          C_Effect.GNOME_ATTACK_BONUS);
      FxEngine.TriggerEffect(creature, C_Effect.DWARF_ATTACK_BONUS);
    end;
    C_Cond.DEFENDER_ARMOR_CLASS: begin
      FxEngine.TriggerEffect(creature, C_Effect.BLIND); FxEngine.TriggerEffect(creature, C_Effect.SHIELD);
      FxEngine.TriggerEffect(creature, C_Effect.PROTECTION_FROM_EVIL);
      FxEngine.TriggerEffect(creature, C_Effect.PROTECTION_FROM_GOOD);
      FxEngine.TriggerEffect(creature, C_Effect.PROTECTION_FROM_EVIL_RADIUS); FxEngine.TriggerEffect(creature,
          C_Effect.PROTECTION_FROM_GOOD_RADIUS);
      FxEngine.TriggerEffect(creature, C_Effect.STINKING_CLOUD_COUGH);
    end;
    FxEngine.COND_SAVING_THROW: begin
      FxEngine.TriggerEffect(creature, C_Effect.PROTECTION_FROM_EVIL);
      FxEngine.TriggerEffect(creature, C_Effect.PROTECTION_FROM_GOOD);
      FxEngine.TriggerEffect(creature, C_Effect.RESIST_COLD); FxEngine.TriggerEffect(creature, C_Effect.SHIELD);
      FxEngine.TriggerEffect(creature, C_Effect.RESIST_FIRE); FxEngine.TriggerEffect(creature, C_Effect.BLIND);
      FxEngine.TriggerEffect(creature, C_Effect.BESTOW_CURSE); FxEngine.TriggerEffect(creature,
          C_Effect.PROTECTION_FROM_EVIL_RADIUS);
      FxEngine.TriggerEffect(creature, C_Effect.PROTECTION_FROM_GOOD_RADIUS); FxEngine.TriggerEffect(creature,
                                                                                                     C_Effect.PRAYER);
      FxEngine.TriggerEffect(creature, C_Effect.RING_OF_FIRE_RESISTANCE); FxEngine.TriggerEffect(creature,
          C_Effect.NO_PARALYSIS_POISON);
      FxEngine.TriggerEffect(creature, C_Effect.NO_CHARM_POISON); FxEngine.TriggerEffect(creature,
          C_Effect.CONSTITUTION_POISON_SAVE);
      FxEngine.TriggerEffect(creature, C_Effect.CONSTITUTION_SPELL_SAVE);
    end;
    C_Cond.HIT_POINTS_ZERO: begin
      FxEngine.TriggerEffect(creature, C_Effect.CAN_FIGHT_ON); FxEngine.TriggerEffect(creature,
          C_Effect.TROLL_BURN);
      FxEngine.TriggerEffect(creature, C_Effect.GASEOUS); FxEngine.TriggerEffect(creature,
          C_Effect.BLOOD_DRAIN);
      FxEngine.TriggerEffect(creature, C_Effect.BITE_HOLD);
    end;
    C_Cond.MONSTER_SPECIAL: begin
      FxEngine.TriggerEffect(creature, C_Effect.PETRIFYING_GAZE); FxEngine.TriggerEffect(creature,
          C_Effect.CHARM_GAZE);
      FxEngine.TriggerEffect(creature, C_Effect.DRAGON_BREATH); FxEngine.TriggerEffect(creature,
          C_Effect.ANKHEG_ACID);
    end;
    C_Cond.ACTION_START: begin
      FxEngine.TriggerEffect(creature, C_Effect.SILENCE); FxEngine.TriggerEffect(creature,
          C_Effect.STINKING_CLOUD_COUGH);
      FxEngine.TriggerEffect(creature, C_Effect.BITE_HOLD); FxEngine.TriggerEffect(creature,
          C_Effect.BLOOD_DRAIN);
      FxEngine.TriggerEffect(creature, C_Effect.CHARM);
    end;
    FxEngine.COND_ATTACK_ROLL_DEF: begin
      FxEngine.TriggerEffect(creature, C_Effect.INVISIBLE); FxEngine.TriggerEffect(creature,
          C_Effect.DUST_OF_DISAPPEARANCE);
      FxEngine.TriggerEffect(creature, C_Effect.BLINKING); FxEngine.TriggerEffect(creature,
          C_Effect.DWARF_GIANT_DEFENSE);
      FxEngine.TriggerEffect(creature, C_Effect.GNOME_BUGBEAR_DEFENSE); FxEngine.TriggerEffect(creature,
                                                                                               C_Effect.DISPLACED);
    end;
    C_Cond.MORALE_CHECK: begin
      FxEngine.TriggerEffect(creature, C_Effect.BLESS); FxEngine.TriggerEffect(creature, C_Effect.CURSE);
      FxEngine.TriggerEffect(creature, C_Effect.CHARM);
    end;
    C_Cond.MOVE_ATTACK_RATE: begin
      FxEngine.TriggerEffect(creature, C_Effect.HASTED); FxEngine.TriggerEffect(creature, C_Effect.SLOWED);
      FxEngine.TriggerEffect(creature, C_Effect.IMMOBILE);
    end;
    C_Cond.ROUND_END: begin
      FxEngine.TriggerEffect(creature, C_Effect.REGENERATION); FxEngine.TriggerEffect(creature,
          C_Effect.SPIRITUAL_HAMMER);
      FxEngine.TriggerEffect(creature, C_Effect.CAMOUFLAGE); FxEngine.TriggerEffect(creature,
          C_Effect.RING_OF_INVISIBILITY);
      FxEngine.TriggerEffect(creature, C_Effect.CHARM);
    end;
  end;
end;

procedure ConsiderTerrainEffects(creature: Types.PCharRecord);
var
  terrIdx: Byte;
  crIdx: Byte;
  effect: Types.PEffectRec;
  saved: Boolean;
begin
  if creature^.enabled = 0 then Exit;
  CbtMap.ProbeDirection(creature, C_Dir.CENTER, crIdx, terrIdx);
  if terrIdx <> C_Terr.TERRAIN_STINK_CLOUD then Exit;
  if CharHlp.HasEffect(creature, C_Effect.STINKING_CLOUD_COUGH, effect) then Exit;
  if CharHlp.HasEffect(creature, C_Effect.HELPLESS, effect) then Exit;
  if CharHlp.HasEffect(creature, C_Effect.ANIMATE_DEAD, effect) then Exit;
  if CharHlp.HasEffect(creature, C_Effect.NO_PARALYSIS_POISON, effect) then Exit;
  if CharHlp.HasEffect(creature, C_Effect.NO_CHARM_POISON, effect) then Exit;
  { save vs. paralyzation, poison and death magic }
  saved := FxEngine.RollSavingThrow(creature, C_Save.PARALYZATION, 0);
  if saved then begin
    FxEngine.AddEffectWithMessage(creature, C_Effect.STINKING_CLOUD_COUGH, 1, 255, False, False, saved,
                                  'starts to cough');
    FxEngine.CallEffectHandler(C_Effect.STINKING_CLOUD_COUGH, creature, effect, False);
  end else begin
    FxEngine.AddEffectWithMessage(creature, C_Effect.HELPLESS, FxEngine.RollDice(1, 4) + 1, 255, False, False,
                                  saved, 'chokes and gags from nausea');
    FxEngine.CallEffectHandler(C_Effect.HELPLESS, creature, effect, False);
  end;
end;

function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;
begin
  AttackRollNoAttacker := False;
  GDVars.attackRoll := FxEngine.RollDice(1, 20);
  if GDVars.attackRoll > 1 then begin
    if GDVars.attackRoll = 20 then GDVars.attackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_DEF, defender);
    if (GDVars.attackRoll >= 0) and (GDVars.attackRoll + sixtyMinusThac0 > defender^.acCur) then
      AttackRollNoAttacker := True;
  end;
end;

function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;
var
  zmod: ShortInt;
begin
  AttackRoll := False;
  FxEngine.RemoveInvisibility(attacker);
  GDVars.attackRoll := FxEngine.RollDice(1, 20);
  if GDVars.attackRoll > 1 then begin
    if GDVars.attackRoll = 20 then GDVars.attackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_ATT, attacker);
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_DEF, defender);
    if attacker^.hostile = 0 then
      zmod := Lo(GDVars.zone1^[C_Gbvm.PARTY_THAC0_MODIFIER])
    else
      zmod := Lo(GDVars.zone1^[C_Gbvm.MONSTER_THAC0_MODIFIER]);
    if (GDVars.attackRoll >= 0) and (GDVars.attackRoll + attacker^.thac0Cur + zmod >= sixtyMinusAc) then
      AttackRoll := True;
  end;
end;

function RollSavingThrow(creature: Types.PCharRecord; saveType, modifier: ShortInt): Boolean;
begin
  GDVars.saveRoll := FxEngine.RollDice(1, 20);
  case GDVars.saveRoll of
    1: RollSavingThrow := False;
    20: RollSavingThrow := True;
  else begin
    GDVars.saveRoll := GDVars.saveRoll + creature^.saveBonus + modifier;
    GDVars.saveType := saveType;
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_SAVING_THROW, creature);
    if creature^.saves[saveType] <= GDVars.saveRoll then
      RollSavingThrow := True
    else
      RollSavingThrow := False;
  end;
  end;
end;

function RollDice(n, sides: Byte): Byte;
var
  i: Byte;
  total: Byte;
begin
  total := 0;
  if n > 0 then
    for i := 1 to n do
      Inc(total, Random(sides) + 1);
  RollDice := total;
end;

function RollDamageDice(n, sides: Byte): Byte;
begin
  GDVars.damageDice := n;
  RollDamageDice := FxEngine.RollDice(n, sides);
end;

procedure AddEffect(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);
var
  { p is the new node, q walks to the tail }
  p: Types.PEffectRec;
  q: Types.PEffectRec;
begin
  GetMem(p, SizeOf(Types.TEffectRec));
  if creature^.effectsAddr = nil then
    creature^.effectsAddr := p
  else begin
    q := creature^.effectsAddr;
    while q^.next <> nil do
      q := q^.next;
    q^.next := p;
  end;
  p^.next := nil;
  p^.id := effId;
  Types.PEffectRec(p)^.duration := minutes;
  Types.PEffectRec(p)^.onRemove := onRemove;
  Types.PEffectRec(p)^.strength := strength;
end;

procedure PutOutOfPlayWithStatus(creature: Types.PCharRecord; status: Byte; msg: Types.TStr40);
var
  slot: Byte;
begin
  if creature^.enabled = 0 then Exit;
  slot := CbtMap.CombatSlot(creature);
  CbtMap.DisplayMapViewCentered(creature, 3, False);
  CharHlp.PrintCreatureMessage(creature, msg, 10, True);
  creature^.enabled := 0;
  creature^.status := status;
  { a creature that fled (RUNNING) keeps its hit points }
  if creature^.status <> C_Status.RUNNING then
    creature^.hpCur := 0;
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  Blit.FlushView;
  GDVars.arenaLoc[slot].size := 0;
  CbtMap.BuildArenaArrays;
  if CharHlp.EndActions(creature) then
    FxEngine.RemoveEffectsHp0(creature);
end;

procedure RemoveInvisibility(creature: Types.PCharRecord);
var
  effect: Types.PEffectRec;
begin
  while CharHlp.HasEffect(creature, C_Effect.INVISIBLE, effect) do
    FxEngine.RemoveEffect(creature, C_Effect.INVISIBLE, effect);
end;

procedure RemoveEffectsHp0(creature: Types.PCharRecord);
var
  i: Byte;
begin
  for i := 1 to 16 do
    FxEngine.RemoveEffect(creature, GDConsts.hpZeroEffects[i], nil);
end;

procedure RemoveAiEffects(creature: Types.PCharRecord);
var
  i: Byte;
begin
  for i := 1 to 2 do
    FxEngine.RemoveEffect(creature, GDConsts.aiRoundRemoveEffects[i], nil);
end;

function RemoveEffectWithMessage(creature: Types.PCharRecord; effId: Byte): Boolean;
var
  effect: Types.PEffectRec;
begin
  RemoveEffectWithMessage := False;
  if CharHlp.HasEffect(creature, effId, effect) then begin
    CharHlp.PrintCreatureMessage(creature, 'is Cured', 10, True);
    FxEngine.RemoveEffect(creature, effId, effect);
    RemoveEffectWithMessage := True;
  end;
end;

function StrengthModifier(baseStr, excStr: Byte): Byte;
begin
  StrengthModifier := baseStr + 100;
  if baseStr = 18 then
    StrengthModifier := excStr + 1;
end;

procedure StrengthEffectToStrength(effect: Types.PEffectRec; var baseStr, excStr: Byte);
begin
  excStr := 0;
  baseStr := Types.PEffectRec(effect)^.strength and $7F;
  if baseStr <= 101 then begin
    excStr := baseStr - 1;
    baseStr := 18;
  end else
    baseStr := baseStr - 100;
end;

function AdjustForNewStrength(creature: Types.PCharRecord; baseStr, excStr: Byte; var effStrength: Byte): Boolean;
var
  p: Types.PEffectRec;
  found: Types.PEffectRec;
  oldBase: Byte;
  oldExc: Byte;
  enc: Byte;
begin
  oldBase := creature^.strCur;
  oldExc := creature^.strExc;
  if (baseStr < oldBase) or ((baseStr = 18) and (excStr < oldExc)) then begin
    AdjustForNewStrength := False;
    effStrength := FxEngine.StrengthModifier(baseStr, excStr) + $80;
  end else begin
    found := nil;
    p := creature^.effectsAddr;
    while (p <> nil) and (found = nil) do begin
      if ((p^.id = C_Effect.ENLARGE) or (p^.id = C_Effect.STRENGTH)) and
          (Types.PEffectRec(p)^.strength < $80) then
        found := p;
      p := p^.next;
    end;
    if found <> nil then begin
      enc := FxEngine.StrengthModifier(oldBase, oldExc);
      FxEngine.StrengthEffectToStrength(found, oldBase, oldExc);
      Types.PEffectRec(found)^.strength := enc + $80;
    end;
    creature^.strCur := baseStr;
    creature^.strExc := excStr;
    CharHlp.RecalcStats(creature);
    effStrength := FxEngine.StrengthModifier(oldBase, oldExc);
    AdjustForNewStrength := True;
  end;
end;

procedure InflictNonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean);
var
  s: String;
begin
  GDVars.pendingDamage := damage;
  FxEngine.TriggerEffectsWithCondition(FxEngine.COND_NONWEAPON_DAMAGE, creature);
  if saved then
    case Char(saveReduction) of
      #1: GDVars.pendingDamage := 0;
      #2: GDVars.pendingDamage := Integer(GDVars.pendingDamage) div 2;
    end;
  if GDVars.pendingDamage > 0 then begin
    if GDVars.pendingDamage <> 1 then
      s := 'takes ' + CharHlp.ByteToString(GDVars.pendingDamage) + ' points of damage '
    else
      s := 'takes 1 point of damage ';
    case GDVars.elementMask and $F7 of
      1: s := s + 'from Fire';
      2: s := s + 'from Cold';
      4: s := s + 'from Electricity';
      16: s := s + 'from Acid';
    end;
    { magic bit alone, or no element bit at all }
    if (GDVars.elementMask and 8) = GDVars.elementMask then
      s := s + 'from Magic';
    CharHlp.PrintNameStringAnim(creature, False, s);
    CharHlp.InflictDamage(creature, GDVars.pendingDamage);
    if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
      creature^.combatAddr^.castAllowed := 0;
      if creature^.combatAddr^.spellCast > 0 then begin
        CharHlp.PrintCreatureMessage(creature, 'lost a spell', 12, True);
        CharHlp.RemoveSpell(creature^.combatAddr^.spellCast);
        creature^.combatAddr^.spellCast := 0;
      end;
    end;
    if creature^.enabled = 0 then begin
      s := 'Goes Down';
      if creature^.status = C_Status.DYING then
        s := s + ', and is Dying';
      { 6..8 = dead, stoned, gone }
      if creature^.status in [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE] then
        s := 'is killed';
      CharHlp.PrintCreatureMessage(creature, s, GDVars.curRow + 1, False);
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then
        TextRend.PauseOnly
      else begin
        FxEngine.RemoveEffectsHp0(creature);
        FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, creature);
        if creature^.enabled = 0 then
          CbtMap.CreatureDowned(creature)
        else
          TextRend.PauseOnly;
      end;
    end;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure AddEffectWithMessage(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveNegates, saved: Boolean; msg: Types.TStr40);
var
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  oldEffect: Byte;
begin
  GDVars.pendingEffectId := effId;
  FxEngine.TriggerEffectsWithCondition(FxEngine.COND_EFFECT_IMMUNITY, creature);
  if (GDVars.pendingEffectId = 0) or (saved and (saveNegates = True)) then
    CharHlp.PrintCreatureMessage(creature, 'is Unaffected', 10, True)
  else begin
    if CharHlp.HasEffect(creature, effId, effect) then
      if ((Types.PEffectRec(effect)^.duration > 0) and (minutes > Types.PEffectRec(effect)^.duration)) or
          (minutes = 0) then
        FxEngine.RemoveEffect(creature, effId, effect);
    FxEngine.AddEffect(creature, effId, minutes, strength, onRemove);
    if msg[0] <> #0 then begin
      CharHlp.PrintNameStringAnim(creature, True, msg);
      CharHlp.ClearMessageWindow;
    end;
  end;
end;

function RestoreHitPoints(creature: Types.PCharRecord; hp: Byte; bypassRot: Boolean): Boolean;
var
  effect: Types.PEffectRec;
begin
  RestoreHitPoints := False;
  if not (creature^.status in [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS,
                               C_Status.DYING]) then Exit;
  if (creature^.hpCur >= creature^.hpMax) or not bypassRot then begin
    if CharHlp.HasEffect(creature, C_Effect.ROT_NO_HEALING, effect) then Exit;
    { bypassRot at full hit points: False }
    if bypassRot then Exit;
  end;
  creature^.hpCur := creature^.hpCur + hp;
  if creature^.hpCur > creature^.hpMax then
    creature^.hpCur := creature^.hpMax;
  if creature^.enabled = 0 then begin
    if creature^.status = C_Status.DYING then
      creature^.status := C_Status.UNCONSCIOUS;
    if (creature^.status = C_Status.UNCONSCIOUS) and (GDVars.ifcState <> C_Ifc.IN_COMBAT) then
      FxEngine.CallEffectHandler(C_Effect.HEAL_WAKE, creature, nil, True);
  end;
  RestoreHitPoints := True;
end;

function ReviveDeadCreature(creature: Types.PCharRecord; hp: Byte): Boolean;
var
  s: Types.TStr40;
begin
  if CbtMap.IsValidCreatureLoc(creature, CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), True)
  then begin
    creature^.status := C_Status.OKAY;
    creature^.enabled := 1;
    creature^.hpCur := hp;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then
      CbtMap.DisplayMapViewCentered(creature, 3, False);
    if creature^.hostile = 1 then
      s := 'stands up and grins'
    else
      s := 'gets back up';
    CharHlp.PrintCreatureMessage(creature, s, 10, True);
    CharHlp.CountTeams;
    ReviveDeadCreature := True;
  end else
    ReviveDeadCreature := False;
end;

begin
end.
