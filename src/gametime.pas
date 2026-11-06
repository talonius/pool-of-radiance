{ Resting, spell preparation and game-clock advancement, including expiration of timed effects. }
{$O+,F+}
unit GameTime;

interface

uses Types, C_Time, C_Msg, GDConsts, GDVars, Crt, TextRend, CharHlp, MenuCore, Magic, FxEngine, C_Keys, C_Ifc, C_Gbvm,
  C_Spell;

{ Empty routine with no callers. }
procedure NoopRest;

{ Advances the game clock one unit at a time, carrying each component into the next, then ages the party's timed effects
  by the same span.
  @param(amount Number of units.)
  @param(tUnit Clock component counted: 1 minutes, 2 tens of minutes, 3 hours, 4 days, 5 months, 6 years.) }
procedure AdvanceTime(amount: Byte; tUnit: ShortInt);

{ Lets the player set the rest time (CampRestMenu), then rests in five-minute ticks, advancing the clock, healing and
  spell preparation, until the rest time runs out. A keypress offers to stop. While the area sets a safe-rest period,
  each time it runs out the rest can be interrupted at the area's chance.
  @returns(True when the rest was interrupted.) }
function CampRest: Boolean;

implementation

const
  { Script-visible game-memory address of the 7-word clock block: segment, minute, turn, hour, day, month, year }
  GBVM_CLOCK = $49C6;

  { Game-clock components (TClock indices) }
  TIME_DAY = 4;
  TIME_MONTH = 5;
  TIME_YEAR = 6;

{ Ages the timed effects of the party by a span of time, in steps of at most ten minutes; an effect whose time runs out
  is removed, and one with no duration never runs out. A flag per member marks the members that still have timed
  effects. Outside camp every member is aged; in camp only flagged members are, and nothing happens when none is
  flagged. Note: when the effect that runs out is second in a list, aging resumes at the first effect, which is aged
  again.
  @param(count Number of units.)
  @param(tUnit Clock component counted.) }
procedure TimeOutEffects(count: Byte; tUnit: ShortInt);
var
  u: ShortInt;
  i: Byte;
  step: Byte;
  total: Word;
  cur: Types.PCharRecord;
  done: Boolean;
  found: Boolean;
  tail: Types.PEffectRec;
  prev: Types.PEffectRec;
  e: Types.PEffectRec;
