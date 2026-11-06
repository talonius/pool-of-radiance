{ Coin conversion, treasure collection, money menus and random item generation. }
{$O+,F+}
unit Money;

interface

uses Types, Crt, C_Npc, GDConsts, GDVars, MenuCore, GameIo, TextRend, Border, CharHlp, FxEngine, C_Keys,
  C_Ifc, C_Money;

{ Works out how many coins of weight a character can carry: its weight allowance plus 1500.
  @param(p The character.)
  @returns(The carrying capacity.) }
function CarryingCapacity(p: Types.PCharRecord): Word;

{ Takes weight off a character's encumbrance.
  @param(p The character.)
  @param(w The weight.) }
procedure RemoveWeight(p: Types.PCharRecord; w: Word);

{ Adds weight to a character's encumbrance.
  @param(p The character.)
  @param(w The weight.) }
procedure AddWeight(p: Types.PCharRecord; w: Word);

{ Tells whether carrying more coins would overload a character.
  @param(p The character.)
  @param(w The coins.)
  @param(takable Receives how many coins still fit when the character would be overloaded; 0 otherwise.)
  @returns(True when the coins would exceed the character's capacity.) }
function CheckOverload(p: Types.PCharRecord; w: Word; var takable: Word): Boolean;

{ Pools the money of each party member that is not an NPC, or is an animated member, and sets treasureMoneyFlag. }
procedure PoolMoney;

{ Counts the party members whose money PoolMoney pools.
  @returns(The count.) }
function CountPoolers: Byte;

{ Shares out the pooled money. Each type's share is the pool divided by CountPoolers, the remainder held back. The first
  pass gives each creature that is not an NPC its share of each type, from jewelry down to copper, or as much as fits
  with the rest held back, and one more coin while the whole remainder would fit. The second pass hands out what is left
  to each creature in turn as far as it can carry, and anything over goes back to the pool. Note: the divisor counts
  animated members, whom the first pass skips, and not NPC values below $80, whom it pays. }
procedure ShareMoney;

{ Runs the take-money menu over the pooled coin types, copper first: the amount asked for, at most the low word of the
  pool's amount, is taken by the current character. It repeats while money is left. Note: the menu entries are freed
  only after a take, not when the menu is left. }
procedure TakeMoneyMenu;

{ Gives platinum to the current character; what does not fit goes to the pooled money.
  @param(pp The platinum pieces.) }
procedure GivePlatinum(pp: Word);

{ Reads a money type from the start of a menu entry. Leading spaces are skipped, unchecked; the first letter gives the
  type, and for G the second letter, upper-cased, tells gems from gold. An unknown letter leaves the result and the name
  unset.
  @param(s The menu entry.)
  @param(typeName Receives the type's name, as the take prompt shows it.)
  @returns(The money type.) }
function ParseMoneyType(s: String; var typeName: String): ShortInt;

{ Reads an amount on the bottom row after a prompt: digits, Backspace, Enter and Escape are taken, and the amount is
  held to the maximum as digits are typed.
  @param(max The largest amount.)
  @param(query The prompt.)
  @param(color The prompt's color.)
  @returns(The amount; 0 for Escape.) }
function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;

{ Moves coins of one type from one character to another when the receiver can carry them, and otherwise says it is
  overloaded. Note: the weight is taken off the giver and then added back to the giver, not to the receiver.
  @param(giver The character giving the coins.)
  @param(rcv The character receiving them.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: Word; mType: ShortInt);

{ Drops coins of one type from a character. In a shop, temple or loot menu they go to the pooled money; elsewhere they
  are lost.
  @param(p The character.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure DropMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);

{ Tells whether money or items are left in the pool.
  @param(treasure Receives True when money is left.)
  @param(items Receives True when items are left.) }
procedure DetermineTreasure(var treasure, items: Boolean);

{ Sets the current character's coins to a worth in gold: platinum for each five gold pieces and gold for the rest. The
  other coin types are cleared; gems and jewelry are kept.
  @param(gp The worth in gold pieces.) }
procedure SetCreatureCoinsInGold(gp: Word);

{ Sets the pooled coins to a worth in gold: platinum for each five gold pieces and gold for the rest. The other coin
  types are cleared; gems and jewelry are kept.
  @param(gp The worth in gold pieces.) }
procedure SetTreasureCoinsInGold(gp: Word);

{ Works out the worth of the five coin types in gold, rounding half up; gems and jewelry are left out.
  @param(m The money.)
  @returns(The worth in gold pieces.) }
function CoinValueInGold(m: Types.TMoney): LongInt;

{ Builds a random item of a kind. Kinds 1 to 59, 73, 77 and 93 are weapons and armor, named from their type, with a
  RandomBonus plus and a weight and value by type. Kinds 61 and 62 are magic-user and cleric scrolls holding 1d3 rolled
  spells. Kinds 63, 67, 69 to 71, 78, 79, 84 and 92 take a random-item template, by its word index. Any other kind gets
  only its type and the defaults. Note: kind 21 can take word index 144, which is not a template's start, and kind 78
  never takes template 49 and makes nothing on a roll of 4.
  @param(kind The item kind.)
  @param(item Receives the item.) }
procedure GenerateRandomItem(kind: Byte; var item: Types.TItemRec);

{ Runs the appraisal of the current character's gems and jewelry, one at a time. Sell pays a fifth of the value in
  platinum, the remainder lost. Keep, offered while one more coin fits and the character has fewer than 16 items, makes
  an item worth the appraisal. Note: with no items the kept item is assigned only to a local and lost.
  @param(ok Receives False when there is nothing to appraise.) }
procedure AppraiseMenu(var ok: Boolean);

implementation

type
  TLoW = record
    lo: Word;
    hi: Word;
  end;

var
  { lo-word view }
  treasureMoneyLo: array[C_Money.COPPER..C_Money.JEWELRY] of TLoW absolute GDVars.treasureMoney;

function CarryingCapacity(p: Types.PCharRecord): Word;
begin
  CarryingCapacity := CharHlp.WeightAllowance(p) + 1500;
end;

procedure RemoveWeight(p: Types.PCharRecord; w: Word);
begin
  p^.encumbrance := p^.encumbrance - w;
end;

procedure AddWeight(p: Types.PCharRecord; w: Word);
begin
  p^.encumbrance := p^.encumbrance + w;
end;

function CheckOverload(p: Types.PCharRecord; w: Word; var takable: Word): Boolean;
begin
  if p^.encumbrance + w > Money.CarryingCapacity(p) then begin
    CheckOverload := True;
    takable := Money.CarryingCapacity(p) - p^.encumbrance;
  end else begin
    CheckOverload := False;
    takable := 0;
  end;
end;

function CoinValueInGold(m: Types.TMoney): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := C_Money.COPPER to C_Money.PLATINUM do
    Inc(total, GDConsts.coinValues[i] * m[i]);
  CoinValueInGold := (total + 100) div GDConsts.coinValues[C_Money.GOLD];
end;

procedure SetCreatureCoinsInGold(gp: Word);
var
  i: ShortInt;
begin
  for i := C_Money.COPPER to C_Money.PLATINUM do
    GDVars.curChar^.coins[i] := 0;
  { platinum }
  GDVars.curChar^.coins[C_Money.PLATINUM] := gp div 5;
  { gold }
  GDVars.curChar^.coins[C_Money.GOLD] := gp mod 5;
end;

procedure SetTreasureCoinsInGold(gp: Word);
var
  i: ShortInt;
begin
  for i := C_Money.COPPER to C_Money.PLATINUM do
    GDVars.treasureMoney[i] := 0;
  GDVars.treasureMoney[C_Money.PLATINUM] := gp div 5;
  GDVars.treasureMoney[C_Money.GOLD] := gp mod 5;
end;

procedure GivePlatinum(pp: Word);
var
  takable: Word;
begin
  if Money.CheckOverload(GDVars.curChar, pp, takable) then begin
    CharHlp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    Inc(GDVars.curChar^.coins[C_Money.PLATINUM], takable);
    Money.AddWeight(GDVars.curChar, takable);
    GDVars.treasureMoney[C_Money.PLATINUM] := pp + GDVars.treasureMoney[C_Money.PLATINUM] - takable;
  end else begin
    Inc(GDVars.curChar^.coins[C_Money.PLATINUM], pp);
    Money.AddWeight(GDVars.curChar, pp);
  end;
end;

function InputNumberMax;
var
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  maxLen: Byte;
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  v: LongInt;
  code: Integer;
  n: Word;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, query);
  qLen := Length(query);
  col := qLen;
  Str(max, maxStr);
  s := '';
  repeat
    ch := GameIo.ReadGameKey;
    case ch of
      '0'..'9': begin
          s := Concat(s, ch);
          Val(s, v, code);
          if max >= v then
            Inc(col)
          else begin
            s := maxStr;
            col := qLen + Length(maxStr);
          end;
          TextRend.DisplayString(qLen, 24, White, s);
        end;
      C_Keys.BACKSPACE: if Length(s) > 0 then begin
          s := Copy(s, 1, Length(s) - 1);
          TextRend.PrintSpaces(col, 24, Black, 1);
          Dec(col);
        end;
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESCAPE);
  TextRend.PrintSpaces(0, 24, Black, 40);
  if ch = C_Keys.ESCAPE then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  if rcv^.encumbrance + qty <= Money.CarryingCapacity(rcv) then begin
    giver^.coins[mType] := giver^.coins[mType] - qty;
    Money.RemoveWeight(giver, qty);
    rcv^.coins[mType] := rcv^.coins[mType] + qty;
    Money.AddWeight(giver, qty);
  end else
    CharHlp.PrintBottomLine('Overloaded');
end;

procedure PoolMoney;
var
  p: Types.PCharRecord;
  i: ShortInt;
  mt: ShortInt;
begin
  p := GDVars.creatureList;
  GDVars.treasureMoneyFlag := True;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_MEMBER) then begin
      for i := C_Money.COPPER to C_Money.JEWELRY do begin
        mt := i;
        GDVars.treasureMoney[mt] := p^.coins[mt] + GDVars.treasureMoney[mt];
        Money.RemoveWeight(p, p^.coins[mt]);
      end;
      FillChar(p^.coins, SizeOf(p^.coins), 0);
    end;
    p := p^.nextCharAddr;
  end;
end;

function CountPoolers: Byte;
var
  p: Types.PCharRecord;
  n: Byte;
begin
  p := GDVars.creatureList;
  n := 0;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_MEMBER) then
      Inc(n);
    p := p^.nextCharAddr;
  end;
  CountPoolers := n;
end;

procedure ShareMoney;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  receiver: Types.PCharRecord;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  takable: Word;
  share: array[C_Money.COPPER..C_Money.JEWELRY] of Word;
  rem: array[C_Money.COPPER..C_Money.JEWELRY] of Word;
  i: ShortInt;
begin
  p := GDVars.creatureList;
  done := False;
  cnt := Money.CountPoolers;
  FillChar(share, SizeOf(share), 0);
  FillChar(rem, SizeOf(rem), 0);
  for i := C_Money.COPPER to C_Money.JEWELRY do
    if GDVars.treasureMoney[i] > 0 then begin
      share[i] := GDVars.treasureMoney[i] div cnt;
      rem[i] := GDVars.treasureMoney[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  { pass 1: shares }
  while p <> nil do begin
    { NON_PLAYER clear }
    if p^.npc < C_Npc.NON_PLAYER then
      for i := C_Money.JEWELRY downto C_Money.COPPER do
        if not Money.CheckOverload(p, share[i], takable) then begin
          p^.coins[i] := share[i] + p^.coins[i];
          Money.AddWeight(p, share[i]);
          if rem[i] > 0 then
            if not Money.CheckOverload(p, rem[i], takable) then begin
              p^.coins[i] := p^.coins[i] + 1;
              Money.AddWeight(p, 1);
              Dec(rem[i]);
            end;
        end else begin
          p^.coins[i] := p^.coins[i] + takable;
          rem[i] := rem[i] + share[i] - takable;
          Money.AddWeight(p, takable);
        end;
    p := p^.nextCharAddr;
  end;
  { pass 2: leftovers }
  for i := C_Money.JEWELRY downto C_Money.COPPER do
    if rem[i] > 0 then begin
      p := GDVars.creatureList;
      while p <> nil do begin
        takable := Money.CarryingCapacity(p) - p^.encumbrance;
        if takable > 0 then
          if rem[i] > takable then begin
            p^.coins[i] := p^.coins[i] + takable;
            Money.AddWeight(p, takable);
            rem[i] := rem[i] - takable;
          end else begin
            p^.coins[i] := p^.coins[i] + rem[i];
            Money.AddWeight(p, rem[i]);
            rem[i] := 0;
          end;
        p := p^.nextCharAddr;
      end;
    end;
  { return the rest to the pool }
  GDVars.treasureMoneyFlag := False;
  for i := C_Money.COPPER to C_Money.JEWELRY do begin
    GDVars.treasureMoney[i] := rem[i];
    if GDVars.treasureMoney[i] <> 0 then
      GDVars.treasureMoneyFlag := True;
  end;
end;

procedure DropMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  p^.coins[mType] := p^.coins[mType] - qty;
  Money.RemoveWeight(p, qty);
  if (GDVars.ifcState = C_Ifc.LOOT) or (GDVars.ifcState = C_Ifc.SHOP_TEMPLE) then
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] + qty;
end;

{ Takes coins of one type from the pooled money for a character; an amount above the pool is cut to the pool's low word.
  The whole take is refused, the character overloaded, when the amount asked for would overload it; there is no partial
  take.
  @param(p The character.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TakeMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);
var
  takable: Word;
begin
  if Money.CheckOverload(p, qty, takable) then
    CharHlp.PrintBottomLine('Overloaded')
  else begin
    if qty > GDVars.treasureMoney[mType] then
      qty := treasureMoneyLo[mType].lo;
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] - qty;
    p^.coins[mType] := p^.coins[mType] + qty;
    Money.AddWeight(p, qty);
  end;
end;

function ParseMoneyType(s: String; var typeName: String): ShortInt;
var
  i: Byte;
begin
  i := 1;
  while s[i] = ' ' do
    Inc(i);
  case s[i] of
    'G': if UpCase(s[i + 1]) = 'E' then begin
           ParseMoneyType := C_Money.GEMS;
           typeName := 'Gems ';
         end else begin
           typeName := 'Gold ';
           ParseMoneyType := C_Money.GOLD;
         end;
    'P': begin
           typeName := 'Platinum ';
           ParseMoneyType := C_Money.PLATINUM;
         end;
    'E': begin
           typeName := 'electrum ';
           ParseMoneyType := C_Money.ELECTRUM;
         end;
    'S': begin
           typeName := 'silver ';
           ParseMoneyType := C_Money.SILVER;
         end;
    'C': begin
           typeName := 'Copper ';
           ParseMoneyType := C_Money.COPPER;
         end;
    'J': begin
           typeName := 'Jewelry ';
           ParseMoneyType := C_Money.JEWELRY;
         end;
  end;
end;

procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  weight: Word;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  save: Types.PItemRec;
  cnt: Word;
  idx: Integer;
  numStr: String;
  n: Word;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindow(1, 1, 38, 22, 0, LightGreen, '');
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := C_Money.JEWELRY downto C_Money.COPPER do
      if GDVars.treasureMoney[i] > 0 then begin
        Inc(cnt);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TMenuNode));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TMenuNode));
          p^.next := sel;
        end;
        Str(GDVars.treasureMoney[i], numStr);
        p^.name := GDConsts.moneyNames[i] + ' ' + numStr;
        p^.inUse := 0;
      end;
    sel := p;
    save := p;
    ch := MenuCore.MenuVertical('Select type of coin', '', LightMagenta, LightGreen, White, 2, 2,
                                15, 8, p, True, redraw, idx, sel);
    if (sel = nil) or (ch = C_Keys.NONE) then
      exitF := True
    else begin
      exitF := False;
      mType := Money.ParseMoneyType(sel^.name, numStr);
      numStr := 'How much ' + numStr + 'will you take? ';
      n := Money.InputNumberMax(treasureMoneyLo[mType].lo, numStr, LightGreen);
      Money.TakeMoney(GDVars.curChar, n, mType);
      MenuCore.FreeStringList(save);
      GDVars.treasureMoneyFlag := False;
      exitF := True;
      for i := C_Money.COPPER to C_Money.JEWELRY do
        if GDVars.treasureMoney[i] > 0 then begin
          GDVars.treasureMoneyFlag := True;
          exitF := False;
        end;
    end;
  until exitF;
