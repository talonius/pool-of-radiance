{ EGA graphics-controller setup, page selection and palette register control. }
{$F+}
unit Video;

interface

uses Types, C_Video, C_Ega, GDConsts, GDVars, Dos;

{ Makes page 0 the main page and page 1 the other page and, on EGA, points the page segments at them. }
procedure InitVideoPages;

{ Shows an EGA page (video BIOS function 5) and points egaCurPage at its segment.
  @param(page The page to show.) }
procedure SetupEgaCurrentPage(page: Byte);

{ Points egaOtherPage at the segment of an EGA page.
  @param(page The page.) }
procedure SetupEgaOtherPage(page: Byte);

{ Switches the display to a BIOS video mode, remembering the mode it replaces so RestoreVideoMode can go back. The BIOS
  result is not checked, so an unsupported mode fails silently while the current-mode bookkeeping still records it.
  @param(mode BIOS INT 10h mode number to select.) }
procedure SetVideoMode(mode: Byte);

{ Returns the display to the mode saved by the last SetVideoMode call. That call also saves the mode being replaced, so
  calling this twice in a row toggles between two modes. }
procedure RestoreVideoMode;

{ Fills a character-cell rectangle of an EGA page with one color in write mode 2, then restores write mode 0 and points
  egaOtherPage back at the other page (pageNum).
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(page The EGA page to fill.)
  @param(color The fill color.) }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);

{ Programs one EGA palette register through BIOS INT 10h. Bright colors (8..15) are offset by a further 8 to reach their
  palette values.
  @param(registerIndex Palette register to change.)
  @param(color Logical color to assign to that register, 0..15.) }
procedure SetPaletteRegister(registerIndex, color: Byte);

{ Resets the EGA graphics controller (registers 0 to 5 to 0, color don't-care $0F, bit mask $FF) and enables writes to
  the four planes. }
procedure ResetEgaGc;

implementation

procedure InitVideoPages;
begin
  GDVars.pageMain := 0;
  GDVars.pageNum := 1;
  case GDVars.videoMode of
    Types.Cga: ;
    Types.Ega: begin
      Video.SetupEgaCurrentPage(GDVars.pageMain);
      Video.SetupEgaOtherPage(GDVars.pageNum);
    end;
    Types.Tandy: ;
  end;
end;

procedure SetupEgaCurrentPage(page: Byte);
begin
  GDVars.interruptRegs.ah := 5;
  GDVars.interruptRegs.al := page;
  Intr($10, Registers(GDVars.interruptRegs));
  GDVars.egaCurPage := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

procedure SetupEgaOtherPage(page: Byte);
begin
  GDVars.egaOtherPage := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

procedure SetVideoMode(mode: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  oldMode: Word;
begin
  GDVars.savedVideoMode := GDVars.curVideoMode;
  GDVars.interruptRegs.ah := 0;
  GDVars.interruptRegs.al := mode;
  Intr($10, Registers(GDVars.interruptRegs));
  GDVars.curVideoMode := mode;
end;

procedure RestoreVideoMode;
begin
  Video.SetVideoMode(GDVars.savedVideoMode);
end;

procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);
var
  savedPage: Byte;
  dstOff: Word;
  rowCount: Word;
  i: Word;
begin
  savedPage := GDVars.pageNum;
  dstOff := Word(ulRow) * 40 * 8 + ulCol;
  rowCount := (lrRow - ulRow + 1) * 8 - 1;
  Video.SetupEgaOtherPage(page);
  Video.ResetEgaGc;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
  Port[C_Ega.GC_DATA_PORT] := 2;
  for i := 0 to rowCount do begin
    FillChar(Mem[GDVars.egaOtherPage: dstOff], lrCol - ulCol + 1, color);
    Inc(dstOff, 40);
  end;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
  Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
  GDVars.pageNum := savedPage;
  Video.SetupEgaOtherPage(GDVars.pageNum);
end;

procedure SetPaletteRegister(registerIndex, color: Byte);
begin
  GDVars.interruptRegs.ah := $10;
  GDVars.interruptRegs.al := 0;
  if color < 8 then
    GDVars.interruptRegs.bh := color
  else
    GDVars.interruptRegs.bh := color + 8;
  GDVars.interruptRegs.bl := registerIndex;
  Intr($10, Registers(GDVars.interruptRegs));
end;

procedure ResetEgaGc;
begin
  Port[C_Ega.GC_ADDR_PORT] := 0;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 1;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 2;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 3;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 4;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 5;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 7;
  Port[C_Ega.GC_DATA_PORT] := $0F;
  Port[C_Ega.GC_ADDR_PORT] := 8;
  Port[C_Ega.GC_DATA_PORT] := $FF;
  Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
  Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
end;

begin
end.
