{ The conditions FxEngine.TriggerEffectsWithCondition checks effects under. }
unit C_Cond;

interface

const
  { Check the target first, then the attacker unless the target vetoes. Handlers veto by setting the
    targeting-suppression flag. }
  { the attacker's own effects }
  ATTACKER_VETO = 0;
  { the target's effects }
  TARGET_VETO = 1;
  WEAPON_DAMAGE_ATTACKER = 4;
  WEAPON_DAMAGE_DEFENDER = 5;
  { CreatureAction, before the initiative test }
  TURN_START = 7;
  COMBAT_START = 8;
  { after RecalcStats, before the roll }
  DEFENDER_ARMOR_CLASS = 11;
  { Already disabled on entry; effect 99 may revive it. }
  HIT_POINTS_ZERO = 13;
  { Gazes, dragon breath and acid attacks. }
  MONSTER_SPECIAL = 14;
  { CreatureAction, and each menu draw }
  ACTION_START = 15;
  MORALE_CHECK = 17;
  { haste / slow / immobile effects }
  MOVE_ATTACK_RATE = 18;
  ROUND_END = 19;

implementation

end.
