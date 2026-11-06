{ Dungeon and wilderness movement, door opening and the map menu. }
{$O+,F+}
unit Explore;

interface

uses Types, Crt, C_Area, C_Time, C_Msg, GDConsts, GDVars, SoundDrv, Camp, ViewChar, View3D, MapTiles, C_Ecl, C_Keys,
  C_Class, C_Status, C_Gbvm, C_Dir, C_Sound, FxEngine, GameTime, TextRend, MenuCore, CharHlp, Border, Portrait, Blit;

{ Moves the party in the direction it faces, unless movement is locked (MOVE_LOCKED 255), which instead clears the lock.
  On the 3D map an open way (barrier type 1) steps forward. A door (type 2 or 3) offers a Locked menu built from the
  door choices still open: Bash, Pick when the party has a thief, Knock (on type 2 when someone has Knock memorized, on
  type 3 when the party has a magic-user) and Exit; with nothing but Exit the door becomes a wall. On a type 3 door Pick
  only closes that choice. A step that fails, or a wall, plays the impact sound. In the wilderness the party takes a
  wilderness step. The portrait and animation buffers are freed on the way out. }
procedure ResolveMovement;

{ Runs the 3D or wilderness command menu until a command ends it: Encamp; Look, which turns searching on for this cell,
  advances the clock one turn and starts the search script; or a move key. In 3D the up arrow ends it after working out
  the step ahead, while the other arrows turn the party; in the wilderness each arrow sets the party's facing and ends
  it. Other extended keys select the previous or next character.
  @returns(The key that ended the menu.) }
function MapMainMenu: Char;

implementation

const
  { Spell ID }
  SPELL_KNOCK = 31;

{ Turns the barrier on one side of a 3D map cell into a wall (barrier type 0); the walls drawn there are unchanged.
  @param(x Map column of the cell.)
  @param(y Map row of the cell.)
  @param(facing The side, a cardinal direction.) }
procedure ChangeBarrierImpassable(x, y: ShortInt; facing: Byte);
begin
  case facing of
    C_Dir.WEST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $3F;
    C_Dir.SOUTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $CF;
    C_Dir.EAST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $F3;
    C_Dir.NORTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $FC;
  end;
end;

{ Opens the barrier on one side of a 3D map cell (barrier type 1). A cell outside the 16x16 map is ignored.
  @param(x Map column of the cell.)
  @param(y Map row of the cell.)
  @param(facing The side, a cardinal direction.) }
procedure ChangeBarrierPassable(x, y: ShortInt; facing: Byte);
begin
  if (x < 0) or (x > 15) or (y < 0) or (y > 15) then Exit;
  case facing of
    C_Dir.WEST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $3F or $40;
    C_Dir.SOUTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $CF or $10;
    C_Dir.EAST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $F3 or $4;
    C_Dir.NORTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $FC or $1;
  end;
end;

{ Tells whether any party member has a level in a class.
  @param(idx The class.)
  @returns(True when a party member has a level in it.) }
function PartyHasClass(idx: ShortInt): Boolean;
var
  p: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not found) do begin
    if p^.classLevels[idx] > 0 then found := True;
    p := p^.nextCharAddr;
  end;
  PartyHasClass := found;
end;

{ Has the party bash the door ahead: the members try in order, on the Strength open-doors table, until one succeeds. On
  a barred door (barrier type 3) Strength 18/91 to 25 rolls on the locked, barred or held column, and each member below
  18/91 closes the Bash choice at this door, though the members after it still try. On another door Strength 3 to 18/00
  rolls on the normal column. Success opens the door from both sides. Note: Strength 19 and above has no case in the
  normal column and never succeeds.
  @returns(True when the door was opened.) }
function BashDoor: Boolean;
var
  p: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not success) do begin
    with p^ do begin
      if View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing) = 3 then begin
        case strCur of
          18: case strExc of
                 91..99: if FxEngine.RollDice(1, 6) = 1 then success := True;
                 100: if FxEngine.RollDice(1, 6) <= 2 then success := True;
               else
                 GDVars.doorOpen[0] := 0;
               end;
          19, 20: if FxEngine.RollDice(1, 6) <= 3 then success := True;
          21, 22: if FxEngine.RollDice(1, 6) <= 4 then success := True;
          23: if FxEngine.RollDice(1, 6) <= 5 then success := True;
          24: if FxEngine.RollDice(1, 8) <= 7 then success := True;
          25: success := True;
        else
          GDVars.doorOpen[0] := 0;
        end;
      end else
        case strCur of
          3..7: if FxEngine.RollDice(1, 6) = 1 then success := True;
          8..15: if FxEngine.RollDice(1, 6) <= 2 then success := True;
          16..17: if FxEngine.RollDice(1, 6) <= 3 then success := True;
          18: case strExc of
                 0..50: if FxEngine.RollDice(1, 6) <= 3 then success := True;
                 51..99: if FxEngine.RollDice(1, 6) <= 4 then success := True;
                 100: if FxEngine.RollDice(1, 6) <= 5 then success := True;
               end;
        end;
    end;
    p := p^.nextCharAddr;
  end;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX + GDConsts.dirDx[GDVars.partyPos.facing],
                                  GDVars.partyPos.mapY + GDConsts.dirDy[GDVars.partyPos.facing],
                                  (GDVars.partyPos.facing + 4) mod 8);
  end;
  BashDoor := success;
