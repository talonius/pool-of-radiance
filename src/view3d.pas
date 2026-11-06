{ Dungeon view and automap rendering, with GEO map and WALLDEF wall-set loading. }
{$O+,F+,I-}
unit View3D;

interface

uses Types, GDConsts, GDVars, Blit, DaxIo, GameIo, Sym8x8, C_Dir;

{ Empty routine with no callers. }
procedure InitView3D;

{ Sets the colors of the four bands of the 3D view's backdrop.
  @param(cSky The sky or ceiling.)
  @param(cHorz1 The horizon line.)
  @param(cHorz2 The horizon band below it.)
  @param(cFloor The floor.) }
procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);

{ Fills the four bands of the 3D view's backdrop into the view buffer: the sky, the horizon line, the horizon band and
  the floor. }
procedure DrawBackdrop;

{ Reads the wall on one side of a 3D map cell. A cell off the map wraps to the far edge, except under ECL scripts 0 and
  10, where it has no wall.
  @param(x Map column of the cell.)
  @param(y Map row of the cell.)
  @param(facing The side, a cardinal direction.)
  @returns(The wall type, 1 to 15, or 0 for no wall.) }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;

{ Reads the barrier on one side of a 3D map cell; a side with no wall is open. A cell off the map wraps to the far edge,
  except under ECL scripts 0 and 10, where it reads as a wall.
  @param(x Map column of the cell.)
  @param(y Map row of the cell.)
  @param(facing The side, a cardinal direction.)
  @returns(The barrier type: 0 a wall, 1 open, 2 a door, 3 a barred door.) }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;

{ Reads the event byte of a 3D map cell. A cell off the map wraps to the far edge, except under ECL scripts 0 and 10,
  where it reads as 0.
  @param(x Map column of the cell.)
  @param(y Map row of the cell.)
  @returns(The event byte.) }
function GetMapEvent(x, y: ShortInt): Byte;

{ Flushes the view buffer to the screen. }
procedure DisplayViewBuf;

