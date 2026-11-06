{ Script-visible game-memory addresses. }
unit C_Gbvm;

interface

const
  { Script-visible game-memory addresses, used as word-array indices through the zone pointers. }
  { zone 1 ($6B00 bank: zone1) }
  { actual monster distance (0..2) }
  MONSTER_DISTANCE = $6DC1;
  { morale-check % threshold }
  MORALE_THRESHOLD = $6DC6;
  { 255 => party X/Y move locked }
  MOVE_LOCKED = $6DC9;
  { bit0 Search on, bit1 Look pending }
  SEARCH_FLAGS = $6DCA;
  { surprise state for next combat }
  SURPRISE = $6DCB;
  { uninterrupted rest time (min/5) }
  REST_SAFE_TIME = $6DD2;
  { % chance rest interrupted }
  REST_INTERRUPT_PERCENT = $6DD3;
  { 1 => party to leave current map }
  LEAVE_MAP = $6DD5;
  { picture loading (255 = none) }
  PICTURE_LOADING = $6DE1;
  { 1 => next combat is a mirror duel }
  MIRROR_DUEL = $6DE6;
  { 1 => party attacked allies last fight }
  ATTACKED_ALLIES = $6E33;
  { party size }
  PARTY_SIZE = $6E3E;
  { int8 ad-hoc monster THAC0 modifier }
  MONSTER_THAC0_MODIFIER = $6E70;
  { int8 ad-hoc party THAC0 modifier }
  PARTY_THAC0_MODIFIER = $6E71;
  { int8 ad-hoc party movement modifier }
  PARTY_MOVE_MODIFIER = $6E72;

implementation

end.
