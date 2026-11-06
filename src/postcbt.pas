{ Resolve combat results, distribute experience and treasure, show the loot menus and clean up creatures. }
{$O+,F+}
unit PostCbt;

interface

uses Types, Crt, C_Npc, C_Msg, GDConsts, GDVars, TextRend, Border, CharHlp, MenuCore, Shop, EclMenu,
  CharGen, ViewChar, Money, Magic, FxEngine, C_Class, C_Keys, C_Status, C_Ifc, C_Gbvm, C_Money;

{ Wraps up a battle: settles the outcome and frees the combat state. When the party survived, or in a duel, the NPCs
  take their shares, the summary shows, the loot menu runs and the treasure items left are freed; on defeat the combat
  result becomes $80 and the game-over screen shows. Then the one-battle GBVM settings are cleared: the THAC0
  adjustments, the party movement adjustment, the no-items flag and the mirror duel. }
procedure PostCombat;

implementation

const
  { AwardExperience: prime stat > 15 earns a 10% bonus }
  PRIME_STAT_THRESHOLD = 15;

  { Class value (TCharRecord.charClass) }
  CLASS_THIEF = 6;

  { Script-visible game-memory addresses }
  { 0 won, 128 lost, 129 fled }
  GBVM_COMBAT_RESULT = $6DC7;
  { # monsters defeated last combat }
  GBVM_MONSTERS_DEFEATED = $6DC8;
  { 1 => next combat drops no items }
  GBVM_NO_COMBAT_ITEMS = $6DE3;

{ Collects the coins, experience and items of the hostile creatures that did not run away. An item is taken when its
  value is above 0, or on a 3-in-10 roll while fewer than 8 items have been taken; no item is taken when the GBVM
  no-items flag is 1. Coins add experience (copper div 200, silver div 20, electrum div 2, gold x1, platinum x5, gems
  x250, jewelry x2200), as does 400 per plus of each taken item before lastMissileItem. The total is shared among the
  party size less nonAnimCount. A mirror duel instead awards 100 experience per level of the current character.
  @param(share Receives each character's share of the experience.) }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCharRecord;
  i: ShortInt;
  expTotal: LongInt;
  q: Types.PItemRec;
  item: Types.PItemRec;
  cnt: Byte;
begin
  if GDVars.duelFlag and (GDVars.zone1^[C_Gbvm.MIRROR_DUEL] <> 0) then
    share := GDVars.curChar^.levelHighest * 100
  else begin
    expTotal := 0;
    p := GDVars.creatureList;
    cnt := 0;
    while p <> nil do begin
      item := p^.itemsAddr;
      if (p^.hostile = 1) and (p^.status <> C_Status.RUNNING) then begin
        GDVars.nonEscapedHostileFound := True;
        for i := C_Money.COPPER to C_Money.JEWELRY do
          Inc(GDVars.treasureMoney[i], p^.coins[i]);
        expTotal := expTotal + p^.xpAward + p^.xpBonusPerHp * p^.hpRolled;
        if GDVars.zone1^[PostCbt.GBVM_NO_COMBAT_ITEMS] <> 1 then
          while item <> nil do begin
            if (item^.value > 0) or ((cnt < 8) and (FxEngine.RollDice(1, 10) <= 3)) then begin
              Inc(cnt);
              if GDVars.treasureItems = nil then begin
                GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
                CharHlp.PrintItemString(p, item, 0, 0, False, False);
                GDVars.treasureItems^ := item^;
                GDVars.treasureItems^.equipped := 0;
                GDVars.treasureItems^.next := nil;
              end else begin
                q := GDVars.treasureItems;
                GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
                CharHlp.PrintItemString(p, item, 0, 0, False, False);
                GDVars.treasureItems^ := item^;
                GDVars.treasureItems^.equipped := 0;
                GDVars.treasureItems^.next := q;
              end;
            end;
            item := item^.next;
          end;
      end;
      p := p^.nextCharAddr;
    end;
    Inc(expTotal, GDVars.treasureMoney[C_Money.COPPER] div 200);
    Inc(expTotal, GDVars.treasureMoney[C_Money.SILVER] div 20);
    Inc(expTotal, GDVars.treasureMoney[C_Money.ELECTRUM] div 2);
    Inc(expTotal, GDVars.treasureMoney[C_Money.GOLD]);
    Inc(expTotal, GDVars.treasureMoney[C_Money.PLATINUM] * 5);
    Inc(expTotal, GDVars.treasureMoney[C_Money.GEMS] * 250);
    Inc(expTotal, GDVars.treasureMoney[C_Money.JEWELRY] * 2200);
    q := GDVars.treasureItems;
    while (q <> nil) and (q <> GDVars.lastMissileItem) do begin
      if q^.plus > 0 then
        Inc(expTotal, q^.plus * 400);
      q := q^.next;
    end;
    share := expTotal div (GDVars.zone1^[C_Gbvm.PARTY_SIZE] - GDVars.nonAnimCount);
  end;
end;

{ Gives experience to each enabled creature in the list that is not animated. A single-class cleric, fighter, magic-user
  or thief whose prime ability (Wisdom, Strength, Intelligence or Dexterity) is above 15 gets 10 percent more; a
  two-class character gets half and a three-class character a third.
  @param(experience The experience each character receives.) }
procedure AwardExperience(experience: LongInt);
var
  p: Types.PCharRecord;
  share: LongInt;
begin
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.enabled <> 0) and (p^.status <> C_Status.ANIMATED) then begin
      share := experience;
      case p^.charClass of
        C_Class.CLERIC: if p^.wisCur > PostCbt.PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
        C_Class.FIGHTER: if p^.strCur > PostCbt.PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
        C_Class.MAGE: if p^.intCur > PostCbt.PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
        PostCbt.CLASS_THIEF: if p^.dexCur > PostCbt.PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
        C_Class.CLERIC_FIGHTER, C_Class.CLERIC_RANGER..C_Class.FIGHTER_THIEF,
          { 2-class multi }
          C_Class.MAGE_THIEF: share := experience div 2;
        C_Class.CLERIC_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF:
          { 3-class multi }
          share := experience div 3;
      end;
      Inc(p^.experience, share);
    end;
    p := p^.nextCharAddr;
  end;
end;

{ Classifies the battle's outcome. Outside a duel the party (the creatures before the first with notPcNpc 1) is defeated
  unless a member that is neither hostile nor an NPC is running, animated or okay, or any such member while MIRROR_DUEL
  is 1. An animated or okay member wins the battle and experience is awarded; otherwise a running member means the party
  fled. When it did not flee, running members return okay, dying ones become unconscious and unconscious ones with hit
  points recover. When it fled, the combat result becomes $81, running members return and each other member is removed.
  On defeat each party member is removed and the party size becomes 0. In a duel the party is never defeated: each
  enabled, okay creature that is not hostile wins the battle and awards experience, okay and animated creatures are
  enabled again and dying ones become unconscious. }
procedure DetermineCombatResults;
var
  p: Types.PCharRecord;
  b: Boolean;
begin
  GDVars.nonAnimCount := 0;
  GDVars.partyDefeated := True;
  GDVars.partyFled := False;
  p := GDVars.creatureList;
  while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
    if p^.status = C_Status.RUNNING then
      GDVars.partyFled := True;
    p := p^.nextCharAddr;
  end;
  if GDVars.duelFlag then
    GDVars.partyDefeated := False;
  GDVars.combatWon := False;
  p := GDVars.creatureList;
  if not GDVars.duelFlag then begin
    while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
      { NON_PLAYER clear }
      if ((p^.status = C_Status.RUNNING) or (p^.status = C_Status.ANIMATED) or
          (p^.status = C_Status.OKAY) or
          (GDVars.zone1^[C_Gbvm.MIRROR_DUEL] = 1)) and (p^.hostile = 0) and (p^.npc < C_Npc.NON_PLAYER) then
        GDVars.partyDefeated := False;
      if (p^.status = C_Status.ANIMATED) or (p^.status = C_Status.OKAY) then begin
        GDVars.combatWon := True;
        GDVars.partyFled := False;
      end;
      if (p^.enabled = 0) or (p^.status = C_Status.ANIMATED) then
        Inc(GDVars.nonAnimCount);
      p := p^.nextCharAddr;
    end;
    if GDVars.combatWon then begin
      PostCbt.DetermineLootExp(GDVars.expShare);
      PostCbt.AwardExperience(GDVars.expShare);
    end;
    p := GDVars.creatureList;
    if not GDVars.partyDefeated then begin
      while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
        if not GDVars.partyFled then begin
          case Char(p^.status) of
            Char(C_Status.RUNNING): begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
               end;
            Char(C_Status.DYING): p^.status := C_Status.UNCONSCIOUS;
            Char(C_Status.UNCONSCIOUS): if p^.hpCur > 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
               end;
          end;
        end else begin
          GDVars.zone1^[PostCbt.GBVM_COMBAT_RESULT] := $81;
          if p^.status = C_Status.RUNNING then begin
            p^.status := C_Status.OKAY;
            p^.enabled := 1;
          end else begin
            GDVars.curChar := p;
            CharGen.RemoveCreature(False, True);
          end;
        end;
        p := p^.nextCharAddr;
      end;
    end else begin
      p := GDVars.creatureList;
      b := False;
      while (p <> nil) and not b do begin
        if p^.combatAddr^.notPcNpc <> 1 then begin
          GDVars.curChar := p;
          CharGen.RemoveCreature(False, True);
        end else
          b := True;
        p := p^.nextCharAddr;
      end;
      GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
    end;
  end else begin
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.enabled = 1) and (p^.status = C_Status.OKAY) and (p^.hostile <> 1) then begin
        GDVars.combatWon := True;
        PostCbt.DetermineLootExp(GDVars.expShare);
        PostCbt.AwardExperience(GDVars.expShare);
      end;
      p := p^.nextCharAddr;
    end;
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.status = C_Status.OKAY) or (p^.status = C_Status.ANIMATED) then
        p^.enabled := 1;
      if p^.status = C_Status.DYING then
        p^.status := C_Status.UNCONSCIOUS;
      p := p^.nextCharAddr;
    end;
  end;
