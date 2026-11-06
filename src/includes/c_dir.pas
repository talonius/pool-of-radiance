{ Direction indices. }
unit C_Dir;

interface

const
  { Direction indices into dirDx/dirDy; cardinals even, diagonals odd }
  NORTH = 0;
  NORTHEAST = 1;
  EAST = 2;
  SOUTHEAST = 3;
  SOUTH = 4;
  SOUTHWEST = 5;
  WEST = 6;
  NORTHWEST = 7;
  { self / no movement (delta 0,0) }
  CENTER = 8;

implementation

end.
