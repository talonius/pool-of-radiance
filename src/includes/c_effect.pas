{ Effect IDs: TEffectRec.id values used by FxEngine.AddEffect, FxEngine.RemoveEffect and CharHlp.HasEffect, and indices
  into EffHndlr's handler table. }
unit C_Effect;

interface

const
  BLESS = 1;
  CURSE = 2;
  UNDEAD_SLAYER = 3;
  TRAINING_START = 4;
  { EffNone handler; item labels mark magic items while any creature has it }
  DETECT_MAGIC = 5;
  FLAME_TONGUE = 6;
  TRAINING_MANUAL = 7;
  PROTECTION_FROM_EVIL = 8;
  PROTECTION_FROM_GOOD = 9;
  RESIST_COLD = 10;
  CHARM = 11;
  ENLARGE = 12;
  FRIENDS = 14;
  SLOW_POISON_HIT = 15;
  READ_MAGIC = 16;
  SHIELD = 17;
  GNOME_ATTACK_BONUS = 18;
  { EffNone handler. }
  FIND_TRAPS = 19;
  RESIST_FIRE = 20;
  SILENCE = 21;
  SLOW_POISON_END = 22;
  SPIRITUAL_HAMMER = 23;
  INVISIBLE = 25;
  DWARF_ATTACK_BONUS = 26;
  { EffNone handler; readying the Ring of Feather Falling adds it }
  FEATHER_FALL = 27;
  MIRROR_IMAGE = 28;
  ENFEEBLED = 29;
  STINKING_CLOUD_COUGH = 30;
  HELPLESS = 31;
  ANIMATE_DEAD = 32;
  BLIND = 33;
  DISEASED = 34;
  { Prayer's bonus alone: +1 to attack and saving throws. PRAYER grants it to the caster's side. }
  ALLIED_PRAYER = 35;
  BESTOW_CURSE = 36;
  BLINKING = 37;
  STRENGTH = 38;
  { EclVm.MoveExtremes doubles movement on it }
  HASTED = 39;
  CAST_STINKING_CLOUD = 40;
  PROTECTION_FROM_MISSILES = 41;
  SLOWED = 42;
  DISEASE_STRENGTH = 43;
  DISEASE_HIT_POINTS = 44;
  { Shares the effect 8 handler, EffProtEvil. }
  PROTECTION_FROM_EVIL_RADIUS = 45;
  { Shares the effect 9 handler, EffProtGood. }
  PROTECTION_FROM_GOOD_RADIUS = 46;
  DWARF_GIANT_DEFENSE = 47;
  GNOME_BUGBEAR_DEFENSE = 48;
  PRAYER = 49;
  ROT_NO_HEALING = 50;
  { Shares the effect 31 handler, EffHelpless. }
  SNAKE_CHARM = 51;
  PARALYSIS = 52;
  SLEEP = 53;
  { Dragon fear, toned down for the game: the handler does nothing, so the effect only marks the creature and camp lists
    it as Repulsed. The full fear effect is DRAGON_FEAR. }
  DRAGON_AURA = 54;
  POISONED = 55;
  RING_OF_INVISIBILITY = 56;
  MUMMY_ROT = 57;
  IMMOBILE = 58;
  TROLL_REGENERATION = 59;
  RING_OF_FIRE_RESISTANCE = 61;
  POISON_ATTACK = 64;
  WEAK_POISON_ATTACK = 65;
  MILD_POISON_ATTACK = 66;
  KREEN_PARALYSIS = 67;
  GHOUL_PARALYSIS = 68;
  DRIDER_PARALYSIS = 69;
  STRONG_POISON_ATTACK = 70;
  { Dust of Disappearance: a stronger form of invisibility than INVISIBLE; camp lists it as Invisible. }
  DUST_OF_DISAPPEARANCE = 71;
  CAMOUFLAGE = 72;
  REAR_CLAW_RAKE = 73;
  BITE_HOLD = 74;
  BLOOD_DRAIN = 75;
  BLOOD_ATTACH = 76;
  { EffBiteHold applies BITE_HOLD. }
  BITE_ATTACH = 77;
  HEAL_WAKE = 78;
  FIRE_TOUCH = 79;
  ACID_SQUIRT = 80;
  DRAGON_FEAR = 81;
  MUMMY_FEAR = 82;
  PETRIFYING_GAZE = 83;
  CHARM_GAZE = 84;
  DRAIN_ONE = 85;
  DRAIN_TWO = 86;
  ROT_TOUCH = 87;
  DRAGON_BREATH = 88;
  DISPLACED = 89;
  CONSTITUTION_POISON_SAVE = 90;
  IMMUNE_MAGIC_MISSILE = 91;
  HALF_FIRE = 93;
  HALF_BASHING = 94;
  FIGHT_ON = 95;
  NEED_SILVER = 96;
  CONSTITUTION_SPELL_SAVE = 97;
  REGENERATION = 98;
  CAN_FIGHT_ON = 99;
  TROLL_BURN = 100;
  TROLL_HEAL = 101;
  GASEOUS = 103;
  KREEN_DODGE = 104;
  STRONG_MAGIC_RESISTANCE = 105;
  WEAK_MAGIC_RESISTANCE = 106;
  ELF_RESISTANCE = 107;
  NO_SLEEP_CHARM = 108;
  NO_PARALYSIS = 109;
  NO_COLD = 110;
  NO_PARALYSIS_POISON = 111;
  NO_FIRE = 112;
  EFREETI_FIRE = 113;
  HALF_ELECTRICITY = 114;
  HALF_PIERCING = 115;
  HALF_MAGICAL = 116;
  HOLY_WATER = 117;
  HALF_COLD = 118;
  NEED_MAGIC = 119;
  BOULDER_DODGE = 120;
  ANKHEG_ACID = 121;
  MUMMY_FIRE = 122;
  SILVER_MAGIC = 123;
  HALF_ELF_RESISTANCE = 124;
  NO_CHARM_POISON = 125;
  GAZE_BLOCK = 126;
  ALIGNED_WEAPON = 132;
  { Spiritual Hammer TItemRec.special, run when unreadied }
  SPIRITUAL_HAMMER_GONE = 137;
  { Ring of Invisibility, effect 56 }
  READY_RING_OF_INVISIBILITY = 139;

implementation

end.
