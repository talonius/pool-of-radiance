{ Update dungeon and wilderness views from the current map state. }
{$O+,F+}
unit MapView;

interface

uses Crt, C_Area, GDConsts, GDVars, Wilds, View3D, MapTiles, Blit;

{ Draws the current map view: the 3D view in a 3D area, or in any area while the zone's 3D-view flag is set, and the
  wilderness map in a wilderness area. For the 3D view it takes the sky or ceiling color from the zone (its alternate
  color when the event value of the party's cell is above $7F), recomputes the horizon band and floor colors from their
  selectors while picRegionW is set, and turns the automap off when the zone forbids it. For the wilderness it centers
  the 5x5 view on the party, kept inside the map, and draws the party's icon. }
procedure DisplayMapView;

{ Draws the party's animated icon on the wilderness map, advances its six-step animation and flushes the view. The view
  is centered on the party except near a map edge, where it stops and the icon moves off center. }
procedure DisplayWildMapView;

implementation

procedure DisplayWildMapView;
var
  wx: ShortInt;
  wy: Byte;
begin
  { 42 and 43, 34 and 35 are the last two columns and rows of the wilderness map. }
  wx := GDConsts.wildColOfs[GDVars.locType] + GDVars.zone0^.partyX.value;
  if wx < 2 then
  else if wx < 42 then wx := 2
  else if wx < 43 then wx := 3
  else wx := 4;
  if GDVars.zone0^.partyY.value < 2 then wy := GDVars.zone0^.partyY.value
  else if GDVars.zone0^.partyY.value < 34 then wy := 2
  else if GDVars.zone0^.partyY.value < 35 then wy := 3
  else wy := 4;
  MapTiles.DrawIconAnimSprite(wx, wy, GDVars.partyPos.facing, GDVars.wildAnimFrame mod 2,
                              GDVars.wildAnimFrame div 2 + 9);
  GDVars.wildAnimFrame := (GDVars.wildAnimFrame + 1) mod 6;
  Blit.FlushView;
end;

procedure DisplayMapView;
var
  wx: ShortInt;
  wy: ShortInt;
  loc: Byte;

  { Upper horizon band color for a horizon color selector. }
  function HorizonUpperColorOf(w: Byte): Byte;
  begin
    case w of
      8: HorizonUpperColorOf := Black;
      65: HorizonUpperColorOf := Black;
      232: HorizonUpperColorOf := White;
      else HorizonUpperColorOf := White;
    end;
  end;

  { Lower horizon band color for a horizon color selector. }
  function HorizonLowerColorOf(w: Byte): Byte;
  begin
    case w of
      8: HorizonLowerColorOf := DarkGray;
      65: HorizonLowerColorOf := LightGray;
      232: HorizonLowerColorOf := LightGray;
      else HorizonLowerColorOf := LightGray;
    end;
  end;

  { Floor color for a floor color selector. }
  function FloorColorOf(w: Byte): Byte;
  begin
    case w of
      11: FloorColorOf := DarkGray;
      9: FloorColorOf := Brown;
      219: FloorColorOf := Brown;
      6: FloorColorOf := Blue;
      else FloorColorOf := Brown;
    end;
  end;

begin
  loc := GDVars.locType;
  if GDVars.zone0^.view3dFlag <> 0 then loc := C_Area.LOC_3D_MAP;
  case loc of
    C_Area.LOC_3D_MAP: begin
      GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
      if GDVars.partyPos.eventAtCell > $7F then
        GDVars.skyCeilingColor := GDConsts.skyCeilingColors[GDVars.zone0^.alternateSkyColor]
      else
        GDVars.skyCeilingColor := GDConsts.skyCeilingColors[GDVars.zone0^.skyCeilingColor];
      if GDVars.picRegionW then begin
        GDVars.ceilingBandColor := HorizonUpperColorOf(GDVars.ceilFloorColorSel);
        GDVars.midBandColor := HorizonLowerColorOf(GDVars.ceilFloorColorSel);
        GDVars.floorBandColor := FloorColorOf(GDVars.wallColorSel);
      end;
      View3D.SetView3DColors(GDVars.skyCeilingColor, GDVars.ceilingBandColor, GDVars.midBandColor,
                             GDVars.floorBandColor);
      if GDVars.zone0^.noAutomap <> 0 then GDVars.automapOn := False;
      View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    end;
    C_Area.LOC_WILD_WEST..C_Area.LOC_WILD_EAST: begin
      wx := GDConsts.wildColOfs[loc] + GDVars.zone0^.partyX.value - 1 - 1;
      if wx < 0 then wx := 0;
      { last column origin for the 5-wide view }
      if wx > 39 then wx := 39;
      wy := GDVars.zone0^.partyY.value - 1 - 1;
      if wy < 0 then wy := 0;
      { last row origin for the 5-tall view }
      if wy > 31 then wy := 31;
      Wilds.BuildWildernessMap(wx, wy);
      MapView.DisplayWildMapView;
    end;
  end;
end;

begin
end.
