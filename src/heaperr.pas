{ Heap-allocation failure handler. When heapFailureSaveEnabled is nonzero it forces a save before returning to DOS.
  Note: recentSaved is not cleared before the save attempt, so a flag still set from an earlier save ends the loop after
  one attempt. }
{$O+,F+}
unit HeapErr;

interface

uses Crt, GDConsts, GDVars, SaveLoad, TextRend, GameIo;

{ The System.HeapError hook. For a nonzero request it warns that memory is short; when heap-failure saving is enabled it
  makes the player save the game, repeating the save prompt until a save succeeds, and otherwise it reports the failure.
  Then it exits to DOS instead of stopping with a runtime error.
  @param(size Size in bytes of the failed request; a zero request is ignored.)
  @returns(Nothing; the game exits before the result is set. Note: for a zero request the result is never set.) }
function HeapErrorHandler(size: Word): Integer;

implementation

function HeapErrorHandler(size: Word): Integer;
var
  { Loop terminator: set once a save succeeded or saving is disabled. }
  exitFlag: Byte;
begin
  if size > 0 then begin
    exitFlag := 0;

    repeat
      TextRend.DisplayAndPause(Yellow, 'WARNING: Insufficient Memory');
      if GDVars.heapFailureSaveEnabled <> 0 then begin
        { Saving shows the save-game menu. }
        SaveLoad.SaveGame;
        exitFlag := GDVars.recentSaved;
      end else begin
        exitFlag := 1;
        TextRend.DisplayAndPause(Yellow, 'Insufficient Memory. Exiting Program');
      end;
    until exitFlag <> 0;

    GameIo.ExitGame;
  end;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