end;

{ Shows the battle's outcome and the experience each character, or the duelist, received, and waits for Enter.
  @param(experience The experience shown; 0 is shown when the party fled or lost a duel.) }
procedure PostCombatSummary(experience: LongInt);
var
  numStr: String[10];
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
  query: String[1];
  ext: Boolean;
begin
  query[0] := #0;
  Border.DrawWindow(1, 1, 38, 22, 0, White, '');
  if GDVars.nonEscapedHostileFound or GDVars.duelFlag then begin
    if GDVars.duelFlag and not GDVars.combatWon then begin
      TextRend.DisplayString(1, 3, LightGreen, 'You have lost the duel.');
      experience := 0;
    end else if GDVars.duelFlag then
      TextRend.DisplayString(1, 3, LightGreen, 'You have won the duel.')
    else
      TextRend.DisplayString(1, 3, LightGreen, 'The party has won.');
  end else begin
    if GDVars.partyFled then begin
      TextRend.DisplayString(1, 3, LightGreen, 'The party has fled.');
      experience := 0;
    end else
      TextRend.DisplayString(1, 3, LightGreen, 'The party has found Treasure!');
  end;
  Str(experience, numStr);
  if GDVars.duelFlag then
    msg := 'The duelist receives ' + numStr
  else
    msg := 'Each character receives ' + numStr;
  TextRend.DisplayString(1, 5, LightGreen, msg);
  TextRend.DisplayString(1, 7, LightGreen, 'experience points.');
  c := MenuCore.MenuHorizontal(query, 'press <enter>/<return> to continue', White, White, White,
                               True, False, ext);
