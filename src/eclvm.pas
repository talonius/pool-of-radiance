{ Main game loop and ECL script interpreter. }
{$O+,F+,I-}
unit EclVm;

interface

uses Types, C_Area, C_Npc, C_Msg, GDConsts, GDVars, Crt, Temple, PostCbt, Shop, EclMenu, Combat, Explore,
  Camp, CharGen, SaveLoad, Ending, GameTime, Money, FxEngine, MenuCore, MapView, Portrait, View3D, MapTiles, CharHlp,
  Border, TextRend, DaxIo, GameIo, SoundDrv, C_Effect, C_Ecl, C_Class, C_Status, C_Ifc, C_Gbvm, C_Sound, C_Money;

{ Main game loop: set the interface state from the previous script id and view3dFlag, load (unless a save was loaded)
  and initialize the ECL script and run its on-load entry, then repeat the map menu, camp, search and movement until the
  party is defeated }
procedure GameLoop;

implementation

const
  { LOAD MONSTER adds no monsters beyond this count }
  MAX_LOADED_MONSTERS = 63;

  { training hall (class bitmask in GBVM_TRAIN_CLASS_MASK) }
  PROG_TRAINING = 0;
  PROG_WIN_GAME = 8;
  PROG_CAMP = 9;
  { The ids of the three wilderness scripts; each selects a locType (C_Area's LOC_WILD_WEST, LOC_WILD_CENTRAL or
    LOC_WILD_EAST). Their values equal IF_GT, IF_LE and IF_GE, but they are script ids, not opcodes. }
  { location type 2, Western Wilderness }
  WILD_WEST_SCRIPT = 25;
  { location type 3, Central Wilderness }
  WILD_CENTRAL_SCRIPT = 26;
  { location type 4, Eastern Wilderness }
  WILD_EAST_SCRIPT = 27;

  { Class value (TCharRecord.charClass) }
  CLASS_RANGER = 4;

  { ECL script opcodes }
  OP_EXIT = $00;
  OP_GOTO = $01;
  GOSUB = $02;
  COMPARE = $03;
  ADD = $04;
  SUBTRACT = $05;
  DIVIDE = $06;
  MULTIPLY = $07;
  OP_RANDOM = $08;
  SAVE = $09;
  LOAD_CHARACTER = $0A;
  LOAD_MONSTER = $0B;
  SETUP_MONSTER = $0C;
  APPROACH = $0D;
  PICTURE = $0E;
  INPUT_NUMBER = $0F;
  INPUT_STRING = $10;
  PRINT = $11;
  PRINT_CLEAR = $12;
  RETURN = $13;
  COMPARE_AND = $14;
  VERTICAL_MENU = $15;
  IF_EQ = $16;
  IF_NE = $17;
  IF_LT = $18;
  IF_GT = $19;
  IF_LE = $1A;
  IF_GE = $1B;
  CLEAR_MONSTERS = $1C;
  PARTY_STRENGTH = $1D;
  CHECK_PARTY = $1E;
  NEW_ECL = $20;
  LOAD_FILES = $21;
  PARTY_SURPRISE = $22;
  SURPRISE = $23;
  OP_COMBAT = $24;
  ON_GOTO = $25;
  ON_GOSUB = $26;
  TREASURE = $27;
  ROB = $28;
  ENCOUNTER = $29;
  GET_TABLE = $2A;
  HORIZONTAL_MENU = $2B;
  PARLAY = $2C;
  CALL = $2D;
  DAMAGE = $2E;
  OP_AND = $2F;
  OP_OR = $30;
  SPRITE_OFF = $31;
  FIND_ITEM = $32;
  PRINT_RETURN = $33;
  CLOCK = $34;
  SAVE_TABLE = $35;
  ADD_NPC = $36;
  LOAD_PIECES = $37;
  OP_PROGRAM = $38;
  WHO = $39;
  OP_DELAY = $3A;
  SPELL = $3B;
  PROTECTION = $3C;
  CLEAR_BOX = $3D;

  { Script-visible game-memory addresses }
  { requested monster distance (0..2) }
  GBVM_MONSTER_DIST_REQ = $6DC0;
  { 1 => party about to enter temple }
  GBVM_ENTER_TEMPLE = $6DE2;
  { 1 => party about to enter shop }
  GBVM_ENTER_SHOP = $6E6C;

  { Sound-effect id }
  SND_ECL_CUE = 7;

procedure CallEclScript(address: Word); forward;

{ EXIT: redraw the borders if PROTECTION text was shown, restore the backed-up current character, clear the graphic
  flags, stop the VM, step past the opcode, free the whole GOSUB return stack and park the message cursor }
procedure EclExit;
begin
  if GDVars.protTextShown <> 0 then begin
    Border.DrawWindow(1, 1, 15, 15, 0, White, '');
    if GDVars.zone0^.view3dFlag <> 0 then
      Border.DrawWindow(3, 3, 13, 13, 0, White, '');
  end;
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0;
  end;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.eclGraphics := False;
  GDVars.protTextShown := 0;
  GDVars.eclStop := 1;
  Inc(GDVars.eclIp);
  while GDVars.eclStackTop <> nil do begin
    GDVars.eclStackPrev := GDVars.eclStackTop^.next;
    FreeMem(GDVars.eclStackTop, SizeOf(Types.TEclRet));
    GDVars.eclStackTop := GDVars.eclStackPrev;
  end;
  GDVars.curRow := C_Msg.MESSAGE_TOP;
  GDVars.curCol := C_Msg.TEXT_LEFT;
  GDVars.clearBoxDone := 0;
end;

{ GOTO, opcode $01: jumps to the address in its argument. }
procedure EclGoto;
begin
  EclMenu.LoadEclVars(1);
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
end;

{ GOSUB, opcode $02: pushes the return address and jumps to the address in its argument. }
procedure EclGosubCmd;
begin
  EclMenu.LoadEclVars(1);
  EclMenu.EclGosub(1);
end;

{ COMPARE, opcode $03: compares its two arguments, as strings when either is a string type ($80 and up), else as
  integers, and sets the comparison flags. }
procedure EclCompare;
var
  firstValue: Word;
  secondValue: Word;
  firstText: String;
  secondText: String;
begin
  EclMenu.LoadEclVars(2);
  if (GDVars.eclVarType[1] >= $80) or (GDVars.eclVarType[2] >= $80) then begin
    firstText := GDVars.gbStrings[1];
    secondText := GDVars.gbStrings[2];
    EclMenu.EclCompareStr(firstText, secondText);
  end else begin
    firstValue := EclMenu.GetEclVar(1);
    secondValue := EclMenu.GetEclVar(2);
    EclMenu.EclCompareInt(firstValue, secondValue);
  end;
end;

{ ADD, SUBTRACT, DIVIDE, MULTIPLY: combine vars 1 and 2 and store the result at var 3's address. SUBTRACT computes var 2
  - var 1. Note: DIVIDE does not check for a zero divisor. }
procedure EclArithmetic;
var
  address: Word;
  v: array[1..2] of Word;
  i: ShortInt;
  r: Word;
begin
  EclMenu.LoadEclVars(3);
  for i := 1 to 2 do
    v[i] := EclMenu.GetEclVar(i);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  case GDVars.curOpcode of
    EclVm.ADD: r := v[1] + v[2];
    EclVm.SUBTRACT: r := v[2] - v[1];
    EclVm.DIVIDE: r := v[1] div v[2];
    EclVm.MULTIPLY: r := v[1] * v[2];
  end;
  EclMenu.WriteGbvm(address, r);
end;

{ RANDOM, opcode $08: stores a random number from 0 to its first argument (0 to 254 when that is 255) at the address in
  its second. }
procedure EclRandom;
var
  n: Byte;
  roll: Byte;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  n := EclMenu.GetEclVar(1);
  if n < 255 then Inc(n);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  roll := Trunc(Random(n));
  EclMenu.WriteGbvm(address, roll);
end;

{ SAVE, opcode $09: stores its first argument, a number or a string (type bit 7 set), at the address in its second. }
procedure EclSave;
var
  v: Word;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  if GDVars.eclVarType[1] < $80 then begin
    v := EclMenu.GetEclVar(1);
    EclMenu.WriteGbvm(address, v);
  end else
    EclMenu.WriteGbvmString(address, GDVars.gbStrings[1]);
end;

{ LOAD CHARACTER: make creature number var 1 (low seven bits, 0 = the first) current; EXIT and PROGRAM restore the
  previous one. With bit 7 set, and dumpOnStatusClear and dumpOnNameClear both set, the creature is removed from the
  party. }
procedure EclLoadCharacter;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  savedIdx: Byte;
  idx: Byte;
  i: Byte;
  flag80: Byte;
begin
  GDVars.restoreChar := 1;
  EclMenu.LoadEclVars(1);
  i := 0;
  idx := EclMenu.GetEclVar(1);
  p := GDVars.creatureList;
  flag80 := idx and $80;
  idx := idx and $7F;
  if idx > 0 then
    while (i < idx) and (p <> nil) do begin
      p := p^.nextCharAddr;
      Inc(i);
    end;
  if p <> nil then
    GDVars.curChar := p;
  if (flag80 <> 0) and GDVars.dumpOnStatusClear and GDVars.dumpOnNameClear then begin
    if GDVars.savedChar = GDVars.curChar then
      GDVars.restoreChar := 0;
    CharGen.RemoveCreature(False, True);
    CharHlp.DisplayParty(GDVars.curChar);
    GDVars.dumpOnStatusClear := False;
    GDVars.dumpOnNameClear := False;
  end;
