{ Spell selection, casting, targeting and spell-specific behavior. }
{$O+,F+}
unit Magic;

interface

uses Types, Crt, C_Npc, C_Terr, C_Save, C_Cond, GDConsts, GDVars, TextRend, Border,
  CharHlp, SoundDrv, MenuCore, Pathing, CbtMap, ClassCal, FxEngine, C_Effect, C_Race, C_Keys, C_Class, C_Status, C_Ifc,
  C_Dir, C_Spell;

{ Runs the spell-selection menu over spellList as GenerateSpellList built it, then frees the list. Scribing also sets
  castItem to the chosen spell's scroll.
  @param(selType 1 to cast, 2 to memorize (a shorter window, bottom row 15), 3 to scribe, 4 to learn on gaining a level
    (no Exit entry); anything else only views, with no title or prompt.)
  @param(idx The menu position, kept from one call to the next; below 0 clears the window and starts at 0 (casting and
    learning always redraw).)
  @returns(The chosen spell, or 0 for Exit.) }
function SpellSelection(selType: Byte; var idx: Integer): Byte;

{ Builds spellList and spellIds for a spell menu. Note: the spell book stops one short of the last spell, so it never
  lists Restoration; and learning reads Restoration's slots past the slot table's bound, from xpAward.
  @param(menuType 0 memorized, 5 still being memorized, 1 the spell book, 2 the current scroll, 3 the spells on each
    readable item, 6 the scroll spells queued for scribing, 4 the spells learnable on gaining a level (the character has
    slots of the spell's class and level and does not know it yet).)
  @returns(True when the list has entries.) }
function GenerateSpellList(menuType: Byte): Boolean;

{ Works out a spell's range: its fixed range plus its range per level times the casting level, level 6 for an item. A
  zero range with an area (touch) and the 255 attack-roll mark both become 1.
  @param(spell The spell.)
  @returns(The range in cells.) }
function CalcSpellRange(spell: Byte): Byte;

{ Picks the targets of a spell cast outside combat; it is installed as the cast-target handler outside combat. Target
  mode 1 targets the caster, 2 asks for one party member (remembered in castTarget; giving up clears the targets and the
  cast) and 4 targets each creature in the list; any other mode gives up the cast.
  @param(spell The spell.)
  @param(b Unused.)
  @param(cast Receives True when targets were picked.) }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Casts a spell for the current character. Outside combat a combat-only spell (target mode 0) is not cast: a memorized
  spell offers to lose it and an item offers to use it anyway. Otherwise, when ai is set and no item is in use, the cast
  is announced, then the cast-target handler runs until it picks targets or the cast ends. On a pick, in combat the
  caster turns to the aim, the cast sound plays and the projectile flies; then the caster loses its invisibility, the
  memorized spell is used up unless an item is in use, and the spell's handler runs with curSpell set. With no pick,
  outside combat it just returns; in combat automatic targeting, or Yes to Abort Spell, gives up the spell, and
  otherwise the targeting repeats.
  @param(spell The spell.)
  @param(b True for automatic targeting (the AI or quick fight).)
  @param(ai True to announce the cast.)
  @param(sel Receives True when targets were picked.) }
procedure CastSpell(spell: Byte; b, ai: Boolean; var sel: Boolean);

{ Tells whether an item is a scroll: it is not nil and its base item's slot is 11, 12 or 13.
  @param(it The item.)
  @returns(True for a readable item.) }
function ItemReadable(it: Types.PItemRec): Boolean;

{ Clears the last of a scroll's spell slots holding a spell, pending mark aside, and lowers its spell-count name part;
  the scroll goes once that count falls below 210. Nothing happens when no slot holds the spell.
  @param(cr The scroll's owner.)
  @param(it The scroll.)
  @param(spell The spell.) }
procedure RemoveSpellFromScroll(cr: Types.PCharRecord; it: Types.PItemRec; spell: Byte);

{ Announces a spell: in combat the creature casts a spell, with the spell's name on the bottom row; otherwise the
  creature's name, the message and the spell's name show in the message window for the text delay.
  @param(creature The caster.)
  @param(msg The message, ignored in combat.)
  @param(spell The spell.) }
procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);

{ Remove Curse (spellHandlers.spells[43], also called by Temple): remove Bestow Curse (effect 36) from spellTargets[1],
  or else clear the curse on its first cursed item. }
procedure SpellRemoveCurse;

{ Called by GameInit.InitializeGame: install every spell handler in GDVars.spellHandlers (castTargets is the noncombat
  cast-target UI) and EffBreatheLightning as effect 88's handler, clear effectLock, GDVars.usingItem and
  GDVars.castTarget, and set redrawInventory. }
procedure InitSpellFns;

implementation

type
  TSleepTier = (SleepTier0, SleepTier1, SleepTier2, SleepTier3, SleepTier4, SleepTier5);

function SpellSelection(selType: Byte; var idx: Integer): Byte;
var
  sel: Types.PItemRec;
  p: Types.PItemRec;
  prompt: Types.TStr40;
  title: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  count: Byte;
  bottomRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
begin
  case selType of
    1: title := 'Cast';
    2: title := 'Memorize';
    3: title := 'Scribe';
    4: title := 'Learn';
  else
    title := '';
  end;
  if selType in [1..4] then
    prompt := 'Choose Spell: '
  else
    prompt := '';
  if selType = 2 then
    bottomRow := 15
  else
    bottomRow := 22;
  if selType = 4 then
    addExit := False
  else
    addExit := True;
  redraw := False;
  if idx < 0 then begin
    Border.DrawWindow(1, 3, 38, bottomRow, 0, Black, '');
    redraw := True;
    idx := 0;
  end;
  if (selType = 4) or (selType = 1) then
    redraw := True;
  sel := nil;
  repeat
    ch := MenuCore.MenuVertical(prompt, title, LightMagenta, LightGreen, White, 1, 5, 38,
                                bottomRow, GDVars.spellList, addExit, redraw, idx, sel);
  until ch in [C_Keys.NONE, C_Keys.ENTER, 'C', 'E', 'L', 'M', 'S'];
  p := GDVars.spellList;
  count := 0;
  while p <> sel do begin
    if p^.inUse = 0 then
      Inc(count);
    p := p^.next;
  end;
  if ch in [C_Keys.NONE, 'E'] then
    SpellSelection := C_Spell.NO_SPELL
  else
    SpellSelection := GDVars.spellIds[count];
  if selType = 3 then
    GDVars.castItem := GDVars.scrollPtrs[count];
  MenuCore.FreeStringList(GDVars.spellList);
end;

{ Appends a spell to spellList, first adding a level heading (inUse set) when its level differs from the previous
  spell's. A pending spell gets a *. The spell, pending mark aside, goes into spellIds at the entry's selectable place.
  @param(spell The spell, with bit 7 set when pending.) }
procedure AddSpellToList(spell: Byte);
var
  p: Types.PItemRec;
  count: ShortInt;
  lastLevel: ShortInt;
begin
  p := GDVars.spellList;
  if GDVars.spellList = nil then begin
    { Allocate only a TMenuNode, the TItemRec prefix a MenuCore.MenuVertical entry uses (name, inUse and next); the rest
      of the record is never touched }
    GetMem(p, SizeOf(Types.TMenuNode));
    GDVars.spellList := p;
    lastLevel := 0;
    count := 0;
  end else begin
    count := 1;
    while p^.next <> nil do begin
      if p^.inUse = 0 then
        Inc(count);
      p := p^.next;
    end;
    lastLevel := GDConsts.spellTable[GDVars.spellIds[count - 1]].levelSp;
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
  end;
  p^.next := nil;
  if GDConsts.spellTable[spell and C_Spell.ID_MASK].levelSp <> lastLevel then begin
    p^.name := GDConsts.spellLevelNames[GDConsts.spellTable[spell and C_Spell.ID_MASK].levelSp];
    p^.inUse := 1;
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
    p^.next := nil;
  end;
  if spell > C_Spell.ID_MASK then
    p^.name := ' *'
  else
    p^.name := '  ';
  p^.name := p^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  p^.inUse := 0;
  GDVars.spellIds[count] := spell and C_Spell.ID_MASK;
end;

{ Adds castItem's spells to the list, recording the scroll in scrollPtrs for each. Read Magic, or any cleric level with
  a scroll of slot 12, identifies the scroll first; an unidentified scroll adds nothing.
  @param(forScribe True to add only the spells queued for scribing.) }
procedure AddScrollSpells(forScribe: Boolean);
var
  i: Byte;
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.READ_MAGIC, effect) or
      ((GDVars.curChar^.classLevels[C_Class.CLERIC_LEVEL] > 0) and
       (GDVars.baseItems[GDVars.castItem^.itemType].slot = 12)) then
    GDVars.castItem^.unidMask := 0;
  if GDVars.castItem^.unidMask = 0 then
    { 3 is the last index of TItemRec.spells }
    for i := 1 to 3 do begin
      if (forScribe and (GDVars.castItem^.spells[i] > C_Spell.PENDING_FLAG)) or
          (not forScribe and (GDVars.castItem^.spells[i] > 0)) then begin
        Magic.AddSpellToList(GDVars.castItem^.spells[i]);
        GDVars.scrollPtrs[GDVars.scrollCount] := GDVars.castItem;
        Inc(GDVars.scrollCount);
      end;
    end;
