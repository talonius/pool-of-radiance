{ Game data, part 3 of 5: party pointers, graphics sets, combat arena, effects, 3D view, map, portraits, menus, spells
  and rest, one section per subsystem. }
unit GameDat3;

interface

uses Types, C_Effect, C_Dir, C_Money;

const
  { Symbol-set ranges }
  symSetFirst: array[0..4] of Word = (1, 46, 116, 186, 256);
  symSetLast: array[0..4] of Word = (45, 115, 185, 255, 286);

const
  { Direction steps, combat terrain, icon footprints, helpless effects }
  dirDX: array[C_Dir.DIR_NORTH..C_Dir.DIR_CENTER] of ShortInt = (
    0, 1, 1, 1, 0, -1, -1, -1, 0);
  dirDY: array[C_Dir.DIR_NORTH..C_Dir.DIR_CENTER] of ShortInt = (
    -1, -1, 0, 1, 1, 1, 0, -1, 0);
  { Combat terrain by arena cell value: movement cost (255 = impassable), line-walk clearance and blocking, and the
    combat tile graphic }
  terrainInfo: array[1..65] of Types.TTerrainRec = (
    (cost: 255; clearance: 0; blocking: 2; tileId: 0),
    (cost: 255; clearance: 0; blocking: 2; tileId: 1),
    (cost: 255; clearance: 0; blocking: 2; tileId: 2),
    (cost: 255; clearance: 0; blocking: 2; tileId: 3),
    (cost: 1; clearance: 0; blocking: 0; tileId: 4),
    (cost: 255; clearance: 0; blocking: 2; tileId: 5),
    (cost: 255; clearance: 0; blocking: 2; tileId: 6),
    (cost: 255; clearance: 0; blocking: 2; tileId: 7),
    (cost: 1; clearance: 0; blocking: 0; tileId: 8),
    (cost: 255; clearance: 0; blocking: 2; tileId: 9),
    (cost: 1; clearance: 0; blocking: 0; tileId: 10),
    (cost: 255; clearance: 0; blocking: 2; tileId: 11),
    (cost: 1; clearance: 0; blocking: 0; tileId: 12),
    (cost: 255; clearance: 0; blocking: 2; tileId: 13),
    (cost: 1; clearance: 0; blocking: 0; tileId: 14),
    (cost: 255; clearance: 0; blocking: 2; tileId: 15),
    (cost: 1; clearance: 0; blocking: 0; tileId: 16),
    (cost: 255; clearance: 0; blocking: 2; tileId: 17),
    (cost: 255; clearance: 0; blocking: 2; tileId: 18),
    (cost: 255; clearance: 0; blocking: 2; tileId: 19),
    (cost: 255; clearance: 0; blocking: 2; tileId: 20),
    (cost: 255; clearance: 0; blocking: 2; tileId: 21),
    (cost: 1; clearance: 0; blocking: 0; tileId: 22),
    (cost: 1; clearance: 0; blocking: 0; tileId: 23),
    (cost: 255; clearance: 0; blocking: 2; tileId: 24),
    (cost: 1; clearance: 0; blocking: 0; tileId: 34),
    (cost: 1; clearance: 0; blocking: 0; tileId: 35),
    (cost: 1; clearance: 0; blocking: 0; tileId: 36),
    (cost: 1; clearance: 0; blocking: 0; tileId: 37),
    (cost: 1; clearance: 0; blocking: 0; tileId: 38),
    (cost: 1; clearance: 0; blocking: 0; tileId: 39),
    (cost: 255; clearance: 0; blocking: 2; tileId: 0),
    (cost: 255; clearance: 0; blocking: 2; tileId: 1),
    (cost: 255; clearance: 0; blocking: 2; tileId: 2),
    (cost: 255; clearance: 0; blocking: 2; tileId: 3),
    (cost: 1; clearance: 0; blocking: 0; tileId: 4),
    (cost: 1; clearance: 0; blocking: 0; tileId: 5),
    (cost: 1; clearance: 0; blocking: 0; tileId: 6),
    (cost: 1; clearance: 0; blocking: 0; tileId: 7),
    (cost: 255; clearance: 0; blocking: 0; tileId: 8),
    (cost: 255; clearance: 0; blocking: 0; tileId: 9),
    (cost: 1; clearance: 0; blocking: 0; tileId: 10),
    (cost: 1; clearance: 0; blocking: 0; tileId: 11),
    (cost: 1; clearance: 0; blocking: 0; tileId: 12),
    (cost: 1; clearance: 0; blocking: 0; tileId: 13),
    (cost: 1; clearance: 0; blocking: 0; tileId: 14),
    (cost: 1; clearance: 0; blocking: 0; tileId: 15),
    (cost: 1; clearance: 0; blocking: 0; tileId: 16),
    (cost: 1; clearance: 0; blocking: 0; tileId: 17),
    (cost: 255; clearance: 0; blocking: 0; tileId: 18),
    (cost: 255; clearance: 0; blocking: 0; tileId: 19),
    (cost: 1; clearance: 0; blocking: 0; tileId: 20),
    (cost: 1; clearance: 0; blocking: 0; tileId: 21),
    (cost: 1; clearance: 0; blocking: 0; tileId: 22),
    (cost: 255; clearance: 0; blocking: 0; tileId: 23),
    (cost: 255; clearance: 0; blocking: 0; tileId: 24),
    (cost: 1; clearance: 0; blocking: 0; tileId: 25),
    (cost: 1; clearance: 0; blocking: 0; tileId: 26),
    (cost: 1; clearance: 0; blocking: 0; tileId: 27),
    (cost: 255; clearance: 0; blocking: 0; tileId: 28),
    (cost: 255; clearance: 0; blocking: 2; tileId: 29),
    (cost: 255; clearance: 0; blocking: 2; tileId: 30),
    (cost: 255; clearance: 0; blocking: 2; tileId: 31),
    (cost: 1; clearance: 0; blocking: 0; tileId: 32),
    (cost: 255; clearance: 0; blocking: 2; tileId: 33));
  { Footprint cells of an icon, by icon size and cell; a negative dx marks an absent cell }
  iconDelta: array[1..4, 0..3] of Types.TIconCoordinateDelta = (
    ((dx: 0; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 0; dy: 1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1), (dx: 1; dy: 1)));
  { Effects that leave a creature helpless: Snake Charm, Paralysis, Sleep, Helpless }
  helplessFx: array[1..4] of Byte = (51, 52, 53, 31);