{ Draws the 3D view from a cell, or the automap while it is on. The view is the backdrop, then the walls row by row from
  two cells ahead to the party's own row: fronts, the corners between far fronts, and the side walls. It is flushed to
  the screen.
  @param(x Map column of the party's cell.)
  @param(y Map row of the party's cell.)
  @param(facing The direction the party faces.) }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);

{ Loads a wall set from WALLDEF<disk>.DAX into a wall-set slot. A block that holds several wall sets fills the slots
  that follow as well, each with its own 8x8 symbol set, numbered fileId * 10 plus its place (file 0 counting as 10).
  Wall symbols from the first set's last symbol on are moved up to the slot's 8x8 symbol set, and the slot's cache entry
  is stamped. A missing block, or one with more wall sets than slots from wsSlot to 3, restores the video mode, prints
  an error and exits to DOS. Note: the size check does not count a partial last wall set, but the copy still copies it,
  into the slot after the last one counted, which can lie past slot 3.
  @param(fileId The block of WALLDEF.DAX.)
  @param(wsSlot The first wall-set slot to fill, 1 to 3; any other slot loads nothing.) }
procedure LoadWallSet(fileId, wsSlot: Byte);

{ Loads a map from GEO<disk>.DAX into the 3D map and records its number in zone 0. A block that is missing or not the
  size of a map restores the video mode, prints an error and exits to DOS.
  @param(mapId The block of GEO.DAX that holds the map.) }
procedure Load3DMap(mapId: Byte);

{ Empty routine with no callers. }
procedure ReleaseView3D;

{ Draws the 11x11 automap around a cell into the view buffer and flushes it: each cell shows its walls as one of sixteen
  8x8 symbols, and the party's cell shows an arrow for its facing. The window stops at the map's edges.
  @param(x Map column of the party's cell.)
  @param(y Map row of the party's cell.)
  @param(facing The direction the party faces.) }
procedure DrawAutoMap(x, y: ShortInt; facing: Byte);

{ Draws one wall slot's rectangle of 8x8 symbols for a wall type into the view buffer, transparently, skipping empty
  symbols and cells outside the 11x11 view.
  @param(x View column of the rectangle's left edge.)
  @param(y View row of the rectangle's top edge.)
  @param(wallType The wall type.)
  @param(slot The view slot, 0 to 9.) }
procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);

{ Tells whether a cell is on the 16x16 map.
  @param(x The map column.)
  @param(y The map row.)
  @returns(True when the cell is on the map.) }
function Valid3DCoords(x, y: ShortInt): Boolean;

implementation

procedure DrawAutoMap(x, y: ShortInt; facing: Byte);
var
  pwx: ShortInt;
  pwy: ShortInt;
  wx: ShortInt;
  wy: ShortInt;
  xLo: ShortInt;
  yLo: ShortInt;
  mx: ShortInt;
  my: ShortInt;
  sym: Word;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: String;
begin
  xLo := x - 5;
  if xLo < 0 then xLo := 0;
  if xLo > 5 then xLo := 5;
  pwx := x - xLo;
  yLo := y - 5;
  if yLo < 0 then yLo := 0;
  if yLo > 5 then yLo := 5;
  pwy := y - yLo;
  for wy := 0 to 10 do begin
    my := wy + yLo;
    for wx := 0 to 10 do begin
      mx := wx + xLo;
      sym := 260;
      if View3D.GetWallType(mx, my, C_Dir.NORTH) > 0 then Inc(sym);
      if View3D.GetWallType(mx, my, C_Dir.EAST) > 0 then Inc(sym, 2);
      if View3D.GetWallType(mx, my, C_Dir.SOUTH) > 0 then Inc(sym, 4);
      if View3D.GetWallType(mx, my, C_Dir.WEST) > 0 then Inc(sym, 8);
      Sym8x8.Put8x8Sym(wx + 3 - 1, wy + 3 - 1, sym, True, False);
    end;
  end;
  Sym8x8.Put8x8Sym(pwx + 3 - 1, pwy + 3 - 1, facing div 2 + 256, True, False);
  View3D.DisplayViewBuf;
end;

procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);
begin
  GDVars.skyCeilingColor := cSky;
  GDVars.ceilingBandColor := cHorz1;
  GDVars.midBandColor := cHorz2;
  GDVars.floorBandColor := cFloor;
end;

procedure DrawBackdrop;
begin
  Blit.FillPicRect(2, 16, 11, 43, GDVars.skyCeilingColor, GDConsts.iconColorMap,
                   GDVars.viewBuffer);
  Blit.FillPicRect(2, 59, 11, 1, GDVars.ceilingBandColor, GDConsts.iconColorMap, GDVars.viewBuffer);
  Blit.FillPicRect(2, 60, 11, 2, GDVars.midBandColor, GDConsts.iconColorMap, GDVars.viewBuffer);
  Blit.FillPicRect(2, 62, 11, 42, GDVars.floorBandColor, GDConsts.iconColorMap, GDVars.viewBuffer);
end;

procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);
var
  colLim: Integer;
  rowLim: Integer;
  col: Integer;
  row: Integer;
  cnt: Byte;
begin
  cnt := GDConsts.viewSlotGeom.start[slot];
  colLim := GDConsts.viewSlotGeom.cols[slot] + x - 1;
  rowLim := GDConsts.viewSlotGeom.rows[slot] + y - 1;
  for row := y to rowLim do
    for col := x to colLim do begin
      if (row >= 0) and (row <= 10) and (col >= 0) and (col <= 10) and (GDVars.wallGfx^.slices[wallType][cnt] > 0) then
        Sym8x8.Put8x8Sym(col + 3 - 1, row + 3 - 1, GDVars.wallGfx^.slices[wallType][cnt], True, True);
      Inc(cnt);
    end;
end;

function Valid3DCoords(x, y: ShortInt): Boolean;
begin
  if (x > 15) or (x < 0) or (y > 15) or (y < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;
var
  b: Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 10)) then
    GetBarrierType := 0
  else begin
    if x > 15 then x := 0;
    if x < 0 then x := 15;
    if y > 15 then y := 0;
    if y < 0 then y := 15;
    b := 1;
    if View3D.GetWallType(x, y, facing) > 0 then
      case facing of
        C_Dir.WEST: b := (GDVars.map3d^.barriers[y][x] and $C0) shr 6;
        C_Dir.SOUTH: b := (GDVars.map3d^.barriers[y][x] and $30) shr 4;
        C_Dir.EAST: b := (GDVars.map3d^.barriers[y][x] and $0C) shr 2;
        C_Dir.NORTH: b := GDVars.map3d^.barriers[y][x] and $03;
      end;
    GetBarrierType := b;
  end;
end;

function GetWallType(x, y: ShortInt; facing: Byte): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 10)) then
    GetWallType := 0
  else begin
    if x > 15 then x := 0;
    if x < 0 then x := 15;
    if y > 15 then y := 0;
    if y < 0 then y := 15;
    case facing of
      C_Dir.NORTH: GetWallType := (GDVars.map3d^.wallsNorthEast[y][x] and $F0) shr 4;
      C_Dir.EAST: GetWallType := GDVars.map3d^.wallsNorthEast[y][x] and $0F;
      C_Dir.SOUTH: GetWallType := (GDVars.map3d^.wallsSouthWest[y][x] and $F0) shr 4;
      C_Dir.WEST: GetWallType := GDVars.map3d^.wallsSouthWest[y][x] and $0F;
    end;
  end;
