{ Character files, saved games and party assembly. CHARLIST.TXT lists available characters; .cha/.itm/.spc files hold
  their records, inventory and effects. SAVGAMx.DAT stores the world and party state, with party members in CHRDATxN.sav
  files. }
{$O+,F+,I-}
unit SaveLoad;

interface

uses Types, Crt, C_Area, GDConsts, GDVars, Blit, TextRend, GameIo, MenuCore, Ending, ClassCal, FxEngine, View3D,
  MapTiles, C_Race, C_Keys, C_Class, C_Ifc, C_Gbvm, DaxIo;

{ Reads CHARLIST.TXT in the save directory into a new list of menu entries, each allocated with only the name, inUse and
  next fields of TItemRec. Names of characters in the party get '* ' in front.
  @param(list Receives the list; nil when the file does not exist.) }
procedure LoadCharlist(var list: Types.PItemRec);

{ Rewrites CHARLIST.TXT in the save directory, one name to a line, skipping the names marked as in the party; while the
  file cannot be opened it asks for the save disk.
  @param(list The names.) }
procedure SaveCharlist(list: Types.PItemRec);

{ Builds the current character's combat icon from virtual disk 3: its head and body pictures, the head laid over the
  body in the character's icon slot, then discards pending keys.
  @param(loading True to recolor the icon from the default colors to the character's icon colors.) }
procedure LoadCharIconAnim(loading: Boolean);

{ Saves a character. Without a file name it is a single character: its name is added to CHARLIST.TXT and it is written
  to <name>.CHA, .ITM and .SPC in the save directory, under its name made a file name. With a file name it is a
  saved-game member, written to <fname>.SAV, .ITM and .SPC. Old .ITM and .SPC files are erased first and written again
  only for a character with items or effects. The records are written as they are, pointers included.
  @param(creature The character.)
  @param(fname The saved-game file name, or empty for a single character.) }
procedure SaveChar(creature: Types.PCharRecord; fname: Types.TStr8);

{ Loads a character from its .CHA or .SAV file, with its items and effects from the .ITM and .SPC files when they exist.
  Its list and combat pointers are cleared. Pending keys are discarded afterwards.
  @param(name The file name, without the extension; with askDisk, the character's name, made a file name in the save
    directory.)
  @param(creature Receives the character.)
  @param(savedGame True for a saved-game member (.SAV), False for a single character (.CHA).)
  @param(askDisk True to ask for the save disk while the file is missing, False to ask for the game disk.) }
procedure LoadChar(name: String; creature: Types.PCharRecord; savedGame, askDisk: Boolean);

{ Loads a monster from MON<disk>CHA.DAX, with its effects and items from MON<disk>SPC.DAX and MON<disk>ITM.DAX. Its list
  and combat pointers are cleared, its icon size follows from its race, and its icon colors are rolled, the hair color
  fixed. A missing monster exits to DOS. Pending keys are discarded afterwards.
  @param(id The monster's block.)
  @param(creature Receives the monster.) }
procedure LoadCreatureData(id: Byte; creature: Types.PCharRecord);

{ Adds a monster to the party, unless the party already has eight members. Its portrait head is rolled by gender, and
  its body by gender and one of its classes, picked at random.
  @param(id The monster's block.) }
procedure AddCreatureToParty(id: Byte);

{ Loads a saved game. The saved games SAVGAMA.DAT to SAVGAMJ.DAT that exist are offered as a letter menu; Escape gives
  up. Each member is loaded from its saved-game file and the single-character files of each member are deleted. The
  icons, the 3D map and the wall sets, or in the wilderness the party icon, are loaded again, and Yarash's pyramid is
  recolored when it is gone. }
procedure LoadGame;

{ Saves the game to one of SAVGAMA.DAT to SAVGAMJ.DAT, chosen from a letter menu; Escape gives up. The wall sets, game
  speed, picture settings and disk number are stored in the GBVM zones, each member is saved as CHRDAT<letter><n>, its
  single-character files are deleted and the recently-saved flag is set. }
procedure SaveGame;

{ Appends a character to the party and makes it the current character. It takes the lowest free icon slot (0 to 7) and
  the GBVM party size goes up. Its class values are recomputed.
  @param(creature The character.) }
procedure AddCharToParty(creature: Types.PCharRecord);

{ Checks that a file is on the disk. When it is not, it offers to save and exit; on Save the party steps back a cell,
  wrapping at the map's edges, the previous virtual disk is selected again, and the game is saved before it exits to
  DOS.
  @param(name The file.) }
procedure CheckFileElseQuit(name: Types.TStr40);

implementation

const
  { Script-visible game-memory addresses }
  { saved wall-set IDs: base + slot 1..3 }
  GBVM_WALLSLOT_ID = $4AF9;
  { saved wall-set symbol slots: base + 1..3 }
  GBVM_WALLSLOT_SLOT = $4AFC;
  { current disk number }
  GBVM_DISK_NUM = $6E12;

procedure CheckSaveDir; forward;

procedure LoadCharlist(var list: Types.PItemRec);
var
  n: Types.PItemRec;
  tail: Types.PItemRec;
  p: Types.PCharRecord;
  f: Text;
begin
  list := nil;
  SaveLoad.CheckSaveDir;
  if not DaxIo.FileExists(GDVars.saveDir + 'charlist.txt') then Exit;
  Assign(f, GDVars.saveDir + 'charlist.txt');
  Reset(f);
  while not Eof(f) do begin
    GetMem(n, SizeOf(Types.TMenuNode));
    FillChar(n^, SizeOf(Types.TMenuNode), 0);
    if list = nil then begin
      list := n;
      tail := list;
    end else begin
      tail^.next := n;
      tail := tail^.next;
    end;
    ReadLn(f, tail^.name);
    p := GDVars.creatureList;
    while (p <> nil) and (p^.name <> tail^.name) do
      p := p^.nextCharAddr;
    if p <> nil then
      tail^.name := '* ' + tail^.name;
  end;
  Close(f);
end;

procedure SaveCharlist(list: Types.PItemRec);
var
  p: Types.PItemRec;
  f: Text;
  ioRes: Integer;
begin
  SaveLoad.CheckSaveDir;
  repeat
    Assign(f, GDVars.saveDir + 'charlist.txt');
    Rewrite(f);
    ioRes := IOResult;
    if ioRes <> 0 then
      TextRend.DisplayAndPause(Yellow, 'Put save disk in ' + GDVars.saveDir[1] + ':');
  until ioRes = 0;
  p := list;
  while p <> nil do begin
    if p^.name[1] <> '*' then
      WriteLn(f, p^.name);
    p := p^.next;
  end;
  Close(f);
end;

{ Creates the save directory, asking for the save disk until the directory is made or already exists. }
procedure CheckSaveDir;
var
  ioRes: Integer;
begin
  repeat
    MkDir(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1));
    ioRes := IOResult;
    if (ioRes <> 0) and (ioRes <> 5) then
      TextRend.DisplayAndPause(Yellow, 'Put save disk in ' + GDVars.saveDir[1] + ':');
  until (ioRes = 0) or (ioRes = 5);
end;

{ Lays one icon picture over another: ORs the pixels on and ANDs the transparency masks. The EGA mask, one plane, is
  sized from the head picture in icon slot 11 rather than from src.
  @param(src The picture laid on.)
  @param(dst The picture it is laid onto.) }
procedure MergeIcon(src, dst: Types.PImgBuf);
var
  n: Word;
  i: Word;
begin
  case GDVars.videoMode of
    Types.Cga, Types.Tandy:
      for i := 0 to src^.imgSize - 1 do begin
        dst^.data[i] := dst^.data[i] or src^.data[i];
        dst^.transp^[i] := dst^.transp^[i] and src^.transp^[i];
      end;
    Types.Ega: begin
      for i := 0 to src^.imgSize - 1 do
        dst^.data[i] := dst^.data[i] or src^.data[i];
      n := GDVars.iconAnimation[11, 0]^.imgSize div 4 - 1;
      for i := 0 to n do
        dst^.transp^[i] := dst^.transp^[i] and src^.transp^[i];
    end;
  end;
end;

procedure LoadCharIconAnim(loading: Boolean);

var
  { Unused in this version; see the other implementations of this routine. }
  animSlot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  iconIds: Byte;
  fromMap: Types.TColorTab;
  toMap: Types.TColorTab;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  partIdx: Byte;
begin
  DaxIo.PushState(3);
  with GDVars.curChar^ do begin
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.iconHeightSuffix[iconSize], iconHead, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.iconHeightSuffix[iconSize], iconBody, orderNumber);
    SaveLoad.MergeIcon(GDVars.iconAnimation[11, 0], GDVars.iconAnimation[orderNumber, 0]);
    SaveLoad.MergeIcon(GDVars.iconAnimation[11, 1], GDVars.iconAnimation[orderNumber, 1]);
    if loading then begin
      for i := 0 to 15 do begin
        fromMap[i] := i;
        toMap[i] := i;
      end;
      for i := 1 to 6 do begin
        toMap[GDConsts.defIconCol[i]] := iconColors1[i] and $F;
        toMap[GDConsts.defIconCol[i] + 8] := (iconColors1[i] and $F0) shr 4;
      end;
      Blit.RemapPic(fromMap, toMap, 0, False, GDVars.iconAnimation[orderNumber, 0]);
      Blit.RemapPic(fromMap, toMap, 0, False, GDVars.iconAnimation[orderNumber, 1]);
    end;
  end;
  MapTiles.FreeIconAnim(11);
  DaxIo.PopState;
  GameIo.DiscardPendingKeys;
end;

procedure SaveChar(creature: Types.PCharRecord; fname: Types.TStr8);
var
  f: file;
  fn: Types.TStr40;
  ext: String[4];
  { Unused in this version; see the other implementations of this routine. }
  res: Word;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  list: Types.PItemRec;
  p: Types.PItemRec;
  n: Types.PItemRec;
  ioRes: Integer;
begin
  { LoadCharlist marks party members with '* ' and SaveCharlist skips them, so this rewrite drops every current party
    member's old line and then appends this character's name unmarked. }
  if Length(fname) = 0 then begin
    SaveLoad.LoadCharlist(list);
    p := list;
    if p <> nil then
      while p^.next <> nil do
        p := p^.next;
    GetMem(n, SizeOf(Types.TMenuNode));
    FillChar(n^, SizeOf(Types.TMenuNode), 0);
    n^.name := creature^.name;
    if p <> nil then
      p^.next := n
    else
      list := n;
    SaveLoad.SaveCharlist(list);
    MenuCore.FreeStringList(list);
    ext := '.cha';
    fn := GDVars.saveDir + DaxIo.SanitizeFileName(DaxIo.SanitizeString(creature^.name, '.'));
  end else begin
    SaveLoad.CheckSaveDir;
    ext := '.sav';
    fn := GDVars.saveDir + fname;
  end;
  repeat
    Assign(f, fn + ext);
    Rewrite(f, 1);
    ioRes := IOResult;
    if ioRes <> 0 then
      TextRend.DisplayAndPause(Yellow, 'Put save disk in ' + GDVars.saveDir[1] + ':');
  until ioRes = 0;
  BlockWrite(f, creature^, SizeOf(Types.TCharRecord));
  Close(f);
  if DaxIo.FileExists(fn + '.itm') then begin
    Assign(f, fn + '.itm');
    Erase(f);
  end;
  if creature^.itemsAddr <> nil then begin
    Assign(f, fn + '.itm');
    Rewrite(f, 1);
    item := creature^.itemsAddr;
    while item <> nil do begin
      BlockWrite(f, item^, SizeOf(Types.TItemRec));
      item := item^.next;
    end;
    Close(f);
  end;
  if DaxIo.FileExists(fn + '.spc') then begin
    Assign(f, fn + '.spc');
    Erase(f);
  end;
  if creature^.effectsAddr <> nil then begin
    Assign(f, fn + '.spc');
    Rewrite(f, 1);
    effect := creature^.effectsAddr;
    while effect <> nil do begin
      BlockWrite(f, effect^, SizeOf(Types.TEffectRec));
      effect := effect^.next;
    end;
    Close(f);
  end;
end;

procedure LoadChar(name: String; creature: Types.PCharRecord; savedGame, askDisk: Boolean);
var
  f: file;
  res: Word;
  ext: String[4];
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  msg: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
begin
  if askDisk then begin
    name := GDVars.saveDir + DaxIo.SanitizeFileName(name);
    msg := 'Put save disk in ' + GDVars.saveDir[1] + ':';
  end else
    msg := GDConsts.insertDiskMsg[GDVars.virtualDisk] + GDVars.gameDir[1] + ':';
  if savedGame then
    ext := '.sav'
  else
    ext := '.cha';
  found := DaxIo.OpenWithRetry(name + ext, msg, #0, f);
  BlockRead(f, creature^, SizeOf(Types.TCharRecord), res);
  Close(f);
  creature^.nextCharAddr := nil;
  creature^.itemsAddr := nil;
  creature^.effectsAddr := nil;
  creature^.combatAddr := nil;
  if DaxIo.FileExists(name + '.itm') then begin
    GetMem(creature^.itemsAddr, SizeOf(Types.TItemRec));
    item := creature^.itemsAddr;
    found := DaxIo.OpenWithRetry(name + '.itm', msg, #0, f);
    repeat
      BlockRead(f, item^, SizeOf(Types.TItemRec), res);
      item^.next := nil;
      if not Eof(f) then begin
        GetMem(item^.next, SizeOf(Types.TItemRec));
        item := item^.next;
      end;
    until Eof(f);
    Close(f);
  end;
  if DaxIo.FileExists(name + '.spc') then begin
    GetMem(creature^.effectsAddr, SizeOf(Types.TEffectRec));
    effect := creature^.effectsAddr;
    found := DaxIo.OpenWithRetry(name + '.spc', msg, #0, f);
    repeat
      BlockRead(f, effect^, SizeOf(Types.TEffectRec), res);
      effect^.next := nil;
      if not Eof(f) then begin
        GetMem(effect^.next, SizeOf(Types.TEffectRec));
        effect := effect^.next;
      end;
    until Eof(f);
    Close(f);
  end;
  GameIo.DiscardPendingKeys;
end;

procedure LoadCreatureData(id: Byte; creature: Types.PCharRecord);
var
  size: Word;
  data: Types.PByteArr;
  offset: Word;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  numStr: String[1];
  i: Byte;
  roll: Byte;
begin
  Str(GDVars.virtualDisk, numStr);
  DaxIo.LoadDax('MON' + numStr + 'CHA', '.dax', id, size, data);
  if size = 0 then begin
    TextRend.DisplayAndPause(White, 'Unable to load monster');
    GameIo.ExitGame;
  end;
  Move(data^, creature^, SizeOf(Types.TCharRecord));
  with creature^ do begin
    itemsAddr := nil;
    effectsAddr := nil;
    nextCharAddr := nil;
    combatAddr := nil;
    case race of
      C_Race.DWARF, C_Race.GNOME, C_Race.HALFLING: iconSize := 1;
      C_Race.ELF, C_Race.HALF_ELF, C_Race.HALF_ORC, C_Race.HUMAN: iconSize := 2;
    end;
    for i := 1 to 3 do begin
      roll := FxEngine.RollDice(1, 6);
      iconColors1[i] := roll + (roll + 8) shl 4;
    end;
    iconColors1[4] := $C4;
    for i := 5 to 6 do begin
      roll := FxEngine.RollDice(1, 6);
      iconColors1[i] := roll + (roll + 8) shl 4;
    end;
  end;
  FreeMem(data, size);
  GDVars.suppressDiskPrompt := #1;
  DaxIo.LoadDax('MON' + numStr + 'SPC', '.dax', id, size, data);
  if size <> 0 then begin
    offset := 0;
    GetMem(creature^.effectsAddr, SizeOf(Types.TEffectRec));
    effect := creature^.effectsAddr;
    repeat
      Move(data^[offset], effect^, SizeOf(Types.TEffectRec));
      effect^.next := nil;
      Inc(offset, SizeOf(Types.TEffectRec));
      if offset < size then begin
        GetMem(effect^.next, SizeOf(Types.TEffectRec));
        effect := effect^.next;
      end;
    until offset >= size;
    FreeMem(data, size);
  end;
  DaxIo.LoadDax('MON' + numStr + 'ITM', '.dax', id, size, data);
  if size <> 0 then begin
    offset := 0;
    GetMem(creature^.itemsAddr, SizeOf(Types.TItemRec));
    item := creature^.itemsAddr;
    repeat
      Move(data^[offset], item^, SizeOf(Types.TItemRec));
      item^.next := nil;
      Inc(offset, SizeOf(Types.TItemRec));
      if offset < size then begin
        GetMem(item^.next, SizeOf(Types.TItemRec));
        item := item^.next;
      end;
    until offset >= size;
    FreeMem(data, size);
  end;
  GDVars.suppressDiskPrompt := #0;
  GameIo.DiscardPendingKeys;
end;

procedure AddCreatureToParty(id: Byte);

var
  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  creature: Types.PCharRecord;
  cnt: Byte;
  i: ShortInt;
  classes: array[1..4] of Byte;
begin
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 7 then Exit;
  GetMem(creature, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData(id, creature);
  with creature^ do begin
    randByte := Random(256);
    cnt := 0;
    for i := 0 to 6 do
      if classLevels[i] > 0 then begin
        Inc(cnt);
        classes[cnt] := i;
      end;
    if cnt = 0 then begin
      cnt := 1;
      classes[cnt] := C_Class.FIGHTER_LEVEL;
    end;
    cnt := FxEngine.RollDice(1, cnt);
    case classes[cnt] of
      C_Class.CLERIC_LEVEL: portraitBody := GDConsts.npcClericBodies[genderSp, FxEngine.RollDice(1, 5)];
      C_Class.MAGE_LEVEL: portraitBody := GDConsts.npcMageBodies[genderSp, FxEngine.RollDice(1, 5)];
      C_Class.THIEF_LEVEL: portraitBody := GDConsts.npcThiefBodies[genderSp, FxEngine.RollDice(1, 5)];
      else portraitBody := GDConsts.npcFighterBodies[genderSp, FxEngine.RollDice(1, 5)];
    end;
    portraitHead := GDConsts.npcPortraitHeads[genderSp, FxEngine.RollDice(1, 8)];
  end;
  SaveLoad.AddCharToParty(creature);
  SaveLoad.LoadCharIconAnim(True);
end;

procedure AddCharToParty(creature: Types.PCharRecord);
var
  p: Types.PCharRecord;
  used: array[0..7] of Byte;
begin
  creature^.orderNumber := 255;
  if GDVars.creatureList = nil then begin
    GDVars.creatureList := creature;
    GDVars.curChar := creature;
  end else begin
    p := GDVars.creatureList;
    while p^.nextCharAddr <> nil do
      p := p^.nextCharAddr;
    p^.nextCharAddr := creature;
  end;
  FillChar(used, SizeOf(used), 0);
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.orderNumber in [0..7] then
      used[p^.orderNumber] := 1;
    p := p^.nextCharAddr;
  end;
  GDVars.curChar := creature;
  with GDVars.curChar^ do begin
    orderNumber := 0;
    while (orderNumber < 8) and (used[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
  ClassCal.RecalcClassStats(creature);
end;

procedure LoadGame;
var
  names: array[1..8] of Types.TStr40;
  f: file;
  i: Byte;
  creature: Types.PCharRecord;
  fn: Types.TStr40;
  res: Word;
  nChars: Byte;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
  letter: Char;
  ext: Boolean;
  menu: String[20];
begin
  SaveLoad.CheckSaveDir;
  menu := '';
  for letter := 'A' to 'J' do
    if DaxIo.FileExists(GDVars.saveDir + 'savgam' + letter + '.dat') then
      menu := menu + letter + ' ';
  if Length(menu) = 0 then Exit;
  repeat
    letter := MenuCore.MenuHorizontal('Load Which Game: ', menu, LightMagenta, LightGreen, White,
                                      False, False, ext);
  until ((letter in ['A'..'J']) and DaxIo.FileExists(GDVars.saveDir + 'savgam' + letter + '.dat')) or
      (letter = C_Keys.NONE);
  if letter = C_Keys.NONE then Exit;
  found := DaxIo.OpenWithRetry(GDVars.saveDir + 'savgam' + letter + '.dat',
                               'Put save disk in ' + GDVars.saveDir, #1, f);
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Loading...Please Wait');
  BlockRead(f, GDVars.virtualDisk, SizeOf(GDVars.virtualDisk), res);
  BlockRead(f, GDVars.zone0^, SizeOf(GDVars.zone0^), res);
  BlockRead(f, GDVars.zone1^, SizeOf(GDVars.zone1^), res);
  BlockRead(f, GDVars.zone2^, SizeOf(GDVars.zone2^), res);
  BlockRead(f, GDVars.zone3^, SizeOf(GDVars.zone3^), res);
  BlockRead(f, GDVars.partyPos, SizeOf(GDVars.partyPos), res);
  BlockRead(f, GDVars.locType, SizeOf(GDVars.locType), res);
  BlockRead(f, GDVars.ifcState, SizeOf(GDVars.ifcState), res);
  BlockRead(f, nChars, SizeOf(nChars), res);
  BlockRead(f, names, SizeOf(names), res);
  Close(f);
  GDVars.monsterPics := GDVars.zone0^.settings div 2;
  GDVars.portraitsOn := GDVars.zone0^.settings and 1;
  GDVars.gameDelay := GDVars.zone0^.gameSpeed.lo;
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
  for i := 1 to nChars do begin
    fn := DaxIo.SanitizeFileName(DaxIo.SanitizeString(names[i], '.'));
    if DaxIo.FileExists(GDVars.saveDir + fn + '.sav') then begin
      GetMem(creature, SizeOf(Types.TCharRecord));
      SaveLoad.LoadChar(fn, creature, True, True);
      SaveLoad.AddCharToParty(creature);
      SaveLoad.CheckSaveDir;
    end;
  end;
  creature := GDVars.creatureList;
  while creature <> nil do begin
    fn := GDVars.saveDir + DaxIo.SanitizeFileName(DaxIo.SanitizeString(creature^.name, '.'));
    { The .itm and .spc files are erased only when the .cha file exists. }
    if DaxIo.FileExists(fn + '.cha') then begin
      Assign(f, fn + '.cha');
      Erase(f);
      if DaxIo.FileExists(fn + '.itm') then begin
        Assign(f, fn + '.itm');
        Erase(f);
      end;
      if DaxIo.FileExists(fn + '.spc') then begin
        Assign(f, fn + '.spc');
        Erase(f);
      end;
    end;
    creature := creature^.nextCharAddr;
  end;
  GDVars.curChar := GDVars.creatureList;
  while GDVars.curChar <> nil do begin
    SaveLoad.LoadCharIconAnim(True);
    GDVars.curChar := GDVars.curChar^.nextCharAddr;
  end;
  GDVars.curChar := GDVars.creatureList;
  { the disk number SaveGame stored at GBVM_DISK_NUM }
  GDVars.virtualDisk := Lo(GDVars.zone1^[SaveLoad.GBVM_DISK_NUM]);
  if GDVars.locType < C_Area.LOC_WILD_WEST then
    View3D.Load3DMap(GDVars.zone0^.mapId.lo);
  if GDVars.locType > C_Area.LOC_3D_MAP then
    MapTiles.LoadIconAnim('ICON', 0, 11)
  else
    for i := 1 to 3 do begin
      GDVars.wallSetCache[i].wallDefId := GDVars.zone0^.words[SaveLoad.GBVM_WALLSLOT_ID + i];
      GDVars.wallSetCache[i].symbolSlot := GDVars.zone0^.words[SaveLoad.GBVM_WALLSLOT_SLOT + i];
      if GDVars.wallSetCache[i].wallDefId >= 0 then
        View3D.LoadWallSet(GDVars.wallSetCache[i].wallDefId, GDVars.wallSetCache[i].symbolSlot);
    end;
  if GDVars.zone0^.yarashPyramidLeft <> 0 then
    Ending.YarashComplete(False);
  GameIo.DiscardPendingKeys;
  MenuCore.ClearBottomLine;
end;

procedure SaveGame;
var
  names: array[1..8] of Types.TStr40;
  f: file;
  n: Byte;
  p: Types.PCharRecord;
  numStr: String[1];
  fn: Types.TStr40;
  ext: Boolean;
  letter: Char;
  ioRes: Integer;
begin
  repeat
    letter := MenuCore.MenuHorizontal('Save Which Game: ', 'A B C D E F G H I J', LightMagenta,
                                      LightGreen, White, False, GDVars.ifcState = C_Ifc.CAMPING, ext);
  until letter in [C_Keys.NONE, 'A'..'J'];
  if letter = C_Keys.NONE then Exit;
  SaveLoad.CheckSaveDir;
  repeat
    Assign(f, GDVars.saveDir + 'savgam' + letter + '.dat');
    Rewrite(f, 1);
    ioRes := IOResult;
    if ioRes <> 0 then
      TextRend.DisplayAndPause(Yellow, 'Put save disk in ' + GDVars.saveDir[1] + ':');
  until ioRes = 0;
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Saving...Please Wait');
  for n := 1 to 3 do begin
    GDVars.zone0^.words[SaveLoad.GBVM_WALLSLOT_ID + n] := GDVars.wallSetCache[n].wallDefId;
    GDVars.zone0^.words[SaveLoad.GBVM_WALLSLOT_SLOT + n] := GDVars.wallSetCache[n].symbolSlot;
  end;
  GDVars.zone0^.gameSpeed.value := GDVars.gameDelay;
  GDVars.zone0^.settings := GDVars.monsterPics * 2 + GDVars.portraitsOn;
  GDVars.zone1^[SaveLoad.GBVM_DISK_NUM] := GDVars.virtualDisk;
  BlockWrite(f, GDVars.virtualDisk, SizeOf(GDVars.virtualDisk));
  BlockWrite(f, GDVars.zone0^, SizeOf(GDVars.zone0^));
  BlockWrite(f, GDVars.zone1^, SizeOf(GDVars.zone1^));
  BlockWrite(f, GDVars.zone2^, SizeOf(GDVars.zone2^));
  BlockWrite(f, GDVars.zone3^, SizeOf(GDVars.zone3^));
  BlockWrite(f, GDVars.partyPos, SizeOf(GDVars.partyPos));
  BlockWrite(f, GDVars.locType, SizeOf(GDVars.locType));
  BlockWrite(f, GDVars.ifcState, SizeOf(GDVars.ifcState));
  n := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    Inc(n);
    Str(n, numStr);
    names[n] := 'CHRDAT' + letter + numStr;
    p := p^.nextCharAddr;
  end;
  BlockWrite(f, n, SizeOf(n));
  BlockWrite(f, names, SizeOf(names));
  Close(f);
  p := GDVars.creatureList;
  n := 0;
  while p <> nil do begin
    Inc(n);
    Str(n, numStr);
    SaveLoad.SaveChar(p, 'CHRDAT' + letter + numStr);
    fn := GDVars.saveDir + DaxIo.SanitizeFileName(DaxIo.SanitizeString(p^.name, '.'));
    if DaxIo.FileExists(fn + '.cha') then begin
      Assign(f, fn + '.cha');
      Erase(f);
    end;
    if DaxIo.FileExists(fn + '.itm') then begin
      Assign(f, fn + '.itm');
      Erase(f);
    end;
    if DaxIo.FileExists(fn + '.spc') then begin
      Assign(f, fn + '.spc');
      Erase(f);
    end;
    p := p^.nextCharAddr;
  end;
  GDVars.recentSaved := 1;
  MenuCore.ClearBottomLine;
end;

procedure CheckFileElseQuit(name: Types.TStr40);
var
  msg: Types.TStr40;
  numStr: String[1];
  ch: Char;
  ext: Boolean;
begin
  if DaxIo.FileExists(name) then Exit;
  Str(GDVars.virtualDisk, numStr);
  msg := 'Save and exit  Insert disk #' + numStr;
  ch := MenuCore.MenuHorizontal('', msg, LightMagenta, LightGreen, White, False, False, ext);
  if (not ext) and (ch = 'S') then begin
    Dec(GDVars.partyPos.mapX, GDConsts.dirDx[GDVars.partyPos.facing]);
    if GDVars.partyPos.mapX < 0 then GDVars.partyPos.mapX := 15;
    if GDVars.partyPos.mapX > 15 then GDVars.partyPos.mapX := 0;
    Dec(GDVars.partyPos.mapY, GDConsts.dirDy[GDVars.partyPos.facing]);
    if GDVars.partyPos.mapY < 0 then GDVars.partyPos.mapY := 15;
    if GDVars.partyPos.mapY > 15 then GDVars.partyPos.mapY := 0;
    DaxIo.PopState;
    SaveLoad.SaveGame;
    GameIo.ExitGame;
  end;
end;

begin
end.
