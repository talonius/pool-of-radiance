{ Keyboard polling, control-key handling, sound toggling and return to DOS. }
{$F+}
unit GameIo;

interface

uses C_Sound, GDConsts, GDVars, Crt, Dos, SoundDrv;

{ Reads a key and acts on the control keys in its first byte: Ctrl-S toggles the sound, and when the first command-line
  argument is STING, Ctrl-D toggles the hit-point display and Ctrl-C exits to DOS. After a nonzero byte it drains the
  pending input without acting on those controls again. An initial zero is returned at once, leaving the extended scan
  byte pending.
  @returns(The last byte read.) }
function ReadGameKey: Char;

{ Disabled: return at once without polling the keyboard. The polling loop is kept but unreachable. }
procedure DiscardPendingKeys;

{ If input is pending, call ReadGameKey once and discard its result. That call may consume several bytes or leave an
  extended scan byte pending. }
procedure PollGameKeys;

{ Restore the saved sound mode, send the stop command, set the saved video mode through the BIOS and exit to DOS. }
procedure ExitGame;

implementation

procedure ExitGame;
begin
  GDVars.soundMode := GDVars.soundSaved;
  SoundDrv.SoundCommand(GDConsts.soundIds.commands[0]);
  GDVars.interruptRegs.ah := 0;
  GDVars.interruptRegs.al := GDVars.savedVideoMode;
  Intr($10, Registers(GDVars.interruptRegs));
  Halt(0);
end;

function ReadGameKey: Char;
var
  key: Char;
begin
  key := ReadKey;
  { Ctrl-S toggles sound; a cached extended scan code of 19 (Alt-R) also matches }
  if key = #19 then
    if GDVars.soundMode <> C_Sound.OFF then begin
      GDVars.soundSaved := GDVars.soundMode;
      SoundDrv.SoundCommand(GDConsts.soundIds.commands[0]);
      GDVars.soundMode := C_Sound.OFF;
    end else begin
      if GDVars.soundSaved in [C_Sound.TANDY, C_Sound.SPEAKER] then begin
        GDVars.soundMode := GDVars.soundSaved;
        SoundDrv.SoundSuspend;
      end;
    end;
  if ParamStr(1) = 'STING' then begin
    if key = #4 then GDVars.stingHpFlag := Ord(GDVars.stingHpFlag = 0);
    if key = #3 then GameIo.ExitGame;
  end;
  if key <> #0 then
    while KeyPressed do
      key := ReadKey;
  ReadGameKey := key;
end;

procedure DiscardPendingKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  { Polling is disabled; the loop below is unreachable. }
  Exit;
  while KeyPressed do
    key := GameIo.ReadGameKey;
end;

procedure PollGameKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  if KeyPressed then
    key := GameIo.ReadGameKey;
end;

begin
end.
