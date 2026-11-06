{ ECL variable decoding, game-memory access, script menus, comparisons and subroutine calls. }
{$O+,F+}
unit EclMenu;

interface

uses Types, Crt, C_Area, C_Npc, C_Save, C_Msg, GDConsts, GDVars, Portrait, TextRend, DaxIo, CharHlp,
  MenuCore, MapView, SaveLoad, ViewChar, FxEngine, View3D, MapTiles, C_Effect, C_Ecl, C_Keys, C_Status, C_Gbvm, C_Dir,
  C_Money;

{ Gives the value of a loaded ECL variable: type 0 its byte, types 1 and 3 the GBVM word at its address, type 2 its
  word, and $81 (a string reference) its GBVM address. Note: the locals are named backwards, vHi holding the variable's
  low byte; and $80 (a string value) also reads the GBVM, at an address made of the packed length and a stale high byte.
  @param(idx The variable, from 1.)
  @returns(The value.) }
function GetEclVar(idx: ShortInt): Word;

{ Reads ECL variables at the ECL IP into eclVarType, eclVarLo and eclVarHi. Each variable has a type byte and a low
  byte; types 1 to 3 add a high byte. A string value ($80, its low byte the packed length) is decoded into gbStrings,
  and a string reference ($81, with a high byte) has the string at that GBVM address copied there. The IP ends on the
  byte after the last variable.
  @param(count The number of variables.) }
procedure LoadEclVars(count: Byte);

{ Resets the ECL state, reads the five script entry addresses from the header at $9900 and selects the 3D view. Unless a
  saved game was just loaded, GBVM $4A00 to $4A1F and $6E79 to $6E82 are zeroed; after a load the flag is cleared
  instead. }
procedure EclInit;

