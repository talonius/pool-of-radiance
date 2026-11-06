{ Camp menus for spell preparation, resting, party order and game settings. Also provides the noncombat Cast menu. }

{$O+,F+}
unit Camp;

interface

uses Types, Crt, C_Msg, GDConsts, GDVars, GameIo, TextRend, Border, CharHlp, MenuCore, CharGen, SaveLoad,
  ViewChar, GameTime, Magic, C_Effect, C_Keys, C_Status, C_Ifc, C_Spell;

{ Runs the camp menu: Save (then offers to quit to DOS), View, Magic, Rest and Alter; extended keys select the previous
  or next character. Pending spell preparation is cleared on the way in and out, the interface state is kept, and the
  rest time and healing count start at zero.
  @param(interrupted Receives True when a rest was interrupted.) }
procedure CampMainMenu(var interrupted: Boolean);

{ Runs the noncombat Cast menu over the current character's memorized spells until none is chosen, casting each spell
  chosen. The remembered target is cleared on the way in, and the interface is redrawn afterwards when a spell was cast
  or the list was not empty. }
procedure NoncombatCastMenu;

implementation

const
  { CanDoSpellActivity's activity selector: ACT_CAST, ACT_MEMORIZE or ACT_SCRIBE. }
  { cast a memorized spell }
  ACT_CAST = 1;
  { memorize spells from spellbook }
  ACT_MEMORIZE = 2;
  { scribe scrolls into spellbook }
  ACT_SCRIBE = 3;

{ Works out a character's spell preparation time: 15 minutes per level of each pending spell, plus four hours when any
  spell is pending, or six when any pending spell is level 3 or higher. Pending memorizing and pending scribing
  (readable items only) both count. Stores the base hours (0, 4 or 6) in the character's record.
  @param(creature The character.)
  @returns(The preparation time in minutes.) }
function CampSpellPrepTime(creature: Types.PCharRecord): Word;
var
  { highest pending level per kind }
  maxMem: Byte;
  maxScr: Byte;
  { SUM of pending spell levels }
  cntMem: Byte;
  cntScr: Byte;
  p: Types.PItemRec;
  i: Byte;
  lvl: Byte;
  base: Byte;
begin
  maxMem := 0;
  maxScr := 0;
  cntMem := 0;
  cntScr := 0;
  for i := 0 to SizeOf(creature^.memorizedSpells) - 1 do
    if creature^.memorizedSpells[i] > C_Spell.ID_MASK then begin
      lvl := GDConsts.spellTable[creature^.memorizedSpells[i] and C_Spell.ID_MASK].levelSp;
      if lvl > maxMem then maxMem := lvl;
      Inc(cntMem, lvl);
    end;
  p := creature^.itemsAddr;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        if p^.spells[i] > C_Spell.ID_MASK then begin
          lvl := GDConsts.spellTable[p^.spells[i] and C_Spell.ID_MASK].levelSp;
          if lvl > maxScr then maxScr := lvl;
          Inc(cntScr, lvl);
        end;
    p := p^.next;
  end;
  base := 0;
  if (cntMem > 0) or (cntScr > 0) then
    base := 4;
  if (maxMem > 2) or (maxScr > 2) then
    base := 6;
  creature^.spellPrepTime := base;
  CampSpellPrepTime := base * 60 + cntMem * 15 + cntScr * 15;
end;

{ Clears each memorized-spell slot pending memorizing, taking the spell out entirely, and the preparation delay.
  @param(creature The character.) }
procedure ResetMemorize(creature: Types.PCharRecord);
var
  i: Byte;
begin
  for i := 0 to SizeOf(creature^.memorizedSpells) - 1 do
    if creature^.memorizedSpells[i] > C_Spell.ID_MASK then
      creature^.memorizedSpells[i] := 0;
  creature^.spellPrepTime := 0;
end;

{ Clears the pending flag of every scroll spell on a character's readable items.
  @param(creature The character.) }
procedure ResetScribe(creature: Types.PCharRecord);
var
  i: Byte;
  p: Types.PItemRec;
begin
  p := creature^.itemsAddr;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        p^.spells[i] := p^.spells[i] and C_Spell.ID_MASK;
    p := p^.next;
  end;
end;

{ Clears the pending memorizing and scribing of each party member. }
procedure ResetPartySpellActivities;
var
  character: Types.PCharRecord;
begin
  character := GDVars.creatureList;
  while character <> nil do begin
    Camp.ResetMemorize(character);
    Camp.ResetScribe(character);
    character := character^.nextCharAddr;
  end;
end;

{ Counts the current character's free spell slots at a class and level: its allowance less the spells memorized or
  pending there. Note: the result is a Byte and wraps when more are memorized than allowed, as after a level drain.
  @param(spellLevel The spell level.)
  @param(spellClass The spell class.)
  @returns(The free slots.) }
function SpellSlotsRemaining(spellLevel, spellClass: ShortInt): Byte;
var
  count: Byte;
  i: Byte;
begin
  count := 0;
  for i := 0 to SizeOf(GDVars.curChar^.memorizedSpells) - 1 do
    if GDVars.curChar^.memorizedSpells[i] > 0 then
      if (GDConsts.spellTable[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].levelSp = spellLevel) and
          (GDConsts.spellTable[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].castClassSp =
           spellClass) then
        Inc(count);
  SpellSlotsRemaining := GDVars.curChar^.slots[spellClass, spellLevel] - count;
end;

{ Checks whether the current character can cast, memorize or scribe. The area's anti-magic flag blocks casting; animated
  or disabled characters can do none of them. On failure, prints the character's name and the reason.
  @param(activity The activity: cast, memorize or scribe.)
  @returns(True when the character can do it.) }
function CanDoSpellActivity(activity: Byte): Boolean;
var
  message: Types.TStr40;
begin
  message := '';
  if (activity = Camp.ACT_CAST) and (GDVars.zone0^.antimagic > 0) then
    message := 'cannot cast spells in this area'
  else if (GDVars.curChar^.status = C_Status.ANIMATED) or (GDVars.curChar^.enabled = 0) then begin
    message := 'is in no condition to ';
    case activity of
      Camp.ACT_CAST: message := message + 'cast any spells';
      Camp.ACT_MEMORIZE: message := message + 'memorize spells';
      Camp.ACT_SCRIBE: message := message + 'scribe any scrolls';
    end;
  end;
  if message = '' then
    CanDoSpellActivity := True
  else begin
    CanDoSpellActivity := False;
    CharHlp.PrintCreatureMessage(GDVars.curChar, message, 10, True);
  end;
end;

procedure NoncombatCastMenu;
var
  menuIndex: Integer;
  notEmpty: Boolean;
  needsRedraw: Boolean;
  { CastSpell's var out, unread }
  castSelected: Boolean;
  spellId: Byte;
begin
  needsRedraw := False;
  menuIndex := -1;
  GDVars.castTarget := nil;
  if Camp.CanDoSpellActivity(Camp.ACT_CAST) then begin
    repeat
      spellId := ViewChar.SpellMenu(0, 1, menuIndex, notEmpty);
      if spellId <> C_Spell.NO_SPELL then begin
        needsRedraw := True;
        Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
        Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
        Magic.CastSpell(spellId, False, True, castSelected);
        menuIndex := -1;
      end else begin
        if notEmpty then
          needsRedraw := True
        else
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no spells memorized', 10, True);
      end;
    until spellId = C_Spell.NO_SPELL;
  end;
  if needsRedraw then
    CharHlp.DisplayNoncombatInterface;
end;

{ Shows the current character's free spell slots by class and level. A level with no allowance is blank; a full level
  shows 0.
  @returns(True when the character has any spell allowance, even with each slot taken.) }
function DisplaySpellSlots: Boolean;
var
  s: Types.TStr40;
  slotStr: array[1..3, 0..1] of String[2];
  canDo: array[0..1] of Byte;
  typ: ShortInt;
  lvl: ShortInt;
  col: Byte;
  row: Byte;
  any: Boolean;
begin
  any := False;
  for typ := 0 to 1 do begin
    canDo[typ] := 0;
    for lvl := 1 to 3 do begin
      slotStr[lvl, typ] := CharHlp.ByteToString(Camp.SpellSlotsRemaining(lvl, typ));
      if GDVars.curChar^.slots[typ, lvl] = 0 then
        slotStr[lvl, typ] := ' '
      else begin
        canDo[typ] := 1;
        any := True;
      end;
    end;
  end;
  if any then begin
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'can memorize:', 10, False);
    row := 3;
    for typ := 0 to 1 do begin
      if canDo[typ] <> 0 then begin
        case Char(typ) of
          #0: s := '    Cleric Spells:';
          #1: s := 'Magic-User Spells:';
        end;
        TextRend.DisplayString(1, row + 17, LightGreen, s);
        col := 19;
        for lvl := 1 to 3 do begin
          TextRend.DisplayString(col + 1, row + 17, LightGreen, slotStr[lvl, typ]);
          Inc(col, 3);
        end;
        Inc(row);
      end;
    end;
  end;
  DisplaySpellSlots := any;
end;

{ Rests the party for the longest spell preparation time among its members, then clears the rest time and redraws the
  position and time.
  @param(interrupted Receives True when the rest was interrupted.) }
procedure RestForSpellPrep(var interrupted: Boolean);
var
  character: Types.PCharRecord;
  maxPrepMinutes: Word;
  prepMinutes: Word;
  { Unused in this version; see the other implementations of this routine. }
  hours: Word;
begin
  maxPrepMinutes := 0;
  character := GDVars.creatureList;
  while character <> nil do begin
    prepMinutes := Camp.CampSpellPrepTime(character);
    if maxPrepMinutes < prepMinutes then maxPrepMinutes := prepMinutes;
    character := character^.nextCharAddr;
  end;
  GDVars.restRemaining[3] := maxPrepMinutes div 60;
  GDVars.restRemaining[2] := (maxPrepMinutes - 60 * GDVars.restRemaining[3]) div 10;
  GDVars.restRemaining[1] := maxPrepMinutes mod 10;
  interrupted := GameTime.CampRest;
  FillChar(GDVars.restRemaining, SizeOf(GDVars.restRemaining), 0);
  CharHlp.PrintPositionAndTime;
end;

{ Sorts the current character's memorized-spell slots by spell ID, keeping each pending flag with its spell. Empty slots
  sort to the front. }
procedure SortMemorizedSpells;
var
  i: Byte;
  j: Byte;
  tmp: Byte;
begin
  for i := 0 to SizeOf(GDVars.curChar^.memorizedSpells) - 2 do
    for j := i to SizeOf(GDVars.curChar^.memorizedSpells) - 1 do
      if (GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) > (GDVars.curChar^.memorizedSpells[j] and
                                                                     C_Spell.ID_MASK) then begin
        tmp := GDVars.curChar^.memorizedSpells[i];
        GDVars.curChar^.memorizedSpells[i] := GDVars.curChar^.memorizedSpells[j];
        GDVars.curChar^.memorizedSpells[j] := tmp;
      end;
end;

{ Runs the Memorize menu. The spells already pending are shown first: Yes keeps them and skips the choosing, No clears
  them. Then spells are chosen from the spellbook and marked pending while slots remain, and when the spellbook was
  shown the pending spells are confirmed again. Note: a full memorized-spell list is searched past its end for an empty
  slot. }
procedure CampMemorizeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  i: Byte;
  idx: Integer;
begin
  if Camp.CanDoSpellActivity(Camp.ACT_MEMORIZE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Memorize These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetMemorize(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'cannot memorize any spells', 10, True)
      else begin
        spellId := ViewChar.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = C_Spell.NO_SPELL then
          done := True
        else if Camp.SpellSlotsRemaining(GDConsts.spellTable[spellId].levelSp,
                                         GDConsts.spellTable[spellId].castClassSp) > 0
        then begin
          { Sorting puts empty spell slots first, so the search stops at the first one. }
          i := 0;
          while GDVars.curChar^.memorizedSpells[i] <> 0 do
            Inc(i);
          GDVars.curChar^.memorizedSpells[i] := spellId + C_Spell.PENDING_FLAG;
          Camp.SortMemorizedSpells;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Memorize these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetMemorize(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Runs the Scribe menu. The spells already pending are shown first: Yes keeps them and skips the choosing, No clears
  them. Then scroll spells are chosen and marked pending, refusing a spell already known or pending or beyond the
  character's slots, and when the scrolls were shown the pending spells are confirmed again. Note: the marking does not
  check that the item is readable; it marks the first unmarked spell byte equal to the spell on any item. Note: the
  spell's class and level index the slot table unchecked, so a spell an item alone provides can read past it. }
procedure CampScribeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  i: Byte;
  idx: Integer;
  p: Types.PItemRec;
  found: Boolean;
begin
  if Camp.CanDoSpellActivity(Camp.ACT_SCRIBE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Scribe These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetScribe(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      spellId := ViewChar.SpellMenu(3, 3, idx, notEmpty);
      if spellId = C_Spell.NO_SPELL then begin
        done := True;
        if notEmpty = False then
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no copyable scrolls', 10, True)
        else
          redraw := True;
      end else begin
        redraw := True;
        if GDVars.curChar^.spellsKnown[spellId] <> 0 then
          CharHlp.PrintBottomLine('You already know that spell')
        else begin
          p := GDVars.curChar^.itemsAddr;
          found := False;
          while (p <> nil) and (found = False) do begin
            if Magic.ItemReadable(p) then
              for i := 1 to SizeOf(p^.spells) do
                if (p^.spells[i] > C_Spell.ID_MASK) and
                    (p^.spells[i] and C_Spell.ID_MASK = spellId) then begin
                  CharHlp.PrintBottomLine('You are already scibing that spell');
                  found := True;
                end;
            p := p^.next;
          end;
          if found = False then begin
            { Note: spell class and level are used as slot indices without validation. High-level or item-only spell IDs
              can read beyond the slot table into xpAward or iconHead. Unlike the spell-list scan, this path accepts IDs
              directly from scroll items. }
            if GDVars.curChar^.slots[GDConsts.spellTable[spellId].castClassSp,
                                       GDConsts.spellTable[spellId].levelSp] > 0
            then begin
              p := GDVars.curChar^.itemsAddr;
              while (p <> nil) and (found = False) do begin
                i := 1;
                repeat
                  if p^.spells[i] = spellId then begin
                    p^.spells[i] := p^.spells[i] or C_Spell.PENDING_FLAG;
                    found := True;
                  end;
                  Inc(i);
                until (i > SizeOf(p^.spells)) or found;
                p := p^.next;
              end;
            end else
              CharHlp.PrintBottomLine('You can not scribe that spell.');
          end;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Scribe these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetScribe(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Shows the party's spell effects in a list, a heading for each character. A spell effect shows the spell's name and
  other effects shown have fixed labels, with Funky and the number for an effect no named spell produces; other effects,
  the stinking-cloud cough among them, are hidden. }
procedure CampDisplayMenu;
var
  effect: Types.PEffectRec;
  listHead: Types.PItemRec;
  listTail: Types.PItemRec;
  character: Types.PCharRecord;
  effectId: Byte;
  spellIndex: Byte;
  { effects listed for this char }
  effectCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  isHeading: Byte;
  effectNameFound: Boolean;
  displayEffect: Boolean;
  viewNeedsRedraw: Boolean;
  effectName: Types.TStr40;
  menuIndex: Integer;
  { Unused in this version; see the other implementations of this routine. }
  choice: Char;

  { Appends an entry to the list, a heading when isTitle is set. }
  procedure AddToList(isTitle: Boolean; displayText: Types.TStr40);
  begin
    GetMem(listTail^.next, SizeOf(Types.TMenuNode));
    listTail := listTail^.next;
    listTail^.next := nil;
    listTail^.name := displayText;
    listTail^.inUse := Ord(isTitle);
  end;

begin
  GetMem(listHead, SizeOf(Types.TMenuNode));
  listTail := listHead;
  listTail^.inUse := 0;
  listTail^.name := ' ';
  listTail^.next := nil;
  character := GDVars.creatureList;
  while character <> nil do begin
    effectCount := 0;
    AddToList(True, character^.name);
    effect := character^.effectsAddr;
    while effect <> nil do begin
      displayEffect := True;
      effectId := effect^.id;
      case effectId of
        C_Effect.BLESS, C_Effect.CURSE, C_Effect.DETECT_MAGIC, C_Effect.PROTECTION_FROM_EVIL..C_Effect.FRIENDS,
            C_Effect.READ_MAGIC, C_Effect.SHIELD,
        C_Effect.FIND_TRAPS..C_Effect.INVISIBLE, C_Effect.MIRROR_IMAGE, C_Effect.ENFEEBLED,
            C_Effect.ANIMATE_DEAD..C_Effect.DISEASED,
        C_Effect.BESTOW_CURSE..C_Effect.HASTED, C_Effect.PROTECTION_FROM_MISSILES, C_Effect.SLOWED,
            C_Effect.PROTECTION_FROM_EVIL_RADIUS, C_Effect.PROTECTION_FROM_GOOD_RADIUS,
        C_Effect.PRAYER, C_Effect.SNAKE_CHARM..C_Effect.SLEEP:
          begin
            { Find the named spell that produces this effect. Only IDs 1..56 have spell names; higher IDs are item
              effects. }
            spellIndex := 1;
            effectNameFound := False;
            while (spellIndex <= 56) and (effectNameFound = False) do
              if GDConsts.spellTable[spellIndex].effect = effectId then begin
                effectName := GDConsts.spellNames[spellIndex];
                effectNameFound := True;
              end else
                Inc(spellIndex);
            if effectNameFound = False then
              effectName := 'Funky--' + CharHlp.ByteToString(effectId);
          end;
        C_Effect.TRAINING_START: effectName := 'Studying Manual of Bodily Health';
        C_Effect.TRAINING_MANUAL: effectName := 'Training with Manual of Bodily Health';
        C_Effect.FEATHER_FALL: effectName := 'Feather Fall';
        C_Effect.HELPLESS: effectName := 'Helpless';
        C_Effect.ALLIED_PRAYER: effectName := 'Prayer';
        C_Effect.DISEASE_HIT_POINTS: effectName := 'Cause Disease';
        C_Effect.ROT_NO_HEALING: effectName := 'Dreaded Mummy Disease';
        C_Effect.DRAGON_AURA: effectName := 'Repulsed';
        C_Effect.POISONED: effectName := 'Poisoned';
        C_Effect.TROLL_REGENERATION: effectName := 'Regenerating';
        C_Effect.RING_OF_FIRE_RESISTANCE: effectName := 'Fire Resistance';
        C_Effect.DUST_OF_DISAPPEARANCE: effectName := 'Invisible';
        C_Effect.CAMOUFLAGE: effectName := 'Camouflaged';
        C_Effect.DISPLACED: effectName := 'Displaced';
      else
        displayEffect := False;
      end;
      if displayEffect then begin
        Inc(effectCount);
        AddToList(False, ' ' + effectName);
      end;
      effect := effect^.next;
    end;
    if effectCount = 0 then
      AddToList(False, ' <No Spell Effects>');
    AddToList(False, ' ');
    character := character^.nextCharAddr;
  end;
  viewNeedsRedraw := True;
  menuIndex := 0;
  Border.DrawWindow(1, 1, 38, 22, 0, White, 'Display');
  choice := MenuCore.MenuVertical('', '', LightCyan, LightGreen, White, 1, 4, 38, 22, listHead, True,
                                  viewNeedsRedraw, menuIndex, listTail);
  MenuCore.FreeStringList(listHead);
  CharHlp.DisplayNoncombatInterface;
end;

{ Runs the Magic menu (cast, memorize, scribe, display, rest); extended keys change the current character. Ends on Exit,
  Escape or an interrupted rest.
  @param(interrupted Set True when a rest is interrupted; the menu ends at once when it is already True.) }
procedure CampMagicMenu(var interrupted: Boolean);
var
  c: Char;
  ext: Boolean;
begin
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    c := MenuCore.MenuHorizontal('', GDConsts.magicMenu, LightMagenta, LightGreen, White, True, True, ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case c of
        'C': Camp.NoncombatCastMenu;
        'M': Camp.CampMemorizeMenu;
        'S': Camp.CampScribeMenu;
        'D': Camp.CampDisplayMenu;
        'R': Camp.RestForSpellPrep(interrupted);
      end;
  end;
end;

{ Moves the current character one place earlier in the party; the first character moves to the end. }
procedure OrderMoveUp;
var
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  savedNext: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  prev := nil;
  if p = GDVars.curChar then begin
    while p^.nextCharAddr <> nil do
      p := p^.nextCharAddr;
  end else
    while p^.nextCharAddr <> GDVars.curChar do begin
      prev := p;
      p := p^.nextCharAddr;
    end;
  savedNext := GDVars.curChar^.nextCharAddr;
  if GDVars.creatureList = GDVars.curChar then begin
    { first -> last (p walked to the tail above) }
    if savedNext <> nil then
      GDVars.creatureList := savedNext;
    p^.nextCharAddr := GDVars.curChar;
    GDVars.curChar^.nextCharAddr := nil;
  end else begin
    { p = predecessor: unlink and reinsert one earlier }
    p^.nextCharAddr := savedNext;
    GDVars.curChar^.nextCharAddr := p;
    if (p = GDVars.creatureList) or (prev = nil) then
      GDVars.creatureList := GDVars.curChar
    else
      prev^.nextCharAddr := GDVars.curChar;
  end;
end;

{ Moves the current character one place later in the party; the last character moves to the front. }
procedure OrderMoveDown;
var
  predecessor: Types.PCharRecord;
  successor: Types.PCharRecord;
begin
  predecessor := GDVars.creatureList;
  if predecessor <> GDVars.curChar then
    while predecessor^.nextCharAddr <> GDVars.curChar do
      predecessor := predecessor^.nextCharAddr;
  successor := GDVars.curChar^.nextCharAddr;
  if successor = nil then begin
    GDVars.curChar^.nextCharAddr := GDVars.creatureList;
    GDVars.creatureList := GDVars.curChar;
    predecessor^.nextCharAddr := successor;
  end else begin
    GDVars.curChar^.nextCharAddr := successor^.nextCharAddr;
    if GDVars.creatureList = GDVars.curChar then
      GDVars.creatureList := successor;
    if predecessor <> GDVars.curChar then
      predecessor^.nextCharAddr := successor;
    successor^.nextCharAddr := GDVars.curChar;
  end;
end;

{ Reorders the party in two modes. In Select mode extended keys change the current character; in Place mode Home moves
  it up and End moves it down. Enter, P and S switch modes. }
procedure PartyOrderMenu;
var
  selected: ShortInt;
  isExtendedKey: Boolean;
  choice: Char;
begin
  selected := 0;
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    choice := MenuCore.MenuHorizontal('Party Order: ', GDConsts.orderMenus[selected], LightMagenta, LightGreen,
                                      White, True, True, isExtendedKey);
    if isExtendedKey then begin
      if selected = 0 then begin
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.DisplayParty(GDVars.curChar);
      end else begin
        case choice of
          C_Keys.HOME: Camp.OrderMoveUp;
          C_Keys.END_KEY: Camp.OrderMoveDown;
        end;
        CharHlp.DisplayParty(GDVars.curChar);
      end;
    end else
      if choice in [C_Keys.ENTER, 'P', 'S'] then begin
        selected := Ord(selected = 0);
        if selected <> 0 then
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has been selected', 10, False)
        else
          CharHlp.ClearMessageWindow;
      end;
  end;
end;

{ Drops the current character from the party after confirmation, with a farewell that depends on whether it is enabled,
  and redraws the party. For the last party member it offers to quit to DOS instead. }
procedure CampDropMenu;
begin
  if (GDVars.curChar^.nextCharAddr = nil) and (GDVars.curChar = GDVars.creatureList) then begin
    { last member: quit-to-DOS confirm }
    if MenuCore.YesNoMenu('quit TO DOS: ', Yellow, LightGreen, White) = 'Y' then begin
      CharGen.RemoveCreature(False, True);
      GameIo.ExitGame;
    end else
      Exit;
    Exit;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'will be gone', 10, False);
  if MenuCore.YesNoMenu('Drop from party? ', Yellow, LightGreen, White) = 'Y' then begin
    if GDVars.curChar^.enabled <> 0 then
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'bids you farewell', 10, True)
    else
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'is dumped in a ditch', 10, True);
    CharGen.RemoveCreature(False, True);
    Border.ClearBox(17, 1, 38, 11);
    CharHlp.DisplayParty(GDVars.curChar);
  end else
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'Breathes A sigh of relief', 10, True);
end;

{ Adjusts the game delay, 0 (fastest) to 9 (slowest). Faster and Slower are offered only while the delay can move that
  way; the up arrow slows the game and the down arrow speeds it up. }
procedure CampSpeedMenu;
var
  choice: Char;
  isExtendedKey: Boolean;
  menuText: Types.TStr40;
begin
  repeat
    TextRend.DisplayString(1, 18, LightGreen,
                           'Game Speed = ' + CharHlp.ByteToString(GDVars.gameDelay) + ' (0=fastest 9=slowest)');
    menuText := '';
    if GDVars.gameDelay > 0 then
      menuText := menuText + ' Faster';
    if GDVars.gameDelay < 9 then
      menuText := menuText + ' Slower';
    menuText := menuText + ' Exit';
    choice := MenuCore.MenuHorizontal('Game Speed:', menuText, LightMagenta, LightGreen, White, True,
                                      True, isExtendedKey);
    if isExtendedKey then begin
      case choice of
        C_Keys.DOWN: if GDVars.gameDelay > 0 then Dec(GDVars.gameDelay);
        C_Keys.UP: if GDVars.gameDelay < 9 then Inc(GDVars.gameDelay);
      end;
    end else
      case choice of
        'F': Dec(GDVars.gameDelay);
        'S': Inc(GDVars.gameDelay);
      end;
  until choice in [C_Keys.NONE, 'E'];
  CharHlp.ClearMessageWindow;
end;

{ Runs the Alter menu: Order, Drop, Speed, Icon and Pics, which toggles monster pictures and portraits; extended keys
  select the previous or next character. }
procedure CampAlterMenu;
var
  choice: Char;
  toggleChoice: Char;
  isExtendedKey: Boolean;
  menuText: Types.TStr40;
begin
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    choice := MenuCore.MenuHorizontal('Alter: ', GDConsts.alterMenu, LightMagenta, LightGreen, White, True, True,
                                      isExtendedKey);
    if isExtendedKey then begin
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case choice of
        'O': Camp.PartyOrderMenu;
        'D': Camp.CampDropMenu;
        'S': Camp.CampSpeedMenu;
        'I': begin
               CharGen.CustomizeIcon;
               CharHlp.DisplayNoncombatInterface;
             end;
        'P': repeat
               if GDVars.monsterPics <> 0 then
                 menuText := 'Monsters on  '
               else
                 menuText := 'Monsters off  ';
               if GDVars.portraitsOn <> 0 then
                 menuText := menuText + 'Portraits on  '
               else
                 menuText := menuText + 'Portraits off  ';
               menuText := menuText + 'Exit';
               toggleChoice := MenuCore.MenuHorizontal('', menuText, LightMagenta, LightGreen, White, False, True,
                                                       isExtendedKey);
               case toggleChoice of
                 'M': GDVars.monsterPics := Ord(GDVars.monsterPics = 0);
                 'P': GDVars.portraitsOn := Ord(GDVars.portraitsOn = 0);
               end;
             until toggleChoice in [C_Keys.NONE, 'E'];
      end;
  end;
end;

procedure CampMainMenu(var interrupted: Boolean);
var
  savedIfc: Byte;
  c: Char;
  { ViewCharMenu's var out }
  viewDone: Boolean;
  ext: Boolean;
begin
  savedIfc := GDVars.ifcState;
  GDVars.ifcState := C_Ifc.CAMPING;
  GDVars.healTicks := 0;
  FillChar(GDVars.restRemaining, SizeOf(GDVars.restRemaining), 0);
  CharHlp.DisplayNoncombatInterface;
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  TextRend.DisplayString(1, 18, LightGreen, 'The party makes camp...');
  Camp.ResetPartySpellActivities;
  interrupted := False;
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    c := MenuCore.MenuHorizontal('Camp: ', GDConsts.campMenu, LightMagenta, LightGreen, White, True, True,
                                 ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case c of
        'S': begin
               SaveLoad.SaveGame;
               if MenuCore.YesNoMenu('Quit TO DOS ', Yellow, LightGreen, White) = 'Y' then
                 GameIo.ExitGame;
             end;
        'V': ViewChar.ViewCharMenu(viewDone);
        'M': Camp.CampMagicMenu(interrupted);
        'R': Camp.RestForSpellPrep(interrupted);
        'A': Camp.CampAlterMenu;
      end;
  end;
  Camp.ResetPartySpellActivities;
  GDVars.castTarget := nil;
  GDVars.ifcState := savedIfc;
  CharHlp.PrintPositionAndTime;
  CharHlp.ClearMessageWindow;
  MenuCore.ClearBottomLine;
end;

begin
end.
