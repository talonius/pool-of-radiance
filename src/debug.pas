{ STING hit-point debug display. GameIo toggles its flag on Ctrl-D when the first command-line argument is STING. }
{$O+,F+}
unit Debug;

interface

uses Types, Crt, GDConsts, GDVars, TextRend;

{ While the debug display is on, shows three numbers on the top text row, pauses on a message, and clears the row again;
  otherwise does nothing.
  @param(msg The message shown with the pause.)
  @param(maximumHitPoints The first number shown.)
  @param(currentHitPoints The second number shown.)
  @param(drainedHitPoints The third number shown.) }
procedure PrintDebug(msg: Types.TStr40; maximumHitPoints, currentHitPoints, drainedHitPoints: Byte);

implementation

procedure PrintDebug(msg: Types.TStr40; maximumHitPoints, currentHitPoints, drainedHitPoints: Byte);
var
  maxText: String;
  curText: String;
  drainedText: String;
begin
  if GDVars.stingHpFlag <> 0 then begin
    Str(maximumHitPoints, maxText);
    Str(currentHitPoints, curText);
    Str(drainedHitPoints, drainedText);
    { columns 0..39: the whole row, wider than the TEXT_RIGHT window }
    TextRend.ClearRect(0, 0, 39, 0);
    TextRend.DisplayString(0, 0, Yellow, maxText + ' , ' + curText + ' , ' + drainedText);
    TextRend.DisplayAndPause(Yellow, msg);
    TextRend.ClearRect(0, 0, 39, 0);
  end;
end;

begin
end.