end;

{ Draws the Loot window, rebuilding each item's display name, and runs the Items/Take menu over the treasure items.
  @param(c Receives the menu key.)
  @param(itemToTake Receives the highlighted item.)
  @param(cursor The highlighted item, kept from one call to the next.)
  @param(idx The menu position, kept from one call to the next.) }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);
var
  head: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  tmp: String[16];
  { Unused in this version; see the other implementations of this routine. }
  lenv: Byte;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { seeded True so MenuVertical paints the list; MenuVertical clears it }
  redraw: Boolean;
  p: Types.PItemRec;
begin
  redraw := True;
  Border.DrawWindow(1, 1, 38, 22, 0, White, 'Loot');
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
  head := GDVars.treasureItems;
  c := MenuCore.MenuVertical('Items: ', 'Take', LightMagenta, LightGreen, White, 1, 4, 38, 22,
                             head, True, redraw, idx, cursor);
  itemToTake := cursor;
end;

{ Runs the item-taking menu: each item taken goes to the current character as a copy, and the treasure item is freed. It
  ends on any key other than Take or Enter, or when no treasure items are left. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItemRec;
  p: Types.PItemRec;
  c: Char;
  done: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
  failed: Boolean;
begin
  itemToTake := nil;
  cursor := GDVars.treasureItems;
  idx := 0;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if (c <> 'T') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      if not failed then begin
        p := GDVars.treasureItems;
        if p = itemToTake then
          GDVars.treasureItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        if itemToTake <> nil then
          FreeMem(itemToTake, SizeOf(Types.TItemRec));
        if GDVars.treasureItems = nil then
          done := True;
      end;
    end;
  until done;
  CharHlp.DisplayNoncombatInterface;
end;

{ Runs the Take menu. With both money and items left it loops on Money, Items and Exit until one kind runs out; with
  only one kind left it goes straight to that menu.
  @param(treasure True when money is left; kept up to date.)
  @param(items True when items are left; kept up to date.) }
procedure LootTakeMenu(var treasure, items: Boolean);
var
  c: Char;
  done: Boolean;
  ext: Boolean;
begin
  done := False;
  if treasure then begin
    if items then begin
      repeat
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', LightMagenta, LightGreen, White,
                                     True, True, ext);
        case c of
          'M': begin
                 Money.TakeMoneyMenu;
                 CharHlp.DisplayNoncombatInterface;
               end;
          'I': PostCbt.LootTakeItemMenu;
          'E', C_Keys.NONE: done := True;
          'G': ViewChar.SelectPrevNextChar(c);
          'O': ViewChar.SelectPrevNextChar(c);
        end;
        CharHlp.DisplayParty(GDVars.curChar);
        Money.DetermineTreasure(treasure, items);
        if not treasure or not items then
          done := True;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ Runs the loot menu: View, Take, Pool and Share with money left; View, Take and Pool with only items left; View, Pool
  and Exit with nothing left. Detect is offered while items are left and the current character has Detect Magic
  memorized (spell 5 or 11). Leaving with treasure left asks for confirmation. }
