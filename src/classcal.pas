{ Recalculate class skills, saving throws and thief abilities, including wisdom bonuses. }
{$O+,F+}
unit ClassCal;

interface

uses Types, GDConsts, GDVars, C_Class;

{ Recomputes a character's level-derived values. The THAC0 base (thac0Base) becomes the best of its classes at their
  levels and levelHighest rises to its highest class level. Attacks, kept doubled, become 3 for a fighter level above 6
  and 2 otherwise; the value is set for every character. A cleric level above 1 sets the cleric spell slots, adds the
  Wisdom bonus slots and marks known each cleric spell of a level with slots; a magic-user level above 1 sets the
  magic-user spell slots. It then recomputes the saving throws and, with thief levels, the thief skills.
  @param(creature The character to update.) }
procedure RecalcClassStats(creature: Types.PCharRecord);

{ Adds the Wisdom bonus cleric slots: Wisdom above 12 and above 13 each add a first-level slot, above 14 and above 15
  each a second-level slot and above 16 a third-level slot, each only to a spell level that already has slots.
  @param(creature The character to update.) }
procedure AwardWisdomBonus(creature: Types.PCharRecord);

{ Recomputes a character's five saving throws (saves). Each starts at 20 and takes the lowest table value of the classes
  it has levels in, at their levels.
  @param(creature The character to update.) }
procedure RecalcSaves(creature: Types.PCharRecord);

{ Recomputes a character's eight thief skills (thiefSkills) from the thief skill table at its thief level. Each skill
  takes the race adjustment, falling to 0 when a race penalty exceeds it, and skills 1 to 5 also take the Dexterity
  adjustment.
  @param(creature The character to update.) }
procedure RecalcThiefSkills(creature: Types.PCharRecord);

implementation

procedure RecalcClassStats(creature: Types.PCharRecord);
var
  i: ShortInt;
  k: ShortInt;
  lvl: ShortInt;
  m: Byte;
begin
  creature^.thac0Base := 0;
  { 7 is the last index of classLevels }
  for i := 0 to 7 do begin
    lvl := creature^.classLevels[i];
    if GDConsts.thac0Tbl[i, lvl] > creature^.thac0Base then
      creature^.thac0Base := GDConsts.thac0Tbl[i, lvl];
    if creature^.levelHighest < lvl then
      creature^.levelHighest := lvl;
    case i of
      C_Class.FIGHTER_LEVEL:
        if lvl > 6 then creature^.attacks := 3 else creature^.attacks := 2;
      C_Class.CLERIC_LEVEL:
        if lvl > 1 then begin
          { 3 is the last index of clericSpells }
          for k := 1 to 3 do
            creature^.clericSpells[k] := GDConsts.classXpTable[C_Class.CLERIC].slots[lvl, k];
          ClassCal.AwardWisdomBonus(creature);
          { Mark known every cleric spell (castClass 0) of a level with slots; 56 is the last index of spellsKnown. }
          for m := 1 to 56 do
            with GDConsts.spellTable[m] do
              if (castClass = 0) and (creature^.clericSpells[levelSp] > 0) then
                creature^.spellsKnown[m] := 1;
        end;
      C_Class.MAGE_LEVEL:
        if lvl > 1 then
          { 3 is the last index of mageSpells }
          for k := 1 to 3 do
            creature^.mageSpells[k] := GDConsts.classXpTable[C_Class.MAGE].slots[lvl, k];
    end;
  end;
  ClassCal.RecalcSaves(creature);
  if creature^.classLevels[C_Class.THIEF_LEVEL] > 0 then
    ClassCal.RecalcThiefSkills(creature);
end;

procedure AwardWisdomBonus(creature: Types.PCharRecord);
begin
  with creature^ do begin
    if (wisCur > 12) and (clericSpells[1] > 0) then Inc(clericSpells[1]);
    if (wisCur > 13) and (clericSpells[1] > 0) then Inc(clericSpells[1]);
    if (wisCur > 14) and (clericSpells[2] > 0) then Inc(clericSpells[2]);
    if (wisCur > 15) and (clericSpells[2] > 0) then Inc(clericSpells[2]);
    if (wisCur > 16) and (clericSpells[3] > 0) then Inc(clericSpells[3]);
  end;
end;

procedure RecalcSaves(creature: Types.PCharRecord);
var
  i: ShortInt;
  k: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  lvl: ShortInt;
begin
  { 4 is the last index of saves }
  for i := 0 to 4 do begin
    creature^.saves[i] := 20;
    { 7 is the last index of classLevels }
    for k := 0 to 7 do
      if creature^.classLevels[k] > 0 then
        if creature^.saves[i] > GDConsts.saveTbl[k, creature^.classLevels[k], i] then
          creature^.saves[i] := GDConsts.saveTbl[k, creature^.classLevels[k], i];
  end;
end;

procedure RecalcThiefSkills(creature: Types.PCharRecord);
var
  j: Byte;
begin
  with creature^ do
    { 8 is the last index of thiefSkills }
    for j := 1 to 8 do
      if (GDConsts.raceAdj[race, j] < 0) and
          (Abs(GDConsts.raceAdj[race, j]) > GDConsts.thiefBase[classLevels[C_Class.THIEF_LEVEL], j]) then
        thiefSkills[j] := 0
      else begin
        thiefSkills[j] := GDConsts.thiefBase[classLevels[C_Class.THIEF_LEVEL], j] + GDConsts.raceAdj[race, j];
        { dexAdj covers skills 1..5 only }
        if j < 6 then
          thiefSkills[j] := thiefSkills[j] + GDConsts.dexAdj[dexCur, j];
      end;
end;

begin
end.
