{ Menu input, animated menu pictures and linked lists of display strings. }
{$O+,F+}
unit MenuCore;

interface

uses Types, GDConsts, GDVars, Crt, GameIo, Blit, Border, Portrait, C_Keys, TextRend;

{ Finds a member of a list.
  @param(n The member's place, from 0.)
  @param(list The list.)
  @returns(The member, or nil when the list is shorter.) }
function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;

{ Shows a menu on the bottom row after a prompt, its digits and capital letters (the hotkeys) in hlCol, the current
  option (horizChoice, reset to 1 when out of range) wholly in hlCol and the rest in mCol, and waits for a key. Comma
  and period move the current option. A hotkey, which becomes the current option, or space ends the menu; Enter ends it
  when mCol or hlCol is nonzero; Escape returns #0. With reinterpret, an extended key returns its scan code, and digits
  1 to 9 and backslash map to keypad scan codes. While menuAutoAnswer has a timeout, its key is returned once that many
  ticks pass after the last frame change. The menu picture animates when animate is set or the zone's menu-animation
  flag is on; the flag also advances a frame every pass and is cleared on the way out. ext is copied to extFlag.
  @param(query The prompt.)
  @param(menu The menu.)
  @param(qCol The prompt's color.)
  @param(mCol The menu's color.)
  @param(hlCol The hotkeys' color.)
  @param(reinterpret True to accept extended keys and keypad digits as above.)
  @param(animate True to animate the menu picture while waiting.)
  @param(ext Receives True for an extended key or a keypad digit.)
  @returns(The key, upper-cased; #0 for Escape.) }
function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;

{ Blanks the bottom text row. }
procedure ClearBottomLine;

{ Runs a vertical list menu in a box, with the commands, Next, Prev and Exit as they apply on the bottom row. Entries
  are padded to the box's width; the highlight covers an entry's text without its surrounding blanks. Label entries
  (inUse set) are drawn in qCol and skipped by the cursor. Home and End move the cursor a line, wrapping within the page
  and kept inside the list, and Page Up and Page Down or Prev and Next move a page. The bottom-row menu starts on its
  first option.
  @param(query The prompt.)
  @param(menu The commands shown before Next, Prev and Exit.)
  @param(qCol The prompt's and the labels' color.)
  @param(mCol The entries' color.)
  @param(hlCol The highlight color.)
  @param(ulCol Left column of the box.)
  @param(ulRow Top row of the box.)
  @param(lrCol Right column of the box.)
  @param(lrRow Bottom row of the box.)
  @param(list The entries.)
  @param(addExit True to offer Exit.)
  @param(redraw True to draw the page; cleared once it is drawn.)
  @param(idx The highlighted entry, from 0, kept from one call to the next.)
  @param(sel Receives the highlighted entry; nil for an empty list, Exit or Escape.)
  @returns(The command key; #0 for an empty list, Exit or Escape.) }
function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;

{ Asks a yes-or-no question on the bottom row until Y or N is chosen. No is the current option to start with.
  @param(query The question.)
  @param(qCol The question's color.)
  @param(mCol The menu's color.)
  @param(hlCol The hotkeys' color.)
  @returns(Y or N.) }
function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;

{ Builds a list of empty menu entries; the first is allocated even when n is below 1. Each entry is allocated with only
  the name, inUse and next fields of TItemRec; the fields past next do not exist.
  @param(n The number of entries.)
  @param(list Receives the list.) }
procedure AllocStringList(n: Integer; var list: Types.PItemRec);

{ Frees each entry of a list built by AllocStringList. The caller's list pointer is left as it was, not set to nil.
  @param(list The list.) }
procedure FreeStringList(var list: Types.PItemRec);

implementation

type
  TOptRange = record
    first: Byte;
    last: Byte;
  end;

function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;
var
  p: Types.PItemRec;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> n) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = n then
    FindListMember := p
  else
    FindListMember := nil;
end;

{ Counts the members of a list.
  @param(list The list.)
  @returns(The number of members.) }
function ListCount(list: Types.PItemRec): Integer;
var
  p: Types.PItemRec;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;
var
  frameTick: LongInt;
  tick30: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  tick80: LongInt;
  ch: Char;
  j: Byte;
  i: Byte;
  done: Boolean;
  mLen: Byte;
  qLen: Byte;
  opt: array[1..20] of TOptRange;
  optCnt: Byte;
  enterOk: Boolean;

  { Splits the menu into options, each from a hotkey to two characters before the next one. }
  procedure ParseMenu(m: Types.TStr40);
  var
    idx: Byte;
    i: Byte;
    len: Byte;
    { Unused in this version; see the other implementations of this routine. }
    hotkey: Byte;
  begin
    FillChar(opt, SizeOf(opt), 0);
    idx := 1;
    len := Length(m);
    for i := 1 to len do
      if m[i] in ['0'..'9', 'A'..'Z'] then
        if opt[idx].first = 0 then
          opt[idx].first := i
        else begin
          opt[idx].last := i - 2;
          Inc(idx);
          opt[idx].first := i;
        end;
    opt[idx].last := len;
    optCnt := idx;
  end;

  { Draws the menu with option cur wholly in hlCol, the other hotkeys in hlCol and the rest in mCol. }
  procedure DisplayOption(cur: Byte);
  var
    i: Byte;
  begin
    if mLen > 0 then begin
      for i := 1 to mLen do
        if (opt[cur].first <= i) and (opt[cur].last >= i)
           and (hlCol <> 0) then
          TextRend.RenderChar(qLen + i - 1, 24, hlCol, 1, Ord(menu[i]), 1)
        else if menu[i] in ['0'..'9', 'A'..'Z'] then
          TextRend.RenderChar(qLen + i - 1, 24, hlCol, 1, Ord(menu[i]), 1)
        else
          TextRend.RenderChar(qLen + i - 1, 24, mCol, 1, Ord(menu[i]), 1);
      if qLen + mLen < 39 then
        TextRend.RenderChar(qLen + mLen, 24, Black, 39 - mLen - qLen + 1, 32, 1);
    end;
  end;

begin
  GDVars.extFlag := False;
  enterOk := (mCol <> 0) or (hlCol <> 0);
  ParseMenu(menu);
  if GDVars.horizChoice > optCnt then
    GDVars.horizChoice := 1;
  mLen := Length(menu);
  ch := #0;
  ext := False;
  done := False;
  frameTick := TextRend.GetTicks;
  tick30 := TextRend.GetTicks + 30;
  tick80 := tick30 + 50;
  if Length(query) <> 0 then
    TextRend.DisplayString(0, 24, qCol, query);
  qLen := Length(query) + 0;
  DisplayOption(GDVars.horizChoice);
  repeat
    if ((GDVars.zone0^.savedWalls.menuAnimation <> 0) or animate) and (GDVars.animData.current > 0) then begin
      Portrait.DisplayImageBuf(3, 3, animate, GDVars.animData.frames[GDVars.animData.current].pic);
      if (TextRend.GetTicks - frameTick >= GDVars.animData.frames[GDVars.animData.current].time * 10)
         or (GDVars.zone0^.savedWalls.menuAnimation <> 0) then begin
        Inc(GDVars.animData.current);
        if GDVars.animData.current > GDVars.animData.count then
          GDVars.animData.current := 1;
        frameTick := TextRend.GetTicks;
      end;
    end;
    if (GDVars.menuAutoAnswer.timeout > 0)
       and (TextRend.GetTicks - frameTick >= GDVars.menuAutoAnswer.timeout) then begin
      ch := GDVars.menuAutoAnswer.key;
      done := True;
    end else if KeyPressed then begin
      ch := GameIo.ReadGameKey;
      if ch = #0 then
      { #0 prefixes an extended key: the second ReadGameKey reads its scan code. It ends the menu (with ext set) only
        with reinterpret; otherwise it is ignored. }
      begin
        ch := GameIo.ReadGameKey;
        if reinterpret then begin
          ext := True;
          done := True;
        end;
      end else
        case ch of
          { Escape returns #0. }
          C_Keys.ESCAPE: begin
                 done := True;
                 ch := C_Keys.NONE;
               end;
          C_Keys.ENTER: if enterOk then begin
                 ch := C_Keys.ENTER;
                 done := True;
               end;
          ',': begin
                 if GDVars.horizChoice = 1 then
                   GDVars.horizChoice := optCnt
                 else
                   Dec(GDVars.horizChoice);
                 DisplayOption(GDVars.horizChoice);
               end;
          '.': begin
                 if GDVars.horizChoice = optCnt then
                   GDVars.horizChoice := 1
                 else
                   Inc(GDVars.horizChoice);
                 DisplayOption(GDVars.horizChoice);
               end;
        else begin
            ch := UpCase(ch);
            if ch in [' ', '0'..'9', 'A'..'Z'] then
              if ch = ' ' then
                done := True
              else
                for i := 1 to mLen do
                  if menu[i] = ch then begin
                    done := True;
                    j := 1;
                    while opt[j].first <> i do
                      Inc(j);
                    GDVars.horizChoice := j;
                    DisplayOption(GDVars.horizChoice);
                  end;
            if reinterpret then
              if ch in ['1'..'9', '\'] then
              begin
                if ch = '\' then
                  { keypad-'*' scan code, not ASCII '7' }
                  ch := #55
                else
                  ch := Char(GDConsts.keypadScan[Ord(ch) - Ord('1')]);
                ext := True;
                done := True;
              end;
          end;
        end;
    end;
  until done;
  GDVars.zone0^.savedWalls.menuAnimation := 0;
  MenuHorizontal := ch;
  GDVars.extFlag := ext;
end;

procedure ClearBottomLine;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
end;

function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;
var
  width: Byte;
  count: Integer;
  ext: Boolean;
  rows: Integer;
  ch: Char;
  hMenu: Types.TStr40;
  hasNext: Boolean;
  hasPrev: Boolean;
  p: Types.PItemRec;
  headerCnt: Integer;
  total: Integer;

  { Finds the last label among the first n members, or the first member when it is a label and n is 0. }
  function LastLabelBefore(n: Integer; l: Types.PItemRec): Types.PItemRec;
  var
    pp: Types.PItemRec;
    found: Types.PItemRec;
    i: Integer;
  begin
    i := 0;
    pp := l;
    found := nil;
    while (pp <> nil) and (i < n) do begin
      if pp^.inUse <> 0 then
        found := pp;
      pp := pp^.next;
      Inc(i);
    end;
    if (found = nil) and (l^.inUse <> 0) then
      LastLabelBefore := l
    else
      LastLabelBefore := found;
  end;

  { Clear the box and draw the list from member top, labels in qCol and entries in mCol, each padded to the box width. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    q: Types.PItemRec;
    row: ShortInt;
  begin
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    pp := MenuCore.FindListMember(top, list);
    q := LastLabelBefore(top, list);
    row := ulRow;
    while (pp <> nil) and (row <= lrRow) do begin
      if pp^.inUse <> 0 then
        TextRend.DisplayString(ulCol, row, qCol, pp^.name)
      else
        TextRend.DisplayString(ulCol, row, mCol, pp^.name);
      if Length(pp^.name) < width then
        TextRend.RenderChar(ulCol + Length(pp^.name), row, Black, width - Length(pp^.name), 32, 1);
      pp := pp^.next;
      Inc(row);
    end;
  end;

  { Position of the first non-blank character of s (the last position when s is all blanks). }
  function FirstNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { Position of the last non-blank character of s (1 when s is all blanks). }
  function LastNonBlank(s: Types.TStr40): Byte;
  var
    n: Byte;
  begin
    n := Length(s);
    while (n > 1) and (s[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Redraw the text of member n, without its surrounding blanks, in hlCol. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), hlCol, Copy(pp^.name, a, b));
  end;

  { Redraw the text of member n, without its surrounding blanks, in its normal color. }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    if pp^.inUse <> 0 then
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), qCol, Copy(pp^.name, a, b))
    else
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), mCol, Copy(pp^.name, a, b));
  end;

  { Move idx off label rows in the given direction, wrapping within the visible page; gives up after a page of rows. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Inc(idx);
        if GDVars.vertTop + rows - 1 < idx then
          idx := GDVars.vertTop;
        if count - 1 < idx then
          idx := GDVars.vertTop;
      end;
    end else
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Dec(idx);
        if idx < GDVars.vertTop then
          idx := GDVars.vertTop + rows - 1;
        if count - 1 < idx then
          idx := count - 1;
      end;
  end;

  { Scroll a page down or up, clamped to the list, keep the cursor's row on the page and redraw it. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := idx - GDVars.vertTop;
    if down then begin
      Inc(GDVars.vertTop, rows);
      if count - rows < GDVars.vertTop then
        GDVars.vertTop := count - rows;
    end else begin
      Dec(GDVars.vertTop, rows);
      if GDVars.vertTop < 0 then
        GDVars.vertTop := 0;
    end;
    idx := GDVars.vertTop + rel;
    SkipLabels(down);
    DrawPage(GDVars.vertTop);
  end;

  { Move the cursor one line, wrapping within the visible page and clamped to the list, then skip label rows. }
  procedure MoveLine(down: Boolean);
  var
    { Unused in this version; see the other implementations of this routine. }
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    k: Integer;
    { Unused in this version; see the other implementations of this routine. }
    n: Integer;
  begin
    if down then begin
      Inc(idx);
      if GDVars.vertTop + rows - 1 < idx then
        idx := GDVars.vertTop;
      if count - 1 < idx then
        idx := GDVars.vertTop;
    end else begin
      Dec(idx);
      if idx < GDVars.vertTop then
        idx := GDVars.vertTop + rows - 1;
      if count - 1 < idx then
        idx := count - 1;
    end;
    SkipLabels(down);
  end;

begin
  if list = nil then begin
    idx := 0;
    sel := nil;
    MenuVertical := C_Keys.NONE;
  end else begin
    GDVars.horizChoice := 1;
    width := lrCol - ulCol + 1;
    count := MenuCore.ListCount(list);
    rows := lrRow - ulRow + 1;
    p := list;
    headerCnt := 0;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(headerCnt);
    end;
    p := list;
    total := 0;
    while p <> nil do begin
      p := p^.next;
      Inc(total);
    end;
    if GDVars.vertTop > idx then begin
      GDVars.vertTop := idx;
      redraw := True;
    end;
    if GDVars.vertTop > total then begin
      GDVars.vertTop := 0;
      redraw := True;
    end;
    Inc(idx);
    MoveLine(False);
    if redraw then
      DrawPage(GDVars.vertTop);
    redraw := False;
    repeat
      HighlightLine(idx);
      hMenu := menu;
      hasNext := False;
      hasPrev := False;
      if count - rows > GDVars.vertTop then begin
        hMenu := hMenu + ' Next';
        hasNext := True;
      end;
      if GDVars.vertTop > headerCnt then begin
        hMenu := hMenu + ' Prev';
        hasPrev := True;
      end;
      if addExit then
        hMenu := hMenu + ' Exit';
      ch := MenuCore.MenuHorizontal(query, hMenu, qCol, mCol, hlCol, True, False, ext);
      UnhighlightLine(idx);
      if ext then
        case ch of
          { Home = line up }
          C_Keys.HOME: MoveLine(False);
          { End = line down }
          C_Keys.END_KEY: MoveLine(True);
          { Page Up = previous page, when Prev is offered }
          C_Keys.PAGE_UP: if hasPrev then MovePage(False);
          { Page Down = next page, when Next is offered }
          C_Keys.PAGE_DOWN: if hasNext then MovePage(True);
        end else
        case ch of
          'P': MovePage(False);
          'N': MovePage(True);
          C_Keys.ESCAPE, 'E', C_Keys.NONE:
            begin
              sel := nil;
              MenuVertical := C_Keys.NONE;
              Exit;
            end;
        else begin
            sel := MenuCore.FindListMember(idx, list);
            MenuVertical := ch;
            Exit;
          end;
        end;
    until False;
  end;
end;

function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;
var
  ext: Boolean;
  ch: Char;
begin
  { default the highlight to "No" }
  GDVars.horizChoice := 2;
  repeat
    ch := MenuCore.MenuHorizontal(query, 'Yes No', qCol, mCol, hlCol, False, False, ext);
  until ch in ['Y', 'N'];
  YesNoMenu := ch;
end;

procedure AllocStringList(n: Integer; var list: Types.PItemRec);
var
  p: Types.PItemRec;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TMenuNode));
  list^.next := nil;
  list^.inUse := 0;
  list^.name := '';
  p := list;
  for i := 2 to n do begin
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
    p^.next := nil;
    p^.inUse := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var list: Types.PItemRec);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  p := list;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TMenuNode));
  end;
end;

begin
end.
