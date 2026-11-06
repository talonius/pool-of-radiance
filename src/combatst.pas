{ Build dungeon and wilderness combat arenas, load terrain tiles and place creatures. }
{$O+,F+}
unit CombatSt;

interface

uses Types, Crt, C_Area, C_Npc, C_Terr, C_Cond, GDConsts, GDVars, CbtActs, CharGen, FxEngine, Portrait, View3D,
  MapTiles, Blit, GameIo, C_Ifc, C_Gbvm, C_Dir, CharHlp, CbtMap, MenuCore, TextRend;

{ Starts a battle: releases the animation and portrait pictures, clears the combat state, builds the arena, initializes
  and places the creatures and allocates the moving-icon frames. Then it centers the view on the first creature, draws
  the combat interface, fires the start-of-combat effects and works out the hostile hit-point percentage. }
procedure CombatStart;

implementation

{ Rolls 1d100 on each grass cell of the arena (terrain tile 22): 98 gives terrain 26, 99 gives 27, and 100 (unless under
  ECL script 10) a further 1 percent chance of 28 (1d10 of 1 to 6) or 29 (7 to 10). }
procedure SprinkleRareFeatures;
var
  col: ShortInt;
  row: ShortInt;
  roll: Byte;
begin
  for col := 0 to 49 do
    for row := 0 to 24 do
      if GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row, col]].tileId = 22 then begin
        roll := FxEngine.RollDice(1, 100);
        case roll of
          1..97: ;
          98: GDVars.arenaPtr^.cells[row, col] := 26;
          99: GDVars.arenaPtr^.cells[row, col] := 27;
          100: if GDVars.eclScriptId <> 10 then
                 if FxEngine.RollDice(1, 100) = 1 then
                   case FxEngine.RollDice(1, 10) of
                     1..6: GDVars.arenaPtr^.cells[row, col] := 28;
                     7..10: GDVars.arenaPtr^.cells[row, col] := 29;
                   end;
        end;
      end;
end;

{ Finds the wall between a dungeon cell and its neighbor in one direction, probing the edge from both sides and ORing
  the two: 0 open, 1 solid, 3 a door (a wall with a passable barrier); solid on one side and a door on the other gives
  3.
  @param(x Map column of the cell.)
  @param(y Map row of the cell.)
  @param(dir The direction, a cardinal one.)
  @returns(The wall kind.) }
