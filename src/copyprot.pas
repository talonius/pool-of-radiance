{ Translation-wheel challenge, with answer words, rune pairs and path data. }
{$O+,F+}
unit CopyProt;

interface

uses Types, GDConsts, GDVars, Crt, TextRend, Border, C_Rune, GameIo;

{ Give up to three attempts, each with a randomly chosen wheel entry. Return on a correct code word; exit the game after
  the third wrong answer. }
procedure CopyProtection;

implementation

const
  MAX_ATTEMPTS = 3;
  { Game-font offset added to wheel rune values. }
  RUNE_GLYPH_BASE = 64;

procedure CopyProtection;
var
  inputStr: Types.TStr40;
  index: Byte;
  attemptNum: Byte;
begin
  for attemptNum := 1 to CopyProt.MAX_ATTEMPTS do begin
    index := Random(SizeOf(GDConsts.wheel) div SizeOf(Types.TWheelRec));

    Border.DrawWindow(1, 1, 38, 22, 0, Black, '');
    TextRend.DisplayString(1, 1, LightGreen, 'USE THE TRANSLATION WHEEL TO DECIPHER');
    TextRend.DisplayString(1, 2, LightGreen, 'THE CODE WORD.');
    TextRend.DisplayString(1, 5, LightGreen, 'MATCH THE ESPRUAR RUNE (OUTER RING)');

    TextRend.RenderChar(8, 6, LightRed, 1, GDConsts.wheel[index].espruar[1] + CopyProt.RUNE_GLYPH_BASE, 0);
    TextRend.RenderChar(9, 6, LightRed, 1, GDConsts.wheel[index].espruar[2] + CopyProt.RUNE_GLYPH_BASE, 0);

    TextRend.DisplayString(1, 8, LightGreen, 'WITH THE DETHEK RUNE (INNER RING)');

    TextRend.RenderChar(8, 9, LightRed, 1, GDConsts.wheel[index].dethek[1] + CopyProt.RUNE_GLYPH_BASE, 0);

    if GDConsts.wheel[index].dethek[2] <> C_Rune.NONE then
      TextRend.RenderChar(9, 9, LightRed, 1, GDConsts.wheel[index].dethek[2] + CopyProt.RUNE_GLYPH_BASE, 0);

    TextRend.DisplayString(1, 11, LightGreen, 'AND READ THE CODE WORD UNDER THE PATH:');
    TextRend.DisplayString(1, 13, LightRed, '     ' + GDConsts.wheel[index].path);
    TextRend.DisplayString(1, 14, LightGreen, 'READ FROM THE INSIDE TO THE OUTSIDE.');

    GameIo.DiscardPendingKeys;
    inputStr := TextRend.ReadString('INPUT THE CODE WORD: ', LightMagenta, SizeOf(GDConsts.wheel[0].answer) - 1);

    if inputStr = GDConsts.wheel[index].answer then
      Exit;

    TextRend.PrintAndPause('Sorry, that''s incorrect.', Yellow);
  end;

  GameIo.ExitGame;
end;

begin
end.