procedure LootMenu;
var
  treasure: Boolean;
  items: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  canDetect: Boolean;
  menu: String;
  c: Char;
  done: Boolean;
  ext: Boolean;
  query: String[1];
  ynIdx: Byte;
  i: Byte;
  detectSpell: Byte;
  hasDetect: Boolean;
  tail: String[13];
begin
  query[0] := #0;
  done := False;
  CharHlp.DisplayNoncombatInterface;
  treasure := False;
  repeat
    Money.DetermineTreasure(treasure, items);
    menu := 'View Pool Exit';
    i := 0;
    tail := ' Exit';
    hasDetect := False;
    if items then
      { the last index of memorizedSpells }
      while (i <= 20) and not hasDetect do begin
        if (GDVars.curChar^.memorizedSpells[i] = 5) or (GDVars.curChar^.memorizedSpells[i] = 11) then begin
          hasDetect := True;
          detectSpell := GDVars.curChar^.memorizedSpells[i];
        end;
        Inc(i);
      end;
    if hasDetect then
      tail := ' Detect Exit';
    if treasure then
      menu := 'View Take Pool Share' + tail
    else if items then
      menu := 'View Take Pool' + tail;
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, True, ext);
    case c of
      'V': ViewChar.ViewCharMenu(ext);
      'T': PostCbt.LootTakeMenu(treasure, items);
      'P': if not ext then Money.PoolMoney;
      'S': Money.ShareMoney;
      'D': Magic.CastSpell(detectSpell, False, False, ext);
      'E', C_Keys.NONE: begin
                 Money.DetermineTreasure(treasure, items);
                 if treasure or items then begin
                   menu := '~Yes ~No';
                   TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT,
                                                 C_Msg.TEXT_BOTTOM, LightGreen, True,
                                                 'There is still treasure left.  ');
                   TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT,
                                                 C_Msg.TEXT_BOTTOM, White, False,
                                                 'Do you want to go back and claim your treasure?');
                   ynIdx := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen, White,
                                                                  False, False);
                   { 0-based: 1 = No leaves, anything else returns to the loot menu }
                   if ynIdx = 1 then
                     done := True
                   else
                     TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
                 end else
                   done := True;
               end;
      'G': begin
             ViewChar.SelectPrevNextChar(c);
             CharHlp.DisplayParty(GDVars.curChar);
           end;
      'O': begin
             ViewChar.SelectPrevNextChar(c);
             CharHlp.DisplayParty(GDVars.curChar);
           end;
    end;
  until done;
end;

