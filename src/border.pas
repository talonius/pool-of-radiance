{ Text-window borders, rectangle clearing and centered titles. Borders use the 8x8 symbol set. }
{$O+,F+}
unit Border;

interface

uses Types, TextRend, Sym8x8, Video, Crt, C_Video, GDConsts, GDVars;

{ Draws a border one cell outside a rectangle of character cells, in 8x8 symbols: the corner symbol at the four corners,
  the horizontal symbol along the top and bottom and the vertical symbol down both sides.
  @param(ulCol Left column inside the border.)
  @param(ulRow Top row inside the border.)
  @param(lrCol Right column inside the border.)
  @param(lrRow Bottom row inside the border.)
  @param(corner The border style; each style is three consecutive symbols from SYMBOL_BASE.) }
procedure DrawBorder(ulCol, ulRow, lrCol, lrRow: ShortInt; corner: Byte);

{ Clears a rectangle of character cells, corners included, to color 0 directly in video memory. CGA clears the four
  scanlines of each cell row in both of its banks, EGA clears both display pages through Video.FillRectEga, and Tandy
  clears two scanlines in each of its four banks.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

{ Opens a window: clears a rectangle of character cells, draws a border around it and centers a title on its top row.
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window; the title goes on this row.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(corner The border style, as DrawBorder takes it.)
  @param(color Text color of the title.)
  @param(title The title; an empty title draws nothing.) }
procedure DrawWindow(ulCol, ulRow, lrCol, lrRow: ShortInt; corner, color: Byte; title: Types.TStr40);

implementation

const
  SYMBOL_BASE = 276;

var
  { CGA and Tandy interleave scanlines across video-memory banks. Advancing a row changes the segment: CGA uses two
    banks and Tandy uses four. }
  cgaBank0: Types.TCgaBank absolute C_Video.GFX_BANK0_SEG:0;
  cgaBank1: Types.TCgaBank absolute C_Video.GFX_BANK1_SEG:0;
  tandyBank0: Types.TTandyBank absolute C_Video.GFX_BANK0_SEG:0;
  tandyBank1: Types.TTandyBank absolute C_Video.GFX_BANK1_SEG:0;
  tandyBank2: Types.TTandyBank absolute C_Video.GFX_BANK2_SEG:0;
  tandyBank3: Types.TTandyBank absolute C_Video.GFX_BANK3_SEG:0;

procedure DrawBorder(ulCol, ulRow, lrCol, lrRow: ShortInt; corner: Byte);
var
  i: ShortInt;
  symBase: Word;
begin
  Dec(ulCol);
  Dec(ulRow);
  Inc(lrCol);
  Inc(lrRow);
  symBase := corner * 3 + Border.SYMBOL_BASE;
  Sym8x8.Put8x8Sym(ulCol, ulRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(lrCol, ulRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(ulCol, lrRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(lrCol, lrRow, symBase + 0, False, False);
  for i := ulCol + 1 to lrCol - 1 do begin
    Sym8x8.Put8x8Sym(i, ulRow, symBase + 2, False, False);
    Sym8x8.Put8x8Sym(i, lrRow, symBase + 2, False, False);
  end;
  for i := ulRow + 1 to lrRow - 1 do begin
    Sym8x8.Put8x8Sym(ulCol, i, symBase + 1, False, False);
    Sym8x8.Put8x8Sym(lrCol, i, symBase + 1, False, False);
  end;
end;

procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  top: Word;
  bot: Word;
  colOff: Word;
  rowBytes: Word;
  r: Word;
begin
  case GDVars.videoMode of
    Types.Cga: begin
      top := ulRow * 4;
      bot := lrRow * 4 + 3;
      rowBytes := (lrCol - ulCol + 1) * 2;
      for r := top to bot do begin
        FillChar(cgaBank0[r][Word(ulCol) * 2], rowBytes, 0);
        FillChar(cgaBank1[r][Word(ulCol) * 2], rowBytes, 0);
      end;
    end;
    Types.Ega: begin
      Video.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, Black);
      Video.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, Black);
    end;
    Types.Tandy: begin
      top := ulRow * 2;
      bot := lrRow * 2 + 1;
      colOff := ulCol * 4;
      rowBytes := (lrCol - ulCol + 1) * 4;
      for r := top to bot do begin
        FillChar(tandyBank0[r][colOff], rowBytes, 0);
        FillChar(tandyBank1[r][colOff], rowBytes, 0);
        FillChar(tandyBank2[r][colOff], rowBytes, 0);
        FillChar(tandyBank3[r][colOff], rowBytes, 0);
      end;
    end;
  end;
end;

procedure DrawWindow(ulCol, ulRow, lrCol, lrRow: ShortInt; corner, color: Byte; title: Types.TStr40);
begin
  Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
  Border.DrawBorder(ulCol, ulRow, lrCol, lrRow, corner);
  if Length(title) <> 0 then
    TextRend.DisplayString((ulCol + lrCol - Length(title)) div 2, ulRow, color, title);
end;

begin
end.
