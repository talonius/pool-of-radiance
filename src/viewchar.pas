{ Character sheets, inventory actions, coin menus and spell-menu access. }
{$O+,F+}
unit ViewChar;

interface

uses Types, Crt, C_Npc, GDConsts, GDVars, DaxIo, TextRend, Border, CharHlp, MenuCore, Portrait,
  CbtMap, Money, Magic, FxEngine, C_Effect, C_Equip, C_Keys, C_Class, C_Status, C_Ifc, C_Abil, C_Money;

{ Draws the current character's full character sheet, through tempCr1. }
procedure DisplayChar;

{ Recomputes the current character's stats and prints its armor class, hit points, THAC0, damage, encumbrance and
  movement. Note: the movement shown is doubled when slowed and halved when hasted, the reverse of the effects. }
procedure PrintCombatStats;

{ Prints one of the current character's ability scores; exceptional Strength is added as two digits in parentheses, 100
  shown as 00.
  @param(statIdx The ability, 0 to 5.)
  @param(modifying True to print it in light magenta, as while it is being changed; False for light green.) }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

{ Prints the current character's coins, highest type first, the names ending at column 19 and the amounts from column
  21; types it has none of are left out. }
procedure PrintMoney;

{ Runs the character-sheet menu: Items, Spells, Trade and Drop money, until Escape, Exit or done. During combat the
  noncombat palette is used meanwhile.
  @param(done Receives True when an action ended the turn.) }
procedure ViewCharMenu(var done: Boolean);

{ Runs the current character's inventory menu, offering Ready, Use, Trade, Drop, Halve, Join, Sell and Id as the
  character and the interface state allow, until Escape, done, or no items are left.
  @param(done Receives True when an action ended the turn.) }
procedure UseItemMenu(var done: Boolean);

{ Readies or unreadies an item for the current character. A cursed item cannot be unreadied. Readying checks, the later
  checks winning, the free hands, an occupied slot or ammunition slot and the class mask; the hands-full message is
  skipped for a quick-fighting creature in combat. An item with a special above $7F calls its effect handler when
  readied and when unreadied.
  @param(item The item.) }
procedure ToggleReadyItem(item: Types.PItemRec);

{ Uses an item: casts a spell chosen from a scroll, or the spell of an item with an effect (item effects above 56 are
  the spell entries 23 lower). In combat a spell cast in combat ends the user's actions. A used scroll loses its spell;
  another item uses up a quantity and then its charges, and goes when its charges run out.
  @param(item The item.)
  @param(done Receives True when the item was used.) }
procedure UseItem(item: Types.PItemRec; var done: Boolean);

{ Tells whether a character cannot take an item: it already holds 16 items, or the item's weight, times its quantity,
  would take it past its weight allowance plus 1500. The character's stats are recomputed first.
  @param(creature The character.)
  @param(item The item.)
  @returns(True when the character cannot take the item.) }
function CannotCarryItem(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

{ Selects the previous or next party member as the current character, wrapping at the ends.
  @param(c Home for the previous member, End for the next; any other key selects the first.) }
procedure SelectPrevNextChar(c: Char);

{ Works out the worth of a character's five coin types in gold, rounding half up; gems and jewelry are left out.
  @param(creature The character.)
  @returns(The worth in gold pieces.) }
function CreatureCoinValueInGold(creature: Types.PCharRecord): LongInt;

{ Builds a spell list and runs the spell selection on it.
  @param(menuType The list: 0 in memory, 1 in the spell book, 2 on a scroll, 3 on scrolls, 4 to choose from on gaining a
    level, 5 to be memorized, 6 to be scribed.)
  @param(selType The selection mode passed on to the selection.)
  @param(idx The menu position, kept from one call to the next; below 0 also draws the heading.)
  @param(notEmpty Receives True when the list has entries.)
  @returns(The spell chosen, or 0.) }
function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;

implementation

procedure ItemTradeMenu(item: Types.PItemRec); forward;

procedure HalveItem(item: Types.PItemRec); forward;

procedure JoinItem(item: Types.PItemRec); forward;

procedure SellItem(item: Types.PItemRec); forward;

procedure IdentifyItem(item: Types.PItemRec; var newInfo: Boolean); forward;

procedure TradeTreasureMenu; forward;

procedure DropMoneyMenu; forward;

procedure DisplayChar;
var
  { Unused in this version; see the other implementations of this routine. }
  statRow: Byte;
  row: Byte;
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statCol: Byte;
  i: ShortInt;
  j: ShortInt;
  s: String;
  multi: Boolean;
begin
  GDVars.tempCr1 := GDVars.curChar;
  TextRend.ClearScreen;
  Border.DrawBorder(1, 1, 38, 22, 0);
  CharHlp.DisplayCreatureName(GDVars.tempCr1, 1, 1, False);
  { NON_PLAYER set: shown as an NPC }
  if GDVars.tempCr1^.npc > $7F then
    TextRend.DisplayString(Length(GDVars.tempCr1^.name) + 3, 1, LightGreen, '(NPC)');
  col := 1;
  s := GDConsts.genderNames[GDVars.tempCr1^.genderIdx];
  TextRend.DisplayString(col, 3, White, s);
  col := col + Length(s) + 1;
  s := GDConsts.raceNames[GDVars.tempCr1^.race];
  TextRend.DisplayString(col, 3, White, s);
  col := col + Length(s) + 1;
  TextRend.DisplayString(col, 3, White, 'Age ' + CharHlp.WordToString(GDVars.tempCr1^.age));
  s := GDConsts.alignNames[GDVars.tempCr1^.alignmentIdx];
  TextRend.DisplayString(1, 4, White, s);
  s := GDConsts.classNames[GDVars.tempCr1^.charClass];
  TextRend.DisplayString(1, 5, White, s);
  { the six ability scores }
  for i := C_Abil.STRENGTH to C_Abil.CHARISMA do begin
    case i of
      C_Abil.STRENGTH: s := 'STR ';
      C_Abil.INTELLIGENCE: s := 'INT ';
      C_Abil.WISDOM: s := 'WIS ';
      C_Abil.DEXTERITY: s := 'DEX ';
      C_Abil.CONSTITUTION: s := 'CON ';
      C_Abil.CHARISMA: s := 'CHA ';
    end;
    TextRend.DisplayString(1, i + 7, LightGreen, s);
    ViewChar.PrintStat(i, False);
  end;
  ViewChar.PrintMoney;
  TextRend.DisplayString(1, 15, White, 'Level');
  multi := False;
  s := '';
  { one entry per class the character has levels in, joined with '/' }
  for j := C_Class.CLERIC_LEVEL to C_Class.MONK_LEVEL do
    if GDVars.tempCr1^.classLevels[j] > 0 then begin
      if multi then
        s := s + '/';
      s := s + CharHlp.ByteToString(GDVars.tempCr1^.classLevels[j]);
      multi := True;
    end;
  TextRend.DisplayString(7, 15, White, s);
  TextRend.DisplayString(17, 15, White, 'Exp ' + CharHlp.LongIntToString(GDVars.tempCr1^.experience));
  ViewChar.PrintCombatStats;
  row := 20;
  if GDVars.tempCr1^.equipped[C_Equip.WEAPON] <> nil then begin
    TextRend.DisplayString(1, row, White, 'Weapon');
    CharHlp.PrintItemString(GDVars.tempCr1, GDVars.tempCr1^.equipped[C_Equip.WEAPON], 8, row, False, True);
  end;
  Inc(row);
  if GDVars.tempCr1^.equipped[C_Equip.ARMOR] <> nil then begin
    { 'Armor' starts one column right of 'Weapon' so the two labels end in the same column }
    TextRend.DisplayString(2, row, White, 'Armor');
    CharHlp.PrintItemString(GDVars.tempCr1, GDVars.tempCr1^.equipped[C_Equip.ARMOR], 8, row, False, True);
  end;
  Inc(row);
  TextRend.DisplayString(1, row, White, 'Status');
  TextRend.DisplayString(8, row, LightGreen, GDConsts.statusStrs[GDVars.tempCr1^.status]);
  if (GDVars.portraitsOn <> 0) and (GDVars.virtualDisk = 3) then
    Portrait.DisplayCharPortrait;
end;

procedure PrintMoney;
var
  row: Byte;
  m: ShortInt;
  s: Types.TStr40;
begin
  Border.ClearBox(12, 7, 26, 14);
  row := 7;
  for m := C_Money.JEWELRY downto C_Money.COPPER do
    if GDVars.curChar^.coins[m] > 0 then begin
      s := GDConsts.moneyNames[m];
      TextRend.DisplayString(20 - Length(s), row, LightGreen, s);
      TextRend.DisplayString(21, row, LightGreen, CharHlp.WordToString(GDVars.curChar^.coins[m]));
      Inc(row);
    end;
end;

procedure PrintCombatStats;
var
  p: Types.PCharRecord;
  row: Byte;
  col: Byte;
  mv: Byte;
  s: Types.TStr40;
  effect: Types.PEffectRec;
begin
  p := GDVars.curChar;
  CharHlp.RecalcStats(p);
  row := 17;
  TextRend.DisplayString(1, row, White, 'AC    ');
  CharHlp.PrintArmorClass(p, 4, row);
  TextRend.DisplayString(1, row + 1, White, 'HP    ');
  CharHlp.PrintHitPoints(p, 4, row + 1, False);
  col := 8;
  TextRend.DisplayString(col + 1, row, White, 'THAC0   ');
  TextRend.DisplayString(col + 7, row, LightGreen, CharHlp.ByteToString(60 - p^.thac0Cur));
  s := CharHlp.ByteToString(p^.curRollsA[1]) + 'd' + CharHlp.ByteToString(p^.curDiceA[1]);
  if p^.curModA[1] > 0 then
    s := s + '+' + CharHlp.ByteToString(p^.curModA[1]);
  if p^.curModA[1] < 0 then
    s := s + '-' + CharHlp.ByteToString(Abs(p^.curModA[1]));
  TextRend.DisplayString(col, row + 1, White, 'Damage        ');
  TextRend.DisplayString(col + 7, row + 1, LightGreen, s);
  col := 22;
  TextRend.DisplayString(col, row, White, 'Encumbrance      ');
  TextRend.DisplayString(col + 12, row, LightGreen, CharHlp.WordToString(p^.encumbrance));
  mv := p^.movementCur;
  if CharHlp.HasEffect(p, C_Effect.SLOWED, effect) then
    mv := mv * 2;
  if CharHlp.HasEffect(p, C_Effect.HASTED, effect) then
    mv := mv div 2;
  TextRend.DisplayString(col + 3, row + 1, White, 'Movement   ');
  TextRend.DisplayString(col + 12, row + 1, LightGreen, CharHlp.ByteToString(mv));
end;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  hlCol: Byte;
begin
  if modifying then
    hlCol := LightMagenta
  else
    hlCol := LightGreen;
  col := 5;
  Border.ClearBox(col, statIdx + 7, 11, statIdx + 7);
  if GDVars.curChar^.stats[statIdx] < 10 then
    Inc(col);
  TextRend.DisplayString(col, statIdx + 7, hlCol, CharHlp.ByteToString(GDVars.curChar^.stats[statIdx]));
  if (statIdx = C_Abil.STRENGTH) and (GDVars.curChar^.strCur = 18) and (GDVars.curChar^.strExc > 0) then begin
    s := CharHlp.ByteToString(GDVars.curChar^.strExc);
    if GDVars.curChar^.strExc < 10 then
      s := '0' + s;
    if GDVars.curChar^.strExc = 100 then
      s := '00';
    TextRend.DisplayString(7, 7, hlCol, '(' + s + ')');
  end;
end;

procedure ViewCharMenu(var done: Boolean);
var
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  s: Types.TStr40;
  hasMoney: Boolean;
  hasSpells: Boolean;
  ext: Boolean;
  i: Byte;
  j: ShortInt;
  idx: Integer;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then
    CbtMap.SetNoncombatPalette;
  ch := ' ';
  done := False;
  GDVars.tempCr2 := GDVars.curChar;
  ViewChar.DisplayChar;
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    s := '';
    hasSpells := False;
    hasMoney := False;
    { every memorized-spell slot }
    for i := 0 to 20 do
      if GDVars.tempCr1^.memorizedSpells[i] > 0 then
        hasSpells := True;
    { every coin type, gems and jewelry included }
    for j := C_Money.COPPER to C_Money.JEWELRY do
      if GDVars.tempCr1^.coins[j] > 0 then
        hasMoney := True;
    if GDVars.tempCr1^.itemsAddr <> nil then
      s := s + 'Items ';
    if hasSpells then
      s := s + 'Spells ';
    { party members may trade, and so may NPCs that are disabled or animated }
    if ((GDVars.tempCr1^.npc < C_Npc.NON_PLAYER) or (GDVars.tempCr1^.enabled = 0) or
        (GDVars.tempCr1^.status = C_Status.ANIMATED)) and
        hasMoney and
        (GDVars.ifcState <> C_Ifc.IN_COMBAT) then
      s := s + 'Trade ';
    if hasMoney then
      s := s + 'Drop ';
    s := s + 'Exit';
    ch := MenuCore.MenuHorizontal('View:', s, LightMagenta, LightGreen, White, False, False, ext);
    idx := -1;
    case ch of
      'I': ViewChar.UseItemMenu(done);
      'S': i := ViewChar.SpellMenu(0, 0, idx, hasSpells);
      'T': ViewChar.TradeTreasureMenu;
      'D': begin
             ViewChar.DropMoneyMenu;
             ViewChar.PrintMoney;
           end;
    end;
    if not done and (ch in ['I', 'S', 'T']) then
      ViewChar.DisplayChar;
  end;
  if GDVars.ifcState = C_Ifc.IN_COMBAT then
    CbtMap.SetCombatPalette;
  CharHlp.DisplayNoncombatInterface;
end;

{ Tells whether an item may leave the current character's inventory: a readied item must be unreadied first, and a
  scroll with scribing pending (charges, effect or special above $7F) asks before that work is lost.
  @param(item The item.)
  @returns(True when the item may go.) }
function CheckItemAvail(item: Types.PItemRec): Boolean;
begin
  CheckItemAvail := False;
  if item^.equipped <> 0 then
    CharHlp.PrintBottomLine('Must be unreadied')
  else if not Magic.ItemReadable(item) then
    CheckItemAvail := True
  else if (item^.charges > $7F) or (item^.effect > $7F) or (item^.special > $7F) then begin
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, 21, False);
    GDVars.curCol := Length(GDVars.curChar^.name) + 2;
    GDVars.curRow := 21;
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, False, ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', LightMagenta, LightGreen, White) = 'Y' then
      CheckItemAvail := True;
  end else
    CheckItemAvail := True;
  Border.ClearBox(1, 21, 38, 22);
end;

procedure UseItemMenu(var done: Boolean);
var
  ch: Char;
  s: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  needRedraw: Boolean;
  vmRedraw: Boolean;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  idx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevItem: Types.PItemRec;
  creature: Types.PCharRecord;
  itemCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemSlot: Byte;
begin
  creature := GDVars.curChar;
  ch := ' ';
  sel := creature^.itemsAddr;
  idx := 0;
  vmRedraw := True;
  needRedraw := True;
  while not (ch in [C_Keys.NONE, 'E']) and not done and (creature^.numberOfItems > 0) do begin
    itemCount := creature^.numberOfItems;
    if creature^.itemsAddr <> nil then begin
      s := 'Ready';
      { Use needs an able character outside an anti-magic area, and in combat one still allowed an item this round }
      if (creature^.enabled <> 0) and (GDVars.zone0^.antimagic = 0) and
          ((GDVars.ifcState = C_Ifc.CAMPING) or (GDVars.ifcState = C_Ifc.OUTDOORS) or
           (GDVars.ifcState = C_Ifc.INDOORS) or
           ((GDVars.ifcState = C_Ifc.IN_COMBAT) and (creature^.combatAddr^.itemUseAllowed <> 0))) then
        s := s + ' Use';
      { party members may trade, and so may NPCs that are disabled or animated }
      if ((creature^.npc < C_Npc.NON_PLAYER) or (creature^.enabled = 0) or
          (creature^.status = C_Status.ANIMATED)) and (GDVars.ifcState <> C_Ifc.IN_COMBAT) then
        s := s + ' Trade';
      s := s + ' Drop';
      if creature^.numberOfItems < 16 then
        s := s + ' Halve';
      s := s + ' Join';
      { the same characters may sell, but only in a shop }
      if ((creature^.npc < C_Npc.NON_PLAYER) or (creature^.enabled = 0) or
          (creature^.status = C_Status.ANIMATED)) and (GDVars.ifcState = C_Ifc.SHOP_TEMPLE) then
        s := s + ' Sell';
      if GDVars.ifcState = C_Ifc.SHOP_TEMPLE then
        s := s + ' Id';
      { rebuild every item name }
      p := creature^.itemsAddr;
      while p <> nil do begin
        CharHlp.PrintItemString(creature, p, 0, 0, True, False);
        p := p^.next;
      end;
      if needRedraw or (GDVars.redrawInventory <> 0) then begin
        TextRend.ClearScreen;
        Border.DrawBorder(1, 1, 38, 22, 0);
        CharHlp.DisplayCreatureName(creature, 1, 1, True);
        TextRend.DisplayString(Length(creature^.name) + 4, 1, LightGreen, 'Items');
        Border.DrawWindow(1, 3, 38, 22, 0, Black, '');
        TextRend.DisplayString(1, 3, White, 'Ready Item');
        vmRedraw := True;
        needRedraw := False;
        GDVars.redrawInventory := 0;
      end;
      ch := MenuCore.MenuVertical('', s, LightMagenta, LightGreen, White, 1, 5, 38, 22,
                                  creature^.itemsAddr, True, vmRedraw, idx, sel);
      if sel <> nil then
        case ch of
          'R': ViewChar.ToggleReadyItem(sel);
          'U': if sel^.equipped = 0 then
               begin
                 CharHlp.PrintBottomLine('Must be Readied');
                 ch := ' ';
               end else if Magic.ItemReadable(sel) or ((sel^.effect > 0) and (sel^.special < $80)) then begin
                 ViewChar.UseItem(sel, done);
                 if GDVars.ifcState <> C_Ifc.IN_COMBAT then
                   { outside combat, using an item does not end the menu }
                   done := False;
                 if not done then
                   needRedraw := True;
               end;
          'T': begin
                 if ViewChar.CheckItemAvail(sel) then
                   ViewChar.ItemTradeMenu(sel)
                 else
                   ch := ' ';
                 needRedraw := True;
               end;
          'D': if ViewChar.CheckItemAvail(sel) then
               begin
                 CharHlp.PrintItemString(creature, sel, 0, 0, False, False);
                 TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, True,
                                               'Your ' + sel^.name + 'will be gone forever');
                 if MenuCore.YesNoMenu('Drop It? ', LightMagenta, LightGreen, White) = 'Y' then
                 begin
                   CharHlp.RemoveItem(GDVars.curChar, sel);
                   vmRedraw := True;
                 end;
                 Border.ClearBox(1, 21, 38, 22);
               end else
                 ch := ' ';
          'H': ViewChar.HalveItem(sel);
          'J': ViewChar.JoinItem(sel);
          'S': if ViewChar.CheckItemAvail(sel) then
                 ViewChar.SellItem(sel)
               else
                 ch := ' ';
          'I': ViewChar.IdentifyItem(sel, vmRedraw);
        end;
      CharHlp.RecalcStats(creature);
    end;
    if creature^.numberOfItems <> itemCount then
      vmRedraw := True;
  end;
