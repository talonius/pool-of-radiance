{ Sound: the sound-effect ids, and the soundMode values. }
unit C_Sound;

interface

const
  { weapon hit or blocked-movement bump }
  IMPACT = 3;
  STEP = 6;
  { The Tandy SN76489 chip, chosen by a T in the sound line of POOL.CFG. }
  TANDY = 0;
  { The PC speaker, chosen by a P. }
  SPEAKER = 1;
  { Sound is off, for any other letter or once Ctrl-S turns it off; SoundCommand then does nothing. }
  OFF = 2;

implementation

end.