end;

{ Clears scrollPtrs and scrollCount, then adds the spells of each readable item the current character carries, through
  castItem, which ends as nil.
  @param(forScribe True to add only the spells queued for scribing.) }
procedure AddAllScrollSpells(forScribe: Boolean);
var
  i: Byte;
begin
  { the 49 slots of scrollPtrs }
  for i := 0 to 48 do
    GDVars.scrollPtrs[i] := nil;
  GDVars.scrollCount := 0;
  GDVars.castItem := GDVars.curChar^.itemsAddr;
  while GDVars.castItem <> nil do begin
    if Magic.ItemReadable(GDVars.castItem) then
      Magic.AddScrollSpells(forScribe);
    GDVars.castItem := GDVars.castItem^.next;
  end;
end;

function GenerateSpellList(menuType: Byte): Boolean;
var
  i: Byte;
begin
  GenerateSpellList := False;
  GDVars.spellList := nil;
  { the last index of spellIds }
  for i := 0 to 20 do
    GDVars.spellIds[i] := 0;
  case menuType of
    { the last index of memorizedSpells }
    0: for i := 0 to 20 do
         if (GDVars.curChar^.memorizedSpells[i] > 0) and
             (GDVars.curChar^.memorizedSpells[i] < C_Spell.PENDING_FLAG) then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i]);
    { the last index of memorizedSpells }
    5: for i := 0 to 20 do
         if GDVars.curChar^.memorizedSpells[i] > C_Spell.ID_MASK then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i]);
    { Note: 55 stops one short of the last spell, 56 (Restoration), so the spell book never lists Restoration. }
    1: for i := 1 to 55 do
         if GDVars.curChar^.spellsKnown[i] <> 0 then
           Magic.AddSpellToList(i);
    2: Magic.AddScrollSpells(False);
    3: Magic.AddAllScrollSpells(False);
    6: Magic.AddAllScrollSpells(True);
    { Note: for Restoration (spell 56, level 7) this reads slots[0, 7], past the 1..3 bound, which lands on xpAward's
      low byte }
    4: for i := 1 to 56 do
         if (GDVars.curChar^.slots[GDConsts.spellTable[i].castClassSp, GDConsts.spellTable[i].levelSp] > 0) and
             (GDVars.curChar^.spellsKnown[i] = 0) then
           Magic.AddSpellToList(i);
  end;
  if GDVars.spellList <> nil then
    GenerateSpellList := True;
end;

function CalcSpellRange(spell: Byte): Byte;
var
  r: Byte;
begin
  if GDVars.usingItem = False then
    r := GDConsts.spellTable[spell].rangeFixed + GDConsts.spellTable[spell].rangeVar * CharHlp.GetCasterLevel(spell)
  else
    r := GDConsts.spellTable[spell].rangeVar * 6 + GDConsts.spellTable[spell].rangeFixed;
  { Touch: zero range with an area }
  if (r = 0) and (GDConsts.spellTable[spell].area <> 0) then
    r := 1;
  { A range of 255 marks an attack-roll spell }
  if r = 255 then
    r := 1;
  CalcSpellRange := r;
end;

{ Works out a spell's duration: its fixed duration plus its duration per level times the casting level, except for the
  item spells that roll their own (Cause Disease, Potion of Speed, Wand of Paralyzation, Giant Strength, Dust of
  Disappearance, Manual of Bodily Health).
  @param(spell The spell.)
  @returns(The duration in minutes.) }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Word;
begin
  case spell of
    { Cause Disease }
    40: d := FxEngine.RollDice(1, 6) * 10;
    { Potion of Speed, Wand of Paralyzation }
    57, 61: d := FxEngine.RollDice(5, 4);
    { Giant Strength }
    59: d := FxEngine.RollDice(1, 4) * 10 + 40;
    { Dust of Disappearance }
    63: if GDVars.ifcState = C_Ifc.IN_COMBAT then
                d := FxEngine.RollDice(2, 10) * 10
              else
                d := (FxEngine.RollDice(1, 10) + 10) * 10;
    { Manual of Bodily Health: 1440 minutes, 24 hours }
    67: d := 1440;
  else
    d := GDConsts.spellTable[spell].durFixed + GDConsts.spellTable[spell].durVar * CharHlp.GetCasterLevel(spell);
  end;
  CalcSpellDuration := d;
end;

