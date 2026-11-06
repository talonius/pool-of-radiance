{ Build and display the wilderness map. }
{$O+,F+}
unit Wilds;

interface

uses Types, Crt, C_Msg, GDConsts, GDVars, Border, MapTiles;

{ Draws the 5x5 wilderness view. Each cell's tile comes from the wilderness map; at a special location the location's
  own tile replaces it while the quest flags in zone 0 show the site: the buccaneers' base, the nomad camp, the kobold
  caves, the lizard man keep, Sorcerer's Island and Phlan, and always the hills. The tiles are drawn three character
  cells apart.
  @param(ulX Map column of the view's upper-left cell.)
  @param(ulY Map row of the view's upper-left cell.) }
procedure BuildWildernessMap(ulX, ulY: Integer);

{ Draw the empty bordered windows of the wilderness screen: two side by side at the top and the message area. }
procedure DrawWildWindows;

implementation

const
  { 12,31 = western 12,31 }
  BUCCANEERS_BASE = 3;
  { 25,11 = central 12,11 }
  NOMAD_CAMP = 4;
  { 32,15 = eastern 6,15 }
  KOBOLD_CAVES = 5;
  { Hills icon, always drawn at this location. }
  HILLS_SITE = 6;
  { 37,8 = eastern 11,8 }
  LIZARD_MAN_KEEP = 7;
  { 19,16 = central 6,16, Yarash's island }
  SORCERERS_ISLAND = 8;
  { 25,27 = central 12,27 }
  PHLAN = 9;

procedure BuildWildernessMap(ulX, ulY: Integer);
var
  viewX: ShortInt;
  viewY: ShortInt;
  k: ShortInt;
  mapX: ShortInt;
  mapY: ShortInt;
  icon: Byte;
  col: Byte;
  row: Byte;
begin
  viewY := 0;
  for row := 0 to 4 do begin
    viewX := 0;
    for col := 0 to 4 do begin
      mapX := col + ulX;
      mapY := row + ulY;
      { The map and the override table hold 1-based tile ids. }
      icon := GDConsts.wildMap[mapY, mapX] - 1;
      { one pass per special location }
      for k := 1 to 9 do begin
        if (mapX = GDConsts.wildernessSpecialLocations[k].x) and
            (mapY = GDConsts.wildernessSpecialLocations[k].y) then begin
          case k of
            Wilds.BUCCANEERS_BASE: begin
              if GDVars.zone0^.buccaneersBaseGate <> 255 then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
            Wilds.NOMAD_CAMP: begin
              if (GDVars.zone0^.nomadCampPresent <> 0) or ((GDVars.zone0^.nomadCampFlags and 8) <> 0)
                 or (GDVars.zone0^.nomadCampGate = 0) then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
            Wilds.KOBOLD_CAVES: begin
              if (GDVars.zone0^.easternSitesGate and 2) = 0 then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
            Wilds.HILLS_SITE: icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            Wilds.LIZARD_MAN_KEEP: begin
              if (GDVars.zone0^.easternSitesGate and 1) = 0 then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
            Wilds.SORCERERS_ISLAND, Wilds.PHLAN: begin
              if GDVars.zone0^.yarashMissionDone > 253 then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
          end;
        end;
      end;
      MapTiles.Copy2DTile(viewX + 1 - 1, viewY + 1 - 1, icon, 1);
      Inc(viewX, 3);
    end;
    Inc(viewY, 3);
  end;
end;

procedure DrawWildWindows;
begin
  Border.DrawWindow(1, 1, 15, 15, 0, Black, '');
  Border.DrawWindow(17, 1, 38, 15, 0, Black, '');
  Border.DrawWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0, Black,
                    '');
end;

begin
end.
