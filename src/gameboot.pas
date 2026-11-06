{ Startup configuration: initialize the overlay manager, read POOL.CFG, select the video mode and reserve graphics
  memory. }
{$O+,F+,I-}
unit GameBoot;

interface

uses Types, C_Sound, GDConsts, GDVars, Crt, Dos, Overlay, DaxIo, GameIo, Video, SoundDrv;

implementation

const
  { graphics memory reserve: 16 KB in paragraphs }
  GFX_RESERVE_PARAS = 1024;
  OVERLAY_BUF_BYTES = 114688;

type
  TFreePtrW = record
    o: Word;
    s: Word;
    freeMin: Word;
  end;

var
  freePtrW: TFreePtrW absolute FreePtr;
  { free-range table front -- Move source }
  freeRangeHead: Types.PFreeRange absolute FreePtr;

{ Game startup runs through this unit's initialization section. }
begin
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  repeat
    Assign(GDVars.cfgFile, 'pool.cfg');
    Reset(GDVars.cfgFile, 128);
    GDVars.cfgErr := IOResult;
    if GDVars.cfgErr <> 0 then begin
      WriteLn('Please insert startup disk.');
      GDVars.cfgChar := GameIo.ReadGameKey;
    end;
  until GDVars.cfgErr = 0;
  Close(GDVars.cfgFile);
  CheckBreak := False;
  Assign(GDVars.cfgText, 'POOL.CFG');
  Reset(GDVars.cfgText);
  if IOResult <> 0 then begin
    WriteLn('Unable to find POOL.CFG');
    Halt;
  end;
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  { INT 10h AH=0Fh: get current video mode into AL }
  GDVars.interruptRegs.ah := $F;
  Intr($10, Registers(GDVars.interruptRegs));
  GDVars.savedVideoMode := GDVars.interruptRegs.al;
  GDVars.curVideoMode := GDVars.savedVideoMode;
  case GDVars.cfgChar of
    'E': begin
      GDVars.videoMode := Types.Ega;
      Video.SetVideoMode(13);
    end;
    'T': begin
      GDVars.videoMode := Types.Tandy;
      { Move the free-list entry at FreePtr down by GFX_RESERVE_PARAS paragraphs, keeping its offset, then repoint
        FreePtr at the copy }
      GDVars.gfxRelocDest := Ptr(freePtrW.s - GameBoot.GFX_RESERVE_PARAS, freePtrW.o);
      Move(freeRangeHead^, GDVars.gfxRelocDest^, SizeOf(Types.TFreeRange));
      FreePtr := GDVars.gfxRelocDest;
      Video.SetVideoMode(9);
    end;
    else begin
      GDVars.videoMode := Types.Cga;
      Video.SetVideoMode(4);
    end;
  end;
  if GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf <= MemAvail then
    OvrSetBuf(GameBoot.OVERLAY_BUF_BYTES)
  else begin
    Video.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf, ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    Video.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt;
  end;
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  case GDVars.cfgChar of
    'T': GDVars.soundMode := C_Sound.TANDY;
    'P': GDVars.soundMode := C_Sound.SPEAKER;
    else GDVars.soundMode := C_Sound.OFF;
  end;
  { Set the minimum free-list size and publish FreePtr to other units through GDVars.bootFreePtr }
  freePtrW.freeMin := 80;
  GDVars.bootFreePtr := FreePtr;
  SoundDrv.SoundSuspend;
  ReadLn(GDVars.cfgText, GDVars.gameDir);
  GDVars.gameDir := GDVars.gameDir;
  ReadLn(GDVars.cfgText, GDVars.saveDir);
  GDVars.saveDir := GDVars.saveDir;
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  if GDVars.cfgChar = 'F' then
    GDVars.fullIntro := True
  else
    GDVars.fullIntro := False;
  Close(GDVars.cfgText);
end.