end;

procedure ToggleReadyItem(item: Types.PItemRec);
var
  hasSpecial: Boolean;
  err: Byte;
  slot: ShortInt;
  creature: Types.PCharRecord;
begin
  hasSpecial := item^.special > $7F;
  creature := GDVars.curChar;
  if item^.equipped <> 0 then begin
    if item^.cursed <> 0 then
      CharHlp.PrintBottomLine('It''s Cursed')
    else begin
      item^.equipped := 0;
      if hasSpecial then
        FxEngine.CallEffectHandler(item^.special, creature, item, True);
    end;
  end else begin
    err := 0;
    if creature^.handsEquipped + GDVars.baseItems[item^.itemType].hands > 2 then
      err := 3;
    slot := GDVars.baseItems[item^.itemType].slot;
    { slots 0..8 each hold one item; a ring (slot 9) fails only when the second ring slot is taken }
    case Byte(slot) of
      C_Equip.WEAPON..C_Equip.BOOTS:
        if creature^.equipped[slot] <> nil then
          err := 2;
      C_Equip.FIRST_RING:
        if creature^.equipped[C_Equip.SECOND_RING] <> nil then
          { second ring slot already in use }
          err := 2;
    end;
    { arrows }
    if item^.itemType = 73 then
      if creature^.equipped[C_Equip.ARROW] <> nil then begin
        err := 2;
        slot := C_Equip.ARROW;
      end;
    { quarrels }
    if item^.itemType = 28 then
      if creature^.equipped[C_Equip.BOLT] <> nil then begin
        err := 2;
        slot := C_Equip.BOLT;
      end;
    if GDVars.baseItems[item^.itemType].classMask and creature^.itemLimits = 0 then
      err := 1;
    case err of
      0: begin
           item^.equipped := 1;
           if hasSpecial then
             FxEngine.CallEffectHandler(item^.special, creature, item, False);
         end;
      1: CharHlp.PrintBottomLine('Wrong Class');
      2: begin
           CharHlp.PrintItemString(creature, creature^.equipped[slot], 0, 0, False, False);
           CharHlp.PrintBottomLine('already using ' + creature^.equipped[slot]^.name);
         end;
      3: if (GDVars.ifcState <> C_Ifc.IN_COMBAT) or (creature^.quickfight = 0) then
           CharHlp.PrintBottomLine('Your hands are full!');
    end;
  end;