end;

procedure DetermineTreasure(var treasure, items: Boolean);
var
  i: ShortInt;
begin
  treasure := False;
  items := False;
  for i := C_Money.COPPER to C_Money.JEWELRY do
    if GDVars.treasureMoney[i] <> 0 then
      treasure := True;
  if GDVars.treasureItems <> nil then
    items := True;
end;

{ Rolls a random weapon's or armor's plus on a d20: 1 (70 percent), 2 (25 percent) or 3 (5 percent).
  @returns(The plus.) }
function RandomBonus: ShortInt;
var
  r: Byte;
begin
  r := FxEngine.RollDice(1, 20);
  case r of
    1..14: RandomBonus := 1;
    15..19: RandomBonus := 2;
    else RandomBonus := 3;
  end;
end;

procedure GenerateRandomItem(kind: Byte; var item: Types.TItemRec);
var
  r: Byte;
  n: Byte;
  j: Byte;
  templateWordIndex: Byte;
  spell: Byte;
begin
  { clear the whole item record }
  FillChar(item, SizeOf(Types.TItemRec), 0);
  templateWordIndex := 0;
  with item do begin
    FillChar(spells, SizeOf(spells), 0);
    next := nil;
    equipped := 0;
    unidMask := 6;
    cursed := 0;
    itemType := kind;
    FillChar(nameIds, SizeOf(nameIds), 0);
    case itemType of
      1..59, 73, 77, 93: begin
          plus := Money.RandomBonus;
          case itemType of
            { One time in five, index 144: not a template start, so the item gets the last word of template 18 and the
              first seven of template 19. Template 14 (Javelin of Lightning, index 105) is never selected. }
            21: begin
                   r := FxEngine.RollDice(1, 5);
                   if r = 5 then
                     templateWordIndex := 144;
                   nameIds[3] := 21;
                   nameIds[2] := plus + 161;
                 end;
            28: begin
                   nameIds[3] := 28;
                   nameIds[2] := plus + 161;
                 end;
            50, 51: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 49;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            52: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 50;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            53..58: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 48;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            73: begin
                   nameIds[3] := 61;
                   nameIds[2] := plus + 161;
                 end;
            { bracers: plus 1..3 becomes 4/6/8, named AC 6/4/2 }
            77: begin
                   nameIds[3] := 79;
                   nameIds[2] := 167;
                   plus := plus * 2 + 2;
                   case plus of
                     4: nameIds[1] := 221;
                     6: nameIds[1] := 222;
                     8: nameIds[1] := 220;
                   end;
                 end;
            93: begin
                   nameIds[3] := 66;
                   nameIds[2] := 224;
                   nameIds[1] := plus + 161;
                 end;
            else begin
                   nameIds[3] := itemType;
                   nameIds[2] := plus + 161;
                 end;
          end;
          saveBonus := 0;
          quantity := 0;
          { weight in coins }
          case itemType of
            1, 13, 14, 35:
              weight := 75;
            2, 20, 29, 31, 32, 33, 39, 42, 44, 46, 59:
              weight := 50;
            3, 24, 40:
              weight := 125;
            4, 15, 23, 34, 43, 45, 51:
              weight := 100;
            5, 12, 17, 19, 50:
              weight := 150;
            6: weight := 15;
            7: weight := 30;
            8, 77:
              weight := 10;
            9: begin
                 weight := 25;
                 quantity := 5;
               end;
            10, 26, 36:
              weight := 60;
            11, 16, 25, 27, 41, 47:
              weight := 80;
            18: weight := 175;
            21: weight := 20;
            22, 30:
              weight := 40;
            37: weight := 35;
            38, 53:
              weight := 250;
            52: weight := 200;
            54, 56:
              weight := 400;
            55: weight := 300;
            57: weight := 350;
            58: weight := 450;
            { Only 93 reaches this arm; 47 is matched above }
            47, 93:
              weight := 1;
            else begin
                   weight := 40;
                   quantity := 10;
                 end;
          end;
          { value in gp = plus * K }
          case itemType of
            59: value := plus * 2500;
            73, 28: value := plus * 150;
            53, 54: value := plus * 3000;
            55, 56: value := plus * 3500;
            57: value := plus * 4000;
            58: value := plus * 5000;
            77: value := plus * 3000;
            else value := plus * 2000;
          end;
        end;
      { scrolls }
      61, 62: begin
          n := FxEngine.RollDice(1, 3);
          if itemType = 61 then
            nameIds[3] := 209
          else
            nameIds[3] := 208;
          nameIds[2] := n + 209;
          nameIds[1] := 0;
          plus := 1;
          weight := 25;
          quantity := 0;
          value := 0;
          for j := 1 to n do begin
            r := FxEngine.RollDice(1, 3);
            if itemType = 61 then
              { magic-user spell ids: 9..21, 29..35, 45..55 }
              case r of
                1: spell := FxEngine.RollDice(1, 13) + 8;
                2: spell := FxEngine.RollDice(1, 7) + 28;
                3: spell := FxEngine.RollDice(1, 11) + 44;
              end else
              { clerical spell ids: 1..8, 22..28, 36..44 }
              case r of
                1: spell := FxEngine.RollDice(1, 8);
                2: spell := FxEngine.RollDice(1, 7) + 21;
                3: spell := FxEngine.RollDice(1, 9) + 35;
              end;
            spells[j] := spell;
            value := r * 300 + value;
          end;
        end;
      63: templateWordIndex := 73;
      67: templateWordIndex := 145;
      69: begin
             r := FxEngine.RollDice(1, 10);
             case r of
               1: templateWordIndex := 41;
               2..6: templateWordIndex := 121;
               7..10: templateWordIndex := 129;
             end;
           end;
      78: begin
             { r is 2..4 vs labels 1..3: 49 is never chosen and r = 4 leaves no template }
             r := FxEngine.RollDice(1, 3) + 1;
             case r of
               1: templateWordIndex := 49;
               2: templateWordIndex := 65;
               3: templateWordIndex := 113;
             end;
           end;
      79: templateWordIndex := 57;
      84: templateWordIndex := 9;
      92: templateWordIndex := 97;
      71: begin
             { 11 makes nothing }
             r := FxEngine.RollDice(1, 11);
             case r of
               1..5: templateWordIndex := 17;
               6..8: templateWordIndex := 1;
               9: templateWordIndex := 25;
               10: templateWordIndex := 81;
             end;
           end;
      70: begin
             r := FxEngine.RollDice(1, 10);
             case r of
               1..7: templateWordIndex := 89;
               8..10: templateWordIndex := 137;
             end;
           end;
    end;
    if templateWordIndex <> 0 then begin
      for j := 0 to 2 do
        nameIds[j + 1] := GDConsts.randomItemTemplates.wordBytes[templateWordIndex + j].lo;
      plus := 1;
      saveBonus := 1;
      if templateWordIndex = 97 then begin
        plus := 2;
        saveBonus := 2;
      end;
      weight := GDConsts.randomItemTemplates.words[templateWordIndex + 3];
      quantity := 0;
      value := GDConsts.randomItemTemplates.words[templateWordIndex + 4];
      for j := 1 to 3 do
        spells[j] := GDConsts.randomItemTemplates.wordBytes[templateWordIndex + 4 + j].lo;
    end;
  end;
