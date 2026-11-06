{ Combat pathfinding, line stepping and target-list construction and sorting. }
{$O+,F+}
unit Pathing;

interface

uses Types, GDConsts, GDVars, CbtMap, C_Dir;

{ Finds the sign of a number.
  @param(v The number.)
  @returns(-1, 0 or 1.) }
function SignOf(v: Integer): Integer;

{ Starts a line walk from its start point toward its end point: sets the step directions, the current point, the
  Bresenham error terms and a zero distance.
  @param(req The line walk; its start and end points are set.) }
procedure PathFind(var req: Types.TPathReq);

{ Advances a line walk one cell toward its end point, adding 3 to its doubled distance for a diagonal step and 2 for a
  straight one, and records the step's direction (8 when it did not move).
  @param(req The line walk.)
  @returns(True when it moved; False once the end point has been reached.) }
function NextPathStep(var req: Types.TPathReq): Boolean;

{ Tells whether a direction leads from one arena cell toward another: the target must lie in the 90-degree cone around
  the cell one step away in that direction. A target on the start cell or on the cell one step away always counts.
  @param(x Arena column of the start cell.)
  @param(y Arena row of the start cell.)
  @param(tx Arena column of the target cell.)
  @param(ty Arena row of the target cell.)
  @param(dir The direction, 0 to 7; 8 or 255 for any direction, which always counts.)
  @returns(True when the direction leads toward the target; False when a cell lies outside the arena. Note: a direction
    from 9 to 254 matches no case and leaves the result unset.) }
function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;

{ Walks a line between two arena cells until terrain or the range stops it. The walk stops once the doubled distance (2
  per straight step, 3 per diagonal) exceeds twice the range plus 1, or, when the arena's distance mode is 0, at a cell
  whose terrain rises above the line of sight from the start cell's clearance.
  @param(x Arena column of the start cell.)
  @param(y Arena row of the start cell.)
  @param(tx Arena column of the target cell; receives the cell where the walk stopped.)
  @param(ty Arena row of the target cell; receives the cell where the walk stopped.)
  @param(dist The range in cells; receives the doubled distance walked.)
  @param(view The arena.)
  @returns(True when the walk reached the target.) }
function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Types.PArena): Boolean;

{ Builds the target list from an icon's position: each combatant with an icon on the arena is a target when a line from
  a tile of the icon reaches a tile of its icon within range, in the filter's direction. Each target keeps its shortest
  doubled distance and the lowest direction toward it, and the list is sorted by distance.
  @param(x Arena column of the icon's upper-left cell.)
  @param(y Arena row of the icon's upper-left cell.)
  @param(range The range in cells.)
  @param(filter The direction a target must lie in, 0 to 7; 8 or 255 for any direction.)
  @param(size The icon size.)
  @param(view The arena.) }
procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte; view: Types.PArena);

implementation

function SignOf(v: Integer): Integer;
begin
  if v < 0 then
    SignOf := -1
  else if v > 0 then
    SignOf := 1
  else
    SignOf := 0;
end;

{ Sorts the target list by doubled distance, nearest first. On a tie, a later target moves ahead only when its direction
  is lower and it does not put a diagonal (odd) direction ahead of a cardinal (even) one. }
procedure SortTargets;
var
  i: Byte;
  j: Byte;
  auxJ: Byte;
  auxI: Byte;
  tmp: Types.TCombatTarget;
begin
  if GDVars.targetCount <= 1 then Exit;
  for i := 1 to GDVars.targetCount - 1 do
    for j := i + 1 to GDVars.targetCount do begin
      auxI := GDVars.targetList[i].dir;
      auxJ := GDVars.targetList[j].dir;
      if (GDVars.targetList[j].dist < GDVars.targetList[i].dist) or
          ((GDVars.targetList[j].dist = GDVars.targetList[i].dist) and (auxJ < auxI) and
           (auxJ mod 2 <= auxI mod 2)) then begin
        tmp := GDVars.targetList[i];
        GDVars.targetList[i] := GDVars.targetList[j];
        GDVars.targetList[j] := tmp;
      end;
    end;
end;

procedure PathFind(var req: Types.TPathReq);
begin
  with req do begin
    dist := 0;
    adx := Abs(ex - sx);
    ady := Abs(ey - sy);
    stepX := Pathing.SignOf(ex - sx);
    stepY := Pathing.SignOf(ey - sy);
    cx := sx;
    cy := sy;
    if adx > ady then begin
      err := ady * 2 - adx;
      incD := (ady - adx) * 2;
      incS := ady * 2;
    end else begin
      err := adx * 2 - ady;
      incD := (adx - ady) * 2;
      incS := adx * 2;
    end;
  end;
end;

function NextPathStep(var req: Types.TPathReq): Boolean;
var
  dx8: ShortInt;
  dy8: ShortInt;
begin
  dx8 := 0;
  dy8 := 0;
  NextPathStep := False;
  with req do begin
    if adx > ady then
    { x-major walk }
    begin
      if cx <> ex then begin
        dx8 := stepX;
        if err >= 0 then begin
          dy8 := stepY;
          Inc(cy, stepY);
          Inc(err, incD);
          Inc(dist, 3);
        end else begin
          Inc(err, incS);
          Inc(dist, 2);
        end;
        Inc(cx, stepX);
        NextPathStep := True;
      end;
    end else
    { y-major walk }
    begin
      if cy <> ey then begin
        dy8 := stepY;
        if err >= 0 then begin
          dx8 := stepX;
          Inc(cx, stepX);
          Inc(err, incD);
          Inc(dist, 3);
        end else begin
          Inc(err, incS);
          Inc(dist, 2);
        end;
        Inc(cy, stepY);
        NextPathStep := True;
      end;
    end;
    step := GDConsts.dirByDelta[dy8 + 1, dx8 + 1];
  end;
end;

function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Types.PArena): Boolean;
var
  walk: Types.TPathReq;
  meter: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  stepped: Boolean;
  maxDist: Word;