end;

{ SETUP MONSTER, opcode $0C: sets the monster and its picture, stores the requested monster distance and the actual one
  (capped by the open distance ahead), and draws the monster. }
procedure EclSetupMonster;
var
  { Unused in this version; see the other implementations of this routine. }
  distance: Word;
begin
  EclMenu.LoadEclVars(3);
  GDVars.monId := EclMenu.GetEclVar(1);
  GDVars.zone1^[EclVm.GBVM_MONSTER_DIST_REQ] := EclMenu.GetEclVar(2);
  GDVars.monPicId := EclMenu.GetEclVar(3);
  GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                   GDVars.partyPos.facing);
  if GDVars.zone1^[EclVm.GBVM_MONSTER_DIST_REQ] < GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] then
    GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] := GDVars.zone1^[EclVm.GBVM_MONSTER_DIST_REQ];
  EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]),
                         GDVars.monsterFlags);
end;

{ LOAD MONSTER: load monster var 1 with EclMenu.InitCreature and append it to the creature list, then append var 2 - 1
  copies, each with its own copy of the item and effect lists (prepended, so in reverse order). All use the combat icon
  var 3, loaded into the next icon slot. Stops at 63 monsters. }
procedure EclLoadMonster;
var
  id: Byte;
  count: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  creature: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  tmpl: Types.TCharRecord;
  nm: String[12];
  item: Types.PItemRec;
  tmpIt: Types.PItemRec;
  invHead: Types.PItemRec;
  ef: Types.PEffectRec;
  tmpEf: Types.PEffectRec;
  effHead: Types.PEffectRec;
begin
  savedCur := GDVars.curChar;
  i := 1;
  EclMenu.LoadEclVars(3);
  { at most 63 monsters }
  if GDVars.creatureCnt >= EclVm.MAX_LOADED_MONSTERS then Exit;
  p := nil;
  q := nil;
  id := EclMenu.GetEclVar(1);
  EclMenu.InitCreature(id, creature, item, ef);
  tmpl := creature^;
  invHead := item;
  effHead := ef;
  count := EclMenu.GetEclVar(2);
  if count <= 0 then count := 1;
  picId := EclMenu.GetEclVar(3);
  p := GDVars.creatureList;
  nm := 'CPIC';
  MapTiles.LoadIconAnim(nm, picId, GDVars.iconAnim);
  while p^.nextCharAddr <> nil do
    p := p^.nextCharAddr;
  p^.nextCharAddr := creature;
  p := p^.nextCharAddr;
  p^.orderNumber := GDVars.iconAnim;
  p^.nextCharAddr := nil;
  Inc(GDVars.creatureCnt);
  Inc(i);
  while (i <= count) and (GDVars.creatureCnt < EclVm.MAX_LOADED_MONSTERS) do begin
    GetMem(q, SizeOf(Types.TCharRecord));
    p^.nextCharAddr := q;
    p := p^.nextCharAddr;
    p^ := tmpl;
    p^.orderNumber := GDVars.iconAnim;
    p^.nextCharAddr := nil;
    p^.effectsAddr := nil;
    p^.itemsAddr := nil;
    Inc(i);
    Inc(GDVars.creatureCnt);
    while item <> nil do begin
      if p^.itemsAddr = nil then begin
        GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
        p^.itemsAddr^ := item^;
        p^.itemsAddr^.next := nil;
      end else begin
        tmpIt := p^.itemsAddr;
        GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
        p^.itemsAddr^ := item^;
        p^.itemsAddr^.next := tmpIt;
      end;
      item := item^.next;
    end;
    item := invHead;
    while ef <> nil do begin
      if p^.effectsAddr = nil then begin
        GetMem(p^.effectsAddr, SizeOf(Types.TEffectRec));
        p^.effectsAddr^ := ef^;
        p^.effectsAddr^.next := nil;
      end else begin
        tmpEf := p^.effectsAddr;
        GetMem(p^.effectsAddr, SizeOf(Types.TEffectRec));
        p^.effectsAddr^ := ef^;
        p^.effectsAddr^.next := tmpEf;
      end;
      ef := ef^.next;
    end;
    ef := effHead;
  end;
  Inc(GDVars.iconAnim);
  GDVars.monstersOn := 1;
  GDVars.curChar := savedCur;
end;

{ APPROACH, opcode $0D: brings the monster one step nearer and redraws it, unless it is already adjacent. }
procedure EclApproach;
begin
  if GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] > 0 then begin
    Dec(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]);
    EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]),
                           GDVars.monsterFlags);
  end;
  Inc(GDVars.eclIp);
end;

{ PICTURE: show picture var 1 in the view window, as an animation or a portrait depending on PICTURE_LOADING. 255
  removes the picture, redrawing the map view when ECL graphics or a sprite were showing. }
procedure EclPicture;
var
  picId: Byte;
begin
  EclMenu.LoadEclVars(1);
  picId := EclMenu.GetEclVar(1);
  if (GDVars.zone0^.view3dFlag = 0) and (picId <> 255) then
    Border.DrawWindow(3, 3, 13, 13, 0, White, '');
  if picId <> 255 then begin
    GDVars.monsterFlags[1] := True;
    GDVars.eclGraphics := True;
    if GDVars.zone1^[C_Gbvm.PICTURE_LOADING] = 255 then begin
      Portrait.LoadAnimation('PIC', picId, 0, GDVars.animData);
      Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
    end else
      EclMenu.DisplayPortrait(Byte(GDVars.zone1^[C_Gbvm.PICTURE_LOADING]), picId);
  end else begin
    if ((GDVars.locTypePrev > C_Area.LOC_3D_MAP) or (GDVars.locType = C_Area.LOC_3D_MAP)) and
        (GDVars.eclGraphics or GDVars.sprShown) then begin
      MapView.DisplayMapView;
      GDVars.eclGraphics := False;
      GDVars.sprShown := False;
      GDVars.picDrawn := True;
    end;
    GDVars.monsterFlags[0] := False;
    GDVars.monsterFlags[1] := False;
  end;
end;

{ INPUT NUMBER, opcode $0F: reads a number and stores it at the GBVM address in its second argument. }
procedure EclInputNumber;
var
  q: String[1];
  v: Word;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  v := TextRend.ReadNumber(q, LightGreen);
  EclMenu.WriteGbvm(address, v);
end;

{ INPUT STRING, opcode $10: reads up to 40 characters, a space when nothing is typed, and stores them at the GBVM
  address in its second argument. }
procedure EclInputString;
var
  q: String[1];
  address: Word;
  s: String;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  s := TextRend.ReadString(q, LightGreen, 40);
  if s = '' then s := ' ';
  EclMenu.WriteGbvmString(address, s);
end;

{ PRINT and PRINTCLEAR, opcodes $11 and $12: shows its argument, a number or a string, in the message window; PRINTCLEAR
  first clears the window and starts at its top. }
procedure EclPrint;
begin
  EclMenu.LoadEclVars(1);
  GDVars.bottomMsgCleared := 0;
  GDVars.msgDelayFlag := 1;
  if GDVars.eclVarType[1] < $80 then
    GDVars.gbStrings[1] := CharHlp.WordToString(EclMenu.GetEclVar(1));
  if GDVars.curOpcode = EclVm.PRINT then
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                  LightGreen, False, GDVars.gbStrings[1])
  else begin
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    GDVars.curCol := C_Msg.TEXT_LEFT;
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                  LightGreen, True, GDVars.gbStrings[1]);
  end;
  GDVars.msgDelayFlag := 0;
end;

{ RETURN: pop the GOSUB return stack into the IP. With an empty stack it only steps past the opcode. }
procedure EclReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.eclStackTop <> nil then begin
    GDVars.eclIp := GDVars.eclStackTop^.addr;
    GDVars.eclStackPrev := GDVars.eclStackTop^.next;
    FreeMem(GDVars.eclStackTop, SizeOf(Types.TEclRet));
    GDVars.eclStackTop := GDVars.eclStackPrev;
  end;
end;

{ COMPARE AND: sets the equal flag when v1 = v2 and v3 = v4, else the not-equal flag. }
procedure EclCompareAnd;
var
  v: array[1..4] of Word;
  i: Byte;
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  EclMenu.LoadEclVars(4);
  for i := 1 to 4 do
    v[i] := EclMenu.GetEclVar(i);
  if (v[1] = v[2]) and (v[3] = v[4]) then
    GDVars.cmpFlags[0] := True
  else
    GDVars.cmpFlags[1] := True;
end;

{ Steps the ECL IP past the command at it without running it, loading the command's variables; an opcode not listed
  skips one byte. }
