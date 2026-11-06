{ Character creation, modification and training, plus party management and the main menu. }
{$O+,F+}
unit CharGen;

interface

uses Types, Crt, C_Area, C_Npc, GDConsts, GDVars, MenuCore, SaveLoad, ViewChar, ClassCal, FxEngine,
  Portrait, CbtMap, MapTiles, CharHlp, TextRend, Border, Blit, GameIo, C_Class, C_Race, C_Keys, C_Effect, C_Status,
  C_Ifc, C_Gbvm, C_Abil, C_Money;

{ Runs the party-roster main menu: Create, Drop, Modify, Train, View, Add, Remove, Load, Save, Begin and Exit, offered
  as the party allows; Home and End select the previous or next character. It returns once a loaded game leaves the main
  menu (setting loadedSave) or Begin Adventuring starts the game indoors; Exit to DOS saves until a save succeeds. J
  sets stingMode when the first command-line argument is STING. }
procedure MainMenu;

{ Adds characters from the CHARLIST.TXT roster to the party, unless already there (same name and randByte): at most six
  that are not NPCs and eight members in all. Added names are marked with '* ' and the roster is saved back. Note: the
  menu's Exit flag is never set, so the menu gets an uninitialized value. }
procedure AddCharacterMenu;

{ Takes the current character out of the creature list and frees it; the next creature becomes current when it was the
  first, else the one before it. A current character not in the list is left alone.
  @param(suppressSizeDec True to leave the party size as it is.)
  @param(freeAnim True to free its icon as well.) }
procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);

