{ Effect handlers for spells, items and creature abilities. Each handler receives the creature, the effect node or item
  concerned, and whether the effect is being removed or the item unreadied; it works through shared combat state such as
  GDVars.pendingDamage, the attack roll and GDVars.saveRoll. }
{$O+,F+}
unit EffHndlr;

interface

uses Types, C_Item, C_Npc, C_Terr, C_Save, C_Cond, GDConsts, GDVars, CbtActs, ClassCal, FxEngine, Debug, C_Effect,
  C_Equip, C_Race, C_Class, C_Status, C_Ifc, C_Align, CharHlp, CbtMap, TextRend, Pathing;

{ Install the effect handlers in GDVars.effectFns. Magic installs slot 88 (dragon breath) itself. }
procedure InitEffectHandlers;

{ Bless (effect 1): adds 5 to the morale and 1 to the attack roll.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Curse (effect 2): takes 5 off the morale, not below 0, and 1 off the attack roll.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Undead-slaying weapon (effect 3): against an undead target, adds 2 to the attack roll and the damage.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffUndeadSlayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Starting training with a Manual of Bodily Health (effect 4): adds the training effect for 43200 minutes.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffTrainStart(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Flame Tongue weapon (effect 6): against its target adds 1 to the attack roll and damage of a regenerating creature, 2
  of a cold-based or avian one and 3 of an undead one, and makes the damage magical fire.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFlameTongue(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Manual of Bodily Health training done (effect 7): Constitution rises by 1; at 20 or more it adds regeneration (effect
  62) for 60 minutes instead. From Constitution 15 the hit points gained above the rolled hit points are divided by the
  Constitution bonus summed over the class levels (at least 1) and added to the maximum and current hit points when
  Constitution is below 17 or the creature has fighter levels.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffTrainManual(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Protection from Evil (effects 8 and 45): against an evil attacker, adds 2 to the saving throw and takes 2 off the
  attack roll.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffProtEvil(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Protection from Good (effects 9 and 46): against a good attacker, adds 2 to the saving throw and takes 2 off the
  attack roll.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffProtGood(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Resist Cold (effect 10): against cold, halves the damage and adds 3 to the saving throw.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffResistCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Charm (effect 11): the first time, the creature changes to the charmer's side, fights automatically and becomes an
  animated party member if it was one of the party; the strength keeps the applied mark (bit 5), the old side (bit 6)
  and the charmer's side (bit 7). Each time the morale becomes 100. Removal restores the old side.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Enlarge and Strength (effects 12 and 38): sets Strength to the value this node holds, then applies the strongest other
  Enlarge or Strength node, which takes over the Strength to restore. A node whose strength is above $7F is ignored.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffExtraStr(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Friends (effect 14): sets Charisma to the node's strength.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffFriends(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Slow Poison's damage (effect 15): unless the effect lock is on, it re-arms for 10 minutes and deals 1 damage while the
  creature has more than 1 hit point.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffSlowPoisonHit(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Read Magic (effect 16): does nothing here; scroll reading checks for the effect.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffReadMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Shield (effect 17): the armor class becomes at least 3, the saving throw gains 1, and Magic Missile does no damage.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffShield(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Gnome attack bonus (effect 18): adds 1 to the attack roll against a gnome's foe of size 1.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGnomeAttackBonus(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Resist Fire (effect 20): against fire, halves the damage and adds 3 to the saving throw.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffResistFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Silence 15' (effect 21): the creature can neither use items nor cast this round, and says it is silenced the first
  time.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSilence(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Slow Poison running out (effect 22): a creature still poisoned dies, and Slow Poison's damage effect is removed under
  the effect lock.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSlowPoisonEnd(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Spiritual Hammer (effect 23): removal deletes the hammer; otherwise a +1 hammer is created when the creature has none
  and fewer than 16 items.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSpiritualHammer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Invisibility (effect 25): the attacker cannot target the creature unless it sees invisible, and the attack roll loses
  4.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffInvisible(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Dwarf attack bonus (effect 26): adds 1 to the attack roll against a dwarf's foe of size 1.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDwarfAttackBonus(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Mirror Image (effect 28): against a single-target spell, an image takes it unless 1d(images + 1) rolls 1; the strength
  counts the images left, and the effect goes with the last.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffMirrorImage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Ray of Enfeeblement (effect 29): the damage loses a quarter, rounded down.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffEnfeeble(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Coughing in a stinking cloud (effect 30): the creature can neither use items nor cast this round, says it is coughing
  the first time, and its armor class worsens by 2, to the armor class from behind.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCoughing(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Animate Dead (effect 32), on removal of the animation: the creature collapses dead unless the effect lock is on, and
  returns to its old side as an ordinary creature.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffAnimateDead(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Blindness (effect 33): the attack roll, armor class, armor class from behind and saving throw each lose 4.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBlind(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Diseased (effect 34): runs the Strength and hit-point disease handlers.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDiseased(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Prayer for the caster's side (effect 35): adds 1 to the saving throw and the attack roll.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffAlliedPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Bestow Curse (effect 36): the attack roll and the saving throw lose 4.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBestowCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Blink (effect 37): while the creature has initiative left, it cannot be targeted and attacks on it miss.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBlinking(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Haste (effect 39): the creature ages a year the first time (bit 4 of the strength marks that), and its movement or
  attacks double.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffHasted(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Stinking Cloud running out (effect 40): the cloud this caster made, numbered by the strength's upper nibble, is
  removed, its cells get their terrain back or a corpse mark, and the remaining clouds are drawn again.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffClearStinkingCloud(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Protection from Normal Missiles (effect 41): a missile from a weapon with no plus is avoided.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffProtNormalMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Slow (effect 42): the movement or attacks halve.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSlowed(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ The Strength-draining disease (effect 43): unless the effect lock is on, it re-arms for 60 minutes and the creature
  loses 1 Strength, or at Strength 3 becomes helpless.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffDiseaseStrength(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ The hit-point disease (effect 44): unless the effect lock is on, it re-arms for 10 minutes and deals 1 damage, or at 1
  hit point the creature becomes helpless.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffDiseaseHitPoints(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Dwarf and gnome defense against giants (effect 47): the attack roll loses 4 when a size-2 attacker is one of the
  giants. Note: the comparison reads eight names from the five-name giant table, the last three from the storage after
  it.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDwarfGiantDefense(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Gnome defense against bugbears and gnolls (effect 48): the attack roll loses 4 against such an attacker.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGnomeAcBug(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Prayer (effect 49): creatures on the caster's side (bit 4 of the strength) get the allied bonus, the others lose 1 on
  the attack roll and saving throw.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Mummy rot's block on healing (effect 50): unless the effect lock is on, it re-arms for 14400 minutes and restores 1
  hit point through the block.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffRotNoHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Helplessness (effects 31, 51, 52 and 53): ends the creature's actions.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHelpless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Dragon aura (effect 54): does nothing; the effect only marks the creature, shown in camp as repulsed.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDragonAura(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Poisoned (effect 55): does nothing; other code checks for the effect.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPoisoned(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Wearing a Ring of Invisibility (effect 56): renews invisibility for a minute.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRenewInvisibility(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Mummy rot (effect 57): each time costs 2 Charisma, not below 3; while the countdown in the strength's upper nibble is
  above 1 it counts down and re-arms for 43200 minutes, and then the creature rots away. Nothing happens under the
  effect lock.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffMummyRot(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immobility (effect 58): the creature has no movement.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmobile(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ A troll's regeneration starting (effect 59): adds lasting regeneration (effect 98).
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffTrollRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Ring of Fire Resistance (effect 61): against fire the damage loses 2 a die, at least 1 a die, the saving throw gains
  4, and fire that is not magical is nullified.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRingFireRes(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Regeneration from high Constitution (effect 62): unless the effect lock is on, it re-arms for 60 minutes and restores
  1 hit point.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffConRegeneration(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Poison on a hit (effect 64): the target saves at +0.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPoisonAttack(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Weak poison on a hit (effect 65): the target saves at +4.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffWeakPoisonAttack(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Mild poison on a hit (effect 66): the target saves at +2.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMildPoisonAttack(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Thri-kreen paralysis on a hit (effect 67): 2d8 minutes.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffParalyzingHit(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Ghoul paralysis on a hit (effect 68): 63 minutes, not against elves.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGhoulPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Drider paralysis on a hit (effect 69): 1d9+10 minutes. Note: the -2 save modifier is passed but not used.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDriderPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Strong poison on a hit (effect 70): the target saves at -2.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStrongPoisonAttack(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Dust of Disappearance (effect 71): the creature cannot be targeted, and the attack roll loses 4.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDustDisappear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Camouflage and the Cloak of Elvenkind (effect 72): 95 percent of the time, invisibility for a minute.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCamouflage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Draining blood (effect 75): the creature drains 1d4 from its victim, the strength being the victim's combat slot and
  the duration's upper bits the damage left, ending its actions; the drain ends when the budget runs out or the victim
  drops. On removal, or when either side is down, the victim is freed, and a creature still up with its victim up flees.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffBloodDrain(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Attaching to drain blood (effect 76): the attacker starts draining its target, with 12 to drain, and the target is
  held still.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBloodAttach(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Biting and holding on (effect 77): the attacker starts holding its target, which is held still, unless the target has
  Strength 19 or more.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBiteHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Waking when healed (effect 78): the creature revives with its current hit points, or tries again in a minute.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffDelayedRevival(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Fire on a hit (effect 79): 2d10 magical fire damage to the target.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Acid on a hit (effect 80): 1d4 acid damage to the target.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffAcidTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Dragon fear (effect 81): each enabled enemy saves against spells or, by its highest level, is paralyzed with fear for
  good (0 to 3) or cursed (4 and 5); level 6 and above is unaffected.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDragonFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Mummy fear (effect 82): the effect is removed from each creature, the mummy's own included; each enabled enemy then
  saves against paralysis, at +1 when its team has six members or more and +2 when human, or is paralyzed with fear for
  1d4 minutes.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMummyFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Petrifying gaze (effect 83): the target saves against petrification or is stoned. When the gaze can be reflected
  (effect 127), a readied Mirror turns it back on the gazer.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPetrifyingGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Charming gaze (effect 84): with a clear line to a target it may attack, the target is charmed as by Charm Person,
  saving against spells at -2, with no spell or action used.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCharmGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Draining a level on a hit (effect 85).
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDrainOne(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Draining two levels on a hit (effect 86).
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDrainTwo(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Mummy rot on a hit (effect 87): unless the target already has it, it gets the healing block (effect 50) and the rot
  (effect 57) with a countdown of 1d6.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRotTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Displacement (effect 89): the first attack on the creature each round misses; bit 4 of the strength marks that it has
  been used, cleared at the start of the battle.
  @param(creature Unused.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffDisplaced(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Constitution's save bonus against poison (effect 90): 1 to 5 by Constitution. Note: outside Constitution 4 to 20 the
  bonus is unset.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffConPsnSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to electricity and Magic Missile (effect 91).
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneMagicMissile(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Half damage from fire (effect 93).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Half damage from blunt and piercing weapons (effect 94).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfBash(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Fighting on at 0 hit points (effect 95): when it runs out, a creature still fighting falls dead.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to weapons neither magical nor silver, and to attacks without a weapon (effect 96).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNeedSilver(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Constitution's save bonus against spells and wands (effect 97): 1 to 5 by Constitution. Note: outside Constitution 4
  to 20 the bonus is unset.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffConSpellSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Regeneration (effect 98): 3 hit points a round, up to the maximum.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRegeneration(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Being able to fight on (effect 99): a dying creature less than 6 below 0, or an unconscious one, revives and fights on
  (effect 95) for 1d4+1 minutes, and this effect goes.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffCanFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ A troll's vulnerability to fire and acid (effect 100): damage of any other kind brings it back (effect 102) in 3d6
  minutes.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffTrollBurn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ A troll's regeneration (effect 101): unless it already regenerates, regeneration starts in 3 minutes (effect 59).
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffTrollHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ A troll coming back (effect 102): it revives at full hit points, or tries again in a minute.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffTrollReturn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Gaseous form (effect 103): the creature escapes and is taken out of play as fled.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffGaseous(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Thri-kreen missile dodging (effect 104): a 60 percent chance to avoid a missile.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDodgeMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Magic resistance of 50 percent (effect 105).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStrongMagicResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Magic resistance (effect 106). Note: it passes 15, so it resists 15 percent, not 85, against an 11th-level caster.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffWeakMagicResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ An elf's 90 percent resistance to sleep and charm (effect 107).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffElfResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to sleep and charm (effect 108).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneSleepCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to paralysis (effect 109).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneParalysis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to cold (effect 110).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNoCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to paralysis and poison (effect 111): saves against paralysis and poison succeed.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneParalysisPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to fire (effect 112).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNoFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ An efreeti's fire resistance (effect 113): fire damage loses 1 a die, at least 1 a die.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffEfreetiFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Half damage from electricity (effect 114).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfElec(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Half damage from slashing and piercing weapons (effect 115).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfSlashPierce(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Half damage from magical weapons (effect 116).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfMagicWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Vulnerability to holy water (effect 117): a holy water vial does 1d6+1.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHolyWater(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Half damage from cold (effect 118).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to weapons that are not magical, and to attacks without a weapon (effect 119), against a character race or an
  attacker below level 4.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNeedMagicWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Dodging boulders (effect 120): a 50 percent chance to avoid a thrown boulder.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDodgeBoulders(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ An ankheg's acid spit (effect 121): a 25 percent chance against a target within 4 cells, 8d4 acid, half on a save
  against breath; the creature's actions end and the effect removes itself and the acid touch.
  @param(creature The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffSpitAcid(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ A mummy's vulnerability to fire (effect 122): a flask of oil does 3d8, and magic or fire damage gains 1 a die.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMummyFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity unless the weapon is silver (half damage) or magical (full damage), and to attacks without a weapon (effect
  123).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSilverMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ A half-elf's 30 percent resistance to sleep and charm (effect 124).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfElfResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Immunity to charm, sleep, paralysis and poison (effect 125): saves against paralysis and poison succeed.
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneCharmSleepParalysisPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ A gaze that can be blocked (effect 126): a readied Mirror or the Wooden Holy Symbol of Tyr on the target stops the
  attacker from targeting it.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGazeBlock(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Readying an item with an effect (effects 128 to 130, 133, 134, 136, 138 and 139): readying adds the item's effect for
  good and runs its handler; unreadying removes it.
  @param(creature The creature with the effect.)
  @param(p The item.)
  @param(removed True when the item is being unreadied.) }
procedure EffGrantItemEffect(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Gauntlets of Ogre Power (effect 131): readying sets Strength 18/00 and adds a lasting Strength effect holding the
  Strength to restore. Unreadying removes the first Strength effect when the creature is at 18/00, else the first one
  holding 18/00.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGauntlets(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ An aligned weapon (effect 132): a wielder of another alignment than the low nibble of the item's effect has it
  unreadied and takes magic damage of the upper nibble.
  @param(creature The creature with the effect.)
  @param(p The item.)
  @param(removed True when the item is being unreadied.) }
procedure EffAlignedWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ A boulder (effect 135): readying it without Strength 19 or more unreadies it.
  @param(creature The creature with the effect.)
  @param(p The item.)
  @param(removed True when the item is being unreadied.) }
procedure EffBoulder(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ The spiritual hammer unreadied (effect 137): removal ends the Spiritual Hammer effect.
  @param(creature The creature with the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffHammerGone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing (effects 5, 13, 19, 24, 27, 60, 63, 92 and 127).
  @param(creature Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

implementation

const
  { Alignment values (TCharRecord.alignment) }
  ALIGN_LAWFUL_EVIL = 2;
  ALIGN_NEUTRAL_GOOD = 3;
  ALIGN_NEUTRAL_EVIL = 5;
  ALIGN_CHAOTIC_GOOD = 6;

  { Effect IDs (TEffectRec.id) }
  { EffNone handler. }
  REDUCE = 13;
  SEE_INVISIBLE = 24;
  CONSTITUTION_REGENERATION = 62;
  TROLL_RETURN = 102;
  GAZE_REFLECTABLE = 127;
  { Ring of Feather Falling, effect 27 }
  READY_FEATHER_FALL = 128;
  { Ring of Fire Resistance, effect 61 }
  READY_FIRE_RESISTANCE = 129;
  { Gauntlets of Ogre Power, effect 38 }
  GAUNTLETS = 131;
  { Cloak of Displacement, effect 89 }
  READY_DISPLACEMENT = 133;
  { Cloak of Elvenkind, effect 72 }
  READY_ELVENKIND = 134;
  BOULDER = 135;

  { TBaseItemRec.wpnClass melee damage type. Pierce and bash are distinct bits, so wpnClass and (PIERCING or BASHING)
    tests pierce-or-bash; slash is zero. }
  SLASHING = 0;
  PIERCING = $01;
  BASHING = $80;

  { Base item IDs }
  { eff 120 "boulder evasion" }
  ITEM_BOULDER = 87;
  { eff 120 "boulder evasion" }
  ITEM_LARGE_BOULDER = 88;

  { Saving-throw category (TCharRecord.saves index): rod / staff / wand }
  SAVE_WAND = 2;

var
  { 8-entry view over the 5-entry giantFoes. Note: EffDwarfGiantDefense compares all 8 entries, so entries 6..8 read the
    constants stored after giantFoes. }
  giantNames: array[1..8] of Types.TName15 absolute GDConsts.giantFoes;

{ Nullifies the attack or effect under check: pendingDamage and pendingEffectId become 0. Effect 0 always matches; any
  other only when it is the effect under the immunity check.
  @param(effId The effect to nullify, or 0 for any.) }
procedure NullifyAttack(effId: Byte);
begin
  if (effId = 0) or (GDVars.pendingEffectId = effId) then begin
    GDVars.pendingDamage := 0;
    GDVars.pendingEffectId := 0;
  end;
end;

{ Adds an effect, with onRemove set, unless the effect lock is on. The parameters come in a different order from
  FxEngine.AddEffect, strength before minutes.
  @param(creature The creature.)
  @param(effId The effect.)
  @param(strength Its strength.)
  @param(minutes Its duration in minutes.)
  @returns(True when the effect was added.) }
function AddEffectIfNoLock(creature: Types.PCharRecord; effId, strength: Byte; minutes: Word): Boolean;
begin
  if GDVars.effectLock <> 0 then
    AddEffectIfNoLock := False
  else begin
    AddEffectIfNoLock := True;
    FxEngine.AddEffect(creature, effId, minutes, strength, True);
  end;
end;

{ Prints a message after a creature's name; unless it is already dead, stoned or gone, it then takes that status,
  disabled with 0 hit points, loses the effects that end at 0 hit points, runs its 0-hit-point effects and is marked as
  downed when still disabled. It pauses and clears the message window, and outside combat redraws the party.
  @param(creature The creature.)
  @param(status Its new status: dead, stoned or gone.)
  @param(msg The message.) }
procedure InflictStatusMsg(creature: Types.PCharRecord; status: Byte; msg: Types.TStr40);
begin
  CharHlp.PrintCreatureMessage(creature, msg, 10, False);
  case creature^.status of
    C_Status.STONED, C_Status.DEAD_STATUS, C_Status.GONE: Exit;
  end;
  creature^.status := status;
  creature^.enabled := 0;
  creature^.hpCur := 0;
  FxEngine.RemoveEffectsHp0(creature);
  FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, creature);
  if creature^.enabled = 0 then
    CbtMap.CreatureDowned(creature);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  if GDVars.ifcState <> C_Ifc.IN_COMBAT then
    CharHlp.DisplayParty(GDVars.curChar);
end;

procedure EffBless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(GDVars.curMorale, 5);
  Inc(GDVars.attackRoll);
end;

procedure EffCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.curMorale < 5 then
    GDVars.curMorale := 0
  else
    Dec(GDVars.curMorale, 5);
  Dec(GDVars.attackRoll);
end;

procedure EffUndeadSlayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  { undead }
  if GDVars.otherCreature^.charType = 4 then begin
    Inc(GDVars.attackRoll, 2);
    Inc(GDVars.pendingDamage, 2);
  end;
end;

procedure EffTrainStart(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  CharHlp.PrintCreatureMessage(creature, 'starts to train', 10, True);
  FxEngine.AddEffect(creature, C_Effect.TRAINING_MANUAL, 43200, 255, True);
end;

procedure EffFlameTongue(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  bonus: Byte;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  case GDVars.otherCreature^.charType of
    { regenerating }
    10: bonus := 1;
    { cold-based / avian }
    9, 12: bonus := 2;
    { undead }
    4: bonus := 3;
  else
    bonus := 0;
  end;
  Inc(GDVars.attackRoll, bonus);
  Inc(GDVars.pendingDamage, bonus);
  { magical fire }
  GDVars.elementMask := 9;
end;

procedure EffTrainManual(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  hpGain: Byte;
  hpBonus: Byte;
  j: ShortInt;
begin
  CharHlp.PrintCreatureMessage(creature, 'is hardier', 10, True);
  Inc(creature^.conCur);
  if creature^.conCur >= 20 then begin
    FxEngine.AddEffect(creature, EffHndlr.CONSTITUTION_REGENERATION, 60, 255, True);
    Exit;
  end;
  hpGain := creature^.hpMax - creature^.hpRolled;
  hpBonus := 0;
  if creature^.conCur < 15 then Exit;
  { 7 is the last index of classLevels }
  for j := 0 to 7 do
    if creature^.classLevels[j] > 0 then
      if j = C_Class.FIGHTER_LEVEL then
        Inc(hpBonus, (creature^.conCur - 15) * creature^.classLevels[j])
      else if creature^.conCur > 15 then
        Inc(hpBonus, creature^.classLevels[j] * 2)
      else
        Inc(hpBonus, creature^.classLevels[j]);
  if hpBonus = 0 then
    hpBonus := 1;
  hpGain := hpGain div hpBonus;
  if (creature^.conCur < 17) or (creature^.classLevels[C_Class.FIGHTER_LEVEL] > 0) then begin
    Inc(creature^.hpMax, hpGain);
    Inc(creature^.hpCur, hpGain);
  end;
end;

procedure EffProtEvil(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.alignment = EffHndlr.ALIGN_LAWFUL_EVIL) or
      (GDVars.curChar^.alignment = EffHndlr.ALIGN_NEUTRAL_EVIL) or
      (GDVars.curChar^.alignment = C_Align.CHAOTIC_EVIL) then begin
    Inc(GDVars.saveRoll, 2);
    Dec(GDVars.attackRoll, 2);
  end;
end;

procedure EffProtGood(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.alignment = C_Align.LAWFUL_GOOD) or
      (GDVars.curChar^.alignment = EffHndlr.ALIGN_NEUTRAL_GOOD) or
      (GDVars.curChar^.alignment = EffHndlr.ALIGN_CHAOTIC_GOOD) then begin
    Inc(GDVars.saveRoll, 2);
    Dec(GDVars.attackRoll, 2);
  end;
end;

procedure EffResistCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 2 <> 0 then begin
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
    Inc(GDVars.saveRoll, 3);
  end;
end;

procedure EffCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then begin
    creature^.hostile := (Types.PEffectRec(p)^.strength and $40) div 64;
    if creature^.npc = C_Npc.ANIMATED_MEMBER then
      creature^.npc := 0;
  end else begin
    if Types.PEffectRec(p)^.strength and $20 = 0 then begin
      Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $20 + creature^.hostile * 64;
      creature^.hostile := Types.PEffectRec(p)^.strength div 128;
      creature^.quickfight := 1;
      { NON_PLAYER clear }
      if creature^.npc <= $7F then
        creature^.npc := C_Npc.ANIMATED_MEMBER;
      creature^.combatAddr^.other := nil;
      CharHlp.CountTeams;
    end;
    GDVars.curMorale := 100;
  end;
end;

procedure EffExtraStr(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  base: Byte;
  exc: Byte;
  bestBase: Byte;
  bestExc: Byte;
  q: Types.PEffectRec;
  best: Types.PEffectRec;
begin
  if Types.PEffectRec(p)^.strength > $7F then Exit;
  FxEngine.StrengthEffectToStrength(p, base, exc);
  creature^.strCur := base;
  creature^.strExc := exc;
  best := nil;
  bestBase := 0;
  bestExc := 0;
  q := creature^.effectsAddr;
  while q <> nil do begin
    if (q^.id = C_Effect.ENLARGE) or (q^.id = C_Effect.STRENGTH) then
      if q <> Types.PEffectRec(p) then begin
        FxEngine.StrengthEffectToStrength(q, base, exc);
        if (base > bestBase) or ((bestBase = 18) and (exc > bestExc)) then begin
          bestBase := base;
          bestExc := exc;
          best := q;
        end;
      end;
    q := q^.next;
  end;
  if best <> nil then begin
    Types.PEffectRec(best)^.strength := FxEngine.StrengthModifier(creature^.strCur, creature^.strExc);
    creature^.strCur := bestBase;
    creature^.strExc := bestExc;
  end;
end;

procedure EffFriends(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  creature^.chaCur := Types.PEffectRec(p)^.strength;
end;

procedure EffSlowPoisonHit(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.SLOW_POISON_HIT, Types.PEffectRec(p)^.strength, 10) then
    if creature^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(creature, 1, 0, False);
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then
        CharHlp.DisplayParty(GDVars.curChar);
    end;
end;

procedure EffReadMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffShield(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  { 60-biased AC 3 }
  if creature^.acCur < 57 then
    creature^.acCur := 57;
  Inc(GDVars.saveRoll);
  { Magic Missile }
  if GDVars.curSpell = 15 then
    GDVars.pendingDamage := 0;
end;

procedure EffGnomeAttackBonus(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  if GDVars.otherCreature^.charType = 1 then
    if GDVars.otherCreature^.iconDimensions = 1 then
      { 4 is the last index of gnomeFoes }
      for i := 1 to 4 do
        if GDVars.otherCreature^.name = GDConsts.gnomeFoes[i] then
          Inc(GDVars.attackRoll);
end;

procedure EffResistFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 1 <> 0 then begin
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
    Inc(GDVars.saveRoll, 3);
  end;
end;

procedure EffSilence(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(creature, 'is silenced', 10, True);
  creature^.combatAddr^.itemUseAllowed := 0;
  creature^.combatAddr^.castAllowed := 0;
end;

procedure EffSlowPoisonEnd(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(creature, C_Effect.POISONED, effect) then
    EffHndlr.InflictStatusMsg(creature, C_Status.DEAD_STATUS, 'dies from poison');
  GDVars.effectLock := 1;
  FxEngine.RemoveEffect(creature, C_Effect.SLOW_POISON_HIT, nil);
  GDVars.effectLock := 0;
end;

procedure EffSpiritualHammer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  found: Byte;
begin
  item := creature^.itemsAddr;
  found := 0;
  while (item <> nil) and (found = 0) do
    if (item^.itemType = C_Item.HAMMER) and (item^.nameIds[3] = 243) then
      found := 1
    else
      item := item^.next;
  if removed and (item <> nil) then
    CharHlp.RemoveItem(creature, item);
  if not removed then
    if found = 0 then
      if creature^.numberOfItems < 16 then begin
        GetMem(item, SizeOf(Types.TItemRec));
        FillChar(item^, SizeOf(Types.TItemRec), 0);
        item^.itemType := C_Item.HAMMER;
        item^.nameIds[2] := 20;
        item^.nameIds[3] := 243;
        item^.plus := 1;
        item^.effect := C_Effect.SPIRITUAL_HAMMER;
        item^.special := C_Effect.SPIRITUAL_HAMMER_GONE;
        CharHlp.AddItemCopy(creature, item);
        FreeMem(item, SizeOf(Types.TItemRec));
        CharHlp.PrintCreatureMessage(creature, 'Gains an item', 10, True);
      end;
  CharHlp.RecalcStats(creature);
end;

procedure EffInvisible(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if not CharHlp.HasEffect(GDVars.curChar, EffHndlr.SEE_INVISIBLE, effect) then
    GDVars.suppressTargeting := 1;
  Dec(GDVars.attackRoll, 4);
end;

procedure EffDwarfAttackBonus(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  if GDVars.otherCreature^.charType = 1 then
    if GDVars.otherCreature^.iconDimensions = 1 then
      { 8 is the last index of dwarfFoes }
      for i := 1 to 8 do
        if GDVars.otherCreature^.name = GDConsts.dwarfFoes[i] then
          Inc(GDVars.attackRoll);
end;

procedure EffMirrorImage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, Types.PEffectRec(p)^.strength + 1) > 1 then
    if GDVars.curSpell > 0 then
      if GDVars.multiTarget = 0 then begin
        EffHndlr.NullifyAttack(0);
        CharHlp.PrintCreatureMessage(creature, 'lost an image', 10, True);
        Dec(Types.PEffectRec(p)^.strength);
        if Types.PEffectRec(p)^.strength = 0 then
          FxEngine.RemoveEffect(creature, C_Effect.MIRROR_IMAGE, nil);
      end;
end;

procedure EffEnfeeble(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.pendingDamage := GDVars.pendingDamage - GDVars.pendingDamage div 4;
end;

procedure EffCoughing(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(creature, 'is coughing', 10, True);
  creature^.combatAddr^.itemUseAllowed := 0;
  creature^.combatAddr^.castAllowed := 0;
  CharHlp.RecalcStats(creature);
  if creature^.acBehind > 52 then
    Dec(creature^.acBehind, 2)
  else
    creature^.acBehind := 50;
  creature^.acCur := creature^.acBehind;
  if creature = GDVars.curChar then
    CharHlp.CombatPrintCreatureInfo(creature);
end;

procedure EffAnimateDead(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  if GDVars.effectLock = 0 then
    EffHndlr.InflictStatusMsg(creature, C_Status.DEAD_STATUS, 'collapses');
  creature^.hostile := Types.PEffectRec(p)^.strength div 16;
  creature^.quickfight := 1;
  creature^.levelUndead := 0;
  creature^.attackLevel := creature^.classLevels[C_Class.FIGHTER_LEVEL];
  creature^.movementBase := 12;
  if creature^.npc = C_Npc.ANIMATED_MEMBER then
    creature^.npc := 0;
  creature^.charType := 0;
end;

procedure EffBlind(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Dec(GDVars.attackRoll, 4);
  Dec(creature^.acCur, 4);
  Dec(creature^.acBehind, 4);
  Dec(GDVars.saveRoll, 4);
end;

procedure EffDiseased(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.CallEffectHandler(C_Effect.DISEASE_STRENGTH, creature, p, removed);
  FxEngine.CallEffectHandler(C_Effect.DISEASE_HIT_POINTS, creature, p, removed);
end;

procedure EffAlliedPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(GDVars.saveRoll);
  Inc(GDVars.attackRoll);
end;

procedure EffBestowCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Dec(GDVars.attackRoll, 4);
  Dec(GDVars.saveRoll, 4);
end;

procedure EffBlinking(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.initiative > 0 then begin
    GDVars.suppressTargeting := 1;
    GDVars.attackRoll := -1;
  end;
end;

procedure EffHasted(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Types.PEffectRec(p)^.strength and $10 = 0 then begin
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $10;
    CharHlp.PrintCreatureMessage(creature, 'ages', 10, True);
    Inc(creature^.age);
  end;
  GDVars.attackOrMoveX2 := GDVars.attackOrMoveX2 * 2;
end;

procedure EffClearStinkingCloud(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PStinkRec;
  node: Types.PStinkRec;
  found: Byte;
  slotId: Byte;
  i: Byte;
  xx: Byte;
  yy: Byte;
begin
  slotId := Types.PEffectRec(p)^.strength div 16;
  found := 0;
  node := GDVars.stinkHead;
  while (node <> nil) and (found = 0) do
    if (node^.caster = creature) and (node^.idx = slotId) then
      found := 1
    else
      node := node^.next;
  if found = 0 then Exit;
  CharHlp.PrintBottomLine('The air clears a little...');
  { 4 is the last index of TStinkRec.exists }
  for i := 1 to 4 do
    if node^.exists[i] <> 0 then begin
      xx := node^.ulX + GDConsts.dirDx[GDConsts.cloudDir[i]];
      yy := node^.ulY + GDConsts.dirDy[GDConsts.cloudDir[i]];
      found := 0;
      for slotId := 1 to GDVars.downedCount do
        if GDVars.downed[slotId].cr <> nil then
          if GDVars.downed[slotId].x = xx then
            if GDVars.downed[slotId].y = yy then
              found := 1;
      if found <> 0 then
        GDVars.arenaPtr^.cells[yy, xx] := C_Terr.TERRAIN_CORPSE
      else
        GDVars.arenaPtr^.cells[yy, xx] := node^.under[i];
    end;
  q := GDVars.stinkHead;
  if q = node then
    GDVars.stinkHead := q^.next
  else
    while q^.next <> node do
      q := q^.next;
  q^.next := node^.next;
  FreeMem(node, SizeOf(Types.TStinkRec));
  q := GDVars.stinkHead;
  while q <> nil do begin
    { 4 is the last index of TStinkRec.exists }
    for i := 1 to 4 do
      if q^.exists[i] <> 0 then
        GDVars.arenaPtr^.cells[q^.ulY + GDConsts.dirDy[GDConsts.cloudDir[i]],
                                 q^.ulX + GDConsts.dirDx[GDConsts.cloudDir[i]]] := C_Terr.TERRAIN_STINK_CLOUD;
    q := q^.next;
  end;
end;

{ Lets a creature avoid a missile: when the attacker has a weapon readied and is more than one cell away, a roll within
  the chance makes it avoid the attack, which then does no damage, misses and counts as one hit fewer.
  @param(creature The creature attacked.)
  @param(pct The chance in percent.) }
procedure AvoidMissile(creature: Types.PCharRecord; pct: Byte);
begin
  if GDVars.curChar^.equipped[C_Equip.WEAPON] <> nil then
    if CharHlp.CalcDistance(GDVars.curChar, creature) > 1 then
      if FxEngine.RollDice(1, 100) <= pct then begin
        CharHlp.PrintCreatureMessage(creature, 'Avoids it', 10, True);
        GDVars.pendingDamage := 0;
        GDVars.attackRoll := -1;
        Dec(GDVars.hitsMade[1]);
      end;
end;

{ Finds the item that deals an attacker's damage: the missile or thrown weapon of a ranged attack, else the readied
  weapon.
  @param(creature The attacker.)
  @returns(The item, or nil without a readied weapon.) }
function FindDamagingWeapon(creature: Types.PCharRecord): Types.PItemRec;
var
  sel: Types.PItemRec;
  ok: Boolean;
begin
  sel := nil;
  if creature^.equipped[C_Equip.WEAPON] <> nil then begin
    ok := CharHlp.FindDamagingRangedWeapon(creature, sel);
    if (ok = False) or (sel = nil) then
      sel := creature^.equipped[C_Equip.WEAPON];
  end;
  FindDamagingWeapon := sel;
end;

procedure EffProtNormalMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.FindDamagingWeapon(GDVars.curChar) <> nil then
    if Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar))^.plus = 0 then
      EffHndlr.AvoidMissile(creature, 100);
end;

procedure EffSlowed(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.attackOrMoveX2 := GDVars.attackOrMoveX2 div 2;
end;

procedure EffDiseaseStrength(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.DISEASE_STRENGTH, Types.PEffectRec(p)^.strength, 60) then
    if creature^.strCur > 3 then begin
      CharHlp.PrintCreatureMessage(creature, 'is weakened', 10, True);
      Dec(creature^.strCur);
    end else
      if not CharHlp.HasEffect(creature, C_Effect.HELPLESS, effect) then
        FxEngine.AddEffect(creature, C_Effect.HELPLESS, 0, 255, False);
end;

procedure EffDiseaseHitPoints(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.DISEASE_HIT_POINTS, Types.PEffectRec(p)^.strength, 10) then
    if creature^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(creature, 1, 0, False);
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then
        CharHlp.DisplayParty(GDVars.curChar);
    end else
      if not CharHlp.HasEffect(creature, C_Effect.HELPLESS, effect) then
        FxEngine.AddEffect(creature, C_Effect.HELPLESS, 0, 255, False);
end;

procedure EffDwarfGiantDefense(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  if GDVars.curChar^.charType = 1 then
    if GDVars.curChar^.iconDimensions and $7F = 2 then
      { 8 is the last index of giantNames }
      for i := 1 to 8 do
        if GDVars.otherCreature^.name = giantNames[i] then
          Dec(GDVars.attackRoll, 4);
end;

procedure EffGnomeAcBug(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.curChar^.charType = 1 then
    if (GDVars.curChar^.name = 'BUGBEAR') or (GDVars.curChar^.name = 'GNOLL') then
      Dec(GDVars.attackRoll, 4);
end;

procedure EffPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  side: Byte;
begin
  side := (Types.PEffectRec(p)^.strength and $10) div 16;
  if Byte(creature^.hostile) = side then
    EffHndlr.EffAlliedPrayer(creature, p, removed)
  else begin
    Dec(GDVars.attackRoll);
    Dec(GDVars.saveRoll);
  end;
end;

procedure EffRotNoHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.ROT_NO_HEALING, Types.PEffectRec(p)^.strength, 14400) then
    if FxEngine.RestoreHitPoints(creature, 1, True) then
      CharHlp.AnnounceHealStatus(creature);
end;

procedure EffHelpless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if CharHlp.EndActions(creature) then ;
end;

procedure EffDragonAura(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffPoisoned(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffRenewInvisibility(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(creature, C_Effect.INVISIBLE, 1, 12, False);
end;

procedure EffMummyRot(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.effectLock <> 0 then Exit;
  CharHlp.PrintCreatureMessage(creature, 'Rots...', 10, True);
  if creature^.chaCur > 2 then
    Dec(creature^.chaCur, 2)
  else
    creature^.chaCur := 0;
  if creature^.chaCur < 3 then
    creature^.chaCur := 3;
  if Types.PEffectRec(p)^.strength div 16 > 1 then begin
    Dec(Types.PEffectRec(p)^.strength, $10);
    if EffHndlr.AddEffectIfNoLock(creature, C_Effect.MUMMY_ROT, Types.PEffectRec(p)^.strength, 43200) then ;
  end else
    EffHndlr.InflictStatusMsg(creature, C_Status.GONE, 'Dies rots away');
end;

procedure EffImmobile(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  creature^.combatAddr^.movement := 0;
  if GDVars.calculatingMovement <> 0 then
    GDVars.attackOrMoveX2 := 0;
end;

procedure EffTrollRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(creature, C_Effect.REGENERATION, 0, 255, False);
end;

procedure EffRingFireRes(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  if GDVars.elementMask and 1 <> 0 then begin
    for i := 1 to GDVars.damageDice do begin
      Dec(GDVars.pendingDamage, 2);
      if GDVars.pendingDamage < GDVars.damageDice then
        GDVars.pendingDamage := GDVars.damageDice;
    end;
    Inc(GDVars.saveRoll, 4);
    if GDVars.elementMask and 8 = 0 then
      EffHndlr.NullifyAttack(0);
  end;
end;

procedure EffConRegeneration(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, EffHndlr.CONSTITUTION_REGENERATION, Types.PEffectRec(p)^.strength, 60) then
    if FxEngine.RestoreHitPoints(creature, 1, True) then
      CharHlp.AnnounceHealStatus(creature);
end;

{ Poisons the attacker's target: unless it saves against poison, it is poisoned and killed.
  @param(creature The attacker.)
  @param(saveMod Added to the target's saving throw.) }
procedure PoisonTarget(creature: Types.PCharRecord; saveMod: ShortInt);
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.otherCreature, C_Save.PARALYZATION, saveMod) then begin
    CharHlp.PrintCreatureMessage(GDVars.otherCreature, 'is Poisoned', 10, False);
    TextRend.PauseOnly;
    FxEngine.AddEffect(GDVars.otherCreature, C_Effect.POISONED, 0, 255, False);
    EffHndlr.InflictStatusMsg(GDVars.otherCreature, C_Status.DEAD_STATUS, 'is killed');
  end;
end;

{ Paralyzes the attacker's target unless it saves against paralysis.
  @param(creature The attacker.)
  @param(minutes How long the paralysis lasts.)
  @param(saveMod Unused.) }
procedure ParalyzeTarget(creature: Types.PCharRecord; minutes: Word; saveMod: ShortInt);
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.otherCreature, C_Save.PARALYZATION, 0) then begin
    CharHlp.PrintNameStringAnim(GDVars.otherCreature, True, 'is Paralyzed');
    FxEngine.AddEffect(GDVars.otherCreature, C_Effect.PARALYSIS, minutes, 12, False);
  end;
end;

procedure EffPoisonAttack(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(creature, 0);
end;

procedure EffWeakPoisonAttack(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(creature, 4);
end;

procedure EffMildPoisonAttack(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(creature, 2);
end;

procedure EffParalyzingHit(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ParalyzeTarget(creature, FxEngine.RollDice(2, 8), 0);
end;

procedure EffGhoulPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.other^.race <> C_Race.ELF then
    EffHndlr.ParalyzeTarget(creature, 63, 0);
end;

procedure EffDriderPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ParalyzeTarget(creature, FxEngine.RollDice(1, 9) + 10, -2);
end;

procedure EffStrongPoisonAttack(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(creature, -2);
end;

procedure EffDustDisappear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.suppressTargeting := 1;
  Dec(GDVars.attackRoll, 4);
end;

procedure EffCamouflage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 95 then
    FxEngine.AddEffect(creature, C_Effect.INVISIBLE, 1, 12, False);
end;

procedure EffBloodDrain(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  dmg: Byte;
begin
  GDVars.otherCreature := GDVars.creatureArr[Types.PEffectRec(p)^.strength];
  if removed or (creature^.enabled = 0) or (GDVars.otherCreature^.enabled = 0) then begin
    FxEngine.RemoveEffect(GDVars.otherCreature, C_Effect.IMMOBILE, nil);
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_Effect.BLOOD_DRAIN, p);
    end;
    if creature^.enabled <> 0 then
      if GDVars.otherCreature^.enabled <> 0 then
        creature^.combatAddr^.turned := 1;
  end else begin
    CharHlp.PrintCreatureMessage(creature, 'Sucks some Blood', 10, True);
    dmg := FxEngine.RollDamageDice(1, 4);
    GDVars.elementMask := 0;
    FxEngine.InflictNonWeaponDamage(GDVars.otherCreature, dmg, 0, False);
    done := CharHlp.EndActions(creature);
    if (GDVars.otherCreature^.enabled <> 0) and (Types.PEffectRec(p)^.duration div 16 > dmg) then
      Dec(Types.PEffectRec(p)^.duration, dmg * 16)
    else
      FxEngine.RemoveEffect(creature, C_Effect.BLOOD_DRAIN, p);
  end;
end;

procedure EffBloodAttach(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  { a 12 hp budget in the upper bits of the duration }
  FxEngine.AddEffect(creature, C_Effect.BLOOD_DRAIN, 12 * 16 + 15,
                     CbtMap.CombatSlot(GDVars.otherCreature), True);
  FxEngine.AddEffect(GDVars.otherCreature, C_Effect.IMMOBILE, 0, 255, False);
  FxEngine.CallEffectHandler(C_Effect.IMMOBILE, GDVars.otherCreature, nil, False);
end;

procedure EffBiteHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  if GDVars.otherCreature^.strCur < 19 then begin
    FxEngine.AddEffect(creature, C_Effect.BITE_HOLD, 0, CbtMap.CombatSlot(GDVars.otherCreature),
                       True);
    FxEngine.AddEffect(GDVars.otherCreature, C_Effect.IMMOBILE, 0, 255, False);
    FxEngine.CallEffectHandler(C_Effect.IMMOBILE, GDVars.otherCreature, nil, False);
    CharHlp.PrintCreatureMessage(GDVars.otherCreature, 'is held fast', 10, True);
  end;
end;

procedure EffDelayedRevival(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  repeated: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(creature, creature^.hpCur) then
    repeated := EffHndlr.AddEffectIfNoLock(creature, C_Effect.HEAL_WAKE, Types.PEffectRec(p)^.strength, 1);
end;

procedure EffFireTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := 9;
  FxEngine.InflictNonWeaponDamage(creature^.combatAddr^.other, FxEngine.RollDamageDice(2, 10), 0, False);
end;

procedure EffAcidTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := $10;
  FxEngine.InflictNonWeaponDamage(creature^.combatAddr^.other, FxEngine.RollDamageDice(1, 4), 0, False);
end;

procedure EffDragonFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PCharRecord;
  saved: Boolean;
begin
  q := GDVars.creatureList;
  while q <> nil do begin
    if q^.enabled <> 0 then
      if CharHlp.EnemyTeam(creature) = q^.hostile then begin
        saved := FxEngine.RollSavingThrow(q, C_Save.SPELL, 0);
        case q^.levelHighest of
          0..3: FxEngine.AddEffectWithMessage(q, C_Effect.PARALYSIS, 0, 12, False, True, saved,
                                              'is paralyzed with fear');
          4, 5: FxEngine.AddEffectWithMessage(q, C_Effect.CURSE, 0, 12, False, True, saved, 'is weakened by fear');
        end;
      end;
    q := q^.nextCharAddr;
  end;
end;

procedure EffMummyFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PCharRecord;
  bonus: Byte;
  saved: Boolean;
begin
  q := GDVars.creatureList;
  while q <> nil do begin
    FxEngine.RemoveEffect(q, C_Effect.MUMMY_FEAR, nil);
    if q^.enabled <> 0 then
      if CharHlp.EnemyTeam(creature) = q^.hostile then begin
        bonus := 0;
        if GDVars.teamCount[q^.hostile] >= 6 then
          Inc(bonus);
        if q^.race = C_Race.HUMAN then
          Inc(bonus, 2);
        saved := FxEngine.RollSavingThrow(q, C_Save.PARALYZATION, bonus);
        FxEngine.AddEffectWithMessage(q, C_Effect.PARALYSIS, FxEngine.RollDice(1, 4), 12, False, True, saved,
                                      'is paralyzed with fear');
      end;
    q := q^.nextCharAddr;
  end;
end;

procedure EffPetrifyingGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  reflected: Boolean;
  effect: Types.PEffectRec;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  CharHlp.PrintCreatureMessage(creature, 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.otherCreature),
                                  CbtMap.CombatCellY(GDVars.otherCreature), 4, 45);
  if CharHlp.HasEffect(creature, EffHndlr.GAZE_REFLECTABLE, effect) then begin
    reflected := False;
    item := GDVars.otherCreature^.itemsAddr;
    while (item <> nil) and (reflected = False) do begin
      if item^.equipped <> 0 then
        { "Mirror" }
        if (item^.nameIds[1] = 118) or (item^.nameIds[2] = 118) or (item^.nameIds[3] = 118) then begin
          CharHlp.PrintCreatureMessage(GDVars.otherCreature, 'reflects it!', 12, False);
          CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.otherCreature),
                                          CbtMap.CombatCellY(GDVars.otherCreature),
                                          CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 4, 45);
          reflected := True;
          GDVars.otherCreature := creature;
        end;
      item := item^.next;
    end;
  end;
  if not FxEngine.RollSavingThrow(GDVars.otherCreature, C_Save.PETRIFICATION, 0) then
    EffHndlr.InflictStatusMsg(GDVars.otherCreature, C_Status.STONED, 'is Stoned');
end;

procedure EffCharmGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dist: Word;
  effect: Types.PEffectRec;
  x: ShortInt;
  y: ShortInt;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  x := CbtMap.CombatCellX(GDVars.otherCreature);
  y := CbtMap.CombatCellY(GDVars.otherCreature);
  if not CbtActs.CanTarget(creature, GDVars.otherCreature) then Exit;
  if not Pathing.WalkLine(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), x, y, dist,
                          GDVars.arenaPtr) then Exit;
  CharHlp.PrintCreatureMessage(creature, 'Gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.otherCreature),
                                  CbtMap.CombatCellY(GDVars.otherCreature), 4, 45);
  { Charm Person }
  GDVars.curSpell := 10;
  FxEngine.AddEffectWithMessage(GDVars.otherCreature, C_Effect.CHARM, 0, creature^.hostile * 128 + 12,
                                True, True,
                                FxEngine.RollSavingThrow(creature^.combatAddr^.other, C_Save.SPELL, -2),
                                'is charmed');
  if CharHlp.HasEffect(GDVars.otherCreature, C_Effect.CHARM, effect) then
    FxEngine.CallEffectHandler(C_Effect.CHARM, GDVars.otherCreature, effect, False);
end;

{ Drains levels from a creature; an animated creature is destroyed instead. For each level it loses its maximum hit
  points divided by its total class levels from its maximum, rolled and current hit points, then either dies for good
  (highest level below 2) or loses a level in the class ClassToDrain picks, dying when its hit points reached 0. Its
  highest level and experience are then taken from that class.
  @param(creature The creature.)
  @param(levels The number of levels.) }
procedure DrainLevels(creature: Types.PCharRecord; levels: Byte);
var
  numStr: Types.TStr40;
  xpTry: LongInt;
  xpMin: LongInt;
  j: ShortInt;
  i: Byte;
  totalLevels: Byte;
  hpPerLevel: Byte;
  k: Byte;

  { Picks the class to drain: the highest level whose experience entry is highest, the later class on a tie. }
  function ClassToDrain: ShortInt;
  var
    jj: ShortInt;
    bestLvl: ShortInt;
    lvl: ShortInt;
  begin
    xpMin := 0;
    bestLvl := 0;
    { 7 is the last index of classLevels }
    for jj := 0 to 7 do begin
      lvl := creature^.classLevels[jj];
      if lvl > 1 then
        xpTry := GDConsts.classXpTable[jj].xp[lvl]
      else
        xpTry := 0;
      if lvl >= bestLvl then
        if (xpTry >= xpMin) or (xpTry = -1) then begin
          xpMin := xpTry;
          ClassToDrain := jj;
          bestLvl := lvl;
        end;
    end;
  end;

begin
  if levels > 1 then
    numStr := CharHlp.ByteToString(levels) + ' levels'
  else
    numStr := 'a level';
  CharHlp.PrintCreatureMessage(creature, 'is drained ' + numStr, 10, True);
  if creature^.status = C_Status.ANIMATED then begin
    EffHndlr.InflictStatusMsg(creature, C_Status.GONE, 'is dead forever');
    creature^.hpMax := 0;
    Exit;
  end;
  for i := 1 to levels do begin
    if creature^.status <> C_Status.GONE then begin
      Inc(creature^.drainedLevels);
      totalLevels := 0;
      { 7 is the last index of classLevels }
      for j := 0 to 7 do
        Inc(totalLevels, creature^.classLevels[j]);
      hpPerLevel := creature^.hpMax div totalLevels;
      Debug.PrintDebug('max,cur,lost', creature^.hpMax, creature^.hpCur, creature^.drainedHps);
      for k := 1 to hpPerLevel do begin
        if creature^.hpMax > 0 then
          Dec(creature^.hpMax);
        if creature^.hpRolled > 0 then
          Dec(creature^.hpRolled);
        if creature^.hpCur > 0 then
          Dec(creature^.hpCur);
        Inc(creature^.drainedHps);
      end;
      if creature^.levelHighest < 2 then begin
        EffHndlr.InflictStatusMsg(creature, C_Status.GONE, 'is dead forever');
        creature^.hpMax := 0;
        if creature^.classLevels[ClassToDrain] > 0 then
          if levels = 2 then
            creature^.classLevels[ClassToDrain] := 0;
      end else begin
        Dec(creature^.classLevels[ClassToDrain]);
        if creature^.hpCur = 0 then
          if creature^.status <> C_Status.DEAD_STATUS then
            EffHndlr.InflictStatusMsg(creature, C_Status.DEAD_STATUS, 'is killed');
        ClassCal.RecalcClassStats(creature);
      end;
      creature^.levelHighest := creature^.classLevels[ClassToDrain];
      creature^.experience := xpMin;
      CharHlp.RecalcStats(creature);
    end;
  end;
end;

procedure EffDrainOne(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.DrainLevels(creature^.combatAddr^.other, 1);
end;

procedure EffDrainTwo(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.DrainLevels(creature^.combatAddr^.other, 2);
end;

procedure EffRotTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  if not CharHlp.HasEffect(GDVars.otherCreature, C_Effect.ROT_NO_HEALING, effect) then begin
    FxEngine.AddEffect(GDVars.otherCreature, C_Effect.ROT_NO_HEALING, 14400, 255, True);
    FxEngine.AddEffect(GDVars.otherCreature, C_Effect.MUMMY_ROT, 43200,
                       FxEngine.RollDice(1, 6) * 16 + 15, True);
    CharHlp.PrintCreatureMessage(GDVars.otherCreature, 'is Diseased', 10, True);
  end;
end;

procedure EffDisplaced(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.roundCounter = 0) and (GDVars.attackRoll = 0) then
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength and $F
  else
    if Types.PEffectRec(p)^.strength and $10 = 0 then begin
      GDVars.attackRoll := -1;
      Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength or $10;
    end;
end;

procedure EffConPsnSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  bonus: Byte;
begin
  if GDVars.saveType = C_Save.PARALYZATION then begin
    case creature^.conCur of
      4..6: bonus := 1;
      7..10: bonus := 2;
      11..13: bonus := 3;
      14..17: bonus := 4;
      18..20: bonus := 5;
    end;
    GDVars.saveRoll := GDVars.saveRoll + bonus;
  end;
end;

procedure EffImmuneMagicMissile(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.curSpell = 15 then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintCreatureMessage(creature, 'is unaffected', 10, True);
  end else
    if GDVars.elementMask and 4 <> 0 then
      EffHndlr.NullifyAttack(0);
end;

procedure EffHalfFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 1 <> 0 then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffHalfBash(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then
    if GDVars.baseItems[w^.itemType].wpnClass and (EffHndlr.PIERCING or EffHndlr.BASHING) <> 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  if creature^.enabled <> 0 then
    EffHndlr.InflictStatusMsg(creature, C_Status.DEAD_STATUS, 'Falls dead');
end;

procedure EffNeedSilver(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (w = nil) or ((w^.plus = 0) and (w^.nameIds[3] <> 177)) then
    GDVars.pendingDamage := 0;
end;

procedure EffConSpellSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  bonus: Byte;
begin
  if (GDVars.saveType = C_Save.SPELL) or (GDVars.saveType = EffHndlr.SAVE_WAND) then begin
    case creature^.conCur of
      4..6: bonus := 1;
      7..10: bonus := 2;
      11..13: bonus := 3;
      14..17: bonus := 4;
      18..20: bonus := 5;
    end;
    GDVars.saveRoll := GDVars.saveRoll + bonus;
  end;
end;

procedure EffRegeneration(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(creature^.hpCur, 3);
  if creature^.hpCur > creature^.hpMax then
    creature^.hpCur := creature^.hpMax;
end;

procedure EffCanFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  hp: Byte;
begin
  hp := 0;
  if creature^.status = C_Status.DYING then
    if creature^.combatAddr^.overkill < 6 then
      hp := 6 - creature^.combatAddr^.overkill;
  if creature^.status = C_Status.UNCONSCIOUS then
    hp := 6;
  if hp > 0 then
    if FxEngine.ReviveDeadCreature(creature, hp) then begin
      FxEngine.AddEffect(creature, C_Effect.FIGHT_ON, FxEngine.RollDice(1, 4) + 1, 255, True);
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_Effect.CAN_FIGHT_ON, p);
    end;
end;

procedure EffTrollBurn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1 = 0) and (GDVars.elementMask and $10 = 0) then
    FxEngine.AddEffect(creature, EffHndlr.TROLL_RETURN, FxEngine.RollDice(3, 6), 255, True);
end;

procedure EffTrollHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if not CharHlp.HasEffect(creature, C_Effect.REGENERATION, effect) then
    if not CharHlp.HasEffect(creature, C_Effect.TROLL_REGENERATION, effect) then
      FxEngine.AddEffect(creature, C_Effect.TROLL_REGENERATION, 3, 255, True);
end;

procedure EffTrollReturn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  repeated: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(creature, creature^.hpMax) then
    repeated := EffHndlr.AddEffectIfNoLock(creature, EffHndlr.TROLL_RETURN, Types.PEffectRec(p)^.strength, 1);
end;

procedure EffGaseous(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  CbtMap.DisplayMapViewCentered(creature, 3, False);
  FxEngine.PutOutOfPlayWithStatus(creature, C_Status.RUNNING, 'Turns gaseous and escapes');
end;

procedure EffDodgeMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.AvoidMissile(creature, 60);
end;

{ Resists magic: the chance falls 5 percent a casting level below 11th, and a 1d100 roll within it nullifies an effect
  under the immunity check or magic damage. Note: the chance is a Byte and wraps when negative, so against a low enough
  casting level it always resists.
  @param(pct The chance in percent against an 11th-level caster.) }
procedure MagicResistance(pct: Byte);
var
  lvl: Byte;
  chance: Byte;
begin
  lvl := CharHlp.GetCasterLevel(GDVars.curSpell);
  chance := pct - (11 - lvl) * 5;
  if (GDVars.pendingEffectId = 0) and (GDVars.elementMask and 8 = 0) then
    Exit;
  if FxEngine.RollDice(1, 100) <= chance then
    EffHndlr.NullifyAttack(0);
end;

procedure EffStrongMagicResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(50);
end;

procedure EffWeakMagicResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(15);
end;

procedure EffElfResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(C_Effect.SLEEP);
    EffHndlr.NullifyAttack(C_Effect.CHARM);
  end;
end;

procedure EffImmuneSleepCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.SLEEP);
end;

procedure EffImmuneParalysis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.PARALYSIS);
end;

procedure EffNoCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 2 <> 0 then
    EffHndlr.NullifyAttack(0);
end;

procedure EffImmuneParalysisPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  EffHndlr.NullifyAttack(C_Effect.PARALYSIS);
  if GDVars.saveType = C_Save.PARALYZATION then
    GDVars.saveRoll := 100;
end;

procedure EffNoFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 1 <> 0 then
    EffHndlr.NullifyAttack(0);
end;

procedure EffEfreetiFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  if GDVars.elementMask and 1 <> 0 then
    for i := 1 to GDVars.damageDice do begin
      Dec(GDVars.pendingDamage);
      if GDVars.pendingDamage < GDVars.damageDice then
        GDVars.pendingDamage := GDVars.damageDice;
    end;
end;

procedure EffHalfElec(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 4 <> 0 then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffHalfSlashPierce(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then
    if (GDVars.baseItems[w^.itemType].wpnClass = EffHndlr.SLASHING) or
        (GDVars.baseItems[w^.itemType].wpnClass and EffHndlr.PIERCING <> 0) then
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffHalfMagicWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then
    if w^.plus > 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffHolyWater(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if item <> nil then
    if item^.itemType = C_Item.HOLY_WATER_VIAL then
      GDVars.pendingDamage := FxEngine.RollDamageDice(1, 6) + 1;
end;

procedure EffHalfCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 2 <> 0 then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

procedure EffNeedMagicWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (w = nil) or (w^.plus = 0) then
    if (GDVars.curChar^.race > C_Race.MONSTER) or (GDVars.curChar^.levelHighest < 4) then
      GDVars.pendingDamage := 0;
end;

procedure EffDodgeBoulders(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if item <> nil then
    if (item^.itemType = EffHndlr.ITEM_BOULDER) or (item^.itemType = EffHndlr.ITEM_LARGE_BOULDER) then
      EffHndlr.AvoidMissile(creature, 50);
end;

procedure EffSpitAcid(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  ended: Boolean;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  if FxEngine.RollDice(1, 100) > 25 then Exit;
  if CharHlp.CalcDistance(creature, GDVars.otherCreature) >= 4 then Exit;
  ended := CharHlp.EndActions(creature);
  CharHlp.PrintCreatureMessage(creature, 'Spits Acid', 10, True);
  CharHlp.BuildIconFacings(23);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.otherCreature),
                                  CbtMap.CombatCellY(GDVars.otherCreature), 1, 30);
  FxEngine.InflictNonWeaponDamage(GDVars.otherCreature, FxEngine.RollDamageDice(8, 4), 2,
                                  FxEngine.RollSavingThrow(GDVars.otherCreature, C_Save.BREATH_WEAPON, 0));
  FxEngine.RemoveEffect(creature, C_Effect.ANKHEG_ACID, p);
  FxEngine.RemoveEffect(creature, C_Effect.ACID_SQUIRT, nil);
end;

procedure EffMummyFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if item <> nil then
    if item^.itemType = C_Item.FLASK_OF_OIL then
      GDVars.pendingDamage := FxEngine.RollDamageDice(3, 8);
  if GDVars.elementMask and 9 <> 0 then
    Inc(GDVars.pendingDamage, GDVars.damageDice);
end;

procedure EffSilverMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then begin
    if (w^.plus = 0) and (w^.nameIds[3] = 177) then
      GDVars.pendingDamage := GDVars.pendingDamage div 2
    else if w^.plus = 0 then
      GDVars.pendingDamage := 0;
  end else
    GDVars.pendingDamage := 0;
end;

procedure EffHalfElfResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 30 then begin
    EffHndlr.NullifyAttack(C_Effect.CHARM);
    EffHndlr.NullifyAttack(C_Effect.SLEEP);
  end;
end;

procedure EffImmuneCharmSleepParalysisPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.SLEEP);
  EffHndlr.NullifyAttack(C_Effect.PARALYSIS);
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  if GDVars.saveType = C_Save.PARALYZATION then
    GDVars.saveRoll := 100;
end;

procedure EffGazeBlock(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  j: Byte;
begin
  GDVars.otherCreature := creature^.combatAddr^.other;
  item := GDVars.otherCreature^.itemsAddr;
  while (item <> nil) and (GDVars.suppressTargeting = 0) do begin
    if item^.equipped <> 0 then
      { 3 is the last index of TItemRec.nameIds }
      for j := 1 to 3 do
        if ((item^.nameIds[j] = 152) and (item^.nameIds[3] = 252)) or (item^.nameIds[j] = 118) then
          GDVars.suppressTargeting := 1;
    item := item^.next;
  end;
end;

procedure EffGrantItemEffect(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := p;
  if removed then
    FxEngine.RemoveEffect(creature, item^.effect, nil)
  else begin
    FxEngine.AddEffect(creature, item^.effect, 0, 12, False);
    FxEngine.CallEffectHandler(item^.effect, creature, nil, False);
  end;
end;

procedure EffGauntlets(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  enc: Byte;
  base: Byte;
  exc: Byte;
  isOgre: Boolean;
  found: Boolean;
  q: Types.PEffectRec;
begin
  if removed then begin
    found := False;
    q := creature^.effectsAddr;
    if (creature^.strCur = 18) and (creature^.strExc = 100) then
      isOgre := True
    else
      isOgre := False;
    while (q <> nil) and (found = False) do begin
      if q^.id = C_Effect.STRENGTH then begin
        FxEngine.StrengthEffectToStrength(q, base, exc);
        { Note: q^.id < $80 is always true here, since q^.id is STRENGTH. The $80 flag is kept in the strength byte,
          which EffExtraStr tests }
        if (isOgre and (q^.id < $80)) or ((base = 18) and (exc = 100) and (isOgre = False)) then begin
          FxEngine.RemoveEffect(creature, C_Effect.STRENGTH, q);
          found := True;
        end;
      end;
      q := q^.next;
    end;
  end else begin
    if FxEngine.AdjustForNewStrength(creature, 18, 100, enc) then
      if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
        GDVars.ifcState := C_Ifc.CAMPING;
        CharHlp.PrintCreatureMessage(creature, 'is stronger', 10, True);
        GDVars.ifcState := C_Ifc.IN_COMBAT;
      end else
        CharHlp.PrintCreatureMessage(creature, 'is stronger', 10, True);
    GDVars.redrawInventory := 1;
    FxEngine.AddEffect(creature, C_Effect.STRENGTH, 0, enc, True);
  end;
end;

procedure EffAlignedWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  dmg: Byte;
begin
  item := p;
  if removed then Exit;
  if item^.effect and $F <> creature^.alignment then begin
    item^.equipped := 0;
    dmg := item^.effect div 16;
    GDVars.elementMask := 8;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then
      CharHlp.DisplayCombatInterface;
    FxEngine.InflictNonWeaponDamage(creature, dmg, 0, False);
    GDVars.redrawInventory := 1;
  end;
end;

procedure EffBoulder(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := p;
  if removed then Exit;
  if creature^.strCur < 19 then begin
    item^.equipped := 0;
    CharHlp.PrintBottomLine('Must have Giant Strength');
  end;
end;

procedure EffHammerGone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then
    FxEngine.RemoveEffect(creature, C_Effect.SPIRITUAL_HAMMER, nil);
end;

procedure EffNone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure InitEffectHandlers;
begin
  GDVars.effectFns[C_Effect.BLESS] := EffHndlr.EffBless;
  GDVars.effectFns[C_Effect.CURSE] := EffHndlr.EffCurse;
  GDVars.effectFns[C_Effect.UNDEAD_SLAYER] := EffHndlr.EffUndeadSlayer;
  GDVars.effectFns[C_Effect.TRAINING_START] := EffHndlr.EffTrainStart;
  GDVars.effectFns[C_Effect.DETECT_MAGIC] := EffHndlr.EffNone;
  GDVars.effectFns[C_Effect.FLAME_TONGUE] := EffHndlr.EffFlameTongue;
  GDVars.effectFns[C_Effect.TRAINING_MANUAL] := EffHndlr.EffTrainManual;
  GDVars.effectFns[C_Effect.PROTECTION_FROM_EVIL] := EffHndlr.EffProtEvil;
  GDVars.effectFns[C_Effect.PROTECTION_FROM_GOOD] := EffHndlr.EffProtGood;
  GDVars.effectFns[C_Effect.RESIST_COLD] := EffHndlr.EffResistCold;
  GDVars.effectFns[C_Effect.CHARM] := EffHndlr.EffCharm;
  GDVars.effectFns[C_Effect.ENLARGE] := EffHndlr.EffExtraStr;
  GDVars.effectFns[EffHndlr.REDUCE] := EffHndlr.EffNone;
  GDVars.effectFns[C_Effect.FRIENDS] := EffHndlr.EffFriends;
  GDVars.effectFns[C_Effect.SLOW_POISON_HIT] := EffHndlr.EffSlowPoisonHit;
  GDVars.effectFns[C_Effect.READ_MAGIC] := EffHndlr.EffReadMagic;
  GDVars.effectFns[C_Effect.SHIELD] := EffHndlr.EffShield;
  GDVars.effectFns[C_Effect.GNOME_ATTACK_BONUS] := EffHndlr.EffGnomeAttackBonus;
  GDVars.effectFns[C_Effect.FIND_TRAPS] := EffHndlr.EffNone;
  GDVars.effectFns[C_Effect.RESIST_FIRE] := EffHndlr.EffResistFire;
  GDVars.effectFns[C_Effect.SILENCE] := EffHndlr.EffSilence;
  GDVars.effectFns[C_Effect.SLOW_POISON_END] := EffHndlr.EffSlowPoisonEnd;
  GDVars.effectFns[C_Effect.SPIRITUAL_HAMMER] := EffHndlr.EffSpiritualHammer;
  GDVars.effectFns[EffHndlr.SEE_INVISIBLE] := EffHndlr.EffNone;
  GDVars.effectFns[C_Effect.INVISIBLE] := EffHndlr.EffInvisible;
  GDVars.effectFns[C_Effect.DWARF_ATTACK_BONUS] := EffHndlr.EffDwarfAttackBonus;
  GDVars.effectFns[C_Effect.FEATHER_FALL] := EffHndlr.EffNone;
  GDVars.effectFns[C_Effect.MIRROR_IMAGE] := EffHndlr.EffMirrorImage;
  GDVars.effectFns[C_Effect.ENFEEBLED] := EffHndlr.EffEnfeeble;
  GDVars.effectFns[C_Effect.STINKING_CLOUD_COUGH] := EffHndlr.EffCoughing;
  GDVars.effectFns[C_Effect.HELPLESS] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.ANIMATE_DEAD] := EffHndlr.EffAnimateDead;
  GDVars.effectFns[C_Effect.BLIND] := EffHndlr.EffBlind;
  GDVars.effectFns[C_Effect.DISEASED] := EffHndlr.EffDiseased;
  GDVars.effectFns[C_Effect.ALLIED_PRAYER] := EffHndlr.EffAlliedPrayer;
  GDVars.effectFns[C_Effect.BESTOW_CURSE] := EffHndlr.EffBestowCurse;
  GDVars.effectFns[C_Effect.BLINKING] := EffHndlr.EffBlinking;
  GDVars.effectFns[C_Effect.STRENGTH] := EffHndlr.EffExtraStr;
  GDVars.effectFns[C_Effect.HASTED] := EffHndlr.EffHasted;
  GDVars.effectFns[C_Effect.CAST_STINKING_CLOUD] := EffHndlr.EffClearStinkingCloud;
  GDVars.effectFns[C_Effect.PROTECTION_FROM_MISSILES] := EffHndlr.EffProtNormalMissiles;
  GDVars.effectFns[C_Effect.SLOWED] := EffHndlr.EffSlowed;
  GDVars.effectFns[C_Effect.DISEASE_STRENGTH] := EffHndlr.EffDiseaseStrength;
  GDVars.effectFns[C_Effect.DISEASE_HIT_POINTS] := EffHndlr.EffDiseaseHitPoints;
  GDVars.effectFns[C_Effect.PROTECTION_FROM_EVIL_RADIUS] := EffHndlr.EffProtEvil;
  GDVars.effectFns[C_Effect.PROTECTION_FROM_GOOD_RADIUS] := EffHndlr.EffProtGood;
  GDVars.effectFns[C_Effect.DWARF_GIANT_DEFENSE] := EffHndlr.EffDwarfGiantDefense;
  GDVars.effectFns[C_Effect.GNOME_BUGBEAR_DEFENSE] := EffHndlr.EffGnomeAcBug;
  GDVars.effectFns[C_Effect.PRAYER] := EffHndlr.EffPrayer;
  GDVars.effectFns[C_Effect.ROT_NO_HEALING] := EffHndlr.EffRotNoHeal;
  GDVars.effectFns[C_Effect.SNAKE_CHARM] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.PARALYSIS] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.SLEEP] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.DRAGON_AURA] := EffHndlr.EffDragonAura;
  GDVars.effectFns[C_Effect.POISONED] := EffHndlr.EffPoisoned;
  GDVars.effectFns[C_Effect.RING_OF_INVISIBILITY] := EffHndlr.EffRenewInvisibility;
  GDVars.effectFns[C_Effect.MUMMY_ROT] := EffHndlr.EffMummyRot;
  GDVars.effectFns[C_Effect.IMMOBILE] := EffHndlr.EffImmobile;
  GDVars.effectFns[C_Effect.TROLL_REGENERATION] := EffHndlr.EffTrollRegen;
  GDVars.effectFns[60] := EffHndlr.EffNone;
  GDVars.effectFns[C_Effect.RING_OF_FIRE_RESISTANCE] := EffHndlr.EffRingFireRes;
  GDVars.effectFns[EffHndlr.CONSTITUTION_REGENERATION] := EffHndlr.EffConRegeneration;
  GDVars.effectFns[63] := EffHndlr.EffNone;
  GDVars.effectFns[C_Effect.POISON_ATTACK] := EffHndlr.EffPoisonAttack;
  GDVars.effectFns[C_Effect.WEAK_POISON_ATTACK] := EffHndlr.EffWeakPoisonAttack;
  GDVars.effectFns[C_Effect.MILD_POISON_ATTACK] := EffHndlr.EffMildPoisonAttack;
  GDVars.effectFns[C_Effect.KREEN_PARALYSIS] := EffHndlr.EffParalyzingHit;
  GDVars.effectFns[C_Effect.GHOUL_PARALYSIS] := EffHndlr.EffGhoulPara;
  GDVars.effectFns[C_Effect.DRIDER_PARALYSIS] := EffHndlr.EffDriderPara;
  GDVars.effectFns[C_Effect.STRONG_POISON_ATTACK] := EffHndlr.EffStrongPoisonAttack;
  GDVars.effectFns[C_Effect.DUST_OF_DISAPPEARANCE] := EffHndlr.EffDustDisappear;
  GDVars.effectFns[C_Effect.CAMOUFLAGE] := EffHndlr.EffCamouflage;
  GDVars.effectFns[C_Effect.REAR_CLAW_RAKE] := CbtActs.RearClawRake;
  GDVars.effectFns[C_Effect.BITE_HOLD] := CbtActs.BiteAndHold;
  GDVars.effectFns[C_Effect.BLOOD_DRAIN] := EffHndlr.EffBloodDrain;
  GDVars.effectFns[C_Effect.BLOOD_ATTACH] := EffHndlr.EffBloodAttach;
  GDVars.effectFns[C_Effect.BITE_ATTACH] := EffHndlr.EffBiteHold;
  GDVars.effectFns[C_Effect.HEAL_WAKE] := EffHndlr.EffDelayedRevival;
  GDVars.effectFns[C_Effect.FIRE_TOUCH] := EffHndlr.EffFireTouch;
  GDVars.effectFns[C_Effect.ACID_SQUIRT] := EffHndlr.EffAcidTouch;
  GDVars.effectFns[C_Effect.DRAGON_FEAR] := EffHndlr.EffDragonFear;
  GDVars.effectFns[C_Effect.MUMMY_FEAR] := EffHndlr.EffMummyFear;
  GDVars.effectFns[C_Effect.PETRIFYING_GAZE] := EffHndlr.EffPetrifyingGaze;
  GDVars.effectFns[C_Effect.CHARM_GAZE] := EffHndlr.EffCharmGaze;
  GDVars.effectFns[C_Effect.DRAIN_ONE] := EffHndlr.EffDrainOne;
  GDVars.effectFns[C_Effect.DRAIN_TWO] := EffHndlr.EffDrainTwo;
  GDVars.effectFns[C_Effect.ROT_TOUCH] := EffHndlr.EffRotTouch;
  GDVars.effectFns[C_Effect.DISPLACED] := EffHndlr.EffDisplaced;
  GDVars.effectFns[C_Effect.CONSTITUTION_POISON_SAVE] := EffHndlr.EffConPsnSave;
  GDVars.effectFns[C_Effect.IMMUNE_MAGIC_MISSILE] := EffHndlr.EffImmuneMagicMissile;
  GDVars.effectFns[92] := EffHndlr.EffNone;
  GDVars.effectFns[C_Effect.HALF_FIRE] := EffHndlr.EffHalfFire;
  GDVars.effectFns[C_Effect.HALF_BASHING] := EffHndlr.EffHalfBash;
  GDVars.effectFns[C_Effect.FIGHT_ON] := EffHndlr.EffFightOn;
  GDVars.effectFns[C_Effect.NEED_SILVER] := EffHndlr.EffNeedSilver;
  GDVars.effectFns[C_Effect.CONSTITUTION_SPELL_SAVE] := EffHndlr.EffConSpellSave;
  GDVars.effectFns[C_Effect.REGENERATION] := EffHndlr.EffRegeneration;
  GDVars.effectFns[C_Effect.CAN_FIGHT_ON] := EffHndlr.EffCanFightOn;
  GDVars.effectFns[C_Effect.TROLL_BURN] := EffHndlr.EffTrollBurn;
  GDVars.effectFns[C_Effect.TROLL_HEAL] := EffHndlr.EffTrollHeal;
  GDVars.effectFns[EffHndlr.TROLL_RETURN] := EffHndlr.EffTrollReturn;
  GDVars.effectFns[C_Effect.GASEOUS] := EffHndlr.EffGaseous;
  GDVars.effectFns[C_Effect.KREEN_DODGE] := EffHndlr.EffDodgeMissiles;
  GDVars.effectFns[C_Effect.STRONG_MAGIC_RESISTANCE] := EffHndlr.EffStrongMagicResistance;
  GDVars.effectFns[C_Effect.WEAK_MAGIC_RESISTANCE] := EffHndlr.EffWeakMagicResistance;
  GDVars.effectFns[C_Effect.ELF_RESISTANCE] := EffHndlr.EffElfResistance;
  GDVars.effectFns[C_Effect.NO_SLEEP_CHARM] := EffHndlr.EffImmuneSleepCharm;
  GDVars.effectFns[C_Effect.NO_PARALYSIS] := EffHndlr.EffImmuneParalysis;
  GDVars.effectFns[C_Effect.NO_COLD] := EffHndlr.EffNoCold;
  GDVars.effectFns[C_Effect.NO_PARALYSIS_POISON] := EffHndlr.EffImmuneParalysisPoison;
  GDVars.effectFns[C_Effect.NO_FIRE] := EffHndlr.EffNoFire;
  GDVars.effectFns[C_Effect.EFREETI_FIRE] := EffHndlr.EffEfreetiFire;
  GDVars.effectFns[C_Effect.HALF_ELECTRICITY] := EffHndlr.EffHalfElec;
  GDVars.effectFns[C_Effect.HALF_PIERCING] := EffHndlr.EffHalfSlashPierce;
  GDVars.effectFns[C_Effect.HALF_MAGICAL] := EffHndlr.EffHalfMagicWeapon;
  GDVars.effectFns[C_Effect.HOLY_WATER] := EffHndlr.EffHolyWater;
  GDVars.effectFns[C_Effect.HALF_COLD] := EffHndlr.EffHalfCold;
  GDVars.effectFns[C_Effect.NEED_MAGIC] := EffHndlr.EffNeedMagicWeapon;
  GDVars.effectFns[C_Effect.BOULDER_DODGE] := EffHndlr.EffDodgeBoulders;
  GDVars.effectFns[C_Effect.ANKHEG_ACID] := EffHndlr.EffSpitAcid;
  GDVars.effectFns[C_Effect.MUMMY_FIRE] := EffHndlr.EffMummyFire;
  GDVars.effectFns[C_Effect.SILVER_MAGIC] := EffHndlr.EffSilverMagic;
  GDVars.effectFns[C_Effect.HALF_ELF_RESISTANCE] := EffHndlr.EffHalfElfResistance;
  GDVars.effectFns[C_Effect.NO_CHARM_POISON] := EffHndlr.EffImmuneCharmSleepParalysisPoison;
  GDVars.effectFns[C_Effect.GAZE_BLOCK] := EffHndlr.EffGazeBlock;
  GDVars.effectFns[EffHndlr.GAZE_REFLECTABLE] := EffHndlr.EffNone;
  GDVars.effectFns[EffHndlr.READY_FEATHER_FALL] := EffHndlr.EffGrantItemEffect;
  GDVars.effectFns[EffHndlr.READY_FIRE_RESISTANCE] := EffHndlr.EffGrantItemEffect;
  GDVars.effectFns[130] := EffHndlr.EffGrantItemEffect;
  GDVars.effectFns[EffHndlr.GAUNTLETS] := EffHndlr.EffGauntlets;
  GDVars.effectFns[C_Effect.ALIGNED_WEAPON] := EffHndlr.EffAlignedWeapon;
  GDVars.effectFns[EffHndlr.READY_DISPLACEMENT] := EffHndlr.EffGrantItemEffect;
  GDVars.effectFns[EffHndlr.READY_ELVENKIND] := EffHndlr.EffGrantItemEffect;
  GDVars.effectFns[EffHndlr.BOULDER] := EffHndlr.EffBoulder;
  GDVars.effectFns[136] := EffHndlr.EffGrantItemEffect;
  GDVars.effectFns[C_Effect.SPIRITUAL_HAMMER_GONE] := EffHndlr.EffHammerGone;
  GDVars.effectFns[138] := EffHndlr.EffGrantItemEffect;
  GDVars.effectFns[C_Effect.READY_RING_OF_INVISIBILITY] := EffHndlr.EffGrantItemEffect;
end;

begin
end.