procedure SkipEclCmd;
begin
  GDVars.curOpcode := GDVars.zone3^[GDVars.eclIp];
  case GDVars.curOpcode of
    EclVm.OP_GOTO, EclVm.GOSUB, EclVm.LOAD_CHARACTER, EclVm.PICTURE, EclVm.PRINT, EclVm.PRINT_CLEAR,
        EclVm.PARTY_STRENGTH, EclVm.NEW_ECL, EclVm.CALL,
    EclVm.FIND_ITEM, EclVm.CLOCK, EclVm.ADD_NPC, EclVm.OP_PROGRAM, EclVm.WHO, EclVm.PROTECTION:
      EclMenu.LoadEclVars(1);
    EclVm.COMPARE, EclVm.OP_RANDOM, EclVm.SAVE, EclVm.SETUP_MONSTER, EclVm.INPUT_NUMBER, EclVm.INPUT_STRING,
        $1F, EclVm.PARTY_SURPRISE:
      EclMenu.LoadEclVars(2);
    EclVm.ADD..EclVm.MULTIPLY, EclVm.LOAD_MONSTER, EclVm.LOAD_FILES, EclVm.ROB, EclVm.GET_TABLE,
        EclVm.OP_AND, EclVm.OP_OR, EclVm.SAVE_TABLE,
    EclVm.LOAD_PIECES, EclVm.SPELL:
      EclMenu.LoadEclVars(3);
    EclVm.COMPARE_AND, EclVm.SURPRISE:
      EclMenu.LoadEclVars(4);
    EclVm.DAMAGE:
      EclMenu.LoadEclVars(5);
    EclVm.CHECK_PARTY, EclVm.PARLAY:
      EclMenu.LoadEclVars(6);
    EclVm.TREASURE:
      EclMenu.LoadEclVars(8);
    EclVm.ENCOUNTER:
      EclMenu.LoadEclVars(14);
  else
    Inc(GDVars.eclIp);
  end;
end;

{ IF, opcodes $16..$1B (=, <>, <, >, <=, >=): skips the next command unless its comparison flag is set. }
procedure EclIf;
begin
  Inc(GDVars.eclIp);
  case GDVars.curOpcode of
    EclVm.IF_EQ: if not GDVars.cmpFlags[0] then EclVm.SkipEclCmd;
    EclVm.IF_NE: if not GDVars.cmpFlags[1] then EclVm.SkipEclCmd;
    EclVm.IF_LT: if not GDVars.cmpFlags[2] then EclVm.SkipEclCmd;
    EclVm.IF_GT: if not GDVars.cmpFlags[3] then EclVm.SkipEclCmd;
    EclVm.IF_LE: if not GDVars.cmpFlags[4] then EclVm.SkipEclCmd;
    EclVm.IF_GE: if not GDVars.cmpFlags[5] then EclVm.SkipEclCmd;
  end;
end;

{ NEWECL: remember the current script id, check that the script archive is available, load and initialize script var 1,
  then stop the VM and set newEclFlag so the game loop runs its on-load entry (NewEclDone) }
procedure EclNewEcl;
var
  id: Byte;
  s: String[1];
begin
  EclMenu.LoadEclVars(1);
  GDVars.zone0^.previousScriptId := GDVars.eclScriptId;
  id := EclMenu.GetEclVar(1);
  GDVars.eclScriptId := id;
  Str(GDVars.virtualDisk, s);
  SaveLoad.CheckFileElseQuit(GDVars.gameDir + 'ECL' + s + '.dax');
  EclMenu.LoadEclScript(id);
  EclMenu.EclInit;
  GDVars.eclStop := 1;
  GDVars.newEclFlag := 1;
  GDVars.filesLoaded := 0;
end;

{ LOADFILES: load GEO map var 1 when view3dFlag <> 0, or the BACPAC tile set when view3dFlag = 0. LOADPIECES: load the
  wall sets in vars 1..3 (127 loads set 0; with both mapGraphics flags set only vars 1 and 3 are used); otherwise a 255
  slot is left untouched. Once both have run on entering the main loop, draw the noncombat interface and the party. }
procedure EclLoadFiles;
var
  f: array[1..3] of Byte;
  i: Byte;
begin
  EclMenu.LoadEclVars(3);
  GDVars.filesLoaded := 1;
  for i := 1 to 3 do
    f[i] := EclMenu.GetEclVar(i);
  if GDVars.curOpcode = EclVm.LOAD_FILES then begin
    GDVars.mapLoaded := 1;
    if (f[1] <> 255) and (f[1] <> 127) and (GDVars.zone0^.view3dFlag <> 0) then begin
      GDVars.zone0^.mapId.value := f[1];
      View3D.Load3DMap(f[1]);
      GDVars.zone1^[C_Gbvm.MOVE_LOCKED] := 0;
    end;
    if (f[3] <> 255) and (GDVars.zone0^.view3dFlag = 0) then
      MapTiles.Load24x24Set('BACPAC', 0, 40);
  end else begin
    GDVars.piecesLoaded := 1;
    if f[1] = 127 then
      View3D.LoadWallSet(0, 1)
    else if (GDVars.zone0^.mapGraphics1 <> 0) and (GDVars.zone0^.mapGraphics2 <> 0) then begin
      View3D.LoadWallSet(f[1], 1);
      View3D.LoadWallSet(f[3], 3);
    end else
      for i := 1 to 3 do
        if f[i] <> 255 then
          View3D.LoadWallSet(f[i], i);
  end;
  if (GDVars.enteringLoop <> 0) and (GDVars.piecesLoaded <> 0) and (GDVars.mapLoaded <> 0) then begin
    CharHlp.DisplayNoncombatInterface;
    CharHlp.DisplayParty(GDVars.curChar);
    GDVars.enteringLoop := 0;
  end;
end;

{ AND and OR, opcodes $2F and $30: combines its first two arguments bitwise, truncates the result to a byte, sets the
  comparison flags as for COMPARE of 0 with the result, and stores it at the address in its third. }
procedure EclAndOr;
var
  address: Word;
  secondValue: Word;
  firstValue: Word;
  r: Byte;
begin
  EclMenu.LoadEclVars(3);
  firstValue := EclMenu.GetEclVar(1);
  secondValue := EclMenu.GetEclVar(2);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  if GDVars.curOpcode = EclVm.OP_AND then
    r := firstValue and secondValue
  else
    r := firstValue or secondValue;
  EclMenu.EclCompareInt(0, r);
  EclMenu.WriteGbvm(address, r);
end;

{ GETTABLE, opcode $2A: reads the GBVM entry at its first argument's address plus its second and stores it at the
  address in its third. }
procedure EclGetTable;
var
  addr1: Word;
  addr2: Word;
  sum: Word;
  v: Word;
  idx: Byte;
begin
  EclMenu.LoadEclVars(3);
  addr1 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  idx := EclMenu.GetEclVar(2);
  addr2 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  sum := addr1 + idx;
  v := EclMenu.ReadGbvm(sum);
  EclMenu.WriteGbvm(addr2, v);
end;

{ SAVETABLE, opcode $35: stores its first argument at the GBVM entry at its second argument's address plus its third. }
procedure EclSaveTable;
var
  idx: Word;
  address: Word;
  v: Word;
  sum: Word;
begin
  EclMenu.LoadEclVars(3);
  v := EclMenu.GetEclVar(1);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  idx := EclMenu.GetEclVar(3);
  sum := address + idx;
  EclMenu.WriteGbvm(sum, v);
end;

{ VERTICAL MENU, opcode $15: shows its message, then a vertical menu of as many strings as its third argument says, and
  stores the choice at the GBVM address in its first. }
procedure EclVMenu;
var
  count: Byte;
  i: Byte;
  msg: String;
  list: Types.PItemRec;
  head: Types.PItemRec;
  q: String[1];
  idx: Integer;
  redraw: Boolean;
  address: Word;
begin
  GDVars.bottomMsgCleared := 0;
  redraw := True;
  q := '';
  i := 1;
  EclMenu.LoadEclVars(3);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  msg := GDVars.gbStrings[1];
  count := EclMenu.GetEclVar(3);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  MenuCore.AllocStringList(count, list);
  head := list;
  GDVars.curCol := C_Msg.TEXT_LEFT;
  GDVars.curRow := C_Msg.MESSAGE_TOP;
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                LightGreen, True, msg);
  while list <> nil do begin
    list^.name := GDVars.gbStrings[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := head;
  idx := 0;
  EclMenu.EclVerticalMenu(q, q, LightMagenta, LightGreen, White, C_Msg.TEXT_LEFT, GDVars.curRow + 1,
                          C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, list, False, redraw, idx, list);
  EclMenu.WriteGbvm(address, idx);
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

{ HORIZONTAL MENU, opcode $2B: builds a '~A ~B ~C' horizontal menu from the strings that follow, as many as its second
  argument says, and stores the chosen index at the address in its first. A single choice also accepts Enter, and the
  joystick wording of the continue prompt becomes the keyboard wording. }
procedure EclHMenu;
var
  count: Byte;
  ch: Byte;
  i: Byte;
  q: String[1];
  menu: String[50];
  address: Word;
  enterOk: Boolean;
  anim: Boolean;
  hlCol: Byte;
  mCol: Byte;
begin
  q := '';
  menu := '';
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  menu := '';
  if count = 1 then begin
    enterOk := True;
    hlCol := White;
    mCol := White;
    if GDVars.gbStrings[1] = 'PRESS <RETURN> OR BUTTON TO CONTINUE' then
      GDVars.gbStrings[1] := 'PRESS <ENTER>/<RETURN> TO CONTINUE';
  end else begin
    enterOk := False;
    hlCol := White;
    mCol := LightGreen;
  end;
  anim := GDVars.eclGraphics and GDVars.picDrawn;
  for i := 1 to count - 1 do
    menu := menu + '~' + GDVars.gbStrings[i] + ' ';
  menu := menu + '~' + GDVars.gbStrings[count];
  ch := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, mCol, hlCol, enterOk, anim);
  EclMenu.WriteGbvm(address, ch);
  TextRend.ClearRect(0, 24, 39, 24);
