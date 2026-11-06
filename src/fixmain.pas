{ Program entry: initialize the game, show the introduction and translation-wheel challenge, run CharGen's main menu,
  then run the game loop and shut down. }
{$F+}
{$M 8192,65536,655360}
program FixMain;

uses Types,
  Overlay, Crt, Dos, EmptyC, EmptyA,
  GDConsts, GDVars,
  Video, SoundDrv, GameIo, DaxIo, GameBoot, TextRend, Blit, Sym8x8, Border, Debug, EmptyB, MapTiles,
  CbtMap, Pathing, View3D, Portrait, Wilds, MapView, MenuCore, CharHlp, FxEngine, ClassCal, Magic,
  Money, GameTime, ViewChar, Ending, SaveLoad, CharGen, Camp, Explore, CbtActs, EffHndlr, GameInit, CombatSt,
  CombatAi, Combat, EclMenu, Shop, PostCbt, Temple, EclVm, CopyProt, Intro, HeapErr;

{$O HeapErr}
{$O Intro}
{$O CopyProt}
{$O EclVm}
{$O Temple}
{$O PostCbt}
{$O Shop}
{$O EclMenu}
{$O Combat}
{$O CombatAi}
{$O CombatSt}
{$O GameInit}
{$O EffHndlr}
{$O CbtActs}
{$O Explore}
{$O Camp}
{$O CharGen}
{$O SaveLoad}
{$O Ending}
{$O ViewChar}
{$O GameTime}
{$O Money}
{$O Magic}
{$O ClassCal}
{$O FxEngine}
{$O CharHlp}
{$O MenuCore}
{$O MapView}
{$O Wilds}
{$O Portrait}
{$O View3D}
{$O Pathing}
{$O CbtMap}
{$O MapTiles}
{$O Debug}
{$O Sym8x8}
{$O Blit}
{$O TextRend}

begin
  GameInit.InitializeGame;
  { STING skips the introduction and translation-wheel challenge }
  if ParamStr(1) <> 'STING' then
  begin
    Intro.Introduction;
    CopyProt.CopyProtection;
  end;
  CharGen.MainMenu;
  View3D.SetView3DColors(LightCyan, Black, LightGray, Brown);
  EclVm.GameLoop;
  GameIo.ExitGame;
end.
