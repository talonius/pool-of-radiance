{ Game data, part 2 of 5: the ITEMS catalogue. One section per subsystem, and a new section after each word-rounding
  pad. }
unit GameDat2;

interface

uses Types;

var
  { ITEMS catalogue }
  { Base item types, indexed by TItemRec.itemType. }
  baseItems: array[0..127] of Types.TBaseItemRec;
  { Unused; the ITEMS read takes 129 records, and the last one lands here. }
  baseItemsOverflow: Types.TBaseItemRec;

implementation

end.