end;

{ CLEAR MONSTERS: forget the loaded monsters, reset the monster icon slot, and clear the treasure money and items }
procedure EclClearMonsters;
var
  nxt: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
begin
  Inc(GDVars.eclIp);
  GDVars.creatureCnt := 0;
  GDVars.monstersOn := 0;
  GDVars.iconAnim := 8;
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  while GDVars.treasureItems <> nil do begin
    nxt := GDVars.treasureItems^.next;
    FreeMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
    GDVars.treasureItems := nxt;
  end;
end;

{ PARTY STRENGTH: store the party's rating at var 1's address: (4*cleric + (hp + 5*(AC below 0) + 5*(THAC0 below 21)
  + 8*mage)) div 10 per member, from the stored 60-biased AC and THAC0. Note: the Byte sum may overflow. }
procedure EclPartyStrength;
var
  hp: Byte;
  th: Byte;
  mage: Byte;
  cleric: Byte;
  ac: Byte;
  strength: Byte;
  address: Word;
  p: Types.PCharRecord;
begin
  EclMenu.LoadEclVars(1);
  strength := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    hp := p^.hpCur;
    ac := p^.acCur;
    th := p^.thac0Cur;
    mage := p^.classLevels[C_Class.MAGE_LEVEL];
    cleric := p^.classLevels[C_Class.CLERIC_LEVEL];
    if ac > 60 then
      ac := ac - 60
    else
      ac := 0;
    if th > 39 then
      th := th - 39
    else
      th := 0;
    strength := strength + (cleric * 4 + (hp + ac * 5 + th * 5 + mage * 8))
                 div 10;
    p := p^.nextCharAddr;
  end;
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  EclMenu.WriteGbvm(address, strength);
end;

{ CHECK PARTY: with var 1 = 0, report whether any member has effect var 2; with var 1 = $6BA7 (thiefSkills[3]) or $6C1B
  (movement), report the party's lowest, highest and average value. The results go to the addresses of vars 3..6
  (lowest, highest, average, found). }
procedure EclCheckParty;
var
  attr: Word;
  sum: Word;
  effId: Byte;
  p: Types.PCharRecord;
  found: Boolean;
  effect: Types.PEffectRec;
  outv: array[1..3] of Byte;
  addr1: Word;
  addr2: Word;
  addr3: Word;
  addr4: Word;
  count: Byte;

  { Stores the three results and the found flag at the four result addresses. }
  procedure Write4Gbvm;
  begin
    EclMenu.WriteGbvm(addr1, outv[1]);
    EclMenu.WriteGbvm(addr2, outv[2]);
    EclMenu.WriteGbvm(addr3, outv[3]);
    EclMenu.WriteGbvm(addr4, ShortInt(found));
  end;

begin
  EclMenu.LoadEclVars(6);
  p := GDVars.creatureList;
  found := False;
  if GDVars.eclVarType[1] = 1 then
    attr := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1])
  else
    attr := EclMenu.GetEclVar(1);
  effId := EclMenu.GetEclVar(2);
  addr1 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[4], GDVars.eclVarHi[4]);
  addr3 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[5], GDVars.eclVarHi[5]);
  addr4 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[6], GDVars.eclVarHi[6]);
  sum := 0;
  count := 0;
  outv[1] := 255;
  outv[2] := 0;
  case attr of
    0: begin
      while (p <> nil) and (not found) do begin
        found := CharHlp.HasEffect(p, effId, effect);
        p := p^.nextCharAddr;
      end;
      for count := 1 to 3 do
        outv[count] := 0;
      Write4Gbvm;
    end;
    $6BA7: begin
      while p <> nil do begin
        Inc(count);
        if p^.thiefSkills[3] < outv[1] then
          outv[1] := p^.thiefSkills[3];
        if p^.thiefSkills[3] > outv[2] then
          outv[2] := p^.thiefSkills[3];
        Inc(sum, p^.thiefSkills[3]);
        p := p^.nextCharAddr;
      end;
      outv[3] := sum div count;
      Write4Gbvm;
    end;
    $6C1B: begin
      while p <> nil do begin
        Inc(count);
        if p^.movementCur < outv[1] then
          outv[1] := p^.movementCur;
        if p^.movementCur > outv[2] then
          outv[2] := p^.movementCur;
        Inc(sum, p^.movementCur);
        p := p^.nextCharAddr;
      end;
      outv[3] := sum div count;
      Write4Gbvm;
    end;
  end;
end;

{ PARTY SURPRISE, opcode $22: stores 1 at its first argument's address when the party holds a ranger or a cleric/ranger,
  else 0, and 0 at its second's. }
procedure EclPartySurprise;
var
  p: Types.PCharRecord;
  mod1: Byte;
  mod2: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rangerDead: Byte;
  addr1: Word;
  addr2: Word;
begin
  EclMenu.LoadEclVars(2);
  p := GDVars.creatureList;
  mod1 := 0;
  mod2 := 0;
  rangerDead := 0;
  while p <> nil do begin
    if (p^.charClass = EclVm.CLASS_RANGER) or (p^.charClass = C_Class.CLERIC_RANGER) then begin
      mod1 := 1;
      rangerDead := 1;
    end;
    p := p^.nextCharAddr;
  end;
  addr1 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  EclMenu.WriteGbvm(addr1, mod1);
  EclMenu.WriteGbvm(addr2, mod2);
end;

{ SURPRISE: roll 1d6 for each side against targets built from vars 1..4 and store the result at SURPRISE: 0 = neither
  roll succeeded, 1 = only the first succeeded, 2 = the second succeeded. Note: when both succeed, the 3 set for that
  case is overwritten by 2. }
procedure EclSurprise;
var
  firstRoll: Byte;
  secondRoll: Byte;
  i: Byte;
  result: Byte;
  v: array[1..4] of Byte;
  firstTarget: ShortInt;
  secondTarget: ShortInt;
begin
  EclMenu.LoadEclVars(4);
  result := 0;
  for i := 1 to 4 do
    v[i] := EclMenu.GetEclVar(i);
  firstTarget := v[4] + 2 - v[1];
  secondTarget := v[2] + 2 - v[3];
  firstRoll := FxEngine.RollDice(1, 6);
  secondRoll := FxEngine.RollDice(1, 6);
  if firstRoll <= firstTarget then
    if secondRoll <= secondTarget then
      result := 3
    else
      result := 1;
  if secondRoll <= secondTarget then
    result := 2;
  EclMenu.WriteGbvm(C_Gbvm.SURPRISE, result);
end;

{ COMBAT: with no monsters and no duel, enter the shop or temple when GBVM_ENTER_SHOP or GBVM_ENTER_TEMPLE is 1, else
  run PostCbt.PostCombat. Otherwise fight, then run PostCbt.PostCombat. Afterwards restore the interface state. }
procedure EclCombat;
var
  dist: Word;
begin
  Inc(GDVars.eclIp);
  if (GDVars.monstersOn = 0) and (not GDVars.duelFlag) then begin
    if GDVars.zone1^[EclVm.GBVM_ENTER_SHOP] = 1 then begin
      GDVars.zone1^[EclVm.GBVM_ENTER_SHOP] := 0;
      Shop.ShopMainMenu;
    end else if GDVars.zone1^[EclVm.GBVM_ENTER_TEMPLE] = 1 then begin
      GDVars.zone1^[EclVm.GBVM_ENTER_TEMPLE] := 0;
      Temple.TempleMainMenu;
    end else
      PostCbt.PostCombat;
  end else begin
    dist := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    if dist < GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] then
      GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] := dist;
    Combat.CombatMain;
    PostCbt.PostCombat;
    if GDVars.zone0^.view3dFlag = 0 then begin
      MapTiles.Load24x24Set('BACPAC', 0, 40);
      MapTiles.LoadIconAnim('ICON', 0, 9);
      MapTiles.LoadIconAnim('ICON', 1, 10);
      MapTiles.LoadIconAnim('ICON', 2, 11);
    end;
    if GDVars.duelFlag then
      GDVars.duelFlag := False;
  end;
  if GDVars.locType = C_Area.LOC_3D_MAP then
    GDVars.ifcState := C_Ifc.INDOORS
  else
    GDVars.ifcState := C_Ifc.OUTDOORS;
  GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.eclGraphics := False;
  CharHlp.DisplayNoncombatInterface;
