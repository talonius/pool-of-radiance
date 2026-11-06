{ Game data, part 5 of 5: character rules, doors, combat round and the ECL interpreter, one section per subsystem. }
unit GameDat5;

interface

uses Types;

const
  { Class, race and level rules }
  { 60 - THAC0 }
  thac0Tbl: array[0..7, 0..10] of Byte = (
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 40, 40, 40, 40, 41, 41, 41, 41, 41),
    (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46));
  defIconCol: array[1..6] of Byte = (1, 2, 3, 4, 6, 7);
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
  raceAdj: array[1..7, 1..8] of ShortInt = (
    (0, 10, 15, 0, 0, 0, -10, -5),
    (5, -5, 0, 5, 10, 5, 0, 0),
    (0, 5, 10, 5, 5, 10, -15, 0),
    (10, 0, 0, 0, 5, 0, 0, 0),
    (5, 5, 5, 10, 15, 5, -15, -5),
    (-5, 5, 5, 0, 0, 5, 5, -10),
    (0, 0, 0, 0, 0, 0, 0, 0));
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
  dsMinimumMaximumStatistics: array[1..7] of Types.TRaceLim = (
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
  { Column zero is a count; subsequent columns are class IDs }
  classesByRace: array[1..7, 0..11] of ShortInt = (
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0),
    (7, 2, 5, 6, 13, 14, 15, 16, 0, 0, 0, 0),
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0),
    (11, 0, 2, 5, 6, 8, 9, 11, 13, 14, 15, 16),
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0),
    (6, 0, 2, 6, 8, 12, 14, 0, 0, 0, 0, 0),
    (4, 0, 2, 5, 6, 0, 0, 0, 0, 0, 0, 0));
  { race, class }
  dsStartingAge: array[1..7, 0..6] of Types.TAgeRec = (
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
  { age thresholds in years }
  ageCat: array[1..7, 1..5] of Word = (
    (50, 150, 250, 350, 450),
    (175, 550, 875, 1200, 1600),
    (90, 300, 450, 600, 750),
    (40, 100, 175, 250, 325),
    (33, 68, 101, 144, 199),
    (15, 30, 45, 60, 80),
    (20, 40, 60, 90, 120));
  { Str Int Wis Dex Con Cha }
  classMin: array[0..16, 0..5] of Byte = (
    (6, 6, 9, 0, 0, 0), (0, 0, 12, 0, 0, 15), (9, 0, 6, 6, 7, 0),
    (13, 9, 12, 0, 9, 17), (0, 13, 14, 0, 14, 0), (0, 9, 6, 6, 0, 0),
    (6, 6, 0, 9, 0, 0), (15, 0, 15, 15, 11, 0), (9, 0, 9, 0, 0, 0),
    (9, 9, 9, 0, 0, 0), (0, 13, 14, 0, 14, 0), (0, 9, 9, 0, 0, 0),
    (0, 0, 9, 9, 0, 0), (9, 9, 0, 0, 0, 0), (9, 0, 0, 9, 0, 0),
    (9, 9, 0, 9, 0, 0), (0, 9, 0, 9, 0, 0));
  { Column zero is a count; subsequent columns are alignment IDs }
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
  conBonusTbl: array[3..20] of ShortInt = (
    -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2);
  dsExperienceSpellsClass: array[0..7] of Types.TRuleXp = (
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
  dsStartingGoldClass: array[0..7] of Types.TGoldDice = (
    (num: 3; sides: 6), (num: 3; sides: 6), (num: 5; sides: 4), (num: 5; sides: 4),
    (num: 5; sides: 4), (num: 2; sides: 4), (num: 2; sides: 6), (num: 5; sides: 4));
  { ClassCal: Saving throws indexed by class-level slot (the CLEVEL_ order), level 1..9 and save column 0..4. }
  { class, level, save }
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
  { unused }
  dsUnidentified16: Byte = (0);

var
  { Door-opening flags }
  { Door-opening flags: bash, pick and knock. }
  doorOpen: array[0..2] of Byte;

var
  { Combat round }
  { Set when the party confirms an attack on an ally (CbtActs.CheckAttackAlly) }
  attackedAllies: Byte;
  { Combat round counter, 0-indexed }
  roundCounter: Byte;
  { Potential-target creature indices. }
  dsPotentialTargetCreature: array[1..72] of Byte;
  { Primary and secondary attack counts. }
  attacksMade: array[1..2] of Byte;
  { Hostile creatures' hit points, percent remaining }
  hostileHpPct: Byte;
  { quick combat magic; toggled by Alt-M }
  quickMagic: Boolean;
  { Done flag for the acting creature's attacks; combat menus also return their extended-key flag here }
  doneRoundFlag: Boolean;
  { unused }
  dsUnidentified33: array[0..3] of Byte;
  { The combat moving-icon sheet: CombatSt allocates it, CharHlp copies icon facings in and draws from it, Combat frees
    it }
  dsMoveIconSheet: Types.PImgBuf;

var
  { ECL colour selectors and read registers }
  { Script-controlled wall color; script writes request a view redraw. }
  wallColorSel: Byte;
  { Script-controlled ceiling and floor color; writes request a view redraw. }
  ceilFloorColorSel: Byte;
  { Read-only script register. }
  readReg1: Word;
  { Read-only script register. }
  readReg2: Word;
  { Read-only script register. }
  readReg3: Word;

var
  { ECL interpreter }
  { Top ECL return-stack node. }
  dsEclStackTopPtr: Types.PEclRet;
  { Previous ECL return-stack node. }
  dsEclStackSecondPtr: Types.PEclRet;
  { eq, ne, lt, gt, le, ge; cleared together by FillChar }
  cmpFlags: array[0..5] of Boolean;
  { Previous ECL opcode. }
  prevOpcode: Byte;
  { Current ECL opcode }
  curOpcode: Byte;
  { unused }
  dsUnidentified34: Byte;
  { Current monster ID }
  monId: Byte;
  { Current monster picture ID }
  monPicId: Byte;
  { Current icon animation slot. }
  gIconAnim: Byte;
  { unused }
  dsUnidentified61: array[0..129] of Byte;

var
  { ECL variables and strings }
  { Decoded ECL variable types. }
  dsGbvmType: array[1..64] of Byte;
  { High bytes of decoded ECL variables. }
  dsGbvmUpperByte: array[1..64] of Byte;
  { Low bytes of decoded ECL variables. }
  dsGbvmLowerByte: array[1..64] of Byte;
  { Receives the aim result for the bronze-dragon breath attack. }
  breathAim: Boolean;
  { Loop counter shared by the Blit, Portrait and CbtMap drawing loops; its value means nothing outside them. }
  dsCurrentPictureNumber: ShortInt;
  { Script string buffers. }
  gbStrings: array[1..20] of String;

var
  { ECL monster, write-register and post-combat state }
  { Monster display flags used by the ECL VM; EclVm and EclMenu clear both together }
  dsMonsterFlags: Types.TMonFlags;
  { unused }
  dsUnidentified35: array[0..1] of Byte;
  { Sound effect selected by a script write (EclMenu.WriteGbvm) }
  sndEffect: Word;
  { Script write register; the engine does not read it back. }
  writeReg1: Word;
  { Script write register; the engine does not read it back. }
  writeReg2: Word;
  { Dump the creature at ECL LOAD CHARACTER; set when a script writes 0 to its trigger word (EclMenu.SpecialWriteZ1) }
  dumpCr6C00: Boolean;
  { Dump the creature at ECL LOAD CHARACTER; set when a script writes 0 to its trigger word (EclMenu.SpecialWriteZ1) }
  dumpCr6B00: Boolean;
  duelFlag: Boolean;
  { Count of disabled or Animated creatures, which get no experience share }
  nonAnimCount: Byte;
  { Experience share before individual bonuses. }
  expShare: LongInt;
  combatWon: Boolean;

var
  { ECL flags }
  { ECL script ID }
  eclScriptId: Byte;
  { Backup of the search-mode bit (GBVM_SEARCH_FLAGS bit 0) }
  dsSearchModeFlag: Byte;
  { ECL 3D CLEAR BOX executed flag }
  dsEcl3dClearFlag: Byte;
  protNewLine: Byte;
  { ECL currently displaying graphics flag }
  eclGraphics: Boolean;
  { picture-drawn flag: gates ECL animation }
  picDrawn: Boolean;
  { Set when EclProtection moves its text into the 3D box (after a CLEAR BOX); EclExit then redraws the borders and
    clears it }
  protTextShown: Byte;
  { ECL displaying monster sprite flag }
  sprShown: Boolean;
  { 0 when an ECL script has written a message to the bottom text window; Explore.MapMainMenu clears that window on its
    way out and sets it back to 1 }
  bottomMsgCleared: Byte;
  { Set when a script changes a view colour selector; MapView then applies them }
  picRegionW: Boolean;
  { ECL write moved party flag }
  movedParty: Boolean;
  { Creature list contains hostile monsters flag }
  monstersOn: Byte;
  { Redraw sky/ceiling in 3D view flag }
  redrawSky: Boolean;
  { Currently in ECL opcode 29 ENCOUNTER MENU flag }
  inEncMenu: Byte;
  { Picture id last shown, copied from GBVM_PIC_LOADING }
  picIdShown: Byte;
  { unused }
  dsUnidentified37: Byte;

var
  { Reserved graphics area }
  { FreePtr as GameBoot leaves it at startup }
  dsReservedGraphicalAreaPtr: Pointer;
  { unused }
  dsUnidentified71: array[0..1] of Byte;

implementation

end.
