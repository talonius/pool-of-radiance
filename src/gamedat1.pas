{ Game data, part 1 of 5: name strings, play session, video, sound and disk state, one section per subsystem. }
unit GameDat1;

interface

uses Types, Dos, C_Gender, C_Class, C_Race, C_Status, C_Align, C_Dir, C_Money;

const
  { Character, money and item name strings; compass names }
  { Coin values in copper: copper 1, silver 10, electrum 100, gold 200, platinum 1000. Note: when the purse runs short,
    CharGen.TakeCoins indexes past the five rates into classNames, so keep classNames right after this table. }
  dsCoinValuationCopper: array[C_Money.MONEY_COPPER..C_Money.MONEY_PLATINUM] of LongInt = (
    1, 10, 100, 200, 1000);
  { Class names, indexed by TCharRecord.charClass. }
  classNames: array[C_Class.CLASS_CLERIC..C_Class.CLASS_MAGE_THIEF] of string[26] = (
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
  raceNames: array[C_Race.RACE_MONSTER..C_Race.RACE_HUMAN] of string[9] = (
    'Monster',
    'Dwarf',
    'Elf',
    'Gnome',
    'Half-Elf',
    'Halfling',
    'Half-Orc',
    'Human');
  { Alignment names, indexed by TCharRecord.alignment. }
  alignNames: array[C_Align.ALIGN_LAWFUL_GOOD..C_Align.ALIGN_CHAOTIC_EVIL] of string[16] = (
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
  genderNames: array[C_Gender.GENDER_MALE..C_Gender.GENDER_FEMALE] of string[6] = (
    'Male',
    'Female');
  { Money names, indexed like TCharRecord.coins and TMoney. }
  moneyNames: array[C_Money.MONEY_COPPER..C_Money.MONEY_JEWELRY] of string[10] = (
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Gems',
    'Jewelry');
  { Status names, indexed by TCharRecord.status; see the STATUS_ constants. }
  statusStrs: array[C_Status.STATUS_OKAY..C_Status.STATUS_GONE] of string[12] = (
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

const
  { clockwise facing codes 0..7, starting at north }
  dirNames: array[C_Dir.DIR_NORTH..C_Dir.DIR_NORTHWEST] of string[2] = (
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW');

const
  { Text-mode colour and pixel tables; EGA plane and CGA pixel tables; icon colour map }
  { Direction code for a one-cell step, indexed [dy + 1, dx + 1]; the center entry (DIR_CENTER) means no movement. }
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
    { EGA 0 Black -> CGA colour 0 }
    0,
    { EGA 1 Blue -> CGA colour 0 }
    0,
    { EGA 2 Green -> CGA colour 0 }
    0,
    { EGA 3 Cyan -> CGA colour 1 }
    1,
    { EGA 4 Red -> CGA colour 2 }
    2,
    { EGA 5 Magenta -> CGA colour 2 }
    2,
    { EGA 6 Brown -> CGA colour 2 }
    2,
    { EGA 7 LightGray -> CGA colour 3 }
    3,
    { EGA 8 DarkGray -> CGA colour 3 }
    3,
    { EGA 9 LightBlue -> CGA colour 1 }
    1,
    { EGA 10 LightGreen -> CGA colour 1 }
    1,
    { EGA 11 LightCyan -> CGA colour 1 }
    1,
    { EGA 12 LightRed -> CGA colour 2 }
    2,
    { EGA 13 LightMagenta -> CGA colour 2 }
    2,
    { EGA 14 Yellow -> CGA colour 3 }
    3,
    { EGA 15 White -> CGA colour 3 }
    3);
  { One mask per 2-bit pixel position within a CGA pixel word, high pair first. Blit uses them to isolate, place and
    reflect CGA pixels; TextRend.RenderChar uses them to draw characters. }
  cgaPixelMask: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003);

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
  dsIconColorMap: Types.TColorMap = (
    { EGA 0 Black -> CGA 0; EGA 1 Blue -> CGA 0 }
    $00,
    { EGA 2 Green -> CGA 1; EGA 3 Cyan -> CGA 1 }
    $11,
    { EGA 4 Red -> CGA 2; EGA 5 Magenta -> CGA 2 }
    $22,
    { EGA 6 Brown -> CGA 1; EGA 7 LightGray -> CGA 2 }
    $12,
    { EGA 8 DarkGray -> CGA 0; EGA 9 LightBlue -> CGA 0 }
    $00,
    { EGA 10 LightGreen -> CGA 2; EGA 11 LightCyan -> CGA 1 }
    $21,
    { EGA 12 LightRed -> CGA 3; EGA 13 LightMagenta -> CGA 0 }
    $30,
    { EGA 14 Yellow -> CGA 3; EGA 15 White -> CGA 3 }
    $33);

const
  { Sound command tables }
  { One table of sound command ids: the three subsystems read their own slice; Magic indexes all of it as
    soundIds[0..12]. }
  soundIds: record
    commands: array[0..3] of Word;
    damage: Word;
    combat: array[0..10] of Word;
  end = (
    commands: (255, 0, 1, 2);
    damage: 3;
    combat: (4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14));

const
  { Insert-disk prompts }
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

var
  { Play session }
  { nonzero makes HeapErr force a save; never set }
  heapFailureSaveEnabled: Byte;
  { GameBoot writes 0/1, Intro tests zero }
  fullIntro: Byte;
  { word bank }
  zone0: Types.PZone0State;
  { GBVM zone 1, indexed directly by GBVM address (the zone-1 GBVM_ constants) }
  { word bank }
  zone1: Types.PZone1;
  { word bank }
  zone2: Types.PZone2;
  { script bytes }
  zone3: Types.PZone3;
  { game speed, 0 = fastest 9 = slowest; SaveLoad keeps it in the GBVM gameSpeed word }
  gameDelay: Byte;
  { Five GBVM addresses loaded from the ECL entry header. [1] runs before movement and after on-load; [2] search/Look;
    [3] pre-camp; [4] camp interruption; [5] on-load }
  { ECL entry GBVM addresses }
  scriptEntryAddrs: array[1..5] of Word;
  { ECL instruction pointer into zone3 }
  eclIp: Word;
  { reserved }
  dsUnidentified20: array[0..3] of Byte;
  { Interface state, one of the IFC_ constants of C_Ifc and Ending }
  ifcState: Byte;
  { nonzero suppresses Combat's Continue Battle prompt }
  suppressContinuePrompt: Byte;
  { zero disables ViewChar's disk-3 portrait branch }
  portraitsOn: Byte;
  { zero skips the close-up load when GameDat5.inEncMenu is nonzero }
  monsterPics: Byte;
  { GameInit clears it; GameIo toggles it on STING Ctrl-D; nonzero enables PrintHpDebug }
  stingHpFlag: Byte;
  { main-menu load handoff; EclVm skips reload, EclMenu clears it }
  loadedSave: Byte;
  { Party location type, previous (as below) }
  locTypePrev: Byte;
  { Party location type, current }
  gLocType: Byte;
  { Uninterrupted resting time when disturbable }
  restTicks: Word;
  { Portrait head ID. }
  dsCurrentPortraitHead: Byte;
  { Portrait body ID. }
  dsCurrentPortraitHead2: Byte;
  partyDefeated: Boolean;
  { Delay in printing message to message window }
  msgDelayFlag: Byte;

var
  { Video registers, pages and modes; view and icon buffers, dirty spans and row tables }
  { Register record handed to Dos.Intr for BIOS video calls; every unit calling the BIOS uses this one record. }
  dsInterruptRegisters: Registers;
  { EGA video memory segment for currently displayed page }
  egaCurPage: Word;
  egaOtherPage: Word;
  { Other EGA page number (always 0) }
  pageNum: Byte;
  { Currently displayed EGA page number (always 0) }
  pageMain: Byte;
  { BIOS mode queried at init, then the mode active before the latest Blit.SetVideoMode call; RestoreVideoMode returns
    to it. }
  savedVideoMode: Byte;
  { BIOS mode queried at init, then the mode most recently requested through Blit.SetVideoMode. }
  curVideoMode: Byte;
  { Video mode (line 1 in POOL.CFG) }
  videoMode: Byte;

var
  { Off-screen 168x168 view buffer that the compositors draw into and Blit.FlushView copies to the screen; GameInit
    allocates it. }
  dsViewImageBufferPtr: Types.PImgBuf;
  { Backdrop buffer that Blit.BlitTileClipped fills with the destination bytes it is about to cover (when the save flag
    is set), so CharHlp can restore the background afterwards. }
  dsIconImageBufferPtr: Types.PImgBuf;
  { Dirty-span tables, one slot per view scanline (21 character rows x 8 = 168); GameInit initializes all four. }
  { Nonzero when that view scanline holds changes that Blit.FlushView still has to copy to the screen. }
  spanActive: array[0..167] of Byte;
  { Horizontal byte offset in video memory where the dirty span begins; the screen-side counterpart of spanFirstOfs. }
  spanScreenOfs: array[0..167] of Word;
  { Offset of the first dirty byte in the view buffer's image data. Reset to $FFFF when clean so any new span compares
    as earlier. }
  spanFirstOfs: array[0..167] of Word;
  { Offset of the last dirty byte (inclusive) in the view buffer's image data. Reset to 0 when clean so any new span
    compares as later. }
  spanLastOfs: array[0..167] of Word;
  { Video segment for each CGA scanline, precomputed so row writes need no bank arithmetic: even and odd rows interleave
    between the B800 and BA00 banks. }
  cgaRowSeg: array[0..199] of Word;
  { Offset into the EGA video segment for each scanline; rows are 40 bytes apart. }
  fbRowOfs: array[0..199] of Word;
  { Video segment for each Tandy scanline, precomputed like cgaRowSeg. }
  tandyRowSeg: array[0..199] of Word;
  { Nonzero makes Blit.BlitTileClipped clip against the destination bounds; zero trusts the caller to have kept the tile
    inside. GameInit initializes it to 1. }
  clipFlag: Byte;

var
  { Sound mode }
  { Active sound device; GameBoot maps POOL.CFG line 2: 'T' = 0, 'P' = 1, else 2. }
  soundMode: Byte;
  { Copy of soundMode taken at suspend so the configured mode is not lost. }
  soundSaved: Byte;
  { Nonzero: SoundDrv.SoundCommand waits a fixed delay after each command, then silences the voices and removes its
    timer. Zero leaves the timer driver resident for persistent playback. }
  soundAutoStop: Word;

var
  { Disks, directories and the DAX buffer }
  { current resource disk; saved by SaveLoad }
  virtualDisk: Byte;
  { disk saved by DaxIo.PushState for PopState }
  prevVirtualDisk: Byte;
  { GameInit sets it to 1; otherwise unused }
  unidentified02: Word;
  { Save directory from line 4 of POOL.CFG. }
  dsSaveDirectory: String[255];
  { GameInit sets it to 1; otherwise unused }
  unidentified03: Word;
  { POOL.CFG line 3, the game directory; gameDir[1] is its drive letter }
  gameDir: String;
  { Flag for suppressing insert disk prompt }
  dsSuppressingInsertDiskFlag: Byte;
  { Set by SaveLoad once a save completes; HeapErr and the Exit to DOS loop use it to tell whether a save succeeded. }
  recentSaved: Byte;
  { Temporary compressed DAX data buffer. }
  dsDaxCompressedFilePtr: Types.PByteArr;

implementation

end.
