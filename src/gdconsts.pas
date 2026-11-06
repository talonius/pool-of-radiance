{ Typed constants: the game's initialized data in storage order, grouped in sections by subsystem. A new section starts
  wherever the data needs a word boundary. }
unit GDConsts;

interface

uses C_Gender, C_Class, C_Money, Types, Crt, C_Effect, C_Dir, C_Race, C_Status, C_Align, C_Rune;

{ Copy protection: the translation wheel. }
const
  { The translation wheel's code words: the Espruar and Dethek runes shown for each word, the path style printed under
    them, and the answer expected. CopyProtection picks an entry at random. }
  wheel: array[0..12] of Types.TWheelRec = (
    (answer: 'BEWARE'; espruar: (29, 30); dethek: (108, 112); path: '- - - - -'),
    (answer: 'ZOMBIE'; espruar: (91, 92); dethek: (77, C_Rune.NONE); path: '-..-..-..'),
    (answer: 'NOTNOW'; espruar: (44, 45); dethek: (106, C_Rune.NONE); path: '.........'),
    (answer: 'COPPER'; espruar: (9, 10); dethek: (67, C_Rune.NONE); path: '- - - - -'),
    (answer: 'DRAGON'; espruar: (1, 2); dethek: (104, C_Rune.NONE); path: '-..-..-..'),
    (answer: 'EFREET'; espruar: (17, 18); dethek: (109, C_Rune.NONE); path: '.........'),
    (answer: 'FRIEND'; espruar: (23, 24); dethek: (63, C_Rune.NONE); path: '- - - - -'),
    (answer: 'JUNGLE'; espruar: (25, 26); dethek: (78, C_Rune.NONE); path: '-..-..-..'),
    (answer: 'KNIGHT'; espruar: (34, 35); dethek: (108, C_Rune.NONE); path: '.........'),
    (answer: 'SAVIOR'; espruar: (46, 47); dethek: (66, C_Rune.NONE); path: '- - - - -'),
    (answer: 'TEMPLE'; espruar: (54, 55); dethek: (75, C_Rune.NONE); path: '-..-..-..'),
    (answer: 'VULCAN'; espruar: (52, 53); dethek: (110, C_Rune.NONE); path: '.........'),
    (answer: 'WYVERN'; espruar: (44, 45); dethek: (71, C_Rune.NONE); path: '- - - - -')
  );