end;

{ Gives an item to another character chosen by the player, when that character can carry it.
  @param(item The item.) }
procedure ItemTradeMenu(item: Types.PItemRec);
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.tempCr2;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.SelectChar('Trade with Whom?', True, tgt);
  if tgt <> nil then begin
    GDVars.tempCr2 := tgt;
    if ViewChar.CannotCarryItem(tgt, item) then
      CharHlp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.AddItemCopy(tgt, item);
      CharHlp.RemoveItem(GDVars.curChar, item);
      CharHlp.RecalcStats(tgt);
    end;
  end;
end;

{ Splits an item stack: a copy holding half the quantity, rounded down, and unreadied, follows the original, which keeps
  the rest.
  @param(item The item.) }
procedure HalveItem(item: Types.PItemRec);
var
  newIt: Types.PItemRec;
  half: Byte;
  remainder: Byte;
begin
  half := item^.quantity div 2;
  if half > 0 then begin
    remainder := item^.quantity - half;
    GetMem(newIt, SizeOf(Types.TItemRec));
    Move(item^, newIt^, SizeOf(Types.TItemRec));
    newIt^.quantity := half;
    newIt^.equipped := 0;
    newIt^.next := item^.next;
    item^.quantity := remainder;
    item^.next := newIt;
  end else
    CharHlp.PrintBottomLine('Can''t halve that');
