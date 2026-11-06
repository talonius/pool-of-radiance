{ Saving-throw categories. }
unit C_Save;

interface

const
  { Saving-throw categories in AD&D 1e order: indices into TCharRecord.saves and the saveType argument of
    FxEngine.RollSavingThrow }
  { paralyzation / poison / death magic }
  PARALYZATION = 0;
  { petrification / polymorph }
  PETRIFICATION = 1;
  { breath weapon }
  BREATH_WEAPON = 3;
  { spell }
  SPELL = 4;

implementation

end.
