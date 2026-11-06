{ Spell values: the pending flag and id mask of a spell slot, and named spell ids. }
unit C_Spell;

interface

const
  PENDING_FLAG = $80;
  ID_MASK = $7F;
  { Spell IDs index GDVars.spellHandlers.spells: 1..56 are spells and 57..67 are item effects. }
  { no spell selected (SpellMenu exit/cancel) }
  NO_SPELL = 0;
  { The AI casts it only when it finds a creature to cure. }
  CURE_LIGHT_WOUNDS = 3;

implementation

end.
