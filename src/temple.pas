{ Temple services: healing, revival, curse removal and payment. }
{$O+,F+}
unit Temple;

interface

uses Types, Crt, C_Msg, GDConsts, GDVars, TextRend, Border, CharHlp, MenuCore, EclMenu, ViewChar, Money, Magic,
  FxEngine, C_Effect, C_Keys, C_Class, C_Status, C_Ifc;

{ Runs the temple: heal, view, take, pool, share and appraise, with Take and Share offered only while there is pooled
  money. The pooled money starts empty. H and P are told apart from the extended Up and Down keys; Home and End select
  the previous or next character. Leaving with money still in the pool asks whether to go back for it. }
procedure TempleMainMenu;

implementation

{ Tells the player why the current character needs no cure and asks whether to cast it anyway.
  @param(msg The reason, printed after the character's name.)
  @returns(Y or N.) }
function ConfirmCureAnyway(msg: String): Char;
begin
  CharHlp.PrintCreatureMessage(GDVars.curChar, msg, 0, False);
  ConfirmCureAnyway := MenuCore.YesNoMenu('cast cure anyway: ', LightMagenta, LightGreen, White);
  CharHlp.ClearMessageWindow;
end;

{ Shows a cure's price and asks whether to pay. The price is paid from the current character's coins when they cover it,
  and otherwise from the pooled money; when neither covers it, the cure is refused. A paid cure prints that the
  character is cured.
  @param(spell The cure's name.)
  @param(cost The price in gold pieces.)
  @returns(Y when the cure was paid for, N otherwise.) }
function ConfirmCureCost(spell: String; cost: Word): Char;
var
  c: Char;
  charGold: Word;
  pooled: LongInt;
begin
  spell := spell + ' will only cost ' + CharHlp.WordToString(cost) + ' gold pieces.';
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                True, spell);
  c := MenuCore.YesNoMenu('pay for cure ', LightMagenta, White, LightGreen);
  if c = 'Y' then begin
    charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
    if cost <= charGold then begin
      Dec(charGold, cost);
      Money.SetCreatureCoinsInGold(charGold);
    end else begin
      pooled := Money.CoinValueInGold(GDVars.treasureMoney);
      if cost <= pooled then begin
        Dec(pooled, cost);
        Money.SetTreasureCoinsInGold(pooled);
      end else begin
        CharHlp.PrintBottomLine('Not enough money.');
        c := 'N';
      end;
    end;
  end;
  if c = 'Y' then begin
    CharHlp.ClearMessageWindow;
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'is cured.', 0, True);
  end;
  ConfirmCureCost := c;
end;

{ Cures the current character's blindness for 1000 gold pieces, asking first when it is not blind. }
procedure CureBlindness;
var
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BLIND, effect) then
    c := Temple.ConfirmCureAnyway('is not blind.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Blindness', 1000);
    if c = 'Y' then
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
  end;
end;

{ Cures the current character's diseases for 1000 gold pieces, asking first when it has none of the six disease effects.
  All six are removed under the effect lock. }
procedure CureDisease;
var
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  i: Byte;
  found: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  { 6 is the last index of cureDiseaseEffects }
  for i := 1 to 6 do
    if CharHlp.HasEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], effect) then
      found := True;
  if not found then
    c := Temple.ConfirmCureAnyway('is not Diseased.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Disease', 1000);
    if c = 'Y' then begin
      GDVars.effectLock := 1;
      { 6 is the last index of cureDiseaseEffects }
      for i := 1 to 6 do
        FxEngine.RemoveEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], nil);
      GDVars.effectLock := 0;
    end;
  end;
end;

{ Heals the current character's wounds for a price.
  @param(spell 1 for Cure Light Wounds, 1d8 for 100 gold pieces; 2 for Cure Serious Wounds, 2d8+1 for 350; 3 for Cure
    Critical Wounds, 3d8+3 for 600.) }
procedure CureWounds(spell: Byte);
var
  hp: Byte;
  c: Char;
  { Unused in this version; see the other implementations of this routine. }
  restored: Boolean;