end;

function GetMapEvent(x, y: ShortInt): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 10)) then
    GetMapEvent := 0
  else begin
    if x > 15 then x := 0;
    if x < 0 then x := 15;
    if y > 15 then y := 0;
    if y < 0 then y := 15;
    GetMapEvent := GDVars.map3d^.events[y][x];
  end;
end;

procedure DisplayViewBuf;
begin
  Blit.FlushView;
end;

procedure Display3DMapView(x, y: ShortInt; facing: Byte);
var
  fL: Byte;
  fR: Byte;
  fB: Byte;
  cxPos: Integer;
  cyPos: Integer;
  dxF: Integer;
  dyF: Integer;
  wx: Integer;
  wy: Integer;
  side: Byte;
  symOfs: Integer;
  dist: Byte;
  wallFront: Byte;
  wallSide: Byte;
  { Unused in this version; see the other implementations of this routine. }
  wallBack: Byte;
  prevWall: Byte;
begin
  if GDVars.automapOn then
    View3D.DrawAutoMap(x, y, facing)
  else begin
    View3D.DrawBackdrop;
    fL := (facing + 6) mod 8;
    fB := (facing + 4) mod 8;
    fR := (facing + 2) mod 8;
    cxPos := x;
    cyPos := y;
    dxF := GDConsts.dirDx[facing];
    dyF := GDConsts.dirDy[facing];
    dist := 2;
    Inc(cxPos, dist * dxF);
    Inc(cyPos, dist * dyF);
    repeat
      case dist of
        2: begin
          { far row: fronts + corner slot 9, walking LEFT }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, fR) = 0) then
              prevWall := 0;
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs + 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[0] + symOfs, GDConsts.viewSlotGeom.yRow[0], wallFront, 0);
            end else begin
              if (prevWall > 0) and (View3D.GetWallType(wx - GDConsts.dirDx[fL], wy - GDConsts.dirDy[fL], fL) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs + 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side);
            Dec(symOfs, 2);
            wx := wx + GDConsts.dirDx[fL];
            wy := wy + GDConsts.dirDy[fL];
          end;
          { far row: fronts + corner slot 9, walking RIGHT }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, fL) = 0) then
              prevWall := 0;
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs - 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[0] + symOfs, GDConsts.viewSlotGeom.yRow[0], wallFront, 0);
            end else begin
              if (prevWall > 0) and (View3D.GetWallType(wx - GDConsts.dirDx[fR], wy - GDConsts.dirDy[fR], fR) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs - 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side);
            Inc(symOfs, 2);
            wx := wx + GDConsts.dirDx[fR];
            wy := wy + GDConsts.dirDy[fR];
          end;
          { far row left-side walls, slot 1 }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[1] + symOfs, GDConsts.viewSlotGeom.yRow[1], wallSide, 1)
              else
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[1] + symOfs - 1, GDConsts.viewSlotGeom.yRow[1],
                                     wallSide, 1);
            Inc(side);
            Dec(symOfs, 2);
            wx := wx + GDConsts.dirDx[fL];
            wy := wy + GDConsts.dirDy[fL];
          end;
          { far row right-side walls, slot 2 }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[2] + symOfs, GDConsts.viewSlotGeom.yRow[2], wallSide, 2)
              else
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[2] + symOfs + 1, GDConsts.viewSlotGeom.yRow[2],
                                     wallSide, 2);
            Inc(side);
            Inc(symOfs, 2);
            wx := wx + GDConsts.dirDx[fR];
            wy := wy + GDConsts.dirDy[fR];
          end;
        end;
        1: begin
          { middle row: from 2-left, scanning right; fronts slot 3 + left sides slot 4 }
          wx := cxPos + GDConsts.dirDx[fL];
          wx := wx + GDConsts.dirDx[fL];
          wy := cyPos + GDConsts.dirDy[fL];
          wy := wy + GDConsts.dirDy[fL];
          side := 0;
          symOfs := -6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[3] + symOfs, GDConsts.viewSlotGeom.yRow[3], wallFront, 3);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[4] + symOfs, GDConsts.viewSlotGeom.yRow[4], wallSide, 4);
            Inc(side);
            Inc(symOfs, 3);
            wx := wx + GDConsts.dirDx[fR];
            wy := wy + GDConsts.dirDy[fR];
          end;
          { middle row: from 2-right, scanning left; fronts slot 3 + right sides slot 5 }
          wx := cxPos + GDConsts.dirDx[fR];
          wx := wx + GDConsts.dirDx[fR];
          wy := cyPos + GDConsts.dirDy[fR];
          wy := wy + GDConsts.dirDy[fR];
          side := 0;
          symOfs := 6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[3] + symOfs, GDConsts.viewSlotGeom.yRow[3], wallFront, 3);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[5] + symOfs, GDConsts.viewSlotGeom.yRow[5], wallSide, 5);
            Inc(side);
            Dec(symOfs, 3);
            wx := wx + GDConsts.dirDx[fL];
            wy := wy + GDConsts.dirDy[fL];
          end;
        end;
        0: begin
          { near row: left cell + center; fronts slot 6 + left slot 7 }
          wx := cxPos + GDConsts.dirDx[fL];
          wy := cyPos + GDConsts.dirDy[fL];
          side := 0;
          symOfs := -7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[6] + symOfs, GDConsts.viewSlotGeom.yRow[6], wallFront, 6);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[7] + symOfs, GDConsts.viewSlotGeom.yRow[7], wallSide, 7);
            Inc(side);
            Inc(symOfs, 7);
            wx := wx + GDConsts.dirDx[fR];
            wy := wy + GDConsts.dirDy[fR];
          end;
          { near row: right cell + center; fronts slot 6 + right slot 8 }
          wx := cxPos + GDConsts.dirDx[fR];
          wy := cyPos + GDConsts.dirDy[fR];
          side := 0;
          symOfs := 7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[6] + symOfs, GDConsts.viewSlotGeom.yRow[6], wallFront, 6);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[8] + symOfs, GDConsts.viewSlotGeom.yRow[8], wallSide, 8);
            Inc(side);
            Dec(symOfs, 7);
            wx := wx + GDConsts.dirDx[fL];
            wy := wy + GDConsts.dirDy[fL];
          end;
        end;
      end;
      cxPos := cxPos + GDConsts.dirDx[fB];
      cyPos := cyPos + GDConsts.dirDy[fB];
      Dec(dist);
    { Byte dist wrapping past 0 }
    until dist = 255;
    View3D.DisplayViewBuf;
  end;
