{ Shared creature operations: statistics, equipment, inventory, damage, targeting and party display. }
{$O+,F+}
unit CharHlp;

interface

uses Types, C_Area, C_Item, C_Msg, GDConsts, GDVars, Crt, SoundDrv, TextRend, Border, Blit,
  MenuCore, MapView, Wilds, Portrait, Pathing, CbtMap, C_Effect, C_Equip, C_Race, C_Keys, C_Class, C_Status, C_Ifc,
  C_Money, C_Gbvm;

{ Builds an item's label in its name: the Yes or No readied marker (inventory listings only), a * when a party member
  has Detect Magic and the item has a plus, a save bonus or a curse, the quantity when there is one, then the identified
  name parts from 3 down to 1, one of them made plural for a quantity of 2 or more.
  @param(creature Unused.)
  @param(item The item.)
  @param(col Column to print the label at.)
  @param(row Row to print the label at.)
  @param(isInv True to add the readied marker.)
  @param(doPrint True to print the label in light green.) }
procedure PrintItemString(creature: Types.PCharRecord; item: Types.PItemRec; col, row: Byte; isInv, doPrint: Boolean);

{ Draws the party panel: the Name and AC HP headings, then a row for each creature with its name, armor class and hit
  points, the numbers right-aligned. Each row is cleared first, and one more after the last.
  @param(hl The creature whose name is drawn in white; the others are colored as DisplayCreatureName colors them.) }
procedure DisplayParty(hl: Types.PCharRecord);

{ Prints a creature's hit points: yellow when wounded, light green when whole.
  @param(creature The creature.)
  @param(col Column to print at.)
  @param(row Row to print at.)
  @param(hotPink True to print them in light magenta instead.) }
procedure PrintHitPoints(creature: Types.PCharRecord; col, row: Byte; hotPink: Boolean);

{ Prints a character's armor class in light green: 60 minus the stored value, with a minus sign when the value is above
  60.
  @param(creature The character.)
  @param(col Screen column.)
  @param(row Screen row.) }
procedure PrintArmorClass(creature: Types.PCharRecord; col, row: Byte);

{ Shows a creature's name, hit points, armor class, readied weapon and status in the combat information panel.
  @param(creature The creature.) }
procedure CombatPrintCreatureInfo(creature: Types.PCharRecord);

{ Tells whether a creature is helpless: any of the four helplessness effects is on it.
  @param(creature The creature.)
  @returns(True when the creature is helpless.) }
function IsHelpless(creature: Types.PCharRecord): Boolean;

{ Recomputes a creature's readied items, encumbrance and combat values: the Strength, Dexterity and item adjustments,
  armor class, armor class from behind (without Dexterity or shield), attack level (the fighter level for a fighter that
  is not a monster, else 1) and movement. A readied bag of holding takes up to 5000 coins off the encumbrance, never
  leaving less than the readied items' weight.
  @param(creature The creature.) }
procedure RecalcStats(creature: Types.PCharRecord);

{ Writes a number in decimal.
  @param(value The number.)
  @returns(The digits.) }
function LongIntToString(value: LongInt): String;

{ Writes a number in decimal.
  @param(value The number.)
  @returns(The digits.) }
function WordToString(value: Word): String;

{ Writes a number in decimal.
  @param(value The number.)
  @returns(The digits.) }
function ByteToString(value: Byte): String;

{ Computes the Dexterity missile adjustment from the current Dexterity: -4 at 0..2, -3..-1 at 3..5, +1..+3 at 16..18, 3
  at 19..20, 4 at 21..23, 5 at 24..25, else 0.
  @param(creature The creature.)
  @returns(The adjustment.) }
function DexMissileAdjust(creature: Types.PCharRecord): ShortInt;

{ Computes the Dexterity defensive adjustment from the current Dexterity: -4 at 1..3, -3..-1 at 4..6, +1..+4 at 15..18,
  4 at 19..20, 5 at 21..23, 6 at 24..25, else 0.
  @param(creature The creature.)
  @returns(The adjustment.) }
function DexterityArmorAdjustment(creature: Types.PCharRecord): ShortInt;

{ Computes the Strength to-hit bonus on TranslatedStrength's scale (-3 at 1..3 up to +7 at 30), or 0 unless the
  creature's Strength bonus applies.
  @param(creature The creature.)
  @returns(The to-hit bonus.) }
function StrToHitAdjust(creature: Types.PCharRecord): ShortInt;

{ Finds a creature's damage adjustment for its translated Strength, 0 when the creature takes no Strength bonus.
  @param(creature The creature.)
  @returns(The adjustment.) }
function StrDamageAdjust(creature: Types.PCharRecord): ShortInt;

{ Finds a creature's weight allowance for its translated Strength, from -350 to 15000 encumbrance units.
  @param(creature The creature.)
  @returns(The allowance, which may be negative.) }
function WeightAllowance(creature: Types.PCharRecord): Integer;

{ Clears the current character's first memorized-spell slot holding a spell.
  @param(spell The spell.) }
procedure RemoveSpell(spell: Byte);

{ Takes an item out of a creature's items and frees it; a nil item, or one not in the list, only gets an error message.
  @param(creature The creature.)
  @param(item The item.) }
procedure RemoveItem(creature: Types.PCharRecord; item: Types.PItemRec);

{ Appends a copy of an item to the end of a character's item list.
  @param(creature The character who receives the copy.)
  @param(item The item to copy.) }
procedure AddItemCopy(creature: Types.PCharRecord; item: Types.PItemRec);

{ Shows a message on the bottom row in light green for the text delay, then clears the row.
  @param(s The message.) }
procedure PrintBottomLine(s: Types.TStr40);

{ Shows a creature's name and a message in the message window: in combat in the panel from column 23 at a row, and
  otherwise in the bottom window (bordered unless suppressBorder is set) with the name on its first line and the message
  wrapped below.
  @param(creature The creature.)
  @param(s The message.)
  @param(row The panel row in combat.)
  @param(pause True to wait the text delay and clear the window afterwards.) }
procedure PrintCreatureMessage(creature: Types.PCharRecord; s: string; row: Byte; pause: Boolean);

