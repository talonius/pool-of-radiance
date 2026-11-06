{ Startup configuration: initialize the overlay manager, read POOL.CFG, select the video mode and reserve graphics
  memory. }
{$O+,F+,I-}
unit GameBoot;

interface

uses Types, C_Sound, GDConsts, GDVars, Crt, Dos, Overlay, TextRend, Blit, SoundDrv, DaxIo, GameIo;

implementation

const
  { graphics memory reserve: 16 KB in paragraphs }
  GFX_RESERVE_PARAS = 1024;
  OVERLAY_BUF_BYTES = 100352;

type
  THeapEndW = record
    o: Word;
    s: Word;
  end;

var
  heapEndW: THeapEndW absolute HeapEnd;

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
      Blit.SetVideoMode(13);
      GDVars.pageMain := 0;
      GDVars.pageNum := 0;
      TextRend.SetupEgaCurrentPage(GDVars.pageMain);
      TextRend.SetupEgaOtherPage(GDVars.pageNum);
    end;
    'T': begin
      GDVars.videoMode := Types.Tandy;
      { Lower HeapEnd by GFX_RESERVE_PARAS; the common code after the sound setting lowers it once more, so Tandy
        reserves twice as much }
      GDVars.gfxReserve := Ptr(heapEndW.s - GameBoot.GFX_RESERVE_PARAS, heapEndW.o);
      HeapEnd := GDVars.gfxReserve;
      Blit.SetVideoMode(9);
    end;
    else begin
      GDVars.videoMode := Types.Cga;
      Blit.SetVideoMode(4);
    end;
  end;
  if GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf <= MemAvail then
    OvrSetBuf(GameBoot.OVERLAY_BUF_BYTES)
  else begin
    Blit.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf, ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt;
  end;
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  case GDVars.cfgChar of
    'T': GDVars.soundMode := C_Sound.TANDY;
    'P': GDVars.soundMode := C_Sound.SPEAKER;
    else GDVars.soundMode := C_Sound.OFF;
  end;
  { Lower HeapEnd by GFX_RESERVE_PARAS (16 KB) and record the new limit in gfxReserve }
  GDVars.gfxReserve := Ptr(heapEndW.s - GameBoot.GFX_RESERVE_PARAS, heapEndW.o);
  HeapEnd := GDVars.gfxReserve;
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