end;

{ Merges into an item each other stack of the current character's that has a quantity and the same name, type, plus,
  save bonus, curse and weight and fewer than 2 charges. When the total would pass 255, the item is filled to 255 and
  the merging goes on into the stack that keeps the excess. Note: the charges, effect and special tests compare a stack
  with itself, so they always pass.
  @param(item The item to merge into.) }
procedure JoinItem(item: Types.PItemRec);
var
  cur: Types.PItemRec;
  next: Types.PItemRec;
  dst: Types.PItemRec;
  qty: Byte;
begin
  dst := item;
  qty := dst^.quantity;
  cur := GDVars.curChar^.itemsAddr;
  while cur <> nil do begin
    next := cur^.next;
    if (cur <> dst) and (cur^.quantity > 0) and (cur^.nameIds[1] = dst^.nameIds[1]) and
        (cur^.nameIds[2] = dst^.nameIds[2]) and (cur^.nameIds[3] = dst^.nameIds[3]) and
        (cur^.itemType = dst^.itemType) and (cur^.plus = dst^.plus) and (cur^.saveBonus = dst^.saveBonus) and
        (cur^.cursed = dst^.cursed) and (cur^.weight = dst^.weight) and (cur^.charges = cur^.charges) and
        (cur^.charges < 2) and (cur^.effect = cur^.effect) and (cur^.special = cur^.special) then begin
      if qty + cur^.quantity <= 255 then begin
        Inc(qty, cur^.quantity);
        CharHlp.RemoveItem(GDVars.curChar, cur);
      end else begin
        dst^.quantity := 255;
        cur^.quantity := cur^.quantity - (255 - qty);
        qty := cur^.quantity;
        dst := cur;
      end;
    end;
    cur := next;
  end;
  dst^.quantity := qty;