{ Temple cures, combat AI stepping and placement, racial foes, turning undead, and the exploration and camp menus. }
const
  { Effects the temple's Cure Disease removes. }
  cureDiseaseEffects: array[1..6] of Byte = (
    C_Effect.HELPLESS, C_Effect.DISEASED, C_Effect.DISEASE_STRENGTH, C_Effect.DISEASE_HIT_POINTS,
        C_Effect.ROT_NO_HEALING, C_Effect.MUMMY_ROT);
  { The temple's healing menu. }
  templeSpells: array[1..10] of String[40] = (
    'Cure Blindness',
    'Cure Disease',
    'Cure Light Wounds',
    'Cure Serious Wounds',
    'Cure Critical Wounds',
    'Neutralize Poison',
    'Raise Dead',
    'Remove Curse',
    'Stone to Flesh',
    'Exit');
  { AI step patterns (aiStance 1..6): five direction offsets tried in order, each added to the base direction mod 8 (8 =
    straight ahead, 1/7 = one step clockwise/counterclockwise, 2/6 = two, 3/5 = three, 4 = reverse). Patterns 1..4 are
    kept on three turns out of four; sweep patterns 5..6 are rerolled every turn. }
  aiDirOffsets: array[1..6, 1..5] of Byte = (
    ( 8, 7, 6, 1, 2),
    ( 8, 1, 2, 7, 6),
    ( 7, 1, 8, 6, 2),
    ( 1, 7, 8, 2, 6),
    ( 8, 7, 6, 5, 4),
    ( 8, 1, 2, 3, 4));
  { The direction each placement ring moves out from the team's origin, by the quadrant the team faces; a wall that way
    keeps the ring from starting there. Entry 0 (center) is no step. }
  ringDirTbl: array[0..3, 0..3] of Byte = (
    ( 8, 4, 6, 2),
    ( 8, 6, 4, 0),
    ( 8, 0, 6, 2),
    ( 8, 2, 0, 4));
  { Starting direction of each placement ring, by the quadrant the team faces; halved, it is the quadrant the ring
    starts in. }
  ringStart: array[0..3, 0..3] of Byte = (
    ( 0, 0, 2, 6),
    ( 2, 2, 0, 4),
    ( 4, 4, 2, 6),
    ( 6, 6, 4, 0));
  { Step direction of each quadrant, read through dirDx and dirDy; also the facing a placed creature takes from the
    party's facing. }
  quadDir: array[0..3] of Byte = (
     7, 2, 3, 6);
  { Quad column where a placement leg starts, by outer ring (True) or first ring and by quadrant. }
  startQuadX: array[Boolean, 0..3] of ShortInt = (
    ( 5, 4, 5, 6),
    ( 3, 8, 7, 2));
  { Quad row where a placement leg starts, by outer ring (True) or first ring and by quadrant. }
  startQuadY: array[Boolean, 0..3] of ShortInt = (
    ( 3, 2, 2, 3),
    ( 0, 2, 5, 3));
  { The free quad-column range lo..hi of each quad row, by facing pattern d; lo > hi closes the row. }
  rowBand: array[0..4, 0..5] of Types.TBandRec = (
    ((lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)),
    ((lo: 0; hi: 2), (lo: 0; hi: 3), (lo: 1; hi: 4), (lo: 2; hi: 5), (lo: 3; hi: 6), (lo: 4; hi: 7)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0)),
    ((lo: 3; hi: 6), (lo: 4; hi: 7), (lo: 5; hi: 8), (lo: 6; hi: 9), (lo: 7; hi: 10), (lo: 8; hi: 10)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)));
  { Monsters a gnome gets an attack bonus against. }
  gnomeFoes: array[1..4] of Types.TName15 = (
    'KOBOLD', 'KOBOLD LEADER', 'GOBLIN', 'GOBLIN LEADER');
  { Monsters a dwarf gets an attack bonus against. }
  dwarfFoes: array[1..8] of Types.TName15 = (
    'ORC', 'ORC LEADER', 'GOBLIN', 'GOBLIN LEADER',
    'HOBGOBLIN', 'HOBGOBLIN CHIEF', 'GAGOOL', 'MACE');
  { Monsters whose attack roll against a dwarf drops by 4. EffHndlr reads them through an eight-entry view. }
  giantFoes: array[1..5] of Types.TName15 = (
    'OGRE', 'OGRE LEADER', 'TROLL', 'FIRE GIANT', 'HILL GIANT');
  { Turning table by undead level (row) and cleric level (column: levels 1..8 one each, then 9..13, then 14+). Roll d20
    >= Abs(value): positive values turn, zero or negative values destroy. 1 turns automatically, 0 destroys
    automatically, and 99 is immune. A negative result extends exhausted attempts until six successes. }
  turnTable: Types.TTurnUndeadTable = (
    { 1: Skeleton }
    (10, 7, 4, 1, 1, 0, 0, -1, -1, -1),
    { 2: Zombie }
    (13, 10, 7, 1, 1, 0, 0, 0, -1, -1),
    { 3: Ghoul }
    (16, 13, 10, 4, 1, 1, 0, 0, 0, -1),
    (19, 16, 13, 7, 4, 1, 1, 0, 0, -1),
    { 5: Wight }
    (20, 19, 16, 10, 7, 4, 1, 1, 0, 0),
    { 6: Ghast }
    (99, 20, 19, 13, 10, 7, 4, 1, 1, 0),
    { 7: Wraith }
    (99, 99, 20, 16, 13, 10, 7, 4, 1, 0),
    { 8: Mummy }
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 1),
    { 9: Spectre }
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 1),
    { 10: Vampire }
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 4));
  { The dungeon exploration menu. }
  menu3D: String[40] = 'Area Cast View Encamp Search Look';
  { The wilderness exploration menu. }
  menuWild: String[40] = 'Cast View Encamp Search Look';
  { The camp menu. }
  campMenu: String[40] = 'Save View Magic Rest Alter Exit';
  { The camp's magic menu. }
  magicMenu: String[40] = 'Cast Memorize Scribe Display Rest Exit';
  { The camp's Alter menu. }
  alterMenu: String[40] = 'Order Drop Speed Icon Pics Exit';

{ The party order menu and the class bits for item use and training. }
const
  { The party order menu, before and after a character is picked. }
  orderMenus: array[0..1] of String[40] = ('Select Exit', 'Place Exit');
  { TCharRecord.itemLimits usability bit for each class slot, in classLevels (C_Class level-slot) order. }
  usabilityBit: array[0..7] of Byte = (
    1 shl 1, 1 shl 4, 1 shl 3, 1 shl 6, 1 shl 7, 1 shl 0, 1 shl 2, 1 shl 5);
  { Training-hall class bits (GBVM_TRAIN_CLASS_MASK) by class slot; only entries 0..7 are read. Paladin, ranger and monk
    combine two bits. }
  classBit: array[0..16] of Byte = (
    2, 2, 8, 10, 10, 1, 4, 6, 16, 16, 16, 32, 32, 32, 64, 64, 64);

{ The main menu. }
const
  { Hotkeys of the main menu. }
  menuKeys: String[40] = 'C D M T V A R L S B E J';
  { The main menu's entries, set for an empty roster. }
  menuItems: array[0..10] of Types.TMenuItem = (
    (name: 'Create New Character'; enabled: 1),
    (name: 'Drop Character'; enabled: 0),
    (name: 'Modify Character'; enabled: 0),
    (name: 'Train Character'; enabled: 0),
    (name: 'View Character'; enabled: 0),
    (name: 'Add Character to Party'; enabled: 1),
    (name: 'Remove Character from Party'; enabled: 0),
    (name: 'Load Saved Game'; enabled: 1),
    (name: 'Save Current Game'; enabled: 0),
    (name: 'BEGIN Adventuring'; enabled: 0),
    (name: 'Exit to DOS'; enabled: 1));

{ The icon editor's menus. }
const
  { The icon editor's menus, one per editor state. }
  iconMenus: array[1..5] of String[40] = (
    { State 1: editor actions }
    'Parts color-1 color-2 Size Exit',
    { State 2: shape selection }
    'Head Weapon Exit',
    { State 3: color part; xxxx becomes Hair or Face }
    'Weapon Body xxxx Shield Arm Leg Exit',
    { State 4: size, prefixed with Small or Large }
    ' Keep Exit',
    { State 5: cycle shape or color }
    'Next Prev Keep Exit');

{ Hit dice, combat icon names, the portraits of joining NPCs and the Yarash ending's map remaps. }
const
  { Hit dice rolled per class, at creation and in training. }
  hpDice: array[0..7] of Byte = (
    { Cleric: 1d8 }
    1,
    { Druid: 1d8 }
    1,
    { Fighter: 1d10 }
    1,
    { Paladin: 1d10 }
    1,
    { Ranger: 2d8 }
    2,
    { Magic-User: 1d4 }
    1,
    { Thief: 1d6 }
    1,
    { Monk: 2d4 }
    2);
  { Sides of each class's hit die. }
  hpSides: array[0..7] of Byte = (
     { Cleric: d8 }
     8,
     { Druid: d8 }
     8,
    { Fighter: d10 }
    10,
    { Paladin: d10 }
    10,
     { Ranger: d8 }
     8,
     { Magic-User: d4 }
     4,
     { Thief: d6 }
     6,
     { Monk: d4 }
     4);
  { CHEAD/CBODY filename suffix indexed by iconSize: S for 1 (dwarf, gnome, halfling), T for 2 (tall races). }
  iconHeightSuffix: array[1..2] of Char = ('S', 'T');
  { Portrait heads for a joining NPC, by gender (male, female) and a 1d8 roll. }
  npcPortraitHeads: array[0..1, 1..8] of Byte = (
    (1, 2, 3, 4, 5, 8, 11, 12),
    (6, 7, 9, 10, 13, 14, 6, 7));
  { Portrait bodies for a joining cleric, by gender (male, female) and a 1d5 roll. }
  npcClericBodies: array[0..1, 1..5] of Byte = (
    (2, 4, 2, 4, 2), (2, 4, 8, 2, 4));
  { Portrait bodies for a joining fighter, and for any class other than cleric, magic-user and thief, by gender (male,
    female) and a 1d5 roll. }
  npcFighterBodies: array[0..1, 1..5] of Byte = (
    (1, 3, 4, 5, 6), (7, 9, 11, 7, 9));
  { Portrait bodies for a joining magic-user, by gender (male, female) and a 1d5 roll. }
  npcMageBodies: array[0..1, 1..5] of Byte = (
    (2, 2, 2, 2, 2), (8, 10, 12, 8, 10));
  { Portrait bodies for a joining thief, by gender (male, female) and a 1d5 roll. }
  npcThiefBodies: array[0..1, 1..5] of Byte = (
    (6, 6, 6, 6, 6), (8, 10, 8, 10, 8));
  { Wilderness tiles the Yarash ending remaps Black to Blue and LightGray to Green. Bit 7 selects the second tile set
    (tileSetHigh), the low 7 bits the frame. }
  yarBlueGreenTiles: array[0..10] of Byte = (
    101, 102, 103, 104, 105, 106, 107, 113, 128 + 96, 128 + 97, 128 + 98);
  { Wilderness tiles the Yarash ending remaps LightGray to Green. Bit 7 selects the second tile set, the low 7 bits the
    frame. }
  yarGreenTiles: array[0..17] of Byte = (
    86, 87, 88, 89, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119,
    128 + 95, 128 + 115, 128 + 117);
  { Source side of both Yarash remaps: every color, in palette order. }
  yarRemapFrom: Types.TColorTab = (
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DarkGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    Yellow,
    White);
  { Target side of the Black to Blue and LightGray to Green remap. }
  yarBlueGreenTo: Types.TColorTab = (
    { Black -> Blue }
    Blue,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> Green }
    Green,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> LightMagenta }
    LightMagenta,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Target side of the LightGray to Green remap. }
  yarGreenTo: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> Green }
    Green,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> LightMagenta }
    LightMagenta,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Left column of the wilderness view for each step of the Yarash ending. }
  yarViewX: array[0..8] of Word = (
    17, 17, 17, 19, 19, 19, 23, 23, 23);
  { Top row of the wilderness view for each step of the Yarash ending. }
  yarViewY: array[0..8] of Word = (
    15, 15, 15, 20, 20, 20, 25, 25, 25);

{ Random treasure items and the spell list headings. }
const
  { Items a random treasure can hold. }
  randomItemTemplates: Types.TRandomItemTable = (
    templates: (
      { Template 1 (word index 1): Potion of Extra Healing }
      (nameIds: (187, 167, 64); weight: 1; value: 800; properties: (3, 3, 0)),
      { Template 2 (word index 9): Potion of Giant Strength }
      (nameIds: (239, 167, 64); weight: 1; value: 1100; properties: (1, 82, 0)),
      { Template 3 (word index 17): Potion of Healing }
      (nameIds: (185, 167, 64); weight: 1; value: 400; properties: (1, 85, 0)),
      { Template 4 (word index 25): Potion of Speed }
      (nameIds: (173, 167, 64); weight: 1; value: 450; properties: (1, 80, 0)),
      { Template 5 (word index 33): Scroll of Restoring Levels }
      (nameIds: (240, 167, 65); weight: 1; value: 2100; properties: (56, 56, 0)),
      { Template 6 (word index 41): Ring of Feather Falling }
      (nameIds: (238, 167, 66); weight: 1; value: 5000; properties: (0, 27, 128)),
      { Template 7 (word index 49): Wand of Lightning }
      (nameIds: (157, 167, 69); weight: 1; value: 6000; properties: (20, 51, 0)),
      { Template 8 (word index 57): Wand of Magic Missiles }
      (nameIds: (206, 167, 69); weight: 1; value: 11000; properties: (30, 88, 0)),
      { Template 9 (word index 65): Wand of Paralyzation }
      (nameIds: (225, 167, 69); weight: 1; value: 5000; properties: (20, 84, 0)),
      { Template 10 (word index 73): Gauntlets of Ogre Power }
      (nameIds: (226, 167, 100); weight: 10; value: 15000; properties: (0, 38, 131)),
      { Template 11 (word index 81): Keoghtum's Ointment }
      (nameIds: (0, 111, 182); weight: 1; value: 10000; properties: (5, 81, 0)),
      { Template 12 (word index 89): Necklace of Missiles }
      (nameIds: (228, 167, 119); weight: 1; value: 16000; properties: (20, 87, 0)),
      { Template 13 (word index 97): Cloak of Displacement }
      (nameIds: (170, 167, 88); weight: 25; value: 17500; properties: (0, 89, 133)),
      { Template 14 (word index 105): Javelin of Lightning }
      (nameIds: (157, 167, 21); weight: 20; value: 3000; properties: (1, 83, 0)),
      { Template 15 (word index 113): Wand of Fireballs }
      (nameIds: (242, 167, 69); weight: 1; value: 5000; properties: (20, 47, 0)),
      { Template 16 (word index 121): Ring of Fire Resistance }
      (nameIds: (205, 167, 66); weight: 1; value: 5000; properties: (0, 61, 129)),
      { Template 17 (word index 129): Ring of Invisibility }
      (nameIds: (227, 167, 66); weight: 1; value: 7500; properties: (0, 56, 139)),
      { Template 18 (word index 137): Bag of Holding }
      (nameIds: (186, 167, 73); weight: 150; value: 25000; properties: (0, 0, 0)),
      { Template 19 (word index 145): Cloak of Elvenkind }
      (nameIds: (229, 167, 88); weight: 25; value: 6000; properties: (0, 72, 134))));
  { Spell list headings, by spell level. }
  spellLevelNames: array[1..9] of string[40] = (
    '1st Level',
    '2nd Level',
    '3rd Level',
    '4th Level',
    '5th Level',
    '6th Level',
    '7th Level',
    '8th Level',
    '9th Level');

{ Effect lists, the 3D view's colors and geometry, color remaps and fills, word-wrap and file-name characters, and the
  name strings. }
const
  { Effects removed by RemoveEffectsHp0 when a creature reaches zero hit points or is put out of play. }
  hpZeroEffects: array[1..16] of Byte = (
    C_Effect.TRAINING_MANUAL, C_Effect.CHARM, C_Effect.STINKING_CLOUD_COUGH, C_Effect.HELPLESS,
        C_Effect.ANIMATE_DEAD, C_Effect.SNAKE_CHARM, C_Effect.PARALYSIS,
    C_Effect.SLEEP, C_Effect.DRAGON_AURA, C_Effect.IMMOBILE, C_Effect.TROLL_REGENERATION,
        C_Effect.FIGHT_ON, C_Effect.REGENERATION, C_Effect.SPIRITUAL_HAMMER_GONE,
    C_Effect.BITE_HOLD, C_Effect.BLOOD_DRAIN);
  { Effects removed by RemoveAiEffects at the start of CombatAi.CheckMorale. }
  aiRoundRemoveEffects: array[1..2] of Byte = (
    C_Effect.BITE_HOLD, C_Effect.BLOOD_DRAIN);
  { Display color for each sky and ceiling selector of a zone; selectors 8..15 repeat 0..7. }
  skyCeilingColors: array[0..15] of Byte = (
    Black,
    White,
    LightRed,
    LightCyan,
    LightMagenta,
    LightGreen,
    LightBlue,
    Yellow,
    Black,
    White,
    LightRed,
    LightCyan,
    LightMagenta,
    LightGreen,
    LightBlue,
    Yellow);
  { Special locations on the 44x36 wilderness map, by Wilds location constant: x and y are map cells and icon a 1-based
    tile id. BuildWildernessMap applies no icon for entries 1 and 2. }
  wildernessSpecialLocations: array[1..9] of Types.TSpecLoc = (
    { 1: the silver dragon's den }
    (x: 10; y: 9; icon: 240),
    { 2: the Zhentil outpost }
    (x: 3; y: 32; icon: 2),
    { 3 BUCCANEERS_BASE }
    (x: 12; y: 31; icon: 2),
    { 4 NOMAD_CAMP }
    (x: 25; y: 11; icon: 1),
    { 5 KOBOLD_CAVES }
    (x: 32; y: 15; icon: 165),
    { 6 HILLS_SITE }
    (x: 33; y: 23; icon: 157),
    { 7 LIZARD_MAN_KEEP }
    (x: 37; y: 8; icon: 147),
    { 8 SORCERERS_ISLAND }
    (x: 19; y: 16; icon: 247),
    { 9 PHLAN }
    (x: 25; y: 27; icon: 256));
  { Source side of the sprite color remap LoadAnimation applies when its transp argument is odd (not under CGA). }
  animRemapFrom: Types.TColorTab = (
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DarkGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    Yellow,
    White);
  { Target side of LoadAnimation's sprite color remap. }
  animRemapTo: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> Black }
    Black,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Where each wall slot of the 3D view sits: its first cell in a WALLDEF slice, its size in symbol cells and its base
    column and row in the 11x11 view. }
  viewSlotGeom: Types.TViewSlotGeom = (
    { First cell in a 156-cell WALLDEF slice }
    start: (0, 2, 6, 10, 22, 38, 54, 110, 132, 154);
    { Rectangle width in symbol cells }
    cols: (1, 1, 1, 3, 2, 2, 7, 2, 2, 1);
    { Rectangle height in symbol cells }
    rows: (2, 4, 4, 4, 8, 8, 8, 11, 11, 2);
    { Base column inside the 11-column view }
    xCol: (5, 4, 6, 4, 2, 7, 2, 0, 9, 5);
    { Base row inside the 11-row view }
    yRow: (4, 3, 3, 3, 1, 1, 1, 0, 0, 4));
  { Source side of LoadIconAnim's two icon remaps: every color, in palette order. }
  iconColorIdentity: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> LightMagenta }
    LightMagenta,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Target side of the icon remap that turns LightMagenta into DarkGray. }
  iconColorPinkToDarkGray: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> DarkGray }
    DarkGray,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Target side of the icon remap that turns LightMagenta into Black. }
  iconColorPinkToBlack: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> Black }
    Black,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Packed fill byte for each mapped CGA color (0..3), indexed by SrcNibble(color, map): four identical 2-bit pixels.
    FillPicRect fills with it. }
  cgaColorFill: array[0..3] of Byte = ($00, $55, $AA, $FF);
  { Packed fill byte for each Tandy color, 0..15 (Black through White): two identical 4-bit pixels. }
  tandyColorFill: array[0..15] of Byte = (
    $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF);
  { Punctuation DisplayMessageWindow may break a line after; space is tested separately. }
  breakChars: Types.TBrkSet = ['!', ',', '-', '.', ':', ';', '?'];
  { Characters SanitizeFileName removes from a file name. }
  invalidFileChars: array[1..10] of Char = (
    { space }
    ' ',
    { period }
    '.',
    { asterisk }
    '*',
    { comma }
    ',',
    { question mark }
    '?',
    { slash }
    '/',
    { backslash }
    '\',
    { colon }
    ':',
    { semicolon }
    ';',
    { vertical bar }
    '|');
  { Coin values in copper: copper 1, silver 10, electrum 100, gold 200, platinum 1000. Note: when the purse runs short,
    CharGen.TakeCoins indexes past the five rates into classNames, so keep classNames right after this table. }
  coinValues: array[C_Money.COPPER..C_Money.PLATINUM] of LongInt = (
    1, 10, 100, 200, 1000);
  { Class names, indexed by TCharRecord.charClass. }
  classNames: array[C_Class.CLERIC..C_Class.MAGE_THIEF] of string[26] = (
    'Cleric',
    'Druid',
    'Fighter',
    'Paladin',
    'Ranger',
    'Magic-User',
    'Thief',
    'Monk',
    'Cleric/Fighter',
    'Cleric/Fighter/Magic-User',
    'Cleric/Ranger',
    'Cleric/Magic-User',
    'Cleric/Thief',
    'Fighter/Magic-User',
    'Fighter/Thief',
    'Fighter/Magic-User/Thief',
    'Magic-User/Thief');
  { Race names, indexed by TCharRecord.race. }
  raceNames: array[C_Race.MONSTER..C_Race.HUMAN] of string[9] = (
    'Monster',
    'Dwarf',
    'Elf',
    'Gnome',
    'Half-Elf',
    'Halfling',
    'Half-Orc',
    'Human');
  { Alignment names, indexed by TCharRecord.alignment. }
  alignNames: array[C_Align.LAWFUL_GOOD..C_Align.CHAOTIC_EVIL] of string[16] = (
    'Lawful Good',
    'Lawful Neutral',
    'Lawful Evil',
    'Neutral Good',
    'True Neutral',
    'Neutral Evil',
    'Chaotic Good',
    'Chaotic Neutral',
    'Chaotic Evil');
  { Gender names, indexed by TCharRecord.gender. }
  genderNames: array[C_Gender.MALE..C_Gender.FEMALE] of string[6] = (
    'Male',
    'Female');
  { Money names, indexed like TCharRecord.coins and TMoney. }
  moneyNames: array[C_Money.COPPER..C_Money.JEWELRY] of string[10] = (
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Gems',
    'Jewelry');
  { Status names, indexed by TCharRecord.status; see C_Status. }
  statusStrs: array[C_Status.OKAY..C_Status.GONE] of string[12] = (
    'Okay',
    'Animated',
    'tempgone',
    'Running',
    'Unconscious',
    'Dying',
    'Dead',
    'Stoned',
    'Gone');
  { Item name components, indexed 1..255 by TItemRec.nameIds; a zero name ID adds no component. }
  nameParts: array[1..255] of string[20] = (
    'Battle Axe',
    'Hand Axe',
    'Bardiche',
    'Bec De Corbin',
    'Bill-Guisarme',
    'Bo Stick',
    'Club',
    'Dagger',
    'Dart',
    'Fauchard',
    'Fauchard-Fork',
    'Flail',
    'Military Fork',
    'Glaive',
    'Glaive-Guisarme',
    'Guisarme',
    'Guisarme-Voulge',
    'Halberd',
    'Lucern Hammer',
    'Hammer',
    'Javelin',
    'Jo Stick',
    'Mace',
    'Morning Star',
    'Partisan',
    'Military Pick',
    'Awl Pike',
    'Quarrel',
    'Ranseur',
    'Scimitar',
    'Spear',
    'Spetum',
    'Quarter Staff',
    'Bastard Sword',
    'Broad Sword',
    'Long Sword',
    'Short Sword',
    'Two-Handed Sword',
    'Trident',
    'Voulge',
    'Composite Long Bow',
    'Composite Short Bow',
    'Long Bow',
    'Short Bow',
    'Heavy Crossbow',
    'Light Crossbow',
    'Sling',
    'Mail',
    'Armor',
    'Leather',
    'Padded',
    'Studded',
    'Ring',
    'Scale',
    'Chain',
    'Splint',
    'Banded',
    'Plate',
    'Shield',
    'Woods',
    'Arrow',
    '',
    '',
    'Potion',
    'Scroll',
    'Ring',
    'Rod',
    'Stave',
    'Wand',
    'Jug',
    'Amulet',
    'Apparatus',
    'Bag',
    'Beaker',
    'Boat',
    'Book',
    'Boots',
    'Bowl',
    'Bracers',
    'Brazier',
    'Brooch',
    'Broom',
    'Purse',
    'Candle',
    'Carpet',
    'Censer',
    'Chime',
    'Cloak',
    'Crystal',
    'Cube',
    'Cubic',
    'Fortress',
    'Decanter',
    'Deck',
    'Drums',
    'Dust',
    'Eyes',
    'Figurine',
    'Flask',
    'Gauntlets',
    'Gem',
    'Girdle',
    'Helm',
    'Horn',
    'Horseshoes',
    'Incense',
    'Stone',
    'Instrument',
    'Javelin',
    'Jewel',
    'Ointment',
    'Libram',
    'Lyre',
    'Manual',
    'Mattock',
    'Maul',
    'Medallion',
    'Mirror',
    'Necklace',
    'Net',
    'Pigment',
    'Pearl',
    'Periapt',
    'Phylactery',
    'Pipes',
    'Hole',
    'Token',
    'Robe',
    'Rope',
    'Rug',
    'Saw',
    'Scarab',
    'Spade',
    'Sphere',
    '',
    'Talisman',
    'Tome',
    'Trident',
    'Grimoire',
    'Well',
    'Wings',
    'Vial',
    'Lantern',
    '',
    'Oil',
    '10 ft. Pole',
    '50 ft. Rope',
    'Iron',
    'Thf Prickly Tools',
    'Iron Rations',
    'Standard Rations',
    'Holy Symbol',
    'Holy Water vial',
    'Unholy Water vial',
    'Barding',
    'Dragon',
    'Lightning',
    'Saddle',
    'Small Raft',
    'Cart',
    'Wagon',
    '+1',
    '+2',
    '+3',
    '+4',
    '+5',
    'of',
    '',
    'Cloak',
    'Displacement',
    'Torches',
    'Oil',
    'Speed',
    'Tapestry',
    'Bodily Health',
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Ointment',
    'Keoghtum''s',
    'Sheet',
    'Strength',
    'Healing',
    'Holding',
    'Extra',
    'Gaseous Form',
    'Slipperiness',
    'Jewelled',
    'Flying',
    'Treasure Finding',
    'Fear',
    'Disappearance',
    'Statuette',
    'Fungus',
    'Chain',
    'Pendant',
    'Broach',
    'Of Seeking',
    '-1',
    '-2',
    '-3',
    'Lightning Bolt',
    'Fire Resistance',
    'Magic Missiles',
    'Save',
    'Clerical Scroll',
    'Magic User Scroll',
    'With 1 Spell',
    'With 2 Spells',
    'With 3 Spells',
    'Protection Scroll',
    'Jewelry',
    'Fine',
    'Huge',
    'Bone',
    'Brass',
    'Key',
    'AC 2',
    'AC 6',
    'AC 4',
    'AC 3',
    'Of Protection',
    'Paralyzation',
    'Ogre Power',
    'Invisibility',
    'Missiles',
    'Elvenkind',
    'Rotting',
    'Covered',
    'Efreeti',
    'Bottle',
    'Missile Attractor',
    'Of Maglubiyet',
    'Secr Door & Trap Det',
    'Gd Dragon Control',
    'Feather Falling',
    'Giant Strength',
    'Restoring Level(s)',
    'Flame Tongue',
    'Fireballs',
    'Spiritual',
    'Boulder',
    'Diamond',
    'Emerald',
    'Opal',
    'Saphire',
    'Of Tyr',
    'Of Tempus',
    'Of Sune',
    'Wooden',
    '+3 vs Undead',
    'Pass',
    'Cursed');