end;

{ ON GOTO and ON GOSUB, opcodes $25 and $26: jumps to, or calls, the address its first argument picks from the list
  whose length its second gives; an index past the list does nothing. }
procedure EclOnGoto;
var
  sel: Byte;
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  target: Byte;
  i: Byte;
  done: Boolean;
begin
  done := False;
  EclMenu.LoadEclVars(2);
  sel := EclMenu.GetEclVar(1);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  i := 0;
  while (i < count) and (not done) do begin
    if sel = i then begin
      if GDVars.curOpcode = EclVm.ON_GOTO then
        GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLo[i + 1], GDVars.eclVarHi[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      done := True;
    end else
      Inc(i);
  end;
end;

{ TREASURE: set the treasure money from vars 1..7 and add items by var 8: below $80 it selects an ITEM archive list,
  $80+n generates n random items and 255 none. Item nodes are prepended. Note: a second roll of 48 or 49 picks no item
  id and reuses the previous one. }
procedure EclTreasure;
var
  i: ShortInt;
  tId: Byte;
  j: Byte;
  { Unused in this version; see the other implementations of this routine. }
  treasureMsg: String[22];
  it: Types.TItemRec;
  tmp: Types.PItemRec;
  walk: Types.PItemRec;
  roll3: Byte;
  roll: Byte;
  roll2: Byte;
  itemId: Byte;
  offset: Word;
  sizeRead: Word;
  s: String[1];
  data: Types.PByteArr;
begin
  EclMenu.LoadEclVars(8);
  for i := C_Money.COPPER to C_Money.JEWELRY do
    GDVars.treasureMoney[i] := EclMenu.GetEclVar(Byte(i) + 1);
  tId := EclMenu.GetEclVar(8);
  if tId < $80 then begin
    Str(GDVars.virtualDisk, s);
    DaxIo.LoadDax('ITEM' + s, '.dax', tId, sizeRead, data);
    if sizeRead = 0 then begin
      TextRend.DisplayAndPause(White, 'Unable to find item file');
      GameIo.ExitGame;
    end;
    offset := 0;
    repeat
      Move(data^[offset], it, SizeOf(Types.TItemRec));
      it.next := nil;
      Inc(offset, SizeOf(Types.TItemRec));
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    until offset >= sizeRead;
    FreeMem(data, sizeRead);
  end else begin
    if tId = 255 then Exit;
    i := tId - $80;
    for j := 1 to i do begin
      roll := FxEngine.RollDice(1, 100);
      case roll of
        1..60: begin
          roll2 := FxEngine.RollDice(1, 100);
          case roll2 of
            1..47, 50..59:
              if roll2 = 45 then
                itemId := 59
              else
                itemId := roll2;
            60..90: begin
              roll2 := FxEngine.RollDice(1, 10);
              case roll2 of
                1..4: itemId := 36;
                5..7: itemId := 35;
                8: itemId := 34;
                9: itemId := 37;
                10: itemId := 38;
              end;
            end;
            91..94: itemId := 73;
            95..97: itemId := 93;
            98..100: itemId := 77;
          end;
        end;
        61..85: itemId := 61;
        86..92: itemId := 62;
        91..98: begin
          roll3 := FxEngine.RollDice(1, 16);
          case roll3 of
            1..7: itemId := 71;
            8..9: itemId := 70;
            10: itemId := 84;
            11, 12: itemId := 78;
            13, 14: itemId := 79;
            15: itemId := 92;
            16: itemId := 67;
          end;
        end;
        99, 100: itemId := 69;
      end;
      Money.GenerateRandomItem(itemId, it);
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := nil;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    end;
    walk := GDVars.treasureItems;
    while walk <> nil do begin
      CharHlp.PrintItemString(GDVars.curChar, walk, 0, 0, False, False);
      walk := walk^.next;
    end;
  end;
end;

{ ROB: take var 2 percent of the money and steal each item with a var 2 percent chance, from the current character or,
  when var 1 is nonzero, from every member. Note: var 3 is read but unused. }
procedure EclRob;
var
  whole: Byte;
  pct: Byte;
  chance: Byte;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  inv: Types.PItemRec;
  fraction: Real;
begin
  EclMenu.LoadEclVars(3);
  whole := EclMenu.GetEclVar(1);
  pct := EclMenu.GetEclVar(2);
  fraction := (100 - pct) / 100;
  chance := EclMenu.GetEclVar(2);
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, GDVars.curChar);
    EclMenu.RobItems(chance, GDVars.curChar);
  end else begin
    p := GDVars.creatureList;
    while p <> nil do begin
      inv := p^.itemsAddr;
      EclMenu.RobMoney(fraction, p);
      EclMenu.RobItems(chance, p);
      p := p^.nextCharAddr;
    end;
  end;
end;

{ Finds the highest and lowest movement in the creature list, haste doubling and otherwise slow halving it. Both start
  from the first creature's unadjusted movement, so that value always lies within them. Note: the first creature is read
  before the check for nil, so an empty list is read through nil.
  @param(hiMove Receives the highest movement.)
  @param(loMove Receives the lowest movement.) }
procedure MoveExtremes(var hiMove, loMove: Byte);
var
  p: Types.PCharRecord;
  effect: Types.PEffectRec;
  m: Byte;
begin
  p := GDVars.creatureList;
  hiMove := p^.movementCur;
  loMove := p^.movementCur;
  while p <> nil do begin
    m := p^.movementCur;
    if CharHlp.HasEffect(p, C_Effect.HASTED, effect) then
      m := m * 2
    else if CharHlp.HasEffect(p, C_Effect.SLOWED, effect) then
      m := m div 2;
    if m > hiMove then hiMove := m;
    if m < loMove then loMove := m;
    p := p^.nextCharAddr;
  end;
end;

{ ENCOUNTER MENU, opcode $29: runs the encounter menu until combat, flight, parley or the monsters' retreat ends it;
  WAIT and ADVANCE update the encounter and repeat. Stores the outcome at the address in its fourth argument: 0 when the
  monsters flee, 1 for combat, 2 when the party flees, 3 for parley. }
procedure EclEncounter;
var
  sel: Byte;
  resp: array[0..4] of Byte;
  msgs: array[1..3] of String;
  msg: String;
  fleePar: Byte;
  fleeMon: Byte;
  i: Byte;
  hiMove: Byte;
  loMove: Byte;
  waited: Boolean;
  clearW: Boolean;
  anim: Boolean;
  menu: String[40];
  q: String[1];
  choice: Byte;
  k: Byte;
  address: Word;
begin
  GDVars.inEncMenu := 1;
  GDVars.bottomMsgCleared := 0;
  GDVars.msgDelayFlag := 1;
  EclVm.MoveExtremes(hiMove, loMove);
  q := '';
  EclMenu.LoadEclVars(14);
  GDVars.monId := EclMenu.GetEclVar(1);
  GDVars.zone1^[EclVm.GBVM_MONSTER_DIST_REQ] := EclMenu.GetEclVar(2);
  GDVars.monPicId := EclMenu.GetEclVar(3);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[4], GDVars.eclVarHi[4]);
  for i := 0 to 4 do
    resp[i] := EclMenu.GetEclVar(i + 5);
  for i := 1 to 3 do
    msgs[i] := GDVars.gbStrings[i];
  fleePar := EclMenu.GetEclVar(13);
  fleeMon := EclMenu.GetEclVar(14);
  GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                   GDVars.partyPos.facing);
  if GDVars.zone1^[EclVm.GBVM_MONSTER_DIST_REQ] < GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] then
    GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] := GDVars.zone1^[EclVm.GBVM_MONSTER_DIST_REQ];
  EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]),
                         GDVars.monsterFlags);
  repeat
    anim := GDVars.eclGraphics and GDVars.picDrawn;
    clearW := True;
    waited := False;
    GDVars.curCol := C_Msg.TEXT_LEFT;
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    case GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] of
      0: begin
        k := 1;
        repeat
          msg := msgs[k];
          Inc(k);
        until (msg <> '') or (k > 3);
      end;
      1: begin
        k := 2;
        repeat
          msg := msgs[k];
          Inc(k);
          if k > 3 then k := 1;
        until (msg <> '') or (k = 2);
      end;
      2: begin
        k := 3;
        repeat
          msg := msgs[k];
          Inc(k);
          if k > 3 then k := 1;
        until (msg <> '') or (k = 3);
      end;
    end;
    if msg = '' then
      clearW := False;
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                  LightGreen, clearW, msg);
    if (GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] = 0) or (GDVars.zone0^.view3dFlag = 0) then
      menu := '~COMBAT ~WAIT ~FLEE ~PARLAY'
    else
      menu := '~COMBAT ~WAIT ~FLEE ~ADVANCE';
    sel := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, LightGreen, White, False, anim);
    if ((GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] = 0) or (GDVars.zone0^.view3dFlag = 0)) and (sel = 3) then
      sel := 4;
    choice := resp[sel];
    case choice of
      0:
        if sel <> 2 then
          EclMenu.WriteGbvm(address, 1)
        else begin
          if loMove >= fleePar then
            EclMenu.WriteGbvm(address, 2)
          else
            EclMenu.WriteGbvm(address, 1);
        end;
      1:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1: begin
            waited := True;
            TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                          LightGreen, True, 'Both sides wait.');
          end;
          2: EclMenu.WriteGbvm(address, 2);
          3: begin
            if GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] <> 0 then begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]),
                                     GDVars.monsterFlags);
            end else
              TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                            LightGreen, True, 'Both sides wait.');
            waited := True;
          end;
          4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]),
                                     GDVars.monsterFlags);
              waited := True;
            end;
        end;
      2:
        case sel of
          0:
            if fleeMon > hiMove then begin
              EclMenu.WriteGbvm(address, 0);
              GDVars.curCol := C_Msg.TEXT_LEFT;
              GDVars.curRow := C_Msg.MESSAGE_TOP;
              TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                            LightGreen, True, 'The monsters flee.');
            end else
              EclMenu.WriteGbvm(address, 1);
          1..4: begin
            EclMenu.WriteGbvm(address, 0);
            GDVars.curCol := C_Msg.TEXT_LEFT;
            GDVars.curRow := C_Msg.MESSAGE_TOP;
            TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                          LightGreen, True, 'The monsters flee.');
          end;
        end;
      3:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1, 3: begin
            if GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] <> 0 then begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]),
                                     GDVars.monsterFlags);
            end else
              TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                            LightGreen, True, 'Both sides wait.');
            waited := True;
          end;
          2: EclMenu.WriteGbvm(address, 2);
          4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]),
                                     GDVars.monsterFlags);
              waited := True;
            end;
        end;
      4:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1, 3, 4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE]),
                                     GDVars.monsterFlags);
              waited := True;
            end;
          2: EclMenu.WriteGbvm(address, 2);
        end;
    end;
  until not waited;
  TextRend.ClearRect(0, 24, 39, 24);
  GDVars.msgDelayFlag := 0;
  GDVars.inEncMenu := 0;
