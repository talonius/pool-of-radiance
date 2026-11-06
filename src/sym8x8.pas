{ Load and draw 8x8 symbol sets. }
{$O+,F+}
{$I-}
unit Sym8x8;

interface

uses Crt, GDConsts, GDVars, Blit, GameIo;

{ Empty routine with no callers. }
procedure Noop8x8;

{ Loads an 8x8 symbol set from 8X8D<disk>.DAX, with a transparency mask for light magenta, then discards pending keys. A
  load failure prints the file name and block, waits for a key and exits to DOS.
  @param(fileId The block of the DAX file that holds the set.)
  @param(setId The symbol-set slot to fill, 0 to 4; any other value loads nothing.) }
procedure Load8x8Set(fileId, setId: Byte);

{ Draws one 8x8 symbol at a character cell. Symbols 1 to 286 are numbered across the five sets; the symbol's set and its
  frame in that set follow from the number. Nothing is drawn when the set is not loaded. Symbol 0 or 287 to 32767 prints
  an error, waits for a key and exits to DOS. Note: a symbol above 32767 matches no case and uses an unset set index.
  @param(col Column of the cell.)
  @param(row Row of the cell.)
  @param(symbol The symbol, 1 to 286.)
  @param(inCombat True to draw into the view buffer, to be flushed later; False to draw straight to the screen.)
  @param(other True to draw transparently; read only when inCombat is True.) }
procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, other: Boolean);

implementation

procedure Load8x8Set(fileId, setId: Byte);
var
  diskText: String[1];
  fileText: String[3];
  { Unused in this version; see the other implementations of this routine. }
  setSlot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if setId in [0..4] then begin
    Str(GDVars.virtualDisk, diskText);
    Str(fileId, fileText);
    Blit.LoadPic('8x8d' + diskText, fileId, True, LightMagenta, GDVars.symbolSets[setId]);
    if GDVars.symbolSets[setId] = nil then begin
      Blit.RestoreVideoMode;
      WriteLn('Unable to load 8x8D' + diskText + '-' + fileText);
      ch := GameIo.ReadGameKey;
      Blit.RestoreVideoMode;
      GameIo.ExitGame;
    end;
    GameIo.DiscardPendingKeys;
  end;
end;

procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, other: Boolean);
var
  setIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  case symbol of
    1..45: setIdx := 0;
    46..115: setIdx := 1;
    116..185: setIdx := 2;
    186..255: setIdx := 3;
    256..286: setIdx := 4;
    0, 287..32767: begin
      Blit.RestoreVideoMode;
      WriteLn('Bad symbol number in Put8x8Symbol.');
      ch := GameIo.ReadGameKey;
      GameIo.ExitGame;
    end;
  end;
  if GDVars.symbolSets[setIdx] <> nil then begin
    Dec(symbol, GDConsts.symSetFirst[setIdx]);
    if inCombat then
      Blit.BlitTileCell(col, row, symbol, Ord(other), GDVars.symbolSets[setIdx], GDVars.viewBuffer)
    else begin
      with GDVars.symbolSets[setIdx]^ do
        Move(data[symbol * imgSize], GDVars.curSymbolSet^.data, imgSize);
      Blit.ShowPic(col, row, GDVars.curSymbolSet);
    end;
  end;
end;

procedure Noop8x8;
begin
end;

begin
end.
