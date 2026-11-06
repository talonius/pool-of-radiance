{ Class values (TCharRecord.charClass): single classes 0..7, then multiclass combinations 8..16; and the class-level
  slots that index classLevels. }
unit C_Class;

interface

const
  CLERIC = 0;
  FIGHTER = 2;
  MAGE = 5;
  CLERIC_FIGHTER = 8;
  CLERIC_FIGHTER_MAGE = 9;
  CLERIC_RANGER = 10;
  FIGHTER_THIEF = 14;
  FIGHTER_MAGE_THIEF = 15;
  MAGE_THIEF = 16;
  { classLevels indices }
  CLERIC_LEVEL = 0;
  FIGHTER_LEVEL = 2;
  MAGE_LEVEL = 5;
  THIEF_LEVEL = 6;
  MONK_LEVEL = 7;

implementation

end.