end;

procedure UseItem(item: Types.PItemRec; var done: Boolean);
var
  spell: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  idx := -1;
  GDVars.usingItem := False;
  spell := 0;
  if Magic.ItemReadable(item) then begin
    GDVars.castItem := item;
    spell := ViewChar.SpellMenu(2, 1, idx, notEmpty);
  end else if (item^.effect > 0) and (item^.special < $80) then begin
    GDVars.usingItem := True;
    spell := item^.effect;
  end;
  if spell = 0 then
    done := False
  else begin
    if (GDVars.ifcState = C_Ifc.IN_COMBAT) and (GDVars.curChar^.quickfight = 0) then
      CharHlp.DisplayCombatInterface;
    if GDVars.usingItem then begin
      if spell > 56 then
        { item effect -> spell id }
        Dec(spell, 23);
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'uses an item', 10, False);
      if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
        TextRend.DisplayString(0, 23, LightGreen, 'Item:');
        CharHlp.PrintItemString(GDVars.curChar, item, 5, 23, False, True);
      end else
        CharHlp.PrintItemString(GDVars.curChar, item, 1, 22, False, True);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow;
    end;
    GDVars.usingItem := True;
    Magic.CastSpell(spell, Boolean(GDVars.curChar^.quickfight), False, done);
    GDVars.usingItem := False;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then
      if GDConsts.spellTable[spell].whenCast <> 0 then
        done := CharHlp.EndActions(GDVars.curChar);
  end;
  if done then begin
    if Magic.ItemReadable(item) then
      Magic.RemoveSpellFromScroll(GDVars.curChar, item, spell)
    else if item^.charges > 0 then begin
      if item^.quantity > 1 then
        Dec(item^.quantity)
      else begin
        Dec(item^.charges);
        if item^.charges = 0 then
          CharHlp.RemoveItem(GDVars.curChar, item);
      end;
    end;
  end;