begin
  case spell of
    1: begin
         c := Temple.ConfirmCureCost('Cure Light Wounds', 100);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(1, 8);
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    2: begin
         c := Temple.ConfirmCureCost('Cure Serious Wounds', 350);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(2, 8) + 1;
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    3: begin
         c := Temple.ConfirmCureCost('Cure Critical Wounds', 600);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(3, 8) + 3;
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
  end;
end;

{ Raises the current character for 5500 gold pieces, asking first when it is not dead or animated; paying for a living
  character changes nothing. A dead or animated character loses its animation and poison effects, comes back with one
  hit point, okay and enabled, and loses a point of Constitution unless it has none. The hit points it gained above its
  rolled hit points are the loss; while its Constitution is still 14 or more, the loss is divided by its Constitution
  bonus summed over its class levels (when that sum is not 0) and taken off its maximum hit points when its Constitution
  is below 17 or it has fighter levels. }
procedure RaiseDead;
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  wasDead: Boolean;
  hpLoss: Byte;
  hpBonus: Byte;
  i: ShortInt;
  creature: Types.PCharRecord;
begin
  creature := GDVars.curChar;
  wasDead := False;
  s := '';
  c := 'Y';
  if (creature^.status = C_Status.DEAD_STATUS) or (creature^.status = C_Status.ANIMATED) then
    wasDead := True;
  if not wasDead then
    c := Temple.ConfirmCureAnyway('is not dead.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Raise Dead', 5500);
    if c = 'Y' then begin
      if wasDead then begin
        GDVars.effectLock := 1;
        FxEngine.RemoveEffect(creature, C_Effect.ANIMATE_DEAD, nil);
        FxEngine.RemoveEffect(creature, C_Effect.POISONED, nil);
        GDVars.effectLock := 0;
        creature^.hpCur := 1;
        creature^.status := C_Status.OKAY;
        creature^.enabled := 1;
        if creature^.conCur > 0 then
          Dec(creature^.conCur);
        if creature^.hpMax > creature^.hpRolled then
          hpLoss := creature^.hpMax - creature^.hpRolled
        else
          hpLoss := 0;
        hpBonus := 0;
        if creature^.conCur >= 14 then begin
          { 7 is the last index of classLevels }
          for i := 0 to 7 do
            if creature^.classLevels[i] > 0 then begin
              if i = C_Class.FIGHTER_LEVEL then
                Inc(hpBonus, (creature^.conCur - 14) * creature^.classLevels[i])
              else if creature^.conCur > 15 then
                Inc(hpBonus, creature^.classLevels[i] * 2)
              else
                Inc(hpBonus, creature^.classLevels[i]);
            end;
          if hpBonus > 0 then
            hpLoss := hpLoss div hpBonus;
          if (creature^.conCur < 17) or (creature^.classLevels[C_Class.FIGHTER_LEVEL] > 0) then
            Dec(creature^.hpMax, hpLoss);
        end;
      end;
    end;
  end;
end;

{ Neutralizes poison in the current character for 1000 gold pieces, asking first when it is not poisoned. The poison and
  both slow-poison effects are removed under the effect lock. }
procedure NeutralizePoison;
var
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  found: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.POISONED, effect) then
    found := True;
  if not found then
    c := Temple.ConfirmCureAnyway('is not poisoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Neutralize Poison', 1000);
    if c = 'Y' then begin
      GDVars.effectLock := 1;
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISONED, nil);
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_END, nil);
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_HIT, nil);
      GDVars.effectLock := 0;
    end;
  end;
end;

{ Removes curses from the current character for 3500 gold pieces through the Remove Curse spell, asking first when it
  carries no cursed item and is not cursed. }
