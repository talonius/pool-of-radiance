{ The game clock's components. }
unit C_Time;

interface

const
  { Game-clock components in GBVM_CLOCK word order: indices into TClock and GDConsts.unitScale, and the tUnit argument
    of GameTime.AdvanceTime }
  MINUTES = 1;
  { ten minutes }
  TURNS = 2;
  HOURS = 3;

implementation

end.
