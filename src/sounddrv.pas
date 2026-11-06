{ PC-speaker and Tandy SN76489 sound controls and clock delays. SoundCommand selects tunes, output gating and optional
  per-command cleanup. SoundSuspend saves the mode and silences the devices; SoundSetAutoStop controls the timer
  driver's lifetime. SOUNDDRV.OBJ owns the timer sequencer, streams and device voice state; GDVars holds the current and
  saved modes and the auto-stop setting. }
{$F+}
unit SoundDrv;

interface

{ Provides the time base for SoundDelay by reading the DOS clock.
  @returns(Clock time in centiseconds. Note: minute times 6000 is computed in Word arithmetic and wraps.) }
function SoundTime: LongInt;

{ Paces sound cleanup without relying on the timer interrupt, which the sound driver may have hooked. Busy-waits
   against SoundTime. Note: a clock discontinuity can prolong the wait.
   @param(centiseconds Number of centiseconds to wait.) }
procedure SoundDelay(centiseconds: Word);

{ Single entry point for sound: mutes or restores output, silences the devices, or starts a tune on whichever device
   is configured. Does nothing when sound is disabled. With auto-stop on, hooks the timer driver first, then waits
   10 centiseconds before silencing both devices and unhooking it.
   @param(cmd 0 silences both devices and disables output, 1 enables output, 255 silences both devices; other values
     select tune cmd minus one for the active device.) }
procedure SoundCommand(cmd: Word);

{ Remembers the configured mode and, unless sound is disabled, hooks the timer driver, silences both devices and
   unhooks it again so the game can leave sound idle. }
procedure SoundSuspend;

{ Chooses between a resident timer driver with persistent playback and per-command cleanup that unhooks the driver
   after each sound.
   @param(autoStop Zero installs the timer; nonzero enables fixed-delay cleanup, and a zero-to-nonzero change
     uninstalls it. When sound is disabled the setting is left unchanged.) }
procedure SoundSetAutoStop(autoStop: Word);

implementation

uses C_Sound, Dos, GDConsts, GDVars;

const
  { SoundCommand selector that turns sound output off. }
  CMD_DISABLE = 0;
  { SoundCommand selector that turns sound output back on. }
  CMD_ENABLE = 1;
  { SoundCommand selector that stops playback and silences both devices. }
  CMD_STOP = 255;
  { Tune id that leaves a device's voices silent. }
  SILENT_TUNE = 0;
  { Value passed to SetSoundOutputEnabled to mute output. }
  OUTPUT_DISABLED = 0;
  { Value passed to SetSoundOutputEnabled to allow output. }
  OUTPUT_ENABLED = 1;

{$L SOUNDDRV.OBJ}
{ Hooks the timer interrupt so the sequencer runs in the background. }
procedure InstallSoundTimer; external;

{ Restores the original timer interrupt and silences both devices. }
procedure UninstallSoundTimer; external;

{ Loads a tune into the PC-speaker voices.
  @param(tuneId Tune to play; SILENT_TUNE silences the voices.) }
procedure ProgramSpeakerVoices(tuneId: Word); external;

{ Loads a tune into the Tandy SN76489 voices.
  @param(tuneId Tune to play; SILENT_TUNE silences the voices.) }
procedure ProgramTandyVoices(tuneId: Word); external;

{ Gates the sound output without disturbing the loaded tune.
  @param(enabledValue OUTPUT_ENABLED or OUTPUT_DISABLED; only the low byte is used.) }
procedure SetSoundOutputEnabled(enabledValue: Word); external;

function SoundTime: LongInt;
var
  hour: Word;
  minute: Word;
  second: Word;
  hundredthSecond: Word;
begin
  GetTime(hour, minute, second, hundredthSecond);
  SoundTime := hour * 360000 + minute * 6000 + second * 100 + hundredthSecond;
end;

procedure SoundDelay(centiseconds: Word);
var target: LongInt;
begin
  target := SoundDrv.SoundTime + centiseconds;
  repeat
  until SoundDrv.SoundTime >= target;
end;

procedure SoundCommand(cmd: Word);
begin
  if GDVars.soundMode = C_Sound.OFF then Exit;
  if GDVars.soundAutoStop > 0 then SoundDrv.InstallSoundTimer;
  case cmd of
    SoundDrv.CMD_DISABLE:
      begin
        SoundDrv.ProgramTandyVoices(SoundDrv.SILENT_TUNE);
        SoundDrv.ProgramSpeakerVoices(SoundDrv.SILENT_TUNE);
        SoundDrv.SetSoundOutputEnabled(SoundDrv.OUTPUT_DISABLED);
      end;
    SoundDrv.CMD_ENABLE: SoundDrv.SetSoundOutputEnabled(SoundDrv.OUTPUT_ENABLED);
    SoundDrv.CMD_STOP: begin
      SoundDrv.ProgramTandyVoices(SoundDrv.SILENT_TUNE);
      SoundDrv.ProgramSpeakerVoices(SoundDrv.SILENT_TUNE);
    end;
  else
    case Char(GDVars.soundMode) of
      Char(C_Sound.SPEAKER): SoundDrv.ProgramSpeakerVoices(cmd - 1);
      Char(C_Sound.TANDY): SoundDrv.ProgramTandyVoices(cmd - 1);
    end;
  end;
  if GDVars.soundAutoStop > 0 then begin
    SoundDrv.SoundDelay(10);
    SoundDrv.ProgramTandyVoices(SoundDrv.SILENT_TUNE);
    SoundDrv.ProgramSpeakerVoices(SoundDrv.SILENT_TUNE);
    SoundDrv.UninstallSoundTimer;
  end;
end;

procedure SoundSuspend;
begin
  GDVars.soundSaved := GDVars.soundMode;
  if GDVars.soundMode = C_Sound.OFF then Exit;
  SoundDrv.InstallSoundTimer;
  SoundDrv.ProgramSpeakerVoices(SoundDrv.SILENT_TUNE);
  SoundDrv.ProgramTandyVoices(SoundDrv.SILENT_TUNE);
  SoundDrv.UninstallSoundTimer;
end;

procedure SoundSetAutoStop(autoStop: Word);
begin
  if GDVars.soundMode = C_Sound.OFF then Exit;
  if autoStop > 0 then begin
    if GDVars.soundAutoStop = 0 then SoundDrv.UninstallSoundTimer;
  end else
    SoundDrv.InstallSoundTimer;
  GDVars.soundAutoStop := autoStop;
end;

begin
end.