{ Removes the monsters and hostile creatures from the list, counting the ones that were not enabled in the GBVM
  monsters-defeated count, and frees the combat records of the others. The current character is left at the head of the
  list. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
begin
  GDVars.zone1^[PostCbt.GBVM_MONSTERS_DEFEATED] := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpc = 1) or (p^.hostile = 1) then begin
      if p^.enabled <> 1 then
        Inc(GDVars.zone1^[PostCbt.GBVM_MONSTERS_DEFEATED]);
      next := p^.nextCharAddr;
      GDVars.curChar := p;
      CharGen.RemoveCreature(p^.combatAddr^.notPcNpc = 1, True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil;
      end;
      p := p^.nextCharAddr;
    end;
  end;
  GDVars.curChar := GDVars.creatureList;
end;

{ Lets the NPCs take their shares of the coins. Each okay NPC claims its share count (npcTreasureShare and 7), and each
  other creature one share. Each coin type above 0 is cut into that many shares and the NPCs' shares are taken away;
  when any coin was taken, the NPCs with a share are listed as taking it. Note: a share is computed in a Byte, so a
  large pile loses all but the low byte of each share. }
procedure NpcTreasureShare;
var
  p: Types.PCharRecord;
  npcShares: Byte;
  total: Byte;
  cut: Byte;
  row: Byte;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  tmp: String[8];
  took: Boolean;
  ext: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  took := False;
  p := GDVars.creatureList;
  npcShares := 0;
  total := 0;
  while p <> nil do begin
    { NON_PLAYER set }
    if (p^.npc > $7F) and (p^.status = C_Status.OKAY) then begin
      Inc(npcShares, p^.npcTreasureShare and 7);
      Inc(total, p^.npcTreasureShare and 7);
    end else
      Inc(total);
    p := p^.nextCharAddr;
  end;
  if npcShares > 0 then
    for i := C_Money.COPPER to C_Money.JEWELRY do
      if GDVars.treasureMoney[i] > 0 then begin
        cut := GDVars.treasureMoney[i] div total;
        Dec(GDVars.treasureMoney[i], npcShares * cut);
        took := True;
      end;
  if took then begin
    Border.DrawWindow(1, 1, 38, 22, 0, White, '');
    p := GDVars.creatureList;
    row := 0;
    while p <> nil do begin
      { NON_PLAYER set }
      if (p^.npc > $7F) and (p^.status = C_Status.OKAY) and (p^.npcTreasureShare > 0) then begin
        TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, True,
                                      p^.name + ' takes and hides his share.');
        Inc(row, 2);
      end;
      p := p^.nextCharAddr;
    end;
    c := MenuCore.MenuHorizontal('', 'press <enter>/<return> to continue', White, White, White,
                                 True, False, ext);
  end;
end;

procedure PostCombat;
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  GDVars.zone1^[PostCbt.GBVM_COMBAT_RESULT] := 0;
  GDVars.nonEscapedHostileFound := False;
  GDVars.ifcState := C_Ifc.LOOT;
  PostCbt.DetermineCombatResults;
  PostCbt.PostCombatCreatureCleanup;
  if not GDVars.partyDefeated or GDVars.duelFlag then begin
    PostCbt.NpcTreasureShare;
    PostCbt.PostCombatSummary(GDVars.expShare);
    PostCbt.LootMenu;
    p := GDVars.treasureItems;
    while p <> nil do begin
      q := p;
      p := p^.next;
      FreeMem(q, SizeOf(Types.TItemRec));
    end;
    GDVars.treasureItems := nil;
  end else begin
    GDVars.zone1^[PostCbt.GBVM_COMBAT_RESULT] := $80;
    Border.DrawWindow(1, 1, 38, 22, 0, White, 'The END!');
    GDVars.curCol := 2;
    GDVars.curRow := 6;
    TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, True,
                                  'The monsters rejoice for the party has been destroyed');
    TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
  end;
  GDVars.msgDelayFlag := 1;
  GDVars.zone1^[C_Gbvm.MONSTER_THAC0_MODIFIER] := 0;
  GDVars.zone1^[C_Gbvm.PARTY_THAC0_MODIFIER] := 0;
  GDVars.zone1^[C_Gbvm.PARTY_MOVE_MODIFIER] := 0;
  GDVars.zone1^[PostCbt.GBVM_NO_COMBAT_ITEMS] := 0;
  GDVars.zone1^[C_Gbvm.MIRROR_DUEL] := 0;
end;

begin
end.