end;

{ PARLAY: offers Haughty, Sly, Nice, Meek and Abusive and stores the script's value for the chosen attitude at the sixth
  argument's address. }
procedure EclParlay;
var
  sel: Byte;
  chosenValue: Byte;
  i: Byte;
  v: array[0..4] of Byte;
  address: Word;
  space: Char;
begin
  EclMenu.LoadEclVars(6);
  space := ' ';
  for i := 0 to 4 do
    v[i] := EclMenu.GetEclVar(i + 1);
  sel := EclMenu.MenuHorizontalCharacterSelect(space, '~HAUGHTY ~SLY ~NICE ~MEEK ~ABUSIVE', LightMagenta, LightGreen,
                                               White, False, False);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[6], GDVars.eclVarHi[6]);
  chosenValue := v[sel];
  EclMenu.WriteGbvm(address, chosenValue);
end;

{ FIND ITEM, opcode $32: sets the equal flag when a party member carries an item of the type in its argument, the
  not-equal flag otherwise. }
procedure EclFindItem;
var
  itemType: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Byte;
  p: Types.PCharRecord;
  item: Types.PItemRec;
  found: Boolean;
begin
  EclMenu.LoadEclVars(1);
  found := False;
  itemType := EclMenu.GetEclVar(1);
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  GDVars.cmpFlags[1] := True;
  p := GDVars.creatureList;
  while (p <> nil) and (not found) do begin
    item := p^.itemsAddr;
    while (item <> nil) and (not found) do begin
      if itemType = item^.itemType then begin
        GDVars.cmpFlags[0] := True;
        GDVars.cmpFlags[1] := False;
        found := True;
      end;
      item := item^.next;
    end;
    p := p^.nextCharAddr;
  end;
end;

{ DELAY, opcode $3A: waits the message delay; no key is read. }
procedure EclDelay;
begin
  Inc(GDVars.eclIp);
  TextRend.PauseOnly;
end;

{ Deals script damage to a creature with a message, then redraws the party panel; a dead creature is skipped. The
  creature dies when the damage is more than 10 above its hit points; otherwise the message gives the damage, at most
  three digits. When the message window is full it waits for a key first.
  @param(dmg The damage.)
  @param(creature The creature.) }
procedure EclInflictDamage(dmg: Word; creature: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  msg: String;
  dmgStr: String[3];
  pause: Boolean;
begin
  if creature^.status = C_Status.DEAD_STATUS then Exit;
  pause := False;
  Str(dmg, dmgStr);
  if creature^.hpCur + 10 < dmg then
    msg := '  ' + creature^.name + ' dies. '
  else
    msg := '  ' + creature^.name + ' is hit for ' + dmgStr + ' points of damage.';
  if GDVars.curRow > C_Msg.TEXT_BOTTOM then begin
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    pause := True;
    TextRend.DisplayAndPause(White, 'press <enter>/<return> to continue');
  end else
    pause := False;
  GDVars.curCol := C_Msg.TEXT_RIGHT;
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, White,
                                pause, msg);
  CharHlp.InflictDamage(creature, dmg);
  TextRend.ClearRect(17, 1, 38, 15);
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ DAMAGE: apply scripted damage, then check for total party defeat. Without attack bit 7, attack counts attack rolls
  against random members (value is passed to FxEngine.AttackRollNoAttacker) and damage is rerolled after each roll. With
  bit 7, bit 6 selects the whole party, bit 5 skips whole-party saves, and the low five bits modify the save. value bit
  7 selects the current character instead of a random one; its low three bits select the save type. The
  current-character path subtracts one from that type, and type 0 there means no save. }
procedure EclDamage;
var
  attack: Byte;
  dice: Byte;
  sides: Byte;
  i: Byte;
  saveMod: Byte;
  value: Byte;
  bonus: Byte;
  count: Byte;
  saveType: Byte;
  k: Byte;
  dmg: Word;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  allParty: Byte;
begin
  savedCur := GDVars.curChar;
  damageType := 0;
  allParty := 0;
  p := GDVars.creatureList;
  EclMenu.LoadEclVars(5);
  attack := EclMenu.GetEclVar(1);
  dice := EclMenu.GetEclVar(2);
  sides := EclMenu.GetEclVar(3);
  bonus := EclMenu.GetEclVar(4);
  value := EclMenu.GetEclVar(5);
  dmg := bonus + FxEngine.RollDice(dice, sides);
  if attack and $40 <> 0 then
    allParty := 1
  else
    count := FxEngine.RollDice(1, Byte(GDVars.zone1^[C_Gbvm.PARTY_SIZE]));
  if attack and $80 <> 0 then begin
    saveMod := attack and $1F;
    saveType := value and 7;
    if allParty <> 0 then begin
      while p <> nil do begin
        if attack and $20 <> 0 then
          EclVm.EclInflictDamage(dmg, p)
        else begin
          if not FxEngine.RollSavingThrow(p, saveType, saveMod) then
            EclVm.EclInflictDamage(dmg, p);
        end;
        p := p^.nextCharAddr;
      end;
    end else if value and $80 <> 0 then begin
      if (saveType = 0) or (not FxEngine.RollSavingThrow(GDVars.curChar, saveType - 1, saveMod)) then
        EclVm.EclInflictDamage(dmg, GDVars.curChar);
    end else begin
      for i := 2 to count do
        p := p^.nextCharAddr;
      if not FxEngine.RollSavingThrow(p, saveType, saveMod) then
        EclVm.EclInflictDamage(dmg, p);
    end;
  end else begin
    for i := 1 to attack do begin
      p := GDVars.creatureList;
      count := FxEngine.RollDice(1, Byte(GDVars.zone1^[C_Gbvm.PARTY_SIZE]));
      k := 1;
      while k < count do begin
        p := p^.nextCharAddr;
        Inc(k);
      end;
      if FxEngine.AttackRollNoAttacker(p, value) then
        EclVm.EclInflictDamage(dmg, p);
      dmg := bonus + FxEngine.RollDice(dice, sides);
    end;
  end;
  q := GDVars.creatureList;
  GDVars.partyDefeated := True;
  while q <> nil do begin
    if q^.enabled <> 0 then
      GDVars.partyDefeated := False;
    q := q^.nextCharAddr;
  end;
  if GDVars.partyDefeated then begin
    Border.DrawWindow(1, 1, 38, 22, 0, White, 'The END!');
    GDVars.curCol := 2;
    GDVars.curRow := 2;
    TextRend.DisplayMessageWindow(1, 1, 38, 22, LightGreen, True, 'The entire party is killed!');
    Delay(3000);
  end;
  GDVars.curChar := savedCur;
  TextRend.DisplayAndPause(White, 'press <enter>/<return> to continue');
end;

{ SPRITE OFF, opcode $31: when a sprite is showing, redraws the map view over it. }
procedure EclSpriteOff;
begin
  Inc(GDVars.eclIp);
  if GDVars.sprShown then begin
    MapView.DisplayMapView;
    GDVars.sprShown := False;
    GDVars.eclGraphics := False;
  end;
end;

{ CLOCK: advance the clock by var 1. Note: GetEclVar is passed the unset v, not 1. }
procedure EclClock;
var
  v: Byte;