{ Loads an ECL script from ECL<disk>.DAX into the script zone, which is cleared first, retrying until the block gives at
  least two bytes; its first two bytes are skipped.
  @param(scriptId The script's block.) }
procedure LoadEclScript(scriptId: Byte);

{ Allocates and loads a monster.
  @param(id The monster's block.)
  @param(creature Receives the monster.)
  @param(inv Receives the head of its items.)
  @param(effect Receives the head of its effects.) }
procedure InitCreature(id: Byte; var creature: Types.PCharRecord; var inv: Types.PItemRec;
                       var effect: Types.PEffectRec);

{ Finds the farthest distance, 0 to 2, at which monsters may appear in front of the party: 2 when the 3D-view flag is 0
  (also stored in MONSTER_DISTANCE), otherwise the open cells ahead before the first wall, at most 2.
  @param(x Map column of the party's cell.)
  @param(y Map row of the party's cell.)
  @param(facing The direction the party faces.)
  @returns(The distance.) }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Loads and shows a portrait, remembering its head and body for later redraws.
  @param(headId The head picture.)
  @param(bodyId The body picture.) }
procedure DisplayPortrait(headId, bodyId: Byte);

{ Shows an encounter's monster: its sprite at the distance until a close-up is shown, and at distance 0 on the 3D map
  the close-up, a PIC picture or, while PICTURE_LOADING is not 255, the portrait with that head and the picture as its
  body.
  @param(sprId The SPRIT sprite.)
  @param(picId The close-up picture.)
  @param(dist The distance, 0 to 2; outside the 3D map the sprite is drawn at distance 2.)
  @param(flags Element 0 set once the sprite is loaded, element 1 once the close-up is shown.) }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Joins two bytes into a word.
  @param(lowByte The low byte.)
  @param(highByte The high byte.)
  @returns(The word.) }
function CombineBytesToWord(lowByte, highByte: Byte): Word;

{ Turns a 6-bit game character into ASCII: 0 to 31 become @ to _, higher codes stay as they are.
  @param(c The game character.)
  @returns(The ASCII character.) }
function DecodeGameCharacter(c: Byte): Char;

{ Finds the GBVM zone of an address: 0 for $4900 to $4CFF, 1 for $6B00 to $6EFF, 2 for $9700 to $98FF, 3 for $9900 to
  $B6FF (the script), otherwise 4 (special registers).
  @param(address The address.)
  @returns(The zone.) }
function GbvmZone(address: Word): Byte;

{ Finds a creature's place in the creature list.
  @param(creature The creature.)
  @returns(Its place from 0; the list's length when it is not there.) }
function FindCurCharIdx(creature: Types.PCharRecord): Byte;

{ Reads a zone 1 address that maps to the current character or other game state. Note: $10D, and $2CF for Charisma
  outside 3 to 25, are handled but leave the result unset.
  @param(address The address.)
  @param(found Receives True when the address is handled here.)
  @returns(The value.) }
function SpecialReadZ1(address: Word; var found: Boolean): Word;

{ Writes to a zone 1 address that maps to the current character or other game state, besides the zone's own word.
  @param(address The address.)
  @param(value The value.) }
procedure SpecialWriteZ1(address, value: Word);

{ Writes a value to a GBVM address; zone 1 also runs its special handling, and zone 4 sets special registers and the
  party's position, facing and view colors.
  @param(address The address.)
  @param(value The value.) }
procedure WriteGbvm(address, value: Word);

{ Reads a GBVM address. Zone 4 below $C04B gives fixed registers and from $C04B the party's position and view state.
  Note: an unhandled zone 4 address leaves the result unset.
  @param(address The address.)
  @returns(The value.) }
function ReadGbvm(address: Word): Word;

{ Writes a string to the GBVM, zero-terminated, one character per cell (words in zones 0 to 2, bytes in zone 3). GBVM
  $6B00 instead sets the current character's name, capped at 15 characters; zone 4 writes nothing.
  @param(address The address.)
  @param(s The string.) }
procedure WriteGbvmString(address: Word; s: String);

{ Decodes packed 6-bit game characters after the ECL IP into a string, four characters to three bytes; zero characters
  are dropped. The IP ends on the last byte read.
  @param(len The number of packed bytes.)
  @param(strIdx The gbStrings entry to fill.) }
procedure ConvGbString(len, strIdx: Byte);

{ Copies the zero-terminated GBVM string at an address into a string, one character per cell (the low byte of a word
  cell). GBVM $6B00 gives the current character's name, and zone 4 an empty string.
  @param(strIdx The gbStrings entry to fill.)
  @param(address The address.) }
procedure DerefGbString(strIdx: Byte; address: Word);

{ Runs a horizontal menu with ~ hotkeys; extended keys select the previous or next character.
  @param(query The prompt.)
  @param(menu The menu, with ~ before each hotkey.)
  @param(qCol The prompt's color.)
  @param(mCol The menu's color.)
  @param(hlCol The hotkeys' color.)
  @param(enterOk True to accept Enter.)
  @param(animate True to animate the menu picture while waiting.)
  @returns(The hotkey's place from 0; 0 for Enter; 255 for a letter or digit that is not a hotkey.) }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte;
                                       enterOk, animate: Boolean): Byte;

{ Runs a vertical list menu for a script, with ~ hotkeys in its commands; the key it returns is not kept.
  @param(query The prompt.)
  @param(menu The commands, with ~ before each hotkey.)
  @param(qCol The prompt's and the labels' color.)
  @param(mCol The entries' color.)
  @param(hlCol The highlight color.)
  @param(ulCol Left column of the box.)
  @param(ulRow Top row of the box.)
  @param(lrCol Right column of the box.)
  @param(lrRow Bottom row of the box.)
  @param(list The entries.)
  @param(addExit True to offer Exit.)
  @param(redraw True to draw the page; cleared once it is drawn.)
  @param(idx The highlighted entry, from 0.)
  @param(sel Receives the highlighted entry; nil for Exit or an empty list.) }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                          lrRow: ShortInt; list: Types.PItemRec; addExit: Boolean; var redraw: Boolean;
                          var idx: Integer; var sel: Types.PItemRec);

{ Sets the six comparison flags from two strings: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareStr(leftOperand, rightOperand: String);

{ Sets the six comparison flags from two numbers: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareInt(leftOperand, rightOperand: Word);

{ Pushes the ECL IP on the return stack, then jumps to the address in a loaded variable.
  @param(varIdx The variable holding the address.) }
procedure EclGosub(varIdx: Byte);

{ Sets up a duel: each creature not named as the current character is disabled. A mirror duel appends a hostile copy of
  the current character named ROLF, with the CPIC icon; its items are copied in reverse order and its effects are not.
  @param(mirror Nonzero for a mirror duel; stored in MIRROR_DUEL.) }
procedure CharFightsAlone(mirror: ShortInt);

{ Steps the party one cell forward, wrapping at the map's edges, then refreshes the cell's event and the wall ahead. }
procedure EclMoveForward;

{ Scales each of a creature's seven money types by a fraction, truncating.
  @param(fraction The fraction kept.)
  @param(creature The creature.) }
procedure RobMoney(fraction: Real; creature: Types.PCharRecord);

{ Steals each of a creature's items on a roll within the chance; an item heavier than 255 takes 90 off the chance and
  one heavier than 24 takes 50. Note: the reductions come off the chance itself, so they add up over the items.
  @param(chance The chance, in percent.)
  @param(creature The creature.) }
procedure RobItems(chance: Byte; creature: Types.PCharRecord);

{ Steps the ECL IP past the command at it without running it, loading the command's variables; an opcode not listed
  skips one byte. }
procedure SkipEclCmd;

{ Finds the party's highest and lowest movement, haste doubling and otherwise slow halving it. Both start from the first
  member's unadjusted movement, so that value always lies within them. Note: the first member is read before the check
  for nil, so an empty party is read through nil.
  @param(hiMove Receives the highest movement.)
  @param(loMove Receives the lowest movement.) }
procedure MoveExtremes(var hiMove, loMove: Byte);

{ Deals script damage to a creature with a message, then redraws the party panel; a dead creature is skipped. The
  creature dies when the damage is more than 10 above its hit points; otherwise the message gives the damage, at most
  three digits. When the message window is full it waits for a key first.
  @param(dmg The damage.)
  @param(creature The creature.) }
procedure EclInflictDamage(dmg: Word; creature: Types.PCharRecord);

implementation

procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  v: Word;
  len: Word;
begin
  strIdx := 0;
  for i := 1 to count do begin
    GDVars.eclVarType[i] := GDVars.zone3^[GDVars.eclIp + 1];
    GDVars.eclVarLo[i] := GDVars.zone3^[GDVars.eclIp + 2];
    GDVars.eclIp := GDVars.eclIp + 2;
    case GDVars.eclVarType[i] of
      1, 2, 3: begin
        Inc(GDVars.eclIp);
        GDVars.eclVarHi[i] := GDVars.zone3^[GDVars.eclIp];
      end;
      $80: begin
        Inc(strIdx);
        len := GDVars.eclVarLo[i];
        if len > 0 then
          EclMenu.ConvGbString(len, strIdx)
        else
          GDVars.gbStrings[strIdx] := '';
      end;
      $81: begin
        Inc(strIdx);
        Inc(GDVars.eclIp);
        GDVars.eclVarHi[i] := GDVars.zone3^[GDVars.eclIp];
        v := EclMenu.CombineBytesToWord(GDVars.eclVarLo[i], GDVars.eclVarHi[i]);
        EclMenu.DerefGbString(strIdx, v);
      end;
    end;
  end;
  Inc(GDVars.eclIp);
end;

function GetEclVar(idx: ShortInt): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  address: Word;
  { Unused in this version; see the other implementations of this routine. }
  value: Word;
  { Unused in this version; see the other implementations of this routine. }
  kind: Word;
  vHi: Byte;
  vLo: Byte;
begin
  vHi := GDVars.eclVarLo[idx];
  vLo := GDVars.eclVarHi[idx];
  case GDVars.eclVarType[idx] of
    0: GetEclVar := vHi;
    1, 3, $80: GetEclVar := EclMenu.ReadGbvm(vLo * 256 + vHi);
    2, $81: GetEclVar := EclMenu.CombineBytesToWord(vHi, vLo);
  end;
end;

procedure EclInit;
var
  { Unused in this version; see the other implementations of this routine. }
  scriptId: Byte;
  i: Word;
begin
  GDVars.eclGraphics := False;
  GDVars.protTextShown := 0;
  GDVars.dumpOnStatusClear := False;
  GDVars.dumpOnNameClear := False;
  GDVars.wallColorSel := 65;
  GDVars.ceilFloorColorSel := 9;
  GDVars.picRegionW := True;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.iconAnim := 8;
  GDVars.eclIp := $9900;
  GDVars.breathAim := False;
  GDVars.eclStackTop := nil;
  GDVars.eclStackPrev := nil;
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  { No portrait head (255), so DisplayMonster shows the PIC close-up }
  GDVars.zone1^[C_Gbvm.PICTURE_LOADING] := 255;
  { rest interruption }
  GDVars.zone1^[C_Gbvm.REST_SAFE_TIME] := 0;
  GDVars.zone1^[C_Gbvm.REST_INTERRUPT_PERCENT] := 0;
  GDVars.zone0^.antimagic := 0;
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[1] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[C_Ecl.SEARCH_ENTRY] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1],
                                                                            GDVars.eclVarHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[3] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[4] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[5] := EclMenu.CombineBytesToWord(GDVars.eclVarLo[1], GDVars.eclVarHi[1]);
  { Select the 3D view (MapView treats view3dFlag <> 0 as location type 1) }
  GDVars.zone0^.view3dFlag := 1;
  if GDVars.loadedSave = 0 then begin
    for i := 1 to 32 do
      { GBVM $4A00..$4A1F }
      GDVars.zone0^.words[i + $49FF] := 0;
    for i := 0 to 9 do
      { GBVM $6E79..$6E82 }
      GDVars.zone1^[i + $6E79] := 0;
  end else
    GDVars.loadedSave := 0;
end;

procedure LoadEclScript(scriptId: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  scriptSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  scriptOffset: Word;
  s: String[1];
  sizeRead: Word;
  data: Types.PByteArr;
begin
  FillChar(GDVars.zone3^, SizeOf(Types.TZone3), 0);
  GDVars.suppressDiskPrompt := #0;
  repeat
    MenuCore.ClearBottomLine;
    TextRend.DisplayString(0, 24, White, 'Loading...Please Wait');
    Str(GDVars.virtualDisk, s);
    DaxIo.LoadDax('ECL' + s, '.dax', scriptId, sizeRead, data);
  until sizeRead >= 2;
  Move(data^[2], GDVars.zone3^, sizeRead - 2);
  FreeMem(data, sizeRead);
  MenuCore.ClearBottomLine;
end;

procedure InitCreature(id: Byte; var creature: Types.PCharRecord; var inv: Types.PItemRec;
                       var effect: Types.PEffectRec);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
begin
  creature := nil;
  GetMem(creature, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData(id, creature);
  inv := creature^.itemsAddr;
  effect := creature^.effectsAddr;
end;

function MaxMonsterDist(x, y, facing: Byte): Byte;
var
  blocked: Boolean;
  dist: Byte;
begin
  dist := 0;
  blocked := False;
  MaxMonsterDist := 0;
  if GDVars.zone0^.view3dFlag = 0 then begin
    MaxMonsterDist := 2;
    GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] := 2;
  end else
    while (dist < 2) and (not blocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        MaxMonsterDist := dist;
        case facing of
          C_Dir.NORTH: Dec(y);
          C_Dir.EAST: Inc(x);
          C_Dir.SOUTH: Inc(y);
          C_Dir.WEST: Dec(x);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayPortrait(headId, bodyId: Byte);
begin
  GDVars.picDrawn := False;
  GDVars.portraitHead := headId;
  GDVars.portraitBody := bodyId;
  Portrait.LoadPortraitBufs(headId, bodyId);
  Portrait.DisplayPortraitBufs(3, 3, True);
end;

procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);
var
  { Unused in this version; see the other implementations of this routine. }
  headPic: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  bodyPic: Pointer;
  spriteDist: Byte;
begin
  if (not flags[1]) and flags[0] then
    MapView.DisplayMapView;
  spriteDist := dist + 1;
  if not flags[1] then begin
    if not flags[0] then begin
      if GDVars.automapOn then begin
        GDVars.automapOn := False;
        MapView.DisplayMapView;
      end;
      Portrait.LoadAnimation('SPRIT', sprId, 1, GDVars.animData);
      flags[0] := True;
      GDVars.sprShown := True;
    end;
    if GDVars.locType = C_Area.LOC_3D_MAP then
      Portrait.Show3DSprite(spriteDist, GDVars.animData)
    else
      Portrait.Show3DSprite(2, GDVars.animData);
  end;
  if flags[1] then
    if GDVars.picIdShown = GDVars.zone1^[C_Gbvm.PICTURE_LOADING] then
      Exit;
  if dist <> 0 then Exit;
  if GDVars.locType <> C_Area.LOC_3D_MAP then Exit;
  if (GDVars.inEncMenu <> 0) and (GDVars.monsterPics = 0) then Exit;
  GDVars.picIdShown := Byte(GDVars.zone1^[C_Gbvm.PICTURE_LOADING]);
  GDVars.eclGraphics := True;
  if GDVars.zone1^[C_Gbvm.PICTURE_LOADING] = 255 then begin
    Portrait.LoadAnimation('PIC', picId, 0, GDVars.animData);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
  end else begin
    EclMenu.DisplayPortrait(Byte(GDVars.zone1^[C_Gbvm.PICTURE_LOADING]), picId);
    flags[1] := True;
    GDVars.picDrawn := False;
  end;
end;

function CombineBytesToWord(lowByte, highByte: Byte): Word;
begin
  CombineBytesToWord := highByte * 256 + lowByte;
end;

function DecodeGameCharacter(c: Byte): Char;
begin
  if c > 31 then
    DecodeGameCharacter := Chr(c)
  else
    DecodeGameCharacter := Chr(c + 64);
end;

function GbvmZone(address: Word): Byte;
begin
  GbvmZone := 4;
  if (address >= $4900) and (address <= $4CFF) then GbvmZone := 0;
  if (address >= $6B00) and (address <= $6EFF) then GbvmZone := 1;
  if (address >= $9700) and (address <= $98FF) then GbvmZone := 2;
  if (address >= $9900) and (address <= $B6FF) then GbvmZone := 3;
end;

function FindCurCharIdx(creature: Types.PCharRecord): Byte;
var
  idx: Byte;
  p: Types.PCharRecord;
  found: Boolean;
begin
  p := GDVars.creatureList;
  found := False;
  idx := 0;
  while (p <> nil) and (not found) do begin
    if p = creature then
      found := True
    else begin
      Inc(idx);
      p := p^.nextCharAddr;
    end;
  end;
  FindCurCharIdx := idx;
end;

function SpecialReadZ1(address: Word; var found: Boolean): Word;
var
  t: Byte;
begin
  found := True;
  address := address - $6B00;
  case address of
    $18: SpecialReadZ1 := GDVars.curChar^.conCur;
    $9B: SpecialReadZ1 := GDVars.curChar^.saves[C_Save.PETRIFICATION];
    $A0: SpecialReadZ1 := GDVars.curChar^.levelHighest;
    $A5..$AC: begin
      t := address - $A4;
      SpecialReadZ1 := GDVars.curChar^.thiefSkills[t];
    end;
    $B8: SpecialReadZ1 := GDVars.curChar^.npc;
    $BB: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.COPPER];
    $BD: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.SILVER];
    $BF: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.ELECTRUM];
    $C1: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.GOLD];
    $C3: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.PLATINUM];
    $D8: SpecialReadZ1 := ShortInt(GDVars.curChar^.alignment);
    $F7: SpecialReadZ1 := GDVars.curChar^.xpAward;
    $F9: SpecialReadZ1 := GDVars.curChar^.xpBonusPerHp;
    $100:
      if GDVars.curChar^.enabled <> 0 then
        SpecialReadZ1 := 1
      else
        SpecialReadZ1 := $80;
    $10C:
      if (GDVars.curChar^.hostile = 0) and (GDVars.curChar^.quickfight <> 0) then
        SpecialReadZ1 := $80
      else if GDVars.curChar^.hostile = 1 then
        SpecialReadZ1 := $81
      else
        SpecialReadZ1 := 0;
    { handled, but no value is returned }
    $10D: ;
    $11B: SpecialReadZ1 := GDVars.curChar^.movementCur;
    $2B1: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2B4: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2CF:
      { charisma -> loyalty base; no result for charisma outside 3..25 }
      case GDVars.curChar^.chaCur of
        3: SpecialReadZ1 := 0;
        4: SpecialReadZ1 := 5;
        5: SpecialReadZ1 := 10;
        6: SpecialReadZ1 := 15;
        7: SpecialReadZ1 := 20;
        8..12: SpecialReadZ1 := 25;
        13: SpecialReadZ1 := 30;
        14: SpecialReadZ1 := 35;
        15: SpecialReadZ1 := 40;
        16: SpecialReadZ1 := 50;
        17: SpecialReadZ1 := 55;
        18..25: SpecialReadZ1 := 60;
      end;
    $312: SpecialReadZ1 := GDVars.virtualDisk;
    { party size }
    $33E: SpecialReadZ1 := GDVars.zone1^[C_Gbvm.PARTY_SIZE];
  else
    found := False;
  end;
end;

procedure SpecialWriteZ1(address, value: Word);
var
  t: Byte;
begin
  address := address - $6B00;
  case address of
    0:
      if value = 0 then GDVars.dumpOnNameClear := True;
    { a raw window into the character record, starting at memorizedSpells[1] and running on past it }
    $20..$70: begin
      t := address - $1F;
      GDVars.curChar^.memorizedSpells[t] := value;
    end;
    $B8: begin
      { values above ANIMATED_CREATURE ($B2) lose $32 (= ANIMATED_CREATURE and MORALE_MASK) }
      if value > C_Npc.ANIMATED_CREATURE then Dec(value, $32);
      GDVars.curChar^.npc := value;
    end;
    $BB: GDVars.curChar^.coins[C_Money.COPPER] := value;
    $BD: GDVars.curChar^.coins[C_Money.SILVER] := value;
    $BF: GDVars.curChar^.coins[C_Money.ELECTRUM] := value;
    $C1: GDVars.curChar^.coins[C_Money.GOLD] := value;
    $C3: GDVars.curChar^.coins[C_Money.PLATINUM] := value;
    $F7: GDVars.curChar^.xpAward := value;
    $F9: GDVars.curChar^.xpBonusPerHp := value;
    $100: begin
      if value >= $80 then begin
        GDVars.curChar^.enabled := 0;
        if value = $87 then GDVars.curChar^.status := C_Status.STONED;
      end;
      if value = 0 then GDVars.dumpOnStatusClear := True;
    end;
    $10C:
      case value of
        0: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 0;
        end;
        $80: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 1;
        end;
        $81: begin
          GDVars.curChar^.hostile := 1;
          GDVars.curChar^.quickfight := 1;
        end;
      end;
    $312: DaxIo.PushState(value);
    $322:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 1);
      end;
    $324:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 2);
      end;
    $326:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 3);
      end;
  end;
end;

procedure WriteGbvm(address, value: Word);
var
  zone: ShortInt;
  ok: Boolean;
begin
  zone := EclMenu.GbvmZone(address);
  case zone of
    0: begin
      GDVars.zone0^.words[address] := value;
      if (address = $49FD) or (address = $49FE) then
        GDVars.redrawSky := True;
    end;
    1: begin
      GDVars.zone1^[address] := value;
      EclMenu.SpecialWriteZ1(address, value);
    end;
    2:
      GDVars.zone2^[address] := value;
    3:
      GDVars.zone3^[address] := value;
    4:
      if address < $BF68 then
        case address of
          $FB: ;
          $FC: ;
          $B1: ;
          $3DE: GDVars.sndEffect := value;
          $B8: GDVars.writeReg1 := value;
          $B9: GDVars.writeReg2 := value;
        end else begin
        address := address - $BF68;
        case address of
          { party X }
          $E3: begin
            GDVars.movedParty := True;
            GDVars.partyPos.mapX := value;
          end;
          { party Y }
          $E4: begin
            GDVars.partyPos.mapY := value;
            GDVars.movedParty := True;
          end;
          { facing, mod-4 loop }
          $E5: begin
            repeat
              ok := True;
              case value of
                0: GDVars.partyPos.facing := C_Dir.NORTH;
                1: GDVars.partyPos.facing := C_Dir.EAST;
                2: GDVars.partyPos.facing := C_Dir.SOUTH;
                3: GDVars.partyPos.facing := C_Dir.WEST;
              else begin
                ok := False;
                Dec(value, 4);
              end;
              end;
            until ok = True;
            GDVars.movedParty := True;
          end;
          $F1: begin
            GDVars.wallColorSel := value;
            GDVars.picRegionW := True;
          end;
          $F7: begin
            GDVars.ceilFloorColorSel := value;
            GDVars.picRegionW := True;
          end;
          { accepted, ignored }
          $10BA: ;
        end;
      end;
  end;
end;

function ReadGbvm(address: Word): Word;
var
  zone: Byte;
  found: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  offset: Word;
begin
  zone := EclMenu.GbvmZone(address);
  found := False;
  case zone of
    0:
      ReadGbvm := GDVars.zone0^.words[address];
    1: begin
      ReadGbvm := EclMenu.SpecialReadZ1(address, found);
      if not found then
        ReadGbvm := GDVars.zone1^[address];
    end;
    2:
      ReadGbvm := GDVars.zone2^[address];
    3:
      ReadGbvm := GDVars.zone3^[address];
    4:
      if address < $C04B then
        case address of
          $B1: ReadGbvm := GDVars.readReg3;
          $FB: ReadGbvm := GDVars.readReg1;
          $FC: ReadGbvm := GDVars.readReg2;
          $33D: ReadGbvm := GDVars.partyPos.facing;
          { handled, but no value is returned }
          $35F: ;
        end else begin
        address := address - $C04B;
        case address of
          { sign-extends (ShortInt) }
          0: ReadGbvm := GDVars.partyPos.mapX;
          1: ReadGbvm := GDVars.partyPos.mapY;
          2: ReadGbvm := Word(GDVars.partyPos.facing) div 2;
          3: ReadGbvm := GDVars.partyPos.wallAhead;
          4: ReadGbvm := GDVars.partyPos.eventAtCell;
          { Wall color ($C059): write-only, result unassigned }
          14: ;
        end;
      end;
  end;
end;

procedure WriteGbvmString(address: Word; s: String);
var
  zone: ShortInt;
  len: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(address);
  len := Length(s);
  case zone of
    0: begin
      for i := 0 to len - 1 do
        GDVars.zone0^.words[address + i] := Ord(s[i + 1]);
      GDVars.zone0^.words[address + len] := 0;
    end;
    1:
      if address = $6B00 then
        GDVars.curChar^.name := s
      else begin
        for i := 0 to len - 1 do
          GDVars.zone1^[address + i] := Ord(s[i + 1]);
        GDVars.zone1^[address + len] := 0;
      end;
    2: begin
      for i := 0 to len - 1 do
        GDVars.zone2^[address + i] := Ord(s[i + 1]);
      GDVars.zone2^[address + len] := 0;
    end;
    3: begin
      for i := 0 to len - 1 do
        GDVars.zone3^[address + i] := Ord(s[i + 1]);
      GDVars.zone3^[address + len] := 0;
    end;
  end;
end;

procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outPos: Byte;
  cur: Byte;
  prev: Byte;
  gbChar: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.eclIp);
      prev := cur;
      cur := GDVars.zone3^[GDVars.eclIp];
      Inc(i);
    end;
    case phase of
      1:
        gbChar := cur shr 2;
      2: begin
        gbChar := prev shl 6 + cur shr 2;
        gbChar := gbChar shr 2;
      end;
      3: begin
        gbChar := prev shl 4 + cur shr 4;
        gbChar := gbChar shr 2;
      end;
      4:
        gbChar := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if gbChar <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(gbChar);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
  if phase = 4 then begin
    gbChar := cur and $3F;
    if gbChar <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(gbChar);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
end;

procedure DerefGbString(strIdx: Byte; address: Word);
var
  zone: ShortInt;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(address);
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  case zone of
    0:
      while GDVars.zone0^.words[address + i] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.zone0^.words[address + i]));
        Inc(i);
      end;
    1:
      if address = $6B00 then
        GDVars.gbStrings[strIdx] := GDVars.curChar^.name
      else
        while GDVars.zone1^[address + i] <> 0 do begin
          GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.zone1^[address + i]));
          Inc(i);
        end;
    2:
      while GDVars.zone2^[address + i] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.zone2^[address + i]));
        Inc(i);
      end;
    3:
      while GDVars.zone3^[address + i] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.zone3^[address + i]));
        Inc(i);
      end;
  end;