begin
  maxDist := dist * 2 + 1;
  walk.sx := x;
  walk.sy := y;
  walk.ex := tx;
  walk.ey := ty;
  Pathing.PathFind(walk);
  meter.sx := 0;
  meter.sy := GDConsts.terrainInfo[view^.cells[y, x]].clearance;
  if walk.adx > walk.ady then
    meter.ex := walk.adx
  else
    meter.ex := walk.ady;
  meter.ey := GDConsts.terrainInfo[view^.cells[y, x]].clearance;
  Pathing.PathFind(meter);
  done := False;
  repeat
    if ((view^.distMode = 0) and
        (GDConsts.terrainInfo[view^.cells[walk.cy, walk.cx]].blocking > meter.cy)) or
          (walk.dist > maxDist) then begin
      tx := walk.cx;
      ty := walk.cy;
      dist := walk.dist;
      WalkLine := False;
      Exit;
    end;
    stepped := Pathing.NextPathStep(meter);
    done := not Pathing.NextPathStep(walk);
  until done;
  dist := walk.dist;
  WalkLine := True;
end;

function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;
var
  nx: ShortInt;
  ny: ShortInt;
begin
  if (x < 0) or (x > 49) or (y < 0) or (y > 24) or (tx < 0) or (tx > 49) or (ty < 0) or (ty > 24) then begin
    IsDirToward := False;
    Exit;
  end;
  if dir = 255 then
    dir := C_Dir.CENTER;
  nx := x + GDConsts.dirDx[dir];
  ny := y + GDConsts.dirDy[dir];
  if ((x = tx) and (y = ty)) or ((nx = tx) and (ny = ty)) then begin
    IsDirToward := True;
    Exit;
  end;
  { Test the 90-degree cone for the requested direction. Note: values 9..254 match no case arm and leave the result
    undefined. }
  case dir of
    C_Dir.NORTH: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_Dir.NORTHEAST: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or
      ((tx >= (nx + ny) - ty) and (ty <= ny));
    C_Dir.EAST: IsDirToward := ((tx >= (nx + ny) - ty) and (ty <= ny)) or ((tx >= (nx + ty) - ny) and (ty >= ny));
    C_Dir.SOUTHEAST: IsDirToward := ((tx >= (nx + ty) - ny) and (ty >= ny)) or
      ((tx >= nx) and (ty >= (tx - nx) + ny));
    C_Dir.SOUTH: IsDirToward := ((tx >= nx) and (ty >= (tx - nx) + ny)) or ((tx <= nx) and (ty >= (nx - tx) + ny));
    C_Dir.SOUTHWEST: IsDirToward := ((tx <= nx) and (ty >= (nx - tx) + ny)) or
      ((tx <= (nx + ny) - ty) and (ty >= ny));
    C_Dir.WEST: IsDirToward := ((tx <= (nx + ny) - ty) and (ty >= ny)) or ((tx <= (nx + ty) - ny) and (ty <= ny));
    C_Dir.NORTHWEST: IsDirToward := ((tx <= (nx + ty) - ny) and (ty <= ny)) or
      ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_Dir.CENTER: IsDirToward := True;
  end;
end;

procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte; view: Types.PArena);
var
  i: Byte;
  bestDir: Byte;
  k: Byte;
  j: Byte;
  bestK: Byte;
  bestJ: Byte;
  found: Boolean;
  tx: ShortInt;
  ty: ShortInt;
  dx8: ShortInt;
  dy8: ShortInt;
  myX: array[0..3] of ShortInt;
  myY: array[0..3] of ShortInt;
  tgX: array[0..3] of ShortInt;
  tgY: array[0..3] of ShortInt;
  dist: Word;
  bestDist: Word;
begin
  for k := 0 to 3 do
    if CbtMap.GetIconTileDelta(size, k, dx8, dy8) then begin
      myX[k] := x + dx8;
      myY[k] := y + dy8;
    end else
      myX[k] := -1;
  GDVars.targetCount := 0;
  for i := 1 to GDVars.arenaCount do
    if GDVars.arenaLoc[i].size > 0 then begin
      found := False;
      bestDist := 255;
      for j := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaLoc[i].size, j, dx8, dy8) then begin
          tgX[j] := GDVars.arenaLoc[i].x + dx8;
          tgY[j] := GDVars.arenaLoc[i].y + dy8;
        end else
          tgX[j] := -1;
      for j := 0 to 3 do
        if tgX[j] >= 0 then
          for k := 0 to 3 do
            if myX[k] >= 0 then
              if Pathing.IsDirToward(myX[k], myY[k], tgX[j], tgY[j], filter) then begin
                tx := tgX[j];
                ty := tgY[j];
                dist := range;
                if Pathing.WalkLine(myX[k], myY[k], tx, ty, dist, view) then begin
                  found := True;
                  if dist < bestDist then begin
                    bestDist := dist;
                    bestK := k;
                    bestJ := j;
                  end;
                end;
              end;
      if found then begin
        Inc(GDVars.targetCount);
        GDVars.targetList[GDVars.targetCount].idx := i;
        GDVars.targetList[GDVars.targetCount].dist := bestDist;
        bestDir := 0;
        if filter < C_Dir.CENTER then
          bestDir := filter
        else
          while not Pathing.IsDirToward(myX[bestK], myY[bestK], tgX[bestJ], tgY[bestJ], bestDir) do
            Inc(bestDir);
        GDVars.targetList[GDVars.targetCount].dir := bestDir;
      end;
    end;
  Pathing.SortTargets;
end;

begin
end.
