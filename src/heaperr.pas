{ Heap-allocation failure handler. Forces a save before returning to DOS. Note: recentSaved is not cleared before the
  save attempt, so a flag still set from an earlier save ends the loop after one attempt. }
{$O+,F+}
unit HeapErr;

interface

uses Crt, GDConsts, GDVars, TextRend, GameIo, SaveLoad;

{ The System.HeapError hook: a failed heap allocation makes the player save the game, repeating the save prompt until a
  save succeeds, and then exits to DOS instead of stopping with a runtime error.
  @param(size Unused.)
  @returns(Nothing; the game exits before the result is set.) }
function HeapErrorHandler(size: Word): Integer;

implementation

function HeapErrorHandler(size: Word): Integer;
begin
  repeat
    TextRend.DisplayAndPause(Yellow, 'Time to save your game.  [return]');
    SaveLoad.SaveGame;
  until GDVars.recentSaved <> 0;

  GameIo.ExitGame;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