end;

{ Prepares a menu with ~ hotkeys: letters and digits are lowered (digits shift by 32 too), each ~ is taken out and the
  character after it raised and collected as a hotkey.
  @param(menu The menu, edited in place.)
  @param(opts Receives the hotkeys.) }
procedure MenuToOptions(var menu: String; var opts: Types.TStr40);
var
  i: Byte;
begin
  opts := '';
  for i := 1 to Length(menu) do begin
    if menu[i] in ['0'..'9', 'A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      menu[i] := UpCase(menu[i]);
      opts := opts + menu[i];
    end;
  end;
end;

function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte;
                                       enterOk, animate: Boolean): Byte;
var
  opts: Types.TStr40;
  idx: Byte;
  ch: Char;
  ext: Boolean;
begin
  EclMenu.MenuToOptions(menu, opts);
  repeat
    ch := MenuCore.MenuHorizontal(query, menu, qCol, mCol, hlCol, True, animate, ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(ch);
      CharHlp.DisplayParty(GDVars.curChar);
      ch := C_Keys.NONE;
    end;
  until (ch in ['0'..'9', 'A'..'Z']) or ((ch = C_Keys.ENTER) and enterOk);
  case ch of
    C_Keys.ENTER: MenuHorizontalCharacterSelect := 0;
  else begin
    idx := 1;
    while (idx <= Length(opts)) and (opts[idx] <> ch) do
      Inc(idx);
    if idx <= Length(opts) then
      MenuHorizontalCharacterSelect := idx - 1
    else
      MenuHorizontalCharacterSelect := 255;
  end;
  end;
end;

procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                          lrRow: ShortInt; list: Types.PItemRec; addExit: Boolean; var redraw: Boolean;
                          var idx: Integer; var sel: Types.PItemRec);
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  opts: Types.TStr40;
begin
  EclMenu.MenuToOptions(menu, opts);
  ch := MenuCore.MenuVertical(query, menu, qCol, mCol, hlCol, ulCol, ulRow, lrCol, lrRow, list, addExit, redraw, idx,
                              sel);
