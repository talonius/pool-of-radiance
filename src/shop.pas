{ Shop menus, item selection and purchases. Shop inventory uses the shared treasure state. }
{$O+,F+}
unit Shop;

interface

uses Types, Crt, C_Msg, GDConsts, GDVars, TextRend, Border, CharHlp, MenuCore, EclMenu, ViewChar, Money, C_Keys,
  C_Ifc;

{ Runs the shop: buy, view, take, pool, share and appraise, with Take and Share offered only while there is pooled
  money. The pooled money starts empty. Leaving with money still in the pool asks whether to go back for it. }
procedure ShopMainMenu;

{ Gives the current character a copy of an item at the end of its items and recalculates its stats, unless it cannot
  carry the item, which reports the character as overloaded.
  @param(item The item to copy.)
  @param(failed Set True when the item was refused, else False.) }
procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);

implementation

{ Lets the player pick a shop item. Each item's name is rewritten as a 30-column line, the name at the left and the
  price right-justified (a zero price becomes 1), for the vertical Buy menu; the real names are rebuilt afterwards.
  @param(c Receives the menu key.)
  @param(itemToBuy Receives the highlighted item.)
  @param(cursor The highlighted item, kept from one call to the next.)
  @param(idx The menu position, kept from one call to the next.) }
procedure ShopBuyItemSelection(var c: Char; var itemToBuy: Types.PItemRec; var cursor: Types.PItemRec;
                               var idx: Integer);
var
  head: Types.PItemRec;
  p: Types.PItemRec;
  tmp: String[16];
  s: String[30];
  lenv: Byte;
  i: Byte;
  { Seeded True; MenuVertical draws the page and clears it. }
  redraw: Boolean;
begin
  redraw := True;
  p := GDVars.treasureItems;
  while p <> nil do begin
    { 30 blanks, the full width of s }
    s := '                              ';
    if p^.value = 0 then p^.value := 1;
    Str(LongInt(p^.value), tmp);
    lenv := Length(tmp);
    for i := 1 to lenv do
      s[SizeOf(s) - 1 - lenv + i] := tmp[i];
    lenv := Length(p^.name);
    for i := 1 to lenv do
      s[i] := p^.name[i];
    p^.name := s;
    p^.name[0] := Chr(SizeOf(s) - 1);
    p := p^.next;
  end;
  Border.DrawWindow(1, 1, 38, 22, 0, White, 'Shop');
  head := GDVars.treasureItems;
  c := MenuCore.MenuVertical('Items: ', 'Buy', LightMagenta, LightGreen, White, 1, 4, 38, 22, head,
                             True, redraw, idx, cursor);
  itemToBuy := cursor;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
end;

procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  if ViewChar.CannotCarryItem(GDVars.curChar, item) then begin
    CharHlp.PrintBottomLine('OverLoaded');
    failed := True;
  end else begin
    failed := False;
    p := GDVars.curChar^.itemsAddr;
    if p = nil then begin
      GetMem(p, SizeOf(Types.TItemRec));
      p^ := item^;
      p^.next := nil;
      GDVars.curChar^.itemsAddr := p;
    end else begin
      while p^.next <> nil do
        p := p^.next;
      GetMem(q, SizeOf(Types.TItemRec));
      q^ := item^;
      q^.next := nil;
      p^.next := q;
    end;
    CharHlp.RecalcStats(GDVars.curChar);
  end;
end;

{ Runs the buy menu until it is left with a key other than Buy or Enter. Each chosen item is paid for from the current
  character's coins when they cover the price, and otherwise from the pooled money. }
procedure ShopBuyMenu;
var
  itemToBuy: Types.PItemRec;
  c: Char;
  done: Boolean;
  price: Word;
  charGold: Word;
  pooled: LongInt;
  failed: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
begin
  itemToBuy := nil;
  cursor := GDVars.treasureItems;
  idx := 1;
  repeat
    Shop.ShopBuyItemSelection(c, itemToBuy, cursor, idx);
    if (c <> 'B') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      price := itemToBuy^.value;
      charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
      if price <= charGold then begin
        Shop.GiveItemCopyToCreature(itemToBuy, failed);
        if not failed then begin
          charGold := charGold - price;
          Money.SetCreatureCoinsInGold(charGold);
        end;
      end else begin
        pooled := Money.CoinValueInGold(GDVars.treasureMoney);
        if price <= pooled then begin
          Shop.GiveItemCopyToCreature(itemToBuy, failed);
          if not failed then begin
            pooled := pooled - price;
            Money.SetTreasureCoinsInGold(pooled);
          end;
        end else
          CharHlp.PrintBottomLine('Not enough money.');
      end;
    end;
  until done;
end;

procedure ShopMainMenu;
var
  menu: String[40];
  query: String[1];
  ext: Boolean;
  done: Boolean;
  c: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  ynIdx: Byte;
  apprOk: Boolean;
  p: Types.PItemRec;
begin
  GDVars.ifcState := C_Ifc.SHOP_TEMPLE;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(GDVars.treasureMoney, SizeOf(Types.TMoney), 0);
  query[0] := #0;
  GDVars.treasureMoneyFlag := False;
  done := False;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := 'Buy View Take Pool Share Appraise Exit'
    else
      menu := 'Buy View Pool Appraise Exit';
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, False, ext);
    case c of
      'B': Shop.ShopBuyMenu;
      'V': ViewChar.ViewCharMenu(ext);
      'T': Money.TakeMoneyMenu;
      'P': if not ext then Money.PoolMoney;
      'S': Money.ShareMoney;
      'A': Money.AppraiseMenu(apprOk);
      'E': begin
             Money.DetermineTreasure(hasMoney, hasItems);
             if hasMoney then begin
               menu := '~Yes ~No';
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT,
                 C_Msg.TEXT_BOTTOM, LightGreen, True,
'As you leave the shopkeeper says, "Excuse me but you have left some money here."  ');
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT,
                                             C_Msg.TEXT_BOTTOM, White, False,
                                             'Do you want to go back and get your money?');
               ynIdx := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen, White,
                                                              False, False);
               if ynIdx = 1 then
                 done := True
               else
                 TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
             end else
               done := True;
           end;
      'G': ViewChar.SelectPrevNextChar(c);
      'O': ViewChar.SelectPrevNextChar(c);
    end;
    case c of
      'B', 'T': CharHlp.DisplayNoncombatInterface;
      'A': if apprOk then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until done;
end;

begin
end.