end;

{ Offers half an item's value for it; a stack of more than one is priced at its quantity over 20 of that. The price is
  paid in platinum and gold; when the character is overloaded, the platinum it cannot take goes to the pooled money.
  Note: the arrows-and-quarrels test joins two inequalities with or, so it always holds and the full-quantity price is
  never used.
  @param(item The item.) }
procedure SellItem(item: Types.PItemRec);
var
  price: Word;
  plat: Word;
  gold: Word;
  takable: Word;
begin
  price := 0;
  if item^.value > 0 then
    price := item^.value div 2;
  if item^.quantity > 1 then begin
    if (item^.itemType <> 73) or (item^.itemType <> 28) then
      price := price * item^.quantity div 20
    else
      price := price * item^.quantity;
  end;
  CharHlp.PrintItemString(GDVars.tempCr1, item, 0, 0, False, False);
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, True,
                                'I''ll give you ' + CharHlp.WordToString(price) + ' gold pieces for your ' +
                                  item^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    CharHlp.PrintBottomLine('Sold!');
    CharHlp.RemoveItem(GDVars.curChar, item);
    plat := price div 5;
    gold := price mod 5;
    if Money.CheckOverload(GDVars.curChar, gold + plat, takable) then begin
      CharHlp.PrintBottomLine('Overloaded.  Money will be put in pool.');
      if takable > plat then
        Inc(GDVars.curChar^.coins[C_Money.PLATINUM], plat)
      else begin
        Inc(GDVars.curChar^.coins[C_Money.PLATINUM], takable);
        Inc(GDVars.treasureMoney[C_Money.PLATINUM], plat - takable);
      end;
      { added even when overloaded }
      Inc(GDVars.curChar^.coins[C_Money.GOLD], gold);
    end else begin
      Inc(GDVars.curChar^.coins[C_Money.PLATINUM], plat);
      Inc(GDVars.curChar^.coins[C_Money.GOLD], gold);
    end;
  end;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Identifies an item for 200 gold pieces, paid from the character's coins when they are worth enough, and otherwise from
  the pooled money. Note: only the low word of the gold left is passed on.
  @param(item The item.)
  @param(newInfo Set to True when the identification told something new; never cleared.) }
