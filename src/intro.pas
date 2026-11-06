{ Introduction, credits and title screens, with delays that can be interrupted by a keypress. }
{$O+,F+}
unit Intro;

interface

uses Types, GDConsts, GDVars, Crt, GameIo, TextRend, Blit, Border, Video, SoundDrv, C_Sound;

{ Shows the title: title picture 1 for 5 seconds or until a key, with the game directory blanked while it loads. With
  the full intro it goes on to title picture 2 for another 5 seconds or until a key, on EGA flashing palette register 1
  at random, and then the credits. Sound command 0 is sent at the start, before an early exit and before the credits;
  with Tandy sound the title theme also plays. }
procedure Introduction;

implementation

const
  { Sound-effect id }
  SND_TITLE_THEME = 9;

{ Waits for a number of seconds or a keypress, whichever comes first, then discards pending keys.
  @param(seconds How long to wait.) }
procedure DelayOrKey(seconds: Word);
var
  start: LongInt;
  deadline: LongInt;
begin
  start := TextRend.GetTicks;
  deadline := start + 100 * seconds;
  repeat
  until (TextRend.GetTicks >= deadline) or KeyPressed;
  GameIo.DiscardPendingKeys;
end;

{ Shows the credits screen for 10 seconds or until a keypress. }
procedure Credits;
begin
  Border.DrawWindow(1, 1, 38, 3, 0, Black, '');
  Border.DrawWindow(1, 5, 38, 23, 0, Black, '');
  TextRend.DisplayString(5, 1, LightGreen, 'scenario created by:');
  TextRend.DisplayString(26, 1, Yellow, 'tsr, inc.');
  TextRend.DisplayString(15, 2, LightGreen, 'jim ward');
  TextRend.DisplayString(2, 3, LightGreen, 'david cook,steve winter,mike breault');
  TextRend.DisplayString(1, 5, LightGreen, 'game created by:');
  TextRend.DisplayString(18, 5, Yellow, 'ssi special projects');
  TextRend.DisplayString(2, 7, Yellow, 'programming:');
  TextRend.DisplayString(20, 7, Yellow, 'original');
  TextRend.DisplayString(2, 8, LightCyan, 'scot bayless');
  TextRend.DisplayString(20, 8, Yellow, 'programming:');
  TextRend.DisplayString(2, 9, LightCyan, 'brad myers');
  TextRend.DisplayString(20, 9, LightCyan, 'keith brors');
  TextRend.DisplayString(2, 10, LightCyan, 'russ brown');
  TextRend.DisplayString(20, 10, LightCyan, 'brad myers');
  TextRend.DisplayString(2, 11, LightCyan, 'ted greer');
  TextRend.DisplayString(2, 13, Yellow, 'graphic arts:');
  TextRend.DisplayString(20, 13, Yellow, 'encounter coding:');
  TextRend.DisplayString(2, 14, LightCyan, 'tom wahl');
  TextRend.DisplayString(20, 14, LightCyan, 'paul murray');
  TextRend.DisplayString(2, 15, LightCyan, 'fred butts');
  TextRend.DisplayString(20, 15, LightCyan, 'russ brown');
  TextRend.DisplayString(2, 16, LightCyan, 'darla marasco');
  TextRend.DisplayString(20, 16, LightCyan, 'victor penman');
  TextRend.DisplayString(2, 17, LightCyan, 'susan halbleib');
  TextRend.DisplayString(20, 17, LightCyan, 'dave shelley');
  TextRend.DisplayString(2, 19, Yellow, 'project manager');
  TextRend.DisplayString(20, 19, Yellow, 'developer:');
  TextRend.DisplayString(2, 20, LightCyan, 'victor penman');
  TextRend.DisplayString(20, 20, LightCyan, 'george mac donald');
  TextRend.DisplayString(2, 22, Yellow, 'testing:');
  TextRend.DisplayString(11, 22, LightCyan, 'joel billings,steve salyer');
  TextRend.DisplayString(2, 23, LightCyan, 'james kucera,robert daly,rick white');
  Intro.DelayOrKey(10);
end;

procedure Introduction;
var
  pic: Types.PImgBuf;
  rndAcc: LongInt;
  i: Byte;
  savedDir: String[40];
  deadline: LongInt;
begin
  rndAcc := 0;
  pic := nil;
  SoundDrv.SoundCommand(GDConsts.soundIds.commands[1]);
  if GDVars.soundMode = C_Sound.TANDY then
    SoundDrv.SoundCommand(GDConsts.soundIds.combat[Intro.SND_TITLE_THEME]);
  savedDir := GDVars.gameDir;
  GDVars.gameDir[0] := #0;
  Blit.LoadPic('title', 1, False, 0, pic);
  Blit.ShowPic(0, 0, pic);
  Intro.DelayOrKey(5);
  if not GDVars.fullIntro then begin
    SoundDrv.SoundCommand(GDConsts.soundIds.commands[1]);
    GDVars.gameDir := savedDir;
    Exit;
  end;
  Blit.LoadPic('title', 2, False, 0, pic);
  GDVars.gameDir := savedDir;
  Blit.ShowPic(0, 0, pic);
  Blit.FreePic(pic);
  deadline := TextRend.GetTicks + 500;
  repeat
    if GDVars.videoMode = Types.Ega then begin
      Inc(rndAcc, Random(4));
      if rndAcc > 50000 then begin
        rndAcc := 0;
        for i := 0 to Random(3) + 1 do begin
          Video.SetPaletteRegister(1, LightBlue);
          Delay(150);
          Video.SetPaletteRegister(1, LightCyan);
          Delay(100);
          Video.SetPaletteRegister(1, White);
          Delay(50);
          Video.SetPaletteRegister(1, LightCyan);
          Delay(100);
          Video.SetPaletteRegister(1, LightBlue);
          Delay(150);
          Video.SetPaletteRegister(1, Blue);
        end;
      end;
    end;
  until KeyPressed or (TextRend.GetTicks >= deadline);
  GameIo.DiscardPendingKeys;
  SoundDrv.SoundCommand(GDConsts.soundIds.commands[1]);
  Intro.Credits;
end;

begin
end.
