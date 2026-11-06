{ BIOS text output, bottom-line prompts, rounded memory allocation and DAX archive loading. }
{$O+,F+}
unit DaxIo;

interface

uses Types, Crt, GDConsts, GDVars, Dos, GameIo;

type
  TStr20 = string[20];

{ Frees a block allocated by AllocRounded, with the same rounding of its size.
  @param(p The block.)
  @param(n The size it was allocated with.) }
procedure FreeRounded(var p: Pointer; n: Word);

{ Allocates a block with its size rounded up to a multiple of eight bytes.
  @param(p Receives the block.)
  @param(n The size wanted.) }
procedure AllocRounded(var p: Pointer; n: Word);

{ Writes copies of a character through the BIOS on the main text page, and on EGA on the other page as well. On CGA the
  attribute is first mapped through the EGA-to-CGA attribute table. Note: the attribute is not checked against the
  table's size.
  @param(col Column of the first copy.)
  @param(row Row of the copies.)
  @param(attr Text attribute.)
  @param(count Number of copies.)
  @param(ch The character.) }
procedure WriteChar(col, row, attr, count, ch: Byte);

{ Writes a string through the BIOS, one character at a time.
  @param(col Column of the first character.)
  @param(row Row of the string.)
  @param(attr Text attribute.)
  @param(source The string.) }
procedure WriteString(col, row, attr: Byte; source: string);

{ Writes a run of solid block characters through the BIOS.
  @param(col Column of the first block.)
  @param(row Row of the run.)
  @param(attr Text attribute.)
  @param(count Number of blocks.) }
procedure WriteBlock(col, row, attr, count: Byte);

{ Shows a prompt on the bottom row, waits for a key and clears the row again.
  @param(attr Text attribute of the prompt.)
  @param(message The prompt.) }
procedure PromptBox(attr: Byte; message: Types.TStr40);

{ Waits until GAME.OVR can be found, asking for the overlay disk and a key between tries. }
procedure OverlayPrompt;