procedure IdentifyItem(item: Types.PItemRec; var newInfo: Boolean);
var
  charGold: LongInt;
  poolGold: LongInt;
  paid: Boolean;
begin
  paid := False;
  CharHlp.PrintItemString(GDVars.tempCr1, item, 0, 0, False, False);
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, True,
                                'For 200 gold pieces I''ll identify your ' + item^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
    if charGold >= 200 then begin
      paid := True;
      Dec(charGold, 200);
      { Note: only the low word of the remaining gold is passed on }
      Money.SetCreatureCoinsInGold(charGold);
    end else begin
      poolGold := Money.CoinValueInGold(GDVars.treasureMoney);
      if poolGold >= 200 then begin
        paid := True;
        Dec(poolGold, 200);
        Money.SetTreasureCoinsInGold(poolGold);
      end else
        CharHlp.PrintBottomLine('Not Enough Money');
    end;
  end;
  if paid then begin
    if item^.unidMask = 0 then
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, True,
                                    'I can''t tell anything new about your ' + item^.name)
    else begin
      item^.unidMask := 0;
      CharHlp.PrintItemString(GDVars.tempCr1, item, 0, 0, False, False);
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, True, 'It looks like some sort of ' + item^.name);
      newInfo := True;
    end;
  end;
  if paid then
    TextRend.PauseOnly;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Trades coins from the current character to another. The player picks the receiver, then a coin type and an amount up
  to the holding, repeating while coins are left. Note: escaping the coin menu leaves the outer loop's exit flag unset,
  so on the first pass whether the menu ends depends on an uninitialized local. }
procedure TradeTreasureMenu;
var
  tgt: Types.PCharRecord;
  m: ShortInt;
  mType: ShortInt;
  k: Byte;
  gapLen: Byte;
  p: Types.PItemRec;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  count: Word;
  idx: Integer;
  numStr: String[15];
  line: String[4];
  prompt: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: Word;
  exitOuter: Boolean;
  exitInner: Boolean;
  redraw: Boolean;
begin
  repeat
    tgt := GDVars.tempCr2;
    CharHlp.DisplayNoncombatInterface;
    CharHlp.SelectChar('Trade to?', True, tgt);
    if tgt = nil then
      exitOuter := True
    else begin
      ViewChar.DisplayChar;
      repeat
        ViewChar.PrintMoney;
        GDVars.tempCr2 := tgt;
        p := nil;
        prev := nil;
        list := nil;
        count := 0;
        for m := C_Money.COPPER to C_Money.JEWELRY do
          if GDVars.curChar^.coins[m] <> 0 then begin
            Inc(count);
            { a menu-list node: only the name, inUse and next fields of a TItemRec }
            if p = nil then begin
              GetMem(p, SizeOf(Types.TMenuNode));
              p^.next := nil;
            end else begin
              prev := p;
              GetMem(p, SizeOf(Types.TMenuNode));
              p^.next := prev;
            end;
            Str(GDVars.curChar^.coins[m], numStr);
            gapLen := 8 - Length(GDConsts.moneyNames[m]);
            line := '';
            line[0] := Chr(gapLen);
            for k := 1 to gapLen do
              line[k] := ' ';
            p^.name := line + GDConsts.moneyNames[m] + ' ' + numStr;
            p^.inUse := 0;
          end;
        list := p;
        idx := 0;
        redraw := True;
        ch := MenuCore.MenuVertical('Select type of coin', '', LightMagenta, LightGreen, White, 12,
                                    7, 25, 13, p, True, redraw, idx, prev);
        if prev = nil then
          exitInner := True
        else begin
          prompt := '';
          mType := Money.ParseMoneyType(prev^.name, prompt);
          prompt := 'How much ' + prompt + 'will you trade? ';
          amount := Money.InputNumberMax(GDVars.curChar^.coins[mType], prompt, 10);
          Money.TradeMoney(GDVars.curChar, tgt, amount, mType);
          exitInner := True;
          exitOuter := True;
          for m := C_Money.COPPER to C_Money.JEWELRY do
            if GDVars.curChar^.coins[m] > 0 then begin
              exitOuter := False;
              exitInner := False;
            end;
        end;
        if list <> nil then
          MenuCore.FreeStringList(list);
      until exitInner;
    end;
  until exitOuter;
