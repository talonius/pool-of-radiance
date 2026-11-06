{ Endgame animation, victory sequence and Yarash completion handling. }
{$O+,F+}
unit Ending;

interface

uses Types, Crt, C_Tile, C_Msg, GDConsts, GDVars, Blit, TextRend, CharHlp, Wilds, Portrait, C_Gbvm;

{ Plays the endgame: the dragon's death, Tyranthraxus' threat to possess a party member and Bane's recall, each with its
  text and a FINAL animation. The pictures are blocks of FINAL<n>.DAX, where n is the virtual disk number; blocks 4, 5
  and 6 add a party figure when the party has more than one, two and three members. The interface state is the won-game
  state for the duration, then the saved state is restored and the non-combat interface redrawn. }
procedure WinGame;

{ Recolors Yarash's pyramid in the wilderness tile sets with the full remap. When animating, it first shows the
  wilderness view and runs nine steps that each apply a dithered (random partial) remap to the pyramid tiles and redraw
  the view at that step's position, and afterwards it shows the view at the pyramid and pauses twice.
  @param(animate True to animate the change on screen.) }
procedure YarashComplete(animate: Boolean);

implementation

const
  { Interface state (GDVars.ifcState) }
  IFC_WON_GAME = 7;

{ Loads a FINAL animation and plays it for a number of full cycles. The first frame is drawn opaque and flushed, then
  each pass draws the current frame transparently at the same place and flushes it. A frame stays up for its time times
  (gameDelay + 3) ticks; wrapping from the last frame to the first completes a cycle.
  @param(col Column of the animation, one more than its left character cell.)
  @param(row Row of the animation, one more than its top character cell.)
  @param(picId The FINAL animation to play.)
  @param(nCycles How many full cycles to play.) }
procedure PlayFinalAnim(col, row: Integer; picId, nCycles: Byte);
var
  a: Types.TAnimRec;
  tickNow: LongInt;
  tickLast: LongInt;
  cycles: Byte;
begin
  cycles := 0;
  tickLast := TextRend.GetTicks;
  FillChar(a, SizeOf(a), 0);
  Portrait.LoadAnimation('FINAL', picId, 2, a);
  Blit.BlitTileClipped(col - 1, row - 1, 0, 0, a.frames[1].pic, GDVars.viewBuffer);
  Blit.FlushView;
  repeat
    Portrait.DisplayImageBuf(col, row, True, a.frames[a.current].pic);
    tickNow := TextRend.GetTicks;
    if tickNow - tickLast > a.frames[a.current].time * (GDVars.gameDelay + 3) then begin
      Inc(a.current);
      if a.current > a.count then begin
        a.current := 1;
        Inc(cycles);
      end;
      tickLast := tickNow;
    end;
  until cycles = nCycles;
  Portrait.FreeAnimation(a);
end;