end;

procedure AppraiseMenu(var ok: Boolean);
var
  gemStr: String[40];
  jwlStr: String[40];
  ch: Char;
  menu: String[40];
  actionStr: String[40];
  r: Byte;
  value: Word;
  takable: Word;
  p: Types.PItemRec;
  gem: Types.PItemRec;
  exitF: Boolean;
  ext: Boolean;
  mustSell: Boolean;
begin
  ok := True;
  if (GDVars.curChar^.coins[C_Money.GEMS] = 0) and
      (GDVars.curChar^.coins[C_Money.JEWELRY] = 0) then begin
    CharHlp.PrintBottomLine('No Gems or Jewelry');
    ok := False;
  end else
    repeat
      if (GDVars.curChar^.coins[C_Money.GEMS] = 0) and (GDVars.curChar^.coins[C_Money.JEWELRY] = 0) then
        exitF := True
      else begin
        exitF := False;
        Str(GDVars.curChar^.coins[C_Money.GEMS], gemStr);
        Str(GDVars.curChar^.coins[C_Money.JEWELRY], jwlStr);
        case GDVars.curChar^.coins[C_Money.GEMS] of
          0: gemStr := '';
          1: gemStr := gemStr + ' Gem';
          else gemStr := gemStr + ' Gems';
        end;
        case GDVars.curChar^.coins[C_Money.JEWELRY] of
          0: jwlStr := '';
          1: jwlStr := jwlStr + ' piece of Jewelry';
          else jwlStr := jwlStr + ' pieces of Jewelry';
        end;
        TextRend.ClearRect(1, 1, 38, 22);
        CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, False);
        TextRend.DisplayString(1, 7, White, 'You have a fine collection of:');
        TextRend.DisplayString(1, 9, White, gemStr);
        TextRend.DisplayString(1, 10, White, jwlStr);
        menu := '';
        if GDVars.curChar^.coins[C_Money.GEMS] <> 0 then
          menu := '  Gems';
        if GDVars.curChar^.coins[C_Money.JEWELRY] <> 0 then
          menu := menu + '  Jewelry';
        menu := menu + ' Exit';
        ch := MenuCore.MenuHorizontal('Appraise : ', menu, LightMagenta, LightGreen, White, True,
                                      False, ext);
        case ch of
          'G': if GDVars.curChar^.coins[C_Money.GEMS] <> 0 then begin
              Dec(GDVars.curChar^.coins[C_Money.GEMS]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..25: value := 10;
                26..50: value := 50;
                51..70: value := 100;
                71..90: value := 500;
                91..99: value := 1000;
                100: value := 5000;
              end;
              Str(value, gemStr);
              gemStr := 'The Gem is Valued at ' + gemStr + ' gp.';
              TextRend.DisplayString(1, 12, White, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen,
                                            White, True, False, ext);
              if (ch = 'K') and (not mustSell) then begin
                { a whole item record }
                GetMem(gem, SizeOf(Types.TItemRec));
                FillChar(gem^, SizeOf(Types.TItemRec), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 101;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 70;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  p := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else begin
                value := value div 5;
                Money.GivePlatinum(value);
              end;
            end;
          'J': if GDVars.curChar^.coins[C_Money.JEWELRY] <> 0 then begin
              Dec(GDVars.curChar^.coins[C_Money.JEWELRY]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..10: value := Trunc(Random(900)) + 100;
                11..20: value := Trunc(Random(1000)) + 200;
                21..40: value := Trunc(Random(1500)) + 300;
                41..50: value := Trunc(Random(2500)) + 500;
                51..70: value := Trunc(Random(5000)) + 1000;
                71..90: value := Trunc(Random(6000)) + 2000;
                91..100: value := Trunc(Random(10000)) + 2000;
              end;
              Str(value, jwlStr);
              gemStr := 'The Jewel is Valued at ' + jwlStr + ' gp.';
              TextRend.DisplayString(1, 12, White, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen,
                                            White, True, False, ext);
              if (ch = 'K') and (not mustSell) then begin
                { a whole item record }
                GetMem(gem, SizeOf(Types.TItemRec));
                FillChar(gem^, SizeOf(Types.TItemRec), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 214;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 70;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  p := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else begin
                value := value div 5;
                Money.GivePlatinum(value);
              end;
            end;
          'E', C_Keys.NONE:
            exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.curChar);
      end;
    until exitF;
end;

begin
end.