function WallBetween(x, y: ShortInt; dir: Byte): Byte;
var
  nearKind: Byte;
  farKind: Byte;
  opp: Byte;

  { Classifies one side of an edge: 1 solid, 0 open, 3 a door; off the map, east and west on the party's row are open. }
  function GetWallKind(px, py: ShortInt; pdir: Byte): Byte;
  begin
    if (px >= 0) and (px <= 15) and (py >= 0) and (py <= 15) then begin
      if View3D.GetBarrierType(px, py, pdir) = 0 then
        GetWallKind := 1
      else if View3D.GetWallType(px, py, pdir) = 0 then
        GetWallKind := 0
      else
        GetWallKind := 3;
    end else begin
      if (py = GDVars.partyPos.mapY) and ((pdir = C_Dir.EAST) or (pdir = C_Dir.WEST)) then
        GetWallKind := 0
      else
        GetWallKind := 1;
    end;
  end;

begin
  opp := (dir + 4) mod 8;
  nearKind := GetWallKind(x, y, dir);
  farKind := GetWallKind(x + GDConsts.dirDx[dir], y + GDConsts.dirDy[dir], opp);
  WallBetween := nearKind or farKind;
end;

{ Builds a dungeon arena from the 13x5 cells around the party: each cell becomes a skewed 6x5 block of terrain with its
  floor, walls and corners, and rare features are added. }
procedure BuildDungeonArena;
var
  dx: ShortInt;
  dy: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  cellEvent: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cellFeature: Byte;
  wallN: Byte;
  wallW: Byte;
  wallE: Byte;

  { Plot terrain t+1 at spot (i, j) of the current cell's skewed block, clipped to the arena }
  procedure PlotCell(i, j, t: Byte);
  var
    x: ShortInt;
    y: ShortInt;
  begin
    x := dx * 6 + dy * 5 + 21 + i;
    y := dy * 5 + 10 + j;
    if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then
      GDVars.arenaPtr^.cells[y, x] := t + 1;
  end;

  { The cell's floor (spots 0..5, rows 2..4) and its WEST wall }
  procedure DrawFloorWestWall;
  var
    c: Byte;
    r: Byte;
  begin
    for r := 2 to 4 do
      for c := 0 to 5 do
        PlotCell(c, r, 22);
    if wallW = 1 then begin
      for r := 2 to 4 do begin
        PlotCell(r - 1, r, 4);
        PlotCell(r, r, 3);
        PlotCell(r + 1, r, 13);
      end;
    end else if wallW = 3 then begin
      PlotCell(1, 2, 8);
      PlotCell(5, 4, 0);
    end;
  end;

  { The NORTH wall band (spots (3..4, 0..1)): wall terrain when solid, floor otherwise }
  procedure DrawNorthWall;
  var
    { Unused in this version; see the other implementations of this routine. }
    column: Integer;
  begin
    if wallN = 1 then begin
      PlotCell(3, 0, 5);
      PlotCell(4, 0, 5);
      PlotCell(3, 1, 10);
      PlotCell(4, 1, 10);
    end else begin
      PlotCell(3, 0, 22);
      PlotCell(4, 0, 22);
      PlotCell(3, 1, 22);
      PlotCell(4, 1, 22);
    end;
  end;

  { Fills the cell's northwest corner, open when both edges beyond it are open. }
  procedure FillCornerNorthWest;
  var
    k: Byte;
    topLeft: Byte;
    bottomLeft: Byte;
    topRight: Byte;
    bottomRight: Byte;
    open: Byte;
  begin
    if (CombatSt.WallBetween(cellX, cellY - 1, C_Dir.WEST) = 0) and
        (CombatSt.WallBetween(cellX - 1, cellY, C_Dir.NORTH) = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case wallN of
             0: case wallW of
                  0: topLeft := 22;
                  3: topLeft := 13;
                  1: if open <> 0 then topLeft := 0 else topLeft := 13;
                end;
             3, 1: if wallW = 0 then begin
                     if open <> 0 then topLeft := 15 else topLeft := 5;
                   end else begin
                     if open <> 0 then topLeft := 18 else topLeft := 2;
                   end;
           end;
        2: case wallN of
             0: topRight := 22;
             3: topRight := 17;
             1: topRight := 5;
           end;
        3: case wallW of
             0: if wallN = 0 then
                  bottomLeft := 22
                else if open <> 0 then
                  bottomLeft := 16
                else
                  bottomLeft := 10;
             3: if open <> 0 then bottomLeft := 20 else bottomLeft := 7;
             1: if open <> 0 then bottomLeft := 1 else bottomLeft := 3;
           end;
        4: case wallW of
             0, 3: case wallN of
                     0: bottomRight := 22;
                     3: bottomRight := 23;
                     1: bottomRight := 10;
                   end;
             1: case wallN of
                  0: bottomRight := 13;
                  3: bottomRight := 21;
                  1: bottomRight := 6;
                end;
           end;
      end;
    PlotCell(1, 0, topLeft);
    PlotCell(2, 0, topRight);
    PlotCell(1, 1, bottomLeft);
    PlotCell(2, 1, bottomRight);
  end;

  { Fills the cell's northeast corner, two spots wide, the second spilling into the next cell's block. }
  procedure FillCornerNorthEast;
  var
    k: Byte;
    topLeft: Byte;
    bottomLeft: Byte;
    topRight: Byte;
    bottomRight: Byte;
    open: Byte;
    kN: Byte;
    kE: Byte;
  begin
    kN := CombatSt.WallBetween(cellX, cellY - 1, C_Dir.EAST);
    kE := CombatSt.WallBetween(cellX + 1, cellY, C_Dir.NORTH);
    if (kN = 0) and (kE = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case wallN of
             0: if kN = 1 then topLeft := 4 else topLeft := 22;
             3: topLeft := 15;
             1: topLeft := 5;
           end;
        2: if wallN = 0 then begin
             case kN of
               0: topRight := 22;
               3: if (wallE = 0) and (kE <> 0) then
                    topRight := 24
                  else
                    topRight := 1;
               1: if (wallE = 0) and (kE <> 0) then
                    topRight := 11
                  else
                    topRight := 3;
             end;
           end else begin
             if wallE <> 0 then
               topRight := 9
             else if kE <> 0 then
               topRight := 5
             else if open <> 0 then
               topRight := 17
             else
               topRight := 19;
           end;
        3: case wallN of
             0: bottomLeft := 22;
             3: bottomLeft := 16;
             1: bottomLeft := 10;
           end;
        4: if wallN = 0 then begin
             if kN = 0 then
               bottomRight := 22
             else if wallE <> 0 then
               bottomRight := 4
             else if kE = 0 then
               bottomRight := 8
             else
               bottomRight := 12;
           end else begin
             if wallE <> 0 then
               bottomRight := 14
             else if kE = 0 then
               bottomRight := 23
             else
               bottomRight := 10;
           end;
      end;
    PlotCell(5, 0, topLeft);
    PlotCell(6, 0, topRight);
    PlotCell(5, 1, bottomLeft);
    PlotCell(6, 1, bottomRight);
  end;

begin
  for dy := -2 to 2 do
    for dx := -6 to 6 do begin
      cellX := GDVars.partyPos.mapX + dx;
      cellY := GDVars.partyPos.mapY + dy;
      wallW := CombatSt.WallBetween(cellX, cellY, C_Dir.WEST);
      wallN := CombatSt.WallBetween(cellX, cellY, C_Dir.NORTH);
      wallE := CombatSt.WallBetween(cellX, cellY, C_Dir.EAST);
      DrawFloorWestWall;
      DrawNorthWall;
      FillCornerNorthWest;
      FillCornerNorthEast;
    end;
  CombatSt.SprinkleRareFeatures;
end;

{ Classes the wilderness terrain under the party for the arena generators, as a mask of feature bits. Once Yarash's
  mission is done (255), bit 7 turns into bit 0. Note: some terrain values appear in two arms, where the first wins, and
  an unmatched value leaves the class unset.
  @returns(The terrain class.) }
function TerrainClassOf: Byte;
var
  cls: Byte;
begin
  { Note: some labels repeat; the first matching arm wins. }
  case GDVars.terrainChar of
    1..2, 40..41, 79..86, 91..92, 43, 241:
      cls := $01;
    168..177:
      cls := $21;
    185, 188..192:
      cls := $11;
    3..4, 6..7, 8..9, 19..21, 23..25:
      cls := $03;
    3..4, 7, 10..18, 22, 26..36, 201..208:
      cls := $02;
    209..213:
      cls := $12;
    37, 57, 64, 154..158, 164..165, 180, 243, 239..240, 250, 252:
      cls := $04;
    39..44, 153, 159:
      cls := $05;
    45..46, 51..56, 67..77, 93..97:
      cls := $44;
    181..184, 186, 193..200:
      cls := $14;
    47..50, 98..101, 242:
      cls := $40;
    38:
      cls := $41;
    178..179:
      cls := $60;
    58..60, 65..66:
      cls := $48;
    61..63, 121..124, 135..137, 139, 141, 144..147, 149, 151..152,
    160..162, 166..167, 214..216, 238:
      cls := $08;
    87..90, 163, 224:
      cls := $88;
    125, 124, 138, 140, 142, 143, 148, 150:
      cls := $09;
    126..133, 229..231:
      cls := $28;
    217..223:
      cls := $18;
    78, 245, 232..233:
      cls := $20;
    109, 244..246:
      cls := $80;
    110..113, 115..120:
      cls := $81;
    102..108, 114:
      cls := $90;
    225..228, 234..237:
      cls := $A0;
  end;
  if cls and $80 <> 0 then
    if GDVars.zone0^.yarashMissionDone = 255 then begin
      Dec(cls, $80);
      cls := cls or 1;
    end;
  TerrainClassOf := cls;
end;

{ Lays a diagonal river across the arena (terrain 50 and 51, one column further each row) with two-row fords (52 and
  53), started on a 1-in-20 roll; a river without one gets a ford at a random row. The chance of a river is 35 percent
  for class bit 5 and 75 percent for bit 4, and none otherwise. }
procedure PlaceRiver;
var
  thresh: Byte;
  fordCnt: Byte;
  startCol: ShortInt;
  col: ShortInt;
  row: ShortInt;

  { Place a ford pair at adjacent cells and increment fordCnt. }
  procedure PlotFord(r, c: ShortInt);
  begin
    GDVars.arenaPtr^.cells[r, c] := 52;
    GDVars.arenaPtr^.cells[r, c + 1] := 53;
    Inc(fordCnt);
  end;

begin
  thresh := 0;
  fordCnt := 0;
  if CombatSt.TerrainClassOf and $20 <> 0 then thresh := 35;
  if CombatSt.TerrainClassOf and $10 <> 0 then thresh := 75;
  if FxEngine.RollDice(1, 100) > thresh then Exit;
  col := 34 - FxEngine.RollDice(5, 4);
  while (col + 2) mod 7 > 0 do
    Dec(col);
  startCol := col;
  for row := 0 to 24 do begin
    if col <= 49 then begin
      GDVars.arenaPtr^.cells[row, col] := 50;
      GDVars.arenaPtr^.cells[row, col + 1] := 51;
      if (FxEngine.RollDice(1, 20) = 1) or Odd(fordCnt) then
        PlotFord(row, col);
      Inc(col);
    end;
  end;
  if fordCnt = 0 then begin
    row := 12 - FxEngine.RollDice(1, 9) + 4;
    col := startCol + row;
    PlotFord(row, col);
    PlotFord(row + 1, col + 1);
  end;
end;

{ Plants trees on pairs of grass cells one above the other, at a density set by the class bits (2, 4, $40, 8 and $80
  give 1, 3, 4, 7 and 0 percent, the later bits winning). A tree's height is 1d2+4 on a 1d10 roll of 9 or 10 and
  otherwise half the roll rounded up, or 1d3+3 for class $40; a tree below height 5 also takes the cell above. }
procedure PlaceTrees;
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
  dens: Byte;
  h: Byte;
  col: ShortInt;
  row: ShortInt;
begin
  dens := 1;
  if CombatSt.TerrainClassOf and $02 <> 0 then dens := 1;
  if CombatSt.TerrainClassOf and $04 <> 0 then dens := 3;
  if CombatSt.TerrainClassOf and $40 <> 0 then dens := 4;
  if CombatSt.TerrainClassOf and $08 <> 0 then dens := 7;
  if CombatSt.TerrainClassOf and $80 <> 0 then dens := 0;
  for col := 0 to 49 do
    for row := 1 to 24 do
      if (GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row, col]].tileId = 22) and
          (GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row - 1, col]].tileId = 22) and
          (FxEngine.RollDice(1, 100) <= dens) then begin
        h := FxEngine.RollDice(1, 10);
        if h > 8 then
          h := FxEngine.RollDice(1, 2) + 4
        else
          h := (h + 1) div 2;
        if CombatSt.TerrainClassOf and $40 <> 0 then
          h := FxEngine.RollDice(1, 3) + 3;
        GDVars.arenaPtr^.cells[row, col] := h + 31 + 4;
        if h < 5 then
          GDVars.arenaPtr^.cells[row - 1, col] := h + 31;
      end;
end;

{ Rolls 1d255 on each grass cell against five stacked bands weighted by the terrain class: a swamp pool (or, on a 4, a
  two-cell pool when the cell above is grass), rocks, bushes, mounds and scrub (its last kind only for class $40). }
procedure ScatterFeatures;
var
  tSwamp: Byte;
  tA: Byte;
  tB: Byte;
  tC: Byte;
  tD: Byte;
  r: Byte;
  col: ShortInt;
  row: ShortInt;
begin
  tSwamp := 0;
  tA := 6;
  tB := 15;
  tC := 40;
  tD := 0;
  if CombatSt.TerrainClassOf and $02 <> 0 then begin
    tB := 45;
    tC := 10;
  end;
  if CombatSt.TerrainClassOf and $04 <> 0 then
    tB := 25;
  if CombatSt.TerrainClassOf and $40 <> 0 then begin
    tC := 5;
    tD := 30;
  end;
  if CombatSt.TerrainClassOf and $80 <> 0 then begin
    tSwamp := 15;
    tC := 25;
    tB := 10;
  end;
  for col := 0 to 49 do
    for row := 0 to 24 do
      if GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row, col]].tileId = 22 then begin
        r := FxEngine.RollDice(1, 255);
        if r <= tSwamp then begin
          r := FxEngine.RollDice(1, 4);
          if (r = 4) and (row > 0) and
              (GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row - 1, col]].tileId = 22) then begin
            GDVars.arenaPtr^.cells[row - 1, col] := 65;
            GDVars.arenaPtr^.cells[row, col] := 64;
          end;
          if r < 4 then
            GDVars.arenaPtr^.cells[row, col] := r + 31 + 29;
        end else if r <= tA + tSwamp then
          GDVars.arenaPtr^.cells[row, col] := FxEngine.RollDice(1, 3) + 31 + 23
        else if r <= tB + tSwamp + tA then
          GDVars.arenaPtr^.cells[row, col] := FxEngine.RollDice(1, 4) + 31 + 10
        else if r <= tD + tB + tSwamp + tA then begin
          r := (FxEngine.RollDice(1, 10) - 1) div 3 + 1;
          GDVars.arenaPtr^.cells[row, col] := r + 31 + 25;
        end else if r <= tA + (tC + tD + tB + tSwamp) then begin
          r := FxEngine.RollDice(1, 4);
          if (r = 4) and (CombatSt.TerrainClassOf and $40 = 0) then
            r := FxEngine.RollDice(1, 3);
          GDVars.arenaPtr^.cells[row, col] := r + 31 + 14;
        end;
      end;