{ Opens a file for reading in bytes, asking for its disk with a bottom-row prompt and trying again until it is found,
  unless prompts are suppressed.
  @param(fileName The file to open.)
  @param(promptMsg The prompt shown while the file is missing.)
  @param(noPrompt #0 to prompt and retry; anything else tries once.)
  @param(f Receives the open file.)
  @returns(True when the file was found and opened.) }
function OpenWithRetry(fileName, promptMsg: Types.TStr40; noPrompt: Char; var f: file): Boolean;

{ Tells whether a file can be opened, keeping the I/O result in ioErr.
  @param(name The file name.)
  @returns(True when the name is not empty and the file opened.) }
function FileExists(name: Types.TStr40): Boolean;

{ Removes occurrences of a substring in one left-to-right pass. After a deletion the scan moves on, so an occurrence
  that slides into the deleted place is kept: adjacent repeats lose every other copy.
  @param(src The string to clean.)
  @param(del The substring to remove.)
  @returns(The cleaned string.) }
function SanitizeString(src, del: string): string;

{ Makes a file name from a string: removes the characters a DOS file name cannot hold, in SanitizeString's single pass,
  keeps the first eight characters and uppercases them.
  @param(name The string.)
  @returns(The file name.) }
function SanitizeFileName(name: string): Types.TStr40;

{ Expands DAX run-length data. A control byte from 0 to $7E copies the next control + 1 bytes; one from $81 to $FF
  repeats the next byte -control times. The data is read at least once, even when it is empty, and neither buffer's
  bounds are checked. Note: control bytes $7F and $80 do not advance the input, so such data loops forever.
  @param(src The compressed data.)
  @param(dst Receives the expanded data.)
  @param(lenCompressed Length of the compressed data.)
  @param(lenDecompressed Unused.) }
procedure DecompressDaxBuffer(var src, dst: Types.PByteArr; var lenCompressed, lenDecompressed: Word);

{ Opens a DAX archive twice: one handle for its directory, the other placed at the data area that follows the two-byte
  header size and the directory. A missing archive asks for the current virtual disk, unless disk prompts are
  suppressed.
  @param(dirName The archive's name, with its directory.)
  @param(ext The archive's extension.)
  @param(headerSize Receives the size of the header size and the directory together.)
  @param(dataFile Receives the handle placed at the data area.)
  @param(dirFile Receives the handle placed at the directory.)
  @returns(True when the archive was opened.) }
function OpenDax(dirName, ext: TStr20; var headerSize: Word; var dataFile, dirFile: file): Boolean;

{ Closes both handles of a DAX archive.
  @param(dataFile The data handle.)
  @param(dirFile The directory handle.) }
procedure CloseDax(var dataFile, dirFile: file);

{ Loads one block of a DAX archive in the game directory into a new buffer, expanded. A directory entry with a
  compressed size above 36000 shows a tempsize prompt and exits to DOS.
  @param(fileName The archive's name.)
  @param(ext The archive's extension.)
  @param(fileId The block.)
  @param(sizeRead Receives the expanded size; 0 when the archive cannot be opened or holds no such block.)
  @param(data Receives the buffer; nil when the archive cannot be opened or holds no such block.) }
procedure LoadDax(fileName, ext: TStr20; fileId: Byte; var sizeRead: Word; var data: Types.PByteArr);

{ Selects another virtual disk, remembering the current one for PopState.
  @param(v The virtual disk to select.) }
procedure PushState(v: Byte);

{ Selects the virtual disk that PushState remembered. }
procedure PopState;

implementation

procedure FreeRounded(var p: Pointer; n: Word);
begin
  FreeMem(p, (n + 7) and $FFF8);
end;

procedure AllocRounded(var p: Pointer; n: Word);
begin
  GetMem(p, (n + 7) and $FFF8);
end;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  GDVars.interruptRegs.ah := 2;
  GDVars.interruptRegs.bh := GDVars.pageMain;
  GDVars.interruptRegs.dh := row;
  GDVars.interruptRegs.dl := col;
  Intr($10, Registers(GDVars.interruptRegs));
  GDVars.interruptRegs.ah := 9;
  GDVars.interruptRegs.al := ch;
  GDVars.interruptRegs.bh := GDVars.pageMain;
  if GDVars.videoMode = Types.Cga then
    GDVars.interruptRegs.bl := GDConsts.attrTable[attr]
  else
    GDVars.interruptRegs.bl := attr;
  GDVars.interruptRegs.cx := count;
  Intr($10, Registers(GDVars.interruptRegs));
  if GDVars.videoMode = Types.Ega then begin
    GDVars.interruptRegs.ah := 2;
    GDVars.interruptRegs.bh := GDVars.pageNum;
    GDVars.interruptRegs.dh := row;
    GDVars.interruptRegs.dl := col;
    Intr($10, Registers(GDVars.interruptRegs));
    GDVars.interruptRegs.ah := 9;
    GDVars.interruptRegs.al := ch;
    GDVars.interruptRegs.bh := GDVars.pageNum;
    GDVars.interruptRegs.bl := attr;
    GDVars.interruptRegs.cx := count;
    Intr($10, Registers(GDVars.interruptRegs));
  end;
end;

procedure WriteString(col, row, attr: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  n := Length(source);
  for i := 1 to n do begin
    DaxIo.WriteChar(col, row, attr, 1, Ord(source[i]));
    Inc(col);
  end;
end;

procedure WriteBlock(col, row, attr, count: Byte);
begin
  DaxIo.WriteChar(col, row, attr, count, 219);
end;

procedure PromptBox(attr: Byte; message: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  DaxIo.WriteBlock(0, 24, Black, 40);
  DaxIo.WriteString(0, 24, attr, message);
  key := GameIo.ReadGameKey;
  DaxIo.WriteBlock(0, 24, Black, 40);
end;

{$I-}

procedure OverlayPrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  found: Boolean;
begin
  repeat
    found := DaxIo.FileExists('game.ovr');
    if not found then begin
      WriteLn('Please insert overlay disk.');
      key := GameIo.ReadGameKey;
    end;
  until found;
end;

function OpenWithRetry(fileName, promptMsg: Types.TStr40; noPrompt: Char; var f: file): Boolean;
var found: Boolean;
begin
  repeat
    found := DaxIo.FileExists(fileName);
    if (not found) and (noPrompt = #0) then
      DaxIo.PromptBox(Yellow, promptMsg);
  until found or (noPrompt <> #0);
  if found then begin
    Assign(f, fileName);
    Reset(f, 1);
  end;
  OpenWithRetry := found;
end;

function FileExists(name: Types.TStr40): Boolean;
var f: file;
begin
  Assign(f, name);
  Reset(f, 128);
  Close(f);
  GDVars.ioErr := IOResult;
  FileExists := (GDVars.ioErr = 0) and (name <> '');
end;

{$I+}

function SanitizeString(src, del: string): string;
var
  limit: Byte;
  delLen: Byte;
  i: Byte;
begin
  delLen := Length(del);
  limit := Length(src) - delLen + 1;
  for i := 1 to limit do
    if Copy(src, i, delLen) = del then
      Delete(src, i, delLen);
  SanitizeString := src;
end;

function SanitizeFileName(name: string): Types.TStr40;
var i: Byte;
begin
  for i := 1 to 10 do
    name := DaxIo.SanitizeString(name, GDConsts.invalidFileChars[i]);
  name := Copy(name, 1, 8);
  for i := 1 to Length(name) do
    name[i] := UpCase(name[i]);
  SanitizeFileName := name;
end;

procedure DecompressDaxBuffer(var src, dst: Types.PByteArr; var lenCompressed, lenDecompressed: Word);
var
  srcIdx: Word;
  dstIdx: Word; b: ShortInt;
begin
  srcIdx := 0;
  dstIdx := 0;
  repeat
    b := src^[srcIdx];
    case b of
      0..$7E: begin
        Move(src^[srcIdx + 1], dst^[dstIdx], b + 1);
        Inc(srcIdx, b + 2);
        Inc(dstIdx, b + 1);
      end;
      -127..-1: begin
        b := -b;
        FillChar(dst^[dstIdx], b, src^[srcIdx + 1]);
        Inc(srcIdx, 2);
        Inc(dstIdx, b);
      end;
    end;
  until srcIdx >= lenCompressed;
end;

{$I-}
function OpenDax(dirName, ext: TStr20; var headerSize: Word; var dataFile, dirFile: file): Boolean;
var nread: Word;
begin
  if DaxIo.OpenWithRetry(dirName + ext, GDConsts.insertDiskMsg[GDVars.virtualDisk] + GDVars.gameDir[1] + ':',
                         GDVars.suppressDiskPrompt, dataFile) then begin
    Assign(dirFile, dirName + ext);
    Reset(dirFile, 1);
    BlockRead(dirFile, headerSize, SizeOf(headerSize), nread);
    Inc(headerSize, SizeOf(headerSize));
    Seek(dataFile, headerSize);
    OpenDax := True;
  end else
    OpenDax := False;
end;

procedure CloseDax(var dataFile, dirFile: file);
begin
  Close(dataFile);
  Close(dirFile);
end;

procedure LoadDax(fileName, ext: TStr20; fileId: Byte; var sizeRead: Word; var data: Types.PByteArr);
var
  compSize: Word;
  offset: LongInt;
  id: Byte;
  n: Word;
  dataFile: file;
  dirFile: file;
  hdrSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  entryFlag: Byte;
  numStr: String[6];
begin
  if not DaxIo.OpenDax(GDVars.gameDir + fileName, ext, hdrSize, dataFile, dirFile) then begin
    sizeRead := 0;
    data := nil;
    Exit;
  end;
  repeat
    BlockRead(dirFile, id, SizeOf(id), n);
    BlockRead(dirFile, offset, SizeOf(offset), n);
    { decompressed size }
    BlockRead(dirFile, sizeRead, SizeOf(sizeRead), n);
    { compressed size }
    BlockRead(dirFile, compSize, SizeOf(compSize), n);
    if compSize > 36000 then begin
      Str(LongInt(compSize), numStr);
      DaxIo.PromptBox(Yellow, 'tempsize ' + numStr);
      GameIo.ExitGame;
    end;
  until (id = fileId) or (FilePos(dirFile) >= hdrSize);
  if id <> fileId then begin
    sizeRead := 0;
    data := nil;
    DaxIo.CloseDax(dataFile, dirFile);
  end else begin
    DaxIo.AllocRounded(Pointer(GDVars.daxCompressedBuf), compSize);
    GetMem(data, sizeRead);
    Seek(dataFile, hdrSize + offset);
    BlockRead(dataFile, GDVars.daxCompressedBuf^, compSize, n);
    DaxIo.CloseDax(dataFile, dirFile);
    DaxIo.DecompressDaxBuffer(GDVars.daxCompressedBuf, data, compSize, sizeRead);
    DaxIo.FreeRounded(Pointer(GDVars.daxCompressedBuf), compSize);
  end;
end;

procedure PushState(v: Byte);
begin
  GDVars.prevVirtualDisk := GDVars.virtualDisk;
  GDVars.virtualDisk := v;
end;

procedure PopState;
begin
  GDVars.virtualDisk := GDVars.prevVirtualDisk;
end;

begin
end.
