{ Global variables: the game's variables in storage order, grouped in sections by subsystem. A new section starts
  wherever the data needs a word boundary. }
unit GDVars;

interface

uses Types, C_Effect;

{ Script interpreter run state, combat results and the combat AI's movement state. }
var
  { Set to stop the script interpreter and hand control back to the player. }
  eclStop: Byte;
  { Set by NEWECL; the game loop then calls NewEclDone. }
  newEclFlag: Byte;
  { Set by LOAD CHARACTER, so that curChar is restored from savedChar afterwards. }
  restoreChar: Byte;
  { Set once LOAD FILES or LOAD PIECES has run, whether or not the load succeeded. }
  filesLoaded: Byte;
  { Set while the first LOAD FILES and LOAD PIECES pair of an area still has to draw the interface. }
  enteringLoop: Byte;
  { Set once LOAD PIECES has run, whether or not the load succeeded. }
  piecesLoaded: Byte;
  { Set once LOAD FILES has run, whether or not the load succeeded. }
  mapLoaded: Byte;
  { Monsters added by LOAD MONSTER since CLEAR MONSTERS; LOAD MONSTER stops adding at 63. }
  creatureCnt: Byte;
  { The current character saved before a script step or LOAD CHARACTER, restored into curChar afterwards. }
  savedChar: Types.PCharRecord;
  { Set by DetermineLootExp when it finds a hostile that did not run away; the summary then reports a win. }
  nonEscapedHostileFound: Boolean;
  { Set by DetermineCombatResults when a party member ran and no member is still standing. }
  partyFled: Boolean;
  { Direction of the AI's last step this turn; 8 before the first step. }
  lastMoveDir: Byte;
  { Times this turn the AI reversed direction or found no way forward. }
  stuckCount: Byte;
  { Cleared at the start of each move and attack loop; never read. }
  aiMoveState: Byte;

{ Combat placement: the free placement quads and the grid origin of each team. }
var
  { Placement quads by team (0 = party, 1 = hostiles), ring 0..3, quad row and quad column; 1 while the quad is free. }
  quadFree: array[0..1, 0..3, 0..5, 0..10] of Byte;
  { Each team's grid origin across, in cells from the party: 0 for the party, the monster distance along the party's
    facing for the hostiles. }
  placeX: array[0..1] of ShortInt;
  { Each team's grid origin down, in cells from the party, set like placeX. }
  placeY: array[0..1] of ShortInt;
  { Length of each team's first placement leg: half the team's size, rounded up. }
  teamRows: array[0..1] of ShortInt;
  { The quadrant each team faces, 0..3: the party's facing halved for the party, the opposite facing for the hostiles. }
  teamDir: array[0..1] of ShortInt;
  { The team being placed. }
  team: ShortInt;

{ Wilderness combat terrain. }
var
  { The wilderness map cell under the party, which picks the terrain of a wilderness arena. }
  terrainChar: Byte;

{ Start-up loop counter. }
var
  { InitializeGame's loop counter for the scanline tables. }
  gi2: Byte;

{ Start-up resource loading and the STING training override. }
var
  { unused }
  maskIdx: Word;
  { Whether OpenWithRetry found the ITEMS file. }
  itemsOk: Boolean;
  { The directory to return to once the resources are loaded. }
  savedDir: String[40];
  { unused }
  savedDirTail: array[0..1] of Byte;
  { The ITEMS file while it is read. }
  itemsFile: file;
  { Nonzero once J is chosen at the main menu with STING on the command line; training then skips its checks. }
  stingMode: Byte;

{ The end-game pictures. }
var
  { The FINAL picture being shown; WinGame hands it to Blit.LoadPic. }
  finalPic: Types.PImgBuf;
  { ifcState saved while the end-game pictures run. }
  savedIfc: Byte;
  { The virtual disk digit appended to the FINAL picture names. }
  finalSfx: String[1];

{ Character menus, timed effects, spell and scroll selection, the configuration file, the play session, the GBVM zones,
  the interface state and the video registers. }
var
  { The character DisplayChar shows, saved while it runs. }
  tempCr1: Types.PCharRecord;
  { The character chosen to trade with; reset when ViewCharMenu opens. }
  tempCr2: Types.PCharRecord;
  { Creatures whose timed effects need processing, by place in the creature list. }
  effFlags: array[1..72] of Byte;
  { The spell menu's entries, built by GenerateSpellList and freed when the menu closes. }
  spellList: Types.PItemRec;
  { The spell id of each spell menu line. }
  spellIds: array[0..20] of Byte;
  { The item each scroll spell menu line comes from, so the chosen line's scroll becomes castItem. }
  scrollPtrs: array[0..48] of Types.PItemRec;
  { Lines filled in scrollPtrs. }
  scrollCount: Byte;
  { Working value of the spell being resolved: the Strength that Strength sets, the hit dice Sleep has left, the hit
    points Snake Charm has left. }
  spellScratch: Byte;
  { Second working value of the spell being resolved: the exceptional Strength that Strength sets, the cost of the
    creature Sleep is trying. }
  spellScratch2: Byte;
  { Weight of the current character's readied items. }
  equippedWeight: Word;
  { Where GameBoot moves the heap's free-list record when it reserves Tandy graphics memory below FreePtr. }
  gfxRelocDest: Types.PFreeRange;
  { A character read from POOL.CFG or the keyboard while the configuration is read. }
  cfgChar: Char;
  { POOL.CFG, read line by line. }
  cfgText: Text;
  { POOL.CFG, opened to see whether it exists. }
  cfgFile: file;
  { IOResult of opening POOL.CFG. }
  cfgErr: Byte;
  { IOResult of DaxIo.FileExists. }
  ioErr: Integer;
  { False stops the title sequence after its first picture (POOL.CFG line 5 is not 'F'). }
  fullIntro: Boolean;
  { GBVM word bank 0. }
  zone0: Types.PZone0State;
  { GBVM word bank 1, indexed directly by GBVM address (the zone-1 C_Gbvm constants). }
  zone1: Types.PZone1;
  { GBVM word bank 2. }
  zone2: Types.PZone2;
  { The running area script's bytes. }
  zone3: Types.PZone3;
  { Game speed, 0 fastest to 9 slowest; SaveLoad keeps it in the GBVM gameSpeed word. }
  gameDelay: Byte;
  { The five entry points from the script header: [1] runs before each move and after on-load, [2] on search and Look,
    [3] before camp, [4] when camp is interrupted, [5] on load. }
  scriptEntryAddrs: array[1..5] of Word;
  { The script interpreter's instruction pointer into zone3. }
  eclIp: Word;
  { reserved }
  eclIpTail: array[0..3] of Byte;
  { Interface state: one of the C_Ifc constants, or Ending.IFC_WON_GAME. }
  ifcState: Byte;
  { Nonzero suppresses Combat's Continue Battle prompt. }
  suppressContinuePrompt: Byte;
  { Zero turns off the portraits ViewChar draws from disk 3. }
  portraitsOn: Byte;
  { Zero skips the monster close-up while an ENCOUNTER MENU is up (inEncMenu). }
  monsterPics: Byte;
  { Nonzero makes Debug.PrintDebug show hit points; GameIo toggles it on STING Ctrl-D and GameInit clears it. }
  stingHpFlag: Byte;
  { Set when the main menu has just loaded a saved game, so EclVm does not reload the area; EclMenu clears it. }
  loadedSave: Byte;
  { The party's location type before the last change of area. }
  locTypePrev: Byte;
  { The party's location type, one of the C_Area LOC_ constants. }
  locType: Byte;
  { Rest time without an interruption, counted against the GBVM's safe-rest time. }
  restTicks: Word;
  { Portrait head id. }
  portraitHead: Byte;
  { Portrait body id. }
  portraitBody: Byte;
  { Set by DetermineCombatResults, and by the script's defeat check, when no party member is left standing. }
  partyDefeated: Boolean;
  { Nonzero delays each message printed to the message window. }
  msgDelayFlag: Byte;
  { Register record handed to Dos.Intr for the BIOS video calls; every unit calling the BIOS uses this one record. }
  interruptRegs: Types.TRegisters;
  { EGA segment of the page on display. }
  egaCurPage: Word;
  { EGA segment of the other page, which TextRend and the rectangle fills draw into. }
  egaOtherPage: Word;
  { Number of the other EGA page. }
  pageNum: Byte;
  { Number of the EGA page on display. }
  pageMain: Byte;
  { BIOS mode queried at start-up, then the mode active before the latest Blit.SetVideoMode call; RestoreVideoMode
    returns to it. }
  savedVideoMode: Byte;
  { BIOS mode queried at start-up, then the mode most recently set through Blit.SetVideoMode. }
  curVideoMode: Byte;
  { The video mode from line 1 of POOL.CFG. }
  videoMode: Types.TVideoMode;

{ The view buffer, its dirty spans and the per-scanline video address tables. }
var
  { Off-screen 168x168 view buffer that the compositors draw into and Blit.FlushView copies to the screen; GameInit
    allocates it. }
  viewBuffer: Types.PImgBuf;
  { Backdrop buffer that Blit.BlitTileClipped fills with the bytes it is about to cover (when the save flag is set), so
    CharHlp can restore the background afterwards. }
  saveUnder: Types.PImgBuf;
  { Nonzero when that view scanline holds changes that Blit.FlushView still has to copy to the screen; one slot per
    scanline, 21 character rows of 8. }
  spanActive: array[0..167] of Byte;
  { Horizontal byte offset in video memory where the dirty span begins; the screen-side counterpart of spanFirstOfs. }
  spanScreenOfs: array[0..167] of Word;
  { Offset of the first dirty byte in the view buffer's image data. Reset to $FFFF when clean so any new span compares
    as earlier. }
  spanFirstOfs: array[0..167] of Word;
  { Offset of the last dirty byte in the view buffer's image data. Reset to 0 when clean so any new span compares as
    later. }
  spanLastOfs: array[0..167] of Word;
  { Video segment for each CGA scanline, precomputed so row writes need no bank arithmetic: even and odd rows interleave
    between the two CGA banks. }
  cgaRowSeg: array[0..199] of Word;
  { Offset into the EGA video segment for each scanline; rows are 40 bytes apart. }
  fbRowOfs: array[0..199] of Word;
  { Video segment for each Tandy scanline, precomputed like cgaRowSeg. }
  tandyRowSeg: array[0..199] of Word;
  { Nonzero makes Blit.BlitTileClipped clip against the destination bounds; zero trusts the caller to have kept the tile
    inside. GameInit sets it to 1. }
  clipFlag: Byte;

{ Sound, disks and directories, the item catalog, the party, the font and text cursor, symbol and tile sets, icon images
  and the combat arena. }
var
  { Active sound device; GameBoot maps POOL.CFG line 2: 'T' = 0, 'P' = 1, else 2. }
  soundMode: Byte;
  { soundMode saved while sound is suspended, so the configured mode is not lost. }
  soundSaved: Byte;
  { Nonzero makes SoundDrv.SoundCommand wait a fixed delay after each command, then silence the voices and remove its
    timer; zero leaves the timer driver resident for persistent playback. }
  soundAutoStop: Word;
  { The resource disk in use; saved with the game. }
  virtualDisk: Byte;
  { The disk DaxIo.PushState saved for PopState. }
  prevVirtualDisk: Byte;
  { GameInit sets it to 1; otherwise unused. }
  saveDisk: Word;
  { The save directory, from line 4 of POOL.CFG. }
  saveDir: String;
  { GameInit sets it to 1; otherwise unused. }
  gameDisk: Word;
  { The game directory, from line 3 of POOL.CFG; gameDir[1] is its drive letter. }
  gameDir: String;
  { Not #0 suppresses the insert-disk prompt. }
  suppressDiskPrompt: Char;
  { Set by SaveLoad once a save completes; HeapErr and the Exit to DOS loop use it to tell whether a save succeeded. }
  recentSaved: Byte;
  { Buffer for a compressed DAX block while it is expanded. }
  daxCompressedBuf: Types.PByteArr;
  { Base item types, indexed by TItemRec.itemType. }
  baseItems: array[0..127] of Types.TBaseItemRec;
  { Unused; the ITEMS read takes 129 records, and the last one lands here. }
  baseItemsOverflow: Types.TBaseItemRec;
  { The current creature. }
  curChar: Types.PCharRecord;
  { Head of the creature list: the party, then any monsters. }
  creatureList: Types.PCharRecord;
  { The last missile item added to the treasure in combat. }
  lastMissileItem: Types.PItemRec;
  { unused }
  scratchFile: file;
  { Bytes the ITEMS read returned. }
  itemsRead: Word;
  { The game font, eight bytes per character. }
  gameFont: Types.PFontArr;
  { Text cursor column, shared by TextRend's message window and slow text. }
  curCol: Byte;
  { Text cursor row, shared like curCol. }
  curRow: Byte;
  { unused }
  curRowTail: array[0..19] of Byte;
  { The five 8x8 symbol-set images, by set id 0..4: Sym8x8.Load8x8Set loads an 8X8D picture into a slot and Put8x8Sym
    draws from it. }
  symbolSets: array[0..4] of Types.PImgBuf;
  { The symbol set Put8x8Sym draws from. }
  curSymbolSet: Types.PImgBuf;
  { First 2D map tile set. }
  tileSetLow: Types.PImgBuf;
  { Second 2D map tile set; bit 7 of a tile id selects it. }
  tileSetHigh: Types.PImgBuf;
  { Animation images for the creature, death and cursor icons: frame 0 is the ready pose and frame 1 the action pose. }
  iconAnimation: array[0..25, 0..1] of Types.PImgBuf;
  { Next free arena slot, also the inclusive limit of a scan. }
  arenaCount: Byte;
  { Icon location and size per arena slot. }
  arenaLoc: array[1..72] of Types.TArenaLoc;
  { Each slot's column relative to the view. }
  gridX: array[1..72] of ShortInt;
  { Each slot's row relative to the view. }
  gridY: array[1..72] of ShortInt;
  { The arena slot standing on each arena cell. }
  crIdxArr: array[0..24, 0..49] of Byte;
  { The creature in each arena slot. }
  creatureArr: array[1..72] of Types.PCharRecord;
  { Corpses lying on the arena. }
  downed: array[1..8] of Types.TDownedRec;
  { Entries used in downed, also its scan limit; a cleared entry leaves a hole. }
  downedCount: Byte;
  { The combat viewport, which the renderers borrow. }
  arenaPtr: Types.PArena;
  { Entries filled in targetList. }
  targetCount: Byte;
  { Pathing's potential targets, sorted by distance and facing. }
  targetList: array[1..72] of Types.TCombatTarget;

{ Treasure, combatants per side and the state of the attack or effect being resolved. }
var
  { Coins and jewelry in the treasure, copper through jewelry. }
  treasureMoney: Types.TMoney;
  { Items in the treasure. }
  treasureItems: Types.PItemRec;
  { Creatures still fighting on each side; combat ends when a side is empty. }
  teamCount: array[0..1] of Byte;
  { The saving throw roll after modifiers. }
  saveRoll: Byte;
  { The effect about to be applied; cleared when the target is immune. }
  pendingEffectId: Byte;
  { Damage about to be subtracted from the target's hit points. }
  pendingDamage: Byte;
  { Damage elements of the attack: 1 fire, 2 cold, 4 electricity, 8 magic, 16 acid. }
  elementMask: Byte;
  { The current attack count, or the current movement, doubled. }
  attackOrMoveX2: Byte;
  { The spell being cast. }
  curSpell: Byte;
  { Dice in the current damage roll. }
  damageDice: Byte;
  { 1 while movement is being calculated. }
  calculatingMovement: Byte;
  { Nonzero suppresses targeting. }
  suppressTargeting: Byte;
  { Nonzero makes EffHndlr.AddEffectIfNoLock refuse to add an effect; set while the slow-poison hit is removed. }
  effectLock: Byte;
  { Nonzero when the spell affects several targets. }
  multiTarget: Byte;
  { Nonzero makes the inventory menu redraw. }
  redrawInventory: Byte;
  { The attack roll: a d20, where 1 misses and 20 becomes 100; signed, because EffHndlr can set it to -1. }
  attackRoll: ShortInt;
  { Hits this round with the first and second attacks; a rear-claw rake needs both first attacks to hit. }
  hitsMade: array[1..2] of Byte;
  { The current morale. }
  curMorale: Byte;
  { The creature this one is interacting with. }
  otherCreature: Types.PCharRecord;
  { Saving throw type, 0..4. }
  saveType: Byte;

{ Effect handlers, the 3D view, the party's position, wall and portrait caches, menus and spell targeting. }
var
  { Effect handlers, indexed by effect id. }
  effectFns: array[C_Effect.BLESS..C_Effect.READY_RING_OF_INVISIBILITY] of Types.TEffectHandler;
  { The wall symbol slices the 3D view draws from. }
  wallGfx: Types.PWallGfx;
  { The 3D map: four 256-byte GEO planes, which View3D and Explore read through views. }
  map3d: Types.PGeoMap;
  { Sky and ceiling color after palette mapping. }
  skyCeilingColor: Byte;
  { 3D view color of the ceiling and horizon band; MapView recomputes the band colors from the script's color selectors
    after picRegionW is set. }
  ceilingBandColor: Byte;
  { 3D view color of the middle band. }
  midBandColor: Byte;
  { 3D view color of the floor and wall band. }
  floorBandColor: Byte;
  { unused }
  bandColorsTail: array[0..71] of Byte;
  { Nonzero while the automap is shown in place of the 3D view. }
  automapOn: Boolean;
  { The party's position on the map. }
  partyPos: Types.TPartyPosition;
  { The three WALLDEF wall sets loaded. }
  wallSetCache: array[1..3] of Types.TWallSetCacheSlot;
  { The picture animation. }
  animData: Types.TAnimRec;
  { The HEAD and BODY image caches. }
  portraitCache: array[1..2] of Types.TPortSlot;
  { Name of the picture archive loaded. }
  picArcName: String[8];
  { Picture id loaded from picArcName; 255 invalidates the pair. }
  picArcId: Byte;
  { Position of the first visible entry of a vertical menu, from 0. }
  vertTop: Integer;
  { The item a spell is cast from. }
  castItem: Types.PItemRec;
  { The spell target picker and the spell handlers, indexed by spell id. }
  spellHandlers: Types.TSpellHandlers;
  { Creatures in spellTargets. }
  spellTargetCount: Byte;
  { The creatures the spell is aimed at. }
  spellTargets: array[1..72] of Types.PCharRecord;
  { The remembered target of a spell cast outside combat; at first the caster. }
  castTarget: Types.PCharRecord;
  { Arena column aimed at, 0..49. }
  targetX: ShortInt;
  { Arena row aimed at, 0..24. }
  targetY: ShortInt;
  { Head of the list of Stinking Clouds. }
  stinkHead: Types.PStinkRec;
  { Set while a spell is cast from an item, which casts at level 6. }
  usingItem: Boolean;
  { Set while the treasure holds any money. }
  treasureMoneyFlag: Boolean;

{ Resting and healing. }
var
  { Rest time left, as a seven-word GBVM clock; TClock-typed so it passes to GameTime.ValidateClock as a var
    parameter. }
  restRemaining: Types.TClock;
  { Spell memorization timers for the eight party slots. }
  prepTimers: array[1..8] of Byte;
  { Time rested today, in five-minute ticks. }
  healTicks: Word;
  { Nonzero suppresses the window border. }
  suppressBorder: Byte;

{ Wilderness animation. }
var
  { Party icon frame, 0..5: its parity selects the icon frame and its half the icon animation. }
  wildAnimFrame: Byte;

{ Door opening. }
var
  { Whether each way of opening the door in front of the party is still offered: bash, pick and knock. GameInit sets all
    three to 1. }
  doorOpen: array[0..2] of Byte;

{ The combat round: targets, attacks and quick combat. }
var
  { Set when the party confirms an attack on an ally (CbtActs.CheckAttackAlly). }
  attackedAllies: Byte;
  { The combat round, counted from 0. }
  roundCounter: Byte;
  { Creature indices of the potential targets. }
  potentialTargets: array[1..72] of Byte;
  { Attacks made this round with the first and second attacks. }
  attacksMade: array[1..2] of Byte;
  { The hostiles' hit points, as a percentage of their full hit points. }
  hostileHpPct: Byte;
  { Quick combat casts spells too; Alt-M toggles it. }
  quickMagic: Boolean;
  { Set when the acting creature's attacks are done; the combat menus also return their extended-key flag here. }
  doneRoundFlag: Boolean;
  { unused }
  doneRoundFlagTail: array[0..3] of Byte;
  { The combat moving-icon sheet: CombatSt allocates it, CharHlp copies icon facings in and draws from it, Combat frees
    it. }
  moveIconSheet: Types.PImgBuf;

{ Script color selectors and registers, the interpreter's stack and comparison flags, script variables and strings, and
  the experience share after combat. }
var
  { Wall color chosen by the script; writing it asks for a view redraw. }
  wallColorSel: Byte;
  { Ceiling and floor color chosen by the script; writing it asks for a view redraw. }
  ceilFloorColorSel: Byte;
  { Script register the engine never writes. }
  readReg1: Word;
  { Script register the engine never writes. }
  readReg2: Word;
  { Script register the engine never writes. }
  readReg3: Word;
  { Top node of the script's return stack. }
  eclStackTop: Types.PEclRet;
  { The node below the top of the script's return stack. }
  eclStackPrev: Types.PEclRet;
  { Result of the last comparison: equal, not equal, less, greater, less or equal, greater or equal; cleared together by
    FillChar. }
  cmpFlags: array[0..5] of Boolean;
  { The script opcode run before curOpcode. }
  prevOpcode: Byte;
  { The script opcode being run. }
  curOpcode: Byte;
  { unused }
  curOpcodeTail: Byte;
  { The monster a script is showing. }
  monId: Byte;
  { Picture id of that monster. }
  monPicId: Byte;
  { The icon animation slot a script loads a character's combat icon into. }
  iconAnim: Byte;
  { unused }
  iconAnimTail: array[0..129] of Byte;
  { Type of each decoded script variable. }
  eclVarType: array[1..64] of Byte;
  { High byte of each decoded script variable. }
  eclVarHi: array[1..64] of Byte;
  { Low byte of each decoded script variable. }
  eclVarLo: array[1..64] of Byte;
  { Receives the aim result for the bronze dragon's breath attack. }
  breathAim: Boolean;
  { Loop counter shared by the Blit, Portrait and CbtMap drawing loops; its value means nothing outside them. }
  drawLoopIndex: ShortInt;
  { The script's string buffers. }
  gbStrings: array[1..20] of String;
  { Monster display flags of the script interpreter; EclVm and EclMenu clear both together. }
  monsterFlags: Types.TMonFlags;
  { unused }
  monsterFlagsTail: array[0..1] of Byte;
  { Sound effect chosen by a script write (EclMenu.WriteGbvm). }
  sndEffect: Word;
  { Script register the engine never reads back. }
  writeReg1: Word;
  { Script register the engine never reads back. }
  writeReg2: Word;
  { Dump the creature at LOAD CHARACTER; set when a script writes 0 to its trigger word (EclMenu.SpecialWriteZ1). }
  dumpOnStatusClear: Boolean;
  { Dump the creature at LOAD CHARACTER; set when a script writes 0 to its trigger word (EclMenu.SpecialWriteZ1). }
  dumpOnNameClear: Boolean;
  { Set when a script starts a duel; the experience, the results and the summary then follow the duel's rules. }
  duelFlag: Boolean;
  { Disabled or animated creatures, which get no share of the experience. }
  nonAnimCount: Byte;
  { Each creature's share of the experience before its own bonuses. }
  expShare: LongInt;
  { Set when a party member is still standing after combat, or the duelist won. }
  combatWon: Boolean;

{ Script display flags: the 3D box, pictures, the bottom text window and the view colors. }
var
  { The running script's id. }
  eclScriptId: Byte;
  { The search-mode bit (C_Gbvm.SEARCH_FLAGS bit 0) saved while a script runs. }
  savedSearchMode: Byte;
  { Set once the script has run CLEAR BOX on the 3D view. }
  clearBoxDone: Byte;
  { Set by EclProtection when it prints its text; PRINTRETURN clears it. }
  protNewLine: Byte;
  { Set while a script is showing graphics. }
  eclGraphics: Boolean;
  { Set once a picture is drawn; the script's animation waits for it. }
  picDrawn: Boolean;
  { Set when EclProtection moves its text into the 3D box (after a CLEAR BOX); EclExit then redraws the borders and
    clears it. }
  protTextShown: Byte;
  { Set while a script is showing a monster sprite. }
  sprShown: Boolean;
  { 0 when a script has written a message to the bottom text window; Explore.MapMainMenu clears that window on its way
    out and sets it back to 1. }
  bottomMsgCleared: Byte;
  { Set when a script changes a view color selector; MapView then applies them. }
  picRegionW: Boolean;
  { Set when a script write has moved the party. }
  movedParty: Boolean;
  { Nonzero while the creature list holds hostile monsters. }
  monstersOn: Byte;
  { Set to redraw the sky or ceiling of the 3D view. }
  redrawSky: Boolean;
  { Nonzero while an ENCOUNTER MENU is up. }
  inEncMenu: Byte;
  { The picture id shown last, copied from C_Gbvm.PICTURE_LOADING. }
  picIdShown: Byte;

{ The heap end at start-up. }
var
  { FreePtr as GameBoot leaves it at start-up. }
  bootFreePtr: Pointer;
  { unused }
  bootFreePtrTail: array[0..1] of Byte;

implementation

end.