end;

{ Builds a wilderness arena: fills it with terrain 23, reads the wilderness terrain under the party (the central and
  eastern maps 13 and 26 columns over), and runs the river, tree, feature and rare-feature generators. }
procedure BuildWildernessArena;
var
  mapX: ShortInt;
  mapY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  mapIndex: Integer;
begin
  FillChar(GDVars.arenaPtr^.cells, SizeOf(GDVars.arenaPtr^.cells), 23);
  mapX := GDVars.zone0^.partyX.lo;
  mapY := GDVars.zone0^.partyY.lo;
  if GDVars.locType = C_Area.LOC_WILD_CENTRAL then Inc(mapX, 13);
  if GDVars.locType = C_Area.LOC_WILD_EAST then Inc(mapX, 26);
  GDVars.terrainChar := GDConsts.wildMap[mapY, mapX];
  CombatSt.PlaceRiver;
  CombatSt.PlaceTrees;
  CombatSt.ScatterFeatures;
  CombatSt.SprinkleRareFeatures;
end;

{ Loads the dungeon or wilderness combat tiles and the random-feature tiles, allocates the arena and builds it. }
procedure LoadCombatTileSet;
begin
  if GDVars.locType = C_Area.LOC_3D_MAP then
    MapTiles.Load24x24Set('DungCom', 0, 24)
  else
    MapTiles.Load24x24Set('WildCom', 0, 33);
  MapTiles.Load24x24Set('RandCom', 34, 5);
  GetMem(GDVars.arenaPtr, SizeOf(Types.TArena));
  GDVars.arenaPtr^.cursorOn := False;
  GDVars.arenaPtr^.cursorSize := 1;
  GDVars.arenaPtr^.distMode := 0;
  if GDVars.locType = C_Area.LOC_3D_MAP then
    CombatSt.BuildDungeonArena
  else
    CombatSt.BuildWildernessArena;