const
  { Portrait head and body tables }
  { portraitHead -> HEAD DAX ID }
  headTbl: array[1..14] of Byte = (
    0, 8, 9, 13, 16, 18, 22, 34, 45, 51, 53, 57, 67, 68);
  { portraitBody -> BODY DAX ID }
  bodyTbl: array[1..12] of Byte = (
    1, 2, 3, 4, 7, 8, 18, 24, 26, 33, 35, 37);

const
  { Menu key and aim-vector tables }
  { keypad digits 1..9 to scan codes; MenuCore indexes Ord(ch) - Ord('1') }
  keypadScan: array[0..8] of Byte = (
    79, 80, 81, 75, 32, 77, 71, 72, 73);

const
  { Cloud directions, spell names and spell table }
  { direction indices: center, E, SE, S }
  cloudDir: array[1..4] of Byte = (
    8, 2, 3, 4);
  { spell IDs 1..56 }
  spellNames: array[1..56] of string[40] = (
    'Bless',
    'Curse',
    'Cure Light Wounds',
    'Cause Light Wounds',
    'Detect Magic',
    'Protection From Evil',
    'Protection from Good',
    'Resist Cold',
    'Burning Hands',
    'Charm Person',
    'Detect Magic',
    'Enlarge',
    'Reduce',
    'Friends',
    'Magic Missile',
    'Protection From Evil',
    'Protection From Good',
    'Read Magic',
    'Shield',
    'Shocking Grasp',
    'Sleep',
    'Find Traps',
    'Hold Person',
    'Resist Fire',
    'Silence, 15'' Radius',
    'Slow Poison',
    'Snake Charm',
    'Spiritual Hammer',
    'Detect Invisibility',
    'Invisibility',
    'Knock',
    'Mirror Image',
    'Ray of Enfeeblement',
    'Stinking Cloud',
    'Strength',
    'Animate Dead',
    'Cure Blindness',
    'Cause Blindness',
    'Cure Disease',
    'Cause Disease',
    'Dispel Magic',
    'Prayer',
    'Remove Curse',
    'Bestow Curse',
    'Blink',
    'Dispel Magic',
    'Fireball',
    'Haste',
    'Hold Person',
    'Invisibility, 10'' Radius',
    'Lightning Bolt',
    'Protection From Evil, 10'' Radius',
    'Protection From Good, 10'' Radius',
    'Protection From Normal Missiles',
    'Slow',
    'Restoration');
  { IDs 57..67 are item effects }
  spellTable: array[1..67] of Types.TSpellRec = (
    { Spell 1: Bless }
    (castClass: 0; level: 1; rangeFixed: 6; rangeVar: 0;
     durFixed: 6; durVar: 0; area: 10; target: 4;
     saveResult: 0; saveType: 4; effect: 1; whenCast: 2;
     castTime: 10; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 2: Curse }
    (castClass: 0; level: 1; rangeFixed: 6; rangeVar: 0;
     durFixed: 6; durVar: 0; area: 10; target: 0;
     saveResult: 0; saveType: 4; effect: 2; whenCast: 1;
     castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { Spell 3: Cure Light Wounds }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 4: Cause Light Wounds }
    (castClass: 0; level: 1; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 5; aiPriority: 2; offensive: 1; aiRadius: 0),
    { Spell 5: Detect Magic }
    (castClass: 0; level: 1; rangeFixed: 3; rangeVar: 0;
     durFixed: 10; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 5; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 6: Protection From Evil }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 3; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 8; whenCast: 2;
     castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 7: Protection from Good }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 3; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 9; whenCast: 2;
     castTime: 4; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 8: Resist Cold }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 10; whenCast: 2;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 9: Burning Hands }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 10: Charm Person }
    (castClass: 1; level: 1; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 11; whenCast: 1;
     castTime: 1; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 11: Detect Magic }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 5; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 12: Enlarge }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 2;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 12; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 13: Reduce }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 2;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 1; saveType: 4; effect: 13; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { Spell 14: Friends }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 14; whenCast: 0;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 15: Magic Missile }
    (castClass: 1; level: 1; rangeFixed: 6; rangeVar: 4;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 16: Protection From Evil }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 8; whenCast: 2;
     castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 17: Protection From Good }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 9; whenCast: 2;
     castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 18: Read Magic }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 16; whenCast: 0;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 19: Shield }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 5; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 17; whenCast: 2;
     castTime: 1; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 20: Shocking Grasp }
    (castClass: 1; level: 1; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 21: Sleep }
    (castClass: 1; level: 1; rangeFixed: 3; rangeVar: 4;
     durFixed: 0; durVar: 5; area: 9; target: 0;
     saveResult: 0; saveType: 4; effect: 53; whenCast: 1;
     castTime: 1; aiPriority: 7; offensive: 1; aiRadius: 1),
    { Spell 22: Find Traps }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 30; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 19; whenCast: 0;
     castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 23: Hold Person }
    (castClass: 0; level: 2; rangeFixed: 6; rangeVar: 0;
     durFixed: 4; durVar: 1; area: 6; target: 0;
     saveResult: 1; saveType: 4; effect: 52; whenCast: 1;
     castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 24: Resist Fire }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 20; whenCast: 2;
     castTime: 5; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 25: Silence, 15' Radius }
    (castClass: 0; level: 2; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 31; target: 0;
     saveResult: 3; saveType: 4; effect: 21; whenCast: 1;
     castTime: 5; aiPriority: 4; offensive: 1; aiRadius: 1),
    { Spell 26: Slow Poison }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 60; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 22; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 27: Snake Charm }
    (castClass: 0; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 240; target: 0;
     saveResult: 0; saveType: 4; effect: 51; whenCast: 1;
     castTime: 5; aiPriority: 0; offensive: 1; aiRadius: 0),
    { Spell 28: Spiritual Hammer }
    (castClass: 0; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 23; whenCast: 2;
     castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 29: Detect Invisibility }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 4;
     durFixed: 0; durVar: 5; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 24; whenCast: 2;
     castTime: 2; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 30: Invisibility }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 25; whenCast: 2;
     castTime: 2; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 31: Knock }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 0;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 32: Mirror Image }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 28; whenCast: 2;
     castTime: 2; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 33: Ray of Enfeeblement }
    (castClass: 1; level: 2; rangeFixed: 1; rangeVar: 1;
     durFixed: 0; durVar: 1; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 29; whenCast: 1;
     castTime: 2; aiPriority: 2; offensive: 1; aiRadius: 0),
    { Spell 34: Stinking Cloud }
    (castClass: 1; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 9; target: 0;
     saveResult: 3; saveType: 0; effect: 30; whenCast: 1;
     castTime: 2; aiPriority: 7; offensive: 1; aiRadius: 1),
    { Spell 35: Strength }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 60; area: 0; target: 2;
     saveResult: 0; saveType: 4; effect: 38; whenCast: 0;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 36: Animate Dead }
    (castClass: 0; level: 3; rangeFixed: 1; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 240; target: 4;
     saveResult: 0; saveType: 4; effect: 32; whenCast: 2;
     castTime: 10; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 37: Cure Blindness }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 38: Cause Blindness }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 33; whenCast: 1;
     castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { Spell 39: Cure Disease }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 0;
     castTime: 100; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 40: Cause Disease }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 34; whenCast: 1;
     castTime: 100; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 41: Dispel Magic }
    (castClass: 0; level: 3; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 9; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 4; aiPriority: 5; offensive: 1; aiRadius: 1),
    { Spell 42: Prayer }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 49; whenCast: 2;
     castTime: 6; aiPriority: 6; offensive: 0; aiRadius: 0),
    { Spell 43: Remove Curse }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 44: Bestow Curse }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 36; whenCast: 1;
     castTime: 6; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 45: Blink }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 37; whenCast: 1;
     castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 46: Dispel Magic }
    (castClass: 1; level: 3; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 9; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 3; aiPriority: 2; offensive: 1; aiRadius: 1),
    { Spell 47: Fireball }
    (castClass: 1; level: 3; rangeFixed: 10; rangeVar: 1;
     durFixed: 0; durVar: 0; area: 11; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 3),
    { Spell 48: Haste }
    (castClass: 1; level: 3; rangeFixed: 6; rangeVar: 0;
     durFixed: 3; durVar: 1; area: 10; target: 4;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 49: Hold Person }
    (castClass: 1; level: 3; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 7; target: 0;
     saveResult: 1; saveType: 4; effect: 52; whenCast: 1;
     castTime: 3; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 50: Invisibility, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 9; target: 4;
     saveResult: 0; saveType: 4; effect: 25; whenCast: 2;
     castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 51: Lightning Bolt }
    (castClass: 1; level: 3; rangeFixed: 4; rangeVar: 1;
     durFixed: 0; durVar: 0; area: 8; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 52: Protection From Evil, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 45; whenCast: 2;
     castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 53: Protection From Good, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 46; whenCast: 2;
     castTime: 3; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 54: Protection From Normal Missiles }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 41; whenCast: 2;
     castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 55: Slow }
    (castClass: 1; level: 3; rangeFixed: 9; rangeVar: 1;
     durFixed: 3; durVar: 1; area: 10; target: 0;
     saveResult: 0; saveType: 4; effect: 42; whenCast: 1;
     castTime: 3; aiPriority: 5; offensive: 1; aiRadius: 0),
    { Spell 56: Restoration }
    (castClass: 0; level: 7; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 57 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 0; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 58 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 59 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 38; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 60 }
    (castClass: 2; level: 6; rangeFixed: 4; rangeVar: 4;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 61 }
    (castClass: 2; level: 6; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 0; effect: 52; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 62 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 63 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 7; target: 4;
     saveResult: 0; saveType: 4; effect: 71; whenCast: 2;
     castTime: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 64 }
    (castClass: 2; level: 6; rangeFixed: 7; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 11; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 3),
    { Spell 65 }
    (castClass: 2; level: 6; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 66 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 67 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 4; whenCast: 0;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0));

