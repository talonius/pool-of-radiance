{ STING hit-point debug display. GameIo toggles its flag on Ctrl-D when the first command-line argument is STING. }
{$O+,F+}
unit Debug;

interface

uses Types, Crt, GDConsts, GDVars, TextRend;

{ Shows three hit-point values across the top row and pauses on a message, while the STING hit-point display is on; the
  top row is cleared again afterwards.
  @param(msg The message to pause on.)
  @param(maximumHitPoints The first value shown.)
  @param(currentHitPoints The second value shown.)
  @param(drainedHitPoints The third value shown.) }
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