begin
  if GDVars.ifcState <> C_Ifc.CAMPING then
    FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1)
  else begin
    found := False;
    i := 1;
    repeat
      if GDVars.effFlags[i] <> 0 then found := True;
      Inc(i);
    until found or (i > GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
    if not found then Exit;
  end;
  total := count;
  u := tUnit;
  while u > 1 do begin
    total := GDConsts.unitScale[Pred(u)] * total;
    u := Pred(u);
  end;
  while total > 0 do begin
    if total > 10 then step := 10 else step := total;
    i := 1;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if GDVars.effFlags[i] <> 0 then begin
        GDVars.effFlags[i] := 0;
        e := Types.PEffectRec(cur^.effectsAddr);
        tail := Types.PEffectRec(cur^.effectsAddr);
        prev := Types.PEffectRec(cur^.effectsAddr);
        if cur^.effectsAddr <> nil then
          while tail^.next <> nil do tail := tail^.next;
        done := False;
        while (e <> nil) and not done do begin
          if e = tail then done := True;
          if e^.duration = 0 then
            e := e^.next
          else if step < e^.duration then begin
            Dec(e^.duration, step);
            GDVars.effFlags[i] := 1;
            e := e^.next;
          end else begin
            FxEngine.RemoveEffect(cur, e^.id, e);
            { prev is the list head when the removed effect was the head's successor; the walk then restarts at the
              head, which is aged again in this step }
            if prev = Types.PEffectRec(cur^.effectsAddr) then
              e := Types.PEffectRec(cur^.effectsAddr)
            else
              e := prev^.next;
          end;
          prev := Types.PEffectRec(cur^.effectsAddr);
          while (prev <> nil) and (prev <> e) and (prev^.next <> e) do
            prev := prev^.next;
        end;
        while e <> nil do begin
          if e^.duration > 0 then GDVars.effFlags[i] := 1;
          e := e^.next;
        end;
      end;
      Inc(i);
      cur := cur^.nextCharAddr;
    end;
    if total > 10 then Dec(total, 10) else total := 0;
  end;
end;

{ Carries each clock component that has reached its limit into the next one, once per component. A year component at its
  limit is left as it is, and each party member ages by a year instead.
  @param(clock The clock to normalize.) }
procedure ValidateClock(var clock: Types.TClock);
var
  i: ShortInt;
  cur: Types.PCharRecord;
begin
  for i := 0 to 6 do
    if clock[i] >= GDConsts.unitScale[i] then
      if i <> GameTime.TIME_YEAR then begin
        Inc(clock[Succ(i)]);
        clock[i] := clock[i] - GDConsts.unitScale[i];
      end else begin
        cur := GDVars.creatureList;
        while cur <> nil do begin
          Inc(cur^.age);
          cur := cur^.nextCharAddr;
        end;
      end;
end;

{ Normalizes the rest time: carries its components and folds any months into days, 30 to a month, capping the days at
  99. }
procedure ValidateRestTime;
begin
  GameTime.ValidateClock(GDVars.restRemaining);
  if GDVars.restRemaining[GameTime.TIME_MONTH] > 0 then begin
    Inc(GDVars.restRemaining[GameTime.TIME_DAY],
        GDConsts.unitScale[GameTime.TIME_DAY] * GDVars.restRemaining[GameTime.TIME_MONTH]);
    GDVars.restRemaining[GameTime.TIME_MONTH] := 0;
    if GDVars.restRemaining[GameTime.TIME_DAY] > 99 then GDVars.restRemaining[GameTime.TIME_DAY] := 99;
  end;
end;

procedure AdvanceTime(amount: Byte; tUnit: ShortInt);
var
  clock: Types.TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := 0 to 6 do
    clock[i] := GDVars.zone0^.words[GameTime.GBVM_CLOCK + i];
  for j := 1 to amount do begin
    Inc(clock[tUnit]);
    GameTime.ValidateClock(clock);
  end;
  for i := 0 to 6 do
    GDVars.zone0^.words[GameTime.GBVM_CLOCK + i] := clock[i];
  GameTime.TimeOutEffects(amount, tUnit);
end;

{ Takes a span off the rest time, borrowing from the larger components as needed; when there is nothing left to borrow,
  the rest time is cleared. Nothing happens when no days, hours or minutes are left.
  @param(count Number of units.)
  @param(tUnit Clock component counted.) }
procedure DecrementRestTime(count: Byte; tUnit: ShortInt);
var
  j: ShortInt;
  k: ShortInt;
begin
  if (GDVars.restRemaining[GameTime.TIME_DAY] <> 0) or (GDVars.restRemaining[C_Time.HOURS] <> 0) or
      (GDVars.restRemaining[C_Time.TURNS] <> 0) or (GDVars.restRemaining[C_Time.MINUTES] <> 0)
  then begin
    while count > GDVars.restRemaining[tUnit] do begin
      j := Succ(tUnit);
      while (GDVars.restRemaining[j] = 0) and (j < GameTime.TIME_MONTH) do
        j := Succ(j);
      if j = GameTime.TIME_MONTH then begin
        FillChar(GDVars.restRemaining, SizeOf(GDVars.restRemaining), 0);
        count := 0;
      end else
        for k := j downto Succ(tUnit) do begin
          Dec(GDVars.restRemaining[k]);
          Inc(GDVars.restRemaining[Pred(k)], GDConsts.unitScale[Pred(k)]);
        end;
    end;
    Dec(GDVars.restRemaining[tUnit], count);
    GameTime.ValidateRestTime;
  end;
end;

{ Formats a number with at least two digits, keeping the first two.
  @param(v The number.)
  @returns(The digits, with a leading zero below 10.) }
function TwoDigitStr(v: Byte): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := CharHlp.ByteToString(v);
  if v < 10 then s := '0' + s;
  TwoDigitStr := Copy(s, 1, 2);
end;

{ Shows the rest time as days, hours and minutes on the message line, the selected field in white.
  @param(hl Clock component shown in white: 2 minutes, 3 hours, 4 days; 0 for none.) }
procedure DisplayRestTime(hl: ShortInt);
var
  i: ShortInt;
  colors: array[0..6] of Word;
  x: Byte;
begin
  for i := 0 to 6 do
    colors[i] := LightGreen;
  colors[hl] := White;
  TextRend.DisplayString(1, 17, LightGreen, 'Rest Time:');
  x := 11;
  for i := GameTime.TIME_DAY downto C_Time.HOURS do begin
    TextRend.DisplayString(x + 1, 17, colors[i], GameTime.TwoDigitStr(GDVars.restRemaining[i]));
    TextRend.DisplayString(x + 1 + 2, 17, LightGreen, ':');
    Inc(x, 3);
  end;
  TextRend.DisplayString(x + 1, 17, colors[C_Time.TURNS],
                         GameTime.TwoDigitStr(10 * GDVars.restRemaining[C_Time.TURNS] +
                           GDVars.restRemaining[C_Time.MINUTES]));
end;

{ Runs the rest-time menu. The up and down arrows (Inc, Dec) change the highlighted component, the minutes in steps of
  5, and the left and right arrows move the highlight; Enter is Rest.
  @returns(True when the player chose Rest.) }
function CampRestMenu: Boolean;
var
  ext: Boolean;
  ch: Char;
  sel: ShortInt;
begin
  CampRestMenu := False;
  sel := C_Time.TURNS;
  repeat
    GameTime.DisplayRestTime(sel);
    ch := MenuCore.MenuHorizontal('', 'Rest   daYs Hours Mins   Inc Dec   Exit', LightMagenta, LightGreen,
                                  White, True, False, ext);
    if ext then
      case ch of
        { up arrow: Inc }
        C_Keys.UP: ch := 'I';
        { down arrow: Dec }
        C_Keys.DOWN: ch := 'D';
        C_Keys.LEFT: begin
                    Inc(sel);
                    if sel > GameTime.TIME_DAY then sel := C_Time.TURNS;
                    ch := #88;
                  end;
        C_Keys.RIGHT: begin
                     Dec(sel);
                     if sel < C_Time.TURNS then sel := GameTime.TIME_DAY;
                     ch := #88;
                   end;
      else
        ch := #88;
      end;
    if ch = C_Keys.ENTER then ch := 'R';
    case ch of
      'R': CampRestMenu := True;
      'Y': sel := GameTime.TIME_DAY;
      'H': sel := C_Time.HOURS;
      'M': sel := C_Time.TURNS;
      'I': begin
             if sel = C_Time.TURNS then
               Inc(GDVars.restRemaining[C_Time.MINUTES], 5)
             else
               Inc(GDVars.restRemaining[sel]);
             GameTime.ValidateRestTime;
           end;
      'D': begin
             if sel = C_Time.TURNS then
               GameTime.DecrementRestTime(5, C_Time.MINUTES)
             else
               GameTime.DecrementRestTime(1, sel);
             GameTime.ValidateRestTime;
           end;
    end;
  until ch in [C_Keys.NONE, 'E', 'R'];
end;

{ Counts a rest tick and, every 288 ticks (a day of five-minute ticks), restores a hit point to each party member and
  says the party is healed; the party is redrawn only when someone healed. }
procedure CheckRestingHeal;
var
  healed: Boolean;
  cur: Types.PCharRecord;
begin
  Inc(GDVars.healTicks);
  if GDVars.healTicks >= 288 then begin
    healed := False;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if FxEngine.RestoreHitPoints(cur, 1, False) then healed := True;
      cur := cur^.nextCharAddr;
    end;
    GameTime.DisplayRestTime(0);
    TextRend.DisplayString(1, 19, LightGreen, 'The Whole Party Is Healed');
    if healed then CharHlp.DisplayParty(GDVars.curChar);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    GDVars.healTicks := 0;
  end;
end;

{ Scans a character's memorized-spell slots for spells still being memorized. Unless the finished flag is already set,
  the first such spell is finished and announced, and the flag is set; the scan then goes on to the next one.
  @param(creature The character.)
  @param(done The finished flag: True to only look up the next pending spell; set when a spell is finished.)
  @returns(The level of the next spell still pending, or 0 when there is none.) }
function CheckMemorizeDone(creature: Types.PCharRecord; var done: Boolean): Byte;
var
  lvl: Byte;
  i: Byte;
begin
  lvl := 0;
  i := 0;
  { 20 is the last index of memorizedSpells }
  while (i <= 20) and (lvl = 0) do begin
    if creature^.memorizedSpells[i] > $7F then
      if done then
        lvl := GDConsts.spellTable[creature^.memorizedSpells[i] and C_Spell.ID_MASK].level
      else begin
        Dec(creature^.memorizedSpells[i], C_Spell.PENDING_FLAG);
        GameTime.DisplayRestTime(0);
        Magic.PrintCastSpellMsg(creature, 'has memorized', creature^.memorizedSpells[i]);
        done := True;
      end;
    Inc(i);
  end;
  CheckMemorizeDone := lvl;
end;

{ Does for scribing what CheckMemorizeDone does for memorizing, over the spells queued for scribing on the character's
  readable scrolls. Finishing one marks the spell known, removes it from the scroll and announces it. Note: removing the
  spell may free the scroll while the scan goes on reading it.
  @param(creature The character.)
  @param(done True to only look up the next pending spell; set when a spell is finished.)
  @returns(The level of the next spell still pending, or 0 when there is none.) }
function CheckScribeDone(creature: Types.PCharRecord; var done: Boolean): Byte;
var
  j: Byte;
  sp: Byte;
  lvl: Byte;
  item: Types.PItemRec;
begin
  lvl := 0;
  item := creature^.itemsAddr;
  while (item <> nil) and (lvl = 0) do begin
    j := 1;
    if Magic.ItemReadable(item) then
      { 3 is the last index of TItemRec.spells }
      while (j <= 3) and (lvl = 0) do begin
        if item^.spells[j] > $80 then
          if done then
            lvl := GDConsts.spellTable[item^.spells[j] and C_Spell.ID_MASK].level
          else begin
            sp := item^.spells[j] and C_Spell.ID_MASK;
            creature^.spellsKnown[sp] := 1;
            Magic.RemoveSpellFromScroll(creature, item, sp);
            GameTime.DisplayRestTime(0);
            Magic.PrintCastSpellMsg(creature, 'has scribed', sp);
            done := True;
          end;
        Inc(j);
      end;
    item := item^.next;
  end;
  CheckScribeDone := lvl;
end;

{ Counts each party member's preparation timer down a rest tick (a zero timer wraps to 255). When it reaches zero after
  the member's preparation delay has run out, the pending scribing or memorizing is finished and the timer reloaded with
  3 ticks per level of the next pending spell. }
procedure AdvanceSpellPrep;
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCharRecord;
  done: Boolean;
begin
  i := 1;
  cur := GDVars.creatureList;
  while cur <> nil do begin
    Dec(GDVars.prepTimers[i]);
    if (GDVars.prepTimers[i] = 0) and (cur^.spellPrepTime = 0) then begin
      done := False;
      lvl := GameTime.CheckScribeDone(cur, done);
      if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
      GDVars.prepTimers[i] := lvl * 3;
    end;
    cur := cur^.nextCharAddr;
    Inc(i);
  end;
end;

{ Counts rest steps; every twelfth step, each party member's preparation wait drops by one, and when it reaches zero the
  member's spell-preparation timer starts at three times the level of the next spell to scribe or memorize.
  @param(tick The step counter, kept by the caller.) }
procedure AdvanceSpellPrepBase(var tick: Byte);
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCharRecord;
  done: Boolean;
begin
  Inc(tick);
  if tick >= 12 then begin
    tick := 0;
    i := 1;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if ShortInt(cur^.spellPrepTime) > 0 then begin
        Dec(cur^.spellPrepTime);
        if cur^.spellPrepTime = 0 then begin
          done := True;
          lvl := GameTime.CheckScribeDone(cur, done);
          if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
          GDVars.prepTimers[i] := lvl * 3;
        end;
      end;
      cur := cur^.nextCharAddr;
      Inc(i);
    end;
  end;
end;

function CampRest: Boolean;
var
  cur: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  member: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  memberCount: Byte;
  i: Byte;
  tick: Byte;
  cnt: Byte;
  stop: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  interrupted: Boolean;
begin
  CampRest := False;
  interrupted := False;
  i := 1;
  cur := GDVars.creatureList;
  while cur <> nil do begin
    GDVars.prepTimers[i] := 0;
    Inc(i);
    cur := cur^.nextCharAddr;
  end;
  FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1);
  tick := 0;
  cnt := 0;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  GameTime.DisplayRestTime(0);
  GDVars.suppressBorder := 1;
  stop := not GameTime.CampRestMenu;
  while (not stop) and
      ((GDVars.restRemaining[GameTime.TIME_DAY] > 0) or (GDVars.restRemaining[C_Time.HOURS] > 0) or
       (GDVars.restRemaining[C_Time.TURNS] > 0) or (GDVars.restRemaining[C_Time.MINUTES] > 0))
  do begin
    if KeyPressed then begin
      GameTime.DisplayRestTime(0);
      if MenuCore.YesNoMenu('Stop Resting? ', LightMagenta, LightGreen, White) = 'Y' then
        stop := True
      else
        MenuCore.ClearBottomLine;
    end;
    if not stop then begin
      GameTime.DecrementRestTime(5, C_Time.MINUTES);
      Inc(cnt);
      if cnt >= 5 then begin
        GameTime.DisplayRestTime(0);
        cnt := 0;
      end;
      GameTime.AdvanceTime(5, C_Time.MINUTES);
      GameTime.CheckRestingHeal;
      GameTime.AdvanceSpellPrep;
      GameTime.AdvanceSpellPrepBase(tick);
      { When the area sets a safe-rest period, roll for an interruption each time it runs out }
      if GDVars.zone1^[C_Gbvm.REST_SAFE_TIME] > 0 then begin
        Inc(GDVars.restTicks);
        if GDVars.restTicks >= GDVars.zone1^[C_Gbvm.REST_SAFE_TIME] then begin
          GDVars.restTicks := 0;
          if FxEngine.RollDice(1, 100) <= GDVars.zone1^[C_Gbvm.REST_INTERRUPT_PERCENT] then begin
            CharHlp.ClearMessageWindow;
            GameTime.DisplayRestTime(0);
            TextRend.DisplayString(1, 19, White, 'The Party is rudely interrupted!');
            stop := True;
            CampRest := True;
            TextRend.PauseOnly;
          end;
        end;
      end;
    end;
  end;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  GDVars.suppressBorder := 0;
end;

procedure NoopRest;
begin
end;

begin
end.