{ Compass names, step directions and the text and pixel tables. }
const
  { Compass abbreviations for the facings 0..7, clockwise from north. }
  dirNames: array[C_Dir.NORTH..C_Dir.NORTHWEST] of string[2] = (
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW');
  { Direction code for a one-cell step, indexed [dy + 1, dx + 1]; the center entry (CENTER) means no movement. }
  dirByDelta: array[0..2, 0..2] of Byte = (
    (7, 0, 1),
    (6, 8, 2),
    (5, 4, 3));
  { EGA plane masks, highest plane first; TextRend reads [3 - k] for plane k }
  egaPlaneMask: array[0..3] of Byte = ($08, $04, $02, $01);
  { CGA colors 0..3 repeated across eight 2-bit pixels }
  cgaColorPat: array[0..3] of Word = (
    $0000, $5555, $AAAA, $FFFF);
  { EGA-to-CGA font color map. }
  attrTable: array[0..15] of Byte = (
    0, 0, 0, 1, 2, 2, 2, 3, 3, 1, 1, 1, 2, 2, 3, 3);
  { One mask per 2-bit pixel position within a CGA pixel word, high pair first. Blit uses them to isolate, place and
    reflect CGA pixels; TextRend.RenderChar uses them to draw characters. }
  cgaPixelMask: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003);