procedure WinGame;
begin
  Str(GDVars.virtualDisk, GDVars.finalSfx);
  GDVars.savedIfc := GDVars.ifcState;
  GDVars.ifcState := Ending.IFC_WON_GAME;
  GDVars.finalPic := nil;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  TextRend.DisplayString(1, 17, LightGreen, 'Mortally wounded, the dragon roars!');
  TextRend.DisplayString(1, 18, LightGreen, 'The spirit of Tyranthraxus flares up');
  TextRend.DisplayString(1, 19, LightGreen, 'from the dragon''s body.');
  CharHlp.DisplayNoncombatInterface;
  Blit.LoadPic('FINAL' + GDVars.finalSfx, 1, False, 0, GDVars.finalPic);
  Blit.BlitTileClipped(0, 0, 0, 0, GDVars.finalPic, GDVars.viewBuffer);
  Ending.PlayFinalAnim(3, 5, 2, (10 - GDVars.gameDelay) * 5 div 2);
  Blit.LoadPic('FINAL' + GDVars.finalSfx, 3, False, 0, GDVars.finalPic);
  Blit.BlitTileClipped(0, 0, 0, 0, GDVars.finalPic, GDVars.viewBuffer);
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 1 then begin
    Blit.LoadPic('FINAL' + GDVars.finalSfx, 4, False, 0, GDVars.finalPic);
    Blit.BlitTileClipped(0, 11, 0, 0, GDVars.finalPic, GDVars.viewBuffer);
  end;
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 2 then begin
    Blit.LoadPic('FINAL' + GDVars.finalSfx, 5, False, 0, GDVars.finalPic);
    Blit.BlitTileClipped(13, 9, 0, 0, GDVars.finalPic, GDVars.viewBuffer);
  end;
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 3 then begin
    Blit.LoadPic('FINAL' + GDVars.finalSfx, 6, False, 0, GDVars.finalPic);
    Blit.BlitTileClipped(0, 9, 0, 0, GDVars.finalPic, GDVars.viewBuffer);
  end;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  TextRend.DisplayString(1, 17, LightGreen, '"Fools, you have but slain the body');
  TextRend.DisplayString(1, 18, LightGreen, 'I possessed.  I cannot be defeated!"');
  TextRend.DisplayString(1, 19, LightGreen, 'With the power of the pool of radiance');
  TextRend.DisplayString(1, 20, LightGreen, 'which I moved here, to my lair,');
  TextRend.DisplayString(1, 21, LightGreen, 'I will still rule, by possessing one');
  TextRend.DisplayString(1, 22, LightGreen, 'of you!"');
  Ending.PlayFinalAnim(3, 1, 7, (10 - GDVars.gameDelay) * 5 div 2);
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  TextRend.DisplayString(1, 17, LightGreen, '"No Lord Bane!  I can still rule here!');
  TextRend.DisplayString(1, 18, LightGreen, 'I have not failed.  Do not call me back');
  TextRend.DisplayString(1, 19, LightGreen, 'through the pool!"');
  TextRend.DisplayString(1, 20, LightGreen, 'Noooo...');
  Ending.PlayFinalAnim(3, 1, 8, 1);
  TextRend.PauseOnly;
  TextRend.PauseOnly;
  TextRend.PauseOnly;
  GDVars.ifcState := GDVars.savedIfc;
  CharHlp.DisplayNoncombatInterface;
end;

procedure YarashComplete(animate: Boolean);
var
  t: Byte;
  step: Byte;
begin
  if animate then begin
    Wilds.BuildWildernessMap(17, 15);
    Blit.FlushView;
    { 8 is the last index of yarViewX and yarViewY }
    for step := 0 to 8 do begin
      { 10 is the last index of yarBlueGreenTiles }
      for t := 0 to 10 do
        if GDConsts.yarBlueGreenTiles[t] > C_Tile.ID_MASK then
          Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarBlueGreenTo,
                        GDConsts.yarBlueGreenTiles[t] and C_Tile.ID_MASK, True, GDVars.tileSetHigh)
        else
          Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarBlueGreenTo, GDConsts.yarBlueGreenTiles[t], True,
                        GDVars.tileSetLow);
      { 17 is the last index of yarGreenTiles }
      for t := 0 to 17 do
        if GDConsts.yarGreenTiles[t] > C_Tile.ID_MASK then
          Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarGreenTo, GDConsts.yarGreenTiles[t] and C_Tile.ID_MASK, True,
                        GDVars.tileSetHigh)
        else
          Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarGreenTo, GDConsts.yarGreenTiles[t], True, GDVars.tileSetLow);
      Wilds.BuildWildernessMap(GDConsts.yarViewX[step], GDConsts.yarViewY[step]);
      Blit.FlushView;
    end;
  end;
  { 10 is the last index of yarBlueGreenTiles }
  for t := 0 to 10 do
    if GDConsts.yarBlueGreenTiles[t] > C_Tile.ID_MASK then
      Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarBlueGreenTo, GDConsts.yarBlueGreenTiles[t] and C_Tile.ID_MASK,
                    False, GDVars.tileSetHigh)
    else
      Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarBlueGreenTo, GDConsts.yarBlueGreenTiles[t], False,
                    GDVars.tileSetLow);
  { 17 is the last index of yarGreenTiles }
  for t := 0 to 17 do
    if GDConsts.yarGreenTiles[t] > C_Tile.ID_MASK then
      Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarGreenTo, GDConsts.yarGreenTiles[t] and C_Tile.ID_MASK, False,
                    GDVars.tileSetHigh)
    else
      Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarGreenTo, GDConsts.yarGreenTiles[t], False, GDVars.tileSetLow);
  if animate then begin
    Wilds.BuildWildernessMap(23, 25);
    Blit.FlushView;
    TextRend.PauseOnly;
    TextRend.PauseOnly;
  end;
end;

begin
end.