end;

procedure EclCompareStr(leftOperand, rightOperand: String);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if leftOperand = rightOperand then GDVars.cmpFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.cmpFlags[1] := True;
  if leftOperand < rightOperand then GDVars.cmpFlags[2] := True;
  if leftOperand > rightOperand then GDVars.cmpFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.cmpFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.cmpFlags[5] := True;
end;

procedure EclCompareInt(leftOperand, rightOperand: Word);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if leftOperand = rightOperand then GDVars.cmpFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.cmpFlags[1] := True;
  if leftOperand < rightOperand then GDVars.cmpFlags[2] := True;
  if leftOperand > rightOperand then GDVars.cmpFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.cmpFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.cmpFlags[5] := True;
end;

procedure EclGosub(varIdx: Byte);
begin
  if GDVars.eclStackTop = nil then begin
    GetMem(GDVars.eclStackTop, SizeOf(Types.TEclRet));
    GDVars.eclStackTop^.next := nil;
  end else begin
    GDVars.eclStackPrev := GDVars.eclStackTop;
    GetMem(GDVars.eclStackTop, SizeOf(Types.TEclRet));
    GDVars.eclStackTop^.next := GDVars.eclStackPrev;
  end;
  GDVars.eclStackTop^.addr := GDVars.eclIp;
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.eclVarLo[varIdx], GDVars.eclVarHi[varIdx]);
end;

