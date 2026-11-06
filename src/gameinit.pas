{ Initialize game state, allocate graphics buffers, load shared resources and install spell and effect handlers. }
{$O+,F+,I-}
unit GameInit;

interface

uses Types, Crt, C_Area, C_Video, GDConsts, GDVars, SoundDrv, DaxIo, TextRend,
  Blit, Sym8x8, MenuCore, MapTiles, Magic, EffHndlr, C_Dir, C_Gbvm;

{ Starts a game session: allocates the GBVM zones and graphics buffers, builds the per-row video address tables, resets
  the game state to its defaults and sets the sound auto-stop, then loads the font, symbol sets, tile sets, combat icons
  and item table and installs the spell and effect handlers. }
procedure InitializeGame;

implementation

procedure InitializeGame;
begin
  GetMem(GDVars.zone0, SizeOf(Types.TGbvmZone0State));
  GetMem(GDVars.zone1, SizeOf(Types.TGbvmZone1));
  GetMem(GDVars.zone2, SizeOf(Types.TZone2));
  GetMem(GDVars.zone3, SizeOf(Types.TZone3));
  GetMem(GDVars.gameFont, SizeOf(Types.TFontArr));
  GetMem(GDVars.wallGfx, SizeOf(Types.TWallGfx));
  GetMem(GDVars.map3d, SizeOf(Types.TGeoMap));
  Blit.AllocPic(8, 1, 1, 0, GDVars.curSymbolSet);
  { the 168x168 view area }
  Blit.AllocPic(168, 21, 1, 0, GDVars.viewBuffer);
  { 24x24 save-under block }
  Blit.AllocPic(24, 3, 1, 0, GDVars.saveUnder);
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);
  { Per-row video addresses: CGA segment (even and odd rows in separate banks, a row pair every 5 paragraphs), EGA
    offset (40 bytes per row), Tandy segment (four banks, four rows every 10 paragraphs). }
  for GDVars.gi2 := 0 to 199 do begin
    if Odd(GDVars.gi2) then
      GDVars.cgaRowSeg[GDVars.gi2] := (GDVars.gi2 div 2) * 5 + C_Video.GFX_BANK1_SEG
    else
      GDVars.cgaRowSeg[GDVars.gi2] := (GDVars.gi2 div 2) * 5 + C_Video.GFX_BANK0_SEG;
    GDVars.fbRowOfs[GDVars.gi2] := GDVars.gi2 * 40;
    case GDVars.gi2 mod 4 of
      0: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK0_SEG;
      1: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK1_SEG;
      2: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK2_SEG;
      3: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK3_SEG;
    end;
  end;
  FillChar(GDVars.symbolSets, SizeOf(GDVars.symbolSets), 0);
  FillChar(GDVars.tileSetLow, SizeOf(GDVars.tileSetLow) + SizeOf(GDVars.tileSetHigh), 0);
  FillChar(GDVars.zone0^, SizeOf(Types.TGbvmZone0State), 0);
  FillChar(GDVars.zone1^, SizeOf(Types.TGbvmZone1), 0);
  FillChar(GDVars.zone2^, SizeOf(Types.TZone2), 0);
  FillChar(GDVars.zone3^, SizeOf(Types.TZone3), 0);
  FillChar(GDVars.iconAnimation, SizeOf(GDVars.iconAnimation), 0);
  for GDVars.gi2 := 1 to 2 do begin
    GDVars.portraitCache[GDVars.gi2].pictureId := 255;
    GDVars.portraitCache[GDVars.gi2].pic := nil;
  end;
  FillChar(GDVars.animData, SizeOf(GDVars.animData), 0);
  GDVars.treasureItems := nil;
  { Clear the five bytes mapX, mapY, facing, wallAhead and eventAtCell. Position and facing are assigned below. }
  FillChar(GDVars.partyPos, SizeOf(GDVars.partyPos), 0);
  GDVars.partyPos.mapX := 15;
  GDVars.partyPos.mapY := 1;
  GDVars.partyPos.facing := C_Dir.WEST;
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  { WALLDEF reload ID 0, symbol slot 1 }
  GDVars.wallSetCache[1].wallDefId := 0;
  GDVars.wallSetCache[1].symbolSlot := 1;
  for GDVars.gi2 := 2 to 3 do begin
    { slots 2-3 = empty }
    GDVars.wallSetCache[GDVars.gi2].wallDefId := -1;
    GDVars.wallSetCache[GDVars.gi2].symbolSlot := -1;
  end;
  GDVars.portraitsOn := 1;
  GDVars.monsterPics := 1;
  GDVars.stingHpFlag := 0;
  GDVars.msgDelayFlag := 1;
  GDVars.loadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.creatureList := nil;
  GDVars.curChar := nil;
  GDVars.eclIp := $9900;
  GDVars.gameDelay := 1;
  GDVars.suppressContinuePrompt := 0;
  GDVars.virtualDisk := 1;
  GDVars.prevVirtualDisk := 1;
  GDVars.gameDisk := 1;
  GDVars.saveDisk := 1;
  GDVars.automapOn := False;
  GDVars.locTypePrev := C_Area.LOC_3D_MAP;
  GDVars.locType := C_Area.LOC_3D_MAP;
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
  GDVars.wildAnimFrame := 0;
  GDVars.vertTop := 1;
  GDVars.duelFlag := False;
  GDVars.suppressBorder := 0;
  GDVars.savedSearchMode := 0;
  GDVars.clearBoxDone := 0;
  GDVars.protNewLine := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.clipFlag := 1;
  GDVars.sprShown := False;
  GDVars.suppressDiskPrompt := #0;
  GDVars.picArcName[0] := #0;
  GDVars.picArcId := 255;
  GDVars.recentSaved := 0;
  GDVars.ceilFloorColorSel := 232;
  GDVars.wallColorSel := 219;
  GDVars.inEncMenu := 0;
  GDVars.soundAutoStop := 0;
  SoundDrv.SoundSetAutoStop(100);
  GDVars.savedDir := GDVars.gameDir;
  GDVars.gameDir[0] := #0;
  TextRend.LoadGameFont;
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Loading...Please Wait');
  Sym8x8.Load8x8Set(202, 4);
  Sym8x8.Load8x8Set(203, 0);
  Blit.LoadPic('sqrpaci', 1, False, 0, GDVars.tileSetLow);
  Blit.LoadPic('sqrpaci', 2, False, 0, GDVars.tileSetHigh);
  for GDVars.gi2 := 0 to 11 do
    MapTiles.LoadIconAnim('COMSPR', GDVars.gi2, GDVars.gi2 + 13);
  MapTiles.LoadIconAnim('COMSPR', 25, 25);
  GDVars.itemsOk := DaxIo.OpenWithRetry('ITEMS', GDConsts.insertDiskMsg[GDVars.virtualDisk] + GDVars.gameDir[1] + ':',
                                        #0, GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  Seek(GDVars.itemsFile, 2);
  { Note: this reads 129 records into the 128-entry item table, so the last one lands in the storage that follows it.
    The returned byte count is not checked. }
  BlockRead(GDVars.itemsFile, GDVars.baseItems, 129 * SizeOf(Types.TBaseItemRec), GDVars.itemsRead);
  Close(GDVars.itemsFile);
  GDVars.gameDir := GDVars.savedDir;
  MenuCore.ClearBottomLine;
  Randomize;
  { Install spell function pointers. }
  Magic.InitSpellFns;
  { Install effect function pointers. }
  EffHndlr.InitEffectHandlers;
end;

begin
end.
