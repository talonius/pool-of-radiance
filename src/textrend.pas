{ Game-font text rendering, message-window input, centisecond timing, and the EGA page and fill helpers. }
{$O+,F+}
unit TextRend;

interface

uses Types, C_Video, C_Ega, GDConsts, GDVars, DaxIo, Crt, Dos, GameIo, C_Keys;

{ Resets the EGA graphics controller (registers 0 to 5 to 0, color don't-care $0F, bit mask $FF) and enables writes to
  the four planes. }
procedure ResetEgaGc;

{ Shows an EGA page (video BIOS function 5) and points egaCurPage at its segment.
  @param(page The page to show.) }
procedure SetupEgaCurrentPage(page: Byte);

{ Points egaOtherPage at the segment of an EGA page.
  @param(page The page.) }
procedure SetupEgaOtherPage(page: Byte);

{ Fills a character-cell rectangle of an EGA page with one color in write mode 2, then restores write mode 0 and points
  egaOtherPage back at the other page (pageNum).
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(page The EGA page to fill.)
  @param(color The fill color.) }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);

{ Loads the 8x8 game font (block 201 of 8X8D1.DAX) into the font buffer; nothing happens when it is missing. }
procedure LoadGameFont;

{ Draws a run of one game-font character rightward from a cell. Nothing is drawn when the first cell is off the 40x25
  screen or there is no font; the run itself is not clipped. CGA maps the color and writes packed pixels, EGA writes the
  four planes on both pages, and Tandy packs two pixels to a byte across its four banks. Note: CGA maps the color
  through the attribute table once per copy, so each copy after the first maps the mapped color again.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(color The character's color.)
  @param(count How many times to draw it.)
  @param(ch The character, or a font index when isAscii is 0.)
  @param(isAscii Nonzero to upper-case ch and take it mod 64 as the font index.) }
procedure RenderChar(col, row, color, count, ch, isAscii: Byte);

{ Blanks a run of cells; nothing happens when the first cell is off the screen.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(color The color to blank to.)
  @param(count The number of cells.) }
procedure PrintSpaces(col, row, color, count: Byte);

{ Writes a string in the game font from a cell, one character per cell. Nothing is drawn from a column beyond 39 or a
  row beyond 39; RenderChar skips characters off the screen.
  @param(col The first character's column.)
  @param(row The row.)
  @param(color The text color.)
  @param(source The text.) }
procedure DisplayString(col, row, color: Byte; source: string);

{ Writes a string word-wrapped into a window, from the text cursor (curCol, curRow) when it is inside the window, else,
  or after clearing with clearFirst, from the top left. Punctuation (breakChars) stays with the word before it.
  Characters appear one by one with the text delay while msgDelayFlag is on. When the window fills with text left over,
  it waits for a key and goes on in the cleared window. The text cursor is left after the text. Nothing is written when
  a corner lies off the screen.
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(color The text color.)
  @param(clearFirst True to clear the window and start at its top left.)
  @param(source The text.) }
procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, color: Byte; clearFirst: Boolean; source: string);

{ Shows a prompt on the bottom row and reads text, echoed in white: a space through z is added while there is room and
  backspace deletes, until Enter or Escape. The row is cleared afterwards.
  @param(query The prompt.)
  @param(color The prompt's color.)
  @param(maxLen The most characters accepted.)
  @returns(The text typed, upper-cased; Escape returns it too.) }
function ReadString(query: Types.TStr40; color, maxLen: Byte): Types.TStr40;

{ Reads numbers of up to six characters (ReadString) until one parses within 0 to 65536. Note: 65536 is accepted and
  becomes 0.
  @param(query The prompt.)
  @param(color The prompt's color.)
  @returns(The number.) }
function ReadNumber(query: Types.TStr40; color: Byte): Word;

{ Shows a message on the bottom row and waits for a key; the message stays.
  @param(color The text color.)
  @param(msg The message.) }
procedure DisplayAndPause(color: Byte; msg: Types.TStr40);

{ Reads the time of day. Note: the minutes are multiplied in 16 bits, which overflows, so the value can jump back within
  an hour.
  @returns(The time since midnight in hundredths of a second.) }
function GetTicks: LongInt;

{ Clears the whole screen to black: both EGA pages, or each CGA or Tandy bank. }
procedure ClearScreen;

{ Shows a message on the bottom row for gameDelay * 225 milliseconds (PauseOnly), then clears the row.
  @param(msg The message.)
  @param(color The text color.) }
procedure PrintAndPause(msg: Types.TStr40; color: Byte);

{ Waits gameDelay * 225 milliseconds. }
procedure PauseOnly;

{ Clears a character-cell rectangle to black, on both EGA pages.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);

implementation

type
  TCgaRow = array[0..39] of Word;
  TTdyRow = array[0..159] of Byte;

var

  cgaEvenRows: array[0..255] of TCgaRow absolute C_Video.GFX_BANK0_SEG:$0000;
  cgaOddRows: array[0..255] of TCgaRow absolute C_Video.GFX_BANK1_SEG:$0000;
  tandyBank0: array[0..255] of TTdyRow absolute C_Video.GFX_BANK0_SEG:$0000;
  tandyBank1: array[0..255] of TTdyRow absolute C_Video.GFX_BANK1_SEG:$0000;
  tandyBank2: array[0..255] of TTdyRow absolute C_Video.GFX_BANK2_SEG:$0000;
  tandyBank3: array[0..255] of TTdyRow absolute C_Video.GFX_BANK3_SEG:$0000;

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
  TextRend.SetupEgaOtherPage(page);
  TextRend.ResetEgaGc;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
  Port[C_Ega.GC_DATA_PORT] := 2;
  for i := 0 to rowCount do begin
    FillChar(Mem[GDVars.egaOtherPage: dstOff], lrCol - ulCol + 1, color);
    Inc(dstOff, 40);
  end;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
  Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
  GDVars.pageNum := savedPage;
  TextRend.SetupEgaOtherPage(GDVars.pageNum);
end;

procedure LoadGameFont;
var
  compSize: Word;
  dataPtr: Types.PByteArr;
begin
  DaxIo.LoadDax('8X8d1', '.dax', 201, compSize, dataPtr);
  if compSize = 0 then Exit;
  Move(dataPtr^, GDVars.gameFont^, compSize);
  FreeMem(dataPtr, compSize);
end;

procedure RenderChar(col, row, color, count, ch, isAscii: Byte);
var
  i: Byte;
  charIdx: Byte;
  dstOff: Word;
  cnt: Word;
  colBase: Word;
  cgaWord: Word;
  tandyPx: Byte;
  k: Byte;
  mask: Byte;
  bank: Byte;
  outerRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  plane: Byte;
begin
  if (col > 39) or (row > 24) or (GDVars.gameFont = nil) then Exit;
  if isAscii <> 0 then
    charIdx := Ord(UpCase(Chr(ch))) mod 64
  else
    charIdx := ch;
  for i := 1 to count do begin
    case GDVars.videoMode of
      Types.Cga: begin
        color := GDConsts.attrTable[color];
        dstOff := row * 4;
        cnt := 0;
        for outerRow := 0 to 3 do begin
          cgaWord := 0;
          mask := $80;
          for k := 0 to 7 do begin
            if (GDVars.gameFont^[charIdx][cnt] and mask) > 0 then
              cgaWord := cgaWord or (GDConsts.cgaPixelMask[k] and GDConsts.cgaColorPat[color]);
            mask := mask shr 1;
          end;
          cgaEvenRows[dstOff][col] := Swap(cgaWord);
          Inc(cnt);
          cgaWord := 0;
          mask := $80;
          for k := 0 to 7 do begin
            if (GDVars.gameFont^[charIdx][cnt] and mask) > 0 then
              cgaWord := cgaWord or (GDConsts.cgaPixelMask[k] and GDConsts.cgaColorPat[color]);
            mask := mask shr 1;
          end;
          cgaOddRows[dstOff][col] := Swap(cgaWord);
          Inc(cnt);
          Inc(dstOff);
        end;
      end;
      Types.Ega: begin
        dstOff := (row * 8) * 40 + col;
        Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
        for outerRow := 0 to 7 do begin
          for k := 0 to 3 do begin
            Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneMask[3 - k];
            if (GDConsts.egaPlaneMask[3 - k] and color) > 0 then begin
              Mem[GDVars.egaCurPage: dstOff] := GDVars.gameFont^[charIdx][outerRow];
              Mem[GDVars.egaOtherPage: dstOff] := GDVars.gameFont^[charIdx][outerRow];
            end else begin
              Mem[GDVars.egaCurPage: dstOff] := 0;
              Mem[GDVars.egaOtherPage: dstOff] := 0;
            end;
          end;
          Inc(dstOff, 40);
        end;
        Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
      end;
      Types.Tandy: begin
        dstOff := 0;
        cnt := row * 2;
        colBase := col * 4;
        for outerRow := 0 to 1 do begin
          for bank := 0 to 3 do begin
            mask := $80;
            for k := 0 to 3 do begin
              if (GDVars.gameFont^[charIdx][dstOff] and mask) > 0 then
                tandyPx := color shl 4
              else
                tandyPx := 0;
              mask := mask shr 1;
              if (GDVars.gameFont^[charIdx][dstOff] and mask) > 0 then
                tandyPx := tandyPx or color;
              mask := mask shr 1;
              case bank of
                0: tandyBank0[cnt][k + colBase] := tandyPx;
                1: tandyBank1[cnt][k + colBase] := tandyPx;
                2: tandyBank2[cnt][k + colBase] := tandyPx;
                3: tandyBank3[cnt][k + colBase] := tandyPx;
              end;
            end;
            Inc(dstOff);
          end;
          Inc(cnt);
        end;
      end;
    end;
    Inc(col);
  end;
end;

procedure PrintSpaces(col, row, color, count: Byte);
begin
  if (col < 0) or (col > 39) or (row < 0) or (row > 24) then Exit;
  TextRend.RenderChar(col, row, color, count, 32, 1);
end;

procedure DisplayString(col, row, color: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  if (col > 39) or (row > 39) then Exit;
  n := Length(source);
  for i := 1 to n do begin
    TextRend.RenderChar(col, row, color, 1, Ord(source[i]), 1);
    Inc(col);
  end;
end;

procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, color: Byte; clearFirst: Boolean; source: string);
var
  len: Byte;
  { Unused in this version; see the other implementations of this routine. }
  width: Byte;
  idx: Byte;
  lineEnd: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lineStart: Byte;

  { Writes the word from idx to lineEnd at the text cursor, with the text delay while it is on. }
  procedure PrintCharInWindow;
  begin
    while idx <= lineEnd do begin
      TextRend.RenderChar(GDVars.curCol, GDVars.curRow, color, 1, Ord(source[idx]), 1);
      if GDVars.msgDelayFlag <> 0 then Delay(GDVars.gameDelay * 10);
      Inc(idx);
      Inc(GDVars.curCol);
    end;
  end;

  { Skips the spaces a line break consumed. }
  procedure FindNewIndex;
  begin
    while (idx < len) and (source[idx] = ' ') do Inc(idx);
  end;

begin
  if (ulCol > 39) or (ulRow > 24) or (lrCol > 39) or (lrRow > 39) then Exit;
  if (GDVars.curCol < ulCol) or (GDVars.curCol > lrCol) or (GDVars.curRow < ulRow) or
      (GDVars.curRow > lrRow) then begin
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
  end;
  if clearFirst then begin
    TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
  end;
  idx := 1;
  len := Length(source);
  if len = 0 then Exit;
  width := lrCol - ulCol + 1;
  repeat
    lineEnd := idx;
    while (lineEnd < len) and (source[lineEnd] in GDConsts.breakChars) do
      Inc(lineEnd);
    while (lineEnd < len) and not (source[lineEnd] in GDConsts.breakChars) and (source[lineEnd] <> ' ') do
      Inc(lineEnd);
    if source[lineEnd] <> ' ' then
      while (lineEnd + 1 < len) and (source[lineEnd + 1] in GDConsts.breakChars) do
        Inc(lineEnd);
    if lineEnd - idx + GDVars.curCol > lrCol then begin
      if (lineEnd - idx + GDVars.curCol = lrCol) and (source[lineEnd] = ' ') then begin
        Dec(lineEnd);
        PrintCharInWindow;
      end;
      GDVars.curCol := ulCol;
      Inc(GDVars.curRow);
      FindNewIndex;
      if (GDVars.curRow > lrRow) and (idx < len) then begin
        GDVars.curCol := ulCol;
        GDVars.curRow := ulRow;
        TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
        GameIo.DiscardPendingKeys;
        TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
        PrintCharInWindow;
      end;
    end else
      PrintCharInWindow;
  until idx > len;
  if GDVars.curCol > lrCol then begin
    GDVars.curCol := ulCol;
    Inc(GDVars.curRow);
  end;
end;

function ReadString(query: Types.TStr40; color, maxLen: Byte): Types.TStr40;
var
  col: Byte;
  reply: string;
  key: Char;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, query);
  col := Length(query);
  reply := '';
  repeat
    key := GameIo.ReadGameKey;
    case key of
      ' '..'z':
        if Length(reply) < maxLen then begin
          reply := reply + key;
          Inc(col);
          TextRend.DisplayString(col, 24, White, key);
        end;
      C_Keys.BACKSPACE:
        if Length(reply) > 0 then begin
          reply := Copy(reply, 1, Length(reply) - 1);
          TextRend.PrintSpaces(col, 24, Black, 1);
          Dec(col);
        end;
    end;
  until (key = C_Keys.ENTER) or (key = C_Keys.ESCAPE);
  TextRend.PrintSpaces(0, 24, Black, 40);
  for col := 1 to Length(reply) do
    reply[col] := UpCase(reply[col]);
  ReadString := reply;
end;

function ReadNumber(query: Types.TStr40; color: Byte): Word;
var
  num: LongInt;
  reply: Types.TStr40;
  code: Integer;
begin
  repeat
    reply := TextRend.ReadString(query, color, 6);
    Val(reply, num, code);
    if code = 0 then
      if (num > 65536) or (num < 0) then code := 1;
  until code = 0;
  ReadNumber := num;
end;

procedure DisplayAndPause(color: Byte; msg: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, msg);
  key := GameIo.ReadGameKey;
end;

function GetTicks: LongInt;
var
  hours: Word;
  minutes: Word;
  seconds: Word;
  hundredths: Word;
begin
  GetTime(hours, minutes, seconds, hundredths);
  GetTicks := LongInt(hours) * 360000 + minutes * 6000 + seconds * 100 + hundredths;
end;

procedure ClearScreen;
begin
  case GDVars.videoMode of
    Types.Cga: begin
      FillChar(cgaOddRows, SizeOf(Types.TCgaBank), 0);
      FillChar(cgaEvenRows, SizeOf(Types.TCgaBank), 0);
    end;
    Types.Ega: begin
      TextRend.FillRectEga(0, 0, 39, 24, 0, Black);
      TextRend.FillRectEga(0, 0, 39, 24, 1, Black);
    end;
    Types.Tandy: begin
      FillChar(tandyBank0, SizeOf(Types.TTandyBank), 0);
      FillChar(tandyBank1, SizeOf(Types.TTandyBank), 0);
      FillChar(tandyBank2, SizeOf(Types.TTandyBank), 0);
      FillChar(tandyBank3, SizeOf(Types.TTandyBank), 0);
    end;
  end;
end;

procedure PrintAndPause(msg: Types.TStr40; color: Byte);
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, msg);
  TextRend.PauseOnly;
  TextRend.PrintSpaces(0, 24, Black, 40);
end;

procedure PauseOnly;
begin
  Delay(GDVars.gameDelay * 225);
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  firstRow: Word;
  lastRow: Word;
  firstByteColumn: Word;
  byteCount: Word;
  row: Word;
begin
  case GDVars.videoMode of
    Types.Cga: begin
      firstRow := ulRow * 4;
      lastRow := lrRow * 4 + 3;
      byteCount := (lrCol - ulCol + 1) * 2;
      for row := firstRow to lastRow do begin
        FillChar(cgaEvenRows[row][ulCol], byteCount, 0);
        FillChar(cgaOddRows[row][ulCol], byteCount, 0);
      end;
    end;
    Types.Ega: begin
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, Black);
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, Black);
    end;
    Types.Tandy: begin
      firstRow := ulRow * 2;
      lastRow := lrRow * 2 + 1;
      firstByteColumn := ulCol * 4;
      byteCount := (lrCol - ulCol + 1) * 4;
      for row := firstRow to lastRow do begin
        FillChar(tandyBank0[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank1[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank2[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank3[row][firstByteColumn], byteCount, 0);
      end;
    end;
  end;
end;

begin
end.
