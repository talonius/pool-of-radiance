{ Picture loading, portrait composition and 3D sprite display. PIC and FINAL frames after the first are XOR deltas
  against the first frame. }
{$O+,F+,I-}
unit Portrait;

interface

uses Types, Crt, GDConsts, GDVars, Blit, DaxIo, GameIo, Border;

{ Empty routine with no callers. }
procedure NoopPortrait;

{ Draws a picture. An animation frame is drawn transparently and clipped into the view buffer one cell up and to the
  left, and the view is flushed; a plain picture goes straight to the screen.
  @param(col Column of the picture's upper-left character cell.)
  @param(row Row of the picture's upper-left character cell.)
  @param(anim True for an animation frame.)
  @param(pic The picture; nil draws nothing.) }
procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);

{ Draws a portrait head straight to the screen.
  @param(col Column of the head's upper-left character cell.)
  @param(row Row of the head's upper-left character cell.)
  @param(pic The head picture; nil draws nothing.) }
procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);

{ Draws a portrait body straight to the screen, five character rows below the head drawn at the same cell.
  @param(col Column of the head's upper-left character cell.)
  @param(row Row of the head's upper-left character cell.)
  @param(pic The body picture; nil draws nothing.) }
procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);

{ Loads a picture of <name><disk>.DAX into an animation record, unless that picture is the one last loaded, which it
  then keeps. Picture 1 of PIC is capped at four frames. A frame is loaded only while at least 3900 bytes of heap are
  free in one block, and the frame count becomes the number loaded. PIC and FINAL frames after the first are stored as
  XOR differences from the first. An odd transp remaps light magenta to black outside CGA. Pending keys are discarded
  afterwards. Note: a skipped frame's data after its 8-byte header is not stepped over, so the frames after it are read
  from the wrong offset.
  @param(name The file name, without the disk number.)
  @param(picId The block of the file that holds the picture.)
  @param(transp Bit 0 set to give each frame a transparency mask and the light magenta remap.)
  @param(a Receives the frames; its previous frames are freed first.) }
procedure LoadAnimation(name: Types.TStr8; picId: Byte; transp: Byte; var a: Types.TAnimRec);

{ Frees each frame of an animation record, clears the record and forgets the last loaded picture.
  @param(a The animation record.) }
procedure FreeAnimation(var a: Types.TAnimRec);

{ Draws a bordered window at the upper right and the current character's portrait in it, its head and body numbers
  mapped through the head and body tables. Nothing is drawn when either number is 0. }
procedure DisplayCharPortrait;

{ Draws the cached portrait straight to the screen.
  @param(col Column of the portrait's upper-left character cell.)
  @param(row Row of the portrait's upper-left character cell.)
  @param(both True for the head and the body, False for the head alone.) }
procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);

{ Loads a head from HEAD<disk>.DAX and a body from BODY<disk>.DAX into the portrait cache, skipping a picture that is
  255 or already cached, then discards pending keys.
  @param(headId The head picture, or 255 for none.)
  @param(bodyId The body picture, or 255 for none.) }
procedure LoadPortraitBufs(headId, bodyId: Byte);

{ Draws a 3D sprite frame transparently into the view buffer at its origin and flushes the view. A distance outside 1 to
  3 restores the video mode, prints an error and exits to DOS.
  @param(dist The view distance, 1 to 3, which is also the frame drawn.)
  @param(a The sprite's animation record; a missing frame draws nothing.) }
procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);

implementation

procedure NoopPortrait;
begin
end;

procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);
begin
  if pic <> nil then
    if anim then begin
      Blit.BlitTileClipped(col - 1, row - 1, 0, 1, pic, GDVars.viewBuffer);
      Blit.FlushView;
    end else
      Blit.ShowPic(col, row, pic);
end;

procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row, False, pic);
end;

procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row + 5, False, pic);
end;

procedure LoadAnimation(name: Types.TStr8; picId: Byte; transp: Byte; var a: Types.TAnimRec);
var
  sz: Word;
  buf: Types.PByteArr;
  offset: Word;
  f: Byte;
  h: Word;
  w: Word;
  diskCh: String[1];
  xorBuf: Types.PByteArr;
  j: Word;
  planeSz: Word;
  isPic: Boolean;
  gotXor: Boolean;
  loaded: Byte;
begin
  if (name = GDVars.picArcName) and (picId = GDVars.picArcId) then Exit;
  Portrait.FreeAnimation(a);
  GDVars.picArcName := name;
  GDVars.picArcId := picId;
  isPic := (name = 'PIC') or (name = 'FINAL');
  Str(LongInt(GDVars.virtualDisk), diskCh);
  DaxIo.LoadDax(name + diskCh, '.dax', picId, sz, buf);
  if sz = 0 then Exit;
  offset := 0;
  gotXor := False;
  with a do begin
    count := buf^[offset];
    if (name = 'PIC') and (picId = 1) then
      if count > 4 then count := 4;
    Inc(offset);
    current := 1;
    loaded := 0;
    for f := 1 to count do begin
      Move(buf^[offset], frames[f].time, SizeOf(frames[f].time));
      Inc(offset, SizeOf(frames[f].time));
      Move(buf^[offset], h, SizeOf(h));
      Inc(offset, SizeOf(h));
      Move(buf^[offset], w, SizeOf(w));
      Inc(offset, SizeOf(w));
      if MaxAvail >= 3900 then begin
        Inc(loaded);
        Blit.AllocPic(h, w, 1, transp, frames[f].pic);
        with frames[f].pic^ do begin
          Move(buf^[offset], originX, SizeOf(originX));
          Inc(offset, SizeOf(originX));
          Move(buf^[offset], originY, SizeOf(originY));
          Inc(offset, SizeOf(originY) + SizeOf(count));
          Move(buf^[offset], map, SizeOf(map));
          Inc(offset, SizeOf(map));
        end;
        if GDVars.videoMode = Types.Cga then
          planeSz := frames[f].pic^.imgSize * 2 - 1
        else
          planeSz := frames[f].pic^.imgSize - 1;
        if isPic then
          if f = 1 then begin
            GetMem(xorBuf, planeSz + 1);
            Move(buf^[offset], xorBuf^, planeSz + 1);
            gotXor := True;
          end else
            for j := offset to offset + planeSz do
              buf^[j] := buf^[j] xor xorBuf^[j - offset];
        Blit.ExpandPicFrames(buf, offset, Boolean(transp), 0, frames[f].pic);
        if (transp and 1 > 0) and (GDVars.videoMode <> Types.Cga) then
          Blit.RemapPic(GDConsts.animRemapFrom, GDConsts.animRemapTo, 0, False, frames[f].pic);
        Inc(offset, planeSz + 1);
      end;
    end;
    count := loaded;
  end;
  if isPic and gotXor then FreeMem(xorBuf, planeSz + 1);
  FreeMem(buf, sz);
  GameIo.DiscardPendingKeys;
end;

procedure FreeAnimation(var a: Types.TAnimRec);
begin
  with a do
    for GDVars.drawLoopIndex := 1 to count do
      Blit.FreePic(frames[GDVars.drawLoopIndex].pic);
  FillChar(a, SizeOf(a), 0);
  GDVars.picArcName[0] := #0;
  GDVars.picArcId := 255;
end;

procedure DisplayCharPortrait;
var
  headText: String[3];
  bodyText: String[3];
begin
  if (GDVars.curChar^.portraitHead = 0) or (GDVars.curChar^.portraitBody = 0) then Exit;
  Border.DrawWindow(28, 1, 38, 11, 0, Black, '');
  with GDVars.curChar^ do begin
    Str(LongInt(GDConsts.headTbl[portraitHead]), headText);
    Str(LongInt(GDConsts.bodyTbl[portraitBody]), bodyText);
    Portrait.LoadPortraitBufs(GDConsts.headTbl[portraitHead], GDConsts.bodyTbl[portraitBody]);
    Portrait.DisplayPortraitBufs(28, 1, True);
  end;
end;

procedure LoadPortraitBufs(headId, bodyId: Byte);
var
  diskCh: String[1];
begin
  Str(LongInt(GDVars.virtualDisk), diskCh);
  if headId <> 255 then
    if (GDVars.portraitCache[1].pictureId = 255) or (GDVars.portraitCache[1].pictureId <> headId)
    then begin
      Blit.LoadPic('HEAD' + diskCh, headId, False, 0, GDVars.portraitCache[1].pic);
      GDVars.portraitCache[1].pictureId := headId;
    end;
  if bodyId <> 255 then
    if (GDVars.portraitCache[2].pictureId = 255) or (GDVars.portraitCache[2].pictureId <> bodyId)
    then begin
      Blit.LoadPic('BODY' + diskCh, bodyId, False, 0, GDVars.portraitCache[2].pic);
      GDVars.portraitCache[2].pictureId := bodyId;
    end;
  GameIo.DiscardPendingKeys;
end;

procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);
begin
  if both then begin
    Portrait.DisplayPortraitHead(col, row, GDVars.portraitCache[1].pic);
    Portrait.DisplayPortraitBody(col, row, GDVars.portraitCache[2].pic);
  end else
    Portrait.DisplayImageBuf(col, row, False, GDVars.portraitCache[1].pic);
end;

procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);
begin
  if (dist < 1) or (dist > 3) then begin
    Blit.RestoreVideoMode;
    WriteLn('Illegal range in Show3DSprite.');
    GameIo.ExitGame;
  end;
  if a.frames[dist].pic <> nil then
    with a.frames[dist].pic^ do
      Blit.BlitTileClipped(originX + 3 - 1, originY + 3 - 1, 0, 1, a.frames[dist].pic, GDVars.viewBuffer)
  else
    Exit;
  Blit.FlushView;
end;

begin
end.
