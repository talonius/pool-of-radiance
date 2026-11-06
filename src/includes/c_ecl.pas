{ ECL script opcodes, plus the search entry-header slot. }
unit C_Ecl;

interface

const
  { Entry-header slot used for search and Look }
  SEARCH_ENTRY = 2;
  OP_GOTO = $01;
  GOSUB = $02;
  COMPARE = $03;
  ADD = $04;
  MULTIPLY = $07;
  OP_RANDOM = $08;
  SAVE = $09;
  LOAD_CHARACTER = $0A;
  LOAD_MONSTER = $0B;
  SETUP_MONSTER = $0C;
  PICTURE = $0E;
  INPUT_NUMBER = $0F;
  INPUT_STRING = $10;
  PRINT = $11;
  PRINT_CLEAR = $12;
  COMPARE_AND = $14;
  PARTY_STRENGTH = $1D;
  CHECK_PARTY = $1E;
  NEW_ECL = $20;
  LOAD_FILES = $21;
  PARTY_SURPRISE = $22;
  SURPRISE = $23;
  TREASURE = $27;
  ROB = $28;
  ENCOUNTER = $29;
  GET_TABLE = $2A;
  PARLAY = $2C;
  CALL = $2D;
  DAMAGE = $2E;
  OP_AND = $2F;
  OP_OR = $30;
  FIND_ITEM = $32;
  CLOCK = $34;
  SAVE_TABLE = $35;
  ADD_NPC = $36;
  LOAD_PIECES = $37;
  OP_PROGRAM = $38;
  WHO = $39;
  SPELL = $3B;
  PROTECTION = $3C;

implementation

end.