{ Video plane and pixel tables, sound command ids, disk prompts, symbol-set ranges, direction steps, combat terrain and
  icon footprints, portrait tables and keypad codes. }
const
  { Color bit (1, 2, 4, 8) carried by each of the four EGA planes. Blit uses it to split a 4-bit color into plane bytes
    and to select planes through the sequencer map mask. }
  egaPlaneBit: array[0..3] of Byte = ($01, $02, $04, $08);
  { CGA color by pixel position within a packed byte. }
  cgaPixPos: array[0..3, 0..3] of Byte = (
    ($00, $00, $00, $00),
    ($40, $10, $04, $01),
    ($80, $20, $08, $02),
    ($C0, $30, $0C, $03));
  { Packed EGA-to-CGA color map, two EGA colors per byte, used by Blit.FillPicRect for the CharGen icon previews and the
    View3D backgrounds }
  iconColorMap: Types.TColorMap = (
    $00, $11, $22, $12, $00, $21, $30, $33);
  { Sound command ids in one table: the three subsystems read their own slice. }
  soundIds: record
    commands: array[0..3] of Word;
    damage: Word;
    combat: array[0..10] of Word;
  end = (
    commands: (255, 0, 1, 2);
    damage: 3;
    combat: (4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14));
  { Insert-disk prompts, indexed by virtualDisk. Note: the index is not range-checked. }
  insertDiskMsg: array[1..8] of string[29] = (
    'Insert disk 1 in drive ',
    'Insert disk 2 in drive ',
    'Insert disk 3 in drive ',
    'Insert disk 4 in drive ',
    'Insert disk 5 in drive ',
    'Insert disk 6 in drive ',
    'Insert disk 7 in drive ',
    'Insert disk 8 in drive ');
  { First symbol of each symbol set, by set id. }
  symSetFirst: array[0..4] of Word = (1, 46, 116, 186, 256);
  { Last symbol of each symbol set, by set id; View3D offsets the WALLDEF cells past the end of set 0. }
  symSetLast: array[0..4] of Word = (45, 115, 185, 255, 286);
  { Column step of each direction; CENTER does not move. }
  dirDx: array[C_Dir.NORTH..C_Dir.CENTER] of ShortInt = (
    0, 1, 1, 1, 0, -1, -1, -1, 0);
  { Row step of each direction; CENTER does not move. }
  dirDy: array[C_Dir.NORTH..C_Dir.CENTER] of ShortInt = (
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
  { HEAD DAX id of each portraitHead. }
  headTbl: array[1..14] of Byte = (
    0, 8, 9, 13, 16, 18, 22, 34, 45, 51, 53, 57, 67, 68);
  { BODY DAX id of each portraitBody. }
  bodyTbl: array[1..12] of Byte = (
    1, 2, 3, 4, 7, 8, 18, 24, 26, 33, 35, 37);
  { Scan codes of the keypad digits 1..9; MenuCore indexes it by Ord(ch) - Ord('1'). }
  keypadScan: array[0..8] of Byte = (
    79, 80, 81, 75, 32, 77, 71, 72, 73);

{ Spells, rest time units and the wilderness map. }
const
  { Directions a Stinking Cloud covers: center, east, southeast and south. }
  cloudDir: array[1..4] of Byte = (
    8, 2, 3, 4);
  { Spell names by spell id 1..56. }
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
  { Spell rules by spell id; ids 57..67 are item effects. }
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
  { Limit of each rest clock unit before it carries into the next. }
  unitScale: array[0..6] of Word = (
    { segment, minute, turn, hour, day, month, year }
    10, 10, 6, 24, 30, 12, 256);
  { The wilderness map, by row and column: tile ids from 1; with the 1 taken off, bit 7 selects the second tile set. }
  wildMap: array[0..35, 0..43] of Byte = (
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02,
     $01, $02, $01, $02, $01, $28, $9D, $9E, $9B, $9C, $35, $65, $31, $9B, $33, $62, $5E, $9D, $35, $36, $9E, $37),
    ($02, $01, $02, $01, $02, $01, $05, $06, $08, $06, $08, $09, $02, $01, $02, $01, $02, $01, $02, $05, $06, $08,
     $09, $01, $02, $01, $25, $2D, $2E, $9C, $2D, $30, $62, $63, $64, $32, $9C, $35, $36, $44, $4A, $9D, $38, $63),
    ($01, $02, $01, $01, $02, $05, $12, $07, $0D, $21, $04, $12, $08, $09, $05, $06, $08, $06, $03, $12, $07, $04,
     $12, $10, $01, $02, $26, $1A, $62, $2F, $62, $62, $36, $5F, $5F, $9B, $37, $5E, $9D, $43, $4B, $9B, $9C, $33),
    ($02, $05, $06, $03, $0D, $0F, $0E, $0F, $0C, $0B, $0A, $23, $07, $04, $0D, $0E, $0F, $23, $12, $0D, $21, $04,
     $12, $07, $10, $01, $02, $27, $33, $65, $64, $5E, $9B, $9C, $9D, $44, $65, $34, $37, $34, $9C, $9D, $9E, $2D),
    ($03, $07, $0D, $0F, $0C, $0B, $22, $0C, $0B, $22, $0B, $1F, $12, $07, $0E, $22, $0C, $0B, $0A, $0C, $0B, $21,
     $04, $12, $07, $10, $01, $02, $28, $38, $65, $34, $9D, $9E, $9B, $43, $62, $63, $62, $63, $4C, $9B, $9C, $48),
    ($0E, $0F, $22, $0B, $22, $0C, $0B, $22, $24, $24, $1F, $07, $04, $0D, $22, $24, $22, $0C, $0B, $24, $22, $24,
     $21, $04, $12, $11, $02, $29, $9C, $37, $62, $63, $32, $9D, $37, $63, $64, $65, $64, $65, $62, $32, $9D, $43),
    ($0C, $0B, $24, $22, $24, $22, $0C, $0B, $22, $1F, $07, $04, $12, $0E, $0C, $0B, $24, $22, $24, $22, $0C, $0B,
     $1F, $07, $04, $11, $01, $02, $28, $33, $64, $5E, $9B, $9C, $48, $65, $3A, $62, $3A, $62, $63, $4D, $9E, $35),
    ($0B, $24, $22, $24, $0C, $0B, $22, $24, $22, $21, $12, $0E, $0F, $22, $24, $22, $0B, $24, $22, $24, $22, $1F,
     $04, $12, $16, $13, $02, $29, $9B, $33, $62, $5E, $9D, $9E, $43, $42, $7B, $3D, $93, $3B, $65, $4B, $44, $63),
    ($22, $22, $0C, $0B, $22, $24, $24, $22, $0C, $0B, $C9, $CA, $22, $0C, $0B, $24, $22, $0C, $0B, $22, $1F, $12,
     $07, $11, $01, $02, $01, $02, $27, $9C, $35, $65, $32, $44, $42, $93, $92, $FF, $A7, $3C, $64, $4D, $43, $65),
    ($24, $0B, $22, $0C, $0B, $22, $0C, $0B, $22, $24, $CB, $CC, $24, $22, $0C, $0B, $24, $20, $1B, $1C, $16, $04,
     $12, $13, $02, $01, $02, $01, $29, $37, $62, $63, $32, $49, $41, $88, $93, $A7, $3E, $65, $62, $63, $64, $36),
    ($0B, $22, $24, $24, $22, $24, $22, $22, $24, $22, $CD, $CE, $CF, $24, $1F, $1D, $1C, $04, $12, $13, $01, $17,
     $15, $02, $01, $02, $01, $02, $01, $2A, $64, $5E, $9B, $37, $62, $41, $3F, $3E, $62, $63, $64, $65, $36, $9C),
    ($24, $0C, $0B, $22, $24, $22, $0C, $0B, $22, $24, $D0, $D1, $D2, $1C, $12, $07, $04, $12, $D8, $94, $02, $01,
     $02, $01, $02, $FB, $02, $01, $02, $01, $2A, $36, $2C, $62, $46, $47, $62, $63, $64, $65, $62, $36, $9E, $9B),
    ($22, $24, $22, $24, $22, $0B, $22, $24, $22, $1F, $04, $12, $D3, $D4, $EF, $D5, $D6, $D7, $79, $7A, $95, $02,
     $01, $02, $01, $8A, $95, $02, $01, $02, $01, $2B, $01, $45, $9B, $9C, $48, $62, $63, $64, $34, $9B, $9C, $9D),
    ($1B, $1B, $1C, $1D, $1E, $0C, $0B, $22, $1F, $04, $12, $07, $04, $12, $07, $DA, $D9, $79, $7C, $79, $7A, $95,
     $02, $01, $8A, $91, $7B, $95, $02, $01, $02, $01, $02, $39, $9D, $9E, $43, $36, $33, $62, $36, $9D, $9E, $2D),
    ($04, $12, $07, $04, $12, $1D, $1E, $1F, $04, $12, $07, $04, $14, $18, $15, $EE, $DB, $DC, $79, $7A, $79, $91,
     $95, $86, $7A, $90, $91, $7B, $95, $02, $01, $02, $40, $9B, $2D, $30, $36, $9E, $44, $64, $4C, $9C, $44, $62),
    ($14, $15, $2B, $17, $18, $18, $19, $14, $15, $17, $18, $15, $01, $02, $8A, $91, $79, $DD, $E7, $E6, $E5, $7D,
     $88, $89, $79, $7A, $7B, $91, $92, $96, $02, $29, $FC, $2F, $62, $4A, $9B, $9C, $5D, $65, $63, $32, $61, $63),
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $8A, $89, $93, $7B, $91, $DE, $E9, $E8, $E4, $01,
     $7D, $88, $7A, $90, $91, $7B, $92, $93, $95, $02, $27, $BA, $64, $4B, $9D, $9E, $9B, $48, $4A, $9B, $43, $64),
    ($02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $86, $89, $7B, $91, $92, $93, $79, $DF, $E1, $E2, $E3, $6F,
     $01, $7D, $88, $92, $93, $92, $93, $79, $7B, $95, $02, $B9, $B8, $2E, $2D, $4C, $9C, $5D, $4B, $44, $62, $63),
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $86, $88, $91, $7B, $92, $93, $79, $E0, $6D, $72, $66, $70,
     $02, $01, $7D, $91, $92, $93, $91, $7C, $91, $8E, $01, $02, $BB, $B7, $48, $63, $4D, $9D, $9E, $61, $64, $65),
    ($02, $01, $02, $01, $02, $01, $52, $5C, $02, $01, $02, $7D, $88, $92, $93, $79, $7B, $8F, $76, $68, $67, $71,
     $01, $02, $8A, $91, $7B, $91, $7B, $91, $79, $8D, $02, $01, $29, $B6, $5D, $65, $60, $9B, $9C, $61, $62, $36),
    ($01, $02, $01, $02, $01, $02, $53, $4F, $5B, $02, $01, $02, $7D, $88, $91, $7C, $8E, $02, $77, $69, $6D, $70,
     $02, $01, $88, $90, $91, $7B, $93, $7B, $91, $93, $95, $02, $99, $C8, $B5, $48, $60, $9D, $9E, $43, $36, $9B),
    ($02, $01, $02, $01, $02, $01, $54, $4F, $50, $01, $02, $01, $02, $7D, $7B, $79, $8D, $01, $F6, $6A, $6B, $73,
     $01, $02, $7D, $7A, $7B, $91, $92, $93, $79, $7A, $8C, $01, $9F, $C7, $9C, $43, $31, $9B, $44, $4A, $9D, $9E),
    ($01, $02, $01, $02, $01, $02, $55, $4F, $5B, $02, $01, $02, $01, $86, $88, $A7, $8C, $02, $8A, $59, $6A, $6B,
     $74, $01, $02, $A6, $91, $7B, $92, $93, $79, $97, $9A, $9A, $9B, $C6, $44, $62, $F2, $4D, $61, $60, $9C, $44),
    ($02, $01, $02, $01, $02, $01, $02, $54, $5C, $01, $02, $01, $02, $01, $7D, $8C, $02, $8A, $91, $58, $6D, $66,
     $6D, $74, $01, $7D, $93, $92, $93, $79, $7B, $97, $9C, $FA, $9E, $C5, $5D, $F1, $01, $2A, $5D, $31, $9B, $43),
    ($01, $02, $01, $02, $01, $02, $01, $53, $4F, $5B, $01, $02, $01, $02, $01, $02, $8A, $91, $7B, $91, $59, $6A,
     $6B, $6D, $75, $01, $A6, $93, $91, $7C, $91, $97, $9C, $C2, $C3, $C4, $A4, $01, $02, $01, $F3, $62, $4C, $35),
    ($02, $01, $02, $01, $02, $01, $52, $4F, $4F, $50, $02, $01, $02, $01, $02, $86, $7A, $90, $91, $7B, $58, $6D,
     $6A, $6C, $6B, $75, $7D, $88, $7B, $79, $7B, $93, $98, $C5, $A4, $01, $01, $02, $8A, $89, $B4, $64, $65, $B2),
    ($01, $02, $01, $02, $01, $02, $55, $4F, $51, $02, $01, $02, $01, $02, $01, $02, $7D, $7A, $7B, $91, $92, $59,
     $6D, $6D, $66, $6D, $75, $7D, $88, $A7, $8C, $A6, $92, $C0, $02, $8A, $89, $89, $92, $93, $87, $B2, $B3, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $54, $4F, $5B, $02, $01, $02, $01, $02, $01, $86, $90, $91, $7B, $92, $93,
     $5A, $59, $F4, $FD, $6E, $01, $7D, $8C, $02, $7D, $93, $BF, $A3, $A1, $A2, $92, $A0, $83, $84, $4E, $4E, $4E),
    ($01, $02, $01, $02, $01, $02, $01, $53, $4F, $50, $01, $02, $01, $02, $01, $02, $01, $7D, $88, $92, $93, $79,
     $7B, $7A, $57, $F5, $AE, $AD, $01, $02, $01, $02, $A6, $BE, $BD, $EB, $ED, $83, $84, $4E, $4E, $4E, $4E, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $54, $51, $01, $02, $01, $02, $01, $02, $01, $02, $01, $7D, $88, $92, $7C,
     $91, $93, $85, $4E, $4E, $4E, $AC, $AA, $A9, $A9, $A8, $BC, $EA, $EC, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($01, $02, $01, $02, $01, $02, $01, $55, $56, $02, $01, $02, $01, $02, $AA, $AB, $AD, $AA, $AF, $7E, $7F, $80,
     $81, $83, $84, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $F9, $B0, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $82, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($01, $02, $01, $FE, $01, $02, $AD, $02, $01, $02, $01, $02, $B0, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($B1, $AD, $B1, $AD, $AA, $AF, $4E, $AC, $B1, $AD, $AA, $AF, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E));
  { Map column offset for location types 2..4. }
  wildColOfs: array[2..4] of Byte = (0, 13, 26);

{ Class, race and level rules. }
const
  { 60 minus THAC0, by class slot and level. }
  thac0Tbl: array[0..7, 0..10] of Byte = (
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 40, 40, 40, 40, 41, 41, 41, 41, 41),
    (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46));
  { Palette slots of the six recolorable parts of a combat icon; the recolors land in these slots and the slot 8
    higher. }
  defIconCol: array[1..6] of Byte = (1, 2, 3, 4, 6, 7);
  { Base thief skills by thief level 1..9 and skill. }
  thiefBase: array[1..9, 1..8] of Byte = (
    (30, 25, 20, 15, 10, 10, 85, 0),
    (35, 29, 25, 21, 15, 10, 86, 0),
    (40, 33, 30, 27, 20, 15, 87, 0),
    (45, 37, 35, 33, 25, 15, 88, 20),
    (50, 42, 40, 40, 31, 20, 90, 25),
    (55, 47, 45, 47, 37, 20, 92, 30),
    (60, 52, 50, 55, 43, 25, 94, 35),
    (65, 57, 55, 62, 49, 25, 96, 40),
    (70, 62, 60, 70, 56, 30, 98, 45));
  { Racial adjustments to the thief skills, by race and skill. }
  raceAdj: array[1..7, 1..8] of ShortInt = (
    (0, 10, 15, 0, 0, 0, -10, -5),
    (5, -5, 0, 5, 10, 5, 0, 0),
    (0, 5, 10, 5, 5, 10, -15, 0),
    (10, 0, 0, 0, 5, 0, 0, 0),
    (5, 5, 5, 10, 15, 5, -15, -5),
    (-5, 5, 5, 0, 0, 5, 5, -10),
    (0, 0, 0, 0, 0, 0, 0, 0));
  { Dexterity adjustments to the first five thief skills, by Dexterity 9..19 and skill. }
  dexAdj: array[9..19, 1..5] of ShortInt = (
    (-15, -10, -10, -20, -10),
    (-19, -5, -10, -15, -5),
    (-5, 0, -5, -10, 0),
    (0, 0, 0, -5, 0),
    (0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0),
    (0, -5, 0, 0, 0),
    (5, 10, 0, 5, 5),
    (10, 15, 5, 10, 10),
    (15, 20, 10, 12, 12));
  { Ability score limits by race, Strength and exceptional Strength by gender. }
  raceStatLimits: array[1..7] of Types.TRuleRace = (
    (strMin: (8, 8); strMax: (18, 17); excMax: (99, 0); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 17; conMin: 12; conMax: 19; chaMin: 3; chaMax: 16),
    (strMin: (3, 3); strMax: (18, 16); excMax: (75, 0); intMin: 8; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 7; dexMax: 19; conMin: 6; conMax: 18; chaMin: 8; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 15); excMax: (50, 0); intMin: 7; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 8; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (3, 3); strMax: (18, 17); excMax: (90, 0); intMin: 4; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 6; dexMax: 18; conMin: 6; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (17, 14); excMax: (0, 0); intMin: 6; intMax: 18;
     wisMin: 3; wisMax: 17; dexMin: 8; dexMax: 18; conMin: 10; conMax: 19; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 18); excMax: (99, 75); intMin: 3; intMax: 17;
     wisMin: 3; wisMax: 14; dexMin: 3; dexMax: 17; conMin: 13; conMax: 19; chaMin: 3; chaMax: 12),
    (strMin: (3, 3); strMax: (18, 18); excMax: (100, 50); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 3; conMax: 18; chaMin: 3; chaMax: 18));
  { Classes open to each race: column 0 counts them and the rest are class ids. }
  classesByRace: array[1..7, 0..11] of ShortInt = (
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0),
    (7, 2, 5, 6, 13, 14, 15, 16, 0, 0, 0, 0),
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0),
    (11, 0, 2, 5, 6, 8, 9, 11, 13, 14, 15, 16),
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0),
    (6, 0, 2, 6, 8, 12, 14, 0, 0, 0, 0, 0),
    (4, 0, 2, 5, 6, 0, 0, 0, 0, 0, 0, 0));
  { Starting age by race and class: a base and the dice added to it. }
  startingAge: array[1..7, 0..6] of Types.TRuleAge = (
    ((base: 250; num: 2; sides: 20), (base: 0; num: 0; sides: 0), (base: 40; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 75; num: 3; sides: 6)),
    ((base: 650; num: 10; sides: 10), (base: 0; num: 0; sides: 0), (base: 130; num: 5; sides: 6),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 150; num: 5; sides: 6),
     (base: 100; num: 5; sides: 6)),
    ((base: 300; num: 3; sides: 12), (base: 0; num: 0; sides: 0), (base: 60; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 100; num: 2; sides: 12),
     (base: 80; num: 5; sides: 4)),
    ((base: 40; num: 2; sides: 4), (base: 0; num: 0; sides: 0), (base: 22; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 30; num: 2; sides: 8),
     (base: 22; num: 3; sides: 8)),
    ((base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 20; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 40; num: 2; sides: 4)),
    ((base: 20; num: 1; sides: 4), (base: 0; num: 0; sides: 0), (base: 13; num: 1; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 20; num: 2; sides: 4)),
    ((base: 18; num: 1; sides: 4), (base: 18; num: 1; sides: 4), (base: 15; num: 1; sides: 4),
     (base: 17; num: 1; sides: 4), (base: 20; num: 1; sides: 4), (base: 24; num: 2; sides: 4),
     (base: 18; num: 1; sides: 4)));
  { Age category thresholds in years, by race. }
  ageCat: array[1..7, 1..5] of Word = (
    (50, 150, 250, 350, 450),
    (175, 550, 875, 1200, 1600),
    (90, 300, 450, 600, 750),
    (40, 100, 175, 250, 325),
    (33, 68, 101, 144, 199),
    (15, 30, 45, 60, 80),
    (20, 40, 60, 90, 120));
  { Minimum Strength, Intelligence, Wisdom, Dexterity, Constitution and Charisma by class. }
  classMin: array[0..16, 0..5] of Byte = (
    (6, 6, 9, 0, 0, 0), (0, 0, 12, 0, 0, 15), (9, 0, 6, 6, 7, 0),
    (13, 9, 12, 0, 9, 17), (0, 13, 14, 0, 14, 0), (0, 9, 6, 6, 0, 0),
    (6, 6, 0, 9, 0, 0), (15, 0, 15, 15, 11, 0), (9, 0, 9, 0, 0, 0),
    (9, 9, 9, 0, 0, 0), (0, 13, 14, 0, 14, 0), (0, 9, 9, 0, 0, 0),
    (0, 0, 9, 9, 0, 0), (9, 9, 0, 0, 0, 0), (9, 0, 0, 9, 0, 0),
    (9, 9, 0, 9, 0, 0), (0, 9, 0, 9, 0, 0));
  { Alignments open to each class: column 0 counts them and the rest are alignment ids. }
  alignByClass: array[0..16, 0..9] of ShortInt = (
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (5, 1, 3, 4, 5, 7, 0, 0, 0, 0),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (1, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (7, 1, 2, 3, 4, 5, 7, 8, 0, 0),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0));
  { Hit point bonus per level by Constitution. }
  conBonusTbl: array[3..20] of ShortInt = (
    -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2);
  { Experience needed for each level, -1 where a class has no further level, and the spell slots gained at each level. }
  classXpTable: array[0..7] of Types.TRuleXp = (
    (xp: (1501, 3001, 6001, 13001, 27501, -1, -1, -1);
     slots: ((2, 0, 0), (2, 1, 0), (3, 2, 0), (3, 3, 1), (3, 3, 2), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (2001, 4001, 8001, 18001, 35001, 70001, 125001, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (2501, 5001, 10001, 22501, 40001, -1, -1, -1);
     slots: ((2, 0, 0), (2, 1, 0), (3, 2, 0), (4, 2, 1), (4, 2, 2), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))));
  { Starting gold dice by class. }
  startingGold: array[0..7] of Types.TRuleGold = (
    (num: 3; sides: 6), (num: 3; sides: 6), (num: 5; sides: 4), (num: 5; sides: 4),
    (num: 5; sides: 4), (num: 2; sides: 4), (num: 2; sides: 6), (num: 5; sides: 4));
  { Saving throws by class-level slot (the C_Class level-slot order), level 1..9 and save column 0..4. }
  saveTbl: array[0..7, 1..9, 0..4] of Byte = (
    ((10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15),
     (9, 12, 13, 15, 14), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12)),
    ((10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15),
     (9, 12, 13, 15, 14), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12)),
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16),
     (13, 14, 15, 16, 16), (11, 12, 13, 13, 14), (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11)),
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16),
     (13, 14, 15, 16, 16), (11, 12, 13, 13, 14), (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11)),
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16),
     (13, 14, 15, 16, 16), (11, 12, 13, 13, 14), (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11)),
    ((14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12),
     (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10)),
    ((13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15), (12, 11, 12, 15, 13), (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (11, 10, 10, 14, 11)),
    ((13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15),
     (13, 12, 14, 16, 15), (12, 11, 12, 15, 13), (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (11, 10, 10, 14, 11)));

implementation

end.