begin
  EclMenu.LoadEclVars(1);
  v := EclMenu.GetEclVar(v);
  GameTime.AdvanceTime(v, 1);
end;

{ PRINT RETURN, opcode $33: moves the message cursor to the start of the next line and clears the print-return flag. }
procedure EclPrintReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.protNewLine <> 0 then begin
    GDVars.curCol := C_Msg.TEXT_LEFT;
    Inc(GDVars.curRow);
    GDVars.protNewLine := 0;
  end else begin
    GDVars.curCol := C_Msg.TEXT_LEFT;
    Inc(GDVars.curRow);
  end;
end;

{ CLEAR BOX: clear the 3D view box and note it for PROTECTION }
procedure EclClearBox;
begin
  Inc(GDVars.eclIp);
  TextRend.ClearRect(1, 1, 15, 15);
  GDVars.clearBoxDone := 1;
end;

{ WHO: let the player pick a party member, prompting with var 1; the choice becomes the current character }
procedure EclWho;
var
  msg: String;
begin
  EclMenu.LoadEclVars(1);
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  msg := GDVars.gbStrings[1];
  CharHlp.SelectChar(msg, False, GDVars.curChar);
end;

{ ADD NPC: add creature var 1 to the party as an NPC whose npc byte is half the morale var 2 with bit 7 set. Monster id
  24 joins as hostile, every other id as friendly. }
procedure EclAddNpc;
var
  { Unused in this version; see the other implementations of this routine. }
  npc: array[1..4] of Byte;
  id: Byte;
  morale: Byte;
  { Unused in this version; see the other implementations of this routine. }
  npcName: array[1..8] of Byte;
begin
  EclMenu.LoadEclVars(2);
  id := EclMenu.GetEclVar(1);
  SaveLoad.AddCreatureToParty(id);
  morale := EclMenu.GetEclVar(2);
  morale := morale div 2;
  morale := morale or C_Npc.NON_PLAYER;
  GDVars.curChar^.npc := morale;
  if id <> 24 then
    GDVars.curChar^.hostile := 0
  else
    GDVars.curChar^.hostile := 1;
  CharHlp.RecalcStats(GDVars.curChar);
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ SPELL: look for spell var 1 in memorizedSpells[1..82] (slot 255 = not found) and write the slot to var 2's address and
  idx to var 3's. Note: found is never initialized; when it starts False only the first creature is scanned (the scan
  always sets found), leaving idx = 1. }
procedure EclSpell;
var
  spellId: Byte;
  slot: Byte;
  idx: Byte;
  p: Types.PCharRecord;
  found: Boolean;
  addr1: Word;
  addr2: Word;
begin
  EclMenu.LoadEclVars(3);
  spellId := EclMenu.GetEclVar(1);
  addr1 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[2], GDVars.eclVarHi[2]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.eclVarLo[3], GDVars.eclVarHi[3]);
  slot := 1;
  idx := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (not found) do begin
    repeat
      if p^.memorizedSpells[slot] = spellId then
        found := True
      else if slot <= 81 then
        Inc(slot)
      else begin
        slot := 255;
        found := True;
      end;
    until found;
    p := p^.nextCharAddr;
    Inc(idx);
  end;
  EclMenu.WriteGbvm(addr1, slot);
  EclMenu.WriteGbvm(addr2, idx);
end;

{ CALL: dispatch ECL service calls by address: refresh the view, start a duel or solo fight, play a sound, step forward
  or update the wall state. }
procedure EclCall;
var
  address: Word;
  key: Word;
begin
  EclMenu.LoadEclVars(1);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  key := address - $7FFF;
  case Integer(key) of
    { address $2C90 }
    Integer($AC91): begin
      GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
      if GDVars.filesLoaded <> 0 then
        if GDVars.eclGraphics or GDVars.sprShown or GDVars.picRegionW or GDVars.movedParty or
            GDVars.redrawSky then begin
          MapView.DisplayMapView;
          CharHlp.PrintPositionAndTime;
          GDVars.redrawSky := False;
          GDVars.picRegionW := False;
          GDVars.movedParty := False;
          GDVars.eclGraphics := False;
          GDVars.sprShown := False;
        end;
    end;
    { address $8000 }
    1:
      EclMenu.CharFightsAlone(1);
    { address $8001 }
    2:
      EclMenu.CharFightsAlone(0);
    { address $BA03 }
    $3A04: begin
      case GDVars.sndEffect of
        8: SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
        10: SoundDrv.SoundCommand(GDConsts.soundIds.combat[EclVm.SND_ECL_CUE]);
      end;
    end;
    { address $C01E }
    $401F:
      EclMenu.EclMoveForward;
    { address $C018 }
    $4019:
      if GDVars.locType = C_Area.LOC_3D_MAP then
        GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                        GDVars.partyPos.facing);
  end;
end;

{ Run the pre-camp script entry (scriptEntryAddrs[3]) and the camp menu, then the camp-interruption entry
  (scriptEntryAddrs[4]) if camp was interrupted. Redraw the map view and clear recentSaved. }
procedure EnterCamp;
var
  interrupted: Boolean;
begin
  interrupted := False;
  EclVm.CallEclScript(GDVars.scriptEntryAddrs[3]);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharHlp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GDVars.scriptEntryAddrs[4]);
  end;
  MapView.DisplayMapView;
  GDVars.recentSaved := 0;
end;

{ PROGRAM: restore the backed-up current character, then run program var 1: PROG_TRAINING (the training hall menu),
  PROG_WIN_GAME, or PROG_CAMP (camp with the IP preserved, then EXIT). Other values do nothing. }
procedure EclProgram;
var
  v: Byte;
  savedIp: Word;
begin
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0;
  end;
  EclMenu.LoadEclVars(1);
  v := EclMenu.GetEclVar(1);
  case v of
    EclVm.PROG_TRAINING: begin
      CharGen.MainMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
    EclVm.PROG_WIN_GAME:
      Ending.WinGame;
    EclVm.PROG_CAMP: begin
      savedIp := GDVars.eclIp;
      EclVm.EnterCamp;
      GDVars.eclIp := savedIp;
      EclVm.EclExit;
    end;
  end;
end;

{ PROTECTION: draw the text at var 1's address at the message cursor; each byte is one less than its game-font glyph,
  and a zero byte ends it. After CLEAR BOX, text below row 13 moves into the 3D box and EXIT redraws its border. }
procedure EclProtection;
var
  address: Word;
  a: Word;
  i: Byte;
  c: Byte;
  done: Boolean;
  s: String;
begin
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.eclGraphics := False;
  s := '';
  EclMenu.LoadEclVars(1);
  address := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  i := 0;
  done := False;
  if (GDVars.clearBoxDone <> 0) and (GDVars.curRow > 13) then begin
    GDVars.curRow := 5;
    GDVars.curCol := 2;
    GDVars.protTextShown := 1;
  end;
  GDVars.protNewLine := 1;
  repeat
    a := address + i;
    c := EclMenu.ReadGbvm(a) + 1;
    if c > 1 then begin
      s := s + CharHlp.ByteToString(c);
      TextRend.RenderChar(GDVars.curCol, GDVars.curRow, White, 1, c, 0);
      Inc(GDVars.curCol);
      Inc(i);
    end else
      done := True;
  until done;
  Inc(GDVars.curRow);
end;

{ Run the command at the IP (curOpcode). Note: an unhandled opcode such as $1F prints a diagnostic and leaves the IP
  unchanged, so CallEclScript would run it forever. }