end;

{ Drops coins from the current character: the player picks a coin type and an amount, repeating until Escape or no coins
  are left. }
procedure DropMoneyMenu;
var
  m: ShortInt;
  mType: ShortInt;
  gapLen: Byte;
  k: Byte;
  count: Word;
  idx: Integer;
  p: Types.PItemRec;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  exitFlag: Boolean;
  redraw: Boolean;
  numStr: String[15];
  line: String[4];
  prompt: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: Word;
begin
  repeat
    ViewChar.PrintMoney;
    p := nil;
    prev := nil;
    list := nil;
    count := 0;
    for m := C_Money.COPPER to C_Money.JEWELRY do
      if GDVars.curChar^.coins[m] <> 0 then begin
        Inc(count);
        { a menu-list node: only the name, inUse and next fields of a TItemRec }
        if p = nil then begin
          GetMem(p, SizeOf(Types.TMenuNode));
          p^.next := nil;
        end else begin
          prev := p;
          GetMem(p, SizeOf(Types.TMenuNode));
          p^.next := prev;
        end;
        Str(GDVars.curChar^.coins[m], numStr);
        gapLen := 8 - Length(GDConsts.moneyNames[m]);
        line := '';
        line[0] := Chr(gapLen);
        for k := 1 to gapLen do
          line[k] := ' ';
        p^.name := line + GDConsts.moneyNames[m] + ' ' + numStr;
        p^.inUse := 0;
      end;
    list := p;
    idx := 0;
    redraw := True;
    ch := MenuCore.MenuVertical('Select type of coin', '', LightMagenta, LightGreen, White, 12, 7,
                                25, 13, p, True, redraw, idx, prev);
    if prev = nil then
      exitFlag := True
    else begin
      prompt := '';
      mType := Money.ParseMoneyType(prev^.name, prompt);
      prompt := 'How much ' + prompt + 'will you drop? ';
      amount := Money.InputNumberMax(GDVars.curChar^.coins[mType], prompt, 10);
      Money.DropMoney(GDVars.curChar, amount, mType);
      exitFlag := True;
      for m := C_Money.COPPER to C_Money.JEWELRY do
        if GDVars.curChar^.coins[m] > 0 then
          exitFlag := False;
    end;
    if list <> nil then
      MenuCore.FreeStringList(list);
  until exitFlag;
end;

function CannotCarryItem(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
var
  f: Boolean;
  w: Word;
begin
  CharHlp.RecalcStats(creature);
  f := False;
  if creature^.numberOfItems > 15 then
    f := True;
  w := item^.weight;
  if item^.quantity > 0 then
    w := w * item^.quantity;
  if creature^.encumbrance + w > CharHlp.WeightAllowance(creature) + 1500 then
    f := True;
  CannotCarryItem := f;
end;

procedure SelectPrevNextChar(c: Char);
var
  p: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  if p <> nil then
    case c of
      C_Keys.HOME:
        if p = GDVars.curChar then begin
          while p^.nextCharAddr <> nil do
            p := p^.nextCharAddr;
        end else
          while (p <> nil) and (p^.nextCharAddr <> GDVars.curChar) do
            p := p^.nextCharAddr;
      C_Keys.END_KEY:
        if GDVars.curChar^.nextCharAddr <> nil then
          p := GDVars.curChar^.nextCharAddr;
    else
      p := GDVars.creatureList;
    end;
  GDVars.curChar := p;
end;

function CreatureCoinValueInGold(creature: Types.PCharRecord): LongInt;
var
  sum: LongInt;
  m: ShortInt;
begin
  sum := 0;
  { the five coin types valued in coinValues }
  for m := C_Money.COPPER to C_Money.PLATINUM do
    Inc(sum, GDConsts.coinValues[m] * creature^.coins[m]);
  CreatureCoinValueInGold := (sum + 100) div GDConsts.coinValues[C_Money.GOLD];
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  s: Types.TStr40;
begin
  case menuType of
    0: s := 'in Memory';
    1: s := 'in Spell Book';
    2: s := 'on Scroll';
    3: s := 'on Scrolls';
    4: s := 'to choose from';
    5: s := 'to be memorized';
    6: s := 'to be scribed';
  else
    s := '';
  end;
  notEmpty := Magic.GenerateSpellList(menuType);
  if notEmpty then begin
    if idx < 0 then begin
      Border.DrawWindow(1, 1, 38, 1, 0, Black, '');
      CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, True);
      TextRend.DisplayString(Length(GDVars.curChar^.name) + 4, 1, LightGreen, 'Spells ' + s);
    end;
    SpellMenu := Magic.SpellSelection(selType, idx);
  end else
    SpellMenu := 0;
end;

begin
end.