{ Runs the icon editor for the current character: the head and weapon pictures, the part colors and the size. The edits
  show in a preview beside the old icon; Keep commits a sub-edit and Exit reverts it, and the result is copied to the
  character's icon slot. It repeats until the player accepts the icon. }
procedure CustomizeIcon;

implementation

const
  { Ability-score indexes (TCharRecord.stats) }
  INTELLIGENCE = 1;
  WISDOM = 2;
  DEXTERITY = 3;
  CONSTITUTION = 4;

  { Class values (TCharRecord.charClass) }
  CLASS_MONK = 7;
  CLASS_CLERIC_MAGE = 11;
  CLASS_CLERIC_THIEF = 12;
  CLASS_FIGHTER_MAGE = 13;

  { classLevels indices }
  DRUID_LEVEL = 1;
  PALADIN_LEVEL = 3;
  RANGER_LEVEL = 4;

  { Script-visible game-memory address of the bitmask of trainable classes }
  GBVM_TRAIN_CLASS_MASK = $6DA8;

type
  TRace = (Monster, Dwarf, Elf, Gnome,
           HalfElf, Halfling, HalfOrc, Human);
  TClass = (ClassCleric, ClassDruid, ClassFighter, ClassPaladin, ClassRanger, ClassMage,
            ClassThief, ClassMonk, ClassClericFighter, ClassClericFighterMage,
            ClassClericRanger, ClassClericMage, ClassClericThief, ClassFighterMage,
            ClassFighterThief, ClassFighterMageThief, ClassMageThief);

{ Ability scores: stats[0..5] follow the TCharRecord strCur..chaCur order, Str Int Wis Dex Con Cha (the C_Abil
  indices). }

procedure CreateCharacterMenu; forward;

procedure DropCharacterMenu; forward;

procedure ModifyCharacterMenu; forward;

procedure TrainingMenu; forward;

procedure CustomizePortrait; forward;

function ConHpBonus(creature: Types.PCharRecord): ShortInt; forward;

function HpMaximum(creature: Types.PCharRecord): Byte; forward;

function HpMinimum(creature: Types.PCharRecord): Byte; forward;

function RollFirstLevelHp(creature: Types.PCharRecord; mask: Byte): Byte; forward;

procedure TakeCoins(gp: LongInt; creature: Types.PCharRecord); forward;

{ Frees a creature's combat record, items and effects, then the record itself.
  @param(creature The creature; the caller's pointer is left as it was.) }
procedure FreeCreature(creature: Types.PCharRecord);
var
  hold: Types.PItemRec;
  item: Types.PItemRec;
  holdE: Types.PEffectRec;
  effect: Types.PEffectRec;
begin
  with creature^ do begin
    if (combatAddr <> nil) then
      FreeMem(combatAddr, SizeOf(Types.TCombatRec));
    item := itemsAddr;
    while item <> nil do begin
      hold := item;
      item := item^.next;
      FreeMem(hold, SizeOf(Types.TItemRec));
    end;
    effect := effectsAddr;
    while effect <> nil do begin
      holdE := effect;
      effect := effect^.next;
      FreeMem(holdE, SizeOf(Types.TEffectRec));
    end;
  end;
  FreeMem(creature, SizeOf(Types.TCharRecord));
  creature := nil;
end;

const
  MENU_CREATE = 0;
  MENU_DROP = 1;
  MENU_MODIFY = 2;
  MENU_TRAIN = 3;
  MENU_VIEW = 4;
  MENU_ADD = 5;
  MENU_REMOVE = 6;
  MENU_LOAD = 7;
  MENU_SAVE = 8;
  MENU_BEGIN = 9;
  MENU_QUIT = 10;

procedure MainMenu;
var
  i: Byte;
  ch: Char;
  ext: Boolean;
  ext2: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuEnabled: array[1..9] of Byte;
  n: ShortInt;
  redraw: Boolean;
  stateB: Byte;
begin
  GDVars.virtualDisk := 3;
  stateB := C_Ifc.INDOORS;
  redraw := True;
  GDVars.stingMode := 0;
  GDVars.ifcState := C_Ifc.MAIN_MENU;
  while True do begin
    if redraw then begin
      Border.DrawWindow(1, 1, 38, 22, 0, Black, '');
      if GDVars.curChar <> nil then begin
        CharHlp.DisplayParty(Types.PCharRecord(GDVars.curChar));
        GDConsts.menuItems[CharGen.MENU_DROP].enabled := 1;
        GDConsts.menuItems[CharGen.MENU_MODIFY].enabled := 1;
        if (GDVars.zone1^[CharGen.GBVM_TRAIN_CLASS_MASK] > 0) or (GDVars.stingMode <> 0) then
          { Only ever set in this branch: once enabled, Train stays enabled until no character is selected. }
          GDConsts.menuItems[CharGen.MENU_TRAIN].enabled := 1;
        GDConsts.menuItems[CharGen.MENU_VIEW].enabled := 1;
        GDConsts.menuItems[CharGen.MENU_REMOVE].enabled := 1;
        GDConsts.menuItems[CharGen.MENU_LOAD].enabled := 0;
        GDConsts.menuItems[CharGen.MENU_SAVE].enabled := 1;
        GDConsts.menuItems[CharGen.MENU_BEGIN].enabled := 1;
      end else begin
        GDConsts.menuItems[CharGen.MENU_DROP].enabled := 0;
        GDConsts.menuItems[CharGen.MENU_MODIFY].enabled := 0;
        GDConsts.menuItems[CharGen.MENU_TRAIN].enabled := 0;
        GDConsts.menuItems[CharGen.MENU_VIEW].enabled := 0;
        GDConsts.menuItems[CharGen.MENU_REMOVE].enabled := 0;
        GDConsts.menuItems[CharGen.MENU_LOAD].enabled := 1;
        GDConsts.menuItems[CharGen.MENU_SAVE].enabled := 0;
        GDConsts.menuItems[CharGen.MENU_BEGIN].enabled := 0;
      end;
      n := 0;
      for i := 0 to 10 do
        if GDConsts.menuItems[i].enabled <> 0 then begin
          TextRend.DisplayString(2, n + 12, White, GDConsts.menuItems[i].name[1]);
          TextRend.DisplayString(3, n + 12, LightGreen,
                                 Copy(GDConsts.menuItems[i].name, 2, Length(GDConsts.menuItems[i].name) - 1));
          Inc(n);
        end;
      redraw := False;
    end;
    ch := MenuCore.MenuHorizontal('Choose a function ', GDConsts.menuKeys, LightMagenta, Black, Black, True,
                                  False, ext);
    MenuCore.ClearBottomLine;
    if ext then begin
      if ch in [C_Keys.HOME, C_Keys.END_KEY] then begin
        ViewChar.SelectPrevNextChar(ch);
        CharHlp.DisplayParty(Types.PCharRecord(GDVars.curChar));
      end;
    end else begin
      if not (ch in ['E', 'S']) then
        GDVars.recentSaved := 0;
      case ch of
        'C': if GDConsts.menuItems[CharGen.MENU_CREATE].enabled <> 0 then
               CharGen.CreateCharacterMenu;
        'D': if GDConsts.menuItems[CharGen.MENU_DROP].enabled <> 0 then
               CharGen.DropCharacterMenu;
        'M': if GDConsts.menuItems[CharGen.MENU_MODIFY].enabled <> 0 then
               CharGen.ModifyCharacterMenu;
        'T': if GDConsts.menuItems[CharGen.MENU_TRAIN].enabled <> 0 then
               CharGen.TrainingMenu;
        'V': if GDConsts.menuItems[CharGen.MENU_VIEW].enabled <> 0 then
               ViewChar.ViewCharMenu(ext2);
        'A': if GDConsts.menuItems[CharGen.MENU_ADD].enabled <> 0 then
               CharGen.AddCharacterMenu;
        'R': if (GDConsts.menuItems[CharGen.MENU_REMOVE].enabled <> 0) and (GDVars.curChar <> nil) then
             begin
               SaveLoad.SaveChar(Types.PCharRecord(GDVars.curChar), '');
               CharGen.RemoveCreature(False, True);
             end;
        'L': if GDConsts.menuItems[CharGen.MENU_LOAD].enabled <> 0 then
             begin
               SaveLoad.LoadGame;
               if GDVars.ifcState <> C_Ifc.MAIN_MENU then begin
                 GDVars.loadedSave := 1;
                 Exit;
               end;
             end;
        'S': if (GDConsts.menuItems[CharGen.MENU_SAVE].enabled <> 0) and (GDVars.creatureList <> nil) then
               SaveLoad.SaveGame;
        'B': if (GDConsts.menuItems[CharGen.MENU_BEGIN].enabled <> 0) and (GDVars.creatureList <> nil) then
             begin
               GDVars.ifcState := stateB;
               MenuCore.ClearBottomLine;
               Exit;
             end;
        'E': if GDConsts.menuItems[CharGen.MENU_QUIT].enabled <> 0 then
             begin
               ch := MenuCore.YesNoMenu('Quit to DOS ', Yellow, LightGreen, White);
               if ch = 'Y' then
               begin
                 while (GDVars.recentSaved = 0) and (GDVars.creatureList <> nil) do
                   SaveLoad.SaveGame;
                 GameIo.ExitGame;
               end;
             end;
        'J': if ParamStr(1) = 'STING' then
             begin
               GDVars.stingMode := 1;
               CharHlp.PrintBottomLine('I Understand, master...');
             end;
      end;
      redraw := True;
    end;
  end;
end;

{ Creates a character: race, gender, class and alignment are picked, the starting age set, and the ability scores, hit
  points and gold rolled until the player keeps the result. The character is named, given a portrait and an icon, and
  saved, and its record freed. Note: leaving a pick menu exits without freeing the character or the menu list. Note: the
  race-list counter still holds human when the scores are rolled, so no racial adjustment applies. Note: only the record
  is freed at the end; the racial effect nodes stay allocated. }
procedure CreateCharacterMenu;
var
  creature: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  list: Types.PItemRec;
  m: Types.PItemRec;
  sel: Integer;
  slot: Byte;
  j: ShortInt;
  roll: Byte;
  ch: Char;
  k: ShortInt;
  g: ShortInt;
  cls: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  statIndex: Byte;
  i: ShortInt;
  cnt: Byte;
  conB: Integer;
  { Unused in this version; see the other implementations of this routine. }
  classCount: Byte;
  clsCount: Byte;
  hpTotal: Byte;
  addExit: Boolean;
  redraw: Boolean;
begin
  GetMem(creature, SizeOf(Types.TCharRecord));
  FillChar(creature^, SizeOf(Types.TCharRecord), 0);
  with creature^ do begin
    for slot := 1 to 6 do
      iconColors1[slot] := GDConsts.defIconCol[slot] + (GDConsts.defIconCol[slot] + 8) * 16;
    acBase := 50;
    thac0Base := 40;
    status := C_Status.OKAY;
    enabled := 1;
    portraitHead := 1;
    portraitBody := 1;
    iconDimensions := 1;
    randByte := Random(256);
  end;
  { race }
  MenuCore.AllocStringList(7, list);
  list^.inUse := 1;
  list^.name := 'Pick Race';
  for k := 1 to 7 do
    case TRace(k) of
      Dwarf..Halfling: begin
              m := MenuCore.FindListMember(k, list);
              m^.name := '  ' + GDConsts.raceNames[k];
            end;
      { half-orc (6) row skipped }
      Human: begin
              m := MenuCore.FindListMember(k - 1, list);
              m^.name := '  ' + GDConsts.raceNames[k];
            end;
    end;
  m := list;
  sel := 1;
  redraw := True;
  addExit := True;
  repeat
    ch := MenuCore.MenuVertical('', '', LightMagenta, LightGreen, White, 1, 2, 38, 22, list,
                                addExit, redraw, sel, m);
    { Note: leaks the character and the string list. }
    if ch = C_Keys.NONE then Exit;
  until ch = C_Keys.ENTER;
  if sel = 6 then
    { 6 -> Human (7) }
    Inc(sel);
  with creature^ do begin
    race := sel;
    { Racial innate effects. }
    case Char(race) of
      Char(C_Race.HALFLING): begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CONSTITUTION_POISON_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CONSTITUTION_SPELL_SAVE, 0, 255, False);
         end;
      Char(C_Race.DWARF): begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CONSTITUTION_POISON_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CONSTITUTION_SPELL_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.DWARF_ATTACK_BONUS, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.DWARF_GIANT_DEFENSE, 0, 255, False);
         end;
      Char(C_Race.GNOME): begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CONSTITUTION_SPELL_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.GNOME_ATTACK_BONUS, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.DWARF_GIANT_DEFENSE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.GNOME_BUGBEAR_DEFENSE, 0, 255, False);
         end;
      Char(C_Race.ELF): begin
           iconSize := 2;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.ELF_RESISTANCE, 0, 255, False);
         end;
      Char(C_Race.HALF_ELF): begin
           iconSize := 2;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.HALF_ELF_RESISTANCE, 0, 255, False);
         end;
      else
        { human }
        iconSize := 2;
    end;
  end;
  { gender }
  MenuCore.FreeStringList(list);
  MenuCore.AllocStringList(3, list);
  list^.inUse := 1;
  list^.name := 'Pick Gender';
  for g := 0 to 1 do begin
    m := MenuCore.FindListMember(g + 1, list);
    m^.name := '  ' + GDConsts.genderNames[g];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', '', LightMagenta, LightGreen, White, 1, 2, 38, 22, list,
                                addExit, redraw, sel, m);
    { Note: leaks the character and the string list. }
    if ch = C_Keys.NONE then Exit;
  until ch = C_Keys.ENTER;
  creature^.genderSp := sel - 1;
  { class }
  MenuCore.FreeStringList(list);
  cnt := GDConsts.classesByRace[creature^.race, 0];
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Class';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.classNames[GDConsts.classesByRace[creature^.race, slot]];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', '', LightMagenta, LightGreen, White, 1, 2, 38, 22, list,
                                addExit, redraw, sel, m);
    { Note: leaks the character and the string list. }
    if ch = C_Keys.NONE then Exit;
  until ch = C_Keys.ENTER;
  with creature^ do begin
    charClass := GDConsts.classesByRace[race, sel];
    levelHighest := 1;
    case TClass(charClass) of
      ClassCleric..ClassMonk: classLevels[charClass] := 1;
      ClassClericFighter: begin
              classLevels[C_Class.CLERIC_LEVEL] := 1; classLevels[C_Class.FIGHTER_LEVEL] := 1;
            end;
      ClassClericFighterMage: begin
              classLevels[C_Class.CLERIC_LEVEL] := 1; classLevels[C_Class.FIGHTER_LEVEL] := 1;
              classLevels[C_Class.MAGE_LEVEL] := 1;
            end;
      ClassClericRanger: begin
              classLevels[C_Class.CLERIC_LEVEL] := 1; classLevels[CharGen.RANGER_LEVEL] := 1;
            end;
      ClassClericMage: begin
              classLevels[C_Class.CLERIC_LEVEL] := 1; classLevels[C_Class.MAGE_LEVEL] := 1;
            end;
      ClassClericThief: begin
              classLevels[C_Class.CLERIC_LEVEL] := 1; classLevels[C_Class.THIEF_LEVEL] := 1;
            end;
      ClassFighterMage: begin
              classLevels[C_Class.FIGHTER_LEVEL] := 1; classLevels[C_Class.MAGE_LEVEL] := 1;
            end;
      ClassFighterThief: begin
              classLevels[C_Class.FIGHTER_LEVEL] := 1; classLevels[C_Class.THIEF_LEVEL] := 1;
            end;
      ClassFighterMageThief: begin
              classLevels[C_Class.FIGHTER_LEVEL] := 1; classLevels[C_Class.MAGE_LEVEL] := 1;
              classLevels[C_Class.THIEF_LEVEL] := 1;
            end;
      ClassMageThief: begin
              classLevels[C_Class.MAGE_LEVEL] := 1; classLevels[C_Class.THIEF_LEVEL] := 1;
            end;
    end;
    if classLevels[C_Class.THIEF_LEVEL] > 0 then
      ClassCal.RecalcThiefSkills(Types.PCharRecord(creature));
    itemLimits := 0;
    thac0Base := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        if GDConsts.thac0Tbl[cls, classLevels[cls]] > thac0Base then
          thac0Base := GDConsts.thac0Tbl[cls, classLevels[cls]];
        Inc(itemLimits, GDConsts.usabilityBit[cls]);
      end;
  end;
  ClassCal.RecalcSaves(Types.PCharRecord(creature));
  { alignment }
  MenuCore.FreeStringList(list);
  cnt := GDConsts.alignByClass[creature^.charClass, 0];
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Alignment';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.alignNames[GDConsts.alignByClass[creature^.charClass, slot]];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', '', LightMagenta, LightGreen, White, 1, 2, 38, 22, list,
                                addExit, redraw, sel, m);
    { Note: leaks the character and the string list. }
    if ch = C_Keys.NONE then Exit;
  until ch = C_Keys.ENTER;
  creature^.alignment := GDConsts.alignByClass[creature^.charClass, sel];
  MenuCore.FreeStringList(list);
  { Starting age: single classes (0..7) roll the age dice; multiclasses take base + sides * num (the dice maximum) of
    one component class. }
  if creature^.charClass <= CharGen.CLASS_MONK then
    with GDConsts.startingAge[creature^.race, creature^.charClass] do
      creature^.age := FxEngine.RollDice(num, sides) + base
  else
    with creature^ do
      case Char(charClass) of
        Char(C_Class.CLERIC_FIGHTER): age := GDConsts.startingAge[race, C_Class.CLERIC].base +
                   GDConsts.startingAge[race, C_Class.CLERIC].sides * GDConsts.startingAge[race,
                       C_Class.CLERIC].num;
        Char(C_Class.CLERIC_FIGHTER_MAGE): age := GDConsts.startingAge[race, C_Class.CLERIC].base +
                   GDConsts.startingAge[race, C_Class.CLERIC].sides * GDConsts.startingAge[race,
                       C_Class.CLERIC].num;
        { CLERIC_RANGER leaves age zero }
        Char(CharGen.CLASS_CLERIC_MAGE): age := GDConsts.startingAge[race, C_Class.CLERIC].base +
                   GDConsts.startingAge[race, C_Class.CLERIC].sides * GDConsts.startingAge[race,
                       C_Class.CLERIC].num;
        Char(CharGen.CLASS_CLERIC_THIEF): age := GDConsts.startingAge[race, C_Class.CLERIC].base +
                   GDConsts.startingAge[race, C_Class.CLERIC].sides * GDConsts.startingAge[race,
                       C_Class.CLERIC].num;
        Char(CharGen.CLASS_FIGHTER_MAGE): age := GDConsts.startingAge[race, C_Class.MAGE].base +
                   GDConsts.startingAge[race, C_Class.MAGE].sides * GDConsts.startingAge[race,
                       C_Class.MAGE].num;
        Char(C_Class.FIGHTER_THIEF): age := GDConsts.startingAge[race, C_Class.FIGHTER].base +
                   GDConsts.startingAge[race, C_Class.FIGHTER].sides * GDConsts.startingAge[race,
                       C_Class.FIGHTER].num;
        Char(C_Class.FIGHTER_MAGE_THIEF): age := GDConsts.startingAge[race, C_Class.MAGE].base +
                   GDConsts.startingAge[race, C_Class.MAGE].sides * GDConsts.startingAge[race,
                       C_Class.MAGE].num;
        Char(C_Class.MAGE_THIEF): age := GDConsts.startingAge[race, C_Class.MAGE].base +
                   GDConsts.startingAge[race, C_Class.MAGE].sides * GDConsts.startingAge[race,
                       C_Class.MAGE].num;
      end;
  { stat roll / derived / keep loop }
  savedCur := GDVars.curChar;
  GDVars.curChar := creature;
  ViewChar.DisplayChar;
  repeat
    creature^.strExc := 0;
    for i := 0 to 5 do begin
      creature^.stats[i] := 0;
      for j := 1 to 6 do begin
        roll := FxEngine.RollDice(3, 6);
        { Note: k still holds 7 (human) from the race-list loop, so no racial adjustment applies. }
        case TRace(k) of
          Dwarf: case Char(i) of
               #4: Inc(roll);
               #5: Dec(roll);
             end;
          Elf: case Char(i) of
               #3: Inc(roll);
               #4: Dec(roll);
             end;
          Halfling: case Char(i) of
               #0: Dec(roll);
               #3: Inc(roll);
             end;
          HalfOrc: case Char(i) of
               #0: Inc(roll);
               #4: Inc(roll);
               #5: Dec(roll, 2);
             end;
        end;
        if creature^.stats[i] < roll then
          creature^.stats[i] := roll;
      end;
      with creature^ do
        case Char(i) of
          { Strength }
          #0: begin
               if (stats[i] > 0) and (GDConsts.ageCat[race, 1] < age) then
                 Inc(stats[i]);
               if (stats[i] > 0) and (GDConsts.ageCat[race, 2] < age) then
                 Dec(stats[i]);
               if (stats[i] > 0) and (GDConsts.ageCat[race, 3] < age) then
                 Dec(stats[i], 2);
               if (stats[i] > 0) and (GDConsts.ageCat[race, 4] < age) then
                 Dec(stats[i]);
               if stats[i] < GDConsts.raceStatLimits[race].strMin[genderSp] then
                 stats[i] := GDConsts.raceStatLimits[race].strMin[genderSp];
               if stats[i] > GDConsts.raceStatLimits[race].strMax[genderSp] then
                 stats[i] := GDConsts.raceStatLimits[race].strMax[genderSp];
               if stats[i] < GDConsts.classMin[charClass, i] then
                 stats[i] := GDConsts.classMin[charClass, i];
               if (stats[C_Abil.STRENGTH] = 18) and (classLevels[C_Class.FIGHTER_LEVEL] > 0) then begin
                 strExc := Random(100) + 1;
                 if GDConsts.raceStatLimits[race].excMax[genderSp] < strExc then
                   strExc := GDConsts.raceStatLimits[race].excMax[genderSp];
               end;
             end;
          { Intelligence }
          #1: begin
               if GDConsts.ageCat[race, 2] < age then
                 Inc(stats[i]);
               if GDConsts.ageCat[race, 4] < age then
                 Inc(stats[i]);
               if stats[i] < GDConsts.raceStatLimits[race].intMin then
                 stats[i] := GDConsts.raceStatLimits[race].intMin;
               if stats[i] > GDConsts.raceStatLimits[race].intMax then
                 stats[i] := GDConsts.raceStatLimits[race].intMax;
               if stats[i] < GDConsts.classMin[charClass, i] then
                 stats[i] := GDConsts.classMin[charClass, i];
             end;
          { Wisdom }
          #2: begin
               if GDConsts.ageCat[race, 1] >= age then
                 Dec(stats[i]);
               if GDConsts.ageCat[race, 2] < age then
                 Inc(stats[i]);
               if GDConsts.ageCat[race, 3] < age then
                 Inc(stats[i]);
               if GDConsts.ageCat[race, 4] < age then
                 Inc(stats[i]);
               if stats[i] < GDConsts.raceStatLimits[race].wisMin then
                 stats[i] := GDConsts.raceStatLimits[race].wisMin;
               if stats[i] > GDConsts.raceStatLimits[race].wisMax then
                 stats[i] := GDConsts.raceStatLimits[race].wisMax;
               if stats[i] < GDConsts.classMin[charClass, i] then
                 stats[i] := GDConsts.classMin[charClass, i];
               if stats[i] < 13 then
                 { cleric multiclasses need Wisdom 13 }
                 if charClass in [C_Class.CLERIC_FIGHTER..CharGen.CLASS_CLERIC_THIEF] then
                   stats[i] := 13;
             end;
          { Dexterity }
          #3: begin
               if GDConsts.ageCat[race, 3] < age then
                 Dec(stats[i], 2);
               if GDConsts.ageCat[race, 4] < age then
                 Dec(stats[i]);
               if stats[i] < GDConsts.raceStatLimits[race].dexMin then
                 stats[i] := GDConsts.raceStatLimits[race].dexMin;
               if stats[i] > GDConsts.raceStatLimits[race].dexMax then
                 stats[i] := GDConsts.raceStatLimits[race].dexMax;
               if stats[i] < GDConsts.classMin[charClass, i] then
                 stats[i] := GDConsts.classMin[charClass, i];
             end;
          { Constitution }
          #4: begin
               if GDConsts.ageCat[race, 2] < age then
                 Dec(stats[i]);
               if GDConsts.ageCat[race, 3] < age then
                 Dec(stats[i]);
               if GDConsts.ageCat[race, 4] < age then
                 Dec(stats[i]);
               if stats[i] < GDConsts.raceStatLimits[race].conMin then
                 stats[i] := GDConsts.raceStatLimits[race].conMin;
               if stats[i] > GDConsts.raceStatLimits[race].conMax then
                 stats[i] := GDConsts.raceStatLimits[race].conMax;
               if stats[i] < GDConsts.classMin[charClass, i] then
                 stats[i] := GDConsts.classMin[charClass, i];
             end;
          { Charisma }
          #5: begin
               if stats[i] < GDConsts.raceStatLimits[race].chaMin then
                 stats[i] := GDConsts.raceStatLimits[race].chaMin;
               if stats[i] > GDConsts.raceStatLimits[race].chaMax then
                 stats[i] := GDConsts.raceStatLimits[race].chaMax;
               if stats[i] < GDConsts.classMin[charClass, i] then
                 stats[i] := GDConsts.classMin[charClass, i];
             end;
        end;
      ViewChar.PrintStat(i, False);
    end;
    with creature^ do begin
      hpCur := hpMax;
      attacks := 2;
      unarmedRollsA[1] := 1;
      unarmedDiceA[1] := 2;
      useStrength := 1;
      movementBase := 12;
      { hpTotal sums each class's starting-gold dice (startingGold); gold = sum * 10 div class count }
      hpTotal := 0;
      clsCount := 0;
      for cls := 0 to 7 do
        if classLevels[cls] > 0 then begin
          case Char(cls) of
            Char(C_Class.CLERIC_LEVEL): clericSpells[1] := 1;
            Char(C_Class.MAGE_LEVEL): mageSpells[1] := 1;
          end;
          Inc(hpTotal,
              FxEngine.RollDice(GDConsts.startingGold[cls].num, GDConsts.startingGold[cls].sides));
          Inc(clsCount);
          case Char(cls) of
            Char(C_Class.CLERIC_LEVEL): begin
                 ClassCal.AwardWisdomBonus(Types.PCharRecord(creature));
                 { 56 is the last index of spellsKnown }
                 for slot := 1 to 56 do
                   with GDConsts.spellTable[slot] do
                     if (castClass = 0) and (level = 1) then
                       spellsKnown[slot] := 1;
               end;
            Char(C_Class.MAGE_LEVEL): begin
                 { Detect Magic }
                 spellsKnown[11] := 1;
                 { Read Magic }
                 spellsKnown[18] := 1;
                 { Shield }
                 spellsKnown[19] := 1;
                 { Sleep }
                 spellsKnown[21] := 1;
               end;
          end;
        end;
      coins[C_Money.GOLD] := hpTotal * 10 div clsCount;
      { Hit points: roll every class, add the Con bonus and divide by the class count (1 if a negative bonus would leave
        too little) }
      hpRolled := CharGen.RollFirstLevelHp(creature, $FF);
      hpMax := hpRolled;
      conB := CharGen.ConHpBonus(creature);
      if conB < 0 then begin
        if hpMax > Abs(conB) + clsCount then
          hpMax := (hpMax + conB) div clsCount
        else
          hpMax := 1;
      end else
        hpMax := (hpMax + conB) div clsCount;
      hpCur := hpMax;
      hpRolled := hpRolled div clsCount;
    end;
    ViewChar.PrintCombatStats;
    ViewChar.PrintMoney;
    ch := MenuCore.YesNoMenu('Keep this character? ', LightMagenta, LightGreen, White);
  until ch = 'Y';
  ViewChar.DisplayChar;
  GDVars.curChar := savedCur;
  repeat
    creature^.name := TextRend.ReadString('Character name: ', LightMagenta, 15);
  until creature^.name <> '';
  savedCur := GDVars.curChar;
  GDVars.curChar := creature;
  CharGen.CustomizePortrait;
  CharGen.CustomizeIcon;
  SaveLoad.SaveChar(Types.PCharRecord(creature), '');
  GDVars.curChar := savedCur;
  FreeMem(creature, SizeOf(Types.TCharRecord));
end;

{ Drops the current character from the party for good after asking twice, freeing it and its icon; the farewell depends
  on whether it is enabled. }
procedure DropCharacterMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  answer: Byte;
begin
  if GDVars.curChar = nil then Exit;
  with GDVars.curChar^ do begin
    if (MenuCore.YesNoMenu('Drop ' + name + ' forever? ', Yellow, LightGreen, White) = 'Y') and
        (MenuCore.YesNoMenu('Are you sure? ', Yellow, LightGreen, White) = 'Y') then
    begin
      if enabled = 0 then
        CharHlp.PrintBottomLine('You dump ' + name + ' out back.')
      else
        CharHlp.PrintBottomLine(name + ' bids you farewell.');
      CharGen.RemoveCreature(False, True);
    end else
      CharHlp.PrintBottomLine(name + ' breathes a sigh of relief.');
  end;
end;

{ Runs the editor for the ability scores and hit points of a character with no experience. Up and down pick a row (6 is
  the hit points); left and right lower or raise it within the racial, class and hit-point limits. Keep sets
  npcTreasureShare to 1; Exit restores the saved scores, exceptional Strength and hit points. A lowered score below the
  racial or class minimum goes back to the racial minimum, even when the class minimum is higher. Note: a Wisdom change
  resets only the first-level cleric slots before the Wisdom bonus is added again. }
procedure ModifyCharacterMenu;
var
  savedStats: array[0..5] of Byte;
  savedExc: Byte;
  savedHp: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedHpHigh: Byte;
  hold: ShortInt;
  key: Char;
  ext: Boolean;
  statIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rowFlags: array[1..7] of Byte;

  { Redraws the selected row, a score or the hit points, highlighted when hotPink is set. }
  procedure DisplayModifyField(hotPink: Boolean);
  begin
    if statIdx < 6 then
      ViewChar.PrintStat(statIdx, hotPink)
    else
      CharHlp.PrintHitPoints(Types.PCharRecord(GDVars.curChar), 4, 18, hotPink);
  end;

begin
  if GDVars.curChar^.experience > 0 then begin
    TextRend.PrintAndPause(GDVars.curChar^.name + ' can''t be modified.', Yellow);
    Exit;
  end;
  ViewChar.DisplayChar;
  Move(GDVars.curChar^.stats, savedStats, SizeOf(GDVars.curChar^.stats));
  savedExc := GDVars.curChar^.strExc;
  savedHp := GDVars.curChar^.hpMax;
  statIdx := 6;
  DisplayModifyField(False);
  statIdx := 0;
  DisplayModifyField(True);
  with GDVars.curChar^ do begin
    repeat
      key := MenuCore.MenuHorizontal('Modify character: ', 'Keep Exit', LightMagenta, LightGreen,
                                     White, True, False, ext);
      DisplayModifyField(False);
      if ext then
        case key of
          C_Keys.DOWN, C_Keys.ENTER:
            begin
              Inc(statIdx);
              if statIdx > 6 then
                statIdx := 0;
            end;
          C_Keys.UP:
            begin
              Dec(statIdx);
              if statIdx = 255 then
                statIdx := 6;
            end;
          { Left = decrease }
          C_Keys.LEFT:
            if statIdx < 6 then begin
              hold := statIdx;
              Dec(stats[hold]);
              case Char(hold) of
                #0: if strExc > 0 then begin
                     Dec(strExc);
                     Inc(stats[hold]);
                   end else if (stats[hold] < GDConsts.raceStatLimits[race].strMin[genderSp]) or
                     (stats[hold] < GDConsts.classMin[charClass, C_Abil.STRENGTH]) then
                     stats[hold] := GDConsts.raceStatLimits[race].strMin[genderSp];
                #1: if (stats[hold] < GDConsts.raceStatLimits[race].intMin) or
                  (stats[hold] < GDConsts.classMin[charClass, CharGen.INTELLIGENCE]) then
                     stats[hold] := GDConsts.raceStatLimits[race].intMin;
                #2: begin
                     if (stats[hold] < GDConsts.raceStatLimits[race].wisMin) or
                         (stats[hold] < GDConsts.classMin[charClass, CharGen.WISDOM]) then
                       stats[hold] := GDConsts.raceStatLimits[race].wisMin;
                     { Only clericSpells[1] is reset; [2] and [3] are not, so each keypress would re-award their bonus
                       with no ceiling (they are 0 for a new first-level character) }
                     if clericSpells[1] > 0 then
                       clericSpells[1] := 1;
                     ClassCal.AwardWisdomBonus(Types.PCharRecord(GDVars.curChar));
                   end;
                #3: if (stats[hold] < GDConsts.raceStatLimits[race].dexMin) or
                  (stats[hold] < GDConsts.classMin[charClass, CharGen.DEXTERITY]) then
                     stats[hold] := GDConsts.raceStatLimits[race].dexMin;
                #4: begin
                     if (stats[hold] < GDConsts.raceStatLimits[race].conMin) or
                         (stats[hold] < GDConsts.classMin[charClass, CharGen.CONSTITUTION]) then
                       stats[hold] := GDConsts.raceStatLimits[race].conMin;
                     if CharGen.HpMaximum(GDVars.curChar) < hpMax then
                       hpMax := CharGen.HpMaximum(GDVars.curChar);
                     hpCur := hpMax;
                     statIdx := 6;
                     DisplayModifyField(False);
                     statIdx := CharGen.CONSTITUTION;
                   end;
                #5: if (stats[hold] < GDConsts.raceStatLimits[race].chaMin) or
                  (stats[hold] < GDConsts.classMin[charClass, C_Abil.CHARISMA]) then
                     stats[hold] := GDConsts.raceStatLimits[race].chaMin;
              end;
            end else
            { HP row }
            begin
              Dec(hpMax);
              if CharGen.HpMinimum(GDVars.curChar) > hpMax then
                hpMax := CharGen.HpMinimum(GDVars.curChar);
              hpCur := hpMax;
            end;
          { Right = increase }
          C_Keys.RIGHT:
            if statIdx < 6 then begin
              hold := statIdx;
              Inc(stats[hold]);
              case Char(hold) of
                #0: if stats[hold] > GDConsts.raceStatLimits[race].strMax[genderSp] then begin
                     if (stats[hold] > 18) and (classLevels[C_Class.FIGHTER_LEVEL] > 0) and
                         (GDConsts.raceStatLimits[race].excMax[genderSp] > strExc) then
                       Inc(strExc);
                     stats[hold] := GDConsts.raceStatLimits[race].strMax[genderSp];
                   end;
                #1: if stats[hold] > GDConsts.raceStatLimits[race].intMax then
                     stats[hold] := GDConsts.raceStatLimits[race].intMax;
                #2: begin
                     if stats[hold] > GDConsts.raceStatLimits[race].wisMax then
                       stats[hold] := GDConsts.raceStatLimits[race].wisMax;
                     { clericSpells[1] only, same shape as the Left arm above }
                     if clericSpells[1] > 0 then
                       clericSpells[1] := 1;
                     ClassCal.AwardWisdomBonus(Types.PCharRecord(GDVars.curChar));
                   end;
                #3: if stats[hold] > GDConsts.raceStatLimits[race].dexMax then
                     stats[hold] := GDConsts.raceStatLimits[race].dexMax;
                #4: begin
                     if stats[hold] > GDConsts.raceStatLimits[race].conMax then
                       stats[hold] := GDConsts.raceStatLimits[race].conMax;
                     if CharGen.HpMinimum(GDVars.curChar) > hpMax then
                       hpMax := CharGen.HpMinimum(GDVars.curChar);
                     hpCur := hpMax;
                     statIdx := 6;
                     DisplayModifyField(False);
                     statIdx := CharGen.CONSTITUTION;
                   end;
                #5: if stats[hold] > GDConsts.raceStatLimits[race].chaMax then
                     stats[hold] := GDConsts.raceStatLimits[race].chaMax;
              end;
            end else
            { HP row }
            begin
              Inc(hpMax);
              if CharGen.HpMaximum(GDVars.curChar) < hpMax then
                hpMax := CharGen.HpMaximum(GDVars.curChar);
              hpCur := hpMax;
            end;
        end else
        case key of
          'E', C_Keys.NONE:
            begin
              for hold := 0 to 5 do
                GDVars.curChar^.stats[hold] := savedStats[hold];
              GDVars.curChar^.strExc := savedExc;
              GDVars.curChar^.hpMax := savedHp;
              GDVars.curChar^.hpCur := hpMax;
              CharHlp.RecalcStats(Types.PCharRecord(GDVars.curChar));
              Exit;
            end;
        end;
      CharHlp.RecalcStats(Types.PCharRecord(GDVars.curChar));
      ViewChar.PrintCombatStats;
      DisplayModifyField(True);
    until (not ext) and (key = 'K');
    GDVars.curChar^.npcTreasureShare := 1;
  end;
end;

{ Trains the current character for 1000 gold pieces. A character that is not okay, has less than 1000 gold pieces, has
  no class this hall trains or lacks the experience is refused; stingMode skips these checks and the fee. The racial
  fighter and half-elf cleric level limits apply, and the experience is first held to one below the threshold two levels
  up that it has reached. Each class trained gains a level and recovers one drained level; a new magic-user level picks
  one spell; the hit points grow by the rolled dice, and the maximum by the Constitution bonus as well, divided by the
  class count and at least 1. Note: when no spell is offered, the spell picked is 0 and the write lands on hpMax. }
procedure TrainingMenu;
var
  atCap: Boolean;
  xpClamp: LongInt;
  nextXp: LongInt;
  trainMask: Byte;
  classMask: Byte;
  trainable: Byte;
  clsCount: Byte;
  rolled: Integer;
  gain: Integer;
  dmg: Byte;
  cls: ShortInt;
  conB: Integer;
  row: ShortInt;
  oldMage: ShortInt;
  lvl: ShortInt;
  sel: Byte;
  idx: Integer;
  notEmpty: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  selIdx: Byte;
begin
  if (GDVars.curChar^.status <> C_Status.OKAY) and (GDVars.stingMode = 0) then begin
    TextRend.PrintAndPause('we only train conscious people', Yellow);
    Exit;
  end;
  if (ViewChar.CreatureCoinValueInGold(Types.PCharRecord(GDVars.curChar)) < 1000) and (GDVars.stingMode = 0) then begin
    TextRend.PrintAndPause('Training costs 1000 gp.', Yellow);
    Exit;
  end;
  trainMask := 0;
  classMask := 0;
  with GDVars.curChar^ do begin
    xpClamp := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        Inc(classMask, GDConsts.classBit[cls]);
        atCap := False;
        lvl := classLevels[cls];
        case Char(race) of
          Char(C_Race.DWARF): if cls = C_Class.FIGHTER_LEVEL then
               if ((lvl = 8) and (stats[C_Abil.STRENGTH] = 17)) or ((lvl = 7) and (stats[C_Abil.STRENGTH] < 17)) then
                 atCap := True;
          Char(C_Race.ELF): if cls = C_Class.FIGHTER_LEVEL then
               if (lvl = 7) or ((lvl = 6) and (stats[C_Abil.STRENGTH] = 17)) or ((lvl = 5) and
                   (stats[C_Abil.STRENGTH] < 17)) then
                 atCap := True;
          Char(C_Race.GNOME): if cls = C_Class.FIGHTER_LEVEL then
               if (lvl = 6) or ((lvl = 5) and (stats[C_Abil.STRENGTH] < 18)) then
                 atCap := True;
          Char(C_Race.HALF_ELF): if (cls = C_Class.CLERIC_LEVEL) and (lvl = 5) then
               atCap := True
             else if cls = C_Class.FIGHTER_LEVEL then
               if (lvl = 8) or ((lvl = 7) and (stats[C_Abil.STRENGTH] = 17)) or ((lvl = 6) and
                   (stats[C_Abil.STRENGTH] < 17)) then
                 atCap := True;
          Char(C_Race.HALFLING): if cls = C_Class.FIGHTER_LEVEL then
               if (lvl = 6) or ((lvl = 5) and (stats[C_Abil.STRENGTH] = 17)) or ((lvl = 4) and
                   (stats[C_Abil.STRENGTH] < 17)) then
                 atCap := True;
        end;
        if not atCap then
          if (GDConsts.classXpTable[cls].xp[Succ(lvl)] <= experience) or (GDVars.stingMode <> 0) then
            if GDConsts.classXpTable[cls].xp[Succ(lvl)] > 0 then begin
              Inc(trainMask, GDConsts.classBit[cls]);
              nextXp := GDConsts.classXpTable[cls].xp[Succ(Succ(lvl))];
              if nextXp > 0 then
                if experience >= nextXp then
                  if nextXp > xpClamp then
                    xpClamp := nextXp - 1;
            end;
      end;
    if xpClamp > 0 then
      experience := xpClamp;
    if GDVars.stingMode = 0 then begin
      if Byte(classMask and GDVars.zone1^[CharGen.GBVM_TRAIN_CLASS_MASK]) = 0 then begin
        TextRend.PrintAndPause('We don''t train that class here', Yellow);
        Exit;
      end else if Byte(trainMask and GDVars.zone1^[CharGen.GBVM_TRAIN_CLASS_MASK]) = 0 then begin
        TextRend.PrintAndPause('Not Enough Experience', Yellow);
        Exit;
      end;
    end;
    if GDVars.stingMode = 0 then
      trainable := trainMask and GDVars.zone1^[CharGen.GBVM_TRAIN_CLASS_MASK]
    else
      trainable := trainMask;
    Border.ClearBox(1, 1, 38, 22);
    row := 4;
    CharHlp.DisplayCreatureName(Types.PCharRecord(GDVars.curChar), 4, row, False);
    TextRend.DisplayString(Length(name) + 4, row, LightGreen, ' will become:');
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then
        if GDConsts.classBit[cls] and trainable > 0 then begin
          Inc(row);
          if row = 5 then
            TextRend.DisplayString(6, row, LightGreen,
                                   '    a level ' + CharHlp.ByteToString(classLevels[cls] + 1) + ' ' +
                                     GDConsts.classNames[cls])
          else
            TextRend.DisplayString(6, row, LightGreen,
                                   'and a level ' + CharHlp.ByteToString(classLevels[cls] + 1) + ' ' +
                                     GDConsts.classNames[cls]);
        end;
    if MenuCore.YesNoMenu('Do you wish to train? ', LightMagenta, LightGreen, White) <> 'Y' then
      Exit;
    CharHlp.PrintBottomLine('Congratulations...');
    if GDVars.stingMode = 0 then
      CharGen.TakeCoins(1000, GDVars.curChar);
    clsCount := 0;
    oldMage := classLevels[C_Class.MAGE_LEVEL];
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        Inc(clsCount);
        if GDConsts.classBit[cls] and trainable > 0 then begin
          Inc(classLevels[cls]);
          if drainedLevels > 0 then begin
            Dec(drainedHps, drainedHps div drainedLevels);
            Dec(drainedLevels);
          end;
        end;
      end;
    ClassCal.RecalcClassStats(Types.PCharRecord(GDVars.curChar));
    if classLevels[C_Class.MAGE_LEVEL] > oldMage then begin
      idx := -1;
      repeat
        sel := ViewChar.SpellMenu(4, 4, idx, notEmpty);
      until (sel > 0) or (not notEmpty);
      { Note: if no spell is offered, SpellMenu returns 0 and this writes spellsKnown[0], which lands on hpMax. }
      spellsKnown[sel] := 1;
    end;
    rolled := CharGen.RollFirstLevelHp(GDVars.curChar, trainable);
    gain := rolled div clsCount;
    if gain = 0 then
      gain := 1;
    Inc(hpRolled, gain);
    conB := CharGen.ConHpBonus(GDVars.curChar);
    gain := (rolled + conB) div clsCount;
    if gain < 1 then
      gain := 1;
    dmg := hpMax - hpCur;
    Inc(hpMax, gain);
    hpCur := hpMax - dmg;
  end;
end;

procedure AddCharacterMenu;
var
  list: Types.PItemRec;
  m: Types.PItemRec;
  creature: Types.PCharRecord;
  p: Types.PCharRecord;
  idx: Integer;
  key: Char;
  addExitU: Boolean;
  redraw: Boolean;
  nonNpc: Byte;
begin
  Border.ClearBox(1, 1, 38, 22);
  SaveLoad.LoadCharlist(list);
  if list = nil then Exit;
  idx := 0;
  m := list;
  redraw := True;
  repeat
    { Note: addExitU is never assigned, so MenuVertical gets an uninitialized value. }
    key := MenuCore.MenuVertical('Add a character: ', 'Add Exit', LightMagenta, LightGreen, White,
                                 1, 2, 38, 22, list, addExitU, redraw, idx, m);
    if (key = C_Keys.ENTER) or (key = 'A') then
      if m^.name[1] <> '*' then
      begin
        GetMem(creature, SizeOf(Types.TCharRecord));
        SaveLoad.LoadChar(m^.name, Types.PCharRecord(creature), False, True);
        m^.name := '* ' + m^.name;
        nonNpc := 0;
        if GDVars.creatureList = nil then begin
          GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
          SaveLoad.AddCharToParty(Types.PCharRecord(creature));
          SaveLoad.LoadCharIconAnim(True);
        end else begin
          p := GDVars.creatureList;
          while (p <> nil) and ((p^.name <> creature^.name) or (p^.randByte <> creature^.randByte)) do begin
            { NON_PLAYER clear }
            if p^.npc < C_Npc.NON_PLAYER then
              Inc(nonNpc);
            p := p^.nextCharAddr;
          end;
          { Add if not already in the party: a non-NPC (NON_PLAYER clear) while under 6 non-NPCs, or an NPC (NON_PLAYER
            set) while the party is under 8 }
          if (p = nil) and
              (((creature^.npc < C_Npc.NON_PLAYER) and (nonNpc < 6)) or
               ((creature^.npc > $7F) and (GDVars.zone1^[C_Gbvm.PARTY_SIZE] < 8))) then begin
            SaveLoad.AddCharToParty(Types.PCharRecord(creature));
            SaveLoad.LoadCharIconAnim(True);
            { NON_PLAYER clear }
            if creature^.npc < C_Npc.NON_PLAYER then
              Inc(nonNpc);
          end else
            FreeMem(creature, SizeOf(Types.TCharRecord));
        end;
      end;
  until (key = 'E') or (key = C_Keys.NONE) or (nonNpc > 5) or (GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 7);
  SaveLoad.SaveCharlist(list);
  MenuCore.FreeStringList(list);
end;

procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);
var
  prev: Types.PCharRecord;
