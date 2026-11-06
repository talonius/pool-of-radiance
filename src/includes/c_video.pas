{ The display memory: the EGA framebuffer and the CGA and Tandy display banks. }
unit C_Video;

interface

const
  { visible EGA framebuffer (planar, mode 13) }
  EGA_VIDEO_SEG = $A000;
  { CGA even rows / Tandy bank 0 }
  GFX_BANK0_SEG = $B800;
  { CGA odd rows / Tandy bank 1 }
  GFX_BANK1_SEG = $BA00;
  { Tandy bank 2 }
  GFX_BANK2_SEG = $BC00;
  { Tandy bank 3 }
  GFX_BANK3_SEG = $BE00;

implementation

end.
