{ Load terrain tiles and creature icon frames, copy tiles into the view buffer and draw animated icons.

  Tile IDs use seven bits for the index and the high bit to select the second tile-set buffer. }
{$O+,F+,I-}
unit MapTiles;

interface

uses Types, Blit, Crt, C_Tile, GDConsts, GDVars, GameIo, C_Dir;

{ Empty routine with no callers. }
procedure NoopMapTiles;

{ Loads block 1 of a 24x24 tile set and, when the first tile-set buffer is allocated, copies its tiles into that buffer
  from a starting tile slot, then discards pending keys. A starting slot above 127, the last, restores the video mode
  and exits to DOS with a range error.
  @param(name The file name of the tile set.)
  @param(mult The first tile slot to fill.)
  @param(slot Unused.) }
procedure Load24x24Set(name: string; mult: Byte; slot: ShortInt);

{ Draws one 24x24 map tile into the view buffer; a tile id above the index mask comes from the second tile set.
  @param(col Column of the tile's upper-left character cell.)
  @param(row Row of the tile's upper-left character cell.)
  @param(tile The tile id.)
  @param(flag Unused.) }
procedure Copy2DTile(col, row: ShortInt; tile: Byte; flag: ShortInt);

{ Frees both frames of an icon animation slot.
  @param(animIdx The slot.) }
procedure FreeIconAnim(animIdx: Byte);

{ Loads both frames of an icon-animation slot, blocks fileId and fileId + 128, with color 0 transparent, then discards
  pending keys. CHEAD and CBODY names drop their last character, and a trailing T adds 64 to the block. Those two,
  COMSPR and ICON take no disk number, and ICON frames turn light magenta into black. Any other name takes the virtual
  disk number, and its frames turn light magenta into dark gray.
  @param(name The file name.)
  @param(fileId The block of the first frame.)
  @param(animIdx The icon-animation slot to fill.) }
procedure LoadIconAnim(name: string; fileId, animIdx: Byte);

{ Draws one frame of an icon animation into the view buffer, transparently and clipped, mirrored for facings past
  southeast. Nothing is drawn when the frame is not loaded.
  @param(col View column; the frame goes three character cells per column.)
  @param(row View row; the frame goes three character cells per row.)
  @param(facing The direction the icon faces.)
  @param(frame The frame, 0 or 1.)
  @param(animIdx The icon-animation slot.) }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

implementation

procedure NoopMapTiles;
begin
end;

procedure Load24x24Set(name: string; mult: Byte; slot: ShortInt);
var
  pic: Types.PImgBuf;
  total: Word;
  offset: Word;
begin
  if mult > 127 then begin
    Blit.RestoreVideoMode;
    WriteLn('Start range error in Load24x24Set');
    GameIo.ExitGame;
  end;
  pic := nil;
  Blit.LoadPic(name, 1, False, 0, pic);
  total := pic^.count * pic^.imgSize;
  offset := mult * pic^.imgSize;
  if GDVars.tileSetLow <> nil then
    Move(pic^.data, GDVars.tileSetLow^.data[offset], total);
  Blit.FreePic(pic);
  GameIo.DiscardPendingKeys;
end;

procedure Copy2DTile(col, row: ShortInt; tile: Byte; flag: ShortInt);
begin
  if tile > C_Tile.ID_MASK then
    Blit.BlitTileCell(col, row, tile and C_Tile.ID_MASK, 0, GDVars.tileSetHigh,
                      GDVars.viewBuffer)
  else
    Blit.BlitTileCell(col, row, tile, 0, GDVars.tileSetLow, GDVars.viewBuffer);
end;

procedure FreeIconAnim(animIdx: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Integer;
begin
  if GDVars.iconAnimation[animIdx, 0] <> nil then
    Blit.FreePic(GDVars.iconAnimation[animIdx, 0]);
  if GDVars.iconAnimation[animIdx, 1] <> nil then
    Blit.FreePic(GDVars.iconAnimation[animIdx, 1]);
end;

procedure LoadIconAnim(name: string; fileId, animIdx: Byte);
var
  suffix: string[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if (Copy(name, 1, 5) = 'CHEAD') or (Copy(name, 1, 5) = 'CBODY') then begin
    if UpCase(name[Length(name)]) = 'T' then
      Inc(fileId, 64);
    name := Copy(name, 1, Length(name) - 1);
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.iconAnimation[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.iconAnimation[animIdx, 1]);
  end else if (name = 'COMSPR') or (name = 'ICON') then begin
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.iconAnimation[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.iconAnimation[animIdx, 1]);
    if name = 'ICON' then begin
      Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToBlack, 0, False,
                    GDVars.iconAnimation[animIdx, 0]);
      Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToBlack, 0, False,
                    GDVars.iconAnimation[animIdx, 1]);
    end;
  end else begin
    Str(GDVars.virtualDisk, suffix);
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.iconAnimation[animIdx, 0]);
    Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToDarkGray, 0, False,
                  GDVars.iconAnimation[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.iconAnimation[animIdx, 1]);
    Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToDarkGray, 0, False,
                  GDVars.iconAnimation[animIdx, 1]);
  end;
  GameIo.DiscardPendingKeys;
end;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var
  work: Types.PImgBuf;
begin
  if GDVars.iconAnimation[animIdx, frame] = nil then
    Exit;
  with GDVars.iconAnimation[animIdx, frame]^ do begin
    Blit.AllocPic(height, width, 1, 1, work);
    if facing > C_Dir.SOUTHEAST then
      Blit.MirrorPic(GDVars.iconAnimation[animIdx, frame], work)
    else begin
      Move(data, work^.data, imgSize);
      { The EGA mask is a quarter of the image size. }
      if GDVars.videoMode = Types.Ega then
        Move(transp^, work^.transp^, imgSize div 4)
      else
        Move(transp^, work^.transp^, imgSize);
    end;
  end;
  Blit.BlitTileClipped(col * 3, row * 3, 0, 1, work, GDVars.viewBuffer);
  Blit.FreePic(work);
end;

begin
end.