procedure RemoveCurse;
var
  cursed: Boolean;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  cursed := False;
  item := GDVars.curChar^.itemsAddr;
  while (item <> nil) and (not cursed) do begin
    if item^.cursed <> 0 then
      cursed := True;
    item := item^.next;
  end;
  if not cursed then
    if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BESTOW_CURSE, effect) then
      c := Temple.ConfirmCureAnyway('is not cursed.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Remove Curse', 3500);
    if c = 'Y' then begin
      GDVars.spellTargets[1] := GDVars.curChar;
      Magic.SpellRemoveCurse;
    end;
  end;
end;

{ Turns the current character from stone to flesh for 2000 gold pieces, asking first when it is not stoned. A stoned
  character comes back okay and enabled, with one hit point. }
procedure StoneToFlesh;
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  if GDVars.curChar^.status <> C_Status.STONED then
    c := Temple.ConfirmCureAnyway('is not stoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Stone to Flesh', 2000);
    if c = 'Y' then
      if GDVars.curChar^.status = C_Status.STONED then begin
        GDVars.curChar^.status := C_Status.OKAY;
        GDVars.curChar^.enabled := 1;
        GDVars.curChar^.hpCur := 1;
      end;
  end;
end;

{ Runs the healing menu over the temple's list of cures until Exit or Escape, then redraws the interface. }
procedure HealMenu;
var
  list: Types.PItemRec;
  sel: Types.PItemRec;
  { Seeded True; MenuVertical draws the page and clears it. }
  redraw: Boolean;
  i: Byte;
  idx: Integer;
  done: Boolean;
  s: String[40];
  c: Char;
begin
  done := False;
  list := nil;
  sel := nil;
  MenuCore.AllocStringList(10, list);
  sel := list;
  i := 1;
  while list <> nil do begin
    list^.name := GDConsts.templeSpells[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := sel;
  TextRend.ClearRect(0, 24, 39, 24);
  redraw := True;
  Border.DrawWindow(1, 1, 38, 22, 0, White, '');
  { the top divider row }
  Border.DrawWindow(1, 1, 38, 1, 0, White, '');
  repeat
    s := GDVars.curChar^.name + ', how can we help you?';
    TextRend.DisplayString(1, 1, White, s);
    Border.DrawWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0, White, '');
    c := MenuCore.MenuVertical('', 'Heal Exit', LightMagenta, LightGreen, White, 2, 4, 38, 15, list, False, redraw, idx,
                               sel);
    case c of
      'H', C_Keys.ENTER:
        case idx of
          0: Temple.CureBlindness;
          1: Temple.CureDisease;
          2: Temple.CureWounds(1);
          3: Temple.CureWounds(2);
          4: Temple.CureWounds(3);
          5: Temple.NeutralizePoison;
          6: Temple.RaiseDead;
          7: Temple.RemoveCurse;
          8: Temple.StoneToFlesh;
          9: done := True;
        end;
      C_Keys.NONE: done := True;
    end;
  until done;
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(0, 0, 39, 24);
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
end;

procedure TempleMainMenu;
var
  c: Char;
  done: Boolean;
  ext: Boolean;
  menu: String[40];
  hasMoney: Boolean;
  hasItems: Boolean;
  ynIdx: Byte;
  apprOk: Boolean;
begin
  GDVars.ifcState := C_Ifc.SHOP_TEMPLE;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(GDVars.treasureMoney, SizeOf(Types.TMoney), 0);
  GDVars.treasureMoneyFlag := False;
  done := False;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := 'Heal View Take Pool Share Appraise Exit'
    else
      menu := 'Heal View Pool Appraise Exit';
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    case c of
      'H': if not ext then Temple.HealMenu;
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
'As you leave a priest says, "Excuse me but you have left some money here" ');
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                             LightGreen, True,
                                             'Do you want to go back and retrieve your money?');
               ynIdx := EclMenu.MenuHorizontalCharacterSelect('', menu, LightMagenta, LightGreen, White, False, False);
               if ynIdx = 1 then
                 done := True
               else
                 TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
             end else
               done := True;
           end;
      C_Keys.HOME: ViewChar.SelectPrevNextChar(c);
      C_Keys.END_KEY: ViewChar.SelectPrevNextChar(c);
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