end;

{ Has the party pick the lock of the door ahead: each member in turn rolls d100 against its Open Locks skill, and the
  roll counts only for a member who is okay. The Pick choice closes at this door whatever the result. Success opens the
  door from both sides.
  @returns(True when the door was opened.) }
function PickLock: Boolean;
var
  p: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not success) do begin
    with p^ do
      if (FxEngine.RollDice(1, 100) <= thiefSkills[2]) and (status = C_Status.OKAY) then
        success := True;
    p := p^.nextCharAddr;
  end;
  GDVars.doorOpen[1] := 0;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX + GDConsts.dirDx[GDVars.partyPos.facing],
                                  GDVars.partyPos.mapY + GDConsts.dirDy[GDVars.partyPos.facing],
                                  (GDVars.partyPos.facing + 4) mod 8);
  end;
  PickLock := success;
end;

{ Finds a memorized spell.
  @param(spellId The spell.)
  @param(creature The character.)
  @returns(The first memorized-spell slot, 0 to 20, holding the spell; 255 when none does.) }
function FindMemorizedSpell(spellId: Byte; creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  i := 0;
  { the last index of memorizedSpells }
  while (i <= 20) and (creature^.memorizedSpells[i] <> spellId) do
    Inc(i);
  if i <= 20 then
    FindMemorizedSpell := i
  else
    FindMemorizedSpell := 255;
end;

{ Finds a party member with a spell memorized.
  @param(spellId The spell.)
  @returns(The first party member with it memorized, or nil.) }
function FindCharWithSpell(spellId: Byte): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  while (p <> nil) and (Explore.FindMemorizedSpell(spellId, p) = 255) do
    p := p^.nextCharAddr;
  FindCharWithSpell := p;
end;

{ Has the first party member with Knock memorized use it on the door ahead, clearing the memorized slot.
  @returns(True when someone had Knock memorized.) }
function PartyCastsKnock: Boolean;
var
  p: Types.PCharRecord;
begin
  p := Explore.FindCharWithSpell(Explore.SPELL_KNOCK);
  if p <> nil then begin
    p^.memorizedSpells[Explore.FindMemorizedSpell(Explore.SPELL_KNOCK, p)] := 0;
    PartyCastsKnock := True;
  end else
    PartyCastsKnock := False;
end;

{ Works out the step ahead on the 3D map without taking it. A step off the 16x16 map, unless a wall stands in the way,
  puts the party on that edge and sets LEAVE_MAP; otherwise LEAVE_MAP is cleared. }
procedure MoveForward;
var
  nx: Integer;
  ny: Integer;
  f: Integer;
begin
  nx := GDVars.partyPos.mapX;
  ny := GDVars.partyPos.mapY;
  f := GDVars.partyPos.facing;
  GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 0;
  if View3D.GetBarrierType(nx, ny, f) <> 0 then begin
    Inc(nx, GDConsts.dirDx[f]);
    Inc(ny, GDConsts.dirDy[f]);
    if nx > 15 then begin
      GDVars.partyPos.mapX := 15;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if nx < 0 then begin
      GDVars.partyPos.mapX := 0;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if ny > 15 then begin
      GDVars.partyPos.mapY := 15;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if ny < 0 then begin
      GDVars.partyPos.mapY := 0;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
  end;
end;

{ Steps the party one cell forward on the 3D map with the step sound, wrapping at the map's edges, refreshes the wall
  ahead and the cell's event, reopens the door choices and advances the clock one minute, or one turn while searching. }
procedure MovePartyForward3D;
begin
  SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
  Inc(GDVars.partyPos.mapX, GDConsts.dirDx[GDVars.partyPos.facing]);
  Inc(GDVars.partyPos.mapY, GDConsts.dirDy[GDVars.partyPos.facing]);
  if GDVars.partyPos.mapX < 0 then GDVars.partyPos.mapX := 15;
  if GDVars.partyPos.mapX > 15 then GDVars.partyPos.mapX := 0;
  if GDVars.partyPos.mapY < 0 then GDVars.partyPos.mapY := 15;
  if GDVars.partyPos.mapY > 15 then GDVars.partyPos.mapY := 0;
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
  if GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1 > 0 then
    GameTime.AdvanceTime(1, C_Time.TURNS)
  else
    GameTime.AdvanceTime(1, C_Time.MINUTES);
end;

{ Steps the party one cell in the direction it faces on the wilderness map, kept inside the area's 16 columns and the
  map's rows. Impassable terrain blocks the step, and the river blocks it with a message until Yarash's pyramid is gone.
  A step advances the clock 12 hours. }
procedure MovePartyWilderness;
var
  col: ShortInt;
  nx: ShortInt;
  ny: ShortInt;
begin
  nx := GDVars.zone0^.partyX.value + GDConsts.dirDx[GDVars.partyPos.facing];
  ny := GDVars.zone0^.partyY.value + GDConsts.dirDy[GDVars.partyPos.facing];
  if nx < 0 then nx := 0;
  if nx > 15 then nx := 15;
  if ny < 0 then ny := 0;
  { the last row of wildMap }
  if ny > 35 then ny := 35;
  col := nx + GDConsts.wildColOfs[GDVars.locType];
  case GDConsts.wildMap[ny, col] of
    78, 126..128, 130..132, 168..172, 174..179, 188, 221..222,
    225..233, 245: ;
    102..108, 114:
      if GDVars.zone0^.yarashPyramidLeft = 0 then
        TextRend.PrintAndPause('The river''s stench drives you back.', Yellow)
      else begin
        GDVars.zone0^.partyX.value := nx;
        GDVars.zone0^.partyY.value := ny;
        GameTime.AdvanceTime(12, C_Time.HOURS);
      end;
  else begin
    GDVars.zone0^.partyX.value := nx;
    GDVars.zone0^.partyY.value := ny;
    GameTime.AdvanceTime(12, C_Time.HOURS);
  end;
  end;
end;

function MapMainMenu: Char;
var
  done: Boolean;
  c: Char;
  ext: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuText: String[40];
  viewDone: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  oldZone: Pointer;
begin
  GDVars.zone1^[C_Gbvm.MOVE_LOCKED] := 0;
  case GDVars.locType of
    C_Area.LOC_3D_MAP: begin
         done := False;
         repeat
           c := MenuCore.MenuHorizontal('', GDConsts.menu3D, LightMagenta, LightGreen, White, True, False,
                                        ext);
           if not ext then begin
             case c of
               'A': if GDVars.zone0^.noAutomap = 0 then begin
                      GDVars.automapOn := GDVars.automapOn = False;
                      View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
                    end else
                      TextRend.PrintAndPause('Not Here', Yellow);
               'C': if GDVars.curChar^.status = C_Status.OKAY then Camp.NoncombatCastMenu;
               'V': ViewChar.ViewCharMenu(viewDone);
               'E': done := True;
               'S': GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] xor 1;
               'L': begin
                      GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] or 2;
                      GameTime.AdvanceTime(1, C_Time.TURNS);
                      GDVars.eclIp := GDVars.scriptEntryAddrs[C_Ecl.SEARCH_ENTRY];
                      done := True;
                    end;
             end;
           end else begin
             case c of
               { up arrow: step forward }
               C_Keys.UP: begin
                         Explore.MoveForward;
                         done := True;
                       end;
               { down arrow: turn around }
               C_Keys.DOWN: begin
                           GDVars.partyPos.facing := (GDVars.partyPos.facing + 4) mod 8;
                           GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                           GDVars.partyPos.facing);
                           View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
                         end;
               { left arrow: turn left }
               C_Keys.LEFT: begin
                           GDVars.partyPos.facing := (GDVars.partyPos.facing + 6) mod 8;
                           SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
                           GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                           GDVars.partyPos.facing);
                           View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
                         end;
               { right arrow: turn right }
               C_Keys.RIGHT: begin
                            GDVars.partyPos.facing := (GDVars.partyPos.facing + 2) mod 8;
                            SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
                            GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                            GDVars.partyPos.facing);
                            View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
                          end;
             else begin
               ViewChar.SelectPrevNextChar(c);
               CharHlp.DisplayParty(GDVars.curChar);
             end;
             end;
           end;
           CharHlp.PrintPositionAndTime;
         until done;
       end;
    C_Area.LOC_WILD_WEST..C_Area.LOC_WILD_EAST: begin
        if GDVars.locTypePrev < C_Area.LOC_WILD_WEST then begin
          MapTiles.LoadIconAnim('ICON', 0, 9);
          MapTiles.LoadIconAnim('ICON', 1, 10);
          MapTiles.LoadIconAnim('ICON', 2, 11);
          CharHlp.DisplayWildernessInterface;
        end;
        done := False;
        repeat
          c := MenuCore.MenuHorizontal('', GDConsts.menuWild, LightMagenta, LightGreen, White, True, False,
                                       ext);
          if not ext then begin
            case c of
              'C': Camp.NoncombatCastMenu;
              'V': ViewChar.ViewCharMenu(viewDone);
              'E': done := True;
              'S': GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] xor 1;
              'L': begin
                     GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] or 2;
                     GameTime.AdvanceTime(1, C_Time.TURNS);
                     GDVars.eclIp := GDVars.scriptEntryAddrs[C_Ecl.SEARCH_ENTRY];
                     done := True;
                   end;
            end;
          end else begin
            done := True;
            case c of
              C_Keys.UP: GDVars.partyPos.facing := C_Dir.NORTH;
              C_Keys.RIGHT: GDVars.partyPos.facing := C_Dir.EAST;
              C_Keys.DOWN: GDVars.partyPos.facing := C_Dir.SOUTH;
              C_Keys.LEFT: GDVars.partyPos.facing := C_Dir.WEST;
            else begin
              ViewChar.SelectPrevNextChar(c);
              CharHlp.DisplayParty(GDVars.curChar);
              done := False;
            end;
            end;
          end;
          CharHlp.PrintPositionAndTime;
        until done;
      end;
  end;
  GDVars.locTypePrev := GDVars.locType;
  if GDVars.bottomMsgCleared = 0 then begin
    Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    GDVars.bottomMsgCleared := 1;
  end;
  MapMainMenu := c;