{ Clears the message area: the side panel's rows 10..21 in combat, otherwise rows 18..22. }
procedure ClearMessageWindow;

{ Prints a creature's name: light red when it is out of action, yellow when hostile, light cyan otherwise.
  @param(creature The creature.)
  @param(col Column to print at.)
  @param(row Row to print at.)
  @param(possessive True to add 's.) }
procedure DisplayCreatureName(creature: Types.PCharRecord; col, row: Byte; possessive: Boolean);

{ Copies one frame of an icon into a frame of the moving-icon sheet, mirrored when asked; on EGA the mask is a quarter
  of the picture's size.
  @param(cell The icon slot.)
  @param(half The icon's frame, 0 or 1.)
  @param(row The sheet's frame, 0 to 3.)
  @param(mirror True to mirror the frame.) }
procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);

{ Builds the four-frame moving-icon sheet from an icon: frame 0 straight and mirrored, then frame 1 mirrored and
  straight.
  @param(cell The icon slot.) }
procedure BuildIconFacings(cell: Byte);

{ Flies an icon from one arena cell to another across the combat view along a line traced in thirds of a cell. The view
  scrolls toward a point that keeps the flight in sight, and the icon moves a third of a cell a step, drawn from the
  moving-icon sheet, flushed and erased again, cycling its frames. When the flight leaves the view before the end the
  view scrolls again; at the end the icon is drawn on the end cell.
  @param(startX Arena column of the start cell.)
  @param(startY Arena row of the start cell.)
  @param(endX Arena column of the end cell.)
  @param(endY Arena row of the end cell.)
  @param(frames The number of frames to cycle.)
  @param(pace The delay between steps, in milliseconds; 0 draws only at cell boundaries.) }
procedure CombatAnimateMovingIcon(startX, startY, endX, endY: ShortInt; frames, pace: Byte);

{ Shows a creature's name and a message with a damage or effect flash. In combat the flash frames are built, the
  creature scrolled into view, the sound played and the message printed; then the four frames flash on the creature,
  once more than the game's delay setting for an effect and once for damage, which then waits the text delay. Outside
  combat it prints the message with a pause.
  @param(creature The creature.)
  @param(effect True for an effect, False for damage.)
  @param(s The message.) }
procedure PrintNameStringAnim(creature: Types.PCharRecord; effect: Boolean; s: Types.TStr40);

{ Tells whether a creature carries an effect.
  @param(creature The creature.)
  @param(id The effect.)
  @param(effect Receives the matching effect node, or nil when there is none.)
  @returns(True when it carries the effect.) }
function HasEffect(creature: Types.PCharRecord; id: Byte; var effect: Types.PEffectRec): Boolean;

{ Takes damage off a creature's hit points and updates its status. Falling more than 9 below 0, or an animated creature
  reaching 0, is death; any other drop below 0 is dying (combat records how far below); exactly 0 is unconscious. A
  creature that is then not okay or animated is taken out of play with no hit points (in combat its side's count drops
  and its initiative is cleared); otherwise it keeps the hit points left.
  @param(creature The creature.)
  @param(dmg The damage.) }
procedure InflictDamage(creature: Types.PCharRecord; dmg: Byte);

{ Prints 'is fully healed' or 'is partially healed' for a creature, and outside combat redraws the roster.
  @param(creature The healed creature.) }
procedure AnnounceHealStatus(creature: Types.PCharRecord);

{ Finds a creature's opposing team.
  @param(creature The creature.)
  @returns(1 for a creature that is not hostile, else 0.) }
function EnemyTeam(creature: Types.PCharRecord): ShortInt;

{ Recounts the creatures in play on each side. }
procedure CountTeams;

{ Builds the target list within a range of a creature, narrows it to the creature's enemies and copies their creature
  indices into the target-slot table.
  @param(creature The creature at the center.)
  @param(range The range.)
  @returns(The number of targets kept.) }
function CountTargets(creature: Types.PCharRecord; range: Byte): Byte;

{ Measures the distance in whole steps from one creature to another, read from a fresh range-255 target list built
  ignoring terrain (the previous list is saved and restored). Note: an absent target gives the last entry's distance.
  @param(creature The creature measuring.)
  @param(other The creature to find.)
  @returns(The distance.) }
function CalcDistance(creature, other: Types.PCharRecord): Byte;

{ Ends a creature's actions for the round: clears its initiative, casting, guarding and movement.
  @param(creature The creature.)
  @returns(Always True.) }
function EndActions(creature: Types.PCharRecord): Boolean;

{ Ends a creature's round on guard, and says so.
  @param(creature The creature.)
  @returns(True.) }
function Guard(creature: Types.PCharRecord): Boolean;

{ Finds the current character's casting level for a spell: its cleric or magic-user level by the spell's class, or 12
  for class 2, the special class; a spell cast from an item is at level 6 unless it is of class 2.
  @param(spell The spell.)
  @returns(The casting level.) }
function GetCasterLevel(spell: Byte): Byte;

{ Redraws the screen for the interface state: the main-menu frame; the shop or temple windows with the portrait; the
  camp picture, party and status line; the indoor or outdoor map view, party and status line; or the loot picture and
  party. }
procedure DisplayNoncombatInterface;

{ Prints the status line below the party panel: the coordinates (left out when the zone has no automap; in the
  wilderness from the zone's party position, the central and eastern maps 13 and 26 columns over), the facing, the clock
  as HH:MM, and camping or search. }
procedure PrintPositionAndTime;

{ Switches to the outdoor interface and draws it: the wilderness windows and views, the status line and the party. }
procedure DisplayWildernessInterface;

{ Empty routine with no callers. }
procedure NoopCharHlp;

{ Draws the combat screen: the combat palette, the two combat windows, the cleared bottom rows, and the combat view
  redrawn around its center. }
procedure DisplayCombatInterface;

{ Lets the player pick a character on the bottom-row menu; End and Home step to the next or previous creature, wrapping.
  Enter and Select keep the choice; Exit and Escape give nil. The current character is not changed. Note: Escape comes
  back as #0, which ends nothing, so it clears the choice and the menu goes on.
  @param(query The prompt.)
  @param(addExit True to offer Exit.)
  @param(sel The creature to start from; receives the choice, or nil.) }
procedure SelectChar(query: Types.TStr40; addExit: Boolean; var sel: Types.PCharRecord);

{ Tells whether a creature's readied weapon reaches beyond 1, thrown weapons included.
  @param(creature The creature.)
  @returns(True for a ranged weapon.) }
function HasRangedWeapon(creature: Types.PCharRecord): Boolean;

{ Tells whether a creature's readied weapon is ranged and can be thrown with a Strength bonus.
  @param(creature The creature.)
  @returns(True for a throwable weapon.) }
function HasThrowableWeapon(creature: Types.PCharRecord): Boolean;

{ Finds the item that does the damage in a ranged attack: the readied weapon itself when thrown, else the readied arrows
  for a bow or the readied quarrels for a crossbow, or nil when there is none.
  @param(creature The creature.)
  @param(sel Receives the item, or nil.)
  @returns(True when an item is found, and also for a weapon whose properties are exactly $0A, which needs no
    ammunition.) }
function FindDamagingRangedWeapon(creature: Types.PCharRecord; var sel: Types.PItemRec): Boolean;

{ Tells whether a creature has reached its race's level limit in a class. Fighter limits rise with high Strength, and a
  half-elf cleric stops at level 5; monsters, half-orcs and humans have no limit here.
  @param(creature The creature.)
  @param(cls The class.)
  @returns(True at the limit.) }
function AtLevelCap(creature: Types.PCharRecord; cls: ShortInt): Boolean;

implementation

const
  { TBaseItemRec.props weapon-property bit: the Dexterity missile-attack bonus applies }
  ITEM_PROP_DEX_MISSILE = $02;

type
  TAcAdjust = array[0..4] of ShortInt;

{ Sets the readied weapon's THAC0 and damage. THAC0 starts from its base, plus the Dexterity missile adjustment for a
  missile weapon and the Strength to-hit bonus for a weapon that uses Strength, which also adds the Strength damage
  bonus. The damage modifier starts from the weapon's small-target modifier. The weapon's plus and its ammunition's plus
  (the readied quarrels or arrows it fires) are added to both the damage modifier and THAC0; an elf adds 1 more to THAC0
  alone with the bows and item types 36 and 37. The damage dice are the small-target dice. Does nothing without a
  readied weapon.
  @param(creature The character.) }
procedure WeaponAdjust(creature: Types.PCharRecord);
var
  w: Types.PItemRec;
  wtype: Byte;
  plus: ShortInt;
begin
  w := creature^.equipped[C_Equip.WEAPON];
  if w = nil then Exit;
  wtype := w^.itemType;
  creature^.thac0Cur := creature^.thac0Base;
  if (GDVars.baseItems[wtype].props and CharHlp.ITEM_PROP_DEX_MISSILE) <> 0 then
    creature^.thac0Cur := CharHlp.DexMissileAdjust(creature) + creature^.thac0Cur;
  creature^.curModA[1] := GDVars.baseItems[wtype].dmgSmMod;
  if (GDVars.baseItems[wtype].props and C_Item.PROP_STRENGTH_BONUS) <> 0 then begin
    creature^.thac0Cur := CharHlp.StrToHitAdjust(creature) + creature^.thac0Cur;
    creature^.curModA[1] := CharHlp.StrDamageAdjust(creature) + creature^.curModA[1];
  end;
  plus := w^.plus;
  { PROP_QUARRELS: the weapon fires quarrels }
  if GDVars.baseItems[wtype].props > $7F then
    if creature^.equipped[C_Equip.BOLT] <> nil then
      plus := plus + creature^.equipped[C_Equip.BOLT]^.plus;
  if (GDVars.baseItems[wtype].props and C_Item.PROP_ARROWS) > 0 then
    if creature^.equipped[C_Equip.ARROW] <> nil then
      plus := plus + creature^.equipped[C_Equip.ARROW]^.plus;
  creature^.curModA[1] := creature^.curModA[1] + plus;
  if (creature^.race = C_Race.ELF) and
      (((w^.itemType > 40) and (w^.itemType < 45)) or (w^.itemType = 37) or (w^.itemType = 36)) then
    Inc(plus);
  creature^.thac0Cur := creature^.thac0Cur + plus;
  creature^.curRollsA[1] := GDVars.baseItems[wtype].dmgSmRolls;
  creature^.curDiceA[1] := GDVars.baseItems[wtype].dmgSmDice;
end;

{ Sets movement from readied body armor's weight: the base movement up to 150, 9 up to 399, else 6; magic armor adds 3
  when that leaves 9 or less.
  @param(creature The character.)
  @param(item A readied item; anything but body armor is ignored.) }
procedure ArmorMoveAdjust(creature: Types.PCharRecord; item: Types.PItemRec);
begin
  if GDVars.baseItems[item^.itemType].slot = C_Equip.ARMOR then begin
    case item^.weight of
      0..150: creature^.movementCur := creature^.movementBase;
      151..399: creature^.movementCur := 9;
    else
      creature^.movementCur := 6;
    end;
    if (item^.plus <> 0) and (creature^.movementCur <= 9) then
      creature^.movementCur := creature^.movementCur + 3;
  end;
end;

{ Folds one readied item into the armor-class adjustments. Only an item whose base armor value has bit 7 set counts; the
  low seven bits are its own armor class. A shield sets the shield slot to its armor class plus its plus. An item with
  armor class 0 adds its save bonus to the creature's and its plus to the slot of armor-class-0 items, except a ring,
  which raises the best-ring slot to its plus. Any other item keeps the best armor class plus plus in the armor slot,
  marking magical body armor when that new best is body armor with a positive plus.
  @param(creature The creature.)
  @param(item The item.)
  @param(adj The adjustments: 0 Dexterity, 1 shield, 2 pluses of armor-class-0 items, 3 best ring, 4 best armor.)
  @param(isMagicBody Set when the best armor becomes magical body armor.) }
procedure AddItemArmorAdjust(creature: Types.PCharRecord; item: Types.PItemRec; var adj: TAcAdjust;
                             var isMagicBody: Boolean);
var
  descr: Byte;
  slot: Byte;
begin
  descr := GDVars.baseItems[item^.itemType].acDescr;
  if descr > $7F then begin
    descr := descr and $7F;
    slot := GDVars.baseItems[item^.itemType].slot;
    if slot = C_Equip.SHIELD then
      adj[1] := descr + item^.plus
    else if descr = 0 then begin
      if slot = C_Equip.FIRST_RING then begin
        if item^.plus > adj[3] then
          adj[3] := item^.plus;
      end else
        adj[2] := adj[2] + item^.plus;
      creature^.saveBonus := creature^.saveBonus + item^.saveBonus;
    end else begin
      if descr + item^.plus > adj[4] then begin
        adj[4] := descr + item^.plus;
        if item^.plus > 0 then
          if slot = C_Equip.ARMOR then
            isMagicBody := True;
      end;
    end;
  end;
end;

{ Lowers a creature's movement for the coins it carries past its weight allowance: up to 512 over changes nothing, and
  each further band of 256 steps down to 9, 6 and 3. The movement is only ever lowered.
  @param(creature The creature.) }
procedure EncumbranceAdjust(creature: Types.PCharRecord);
var
  over: Integer;
  movement: Byte;
begin
  over := creature^.encumbrance - CharHlp.WeightAllowance(creature);
  if over < 0 then
    over := 0;
  case over of
    0..512: movement := creature^.movementCur;
    513..768: movement := 9;
    769..1024: movement := 6;
  else
    movement := 3;
  end;
  if movement < creature^.movementCur then
    creature^.movementCur := movement;
end;

procedure PrintItemString(creature: Types.PCharRecord; item: Types.PItemRec; col, row: Byte; isInv, doPrint: Boolean);
var
  i: Byte;
  mask: Byte;
  effect: Types.PEffectRec;
  found: Boolean;
  appended: Boolean;
  p: Types.PCharRecord;
begin
  item^.name := '';
  if isInv then begin
    if item^.equipped <> 0 then
      item^.name := ' Yes  '
    else
      item^.name := ' No   ';
  end;
  found := False;
  p := GDVars.creatureList;
  while (p <> nil) and not found do begin
    if CharHlp.HasEffect(p, C_Effect.DETECT_MAGIC, effect) then
      found := True;
    p := p^.nextCharAddr;
  end;
  if found then
    if (item^.plus > 0) or (item^.saveBonus > 0) or (item^.cursed <> 0) then
      item^.name := item^.name + '*' + ' ';
  if item^.quantity > 0 then
    item^.name := item^.name + CharHlp.ByteToString(item^.quantity) + ' ';
  mask := 0;
  for i := 1 to 3 do
    if item^.nameIds[i] <> 0 then
      if (item^.unidMask shr (3 - i)) and 1 = 0 then
        Inc(mask, 1 shl (i - 1));
  appended := False;
  for i := 3 downto 1 do
    if (mask shr (i - 1)) and 1 > 0 then begin
      item^.name := item^.name + GDConsts.nameParts[item^.nameIds[i]];
      if (item^.quantity < 2) or appended then
        item^.name := item^.name + ' '
      { Name component 177 is 'Silver' }
      else if ((1 shl (i - 1)) = mask) or ((i = 1) and (mask > 4) and (item^.itemType <> C_Item.FLASK_OF_OIL)) or
        ((i = 2) and not Odd(mask)) or ((i = 3) and (item^.itemType = C_Item.FLASK_OF_OIL)) or
        (((item^.itemType = 73) or (item^.itemType = 28)) and (item^.nameIds[3] <> 177)) then begin
        item^.name := item^.name + 's ';
        appended := True;
      end else
        item^.name := item^.name + ' ';
    end;
  if doPrint then
    TextRend.DisplayString(col, row, LightGreen, item^.name);
end;

procedure DisplayParty(hl: Types.PCharRecord);
var
  p: Types.PCharRecord;
  col: Byte;
  row: Byte;
  band: Byte;
begin
  if GDVars.ifcState = C_Ifc.MAIN_MENU then
    col := 1
  else
    col := 17;
  row := 2;
  TextRend.DisplayString(col, row, White, 'Name');
  TextRend.DisplayString(33, row, White, 'AC  HP');
  Inc(row, 2);
  p := GDVars.creatureList;
  while p <> nil do begin
    Border.ClearBox(col, row, 38, row);
    if p = hl then
      TextRend.DisplayString(col, row, White, p^.name)
    else
      CharHlp.DisplayCreatureName(p, col, row, False);
    case p^.acCur of
      0..50: band := 1;
      51..60: band := 2;
      61..69: band := 1;
    else
      band := 0;
    end;
    CharHlp.PrintArmorClass(p, band + 32, row);
    case p^.hpCur of
      0..9: band := 2;
      10..99: band := 1;
    else
      band := 0;
    end;
    CharHlp.PrintHitPoints(p, band + 36, row, False);
    Inc(row);
    p := p^.nextCharAddr;
  end;
  Border.ClearBox(col, row, 38, row);
end;

procedure PrintArmorClass(creature: Types.PCharRecord; col, row: Byte);
var
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  color: Byte;
begin
  s := CharHlp.ByteToString(Abs(creature^.acCur - 60));
  if creature^.acCur > 60 then
    s := '-' + s;
  TextRend.DisplayString(col, row, LightGreen, s);
end;

procedure PrintHitPoints(creature: Types.PCharRecord; col, row: Byte; hotPink: Boolean);
var
  color: Byte;
  { Unused in this version; see the other implementations of this routine. }
  bgColor: Byte;
begin
  if creature^.hpCur < creature^.hpMax then
    color := Yellow
  else
    color := LightGreen;
  if hotPink then
    color := LightMagenta;
  TextRend.DisplayString(col, row, color, CharHlp.ByteToString(creature^.hpCur));
end;

procedure CombatPrintCreatureInfo(creature: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  row: Byte;
begin
  Border.ClearBox(23, 1, 38, 21);
  row := 1;
  CharHlp.PrintCreatureMessage(creature, ' ', row, False);
  Inc(row);
  TextRend.DisplayString(23, row + 1, LightGreen, 'Hitpoints');
  CharHlp.PrintHitPoints(creature, 33, row + 1, False);
  Inc(row, 2);
  TextRend.DisplayString(23, row + 1, LightGreen, 'AC');
  CharHlp.PrintArmorClass(creature, 26, row + 1);
  GDVars.curRow := row + 1;
  if creature^.equipped[C_Equip.WEAPON] <> nil then begin
    Inc(row, 2);
    col := 23;
    CharHlp.PrintItemString(creature, creature^.equipped[C_Equip.WEAPON], 0, 0, False, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, row + 1 + 2, LightGreen, True,
                                  creature^.equipped[C_Equip.WEAPON]^.name);
  end;
  row := GDVars.curRow + 1;
  if creature^.enabled = 0 then
    TextRend.DisplayString(23, row + 1, White, GDConsts.statusStrs[creature^.status])
  else if CharHlp.IsHelpless(creature) then
    TextRend.DisplayString(23, row + 1, White, '(Helpless)');
end;

function IsHelpless(creature: Types.PCharRecord): Boolean;
var
  i: Byte;
  effect: Types.PEffectRec;
begin
  IsHelpless := False;
  for i := 1 to 4 do
    if CharHlp.HasEffect(creature, GDConsts.helplessFx[i], effect) then
      IsHelpless := True;
end;

procedure RecalcStats(creature: Types.PCharRecord);
var
  j: Byte;
  k: ShortInt;
  item: Types.PItemRec;
  magicBody: Boolean;
  bag: Boolean;
  adj: TAcAdjust;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  propertySlot: Byte;
  c: ShortInt;
  w: Word;
  slot: 0..127;
begin
  { rebuild every equipment slot from the readied items }
  for i := C_Equip.WEAPON to C_Equip.BOLT do
    creature^.equipped[i] := nil;
  bag := False;
  creature^.numberOfItems := 0;
  item := creature^.itemsAddr;
  creature^.handsEquipped := 0;
  creature^.encumbrance := 0;
  GDVars.equippedWeight := 0;
  while item <> nil do begin
    Inc(creature^.numberOfItems);
    w := item^.weight;
    if item^.quantity > 0 then
      w := item^.quantity * w;
    Inc(creature^.encumbrance, w);
    if item^.equipped <> 0 then begin
      Inc(GDVars.equippedWeight, w);
      slot := GDVars.baseItems[item^.itemType].slot;
      case Integer(Byte(slot)) of
        C_Equip.WEAPON..C_Equip.BOOTS: creature^.equipped[slot] := item;
        C_Equip.FIRST_RING:
          if creature^.equipped[C_Equip.FIRST_RING] <> nil then begin
            if creature^.equipped[C_Equip.SECOND_RING] = nil then
              creature^.equipped[C_Equip.SECOND_RING] := item;
          end else
            creature^.equipped[C_Equip.FIRST_RING] := item;
      end;
      if item^.itemType = 73 then
        creature^.equipped[C_Equip.ARROW] := item;
      if item^.itemType = 28 then
        creature^.equipped[C_Equip.BOLT] := item;
      { Name component 186 is 'Holding' }
      if item^.nameIds[1] = 186 then
        bag := True;
      creature^.handsEquipped := creature^.handsEquipped + GDVars.baseItems[item^.itemType].hands;
    end;
    item := item^.next;
  end;
  for c := C_Money.COPPER to C_Money.JEWELRY do
    creature^.encumbrance := creature^.encumbrance + creature^.coins[c];
  for j := 1 to 2 do begin
    creature^.curRollsA[j] := creature^.unarmedRollsA[j];
    creature^.curDiceA[j] := creature^.unarmedDiceA[j];
    creature^.curModA[j] := creature^.unarmedModA[j];
  end;
  { adj: 0 Dexterity, 1 shield, 2 pluses of AC-0 items, 3 best ring, 4 best armor }
  for k := 0 to 4 do
    adj[k] := 0;
  magicBody := False;
  creature^.saveBonus := 0;
  creature^.acCur := creature^.acBase;
  creature^.movementCur := creature^.movementBase;
  creature^.thac0Cur := creature^.thac0Base;
  adj[0] := CharHlp.DexterityArmorAdjustment(creature);
  if creature^.equipped[C_Equip.WEAPON] = nil then begin
    creature^.thac0Cur := CharHlp.StrToHitAdjust(creature) + creature^.thac0Cur;
    creature^.curModA[1] := CharHlp.StrDamageAdjust(creature) + creature^.curModA[1];
  end;
  CharHlp.WeaponAdjust(creature);
  item := creature^.itemsAddr;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      CharHlp.ArmorMoveAdjust(creature, item);
      CharHlp.AddItemArmorAdjust(creature, item, adj, magicBody);
    end;
    item := item^.next;
  end;
  { rings do not add to magical body armor }
  if magicBody then
    adj[3] := 0;
  if bag then begin
    if creature^.encumbrance < 5000 then
      creature^.encumbrance := 0
    else
      Dec(creature^.encumbrance, 5000);
    if creature^.encumbrance < GDVars.equippedWeight then
      creature^.encumbrance := GDVars.equippedWeight;
  end;
  CharHlp.EncumbranceAdjust(creature);
  if adj[4] < creature^.acCur then
    adj[4] := creature^.acCur;
  creature^.acCur := 0;
  for k := 0 to 4 do
    creature^.acCur := creature^.acCur + adj[k];
  creature^.acBehind := adj[4] + adj[2] + adj[3] - 2;
  if (creature^.classLevels[C_Class.FIGHTER_LEVEL] > 0) and (creature^.race > C_Race.MONSTER) then
    creature^.attackLevel := creature^.classLevels[C_Class.FIGHTER_LEVEL]
  else
    creature^.attackLevel := 1;
end;

function ByteToString(value: Byte): String;
var
  s: String;
begin
  Str(value, s);
  ByteToString := s;
end;

function WordToString(value: Word): String;
var
  s: String;
begin
  Str(value, s);
  WordToString := s;
end;

function LongIntToString(value: LongInt): String;
var
  s: String;
begin
  Str(value, s);
  LongIntToString := s;
end;

function DexterityArmorAdjustment(creature: Types.PCharRecord): ShortInt;
var
  d: Byte;
begin
  d := creature^.dexCur;
  case d of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := d - 7;
    15..18: DexterityArmorAdjustment := d - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0;
  end;
end;

function DexMissileAdjust(creature: Types.PCharRecord): ShortInt;
var
  d: Byte;
begin
  d := creature^.dexCur;
  case d of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := d - 6;
    16..18: DexMissileAdjust := d - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0;
  end;
end;

{ Converts Strength to one scale: 0..17 as is; 18 by exceptional Strength (without it 18, 01-50 19, 51-75 20, 76-90 21,
  91-99 22, 00 23); 19..25 become 24..30. Note: other values leave the result undefined.
  @param(creature The creature.)
  @returns(Strength on that scale.) }
function TranslatedStrength(creature: Types.PCharRecord): Byte;
begin
  case creature^.strCur of
    0..17: TranslatedStrength := creature^.strCur;
    18:
      case creature^.strExc of
        0: TranslatedStrength := 18;
        1..50: TranslatedStrength := 19;
        51..75: TranslatedStrength := 20;
        76..90: TranslatedStrength := 21;
        91..99: TranslatedStrength := 22;
        100: TranslatedStrength := 23;
      end;
    19..25: TranslatedStrength := creature^.strCur + 5;
  end;
end;

function StrToHitAdjust(creature: Types.PCharRecord): ShortInt;
var
  ts: Byte;
begin
  StrToHitAdjust := 0;
  ts := CharHlp.TranslatedStrength(creature);
  if creature^.useStrength <> 0 then
    case ts of
      1..3: StrToHitAdjust := -3;
      4..5: StrToHitAdjust := -2;
      6..7: StrToHitAdjust := -1;
      17..19: StrToHitAdjust := 1;
      20..22: StrToHitAdjust := 2;
      23..25: StrToHitAdjust := 3;
      26..27: StrToHitAdjust := 4;
      28..30: StrToHitAdjust := ts - 23;
    end;
end;

function StrDamageAdjust(creature: Types.PCharRecord): ShortInt;
var
  ts: Byte;
begin
  StrDamageAdjust := 0;
  ts := CharHlp.TranslatedStrength(creature);
  if creature^.useStrength <> 0 then
    case ts of
      1..2: StrDamageAdjust := -2;
      3..5: StrDamageAdjust := -1;
      16: StrDamageAdjust := 1;
      17..19: StrDamageAdjust := ts - 16;
      20..29: StrDamageAdjust := ts - 17;
      30: StrDamageAdjust := 14;
    end;
end;

function WeightAllowance(creature: Types.PCharRecord): Integer;
var
  ts: Byte;
begin
  ts := CharHlp.TranslatedStrength(creature);
  case ts of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (ts - 17) * 250 + 500;
    22..26: WeightAllowance := (ts - 22) * 1000 + 2000;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (ts - 28) * 3000 + 9000;
  else
    WeightAllowance := 0;
  end;
end;

procedure RemoveSpell(spell: Byte);
var
  i: Byte;
begin
  i := 0;
  { scan the memorized-spell slots, stopping after the first match }
  while i <= 20 do begin
    if GDVars.curChar^.memorizedSpells[i] = spell then begin
      GDVars.curChar^.memorizedSpells[i] := 0;
      i := 21;
    end;
    Inc(i);
  end;
end;

procedure RemoveItem(creature: Types.PCharRecord; item: Types.PItemRec);
var
  p: Types.PItemRec;
begin
  if item = nil then
    TextRend.DisplayAndPause(Yellow, 'Nil Item pointer...')
  else begin
    p := creature^.itemsAddr;
    if p = item then
      creature^.itemsAddr := item^.next
    else
      while (p <> nil) and (p^.next <> item) do
        p := p^.next;
    if p = nil then
      TextRend.DisplayAndPause(Yellow, 'Tried to Lose item & couldn''t find it!')
    else begin
      p^.next := item^.next;
      item^.next := nil;
      FreeMem(item, SizeOf(Types.TItemRec));
    end;
  end;
end;

procedure AddItemCopy(creature: Types.PCharRecord; item: Types.PItemRec);
var
  p: Types.PItemRec;
  n: Types.PItemRec;
begin
  GetMem(n, SizeOf(Types.TItemRec));
  Move(item^, n^, SizeOf(Types.TItemRec));
  n^.next := nil;
  p := creature^.itemsAddr;
  if p = nil then
    creature^.itemsAddr := n
  else begin
    while p^.next <> nil do
      p := p^.next;
    p^.next := n;
  end;
end;

procedure PrintBottomLine(s: Types.TStr40);
begin
  Border.ClearBox(0, 24, 39, 24);
  TextRend.DisplayString(0, 24, LightGreen, s);
  TextRend.PauseOnly;
  Border.ClearBox(0, 24, 39, 24);
end;

procedure PrintCreatureMessage(creature: Types.PCharRecord; s: string; row: Byte; pause: Boolean);
var
  top: Byte;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
    Border.ClearBox(23, row, 38, 21);
    CharHlp.DisplayCreatureName(creature, 23, row, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, 21, LightGreen, True, s);
  end else begin
    if GDVars.suppressBorder <> 0 then
      top := 18
    else begin
      top := C_Msg.MESSAGE_TOP;
      Border.DrawBorder(C_Msg.TEXT_LEFT, top, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
    end;
    Border.ClearBox(C_Msg.TEXT_LEFT, top, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    CharHlp.DisplayCreatureName(creature, 1, top + 1, False);
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, top + 2, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen, True, s);
  end;
  if pause then begin
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure ClearMessageWindow;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then
    Border.ClearBox(23, 10, 38, 21)
  else
    Border.ClearBox(C_Msg.TEXT_LEFT, 18, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

procedure DisplayCreatureName(creature: Types.PCharRecord; col, row: Byte; possessive: Boolean);
var
  color: Byte;
begin
  if creature^.enabled = 0 then
    color := LightRed
  else if creature^.hostile = 1 then
    color := Yellow
  else
    color := LightCyan;
  TextRend.DisplayString(col, row, color, creature^.name);
  if possessive then
    TextRend.DisplayString(col + Length(creature^.name), row, color, '''s');
end;

procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);
var
  tmp: Types.PImgBuf;
  stride4: Word;
  stride: Word;
begin
  stride := GDVars.moveIconSheet^.imgSize;
  stride4 := stride;
  if GDVars.videoMode = Types.Ega then
    stride4 := stride4 div 4;
  if mirror then begin
    Blit.AllocPic(24, 3, 1, 1, tmp);
    Blit.MirrorPic(GDVars.iconAnimation[cell, half], tmp);
    Move(tmp^.data, GDVars.moveIconSheet^.data[row * stride], stride);
    Move(tmp^.transp^, GDVars.moveIconSheet^.transp^[row * stride4], stride4);
    Blit.FreePic(tmp);
  end else begin
    Move(GDVars.iconAnimation[cell, half]^.data, GDVars.moveIconSheet^.data[row * stride], stride);
    Move(GDVars.iconAnimation[cell, half]^.transp^, GDVars.moveIconSheet^.transp^[row * stride4], stride4);
  end;
end;

procedure BuildIconFacings(cell: Byte);
begin
  CharHlp.CopyIconFacing(cell, 0, 0, False);
  CharHlp.CopyIconFacing(cell, 0, 1, True);
  CharHlp.CopyIconFacing(cell, 1, 2, True);
  CharHlp.CopyIconFacing(cell, 1, 3, False);
end;

procedure CombatAnimateMovingIcon(startX, startY, endX, endY: ShortInt; frames, pace: Byte);
var
  steps: array[0..147] of Byte;
  req: Types.TPathReq;
  { Unused in this version; see the other implementations of this routine. }
  pathCount: Integer;
  n: Byte;
  count: Byte;
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  stop: Byte;
  lastPass: Boolean;
  done: Boolean;
  camX: ShortInt;
  camY: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  accX: ShortInt;
  accY: ShortInt;
  dirX: ShortInt;
  dirY: ShortInt;
  stepX: ShortInt;
  stepY: ShortInt;
  pixX: ShortInt;
  pixY: ShortInt;
begin
  prevX := startX;
  prevY := startY;
  FillChar(steps, SizeOf(steps), 8);
  FillChar(req, SizeOf(req), 0);
  n := 0;
  frame := 0;
  req.sx := startX * 3;
  req.sy := startY * 3;
  req.ex := endX * 3;
  req.ey := endY * 3;
  Pathing.PathFind(req);
  repeat
    done := not Pathing.NextPathStep(req);
    steps[n] := req.step;
    Inc(n);
  until done;
  count := n;
  if count < 2 then Exit;
  dirX := endX - startX;
  dirY := endY - startY;
  if not CbtMap.ViewCoordsValid(startX - GDVars.arenaPtr^.ox, startY - GDVars.arenaPtr^.oy) or
      not CbtMap.ViewCoordsValid(endX - GDVars.arenaPtr^.ox, endY - GDVars.arenaPtr^.oy) then begin
    if (Abs(dirX) <= 6) and (Abs(dirY) <= 6) then begin
      lastPass := True;
      camX := startX + dirX div 2;
      camY := startY + dirY div 2;
    end else begin
      lastPass := False;
      camX := GDVars.arenaPtr^.ox + 3;
      camY := GDVars.arenaPtr^.oy + 3;
    end;
  end else begin
    lastPass := True;
    camX := GDVars.arenaPtr^.ox + 3;
    camY := GDVars.arenaPtr^.oy + 3;
  end;
  CbtMap.ScrollView(camX, camY, 255, 8);
  n := 0;
  accX := 0;
  accY := 0;
  repeat
    pixX := (startX - GDVars.arenaPtr^.ox) * 3 + accX;
    pixY := (startY - GDVars.arenaPtr^.oy) * 3 + accY;
    prevX := startX;
    prevY := startY;
    done := False;
    repeat
      if (pace > 0) or (pixX mod 3 = 0) or (pixY mod 3 = 0) then begin
        Blit.BlitTileClipped(pixX, pixY, frame, 5, GDVars.moveIconSheet, GDVars.viewBuffer);
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.saveUnder, GDVars.viewBuffer);
        Inc(frame);
        if frame >= frames then
          frame := 0;
      end;
      Inc(n);
      stepX := GDConsts.dirDx[steps[n]];
      stepY := GDConsts.dirDy[steps[n]];
      Inc(pixX, stepX);
      Inc(pixY, stepY);
      if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then
        done := True;
      if not done and (n < count) then begin
        Inc(accX, stepX);
        Inc(accY, stepY);
        if Abs(accX) = 3 then begin
          Inc(startX, Pathing.SignOf(accX));
          Inc(camX, Pathing.SignOf(accX));
          accX := 0;
        end;
        if Abs(accY) = 3 then begin
          Inc(startY, Pathing.SignOf(accY));
          Inc(camY, Pathing.SignOf(accY));
          accY := 0;
        end;
      end;
    until (n >= count) or done;
    if n < count then begin
      dirX := Pathing.SignOf(prevX - startX);
      dirY := Pathing.SignOf(prevY - startY);
      if dirX <> 0 then begin
        if startX >= GDVars.arenaPtr^.ox + 6 then
          camX := startX + 3
        else if startX <= GDVars.arenaPtr^.ox then
          camX := startX - 3;
      end;
      if dirY <> 0 then begin
        if startY >= GDVars.arenaPtr^.oy + 6 then
          camY := startY + 3
        else if startY <= GDVars.arenaPtr^.oy then
          camY := startY - 3;
      end;
      CbtMap.ScrollView(camX, camY, 255, 8);
    end else begin
      lastPass := True;
      if not CbtMap.ViewCoordsValid(endX - GDVars.arenaPtr^.ox, endY - GDVars.arenaPtr^.oy) then
        CbtMap.ScrollView(endX, endY, 3, 8);
      pixX := (endX - GDVars.arenaPtr^.ox) * 3;
      pixY := (endY - GDVars.arenaPtr^.oy) * 3;
      Blit.BlitTileClipped(pixX, pixY, frame, 5, GDVars.moveIconSheet, GDVars.viewBuffer);
      if pace > 0 then begin
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.saveUnder, GDVars.viewBuffer);
      end;
    end;
  until lastPass;
  Blit.FlushView;
end;

procedure PrintNameStringAnim(creature: Types.PCharRecord; effect: Boolean; s: Types.TStr40);
var
  gx: ShortInt;
  gy: ShortInt;
  cell: Byte;
  j: Byte;
  i: Byte;
  reps: Byte;
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
    if effect then
      cell := 22
    else
      cell := 23;
    CharHlp.BuildIconFacings(cell);
    if not CbtMap.CombatIconVisible(creature, 1) then
      CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 3, 8);
    if effect then
      SoundDrv.SoundCommand(GDConsts.soundIds.combat[0])
    else
      SoundDrv.SoundCommand(GDConsts.soundIds.damage);
    CharHlp.PrintCreatureMessage(creature, s, 10, False);
    if effect then
      reps := GDVars.gameDelay
    else
      reps := 0;
    gx := GDVars.gridX[CbtMap.CombatSlot(creature)] * 3;
    gy := GDVars.gridY[CbtMap.CombatSlot(creature)] * 3;
    for i := 0 to reps do
      for j := 0 to 3 do begin
        Blit.BlitTileClipped(gx, gy, j, 5, GDVars.moveIconSheet, GDVars.viewBuffer);
        Blit.FlushView;
        Delay(70);
        Blit.BlitTileClipped(gx, gy, 0, 0, GDVars.saveUnder, GDVars.viewBuffer);
      end;
    Blit.FlushView;
    if reps = 0 then
      TextRend.PauseOnly;
  end else
    CharHlp.PrintCreatureMessage(creature, s, 10, True);
end;

function HasEffect(creature: Types.PCharRecord; id: Byte; var effect: Types.PEffectRec): Boolean;
var
  found: Boolean;
begin
  found := False;
  effect := creature^.effectsAddr;
  while (effect <> nil) and not found do begin
    if effect^.id = id then
      found := True
    else
      effect := effect^.next;
  end;
  HasEffect := found;
end;

procedure InflictDamage(creature: Types.PCharRecord; dmg: Byte);
var
  over: Byte;
  remain: Byte;
begin
  over := 0;
  remain := 0;
  if creature^.hpCur >= dmg then
    remain := creature^.hpCur - dmg
  else
    over := dmg - creature^.hpCur;
  if (over > 9) or ((remain = 0) and (creature^.status = C_Status.ANIMATED)) then
    creature^.status := C_Status.DEAD_STATUS
  else if over > 0 then begin
    creature^.status := C_Status.DYING;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then
      creature^.combatAddr^.overkill := over;
  end else if remain = 0 then
    creature^.status := C_Status.UNCONSCIOUS;
  if not (creature^.status in [C_Status.OKAY, C_Status.ANIMATED]) then begin
    creature^.enabled := 0;
    creature^.hpCur := 0;
    if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
      Dec(GDVars.teamCount[creature^.hostile]);
      creature^.combatAddr^.initiative := 0;
    end;
  end else
    creature^.hpCur := remain;
end;

procedure AnnounceHealStatus(creature: Types.PCharRecord);
var
  s: Types.TStr40;
begin
  if creature^.hpCur = creature^.hpMax then
    s := 'is fully healed'
  else
    s := 'is partially healed';
  CharHlp.PrintCreatureMessage(creature, s, 10, True);
  if GDVars.ifcState <> C_Ifc.IN_COMBAT then
    CharHlp.DisplayParty(GDVars.curChar);
end;

function EnemyTeam(creature: Types.PCharRecord): ShortInt;
begin
  if creature^.hostile = 0 then
    EnemyTeam := 1
  else
    EnemyTeam := 0;
end;

procedure CountTeams;
var
  p: Types.PCharRecord;
begin
  GDVars.teamCount[0] := 0;
  GDVars.teamCount[1] := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.enabled <> 0 then
      Inc(GDVars.teamCount[p^.hostile]);
    p := p^.nextCharAddr;
  end;
end;

function CountTargets(creature: Types.PCharRecord; range: Byte): Byte;
var
  n: Byte;
  cnt: Byte;
  i: Byte;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), range, 255,
                          CbtMap.GetIconSize(creature), GDVars.arenaPtr);
  n := GDVars.targetCount;
  cnt := 0;
  if n > 0 then begin
    for i := 1 to n do
      if CharHlp.EnemyTeam(creature) = GDVars.creatureArr[GDVars.targetList[i].idx]^.hostile then begin
        Inc(cnt);
        Move(GDVars.targetList[i], GDVars.targetList[cnt], SizeOf(GDVars.targetList[i]));
      end;
    n := cnt;
    GDVars.targetCount := cnt;
  end;
  CountTargets := n;
  for i := 1 to n do
    GDVars.potentialTargets[i] := GDVars.targetList[i].idx;
end;

function CalcDistance(creature, other: Types.PCharRecord): Byte;
var
  saved: array[1..255] of Types.TCombatTarget;
  i: Byte;
begin
  Move(GDVars.targetList, saved, SizeOf(GDVars.targetList));
  GDVars.arenaPtr^.distMode := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 255, 255,
                          CbtMap.GetIconSize(creature), GDVars.arenaPtr);
  GDVars.arenaPtr^.distMode := 0;
  i := 1;
  while (GDVars.creatureArr[GDVars.targetList[i].idx] <> other) and (i < GDVars.targetCount) do
    Inc(i);
  CalcDistance := Integer(GDVars.targetList[i].dist) div 2;
  Move(saved, GDVars.targetList, SizeOf(GDVars.targetList));
end;

function EndActions(creature: Types.PCharRecord): Boolean;
begin
  creature^.combatAddr^.initiative := 0;
  creature^.combatAddr^.spellCast := 0;
  creature^.combatAddr^.guarding := 0;
  creature^.combatAddr^.movement := 0;
  EndActions := True;
end;

function Guard(creature: Types.PCharRecord): Boolean;
begin
  Guard := CharHlp.EndActions(creature);
  creature^.combatAddr^.guarding := 1;
  CharHlp.PrintBottomLine('Guarding');
end;

function GetCasterLevel(spell: Byte): Byte;
begin
  case Char(GDConsts.spellTable[spell].castClass) of
    #0: GetCasterLevel := GDVars.curChar^.classLevels[C_Class.CLERIC_LEVEL];
    #1: GetCasterLevel := GDVars.curChar^.classLevels[C_Class.MAGE_LEVEL];
    #2: GetCasterLevel := 12;
  end;
  if GDVars.usingItem and (GDConsts.spellTable[spell].castClass <> 2) then
    GetCasterLevel := 6;
end;

{ Draws the noncombat windows: the full screen above the bottom row, the message window and the view.
  @param(inset True to draw the picture inset's border as well.) }
procedure DrawNoncombatWindows(inset: Boolean);
begin
  Border.DrawWindow(1, 1, 38, 22, 0, White, '');
  Border.DrawWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0, White, '');
  Border.DrawWindow(1, 1, 15, 15, 0, White, '');
  if inset then
    Border.DrawWindow(3, 3, 13, 13, 0, White, '');
end;

procedure DisplayNoncombatInterface;
begin
  case Char(GDVars.ifcState) of
    #0: Border.DrawWindow(1, 1, 38, 22, 0, White, '');
    #1: begin
         CharHlp.DrawNoncombatWindows(True);
         Portrait.LoadPortraitBufs(GDVars.portraitHead, GDVars.portraitBody);
         Portrait.DisplayPortraitBufs(3, 3, True);
       end;
    #2: begin
         CharHlp.DrawNoncombatWindows(True);
         Portrait.LoadAnimation('PIC', 29, 0, GDVars.animData);
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    #4: begin
         CharHlp.DrawNoncombatWindows(True);
         MapView.DisplayMapView;
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    #3: begin
         CharHlp.DrawNoncombatWindows(False);
         MapView.DisplayMapView;
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    #6: begin
         CharHlp.DrawNoncombatWindows(True);
         Portrait.LoadAnimation('PIC', 1, 0, GDVars.animData);
         CharHlp.DisplayParty(GDVars.curChar);
       end;
  end;
end;

procedure PrintPositionAndTime;
var
  x: Byte;
  y: Byte;
  hrs: string[2];
  mins: string[2];
  info: Types.TStr40;
begin
  info := '';
  x := GDVars.partyPos.mapX;
  y := GDVars.partyPos.mapY;
  if GDVars.locType > C_Area.LOC_3D_MAP then begin
    x := GDVars.zone0^.partyX.lo;
    y := GDVars.zone0^.partyY.lo;
    if GDVars.locType = C_Area.LOC_WILD_CENTRAL then
      Inc(x, 13);
    if GDVars.locType = C_Area.LOC_WILD_EAST then
      Inc(x, 26);
  end;
  hrs := CharHlp.WordToString(GDVars.zone0^.clock.hour);
  if Length(hrs) < 2 then
    hrs := '0' + hrs;
  { A turn is ten minutes and the minute counter rolls over at ten, so turn * 10 + minute is the minute of the hour (see
    GDConsts.unitScale). }
  mins := CharHlp.WordToString(10 * GDVars.zone0^.clock.turn + GDVars.zone0^.clock.minute);
  if Length(mins) < 2 then
    mins := '0' + mins;
  if GDVars.zone0^.noAutomap = 0 then
    info := CharHlp.ByteToString(x) + ',' + CharHlp.ByteToString(y) + ' ';
  info := info + GDConsts.dirNames[GDVars.partyPos.facing] + ' ';
  info := info + hrs + ':' + mins;
  if GDVars.ifcState = C_Ifc.CAMPING then
    info := info + ' camping'
  else if GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1 > 0 then
    info := info + ' search';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.DisplayString(17, 15, LightGreen, info);
end;

procedure DisplayWildernessInterface;
begin
  GDVars.ifcState := C_Ifc.OUTDOORS;
  Wilds.DrawWildWindows;
  MapView.DisplayMapView;
  MapView.DisplayWildMapView;
  CharHlp.PrintPositionAndTime;
  CharHlp.DisplayParty(GDVars.curChar);
end;

procedure DisplayCombatInterface;
begin
  CbtMap.SetCombatPalette;
  Border.DrawWindow(1, 1, 21, 21, 0, Black, '');
  Border.DrawWindow(23, 1, 38, 21, 0, Black, '');
  Border.ClearBox(0, 23, 39, 24);
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, 8);
end;

procedure SelectChar(query: Types.TStr40; addExit: Boolean; var sel: Types.PCharRecord);
var
  ch: Char;
  ext: Boolean;
  anim: Boolean;
  p: Types.PCharRecord;
  exitStr: Types.TStr40;
begin
  ch := ' ';
  exitStr := '';
  if addExit then
    exitStr := ' Exit';
  while not (ch in [C_Keys.ENTER, C_Keys.ESCAPE, 'E', 'S']) do
  begin
    CharHlp.DisplayParty(sel);
    if (GDVars.ifcState = C_Ifc.CAMPING) or (GDVars.ifcState = C_Ifc.LOOT) then
      anim := True
    else
      anim := False;
    ch := MenuCore.MenuHorizontal(query + ' ', 'Select' + exitStr, LightMagenta, LightGreen, White, True,
                                  anim, ext);
    p := sel;
    if ext then
      case ch of
        { End: next character, wrapping to the head }
        C_Keys.END_KEY: begin
          p := p^.nextCharAddr;
          if p = nil then
            p := GDVars.creatureList;
        end;
        { Home: previous character, wrapping to the tail }
        C_Keys.HOME: begin
          p := GDVars.creatureList;
          if sel <> GDVars.creatureList then
            while p^.nextCharAddr <> sel do
              p := p^.nextCharAddr
          else
            while p^.nextCharAddr <> nil do
              p := p^.nextCharAddr;
        end;
      end else if (ch = 'E') or (ch = C_Keys.NONE) then
      p := nil;
    sel := p;
  end;
end;

function HasRangedWeapon(creature: Types.PCharRecord): Boolean;
begin
  if (creature^.equipped[C_Equip.WEAPON] <> nil) and
      (GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False;
end;

function HasThrowableWeapon(creature: Types.PCharRecord): Boolean;
begin
  if CharHlp.HasRangedWeapon(creature) and
      ((GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].props and
        C_Item.PROPS_THROWABLE) = C_Item.PROPS_THROWABLE) then
    HasThrowableWeapon := True
  else
    HasThrowableWeapon := False;
end;

function FindDamagingRangedWeapon(creature: Types.PCharRecord; var sel: Types.PItemRec): Boolean;
var
  w: Types.PItemRec;
  props: Byte;
begin
  FindDamagingRangedWeapon := False;
  w := creature^.equipped[C_Equip.WEAPON];
  sel := nil;
  props := 0;
  if w <> nil then begin
    props := GDVars.baseItems[w^.itemType].props;
    if (props and C_Item.PROP_THROWN) <> 0 then
      sel := w;
    if (props and C_Item.PROP_FIRES_AMMO) <> 0 then begin
      if (props and C_Item.PROP_ARROWS) <> 0 then
        sel := creature^.equipped[C_Equip.ARROW];
      if (props and C_Item.PROP_QUARRELS) <> 0 then
        sel := creature^.equipped[C_Equip.BOLT];
    end;
  end;
  if (sel <> nil) or (props = CharHlp.ITEM_PROP_DEX_MISSILE + C_Item.PROP_FIRES_AMMO) then
    FindDamagingRangedWeapon := True;
end;

function AtLevelCap(creature: Types.PCharRecord; cls: ShortInt): Boolean;
var
  lvl: ShortInt;
begin
  AtLevelCap := False;
  with creature^ do begin
    lvl := classLevels[cls];
    if lvl <= 0 then
      Exit;
    case Char(race) of
      Char(C_Race.DWARF):
        if cls = C_Class.FIGHTER_LEVEL then
          if ((lvl = 8) and (strCur = 17)) or ((lvl = 7) and (strCur < 17)) then
            AtLevelCap := True;
      Char(C_Race.ELF):
        if cls = C_Class.FIGHTER_LEVEL then
          if (lvl = 7) or ((lvl = 6) and (strCur = 17)) or ((lvl = 5) and (strCur < 17)) then
            AtLevelCap := True;
      Char(C_Race.GNOME):
        if cls = C_Class.FIGHTER_LEVEL then
          if (lvl = 6) or ((lvl = 5) and (strCur < 18)) then
            AtLevelCap := True;
      Char(C_Race.HALF_ELF):
        if (cls = C_Class.CLERIC_LEVEL) and (lvl = 5) then
          AtLevelCap := True
        else if cls = C_Class.FIGHTER_LEVEL then
          if (lvl = 8) or ((lvl = 7) and (strCur = 17)) or ((lvl = 6) and (strCur < 17)) then
            AtLevelCap := True;
      Char(C_Race.HALFLING):
        if cls = C_Class.FIGHTER_LEVEL then
          if (lvl = 6) or ((lvl = 5) and (strCur = 17)) or ((lvl = 4) and (strCur < 17)) then
            AtLevelCap := True;
    end;
  end;
end;

procedure NoopCharHlp;
begin
end;

begin
end.