const
  { Rest time units }
  unitScale: array[0..6] of Word = (
    { segment, minute, turn, hour, day, month, year }
    10, 10, 6, 24, 30, 12, 256);

var
  { Party pointers }
  { Current creature. }
  curChar: Types.PCharRecord;
  { Pointer to linked list of creatures }
  creatureList: Types.PCharRecord;
  { last missile item added to the treasure list in combat }
  lastMissileItem: Types.PItemRec;

var
  { Scratch file and ITEMS read result }
  scratchFile: file;
  { ITEMS read result. }
  itemsRead: Word;

var
  { Font and text cursor }
  { Pointer to font. Each entry in the font table is 8 bytes }
  gameFont: Types.PFontArr;
  { Text cursor shared by TextRend's message window and slow-text output }
  { Current char column. (Equivalent of WhereX.) }
  curCol: Byte;
  { Current char row. (Equivalent of WhereY.) }
  curRow: Byte;
  { unused }
  dsUnidentified58: array[0..19] of Byte;

var
  { Symbol sets and map tile sets }
  { the five 8x8 symbol-set images, by set id 0..4: Sym8x8.Load8x8Set loads an 8X8D picture into a slot and Put8x8Sym
    draws from it }
  dsSymbolSetPtrs: array[0..4] of Types.PImgBuf;
  { Pointer to current 8x8 symbol image buffer }
  dsCurrent8x8SymbolPtr2: Types.PImgBuf;
  { 2D map tile set image buffer 1 }
  ds2dMapTilePtr: Types.PImgBuf;
  { 2D map tile set image buffer 2; bit 7 of a tile id selects it }
  ds2dMapTilePtr2: Types.PImgBuf;

var
  { Icon images }
  { Animation images for creature, death and cursor icons. }
  dsIconAnimation: array[0..25, 0..1] of Pointer;

var
  { Combat arena }
  { next registration slot, inclusive scan limit }
  arenaCount: Byte;
  { icon location and size per slot }
  arenaLoc: array[1..72] of Types.TArenaLoc;
  { view-relative X deltas }
  gridX: array[1..72] of ShortInt;
  { view-relative Y deltas }
  gridY: array[1..72] of ShortInt;
  { creature slot per arena cell }
  crIdxArr: array[0..24, 0..49] of Byte;
  { creature per slot }
  creatureArr: array[1..72] of Types.PCharRecord;
  { corpses on the arena }
  downed: array[1..8] of Types.TDownedRec;
  { append and scan limit; cleared entries leave holes }
  downedCount: Byte;
  { allocated combat viewport, borrowed by renderers }
  arenaPtr: Types.PArena;
  { Pathing's potential-target count }
  targetCount: Byte;
  { sorted by distance and facing }
  targetList: array[1..72] of Types.TCombatTarget;

var
  { Treasure }
  { copper through jewelry }
  treasureMoney: array[C_Money.MONEY_COPPER..C_Money.MONEY_JEWELRY] of LongInt;
  { consumers use PItemRec views }
  treasureItems: Types.PItemRec;

var
  { Combatants per side }
  { combat ends when a side is empty }
  teamCount: array[0..1] of Byte;

var
  { Effect resolution }
  { modified saving-throw roll }
  gSaveRoll: Byte;
  { effect ID, cleared when immune }
  pendingEffectId: Byte;
  { damage before hit-point subtraction }
  pendingDamage: Byte;
  { 1 fire, 2 cold, 4 electricity, 8 magic, 16 acid }
  elementMask: Byte;
  { current attack *or* current movement times 2 }
  dsCurrentAttackCurrent: Byte;
  { spell being cast }
  dsCurrentSpellBeing: Byte;
  { dice count of the current damage roll }
  gDamageDice: Byte;
  { 1 while calculating movement }
  dsCurrentCreatureCalculatingFlag: Byte;
  { suppress targeting }
  dsCurrentSuppressTargetingFlag: Byte;
  { Effect lock. }
  effectLock: Byte;
  { the spell affects multiple targets }
  gMultiTarget: Byte;
  { redraw the inventory menu }
  dsRedrawInventoryMenuFlag: Byte;
  { signed -- EffHndlr assigns -1, FxEngine guards >= 0 }
  gAttackRoll: ShortInt;
  hitsMade: array[1..2] of Byte;
  { current morale }
  dsCurrentMorale: Byte;
  { creature this one is interacting with }
  dsOtherCreatureCurrentPtr: Types.PCharRecord;
  { saving throw type, 0..4 }
  gSaveType: Byte;
  { unused }
  dsUnidentified69: Byte;

var
  { Effect dispatch }
  { effect handlers, indexed by effect id }
  effectFns: array[C_Effect.EFF_BLESS..C_Effect.EFF_READY_RING_INVIS] of Pointer;

var
  { 3D view }
  { shared pointer to wall symbol slices }
  wallGfx: Pointer;
  { four 256-byte GEO planes; View3D/Explore views }
  map3d: Types.PGeoMap;
  { Sky and ceiling color after palette mapping. }
  dsColorSkyCeiling: Byte;
  { View3D band colors; MapView recomputes them from the ECL color selectors after a script changes them
    (GameDat5.picRegionW) }
  { 3D-view color register A (ceiling/horizon band) }
  dsWallColorA: Byte;
  { 3D-view color register B (mid band) }
  dsWallColorB: Byte;
  { 3D-view color register C (floor/wall band) }
  dsWallColorC: Byte;
  { unused }
  dsUnidentified59: array[0..71] of Byte;

var
  { Map position, wall cache, animation and portrait cache }
  { automap shown in place of the 3D view }
  automapOn: Boolean;
  { Current map column; signed for edge and wrap checks. }
  gMapX: ShortInt;
  { Current map row. }
  gMapY: ShortInt;
  { Current party facing direction. }
  gFacing: Byte;
  { Wall at the current square in the facing direction. }
  wallAhead: Byte;
  { Event byte at the party's square; bit 7 is a flag, not a wall }
  eventAtCell: Byte;
  dsWallSetCache: array[1..3] of Types.TWallSetCacheSlot;
  { Picture animation; MenuCore views it as Types.TMenuAnim }
  animData: Types.TAnimRec;
  { HEAD and BODY image caches. }
  dsPortraitCache: array[1..2] of Types.TPortSlot;

var
  { Picture archive and menu state }
  { Current picture archive name. }
  picArcName: String[8];
  { picture id loaded from picArcName; 255 invalidates the pair }
  picArcId: Byte;
  { Zero-based position of the first visible list entry. }
  vertTop: Integer;

var
  { Spell casting and targeting }
  { Current item used for spell casting. }
  dsCurrentScrollPtr: Types.PItemRec;
  { Spell handlers indexed by spell ID. }
  spellFps: array[0..67] of Pointer;
  { Number of targeted creatures }
  spellTargetCount: Byte;
  { Selected target creatures. }
  dsTargetCreaturePtr: array[1..72] of Types.PCharRecord;
  { Remembered noncombat spell target, initially the caster. }
  castTarget: Types.PCharRecord;
  { combat arena column, 0..49 }
  gTargetX: ShortInt;
  { combat arena row, 0..24 }
  gTargetY: ShortInt;
  { Pointer to linked list of Stinking Clouds }
  stinkHead: Types.PStinkRec;
  usingItem: Boolean;
  treasureMoneyFlag: Boolean;

var
  { Rest and healing }
  { Remaining rest time as a seven-word GBVM clock; TClock-typed so it passes to GameTime.ValidateClock as a var
    parameter }
  dsRestingTimeGbvm: Types.TClock;
  { Spell preparation timers for the eight party slots. }
  prepTimers: array[1..8] of Byte;
  { Time rested today, in five-minute ticks. }
  healTicks: Word;
  { Suppress the window border. }
  dsSuppressDrawingBorderFlag: Byte;

implementation

end.