end;

procedure ResolveMovement;
var
  moved: Boolean;
  extendedKey: Boolean;
  menuStr: String[40];
  choice: Char;
begin
  moved := False;
  case GDVars.locType of
    C_Area.LOC_3D_MAP: if GDVars.zone1^[C_Gbvm.MOVE_LOCKED] < 255 then begin
         case View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing) of
           1: moved := True;
           2: begin
                menuStr[0] := #0;
                if GDVars.doorOpen[0] <> 0 then
                  menuStr := 'Bash';
                if (GDVars.doorOpen[1] <> 0) and Explore.PartyHasClass(C_Class.THIEF_LEVEL) then
                  menuStr := menuStr + ' Pick';
                if (GDVars.doorOpen[2] <> 0) and (Explore.FindCharWithSpell(Explore.SPELL_KNOCK) <> nil)
                then
                  menuStr := menuStr + ' Knock';
                menuStr := menuStr + ' Exit';
                if menuStr = ' Exit' then
                  Explore.ChangeBarrierImpassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing)
                else begin
                  choice := MenuCore.MenuHorizontal('Locked. ', menuStr, LightMagenta, LightGreen,
                                                    White, False, False, extendedKey);
                  case choice of
                    'B': moved := Explore.BashDoor;
                    'P': moved := Explore.PickLock;
                    'K': moved := Explore.PartyCastsKnock;
                  end;
                end;
              end;
           3: begin
                menuStr[0] := #0;
                if GDVars.doorOpen[0] <> 0 then
                  menuStr := 'Bash';
                if (GDVars.doorOpen[1] <> 0) and Explore.PartyHasClass(C_Class.THIEF_LEVEL) then
                  menuStr := menuStr + ' Pick';
                if (GDVars.doorOpen[2] <> 0) and Explore.PartyHasClass(C_Class.MAGE_LEVEL) then
                  menuStr := menuStr + ' Knock';
                menuStr := menuStr + ' Exit';
                if menuStr = ' Exit' then
                  Explore.ChangeBarrierImpassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing)
                else begin
                  choice := MenuCore.MenuHorizontal('Locked. ', menuStr, LightMagenta, LightGreen,
                                                    White, False, False, extendedKey);
                  case choice of
                    'B': moved := Explore.BashDoor;
                    'P': GDVars.doorOpen[1] := 0;
                    'K': moved := Explore.PartyCastsKnock;
                  end;
                end;
              end;
         end;
         if moved then
           Explore.MovePartyForward3D
         else
           SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.IMPACT]);
         CharHlp.PrintPositionAndTime;
       end else
         GDVars.zone1^[C_Gbvm.MOVE_LOCKED] := 0;
    C_Area.LOC_WILD_WEST..C_Area.LOC_WILD_EAST: if GDVars.zone1^[C_Gbvm.MOVE_LOCKED] < 255 then begin
            Explore.MovePartyWilderness;
            CharHlp.PrintPositionAndTime;
          end else
            GDVars.zone1^[C_Gbvm.MOVE_LOCKED] := 0;
  end;
  Portrait.FreeAnimation(GDVars.animData);
  Blit.FreePic(GDVars.portraitCache[1].pic);
  Blit.FreePic(GDVars.portraitCache[2].pic);
  GDVars.portraitCache[1].pictureId := 255;
  GDVars.portraitCache[2].pictureId := 255;
end;

begin
end.