procedure DispatchEclCommand;
begin
  case GDVars.curOpcode of
    EclVm.OP_EXIT: EclVm.EclExit;
    EclVm.OP_GOTO: EclVm.EclGoto;
    EclVm.GOSUB: EclVm.EclGosubCmd;
    EclVm.COMPARE: EclVm.EclCompare;
    EclVm.ADD, EclVm.SUBTRACT, EclVm.DIVIDE, EclVm.MULTIPLY: EclVm.EclArithmetic;
    EclVm.OP_RANDOM: EclVm.EclRandom;
    EclVm.SAVE: EclVm.EclSave;
    EclVm.LOAD_CHARACTER: EclVm.EclLoadCharacter;
    EclVm.LOAD_MONSTER: EclVm.EclLoadMonster;
    EclVm.SETUP_MONSTER: EclVm.EclSetupMonster;
    EclVm.APPROACH: EclVm.EclApproach;
    EclVm.PICTURE: EclVm.EclPicture;
    EclVm.INPUT_NUMBER: EclVm.EclInputNumber;
    EclVm.INPUT_STRING: EclVm.EclInputString;
    EclVm.PRINT, EclVm.PRINT_CLEAR: EclVm.EclPrint;
    EclVm.RETURN: EclVm.EclReturn;
    EclVm.COMPARE_AND: EclVm.EclCompareAnd;
    EclVm.VERTICAL_MENU: EclVm.EclVMenu;
    EclVm.IF_EQ, EclVm.IF_NE, EclVm.IF_LT, EclVm.IF_GT, EclVm.IF_LE, EclVm.IF_GE: EclVm.EclIf;
    EclVm.CLEAR_MONSTERS: EclVm.EclClearMonsters;
    EclVm.PARTY_STRENGTH: EclVm.EclPartyStrength;
    EclVm.CHECK_PARTY: EclVm.EclCheckParty;
    EclVm.NEW_ECL: EclVm.EclNewEcl;
    EclVm.LOAD_FILES, EclVm.LOAD_PIECES: EclVm.EclLoadFiles;
    EclVm.PARTY_SURPRISE: EclVm.EclPartySurprise;
    EclVm.SURPRISE: EclVm.EclSurprise;
    EclVm.OP_COMBAT: EclVm.EclCombat;
    EclVm.ON_GOTO, EclVm.ON_GOSUB: EclVm.EclOnGoto;
    EclVm.TREASURE: EclVm.EclTreasure;
    EclVm.ROB: EclVm.EclRob;
    EclVm.ENCOUNTER: EclVm.EclEncounter;
    EclVm.GET_TABLE: EclVm.EclGetTable;
    EclVm.HORIZONTAL_MENU: EclVm.EclHMenu;
    EclVm.PARLAY: EclVm.EclParlay;
    EclVm.CALL: EclVm.EclCall;
    EclVm.DAMAGE: EclVm.EclDamage;
    EclVm.OP_AND, EclVm.OP_OR: EclVm.EclAndOr;
    EclVm.SPRITE_OFF: EclVm.EclSpriteOff;
    EclVm.FIND_ITEM: EclVm.EclFindItem;
    EclVm.PRINT_RETURN: EclVm.EclPrintReturn;
    EclVm.CLOCK: EclVm.EclClock;
    EclVm.SAVE_TABLE: EclVm.EclSaveTable;
    EclVm.ADD_NPC: EclVm.EclAddNpc;
    EclVm.OP_PROGRAM: EclVm.EclProgram;
    EclVm.WHO: EclVm.EclWho;
    EclVm.OP_DELAY: EclVm.EclDelay;
    EclVm.SPELL: EclVm.EclSpell;
    EclVm.PROTECTION: EclVm.EclProtection;
    EclVm.CLEAR_BOX: EclVm.EclClearBox;
  else begin
    WriteLn('codeop = ', GDVars.curOpcode, ' last = ', GDVars.prevOpcode);
    WriteLn('string = ', GDVars.gbStrings[1]);
  end;
  end;
end;

{ Runs ECL commands from an address until EXIT or NEWECL stops the VM or the party is defeated.
  @param(address The script address.) }
procedure CallEclScript(address: Word);
begin
  GDVars.eclIp := address;
  GDVars.eclStop := 0;
  while (GDVars.eclStop = 0) and (not GDVars.partyDefeated) do begin
    GDVars.prevOpcode := GDVars.curOpcode;
    GDVars.curOpcode := GDVars.zone3^[GDVars.eclIp];
    EclVm.DispatchEclCommand;
  end;
  GDVars.eclStop := 0;
end;

{ Refresh the event byte, run the new script's on-load entry (scriptEntryAddrs[5]), and when view3dFlag = 0 set the
  location type for the three wilderness scripts. On the central one, call Ending.YarashComplete once the Yarash pyramid
  is done, whatever view3dFlag is. Redraw, then run scriptEntryAddrs[1] and the search entry. newEclFlag is cleared
  before scriptEntryAddrs[1] runs, so this repeats while that entry itself runs NEWECL. }
procedure NewEclDone;
var
  savedCur: Types.PCharRecord;
begin
  repeat
    GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
    GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 0;
    savedCur := GDVars.curChar;
    GDVars.locTypePrev := GDVars.locType;
    GDVars.locType := C_Area.LOC_3D_MAP;
    EclVm.CallEclScript(GDVars.scriptEntryAddrs[5]);
    GDVars.ifcState := C_Ifc.INDOORS;
    case GDVars.eclScriptId of
      EclVm.WILD_WEST_SCRIPT:
        if GDVars.zone0^.view3dFlag = 0 then begin
          GDVars.locType := C_Area.LOC_WILD_WEST;
          GDVars.ifcState := C_Ifc.OUTDOORS;
        end;
      EclVm.WILD_CENTRAL_SCRIPT: begin
        if GDVars.zone0^.view3dFlag = 0 then begin
          GDVars.locType := C_Area.LOC_WILD_CENTRAL;
          GDVars.ifcState := C_Ifc.OUTDOORS;
        end;
        if (GDVars.zone0^.yarashMissionDone = 254) and (GDVars.zone0^.yarashPyramidLeft = 0) then
          Ending.YarashComplete(True);
      end;
      EclVm.WILD_EAST_SCRIPT:
        if GDVars.zone0^.view3dFlag = 0 then begin
          GDVars.locType := C_Area.LOC_WILD_EAST;
          GDVars.ifcState := C_Ifc.OUTDOORS;
        end;
    end;
    if (GDVars.locTypePrev > C_Area.LOC_3D_MAP) and (GDVars.locType = C_Area.LOC_3D_MAP) then
      Border.DrawWindow(3, 3, 13, 13, 0, LightGreen, '');
    if (((GDVars.locTypePrev > C_Area.LOC_3D_MAP) or (GDVars.locType = C_Area.LOC_3D_MAP)) and
        (GDVars.filesLoaded <> 0)) or
          ((GDVars.locTypePrev = C_Area.LOC_3D_MAP) and (GDVars.locType = C_Area.LOC_3D_MAP)) then
      MapView.DisplayMapView;
    GDVars.newEclFlag := 0;
    EclVm.CallEclScript(GDVars.scriptEntryAddrs[1]);
    if GDVars.newEclFlag = 0 then begin
      EclVm.CallEclScript(GDVars.scriptEntryAddrs[C_Ecl.SEARCH_ENTRY]);
      GDVars.curChar := savedCur;
      CharHlp.DisplayParty(GDVars.curChar);
    end;
  until GDVars.newEclFlag = 0;
end;

procedure GameLoop;
var
  cmd: Char;
begin
  GDVars.piecesLoaded := 0;
  GDVars.mapLoaded := 0;
  GDVars.restoreChar := 0;
  GDVars.filesLoaded := 0;
  GDVars.enteringLoop := 1;
  GDVars.ifcState := C_Ifc.INDOORS;
  GDVars.newEclFlag := 0;
  GDVars.eclScriptId := Byte(GDVars.zone0^.previousScriptId);
  case GDVars.eclScriptId of
    EclVm.WILD_WEST_SCRIPT, EclVm.WILD_CENTRAL_SCRIPT, EclVm.WILD_EAST_SCRIPT:
      if GDVars.zone0^.view3dFlag = 0 then
        GDVars.ifcState := C_Ifc.OUTDOORS;
  end;
  if GDVars.loadedSave = 0 then
    EclMenu.LoadEclScript(GDVars.eclScriptId);
  EclMenu.EclInit;
  EclVm.CallEclScript(GDVars.scriptEntryAddrs[5]);
  if GDVars.ifcState <> C_Ifc.OUTDOORS then begin
    if GDVars.enteringLoop = 1 then begin
      CharHlp.DisplayNoncombatInterface;
      GDVars.enteringLoop := 0;
    end;
    MapView.DisplayMapView;
  end;
  GDVars.zone0^.previousScriptId := GDVars.eclScriptId;
  repeat
    cmd := Explore.MapMainMenu;
    GDVars.savedChar := GDVars.curChar;
    GDVars.zone0^.previousScriptId := GDVars.eclScriptId;
    while ((GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] > 1) or (UpCase(cmd) = 'E')) and
        (not GDVars.partyDefeated) do begin
      if UpCase(cmd) = 'E' then
        EclVm.EnterCamp
      else begin
        GDVars.savedSearchMode := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1;
        GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := 1;
        MapView.DisplayMapView;
        EclVm.CallEclScript(GDVars.scriptEntryAddrs[C_Ecl.SEARCH_ENTRY]);
        if GDVars.newEclFlag <> 0 then
          EclVm.NewEclDone;
        GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.savedSearchMode;
      end;
      if not GDVars.partyDefeated then begin
        cmd := Explore.MapMainMenu;
        GDVars.savedChar := GDVars.curChar;
      end;
    end;
    if not GDVars.partyDefeated then
      EclVm.CallEclScript(GDVars.scriptEntryAddrs[1]);
    if GDVars.newEclFlag <> 0 then
      EclVm.NewEclDone
    else if not GDVars.partyDefeated then begin
      GDVars.zone0^.previousX := GDVars.partyPos.mapX;
      GDVars.zone0^.previousY := GDVars.partyPos.mapY;
      Explore.ResolveMovement;
      MapView.DisplayMapView;
      if (GDVars.partyPos.mapX <> GDVars.zone0^.previousX) or (GDVars.partyPos.mapY <> GDVars.zone0^.previousY) then
        SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
      GDVars.eclGraphics := False;
      GDVars.picDrawn := True;
      EclVm.CallEclScript(GDVars.scriptEntryAddrs[C_Ecl.SEARCH_ENTRY]);
      if GDVars.newEclFlag <> 0 then
        EclVm.NewEclDone;
    end;
  until GDVars.partyDefeated;
  GDVars.partyDefeated := False;
end;

begin
end.
