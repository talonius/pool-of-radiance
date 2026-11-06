{ PC-speaker and Tandy SN76489 music controls. The assembly driver runs the sequencer from the timer interrupt. }
{$F+}
unit SoundDrv;

interface

{ Single entry point for sound: mutes or restores output, shuts the driver down, or starts a tune on whichever device
   is configured. Does nothing when sound is disabled. Disable starts the step sound with output muted, waits 50 ms,
   then enables output; stop starts the step sound, waits 30 ms, then restores the timer vector and silences both
   devices.
   @param(cmd 0 disables, 1 enables, 255 stops; other values select tune cmd minus one for the configured device.) }
procedure SoundCommand(cmd: Word);

{ Remembers the configured mode and, unless sound is disabled, starts the timer driver so playback can resume
   later. }
procedure SoundSuspend;

implementation

uses Crt, GDConsts, GDVars, C_Sound;

const
  { SoundCommand selector that turns sound output off. }
  CMD_DISABLE = 0;
  { SoundCommand selector that turns sound output back on. }
  CMD_ENABLE = 1;
  { SoundCommand selector that stops playback and shuts the driver down. }
  CMD_STOP = 255;
  { Value passed to SetSoundOutputEnabled to mute output. }
  OUTPUT_DISABLED = 0;
  { Value passed to SetSoundOutputEnabled to allow output. }
  OUTPUT_ENABLED = 1;

{$L SOUNDDRV.OBJ}
{ Installs the driver's timer interrupt handler, saving the old one, and speeds up the timer. }
procedure InstallSoundTimer; external;

{ Restores the old timer interrupt handler and the BIOS timer rate, and silences both banks of voices. }
procedure UninstallSoundTimer; external;

{ Starts a sound on the PC-speaker voices; sound 0 silences them.
  @param(tuneId The sound number.) }
procedure ProgramSpeakerVoices(tuneId: Word); external;

{ Starts a sound on the Tandy voices; sound 0 silences them.
  @param(tuneId The sound number.) }
procedure ProgramTandyVoices(tuneId: Word); external;

{ Gates the sound output without disturbing the loaded tune.
  @param(enabledValue OUTPUT_ENABLED or OUTPUT_DISABLED; only the low byte is used.) }
procedure SetSoundOutputEnabled(enabledValue: Word); external;

procedure SoundCommand(cmd: Word);
begin
  if GDVars.soundMode = C_Sound.OFF then Exit;
  case cmd of
    SoundDrv.CMD_DISABLE: begin
            SoundDrv.SetSoundOutputEnabled(SoundDrv.OUTPUT_DISABLED);
            SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
            Delay(50);
            SoundDrv.SetSoundOutputEnabled(SoundDrv.OUTPUT_ENABLED);
          end;
    SoundDrv.CMD_ENABLE: SoundDrv.SetSoundOutputEnabled(SoundDrv.OUTPUT_ENABLED);
    SoundDrv.CMD_STOP: begin
            SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
            Delay(30);
            SoundDrv.UninstallSoundTimer;
          end;
  else
    case Char(GDVars.soundMode) of
      Char(C_Sound.SPEAKER): SoundDrv.ProgramSpeakerVoices(cmd - 1);
      Char(C_Sound.TANDY): SoundDrv.ProgramTandyVoices(cmd - 1);
    end;
  end;
end;

procedure SoundSuspend;
begin
  GDVars.soundSaved := GDVars.soundMode;
  if GDVars.soundMode = C_Sound.OFF then Exit;
  SoundDrv.InstallSoundTimer;
end;

begin
end.