begin
  if GDVars.creatureList = nil then Exit;
  prev := GDVars.creatureList;
  if prev <> GDVars.curChar then begin
    while (prev^.nextCharAddr <> GDVars.curChar) and (prev^.nextCharAddr <> nil) do
      prev := prev^.nextCharAddr;
    if prev^.nextCharAddr <> nil then begin
      if freeAnim then
        MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
      prev^.nextCharAddr := GDVars.curChar^.nextCharAddr;
      CharGen.FreeCreature(GDVars.curChar);
      GDVars.curChar := prev;
      if not suppressSizeDec then
        Dec(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
    end;
  end else begin
    if freeAnim then
      MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
    GDVars.creatureList := GDVars.curChar^.nextCharAddr;
    prev := GDVars.curChar^.nextCharAddr;
    CharGen.FreeCreature(GDVars.curChar);
    GDVars.curChar := prev;
    if not suppressSizeDec then
      Dec(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
  end;
end;

{ Lets the player cycle the current character's portrait head, 1 to 14, and body, 1 to 12; Keep is the only way out. }
procedure CustomizePortrait;
var
  key: Char;
  ext: Boolean;
  savedHead: Byte;
  savedBody: Byte;
begin
  with GDVars.curChar^ do begin
    savedHead := portraitHead;
    savedBody := portraitBody;
    repeat
      Portrait.DisplayCharPortrait;
      key := MenuCore.MenuHorizontal('', 'Head Body Keep', Black, White, LightGreen, False, False,
                                     ext);
      if not ext then
        case key of
          'H': if portraitHead < 14 then
                 Inc(portraitHead)
               else
                 portraitHead := 1;
          'B': if portraitBody < 12 then
                 Inc(portraitBody)
               else
                 portraitBody := 1;
          'K': begin
                 savedHead := portraitHead;
                 savedBody := portraitBody;
               end;
        end;
    until key = 'K';
    portraitHead := savedHead;
    portraitBody := savedBody;
  end;
  MenuCore.ClearBottomLine;
end;

procedure CustomizeIcon;

var
  { Unused in this version; see the other implementations of this routine. }
  oldState: Byte;
  key: Char;
  ext: Boolean;
  savedHead: Byte;
  savedBody: Byte;
  savedSize: Byte;
  savedOrd: Byte;
  state: Byte;
  sizeStr: string[5];
  { Unused in this version; see the other implementations of this routine. }
  partIdx: Byte;
  savedCols: Types.TIconCols;
  slot: Byte;
  which: Byte;
  loColor: Byte;
  hiColor: Byte;
  lastState: Byte;
  partKey: Char;

  { Draws the preview's ready and action frames side by side and flushes the view. }
  procedure ShowIconFrames(cx, cy: Byte);
  begin
    if GDVars.videoMode = Types.Cga then
      Blit.FillPicRect(cx * 3, cy * 24, 12, 24, Cyan, GDConsts.iconColorMap, GDVars.viewBuffer)
    else begin
      Blit.FillPicRect(cx * 3, cy * 24, 12, 24, Black, GDConsts.iconColorMap,
                       GDVars.viewBuffer);
      MapTiles.DrawIconAnimSprite(cx, cy, 0, 0, 25);
      MapTiles.DrawIconAnimSprite(cx + 3, cy, 0, 1, 25);
    end;
    MapTiles.DrawIconAnimSprite(cx, cy, 0, 0, 12);
    MapTiles.DrawIconAnimSprite(cx + 3, cy, 0, 1, 12);
    Blit.FlushView;
  end;

  { Copies both frames of one icon slot to another, recolored to the character's icon colors when applyColors is set. }
  procedure CopyIconPics(src, dst: Byte; applyColors: Boolean);
  var
    i: Byte;
    { Unused in this version; see the other implementations of this routine. }
    frameIdx: Byte;
    fromT: Types.TColorTab;
    toT: Types.TColorTab;
    sizeT: Word;
  begin
    sizeT := GDVars.iconAnimation[dst, 0]^.imgSize;
    if GDVars.videoMode = Types.Ega then
      sizeT := sizeT div 4;
    Move(GDVars.iconAnimation[src, 0]^.data, GDVars.iconAnimation[dst, 0]^.data, GDVars.iconAnimation[dst, 0]^.imgSize);
    Move(GDVars.iconAnimation[src, 1]^.data, GDVars.iconAnimation[dst, 1]^.data, GDVars.iconAnimation[dst, 1]^.imgSize);
    Move(GDVars.iconAnimation[src, 0]^.transp^, GDVars.iconAnimation[dst, 0]^.transp^, sizeT);
    Move(GDVars.iconAnimation[src, 1]^.transp^, GDVars.iconAnimation[dst, 1]^.transp^, sizeT);
    if applyColors then begin
      with GDVars.curChar^ do begin
        for i := 0 to 15 do begin
          fromT[i] := i;
          toT[i] := i;
        end;
        for i := 1 to 6 do begin
          toT[GDConsts.defIconCol[i]] := iconColors1[i] and $F;
          toT[GDConsts.defIconCol[i] + 8] := (iconColors1[i] and $F0) shr 4;
        end;
      end;
      Blit.RemapPic(fromT, toT, 0, False, GDVars.iconAnimation[dst, 0]);
      Blit.RemapPic(fromT, toT, 0, False, GDVars.iconAnimation[dst, 1]);
    end;
  end;

begin
  Border.DrawWindow(1, 1, 38, 22, 0, Black, '');
  CbtMap.SetCombatPalette;
  repeat
    SaveLoad.LoadCharIconAnim(False);
    with GDVars.curChar^ do begin
      state := 1;
      savedCols := iconColors1;
      savedOrd := orderNumber;
      orderNumber := 12;
      SaveLoad.LoadCharIconAnim(False);
      orderNumber := savedOrd;
      savedHead := iconHead;
      savedBody := iconBody;
      savedSize := iconSize;
      CopyIconPics(orderNumber, 12, True);
      ShowIconFrames(1, 2);
      TextRend.DisplayString(8, 6, White, 'old');
      TextRend.DisplayString(3, 10, White, 'ready   action');
      TextRend.DisplayString(8, 12, White, 'new');
      TextRend.DisplayString(3, 16, White, 'ready   action');
      repeat
        ShowIconFrames(1, 4);
        sizeStr := '';
        if state = 4 then
          if iconSize = 2 then
            sizeStr := 'Small'
          else
            sizeStr := 'Large';
        key := MenuCore.MenuHorizontal('', sizeStr + GDConsts.iconMenus[state], LightMagenta, LightGreen,
                                       White, False, False, ext);
        if not ext then
          case state of
            { Parts color-1 color-2 Size Exit }
            1: begin
                 lastState := 1;
                 case key of
                   'P': state := 2;
                   '1': begin
                          state := 3;
                          which := 0;
                          Delete(GDConsts.iconMenus[3], 13, 4);
                          Insert('Hair', GDConsts.iconMenus[3], 13);
                        end;
                   '2': begin
                          state := 3;
                          which := 1;
                          Delete(GDConsts.iconMenus[3], 13, 4);
                          Insert('Face', GDConsts.iconMenus[3], 13);
                        end;
                   'S': state := 4;
                 end;
               end;
            { Head Weapon Exit }
            2: begin
                 lastState := 2;
                 if key in [C_Keys.NONE, 'E'] then
                   state := 1
                 else begin
                   partKey := key;
                   state := 5;
                 end;
               end;
            { part -> color slot }
            3: begin
                 lastState := 3;
                 case key of
                   'W': slot := 6;
                   'B': slot := 1;
                   'H': slot := 4;
                   'F': slot := 4;
                   'S': slot := 5;
                   'A': slot := 2;
                   'L': slot := 3;
                   else slot := 1;
                 end;
                 if key in [C_Keys.NONE, 'E'] then
                   state := 1
                 else
                   state := 5;
               end;
            { size }
            4: begin
                 case key of
                   'L': begin
                          iconSize := 2;
                          SaveLoad.LoadCharIconAnim(False);
                        end;
                   'S': begin
                          iconSize := 1;
                          SaveLoad.LoadCharIconAnim(False);
                        end;
                   'K': begin
                          savedSize := iconSize;
                          state := 1;
                          key := ' ';
                        end;
                   'E', C_Keys.NONE:
                        begin
                          iconSize := savedSize;
                          state := 1;
                          key := ' ';
                        end;
                 end;
                 SaveLoad.LoadCharIconAnim(False);
               end;
            5: case lastState of
                 2: case partKey of
                    'H':
                    begin
                      case key of
                        'P': if iconHead > 0 then
                               Dec(iconHead)
                             else
                               iconHead := 13;
                        'N': if iconHead < 13 then
                               Inc(iconHead)
                             else
                               iconHead := 0;
                        'K': begin
                               with GDVars.curChar^ do
                                 savedHead := iconHead;
                               state := lastState;
                               key := ' ';
                             end;
                        'E', C_Keys.NONE:
                             begin
                               iconHead := savedHead;
                               state := lastState;
                               key := ' ';
                             end;
                      end;
                      SaveLoad.LoadCharIconAnim(False);
                    end;
                    'W':
                    begin
                      case key of
                        'P': if iconBody > 0 then
                               Dec(iconBody)
                             else
                               iconBody := 31;
                        'N': if iconBody < 31 then
                               Inc(iconBody)
                             else
                               iconBody := 0;
                        'K': begin
                               with GDVars.curChar^ do
                                 savedBody := iconBody;
                               state := lastState;
                               key := ' ';
                             end;
                        'E', C_Keys.NONE:
                             begin
                               iconBody := savedBody;
                               state := lastState;
                               key := ' ';
                             end;
                      end;
                      SaveLoad.LoadCharIconAnim(False);
                    end;
                    end;
                 3: begin
                      loColor := iconColors1[slot] and $F;
                      hiColor := (iconColors1[slot] and $F0) shr 4;
                      case key of
                        'N': begin
                               if which <> 0 then
                                 hiColor := (hiColor + 1) mod 16
                               else
                                 loColor := (loColor + 1) mod 16;
                               iconColors1[slot] := hiColor shl 4 + loColor;
                             end;
                        'P': begin
                               if which <> 0 then
                                 hiColor := (hiColor - 1) and $F
                               else
                                 loColor := (loColor - 1) and $F;
                               iconColors1[slot] := hiColor shl 4 + loColor;
                             end;
                        'K': begin
                               savedCols := iconColors1;
                               state := lastState;
                               key := ' ';
                             end;
                        'E', C_Keys.NONE:
                             begin
                               iconColors1 := savedCols;
                               state := lastState;
                               key := ' ';
                             end;
                      end;
                    end;
               end;
          end;
        CopyIconPics(orderNumber, 12, True);
      until (lastState = 1) and (key in [C_Keys.NONE, 'E']);
      iconHead := savedHead;
      iconBody := savedBody;
      iconSize := savedSize;
      iconColors1 := savedCols;
      CopyIconPics(orderNumber, 12, True);
      { commit the preview }
      CopyIconPics(12, orderNumber, False);
    end;
    MenuCore.ClearBottomLine;
    MapTiles.FreeIconAnim(12);
    if GDVars.locType > C_Area.LOC_3D_MAP then begin
      { restore the party map icons }
      MapTiles.LoadIconAnim('ICON', 0, 11);
      MapTiles.LoadIconAnim('ICON', 1, 12);
    end;
    key := MenuCore.YesNoMenu('Is this icon ok? ', LightMagenta, LightGreen, White);
  until key = 'Y';
  CbtMap.SetNoncombatPalette;
end;

{ Works out a character's Constitution bonus to hit points: the table bonus once per class with levels, plus 1 at
  Constitution 17 and 1 more at 18 for a single-class fighter.
  @param(creature The character.)
  @returns(The bonus.) }
function ConHpBonus(creature: Types.PCharRecord): ShortInt;
var
  bonus: ShortInt;
  cls: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  classCount: Byte;
begin
  bonus := 0;
  with creature^ do
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        Inc(bonus, GDConsts.conBonusTbl[stats[CharGen.CONSTITUTION]]);
        if (stats[CharGen.CONSTITUTION] > 16) and (charClass = C_Class.FIGHTER) then
          Inc(bonus);
        if (stats[CharGen.CONSTITUTION] > 17) and (charClass = C_Class.FIGHTER) then
          Inc(bonus);
      end;
  ConHpBonus := bonus;
end;

{ Works out the lowest maximum hit points a character may have: one per level in each class, plus 1 for a ranger or a
  monk, plus the Constitution bonus, divided by the class count; 1 when a negative bonus would leave too little.
  @param(creature The character.)
  @returns(The lowest maximum.) }
function HpMinimum(creature: Types.PCharRecord): Byte;
var
  clsCount: Byte;
  conB: ShortInt;
  sum: Byte;
  cls: ShortInt;
begin
  with creature^ do begin
    clsCount := 0;
    sum := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        Inc(sum, classLevels[cls]);
        Inc(clsCount);
        case Char(cls) of
          Char(CharGen.RANGER_LEVEL): Inc(sum);
          Char(C_Class.MONK_LEVEL): Inc(sum);
        end;
      end;
  end;
  conB := CharGen.ConHpBonus(creature);
  if conB < 0 then begin
    if sum > Abs(conB) + clsCount then
      sum := (sum + conB) div clsCount
    else
      sum := 1;
  end else
    sum := (sum + conB) div clsCount;
  HpMinimum := sum;
end;

{ Works out the highest maximum hit points a character may have: the top of each class's hit dice (cleric and druid d8 a
  level, fighter and paladin d10, ranger d8 on level + 1, magic-user d4, thief d6, monk d4 on level + 1), plus the
  Constitution bonus, divided by the class count. Note: the bonus is the current character's, not the given one's.
  @param(creature The character.)
  @returns(The highest maximum.) }
function HpMaximum(creature: Types.PCharRecord): Byte;
var
  clsCount: Byte;
  sum: Byte;
  conB: ShortInt;
  cls: ShortInt;
begin
  with creature^ do begin
    clsCount := 0;
    sum := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        Inc(clsCount);
        case Char(cls) of
          Char(C_Class.CLERIC_LEVEL): Inc(sum, classLevels[cls] * 8);
          Char(CharGen.DRUID_LEVEL): Inc(sum, classLevels[cls] * 8);
          Char(C_Class.FIGHTER_LEVEL): Inc(sum, classLevels[cls] * 10);
          Char(CharGen.PALADIN_LEVEL): Inc(sum, classLevels[cls] * 10);
          Char(CharGen.RANGER_LEVEL): Inc(sum, (classLevels[cls] + 1) * 8);
          Char(C_Class.MAGE_LEVEL): Inc(sum, classLevels[cls] * 4);
          Char(C_Class.THIEF_LEVEL): Inc(sum, classLevels[cls] * 6);
          Char(C_Class.MONK_LEVEL): Inc(sum, (classLevels[cls] + 1) * 4);
        end;
      end;
  end;
  { Con bonus of curChar, not creature }
  conB := CharGen.ConHpBonus(GDVars.curChar);
  if conB < 0 then begin
    if sum > Abs(conB) + clsCount then
      sum := (sum + conB) div clsCount
    else
      sum := 1;
  end else
    sum := (sum + conB) div clsCount;
  HpMaximum := sum;
end;

{ Rolls hit dice for each class with levels in the mask; a class at level 1 gets at least two thirds of one die's sides,
  even the ranger and monk with two dice.
  @param(creature The character.)
  @param(mask The class bits to roll; $FF for each class.)
  @returns(The total.) }
function RollFirstLevelHp(creature: Types.PCharRecord; mask: Byte): Byte;

var
  roll: Byte;
  sum: Byte;
  cls: ShortInt;
begin
  sum := 0;
  for cls := 0 to 7 do
    if (creature^.classLevels[cls] > 0) and (GDConsts.classBit[cls] and mask > 0) then begin
      roll := FxEngine.RollDice(GDConsts.hpDice[cls], GDConsts.hpSides[cls]);
      if creature^.classLevels[cls] = 1 then
        if roll < GDConsts.hpSides[cls] * 2 div 3 then
          roll := GDConsts.hpSides[cls] * 2 div 3;
      Inc(sum, roll);
    end;
  RollFirstLevelHp := sum;
end;

{ Deducts an amount in gold pieces from a character's coins. Works in 1/200 of a gold piece, taking coins from copper
  upward and rounding each coin type up (capped at what is held), then refunds any overshoot from platinum downward.
  Note: if the purse cannot cover the amount, the index runs past the five coin values into whatever follows them.
  @param(gp The amount in gold pieces.)
  @param(creature The character who pays.) }
procedure TakeCoins(gp: LongInt; creature: Types.PCharRecord);
var
  amt: Word;
  i: ShortInt;
begin
  { gold to copper-equivalent units }
  gp := gp * 200;
  i := C_Money.COPPER;
  with creature^ do begin
    { i can exceed coinValues's extent }
    while gp > 0 do begin
      amt := gp div GDConsts.coinValues[i] + 1;
      if coins[i] < amt then
        amt := coins[i];
      Dec(gp, amt * GDConsts.coinValues[i]);
      Dec(coins[i], amt);
      i := Succ(i);
    end;
    if gp < 0 then begin
      gp := Abs(gp);
      i := C_Money.PLATINUM;
      while gp > 0 do begin
        amt := gp div GDConsts.coinValues[i];
        Dec(gp, amt * GDConsts.coinValues[i]);
        Inc(coins[i], amt);
        i := Pred(i);
      end;
    end;
  end;
end;

begin
end.
