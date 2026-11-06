{ The EGA Sequencer and Graphics Controller ports, registers and register values. }
unit C_Ega;

interface

const
  { Sequencer address register (select which reg) }
  SEQ_ADDR_PORT = $3C4;
  { Sequencer data register (value for selected reg) }
  SEQ_DATA_PORT = $3C5;
  { Sequencer reg 2 = Map Mask (which planes writes hit) }
  SEQ_MAP_MASK_REG = 2;
  { Map Mask = enable all 4 planes (0000_1111) }
  MAP_MASK_ALL_PLANES = $F;
  { Graphics Controller address register }
  GC_ADDR_PORT = $3CE;
  { Graphics Controller data register }
  GC_DATA_PORT = $3CF;
  { GC reg 5 = Mode register }
  GC_MODE_REG = 5;
  { write-mode 0: normal (restore after a latch copy) }
  GC_WRITE_MODE_0 = 0;

implementation

end.