end;

{ Recomputes each creature's stats and gives it a fresh combat record; the creatures past the party size are not party
  members (notPcNpc 1). Creatures that are not hostile face the party's way, hostiles the opposite way. A friendly
  creature outside the party whose morale is 0 or above 102 takes the morale threshold and becomes an NPC. }
procedure InitCreatureCombatData;
var
  p: Types.PCharRecord;
  count: Byte;
  m: Byte;
begin
  p := GDVars.creatureList;
  count := 0;
  while p <> nil do begin
    CharHlp.RecalcStats(p);
    Inc(count);
    GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
    FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
    if count > GDVars.zone1^[C_Gbvm.PARTY_SIZE] then
      p^.combatAddr^.notPcNpc := 1;
    p^.combatAddr^.direction := GDConsts.quadDir[GDVars.partyPos.facing div 2];
    if p^.hostile = 1 then
      p^.combatAddr^.direction := (p^.combatAddr^.direction + 4) mod 8;
    m := p^.npc and C_Npc.MORALE_MASK;
    if (p^.hostile = 0) and (p^.combatAddr^.notPcNpc = 1) and ((m = 0) or (m > 102)) then
      p^.npc := GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD] + C_Npc.NON_PLAYER;
    p := p^.nextCharAddr;
  end;
end;