end;

procedure LoadWallSet(fileId, wsSlot: Byte);
var
  sizeRead: Word;
  data: Types.PByteArr;
  offset: Word;
  symOfs: Word;
  row: Byte;
  i: Word;
  col: Integer;
  count: Byte;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if (wsSlot < 1) or (wsSlot > 3) then Exit;
  Str(GDVars.virtualDisk, numStr);
  DaxIo.LoadDax('WALLDEF' + numStr, '.dax', fileId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead div SizeOf(Types.TView3dWallDef) + wsSlot > 4) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load wallset in LoadWallSet.');
    ch := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  symOfs := GDConsts.symSetFirst[wsSlot] - GDConsts.symSetFirst[1];
  offset := 0;
  i := 1;
  repeat
    Move(data^[offset], GDVars.wallGfx^.defs[wsSlot + i - 1], SizeOf(Types.TView3dWallDef));
    Inc(offset, SizeOf(Types.TView3dWallDef));
    Inc(i);
  until offset >= sizeRead;
  FreeMem(data, sizeRead);
  count := i - 1;
  for i := 1 to count do
    if (wsSlot + i - 1) in [1..3] then begin
      GDVars.wallSetCache[wsSlot + i - 1].wallDefId := -1;
      GDVars.wallSetCache[wsSlot + i - 1].symbolSlot := -1;
      for row := 1 to 5 do
        for col := 0 to 155 do begin
          if GDVars.wallGfx^.defs[wsSlot + i - 1][row][col] >= GDConsts.symSetLast[0] then
            Inc(GDVars.wallGfx^.defs[wsSlot + i - 1][row][col], symOfs);
        end;
      if count > 1 then begin
        if fileId = 0 then fileId := 10;
        Sym8x8.Load8x8Set(fileId * 10 + i, wsSlot + i - 1);
      end else
        Sym8x8.Load8x8Set(fileId, wsSlot + i - 1);
    end;
  if fileId = 10 then fileId := 0;
  GDVars.wallSetCache[wsSlot].wallDefId := fileId;
  GDVars.wallSetCache[wsSlot].symbolSlot := wsSlot;
end;

procedure Load3DMap(mapId: Byte);
var
  sizeRead: Word;
  data: Types.PByteArr;
  offset: Word;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  Str(GDVars.virtualDisk, numStr);
  DaxIo.LoadDax('GEO' + numStr, '.dax', mapId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead <> SizeOf(Types.TGeoMap) + 2) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load geo in Load3DMap.');
    ch := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  offset := 2;
  Move(data^[offset], GDVars.map3d^.wallsNorthEast, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.map3d^.wallsSouthWest, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.map3d^.events, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.map3d^.barriers, SizeOf(Types.TGeoPlane));
  FreeMem(data, sizeRead);
  GDVars.zone0^.mapId.value := mapId;
end;

procedure InitView3D;
begin
end;

procedure ReleaseView3D;
begin
end;

begin
end.