procedure EclMoveForward;
begin
  case GDVars.partyPos.facing of
    C_Dir.NORTH: if GDVars.partyPos.mapY > 0 then Dec(GDVars.partyPos.mapY) else GDVars.partyPos.mapY := 15;
    C_Dir.EAST: if GDVars.partyPos.mapX < 15 then Inc(GDVars.partyPos.mapX) else GDVars.partyPos.mapX := 0;
    C_Dir.SOUTH: if GDVars.partyPos.mapY < 15 then Inc(GDVars.partyPos.mapY) else GDVars.partyPos.mapY := 0;
    C_Dir.WEST: if GDVars.partyPos.mapX > 0 then Dec(GDVars.partyPos.mapX) else GDVars.partyPos.mapX := 15;
  end;
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
end;

procedure CharFightsAlone(mirror: ShortInt);
var
  p: Types.PCharRecord;
  clone: Types.PCharRecord;
  cur: Types.PCharRecord;
  srcIt: Types.PItemRec;
  tmp: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  srcEff: Pointer;
begin
  GDVars.duelFlag := True;
  GDVars.zone1^[C_Gbvm.MIRROR_DUEL] := mirror;
  cur := GDVars.curChar;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.name <> cur^.name then
      p^.enabled := 0;
    p := p^.nextCharAddr;
  end;
  if mirror = 0 then Exit;
  MapTiles.LoadIconAnim('CPIC', 11, GDVars.iconAnim);
  p := GDVars.creatureList;
  while p^.nextCharAddr <> nil do
    p := p^.nextCharAddr;
  GetMem(clone, SizeOf(Types.TCharRecord));
  clone^ := cur^;
  clone^.enabled := 1;
  clone^.nextCharAddr := nil;
  clone^.name := 'ROLF';
  clone^.quickfight := 1;
  clone^.hostile := 1;
  clone^.npc := C_Npc.ANIMATED_CREATURE;
  clone^.orderNumber := GDVars.iconAnim;
  clone^.effectsAddr := nil;
  clone^.itemsAddr := nil;
  p^.nextCharAddr := clone;
  p := p^.nextCharAddr;
  srcIt := cur^.itemsAddr;
  while srcIt <> nil do begin
    if p^.itemsAddr = nil then begin
      GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
      p^.itemsAddr^ := srcIt^;
      p^.itemsAddr^.next := nil;
    end else begin
      tmp := p^.itemsAddr;
      GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
      p^.itemsAddr^ := srcIt^;
      p^.itemsAddr^.next := tmp;
    end;
    srcIt := srcIt^.next;
  end;