{ Tells whether a placement square lies off the 11x6 grid on both axes.
  @param(qx The square's column.)
  @param(qy The square's row.)
  @returns(True only when both coordinates are off the grid.) }
function QuadFullyOff(qx, qy: ShortInt): Boolean;
begin
  if ((qx >= 0) and (qx < 11)) or ((qy >= 0) and (qy < 6)) then
    QuadFullyOff := False
  else
    QuadFullyOff := True;
end;

{ Tries to put a creature on a placement square of its team's grid for one ring. The square must be on the grid and
  free; its arena cell, from the same skewed mapping as the dungeon builder, is stored before the probe, and the cell
  must hold no creature and passable terrain.
  @param(slot The creature's combat slot.)
  @param(qx The square's column.)
  @param(qy The square's row.)
  @param(bqx The grid's base column.)
  @param(bqy The grid's base row.)
  @param(ring The placement ring, 0 to 3.)
  @returns(1 when the creature was placed, which takes the square; 0 otherwise.) }
function TryPlaceAt(slot: Byte; qx, qy, bqx, bqy: ShortInt; ring: Byte): Byte;
var
  crIdx: Byte;
  terrIdx: Byte;
begin
  if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) or (GDVars.quadFree[GDVars.team, ring, qy, qx] = 0) then
    TryPlaceAt := 0
  else begin
    { Store coordinates before probing }
    GDVars.arenaLoc[slot].x := qx + bqx * 6 + bqy * 5 + 22;
    GDVars.arenaLoc[slot].y := qy + bqy * 5 + 10;
    CbtMap.ProbeDirection(GDVars.creatureArr[slot], C_Dir.CENTER, crIdx, terrIdx);
    if (crIdx = 0) and (terrIdx > 0) and (GDConsts.terrainInfo[terrIdx].cost < 255) then begin
      TryPlaceAt := 1;
      GDVars.quadFree[GDVars.team, ring, qy, qx] := 0;
    end else
      TryPlaceAt := 0;
  end;
end;

{ Searches the team's placement grid for a square for a creature, in zigzag legs from the ring's start square. A leg
  ends at a square partly off the grid or after a set number of tries, and the next leg starts a step further back. A
  square fully off the grid moves on to the next ring whose direction is not walled off (always outdoors), up to ring 3.
  @param(slot The creature's combat slot.)
  @returns(True when the creature was placed; False when no ring is left.) }
function FindPlacement(slot: Byte): Boolean;
var
  placed: Byte;
  firstPass: Byte;
  giveUp: Byte;
  offGrid: Byte;
  open: Byte;
  state: Byte;
  dir: Byte;
  quad: Byte;
  k: Byte;
  stepX: ShortInt;
  stepY: ShortInt;
  wallX: ShortInt;
  wallY: ShortInt;
  legShift: Byte;
  legLen: Byte;
  baseQuadX: ShortInt;
  baseQuadY: ShortInt;
  tries: Byte;
  ring: Byte;
  legX: ShortInt;
  legY: ShortInt;
  qx: ShortInt;
  qy: ShortInt;
begin
  firstPass := 1;
  giveUp := 0;
  state := 1;
  legShift := 0;
  ring := 0;
  baseQuadX := GDVars.placeX[GDVars.team];
  baseQuadY := GDVars.placeY[GDVars.team];
  repeat
    quad := GDConsts.ringStart[GDVars.teamDir[GDVars.team], ring] div 2;
    case state of
      1: begin
           stepX := GDConsts.dirDx[GDConsts.quadDir[(quad + 2) mod 4]];
           stepY := GDConsts.dirDy[GDConsts.quadDir[(quad + 2) mod 4]];
           legX := GDConsts.startQuadX[ring > 0, quad] + stepX * legShift;
           legY := GDConsts.startQuadY[ring > 0, quad] + stepY * legShift;
           qx := legX;
           qy := legY;
           legLen := 1;
           state := 2;
           tries := 1;
         end;
      2: begin
           stepX := GDConsts.dirDx[GDConsts.quadDir[(quad + 1) mod 4]];
           stepY := GDConsts.dirDy[GDConsts.quadDir[(quad + 1) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 3;
           Inc(tries);
         end;
      3: begin
           stepX := GDConsts.dirDx[GDConsts.quadDir[(quad + 3) mod 4]];
           stepY := GDConsts.dirDy[GDConsts.quadDir[(quad + 3) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 2;
           Inc(legLen);
           Inc(tries);
         end;
    end;
    if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) then
      offGrid := 1
    else
      offGrid := 0;
    if state > 1 then begin
      { leg exhausted? (a partially-off quad, or out of tries) }
      if ((offGrid <> 0) and (not CombatSt.QuadFullyOff(qx,
                                                        qy))) or ((firstPass <> 0) and
                                                                  (tries >= GDVars.teamRows[GDVars.team])) or
          ((firstPass = 0) and (tries > 11)) then begin
        Inc(legShift);
        if (GDVars.team = 0) and Odd(GDVars.teamDir[0]) and (ring = 0) and (legShift = 1) then begin
          wallX := GDVars.placeX[GDVars.team] + GDVars.partyPos.mapX;
          wallY := GDVars.placeY[GDVars.team] + GDVars.partyPos.mapY;
          open := 0;
          for k := 1 to 3 do begin
            dir := GDConsts.ringDirTbl[GDVars.teamDir[GDVars.team], k];
            if (GDVars.locType > C_Area.LOC_3D_MAP) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then
              open := 1;
          end;
          if open <> 0 then
            Inc(legShift);
        end;
        state := 1;
        firstPass := 0;
      end;
    end;
    { Outside the state > 1 guard: advance the search ring when the quad lies fully outside the grid. }
    if (offGrid <> 0) and CombatSt.QuadFullyOff(qx, qy) then begin
        placed := 0;
        state := 0;
        while (ring < 3) and (state <> 1) do begin
          Inc(ring);
          wallX := GDVars.placeX[GDVars.team] + GDVars.partyPos.mapX;
          wallY := GDVars.placeY[GDVars.team] + GDVars.partyPos.mapY;
          dir := GDConsts.ringDirTbl[GDVars.teamDir[GDVars.team], ring];
          if (GDVars.locType > C_Area.LOC_3D_MAP) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then begin
            baseQuadX := GDVars.placeX[GDVars.team] + GDConsts.dirDx[dir];
            baseQuadY := GDVars.placeY[GDVars.team] + GDConsts.dirDy[dir];
            legShift := 0;
            state := 1;
          end;
        end;
        if state <> 1 then
          giveUp := 1;
    end;
    if offGrid = 0 then
      placed := CombatSt.TryPlaceAt(slot, qx, qy, baseQuadX, baseQuadY, ring);
  until (placed <> 0) or (giveUp <> 0);
  if giveUp <> 0 then
    FindPlacement := False
  else
    FindPlacement := True;
end;

{ Places the party (team 0, at the origin) and the opposing team, which stands the monster distance away along the
  party's facing and faces back. Each team's placement grids are seeded from the row bands, and each creature is
  registered and placed. Outside duels a disabled party member becomes a body; a creature outside the party that cannot
  be placed is removed, and a party member keeps its slot with no icon. Note: the clearing loop runs past the 72 arena
  slots, zeroing every fourth byte of the arena arrays after them, which are then rebuilt. }
procedure PlaceAllCreatures;
var
  x: ShortInt;
  y: ShortInt;
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  slot: Byte;
  g: Byte;
  d: Byte;
  placedCnt: Byte;
  removedCnt: Byte;
begin
  CharHlp.CountTeams;
  removedCnt := 0;
  placedCnt := 0;
  { Note: slots 73..255 run past arenaLoc's 72 entries (range checks are off), zeroing every fourth byte of the arena
    arrays after it; BuildArenaArrays then rebuilds those. }
  for slot := 1 to 255 do
    GDVars.arenaLoc[slot].size := 0;
  CbtMap.BuildArenaArrays;
  GDVars.placeX[0] := 0;
  GDVars.placeY[0] := 0;
  GDVars.teamDir[0] := GDVars.partyPos.facing div 2;
  GDVars.placeX[1] := GDConsts.dirDx[GDVars.partyPos.facing] * GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] +
    GDVars.placeX[0];
  GDVars.placeY[1] := GDConsts.dirDy[GDVars.partyPos.facing] * GDVars.zone1^[C_Gbvm.MONSTER_DISTANCE] +
    GDVars.placeY[0];
  GDVars.teamDir[1] := (GDVars.partyPos.facing + 4) mod 8 div 2;
  for GDVars.team := 0 to 1 do
    GDVars.teamRows[GDVars.team] := (GDVars.teamCount[GDVars.team] + 1) div 2;
  for GDVars.team := 0 to 1 do
    for g := 0 to 3 do begin
      if g = 1 then
        d := 4
      else
        d := GDVars.teamDir[GDVars.team];
      { y = quad row qy here }
      for y := 0 to 5 do
        { x = quad column qx here }
        for x := 0 to 10 do
          if (GDConsts.rowBand[d, y].lo > x) or (GDConsts.rowBand[d, y].hi < x) then
            GDVars.quadFree[GDVars.team, g, y, x] := 0
          else
            GDVars.quadFree[GDVars.team, g, y, x] := 1;
    end;
  slot := 1;
  GDVars.arenaCount := 1;
  prev := GDVars.creatureList;
  p := GDVars.creatureList;
  while p <> nil do begin
    GameIo.PollGameKeys;
    GDVars.creatureArr[slot] := p;
    GDVars.team := p^.hostile;
    GDVars.arenaLoc[slot].slotIndex := slot;
    GDVars.arenaLoc[slot].size := p^.iconDimensions and 7;
    if CombatSt.FindPlacement(slot) then begin
      prev := p;
      if p^.enabled = 0 then begin
        GDVars.arenaLoc[slot].size := 0;
        if (not GDVars.duelFlag) and (p^.combatAddr^.notPcNpc = 0) then begin
          x := GDVars.arenaLoc[slot].x;
          y := GDVars.arenaLoc[slot].y;
          Inc(GDVars.downedCount);
          GDVars.downed[GDVars.downedCount].terrain := GDVars.arenaPtr^.cells[y, x];
          GDVars.arenaPtr^.cells[y, x] := C_Terr.TERRAIN_CORPSE;
          GDVars.downed[GDVars.downedCount].cr := p;
          GDVars.downed[GDVars.downedCount].x := x;
          GDVars.downed[GDVars.downedCount].y := y;
        end;
      end;
      CbtMap.BuildArenaArrays;
      Inc(slot);
      Inc(GDVars.arenaCount);
      Inc(placedCnt);
    end else begin
      GDVars.arenaLoc[slot].size := 0;
      if p^.combatAddr^.notPcNpc = 1 then begin
        Inc(removedCnt);
        GDVars.creatureArr[slot] := nil;
        GDVars.curChar := p;
        CharGen.RemoveCreature(True, False);
        p := prev;
      end else begin
        prev := p;
        Inc(slot);
        Inc(GDVars.arenaCount);
      end;
    end;
    p := p^.nextCharAddr;
  end;
  prev^.nextCharAddr := nil;
end;

procedure CombatStart;
var
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[1..10] of Byte;
  p: Types.PCharRecord;
begin
  Portrait.FreeAnimation(GDVars.animData);
  Blit.FreePic(GDVars.portraitCache[1].pic);
  Blit.FreePic(GDVars.portraitCache[2].pic);
  GDVars.portraitCache[1].pictureId := 255;
  GDVars.portraitCache[2].pictureId := 255;
  MenuCore.ClearBottomLine;
  TextRend.PauseOnly;
  TextRend.DisplayString(0, 24, LightGreen, 'A battle begins...');
  GDVars.quickMagic := False;
  GDVars.roundCounter := 0;
  GDVars.attackRoll := 0;
  GDVars.downedCount := 0;
  GDVars.stinkHead := nil;
  GDVars.lastMissileItem := nil;
  FillChar(GDVars.downed, SizeOf(GDVars.downed), 0);
  GDVars.zone1^[C_Gbvm.ATTACKED_ALLIES] := 0;
  if GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD] > 100 then
    GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD] := 100;
  CombatSt.LoadCombatTileSet;
  GameIo.PollGameKeys;
  CombatSt.InitCreatureCombatData;
  GameIo.PollGameKeys;
  CombatSt.PlaceAllCreatures;
  GameIo.PollGameKeys;
  Blit.AllocPic(24, 3, 4, 1, GDVars.moveIconSheet);
  GDVars.arenaPtr^.ox := CbtMap.CombatCellX(GDVars.creatureList) - 3;
  GDVars.arenaPtr^.oy := CbtMap.CombatCellY(GDVars.creatureList) - 3;
  CharHlp.DisplayCombatInterface;
  p := GDVars.creatureList;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_Cond.COMBAT_START, p);
    p := p^.nextCharAddr;
  end;
  CbtActs.UpdateHostileHpPercent;
  GDVars.ifcState := C_Ifc.IN_COMBAT;
end;

begin
end.
