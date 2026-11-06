{ Types shared between units or used by the game's storage: the character, combat, effect and item records, the GBVM
  zone layouts, and the records behind the rule tables. }
{$F+}
unit Types;

interface

uses C_Gender, C_Save, C_Equip, C_Class, C_Abil, C_Money;

type

  TStr40 = String[40];
  TBaseItemRec = record
    { equip slot }
    slot: Byte;
    { hands required }
    hands: Byte;
    { damage vs large: dice number }
    dmgLgRolls: Byte;
    { damage vs large: dice sides }
    dmgLgDice: Byte;
    { damage vs large: bonus }
    dmgLgMod: ShortInt;
    { ranged rate of fire x2 }
    rateOfFire: Byte;
    { AC adjustment descriptor }
    acDescr: Byte;
    { melee damage type: EffHndlr.SLASHING, PIERCING or BASHING }
    wpnClass: Byte;
    { reserved }
    weaponFlag: Byte;
    { damage vs small/medium: dice number }
    dmgSmRolls: Byte;
    { damage vs small/medium: dice sides }
    dmgSmDice: Byte;
    { damage vs small/medium: bonus }
    dmgSmMod: ShortInt;
    { ranged range (exclusive) }
    range: Byte;
    { class usability bitmask }
    classMask: Byte;
    { weapon-property bitmask; see the PROP_ bits of C_Item and CharHlp.ITEM_PROP_DEX_MISSILE }
    props: Byte;
    { reserved }
    entryTail: Byte;
  end;
  PCharRecord = ^TCharRecord;
  PCombatRec = ^TCombatRec;
  PEffectRec = ^TEffectRec;
  PItemRec = ^TItemRec;
  TIconCols = array[1..6] of Byte;
  TCharRecord = record
    { character name }
    name: string[15];
    case Integer of
      0: (
    { strength }
    strCur: Byte;
    { intelligence }
    intCur: Byte;
    { wisdom }
    wisCur: Byte;
    { dexterity }
    dexCur: Byte;
    { constitution }
    conCur: Byte;
    { charisma }
    chaCur: Byte;
    { exceptional strength (18/xx pct) }
    strExc: Byte;
    { currently memorized }
    memorizedSpells: array[0..20] of Byte;
    { camp writes the hours code 0/4/6, rest counts it down }
    spellPrepTime: Byte;
    { base THAC0 }
    thac0Base: Byte;
    { Race. }
    race: ShortInt;
    charClass: ShortInt;
    age: Word;
    { hit points maximum }
    hpMax: Byte;
    { Known spells, indexed by spell ID. }
    spellsKnown: array[1..56] of Byte;
    attackLevel: Byte;
    iconDimensions: Byte;
    { Saving throws: paralysis, petrification, wand, breath and spell. }
    saves: array[C_Save.PARALYZATION..C_Save.SPELL] of Byte;
    movementBase: Byte;
    { Highest level across the character's classes. }
    levelHighest: ShortInt;
    drainedLevels: Byte;
    drainedHps: Byte;
    { Undead level for turning. }
    levelUndead: ShortInt;
    { Thief skill values. }
    thiefSkills: array[1..8] of Byte;
    { far ptr to effects list }
    effectsAddr: PEffectRec;
    { reserved }
    afterEffects: Byte;
    { packed -- see C_Npc }
    npc: Byte;
    { Low three bits hold the NPC's treasure-share weight. }
    npcTreasureShare: Byte;
    { reserved }
    afterTreasureShare: Byte;
    { reserved }
    beforeCoins: Byte;
    { Coins: copper, silver, electrum, gold, platinum, gems and jewelry. }
    coins: array[C_Money.COPPER..C_Money.JEWELRY] of Word;
    { Class levels; indexed by the C_Class level slots. }
    classLevels: array[C_Class.CLERIC_LEVEL..C_Class.MONK_LEVEL] of ShortInt;
    { Gender; see C_Gender. }
    gender: Byte;
    charType: Byte;
    alignment: Byte;
    { attacks per round }
    attacks: Byte;
    attacks2: Byte;
    { unarmed dice rolls }
    unarmedRollsA: array[1..2] of Byte;
    { unarmed dice sides }
    unarmedDiceA: array[1..2] of Byte;
    { unarmed dmg mods }
    unarmedModA: array[1..2] of ShortInt;
    acBase: Byte;
    { strength to-hit/damage applies }
    useStrength: Byte;
    { Random duplicate-detection key assigned at creation. The roster loader rejects characters whose name and key both
      match a party member. }
    randByte: Byte;
    experience: LongInt;
    itemLimits: Byte;
    hpRolled: Byte;
    { Cleric spell slots by level, including wisdom bonuses. }
    clericSpells: array[1..3] of Byte;
    mageSpells: array[1..3] of Byte;
    xpAward: Word;
    xpBonusPerHp: Byte;
    portraitHead: Byte;
    portraitBody: Byte;
    iconHead: Byte;
    iconBody: Byte;
    orderNumber: Byte;
    iconSize: Byte;
    { Color pairs: body, arm, leg, hair, shield and weapon. }
    iconColors: array[0..5] of Byte;
    numberOfItems: Byte;
    { far ptr to item list }
    itemsAddr: PItemRec;
    { Readied items, indexed by C_Equip. }
    equipped: array[C_Equip.WEAPON..C_Equip.BOLT] of PItemRec;
    handsEquipped: Byte;
    { accumulated save bonus (signed) }
    saveBonus: ShortInt;
    encumbrance: Word;
    { far ptr to next character }
    nextCharAddr: PCharRecord;
    { far ptr to combatant }
    combatAddr: PCombatRec;
    status: 0..127;
    enabled: Byte;
    hostile: ShortInt;
    quickfight: Byte;
    { current THAC0 }
    thac0Cur: Byte;
    { current AC }
    acCur: Byte;
    acBehind: Byte;
    curAttacks: Byte;
    curAttacks2: Byte;
    { current dice rolls }
    curRollsA: array[1..2] of Byte;
    { current dice sides }
    curDiceA: array[1..2] of Byte;
    { current dmg mods }
    curModA: array[1..2] of ShortInt;
    { current hit points }
    hpCur: Byte;
    { current movement }
    movementCur: Byte);
      1: (
    { Current attributes as an array for character creation and display. }
    stats: array[C_Abil.STRENGTH..C_Abil.CHARISMA] of Byte);
      2: (
    { skips to gender }
    beforeGender: array[0..141] of Byte;
    { Signed gender value used to index racial strength limits. }
    genderSp: ShortInt);
      3: (
    { skips to iconColors }
    beforeIconColors: array[0..176] of Byte;
    { One-based icon-color array for character customization and saving. }
    iconColors1: TIconCols);
      4: (
    { skips to clericSpells }
    beforeSlots: array[0..161] of Byte;
    { Spell slots indexed by casting class and level. }
    slots: array[0..1, 1..3] of Byte);
      5: (
    { skips to gender }
    beforeGenderIdx: array[0..141] of Byte;
    { gender as a 0..127 subrange -- ViewChar indexes genderNames with it }
    genderIdx: 0..127;
    { charType }
    charTypeIdx: Byte;
    { alignment as a 0..127 subrange -- ViewChar indexes alignNames with it }
    alignmentIdx: 0..127);
      6: (
    { skips to acCur }
    beforeAcCurArr: array[0..256] of Byte;
    { Current and rear armor class. }
    acCurArr: array[0..1] of Byte;
    { curAttacks and curAttacks2, by attack phase }
    curAttacksArr: array[1..2] of Byte);
  end;
  TCombatRec = record
    { spell being cast }
    spellCast: Byte;
    { may cast this round }
    castAllowed: Byte;
    { may use an item this round }
    itemUseAllowed: Byte;
    { signed (Combat.NextCreature and CreatureAction compare signed); cleared on death and by EndActions }
    initiative: ShortInt;
    attackPhase: Byte;
    { sweep allowance (attackLevel) }
    sweepBudget: Byte;
    { movement left this round }
    movement: Byte;
    { guarding flag }
    guarding: Byte;
    madeAttack: Byte;
    { facing 0..7 }
    direction: Byte;
    { opponent/target }
    other: PCharRecord;
    { damage past 0 hp (dying) }
    overkill: Byte;
    { attackers this round }
    flankCount: Byte;
    { undead-turned flag }
    turned: Byte;
    usedTurnUndead: Byte;
    { summed offset from facing, mod 8 }
    flankSpread: Byte;
    notPcNpc: Byte;
    fleeing: Byte;
    { AI approach-pattern index 1..6 }
    aiStance: Byte;
  end;
  TDownedRec = record
    { the downed creature }
    cr: PCharRecord;
    { Corpse cell coordinates. }
    x: ShortInt;
    y: ShortInt;
    { cell terrain saved from under it }
    terrain: Byte;
  end;
  TEffectRec = record
    { effect id }
    id: Byte;
    { minutes; 0 = permanent -- blood drain packs a damage budget in the upper bits }
    duration: Word;
    { strength; handlers pack flags in the nibbles, and the hold family stores a creature index here }
    strength: Byte;
    { removal calls the handler }
    onRemove: Boolean;
    { next effect }
    next: PEffectRec;
  end;
  { One line of a list MenuCore.MenuVertical shows. Its fields are the leading fields of TItemRec, so an item list is
    shown in place and a line that is never an item is allocated at this size. }
  TMenuNode = record
    { the line's text }
    name: string[40];
    { Nonzero marks a menu-list title. }
    inUse: Byte;
    { the next line, nil after the last }
    next: PItemRec;
  end;
  TItemRec = record
    { item name }
    name: string[40];
    { Nonzero marks a menu-list title; zero for inventory items. }
    inUse: Byte;
    { next item in inventory list }
    next: PItemRec;
    { base-item index (into baseItems) }
    itemType: Byte;
    { identified name components [1]=component 3, [2]=2, [3]=1 }
    nameIds: array[1..3] of Byte;
    { magical bonus }
    plus: ShortInt;
    { saving throw bonus }
    saveBonus: ShortInt;
    { 0 = unequipped, 1 = equipped }
    equipped: Byte;
    { Unidentified name-component mask. }
    unidMask: Byte;
    cursed: Byte;
    { weight in coins }
    weight: Word;
    { 0 = single, non-stacking }
    quantity: Byte;
    { value in gold pieces }
    value: Word;
    case Integer of
      0: (
        { properties (scroll spells / charges) }
        charges: Byte;
        { effect id }
        effect: Byte;
        { special-item id }
        special: Byte);
      1: (
        { scroll spell slots }
        spells: array[1..3] of Byte);
  end;
  PBytes = ^TBytes;
  PImgBuf = ^TImgBuf;
  TArenaLoc = record
    { Arena coordinates. }
    x: ShortInt;
    y: ShortInt;
    { Registration slot stored by CombatSt. }
    slotIndex: Byte;
    { icon footprint, zero marks out of play }
    size: Byte;
  end;
  { constant rowBand entries }
  TBandRec = record
    { valid row range }
    lo: ShortInt;
    hi: ShortInt;
  end;
  TBrkSet = set of ' '..'?';
  TBytes = array[0..65000] of Byte;
  { main-menu entry }
  TMenuItem = record
    { first character is the hotkey }
    name: string[40];
    { MainMenu updates availability }
    enabled: Byte;
  end;
  TColorMap = array[0..7] of Byte;
  TColorTab = array[0..15] of Byte;
  TCombatTarget = record
    { arena registration index }
    idx: Byte;
    { doubled walk distance from the acting creature }
    dist: Byte;
    { best facing direction }
    dir: Byte;
  end;
  TIconCoordinateDelta = record
    { cell X offset; negative marks an absent footprint cell }
    dx: ShortInt;
    { cell Y offset }
    dy: ShortInt;
  end;
  TImgBuf = record
    { image height in pixels }
    height: Word;
    { image width in CHARS (x8 for pixels) }
    width: Word;
    { image placement X from DAX header }
    originX: Word;
    { image placement Y from DAX header }
    originY: Word;
    { images in buffer }
    count: Byte;
    { EGA->CGA color map }
    map: TColorMap;
    { bytes in one image }
    imgSize: Word;
    { extra transparency space (default nil) }
    transp: PBytes;
    { image data (open-ended) }
    data: array[0..32000] of Byte;
  end;
  TName15 = string[15];
  TRandomItemTemplate = record
    { low bytes copied to TItemRec nameIds (components 3, 2, 1) }
    nameIds: array[1..3] of Word;
    { copied to TItemRec weight (coins) and value (gold pieces) }
    weight: Word;
    value: Word;
    { low bytes copied to TItemRec charges/effect/special }
    properties: array[1..3] of Word;
  end;
  TWordBytes = record
    lo: Byte;
    hi: Byte;
  end;
  { The random item templates, which GenerateRandomItem also reads as one run of words, and of their low bytes, from a
    one-based word index. Template n starts at word 8n - 7; word 144 is not a template start: it spans the last word of
    template 18 and the first seven of template 19. }
  TRandomItemTable = record
    case Byte of
      0: (templates: array[1..19] of TRandomItemTemplate);
      1: (words: array[1..152] of Word);
      2: (wordBytes: array[1..152] of TWordBytes);
  end;
  TRuleXp = record
    { XP to reach level; -1 = unavailable }
    xp: array[2..9] of LongInt;
    { class level, spell level }
    slots: array[2..9, 1..3] of Byte;
  end;
  TSpecLoc = record
    x: Word;
    y: Word;
    icon: Word;
  end;
  TTerrainRec = record
    { movement cost multiplier and passability threshold }
    cost: Byte;
    { initial line-walk clearance }
    clearance: Byte;
    { compared against line-walk clearance }
    blocking: Byte;
    { combat tile graphic index }
    tileId: Byte;
  end;
  TTurnUndeadTable = array[1..10, 1..10] of ShortInt;
  TViewSlotGeom = record
    start: array[0..9] of Byte;
    cols: array[0..9] of Byte;
    rows: array[0..9] of Byte;
    xCol: array[0..9] of Integer;
    yRow: array[0..9] of Integer;
  end;
  TWallSetCacheSlot = record
    { cached WALLDEF reload ID; -1 invalidates the slot }
    wallDefId: Integer;
    { destination 8x8 slot, also invalidated with -1 }
    symbolSlot: Integer;
  end;
  { The party's position: GameInit clears it and SaveLoad saves and restores it as one block. }
  TPartyPosition = record
    { The party's map column; signed for the edge and wrap checks. }
    mapX: ShortInt;
    { The party's map row. }
    mapY: ShortInt;
    { The party's facing. }
    facing: Byte;
    { The wall in front of the party on its square. }
    wallAhead: Byte;
    { The event byte of the party's square; bit 7 is a flag, not a wall. }
    eventAtCell: Byte;
  end;

  { GBVM zone types. }
  { A seven-word GBVM clock. }
  TClock = array[0..6] of Word;
  TGbvmClock = packed record
    case Byte of
      0: (values: TClock);
      1: (segment: Word; minute: Word; turn: Word; hour: Word; day: Word; month: Word; year: Word);
  end;
  TGbvmSavedWalls = packed record
    wallSetIds: array[1..3] of Word;
    symbolSlots: array[1..3] of Word;
  end;
  TGbvmWord = packed record
    case Byte of
      0: (value: Word);
      1: (lo: Byte; hi: Byte);
  end;
  TGbvmZone0 = array[$4900..$4CFF] of Word;
  TGbvmZone0State = packed record
    case Byte of
      0: (words: TGbvmZone0);
      1: (bytes: array[0..2047] of Byte);
      2: (
        scriptWordsBeforePartyX: array[$4900..$49C2] of Word;
        partyX: TGbvmWord;
        partyY: TGbvmWord;
        mapId: TGbvmWord;
        clock: TGbvmClock;
        scriptWordsAfterClock: array[$49CD..$49E4] of Word;
        { Nonzero forbids spellcasting here. }
        antimagic: Word;
        { Nonzero when a 3D map is loaded, including indoor areas and town streets; zero in the wilderness. This selects
          wall graphics or the wilderness backdrop. }
        view3dFlag: Word;
        mapGraphics1: Word;
        { With mapGraphics1, controls the combined wall load. }
        mapGraphics2: Word;
        scriptWordsAfterMapGraphics: array[$49E9..$49EF] of Word;
        previousX: Word;
        previousY: Word;
        previousScriptId: Word;
        scriptWordsAfterPreviousScript: array[$49F3..$49FA] of Word;
        { 1 disables the automap. }
        noAutomap: Word;
        gameSpeed: TGbvmWord;
        skyCeilingColor: Word;
        alternateSkyColor: Word;
        { Twice the monster-picture flag plus the portrait flag. }
        settings: Word;
        { Cleared on a fresh script entry. }
        entryWords: array[$4A00..$4A1F] of Word;
        scriptWordsAfterEntry: array[$4A20..$4A7B] of Word;
        { Bit 3 enables the camp icon. }
        nomadCampFlags: Word;
        scriptWordsAfterCampFlags: array[$4A7D..$4A8B] of Word;
        buccaneersBaseGate: Word;
        scriptWordsAfterBaseGate: array[$4A8D..$4A9E] of Word;
        { Zero enables the camp icon. }
        nomadCampGate: Word;
        { Bits 0 and 1 hide the keep and caves. }
        easternSitesGate: Word;
        scriptWordAfterSitesGate: Word;
        { Quest: the party left the Yarash pyramid, cleared. }
        yarashPyramidLeft: Word;
        scriptWordsAfterPyramidLeft: array[$4AA3..$4AB2] of Word;
        { Quest: the Yarash mission succeeded. }
        yarashMissionDone: Word;
        scriptWordsAfterMissionDone: array[$4AB4..$4AD1] of Word;
        { Nonzero enables the camp icon. }
        nomadCampPresent: Word;
        scriptWordsAfterCampPresent: array[$4AD3..$4AF9] of Word;
        savedWalls: TGbvmSavedWalls;
        scriptWordsAfterSavedWalls: array[$4B00..$4CFF] of Word);
  end;
  TGbvmZone1 = array[$6B00..$6EFF] of Word;

  { Blit types. }
  TVideoMode = (Cga, Ega, Tandy);

  { Border types. }
  TCgaBank = array[0..99] of array[0..79] of Byte;
  TTandyBank = array[0..49] of array[0..159] of Byte;

  { Camp types. }
  PZone0State = ^TGbvmZone0State;

  { CbtMap types. }
  PArena = ^TArena;
  TArena = record
    { reserved }
    header: Byte;
    headerTail: Byte;
    { Upper-left cell of the view. }
    ox: ShortInt;
    oy: ShortInt;
    { draw the cursor sprite }
    cursorOn: Boolean;
    { cursor icon size }
    cursorSize: Byte;
    { line-walk distance mode (Pathing.WalkLine) }
    distMode: Byte;
    { terrain-info indices }
    cells: array[0..24, 0..49] of Byte;
  end;

  { CharGen types. }
  { startingAge entries }
  TRuleAge = record
    { years before the dice roll }
    base: Word;
    { dice count }
    num: Byte;
    { dice sides }
    sides: Byte;
  end;
  { startingGold entries }
  TRuleGold = record
    { CharGen awards ten gold per point, averaged over the classes }
    num: Byte;
    sides: Byte;
  end;
  { racial ability limits (GDConsts.raceStatLimits) }
  TRuleRace = record
    { by gender }
    strMin: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    strMax: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    { exceptional-Str cap }
    excMax: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;

  { Spell and downed-record types. }
  TSpellRec = record
    case Integer of
      0: (
        { 0 cleric / 1 mage / 2 item/special }
        castClass: Byte;
        { spell level }
        level: Byte;
        { base range, 255 = attack roll }
        rangeFixed: Byte;
        { range per caster level }
        rangeVar: Byte;
        { base duration }
        durFixed: Byte;
        { duration per caster level }
        durVar: Byte;
        { packed: low nibble area mode, high nibble radius }
        area: Byte;
        { targeting mode }
        target: Byte;
        { saving-throw result; Magic reads it as Boolean saveEffect }
        saveResult: Byte;
        { saving-throw column 0..4 }
        saveType: Byte;
        { effect id added on a hit }
        effect: Byte;
        { 0 noncombat / 1 combat / 2 either }
        whenCast: Byte;
        { casting time }
        castTime: Byte;
        { 0..7, 0 = AI never casts }
        aiPriority: Byte;
        { 1 = offensive }
        offensive: Byte;
        { friendly-fire scan radius }
        aiRadius: Byte);
      1: (
        { Signed class and level view. }
        castClassSp: ShortInt;
        levelSp: ShortInt);
      2: (
        { castClass..target }
        savePrefix: array[0..7] of Byte;
        { Boolean view of saveResult }
        saveEffect: Boolean);
  end;

  { Combat types. }
  PZone1 = ^TGbvmZone1;

  { CombatSt types. }
  TPortSlot = record
    pictureId: Byte;
    pic: PImgBuf;
  end;

  { DaxIo types. }
  PByteArr = ^TByteArr;
  TByteArr = array[0..65534] of ShortInt;

  { EclMenu types. }
  PEclRet = ^TEclRet;
  PZone2 = ^TZone2;
  PZone3 = ^TZone3;
  TEclRet = record
    { return GBVM address }
    addr: Word;
    { node below }
    next: PEclRet;
  end;
  TMonFlags = array[0..1] of Boolean;
  TZone2 = array[$9700..$98FF] of Word;
  TZone3 = array[$9900..$B6FF] of Byte;

  { EffHndlr types. }
  TEffectHandler = procedure(creature: PCharRecord; effectData: Pointer;
                             removed: Boolean);

  { GameBoot types. }
  PFreeRange = ^TFreeRange;
  TFreeRange = record
    rangeStart: Pointer;
    rangeEnd: Pointer;
  end;

  { Money types. }
  TMoney = array[C_Money.COPPER..C_Money.JEWELRY] of LongInt;

  { Pathing types. }
  TPathReq = record
    { start / end points }
    sx: Integer;
    sy: Integer;
    ex: Integer;
    ey: Integer;
    { Bresenham error term }
    err: Integer;
    { horizontal extent of the line }
    adx: Integer;
    { vertical extent of the line }
    ady: Integer;
    { error bump on a diagonal step }
    incD: Integer;
    { error bump on a straight step }
    incS: Integer;
    { x step sign (-1/0/1) }
    stepX: ShortInt;
    { y step sign (-1/0/1) }
    stepY: ShortInt;
    { Current line position. }
    cx: Integer;
    cy: Integer;
    { doubled distance walked }
    dist: Byte;
    { direction of last step (0..8) }
    step: Byte;
  end;

  { Portrait types. }
  TAnimFrame = record
    { How long the frame stays up, from the file. }
    time: LongInt;
    pic: PImgBuf;
  end;
  TAnimRec = record
    { frames actually loaded }
    count: Byte;
    { Frame shown, counting from 1; LoadAnimation sets it to 1 and the animation loops advance it. }
    current: Byte;
    frames: array[1..8] of TAnimFrame;
  end;
  TStr8 = String[8];

  { Magic types. }
  PStinkRec = ^TStinkRec;
  TCastUi = procedure(spell: Byte; b: Boolean; var sel: Boolean);
  TSpellProc = procedure;
  { The spell handlers: the target picker the casting code calls, then the handler of each spell. }
  TSpellHandlers = record
    castTargets: TCastUi;
    spells: array[1..67] of TSpellProc;
  end;
  TStinkRec = record
    caster: PCharRecord;
    next: PStinkRec;
    under: array[1..4] of Byte;
    exists: array[1..4] of Byte;
    { target X }
    ulX: ShortInt;
    { target Y }
    ulY: ShortInt;
    { caster cloud # }
    idx: Byte;
  end;

  { TextRend types. }
  PFontArr = ^TFontArr;
  TFontArr = array[0..176] of array[0..7] of Byte;

  { View3D types. }
  PGeoMap = ^TGeoMap;
  PWallGfx = ^TWallGfx;
  TGeoPlane = array[0..15, 0..15] of Byte;
  TGeoMap = record
    { N = high nibble, E = low }
    wallsNorthEast: TGeoPlane;
    { S = high nibble, W = low }
    wallsSouthWest: TGeoPlane;
    events: TGeoPlane;
    { 2 bits per facing }
    barriers: TGeoPlane;
  end;
  TView3dWallDef = array[1..5, 0..155] of Byte;
  TWallDefs = array[1..3] of TView3dWallDef;
  TWallSlices = array[1..15, 0..155] of Byte;
  { The wall graphics: three wall definitions of five slices each, which the 3D view draws as fifteen slices. }
  TWallGfx = record
    case Integer of
      0: (defs: TWallDefs);
      1: (slices: TWallSlices);
  end;

type
  TWheelRec = record
    answer: String[6];
    { Outer-ring rune pair. }
    espruar: array[1..2] of Byte;
    { Inner-ring rune pair; C_Rune.NONE omits the second glyph. }
    dethek: array[1..2] of Byte;
    path: String[9];
  end;

  { The register block for software interrupts, laid out as Dos.Registers so storage can hold one without using Dos;
    callers pass it to Intr as a Registers. }
  TRegisters = record
    case Integer of
      0: (ax: Word;
          bx: Word;
          cx: Word;
          dx: Word;
          bp: Word;
          si: Word;
          di: Word;
          ds: Word;
          es: Word;
          flags: Word);
      1: (al: Byte;
          ah: Byte;
          bl: Byte;
          bh: Byte;
          cl: Byte;
          ch: Byte;
          dl: Byte;
          dh: Byte);
  end;

implementation

end.