end;

procedure RobMoney(fraction: Real; creature: Types.PCharRecord);
begin
  creature^.coins[C_Money.COPPER] := Trunc(creature^.coins[C_Money.COPPER] * fraction);
  creature^.coins[C_Money.SILVER] := Trunc(creature^.coins[C_Money.SILVER] * fraction);
  creature^.coins[C_Money.ELECTRUM] := Trunc(creature^.coins[C_Money.ELECTRUM] * fraction);
  creature^.coins[C_Money.GOLD] := Trunc(creature^.coins[C_Money.GOLD] * fraction);
  creature^.coins[C_Money.PLATINUM] := Trunc(creature^.coins[C_Money.PLATINUM] * fraction);
  creature^.coins[C_Money.GEMS] := Trunc(creature^.coins[C_Money.GEMS] * fraction);
  creature^.coins[C_Money.JEWELRY] := Trunc(creature^.coins[C_Money.JEWELRY] * fraction);
end;

procedure RobItems(chance: Byte; creature: Types.PCharRecord);
var
  roll: Byte;
  item: Types.PItemRec;
  nxt: Types.PItemRec;
begin
  item := creature^.itemsAddr;
  while item <> nil do begin
    if item^.weight > 255 then begin
      if chance > 90 then
        chance := chance - 90
      else
        chance := 0;
    end else if item^.weight > 24 then begin
      if chance > 50 then
        chance := chance - 50
      else
        chance := 0;
    end;
    roll := FxEngine.RollDice(1, 100);
    nxt := item^.next;
    if roll <= chance then
      CharHlp.RemoveItem(creature, item);
    item := nxt;
  end;
