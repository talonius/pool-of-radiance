{ TCharRecord.npc values. }
unit C_Npc;

interface

const
  { TCharRecord.npc packing: bit 7 marks a non-player character; bits 0..6 hold morale }
  { bit 7: a non-player character }
  NON_PLAYER = $80;
  { bits 0..6: morale }
  MORALE_MASK = $7F;
  { Animated NPC or mirror-duel clone; prior morale is not restored. }
  ANIMATED_CREATURE = $B2;
  { Animated party member or charm marker; removal resets it to zero. }
  ANIMATED_MEMBER = $B3;

implementation

end.