{ Applies a spell to each target. The save is rolled only when the spell has a saving throw. A spell of fixed range 255
  needs an attack roll as well; a miss counts as saved and zeroes the damage for this and each later target. The damage
  is dealt with the save reducing it, and the spell's effect, if any, is added. With no targets it returns at once,
  leaving the element mask set.
  @param(spell The spell.)
  @param(eff The effect's strength; 0 for the casting level.)
  @param(onRemove True to call the effect's handler when it is removed.)
  @param(damage The damage; 0 for none.)
  @param(elem The damage's element mask.)
  @param(msg Printed after each target's name when the effect takes hold.) }
procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40);
var
  effLevel: Byte;
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
begin
  if damage = 0 then
    GDVars.elementMask := 0
  else
    GDVars.elementMask := elem;
  if GDVars.spellTargetCount = 0 then
    Exit;
  if eff = 0 then
    effLevel := CharHlp.GetCasterLevel(spell)
  else
    effLevel := eff;
  for i := 1 to GDVars.spellTargetCount do begin
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      if not GDConsts.spellTable[spell].saveEffect then
        saved := False
      else
        saved := FxEngine.RollSavingThrow(tgt, GDConsts.spellTable[spell].saveType, 0);
      if GDConsts.spellTable[GDVars.curSpell].rangeFixed = 255 then begin
        CharHlp.RecalcStats(tgt);
        FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, tgt);
        if not FxEngine.AttackRoll(GDVars.curChar, tgt, tgt^.acCur) then begin
          damage := 0;
          saved := True;
        end;
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(tgt, damage, Byte(GDConsts.spellTable[spell].saveEffect), saved);
      if GDConsts.spellTable[spell].effect > 0 then
        FxEngine.AddEffectWithMessage(tgt, GDConsts.spellTable[spell].effect, Magic.CalcSpellDuration(spell), effLevel,
                                      onRemove, GDConsts.spellTable[spell].saveEffect, saved, msg);
    end;
  end;
  GDVars.elementMask := 0;
end;

procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  target: Pointer;
begin
  if GDVars.castTarget = nil then
    GDVars.castTarget := GDVars.curChar;
  GDVars.spellTargets[1] := GDVars.curChar;
  GDVars.spellTargetCount := 1;
  cast := True;
  case GDConsts.spellTable[spell].target of
    1: ;
    2: begin
         CharHlp.DisplayNoncombatInterface;
         CharHlp.SelectChar('Cast Spell on whom', True, GDVars.castTarget);
         if GDVars.castTarget = nil then begin
           GDVars.spellTargets[1] := nil;
           GDVars.spellTargetCount := 0;
           cast := False;
         end else
           GDVars.spellTargets[1] := GDVars.castTarget;
       end;
    4: begin
         GDVars.spellTargets[GDVars.spellTargetCount] := GDVars.creatureList;
         while GDVars.spellTargets[GDVars.spellTargetCount]^.nextCharAddr <> nil do begin
           GDVars.spellTargets[GDVars.spellTargetCount + 1] :=
             GDVars.spellTargets[GDVars.spellTargetCount]^.nextCharAddr;
           Inc(GDVars.spellTargetCount);
         end;
       end;
  else
    cast := False;
  end;
end;

procedure CastSpell(spell: Byte; b, ai: Boolean; var sel: Boolean);
var
  ok: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  x: ShortInt;
  y: ShortInt;
  k: Byte;
  p: Types.PCharRecord;
begin
  p := GDVars.curChar;
  ok := True;
  if (GDVars.ifcState <> C_Ifc.IN_COMBAT) and (GDConsts.spellTable[spell].target = 0) then begin
    if GDVars.usingItem = False then begin
      TextRend.DisplayString(1, 19, LightGreen, GDConsts.spellNames[spell]);
      TextRend.DisplayString(1, 20, LightGreen, 'is a combat-only spell...');
      if MenuCore.YesNoMenu('Lose it? ', LightMagenta, White, LightGreen) = 'Y' then
        CharHlp.RemoveSpell(spell);
    end else begin
      TextRend.DisplayString(1, 19, LightGreen, 'That Item');
      TextRend.DisplayString(1, 20, LightGreen, 'is a combat-only item...');
      if MenuCore.YesNoMenu('Use it? ', LightMagenta, White, LightGreen) = 'Y' then
        sel := True;
    end;
    ai := False;
    ok := False;
  end;
  if ai then
    if GDVars.usingItem = False then
      Magic.PrintCastSpellMsg(p, 'casts', spell);
  while ok do begin
    GDVars.spellHandlers.castTargets(spell, b, sel);
    if sel then begin
      ok := False;
      if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
        CharHlp.BuildIconFacings(18);
        x := CbtMap.CombatCellX(p);
        y := CbtMap.CombatCellY(p);
        k := 0;
        while not Pathing.IsDirToward(x, y, GDVars.targetX, GDVars.targetY, k) do
          Inc(k);
        CbtMap.SetCreatureFacing(p, k, 1, 0);
        SoundDrv.SoundSetAutoStop(0);
        case spell of
          { Fireball: 11 }
          47: SoundDrv.SoundCommand(GDConsts.soundIds.combat[7]);
          { Lightning: 8 }
          51: SoundDrv.SoundCommand(GDConsts.soundIds.combat[4]);
        else
          { default: 2 }
          SoundDrv.SoundCommand(GDConsts.soundIds.commands[3]);
        end;
        CharHlp.CombatAnimateMovingIcon(x, y, GDVars.targetX, GDVars.targetY, 4, 30);
        SoundDrv.SoundSetAutoStop(10);
        if CbtMap.CombatIconVisible(p, 0) then begin
          CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 1, 1);
          CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 0, 0);
        end;
      end;
      FxEngine.RemoveInvisibility(p);
      if GDVars.usingItem = False then
        CharHlp.RemoveSpell(spell);
      GDVars.curSpell := spell;
      GDVars.spellHandlers.spells[GDVars.curSpell];
      GDVars.curSpell := C_Spell.NO_SPELL;
      GDVars.multiTarget := 0;
    end else begin
      if GDVars.ifcState <> C_Ifc.IN_COMBAT then
        ok := False
      else if b or (MenuCore.YesNoMenu('Abort Spell? ', Yellow, LightGreen, White) = 'Y') then
      begin
        CharHlp.PrintBottomLine('Spell Aborted');
        if GDVars.usingItem = False then
          CharHlp.RemoveSpell(spell);
        ok := False;
      end;
    end;
  end;
  CharHlp.ClearMessageWindow;
  if GDVars.ifcState = C_Ifc.IN_COMBAT then
    Border.ClearBox(0, 23, 39, 23);
end;

{ Resolves Bless or Curse for the targets on one team, dropping the others and, for Bless in combat, those with an enemy
  beside them.
  @param(hostFlag The team to keep: 0 the party's side, 1 the hostiles.)
  @param(msg The effect message.) }
procedure CastOneSide(hostFlag: ShortInt; msg: Types.TStr40);
var
  i: Byte;
begin
  GDVars.multiTarget := 1;
  for i := 1 to GDVars.spellTargetCount do begin
    if (GDVars.spellTargets[i]^.hostile <> hostFlag) or
        ((GDVars.curSpell = 1) and (GDVars.ifcState = C_Ifc.IN_COMBAT) and
         (CharHlp.CountTargets(GDVars.spellTargets[i], 1) > 0)) then
      GDVars.spellTargets[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, msg);
end;

{ Bless: apply the spell to the caster's own team (see CastOneSide). }
procedure SpellBless;
begin
  Magic.CastOneSide(GDVars.curChar^.hostile, 'is Blessed');
end;

{ Curse: apply the spell to the caster's enemies (see CastOneSide). }
procedure SpellCurse;
begin
  Magic.CastOneSide(CharHlp.EnemyTeam(GDVars.curChar), 'is Cursed');
end;

{ Cure Light Wounds: restore 1d8 hit points to the first target. }
procedure SpellCureLightWounds;
begin
  if GDVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(1, 8), False) then
    CharHlp.AnnounceHealStatus(GDVars.spellTargets[1]);
end;

{ Cause Light Wounds: 1d8 damage, element mask 8. }
procedure SpellCauseLightWounds;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, FxEngine.RollDamageDice(1, 8), 8, '');
end;

{ Shared handler for the detection-style spells: apply the spell's effect. }
procedure SpellDetection;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is affected');
end;

{ Shared handler for the protection spells: apply the spell's effect. }
procedure SpellProtection;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is protected');
end;

{ Resist Cold: apply the spell's effect. }
procedure SpellResistCold;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is cold-resistant');
end;

{ Burning Hands: caster-level damage, element mask 9. }
procedure SpellBurningHands;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, CharHlp.GetCasterLevel(GDVars.curSpell), 9,
                      '');
end;

{ Charm Person: only targets with charType 0..1 and icon size 1 can be charmed. The Charm effect's strength is the
  caster's hostile * 128 + caster level; afterwards the target's first Charm effect (normally the one just added) has
  its handler called with removed = False. }
procedure SpellCharmPerson;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargets[1];
  if (tgt^.charType > 1) or (tgt^.iconDimensions > 1) then
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
  else begin
    Magic.ResolveSpell(GDVars.curSpell,
                        GDVars.curChar^.hostile * 128 + CharHlp.GetCasterLevel(GDVars.curSpell), True, 0,
                        0, 'is charmed');
    if CharHlp.HasEffect(tgt, C_Effect.CHARM, effect) then
      FxEngine.CallEffectHandler(C_Effect.CHARM, GDVars.spellTargets[1], effect, False);
  end;
end;

{ Enlarge: set the first target's Strength from the caster level and add the Enlarge effect, which keeps the Strength
  encoding AdjustForNewStrength returns. }
procedure SpellEnlarge;
var
  enc: Byte;
begin
  { Strength 18 with exceptional Strength 0, 1, 51, 76, 91 or 100 for caster levels 1..6 }
  GDVars.spellScratch := 18;
  { Other caster levels leave spellScratch2 unchanged }
  case CharHlp.GetCasterLevel(GDVars.curSpell) of
    1: GDVars.spellScratch2 := 0;
    2: GDVars.spellScratch2 := 1;
    3: GDVars.spellScratch2 := 51;
    4: GDVars.spellScratch2 := 76;
    5: GDVars.spellScratch2 := 91;
    6: GDVars.spellScratch2 := 100;
  end;
  if FxEngine.AdjustForNewStrength(GDVars.spellTargets[1], GDVars.spellScratch, GDVars.spellScratch2, enc) then
    CharHlp.PrintCreatureMessage(GDVars.spellTargets[1], 'is stronger', 10, True);
  { enc: the Strength encoding AdjustForNewStrength returned, kept as the effect's strength }
  FxEngine.AddEffect(GDVars.spellTargets[1], C_Effect.ENLARGE,
                     Magic.CalcSpellDuration(GDVars.curSpell), enc, True);
end;

{ Reduce: if spellTargets[1] fails a spell save, remove its Enlarge effect (12) }
procedure SpellReduce;
begin
  if GDVars.spellTargetCount > 0 then
    if not FxEngine.RollSavingThrow(GDVars.spellTargets[1], C_Save.SPELL, 0) then
      if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.ENLARGE) then
        CharHlp.PrintCreatureMessage(GDVars.spellTargets[1], 'has been reduced', 10, True);
end;

{ Friends: +2d4 Charisma, capped at 25; the effect's strength is the old Charisma, restored on removal }
procedure SpellFriends;
var
  oldCha: Byte;
begin
  oldCha := GDVars.spellTargets[1]^.chaCur;
  Inc(GDVars.spellTargets[1]^.chaCur, FxEngine.RollDice(2, 4));
  { 25, the Cha cap }
  if GDVars.spellTargets[1]^.chaCur > 25 then
    GDVars.spellTargets[1]^.chaCur := 25;
  Magic.ResolveSpell(GDVars.curSpell, oldCha, True, 0, 0, 'is friendly');
end;

{ Magic Missile: (caster level div 2)d4 + caster level div 2 damage, element mask 8. }
procedure SpellMagicMissile;
var
  cl: Byte;
begin
  cl := CharHlp.GetCasterLevel(GDVars.curSpell);
  Magic.ResolveSpell(GDVars.curSpell, 0, False, cl div 2 + FxEngine.RollDamageDice(cl div 2, 4), 8, '');
end;

{ Shield: apply the spell's effect. }
procedure SpellShield;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is shielded');
end;

{ Shocking Grasp: 1d8 + caster level damage, element mask $C. }
procedure SpellShockingGrasp;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False,
                      FxEngine.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GDVars.curSpell), $C, '');
end;

{ Sleep: a 4d4 hit-dice pool. Cost per target by levelHighest: 0..1 -> 1, 2 -> 2, 3 -> 4, 4 -> 6, 5 -> 10 for MONSTER
  and 20 otherwise, higher -> 20. Animated dead (ANIMATED), targets already asleep (effect 53) and targets the remaining
  pool cannot pay for are dropped; the pool is spent greedily in target order. }
procedure SpellSleep;
var
  i: Byte;
  effect: Types.PEffectRec;
begin
  GDVars.multiTarget := 1;
  GDVars.spellScratch := FxEngine.RollDice(4, 4);
  for i := 1 to GDVars.spellTargetCount do begin
    case TSleepTier(GDVars.spellTargets[i]^.levelHighest) of
      SleepTier0..SleepTier1: GDVars.spellScratch2 := 1;
      SleepTier2: GDVars.spellScratch2 := 2;
      SleepTier3: GDVars.spellScratch2 := 4;
      SleepTier4: GDVars.spellScratch2 := 6;
      SleepTier5: if GDVars.spellTargets[i]^.race = C_Race.MONSTER then
              GDVars.spellScratch2 := 10
            else
              GDVars.spellScratch2 := 20;
    else
      GDVars.spellScratch2 := 20;
    end;
    if (GDVars.spellTargets[i]^.status <> C_Status.ANIMATED) and
        (not CharHlp.HasEffect(GDVars.spellTargets[i], C_Effect.SLEEP, effect)) and
        (GDVars.spellScratch >= GDVars.spellScratch2) then
      Dec(GDVars.spellScratch, GDVars.spellScratch2)
    else
      GDVars.spellTargets[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'falls asleep');
end;

{ Hold Person (spells 23 and 49): save modifier -2 (cleric) or -3 (mage) for one target, -1 for two, 0 for three or
  four. Targets are processed in reverse; each one after the first processed (i < spellTargetCount) gets its own
  projectile animation. Targets with charType > 1 or icon size > 1 always save. }
procedure SpellHold;
var
  tgt: Types.PCharRecord;
  saved: Boolean;
  i: Byte;
  smod: ShortInt;
begin
  { Note: outside 1..4 targets, smod is left uninitialized }
  case GDVars.spellTargetCount of
    1: if GDVars.curSpell = 23 then
         smod := -2
       else
         smod := -3;
    2: smod := -1;
    3, 4: smod := 0;
  end;
  for i := GDVars.spellTargetCount downto 1 do begin
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      if i < GDVars.spellTargetCount then begin
        SoundDrv.SoundSetAutoStop(0);
        SoundDrv.SoundCommand(GDConsts.soundIds.commands[3]);
        CharHlp.BuildIconFacings(18);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.curChar), CbtMap.CombatCellY(GDVars.curChar),
                                        CbtMap.CombatCellX(tgt), CbtMap.CombatCellY(tgt), 4, 30);
        SoundDrv.SoundSetAutoStop(10);
      end;
      saved := FxEngine.RollSavingThrow(tgt, GDConsts.spellTable[GDVars.curSpell].saveType, smod);
      if (tgt^.charType > 1) or (tgt^.iconDimensions > 1) then
        saved := True;
      FxEngine.AddEffectWithMessage(tgt, GDConsts.spellTable[GDVars.curSpell].effect,
                                    Magic.CalcSpellDuration(GDVars.curSpell),
                                    CharHlp.GetCasterLevel(GDVars.curSpell), False,
                                    GDConsts.spellTable[GDVars.curSpell].saveEffect, saved, 'is held');
    end;
  end;
end;

{ Resist Fire: apply the spell's effect. }
procedure SpellResistFire;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is fire resistant');
end;

{ Silence: apply the spell's effect. }
procedure SpellSilence;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is silenced');
end;

{ Slow Poison: animated dead are skipped. A poisoned target (effect 55) has hpCur raised to at least 1, gets the spell's
  effect at strength 255, runs the effect-78 (heal/wake) handler with removed = True, and gains effect 15 for 10 minutes
  at strength 255. }
procedure SpellSlowPoison;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargets[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.spellTargets[1] := nil
  else if CharHlp.HasEffect(tgt, C_Effect.POISONED, effect) then begin
    if tgt^.hpCur = 0 then
      tgt^.hpCur := 1;
    Magic.ResolveSpell(GDVars.curSpell, 255, True, 0, 0, 'is affected');
    FxEngine.CallEffectHandler(C_Effect.HEAL_WAKE, tgt, nil, True);
    FxEngine.AddEffect(tgt, C_Effect.SLOW_POISON_HIT, 10, 255, True);
  end;
end;

{ Snake Charm: rebuild the target list from GDVars.creatureList: snakes whose hpCur still fits in a pool equal to the
  caster's hpCur, paid in list order }
procedure SpellSnakeCharm;
var
  p: Types.PCharRecord;
begin
  GDVars.spellScratch := GDVars.curChar^.hpCur;
  GDVars.spellTargetCount := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    { charType 14: snake }
    if p^.charType = 14 then
      if GDVars.spellScratch >= p^.hpCur then begin
        GDVars.spellScratch := GDVars.spellScratch - p^.hpCur;
        Inc(GDVars.spellTargetCount);
        GDVars.spellTargets[GDVars.spellTargetCount] := p;
      end;
    p := p^.nextCharAddr;
  end;
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is charmed');
end;

{ Spiritual Hammer: apply the spell's effect, then run the Spiritual Hammer effect handler for the first target. }
procedure SpellSpiritualHammer;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(C_Effect.SPIRITUAL_HAMMER, GDVars.spellTargets[1], nil, False);
end;

{ Invisibility: apply the spell's effect. }
procedure SpellInvisibility;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is invisible');
end;

{ Knock: apply the spell's effect. }
procedure SpellKnock;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'Knock-Knock');
end;

{ Mirror Image: apply the spell's effect with 1d4 images as its strength. }
procedure SpellMirrorImage;
begin
  Magic.ResolveSpell(GDVars.curSpell, FxEngine.RollDice(1, 4), False, 0, 0, 'is duplicated');
end;

{ Ray of Enfeeblement: apply the spell's effect. }
procedure SpellRayOfEnfeeblement;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is weakened');
end;

{ Stinking Cloud: append a node to the stinkHead list and give the caster effect 40 for caster-level minutes at strength
  caster level + myClouds * 16, where myClouds counts the caster's clouds among the nodes passed while walking to the
  tail (the old tail node itself is not checked). The cloud covers the 2x2 block whose upper-left is the aim cell
  (GDConsts.cloudDir: center, E, SE, S). Each cell records the terrain underneath (a cell already under another cloud
  takes that cloud's saved terrain, a corpse cell the corpse's), and passable cells are stamped TERRAIN_STINK_CLOUD;
  every creature found in the four cells then gets FxEngine.ConsiderTerrainEffects. }
procedure SpellStinkingCloud;
var
  otherCloud: Types.PStinkRec;
  node: Types.PStinkRec;
  crIdx: array[1..4] of Byte;
  j: Byte;
  myClouds: Byte;
  terr: Byte;
  cl: Byte;
  k: Byte;
  d: Byte;
begin
  GDVars.multiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.curSpell);
  myClouds := 0;
  node := GDVars.stinkHead;
  if GDVars.stinkHead = nil then begin
    GetMem(GDVars.stinkHead, SizeOf(Types.TStinkRec));
    node := GDVars.stinkHead;
  end else begin
    while node^.next <> nil do begin
      if node^.caster = GDVars.curChar then
        Inc(myClouds);
      node := node^.next;
    end;
    GetMem(node^.next, SizeOf(Types.TStinkRec));
    node := node^.next;
  end;
  FillChar(node^, SizeOf(Types.TStinkRec), 0);
  FxEngine.AddEffect(GDVars.curChar, C_Effect.CAST_STINKING_CLOUD, cl, cl + myClouds * 16, True);
  node^.caster := GDVars.curChar;
  node^.idx := myClouds;
  node^.ulX := GDVars.targetX;
  node^.ulY := GDVars.targetY;
  for k := 1 to 4 do begin
    d := GDConsts.cloudDir[k];
    CbtMap.GetArenaContents(GDVars.targetX + GDConsts.dirDx[d], GDVars.targetY + GDConsts.dirDy[d], crIdx[k],
                            terr);
    if (terr > 0) and (GDConsts.terrainInfo[terr].cost < 255) then
      node^.exists[k] := 1
    else
      node^.exists[k] := 0;
    if terr = C_Terr.TERRAIN_STINK_CLOUD then begin
      otherCloud := GDVars.stinkHead;
      while otherCloud <> nil do begin
        if otherCloud <> node then
          for j := 1 to 4 do
            if (otherCloud^.exists[j] <> 0) and
                (otherCloud^.ulX + GDConsts.dirDx[GDConsts.cloudDir[j]] = GDVars.targetX + GDConsts.dirDx[d]) and
                (otherCloud^.ulY + GDConsts.dirDy[GDConsts.cloudDir[j]] = GDVars.targetY + GDConsts.dirDy[d]) then
              if otherCloud^.under[j] <> C_Terr.TERRAIN_STINK_CLOUD then
                terr := otherCloud^.under[j];
        otherCloud := otherCloud^.next;
      end;
    end else if terr = C_Terr.TERRAIN_CORPSE then begin
      for j := 1 to GDVars.downedCount do
        if GDVars.downed[j].x = GDVars.targetX + GDConsts.dirDx[d] then
          if GDVars.downed[j].y = GDVars.targetY + GDConsts.dirDy[d] then
            terr := GDVars.downed[j].terrain;
    end;
    node^.under[k] := terr;
    if node^.exists[k] <> 0 then
      GDVars.arenaPtr^.cells[GDVars.targetY + GDConsts.dirDy[d],
                               GDVars.targetX + GDConsts.dirDx[d]] := C_Terr.TERRAIN_STINK_CLOUD;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'Creates a noxious cloud', 10, False);
  CbtMap.ScrollView(GDVars.targetX, GDVars.targetY, 255, C_Dir.CENTER);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  for k := 1 to 4 do
    if crIdx[k] > 0 then
      FxEngine.ConsiderTerrainEffects(GDVars.creatureArr[crIdx[k]]);
end;

{ Strength: add 1d4 for a mage, 1d6 for a cleric or thief, 1d8 for a fighter; when several classes match, the last test
  wins. Above 18, fighters turn each extra point into 10 points of exceptional Strength (capped at 100) and others are
  held at 18. }
procedure SpellStrength;
var
  tgt: Types.PCharRecord;
  exStr: Byte;
  roll: Byte;
  newStr: Byte;
  enc: Byte;
begin
  exStr := 0;
  tgt := GDVars.spellTargets[1];
  if tgt^.classLevels[C_Class.MAGE_LEVEL] > 0 then
    roll := FxEngine.RollDice(1, 4);
  if (tgt^.classLevels[C_Class.CLERIC_LEVEL] > 0) or (tgt^.classLevels[C_Class.THIEF_LEVEL] > 0) then
    roll := FxEngine.RollDice(1, 6);
  if tgt^.classLevels[C_Class.FIGHTER_LEVEL] > 0 then
    roll := FxEngine.RollDice(1, 8);
  { Note: no matching class leaves roll uninitialized }
  newStr := tgt^.strCur + roll;
  if newStr > 18 then begin
    if tgt^.classLevels[C_Class.FIGHTER_LEVEL] > 0 then begin
      { 10 exceptional points per point above 18 }
      exStr := tgt^.strExc + (newStr - 18) * 10;
      { Percentile cap 100 }
      if exStr > 100 then
        exStr := 100;
      newStr := 18;
    end else
      newStr := 18;
  end;
  if FxEngine.AdjustForNewStrength(tgt, newStr, exStr, enc) then
    CharHlp.PrintCreatureMessage(tgt, 'is stronger', 10, True);
  FxEngine.AddEffect(tgt, C_Effect.STRENGTH, Magic.CalcSpellDuration(GDVars.curSpell), enc, True);
end;

{ Animate Dead: animate up to caster-level dead (DEAD_STATUS) human (charType 0) creatures whose cell is still a valid
  location. Effect 32's strength is the old hostile * 16 + caster level. Each corpse joins the caster's team under
  computer control (quickfight 1), becomes undead (charType 4, levelUndead 2, movementBase 6, attackLevel 0), loses its
  memorized spells and gets the animated NPC or PC npc code; if ReviveDeadCreature succeeds at full hpMax it also gets
  effect 32 and ANIMATED. }
procedure SpellAnimateDead;
var
  i: Byte;
  strength: Byte;
  n: Byte;
  p: Types.PCharRecord;
begin
  GDVars.multiTarget := 1;
  n := CharHlp.GetCasterLevel(GDVars.curSpell);
  GDVars.spellTargetCount := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (n > 0) do begin
    if p^.status = C_Status.DEAD_STATUS then
      { Human }
      if p^.charType = 0 then
        if CbtMap.IsValidCreatureLoc(p, CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), True) then begin
          strength := p^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.curSpell);
          p^.hostile := GDVars.curChar^.hostile;
          p^.quickfight := 1;
          p^.levelUndead := 2;
          p^.attackLevel := 0;
          p^.movementBase := 6;
          { the last index of memorizedSpells }
          for i := 0 to 20 do
            p^.memorizedSpells[i] := 0;
          { NON_PLAYER set }
          if p^.npc > $7F then
            p^.npc := C_Npc.ANIMATED_CREATURE
          else
            p^.npc := C_Npc.ANIMATED_MEMBER;
          { Undead }
          p^.charType := 4;
          if GDVars.ifcState = C_Ifc.IN_COMBAT then
            p^.combatAddr^.other := nil;
          Dec(n);
          if FxEngine.ReviveDeadCreature(p, p^.hpMax) then begin
            FxEngine.AddEffectWithMessage(p, C_Effect.ANIMATE_DEAD, 0, strength, True, False, False, 'is animated');
            p^.status := C_Status.ANIMATED;
          end;
        end;
    p := p^.nextCharAddr;
  end;
end;

{ Cure Blindness: remove the first target's blindness. }
procedure SpellCureBlindness;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.BLIND) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'can see');
end;

{ Cause Blindness: apply the spell's effect. }
procedure SpellCauseBlindness;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is blind');
end;

{ Removes the first target's diseases under the effect lock: Diseased, the Strength-draining disease (with its hit-point
  and helpless effects) and rot (with mummy rot).
  @returns(True when any of the three was present.) }
function RemoveDiseaseEffects: Boolean;
begin
  RemoveDiseaseEffects := False;
  GDVars.effectLock := 1;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.DISEASED) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.DISEASE_STRENGTH) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(GDVars.spellTargets[1], C_Effect.DISEASE_HIT_POINTS, nil);
    FxEngine.RemoveEffect(GDVars.spellTargets[1], C_Effect.HELPLESS, nil);
  end;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.ROT_NO_HEALING) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(GDVars.spellTargets[1], C_Effect.MUMMY_ROT, nil);
  end;
  GDVars.effectLock := 0;
end;

{ Cure Disease: remove the first target's disease effects. }
procedure SpellCureDisease;
var
  { Unused in this version; see the other implementations of this routine. }
  cured: Boolean;
begin
  cured := Magic.RemoveDiseaseEffects;
end;

{ Cause Disease: apply the spell's effect. }
procedure SpellCauseDisease;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, True, 0, 0, 'is diseased');
end;

{ Dispel Magic: try every effect whose strength is below 255, with its low nibble as the effect's caster level: 50%, +5%
  per caster level above it, -2% per level below. }
procedure SpellDispelMagic;
var
  i: Byte;
  cl: Byte;
  tgt: Types.PCharRecord;
  removed: Boolean;
  effect: Types.PEffectRec;
  nxt: Types.PEffectRec;
begin
  GDVars.multiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.curSpell);
  for i := 1 to GDVars.spellTargetCount do begin
    removed := False;
    { Note: uses spellTargets[1] on every pass, whatever i is }
    tgt := GDVars.spellTargets[1];
    effect := Types.PEffectRec(tgt^.effectsAddr);
    while effect <> nil do begin
      nxt := effect^.next;
      if effect^.strength < 255 then begin
        { dispel treats the low nibble as caster level }
        GDVars.spellScratch2 := effect^.strength and $F;
        if cl > GDVars.spellScratch2 then
          GDVars.spellScratch := (cl - GDVars.spellScratch2) * 5 + 50
        else if cl < GDVars.spellScratch2 then
          GDVars.spellScratch := 50 - (GDVars.spellScratch2 - cl) * 2
        else
          GDVars.spellScratch := 50;
        if FxEngine.RollDice(1, 100) <= GDVars.spellScratch then begin
          FxEngine.RemoveEffect(tgt, effect^.id, effect);
          removed := True;
        end;
      end;
      effect := nxt;
    end;
    if removed then
      CharHlp.PrintNameStringAnim(tgt, True, 'is affected');
  end;
end;

{ Prayer: apply the spell's effect at strength caster team * 16 + caster level. }
procedure SpellPrayer;
begin
  Magic.ResolveSpell(GDVars.curSpell,
                      GDVars.curChar^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.curSpell), False, 0,
                      0, 'is praying');
end;

procedure SpellRemoveCurse;
var
  item: Types.PItemRec;
  found: Boolean;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.BESTOW_CURSE) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'is un-cursed')
  else begin
    found := False;
    item := GDVars.spellTargets[1]^.itemsAddr;
    while (item <> nil) and (found = False) do begin
      if item^.cursed <> 0 then begin
        found := True;
        item^.cursed := 0;
      end;
      item := item^.next;
    end;
    if found then
      CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, '''s item is un-cursed');
  end;
end;

{ Bestow Curse: apply the spell's effect. }
procedure SpellBestowCurse;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'has been cursed!');
end;

{ Blink: apply the spell's effect. }
procedure SpellBlink;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is blinking');
end;

{ Fireball: spell 64 (an item fireball) uses level 1d3 * 2 + 1. When zone0^.view3dFlag is 0 the target list is rebuilt
  with Pathing.BuildTargetList, radius 2 around the aim cell. Damage is level d6, element mask 9. }
procedure SpellFireball;
var
  cl: Byte;
  i: Byte;
begin
  GDVars.multiTarget := 1;
  if GDVars.curSpell = 64 then
    cl := FxEngine.RollDice(1, 3) * 2 + 1
  else
    cl := CharHlp.GetCasterLevel(GDVars.curSpell);
  if GDVars.zone0^.view3dFlag = 0 then begin
    Pathing.BuildTargetList(GDVars.targetX, GDVars.targetY, 2, 255, 1, GDVars.arenaPtr);
    for i := 1 to GDVars.targetCount do
      GDVars.spellTargets[i] := GDVars.creatureArr[GDVars.targetList[i].idx];
    GDVars.spellTargetCount := GDVars.targetCount;
  end;
  CbtMap.ScrollView(GDVars.targetX, GDVars.targetY, 0, C_Dir.CENTER);
  Magic.ResolveSpell(GDVars.curSpell, 0, False, FxEngine.RollDamageDice(cl, 6), 9, '');
end;

{ Resolves Haste or Slow for up to the casting level of targets on one team, dropping the rest. A kept target with the
  opposing effect only loses it; the others take the spell's effect and have their movement and attack-rate effects run
  again.
  @param(removeId The opposing effect, Slowed or Hasted.)
  @param(hostFlag The team to keep: 0 the party's side, 1 the hostiles.)
  @param(msg The effect message.) }
procedure HasteSlowLogic(removeId: Byte; hostFlag: ShortInt; msg: Types.TStr40);
var
  cl: Byte;
  i: Byte;
begin
  GDVars.multiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.curSpell);
  for i := 1 to GDVars.spellTargetCount do begin
    if (GDVars.spellTargets[i]^.hostile = hostFlag) and (cl > 0) then begin
      Dec(cl);
      if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[i], removeId) then
        GDVars.spellTargets[i] := nil;
    end else
      GDVars.spellTargets[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, msg);
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then
      FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, GDVars.spellTargets[i]);
end;

{ Haste: the caster's team loses Slowed or is hasted (see HasteSlowLogic). }
procedure SpellHaste;
begin
  Magic.HasteSlowLogic(C_Effect.SLOWED, GDVars.curChar^.hostile, 'is Hasted');
end;

{ Deals lightning damage to the creature on one cell of a bolt, halved on a save.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(damage The damage.)
  @param(saveType The saving throw.)
  @param(blocked Receives True when the cell's terrain is impassable.) }
procedure LightningAttackAt(x, y: ShortInt; damage: Byte; saveType: ShortInt; var blocked: Boolean);
var
  tgt: Types.PCharRecord;
  crIdx: Byte;
  terr: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hitDamage: Word;
begin
  blocked := False;
  CbtMap.GetArenaContents(x, y, crIdx, terr);
  if terr > 0 then
    if GDConsts.terrainInfo[terr].cost = 255 then
      blocked := True;
  if crIdx > 0 then begin
    tgt := GDVars.creatureArr[crIdx];
    GDVars.elementMask := $C;
    FxEngine.InflictNonWeaponDamage(tgt, damage, 2, FxEngine.RollSavingThrow(tgt, saveType, 0));
    CharHlp.BuildIconFacings(19);
    GDVars.elementMask := 0;
  end;
end;

{ Runs a lightning bolt from the aim cell straight away from the caster, attacking each creature cell it reaches; the
  callers attack the aim cell first. The bolt has twice boltLen in doubled distance units. Impassable terrain reflects
  it back; with bounce set, a first reflection within 8 units of the caster costs 8 more. A cell off the arena ends it.
  @param(boltLen The bolt's length in cells.)
  @param(damage The damage.)
  @param(saveType The saving throw.)
  @param(bounce True for the extra cost of a reflection near the caster.) }
procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean);
var
  req: Types.TPathReq;
  req2: Types.TPathReq;
  x0: ShortInt;
  y0: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  sign: ShortInt;
  blocked: Boolean;
  valid: Boolean;
  doBounce: Boolean;
  prevCr: Byte;
  crIdx: Byte;
  terr: Byte;
  budget: Byte;
begin
  CharHlp.BuildIconFacings(19);
  CbtMap.GetArenaContents(GDVars.targetX, GDVars.targetY, prevCr, terr);
  sign := 1;
  x0 := CbtMap.CombatCellX(GDVars.curChar);
  y0 := CbtMap.CombatCellY(GDVars.curChar);
  doBounce := bounce;
  if x0 = GDVars.targetX then
    if y0 = GDVars.targetY then
      Exit;
  budget := boltLen * 2;
  GDVars.multiTarget := 1;
  while budget > 0 do begin
    FillChar(req, SizeOf(req), 0);
    req.sx := GDVars.targetX;
    req.sy := GDVars.targetY;
    req.ex := GDVars.targetX + (GDVars.targetX - x0) * sign * budget;
    req.ey := GDVars.targetY + (GDVars.targetY - y0) * sign * budget;
    Pathing.PathFind(req);
    repeat
      prevX := req.cx;
      prevY := req.cy;
      if (req.sx <> req.ex) or (req.sy <> req.ey) then begin
        repeat
          valid := Pathing.NextPathStep(req);
          CbtMap.GetArenaContents(req.cx, req.cy, crIdx, terr);
        until (valid = False) or ((crIdx > 0) and (crIdx <> prevCr)) or (terr = 0) or
            (GDConsts.terrainInfo[terr].cost > 1) or (req.dist >= budget);
      end;
      prevCr := crIdx;
      if terr = 0 then
        budget := 0;
      CharHlp.CombatAnimateMovingIcon(prevX, prevY, req.cx, req.cy, 4, 50);
      Magic.LightningAttackAt(req.cx, req.cy, damage, saveType, blocked);
      if blocked then begin
        GDVars.targetX := req.cx;
        GDVars.targetY := req.cy;
        FillChar(req2, SizeOf(req2), 0);
        req2.sx := GDVars.targetX;
        req2.sy := GDVars.targetY;
        req2.ex := x0;
        req2.ey := y0;
        Pathing.PathFind(req2);
        while Pathing.NextPathStep(req2) do ;
        if doBounce then
          if req2.dist <= 8 then
            Inc(req.dist, 8);
        sign := 0 - sign;
        doBounce := False;
        prevCr := 0;
      end;
      if req.dist < budget then
        Dec(budget, req.dist)
      else
        budget := 0;
    until blocked or (budget = 0);
  end;
  GDVars.multiTarget := 0;
end;

{ Lightning Bolt: caster-level d6 damage at the aim cell, then a bouncing bolt of 8 cells. }
procedure SpellLightningBolt;
var
  dmg: Byte;
  blocked: Boolean;
begin
  dmg := FxEngine.RollDice(CharHlp.GetCasterLevel(GDVars.curSpell), 6);
  Magic.LightningAttackAt(GDVars.targetX, GDVars.targetY, dmg, C_Save.SPELL, blocked);
  Magic.LightningPath(8, dmg, C_Save.SPELL, True);
end;

{ Slow: the caster's enemies lose Hasted or are slowed (see HasteSlowLogic). }
procedure SpellSlow;
begin
  Magic.HasteSlowLogic(C_Effect.HASTED, CharHlp.EnemyTeam(GDVars.curChar), 'is Slowed');
end;

{ Restoration: give back one drained level. hpMax, hpCur and hpRolled regain drainedHps div drainedLevels. Scanning
  classes 0..7, a class becomes the pick when its level is not above the current pick's, its next-level XP is nonzero
  and smaller, and it is not at its level cap. The pick gains a level and experience is raised to its next-level XP if
  lower. }
procedure SpellRestoration;
var
  tgt: Types.PCharRecord;
  share: Byte;
  bestLvl: ShortInt;
  lvl: ShortInt;
  bestXp: LongInt;
  bestCls: ShortInt;
  cls: ShortInt;
begin
  tgt := GDVars.spellTargets[1];
  if tgt^.drainedLevels > 0 then begin
    share := tgt^.drainedHps div tgt^.drainedLevels;
    Inc(tgt^.hpMax, share);
    Inc(tgt^.hpCur, share);
    Inc(tgt^.hpRolled, share);
    Dec(tgt^.drainedHps, share);
    Dec(tgt^.drainedLevels);
    { 13: above any class level, so the first eligible class passes lvl <= bestLvl }
    bestLvl := 13;
    { sentinel above any table entry }
    bestXp := 10000000;
    { 7 is the last index of classLevels }
    for cls := 0 to 7 do begin
      lvl := tgt^.classLevels[cls];
      if (lvl > 0) and (lvl <= bestLvl) and (GDConsts.classXpTable[cls].xp[Succ(lvl)] > 0) and
          (GDConsts.classXpTable[cls].xp[Succ(lvl)] < bestXp) and
          (not CharHlp.AtLevelCap(tgt, cls)) then begin
        bestLvl := lvl;
        bestCls := cls;
        bestXp := GDConsts.classXpTable[cls].xp[Succ(lvl)];
      end;
    end;
    { Note: bestCls is uninitialized if no class qualified }
    Inc(tgt^.classLevels[bestCls]);
    if tgt^.experience < bestXp then
      tgt^.experience := bestXp;
    ClassCal.RecalcClassStats(tgt);
    CharHlp.PrintCreatureMessage(tgt, 'is restored', 10, True);
  end;
end;

{ Potion of Speed: remove Slowed, or else apply the potion's effect. }
procedure SpellPotionOfSpeed;
begin
  if not FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is Speedy');
end;

{ Keoghtom's Ointment: cure poison (also removing effect 22 silently), else cure disease, else heal 1d4 + 8 }
procedure SpellKeoghtomsOintment;
var
  { Unused in this version; see the other implementations of this routine. }
  removed: Byte;
begin
  { Note: removing the poison does not undo the DEAD_STATUS that poisoning set }
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.POISONED) then begin
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(GDVars.spellTargets[1], C_Effect.SLOW_POISON_END, nil);
    GDVars.effectLock := 0;
  end else if not Magic.RemoveDiseaseEffects then begin
    if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(1, 4) + 8, False) then
      CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'is Healed');
  end;
end;

{ Giant Strength: raise Strength to 21 and add the Strength effect, which keeps the Strength encoding
  AdjustForNewStrength returns. }
procedure SpellGiantStrength;
var
  enc: Byte;
begin
  if FxEngine.AdjustForNewStrength(GDVars.spellTargets[1], 21, 0, enc) then
    CharHlp.PrintCreatureMessage(GDVars.spellTargets[1], 'is stronger', 10, True);
  FxEngine.AddEffect(GDVars.spellTargets[1], C_Effect.STRENGTH,
                     Magic.CalcSpellDuration(GDVars.curSpell), enc, True);
end;

{ Javelin of Lightning: 1d6 + 20 damage at the aim cell, then a 3-cell bolt of 20 damage. }
procedure SpellJavelinOfLightning;
var
  blocked: Boolean;
begin
  Magic.LightningAttackAt(GDVars.targetX, GDVars.targetY, FxEngine.RollDice(1, 6) + 20, C_Save.SPELL, blocked);
  Magic.LightningPath(3, 20, C_Save.SPELL, False);
end;

{ Wand of Paralyzation: apply the item's effect. }
procedure SpellWandOfParalyzation;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is paralyzed');
end;

{ Potion of Healing: restore 2d4 + 2 hit points. }
procedure SpellPotionOfHealing;
begin
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'is Healed');
end;

{ Dust of Disappearance: apply the item's effect. }
procedure SpellDustOfDisappearance;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, 0, 0, 'is invisible');
end;

{ Wand of Magic Missiles: 2d4 + 2 damage, element mask 8. }
procedure SpellWandOfMagicMissiles;
begin
  Magic.ResolveSpell(GDVars.curSpell, 0, False, FxEngine.RollDamageDice(2, 4) + 2, 8, '');
end;

{ Unused item spell slot: does nothing. }
procedure SpellNoEffect;
begin
end;

{ Manual of Bodily Health: apply the item's effect at strength 255. }
procedure SpellManualOfBodilyHealth;
begin
  Magic.ResolveSpell(GDVars.curSpell, 255, True, 0, 0, 'is Reading');
end;

{ Breathes a bronze dragon's lightning, as the handler of its breath effect. After the first round it holds its breath
  half the time. Otherwise the cast-target handler picks an aim for Lightning Bolt with automatic targeting, and the aim
  becomes one step from the dragon toward it, plus one more step on each axis where that step is +1. A bolt of the
  dragon's maximum hit points of damage (save against breath) hits that cell and runs 10 cells. The charges are the
  effect's strength: 255 and 254 count down, anything lower removes the effect.
  @param(creature The dragon.)
  @param(p The breath effect's node.)
  @param(removed Unused.) }
procedure EffBreatheLightning(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  blocked: Boolean;
  x: ShortInt;
  y: ShortInt;
begin
  if GDVars.roundCounter <> 0 then
    if FxEngine.RollDice(1, 100) <= 50 then
      Exit;
  x := CbtMap.CombatCellX(creature);
  y := CbtMap.CombatCellY(creature);
  CharHlp.PrintCreatureMessage(creature, 'Breathes!', 10, True);
  GDVars.spellHandlers.castTargets(51, True, GDVars.breathAim);
  GDVars.targetX := x + Pathing.SignOf(GDVars.targetX - x);
  GDVars.targetY := y + Pathing.SignOf(GDVars.targetY - y);
  if GDVars.targetX = x + 1 then
    Inc(GDVars.targetX);
  if GDVars.targetY = y + 1 then
    Inc(GDVars.targetY);
  FxEngine.RemoveInvisibility(creature);
  CharHlp.BuildIconFacings(19);
  CharHlp.CombatAnimateMovingIcon(x, y, GDVars.targetX, GDVars.targetY, 4, 50);
  Magic.LightningAttackAt(GDVars.targetX, GDVars.targetY, creature^.hpMax, C_Save.BREATH_WEAPON, blocked);
  Magic.LightningPath(10, creature^.hpMax, C_Save.BREATH_WEAPON, False);
  { Remaining breath charges }
  if Types.PEffectRec(p)^.strength > 253 then
    Dec(Types.PEffectRec(p)^.strength)
  else
    FxEngine.RemoveEffect(creature, C_Effect.DRAGON_BREATH, p);
  blocked := CharHlp.EndActions(creature);
end;

function ItemReadable(it: Types.PItemRec): Boolean;
begin
  if (it <> nil) and (GDVars.baseItems[it^.itemType].slot > 10) and
      (GDVars.baseItems[it^.itemType].slot < 14) then
    ItemReadable := True
  else
    ItemReadable := False;
end;

procedure RemoveSpellFromScroll(cr: Types.PCharRecord; it: Types.PItemRec; spell: Byte);
var
  sp: Byte;
  i: Byte;
  found: Byte;
begin
  sp := spell and C_Spell.ID_MASK;
  found := 0;
  { 3 is the last index of TItemRec.spells }
  for i := 1 to 3 do
    if it^.spells[i] and C_Spell.ID_MASK = sp then
      found := i;
  if found = 0 then
    Exit;
  it^.spells[found] := 0;
  { scroll spell-count name component }
  Dec(it^.nameIds[2]);
  if it^.nameIds[2] < 210 then
    CharHlp.RemoveItem(cr, it);
end;

procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);
begin
  if GDVars.ifcState = C_Ifc.IN_COMBAT then begin
    CharHlp.PrintCreatureMessage(creature, 'Casts a Spell', 10, True);
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, 'Spell:' + GDConsts.spellNames[spell]);
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharHlp.DisplayCreatureName(creature, 1, 19, False);
    TextRend.DisplayString(Length(creature^.name) + 1 + 1, 19, LightGreen, msg);
    TextRend.DisplayString(1, 20, LightGreen, GDConsts.spellNames[spell]);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure InitSpellFns;
begin
  @GDVars.spellHandlers.castTargets := @Magic.NoncombatCastTargetMenu;
  GDVars.effectLock := 0;
  GDVars.usingItem := False;
  GDVars.castTarget := nil;
  GDVars.redrawInventory := 1;
  @GDVars.spellHandlers.spells[1] := @Magic.SpellBless;
  @GDVars.spellHandlers.spells[2] := @Magic.SpellCurse;
  @GDVars.spellHandlers.spells[3] := @Magic.SpellCureLightWounds;
  @GDVars.spellHandlers.spells[4] := @Magic.SpellCauseLightWounds;
  @GDVars.spellHandlers.spells[5] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[6] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[7] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[8] := @Magic.SpellResistCold;
  @GDVars.spellHandlers.spells[9] := @Magic.SpellBurningHands;
  @GDVars.spellHandlers.spells[10] := @Magic.SpellCharmPerson;
  @GDVars.spellHandlers.spells[11] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[12] := @Magic.SpellEnlarge;
  @GDVars.spellHandlers.spells[13] := @Magic.SpellReduce;
  @GDVars.spellHandlers.spells[14] := @Magic.SpellFriends;
  @GDVars.spellHandlers.spells[15] := @Magic.SpellMagicMissile;
  @GDVars.spellHandlers.spells[16] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[17] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[18] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[19] := @Magic.SpellShield;
  @GDVars.spellHandlers.spells[20] := @Magic.SpellShockingGrasp;
  @GDVars.spellHandlers.spells[21] := @Magic.SpellSleep;
  @GDVars.spellHandlers.spells[22] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[23] := @Magic.SpellHold;
  @GDVars.spellHandlers.spells[24] := @Magic.SpellResistFire;
  @GDVars.spellHandlers.spells[25] := @Magic.SpellSilence;
  @GDVars.spellHandlers.spells[26] := @Magic.SpellSlowPoison;
  @GDVars.spellHandlers.spells[27] := @Magic.SpellSnakeCharm;
  @GDVars.spellHandlers.spells[28] := @Magic.SpellSpiritualHammer;
  @GDVars.spellHandlers.spells[29] := @Magic.SpellDetection;
  @GDVars.spellHandlers.spells[30] := @Magic.SpellInvisibility;
  @GDVars.spellHandlers.spells[31] := @Magic.SpellKnock;
  @GDVars.spellHandlers.spells[32] := @Magic.SpellMirrorImage;
  @GDVars.spellHandlers.spells[33] := @Magic.SpellRayOfEnfeeblement;
  @GDVars.spellHandlers.spells[34] := @Magic.SpellStinkingCloud;
  @GDVars.spellHandlers.spells[35] := @Magic.SpellStrength;
  @GDVars.spellHandlers.spells[36] := @Magic.SpellAnimateDead;
  @GDVars.spellHandlers.spells[37] := @Magic.SpellCureBlindness;
  @GDVars.spellHandlers.spells[38] := @Magic.SpellCauseBlindness;
  @GDVars.spellHandlers.spells[39] := @Magic.SpellCureDisease;
  @GDVars.spellHandlers.spells[40] := @Magic.SpellCauseDisease;
  @GDVars.spellHandlers.spells[41] := @Magic.SpellDispelMagic;
  @GDVars.spellHandlers.spells[42] := @Magic.SpellPrayer;
  @GDVars.spellHandlers.spells[43] := @Magic.SpellRemoveCurse;
  @GDVars.spellHandlers.spells[44] := @Magic.SpellBestowCurse;
  @GDVars.spellHandlers.spells[45] := @Magic.SpellBlink;
  @GDVars.spellHandlers.spells[46] := @Magic.SpellDispelMagic;
  @GDVars.spellHandlers.spells[47] := @Magic.SpellFireball;
  @GDVars.spellHandlers.spells[48] := @Magic.SpellHaste;
  @GDVars.spellHandlers.spells[49] := @Magic.SpellHold;
  @GDVars.spellHandlers.spells[50] := @Magic.SpellInvisibility;
  @GDVars.spellHandlers.spells[51] := @Magic.SpellLightningBolt;
  @GDVars.spellHandlers.spells[52] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[53] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[54] := @Magic.SpellProtection;
  @GDVars.spellHandlers.spells[55] := @Magic.SpellSlow;
  @GDVars.spellHandlers.spells[56] := @Magic.SpellRestoration;
  @GDVars.spellHandlers.spells[57] := @Magic.SpellPotionOfSpeed;
  @GDVars.spellHandlers.spells[58] := @Magic.SpellKeoghtomsOintment;
  @GDVars.spellHandlers.spells[59] := @Magic.SpellGiantStrength;
  @GDVars.spellHandlers.spells[60] := @Magic.SpellJavelinOfLightning;
  @GDVars.spellHandlers.spells[61] := @Magic.SpellWandOfParalyzation;
  @GDVars.spellHandlers.spells[62] := @Magic.SpellPotionOfHealing;
  @GDVars.spellHandlers.spells[63] := @Magic.SpellDustOfDisappearance;
  @GDVars.spellHandlers.spells[64] := @Magic.SpellFireball;
  @GDVars.spellHandlers.spells[65] := @Magic.SpellWandOfMagicMissiles;
  @GDVars.spellHandlers.spells[66] := @Magic.SpellNoEffect;
  @GDVars.spellHandlers.spells[67] := @Magic.SpellManualOfBodilyHealth;
  GDVars.effectFns[88] := Magic.EffBreatheLightning;
end;

begin
end.