end;

procedure SkipEclCmd;
begin
  GDVars.curOpcode := GDVars.zone3^[GDVars.eclIp];
  case GDVars.curOpcode of
    C_Ecl.OP_GOTO, C_Ecl.GOSUB, C_Ecl.LOAD_CHARACTER, C_Ecl.PICTURE, C_Ecl.PRINT, C_Ecl.PRINT_CLEAR,
        C_Ecl.PARTY_STRENGTH, C_Ecl.NEW_ECL, C_Ecl.CALL,
    C_Ecl.FIND_ITEM, C_Ecl.CLOCK, C_Ecl.ADD_NPC, C_Ecl.OP_PROGRAM, C_Ecl.WHO, C_Ecl.PROTECTION:
      EclMenu.LoadEclVars(1);
    C_Ecl.COMPARE, C_Ecl.OP_RANDOM, C_Ecl.SAVE, C_Ecl.SETUP_MONSTER, C_Ecl.INPUT_NUMBER, C_Ecl.INPUT_STRING,
        $1F, C_Ecl.PARTY_SURPRISE:
      EclMenu.LoadEclVars(2);
    C_Ecl.ADD..C_Ecl.MULTIPLY, C_Ecl.LOAD_MONSTER, C_Ecl.LOAD_FILES, C_Ecl.ROB, C_Ecl.GET_TABLE,
        C_Ecl.OP_AND, C_Ecl.OP_OR, C_Ecl.SAVE_TABLE,
    C_Ecl.LOAD_PIECES, C_Ecl.SPELL:
      EclMenu.LoadEclVars(3);
    C_Ecl.COMPARE_AND, C_Ecl.SURPRISE:
      EclMenu.LoadEclVars(4);
    C_Ecl.DAMAGE:
      EclMenu.LoadEclVars(5);
    C_Ecl.CHECK_PARTY, C_Ecl.PARLAY:
      EclMenu.LoadEclVars(6);
    C_Ecl.TREASURE:
      EclMenu.LoadEclVars(8);
    C_Ecl.ENCOUNTER:
      EclMenu.LoadEclVars(14);
  else
    Inc(GDVars.eclIp);
  end;
end;

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
    msg := '  ' + creature^.name + ' is hit FOR ' + dmgStr + ' points of Damage.';
  if GDVars.curRow > C_Msg.TEXT_BOTTOM then begin
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    pause := True;
    TextRend.DisplayAndPause(White, 'press <enter>/<return> to continue');
  end else
    pause := False;
  GDVars.curCol := C_Msg.TEXT_RIGHT;
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                White, pause, msg);
  CharHlp.InflictDamage(creature, dmg);
  TextRend.ClearRect(17, 1, 38, 15);
  CharHlp.DisplayParty(GDVars.curChar);
end;

begin
end.
