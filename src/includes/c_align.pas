{ Alignment values. }
unit C_Align;

interface

const
  { Alignment values (TCharRecord.alignment) in GDConsts.alignNames order: index = law * 3 + morality, with law lawful
    0, neutral 1, chaotic 2 and morality good 0, neutral 1, evil 2. The good values are 0/3/6 and the evil values
    2/5/8. }
  LAWFUL_GOOD = 0;
  CHAOTIC_EVIL = 8;

implementation

end.
