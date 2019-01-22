unit mapScan;

interface
uses
//  Windows,
  SysUtils, Classes;
type
  TAddr = NativeUInt;
  PMapInfo = ^TMapInfo;
  TMapInfo = record
    VA,
    RVA: TAddr;
    IsProc: Boolean;
    IdxUnitInfo: NativeInt;
    line: NativeInt;
    case Boolean of
      false: (ParentProc: PMapInfo);
      true: (IdxProcInfo: NativeInt);
  end;

  PMapFile = ^TMapFile;
  TMapFile = record
    Base,
    BaseLen: TAddr;
    Position,
    SegmentName,
    Segment,
    endFile: PAnsiChar;
  end;

  TMapList = array of PMapInfo;
  TMapBuf = array of TMapINfo;


  TMapScanner = class
  private
    FFileName: string;
    FList: TMapList;
    FBufMap: TMapBuf;
    FIndexBufMap: Integer;
    FStrInfos: TStrings;
    FBase: NativeUInt;
    FAvailable: Boolean;
    FExeName: string;

    // возвращает адрес структуры, новый елемент
    function GetNewMapInfo: PMapInfo;
    // возваращает указатель на нультерминированную строку  в документе заканчивающуеся на SlIneBreak;
    function GetNextLine(MapFile: PMapFile): PAnsiChar;

//    function GetVA(P

    // следующие функци парсят секции в файле
    // отработка базового адреса и секций кода
    function ParseBase(MapFile: PMapFile): Boolean;
    function ParseDetailed(MapFile: PMapFile): Boolean;
    function ParsePublicName(MapFile: PMapFile): Boolean;
    function ParsePublisValue(MapFile: PMapFile; L: TList): Boolean;
    function ParseLineInfo(MapFile: PMapFile; var Index: Integer): Boolean;
    function ParseLineNumber(MapFile: PMapFile; IndexUnit: Integer; L: TLIst): Boolean;

    // возвращает виртуальный адрес
    function GetVA(mapfile: PMapFile; var P: PAnsiChar; out VA: TAddr): Boolean;


    procedure MergeAddr(LL, LV: TList);
    // if search VA  then RVA must be 0
    // if search RVA then VA must be 0

    function SearchMapInfoVA(VA: TAddr): PMapInfo;
    function SearchMapInfoRVA(RVA: TAddr): PMapInfo;

    procedure Clear;
  public
    function FindMapInfo(VA, RVA: TAddr; out Info: PMapInfo): Boolean;

    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    function GetAddrStrInfo(Addr: TAddr): string;
    property Available: Boolean read FAvailable;
  end;

  function LogStackTrace(AReturnAddresses: PNativeUInt; AMaxDepth: Cardinal): string;
  function GetMapScanner: TMapScanner;
implementation
uses
  System.IOUtils;


var
  map: TMapScanner;

function GetMapScanner: TMapScanner;
begin
  if not Assigned(map) then
    begin
      map := TMapScanner.Create;
      map.LoadFromFile(ChangeFileExt(ParamStr(0), '.map'));
    end;
  Result := map;
end;

function LogStackTrace(AReturnAddresses: PNativeUInt; AMaxDepth: Cardinal): string;
var
  List: TStrings;
  s: string;
begin
  if not Assigned(map) then  GetMapScanner;
  List := TStringList.Create;
  try
    while (AMaxDepth > 0) and (AReturnAddresses^ <> 0) do
      begin
        s := map.GetAddrStrInfo(AReturnAddresses^);
        if s <> '' then
          List.Add(map.GetAddrStrInfo(AReturnAddresses^));
        Inc(AReturnAddresses);
        Dec(AMaxDepth);
      end;
    Result := List.Text;
  finally
    List.Free;
  end;
end;

{ TMapScanner }

procedure TMapScanner.Clear;
begin
  FAvailable := false;
  SetLength(FList, 0);
  SetLength(FBufMap, 0);
  FIndexBufMap := 0;
  if Assigned(FStrInfos) then
  FStrInfos.Clear;
  FBase := 0;
  FFileName := '';
end;

destructor TMapScanner.Destroy;
begin
  Clear;
  FStrInfos.Free;
  inherited;
end;

function TMapScanner.FindMapInfo(VA, RVA: TAddr; out Info: PMapInfo): Boolean;
begin
  if VA <> 0 then
    info := SearchMapInfoVA(VA)
  else if RVA <> 0 then
    info := SearchMapInfoRVA(RVA)
  else info := nil;
  Result := info <> nil;
end;

function TMapScanner.GetAddrStrInfo(Addr: TAddr): string;
var
  infoLine, infoProc: PMapInfo;
begin
  Result := '';
  if Addr = 0 then exit;
  
  if FExeName = '' then
    FExeName := ExtractFileName(ParamStr(0));
  if not FindMapInfo(Addr, 0, infoLine) then exit;
  if infoLine.IsProc then
    infoProc := infoLine else
    infoProc := infoLine.ParentProc;
  Result := Format('(%p){%s} [%p] %s (Line %d, "%s" + %d) + $%x',
    [ Pointer(Addr-FBase), FExeName, Pointer(Addr), FStrInfos[infoProc.IdxProcInfo],
      infoLine.line, FStrInfos[infoLine.IdxUnitInfo],
      infoLine.line - infoProc.line, addr - infoLine.VA]);

  (*
//  (00209784){MapScanner.exe} [0060A784] MainUnit.TForm5.btnAClick (Line 39, "MainUnit.pas" + 2) + $3
// (1C6151){appname} [5C7151] Vcl.Forms.TCustomForm.WndProc (Line 4572, "Vcl.Forms(Vcl.Forms.pas)" + 209) + $5
  if not FindMapInfo(0, addr-FBAse, info) then exit;
  Result := Result + sLineBreak;
  if not info.IsProc then
    begin
      Result := Result + Format('addr=$%x line=%d info=%s', [info.VA, info.line, FStrInfos[info.IdxUnitInfo]]);
      info := info.ParentProc;
    end;
  if info <> nil then
    begin
      if Result <> '' then Result := Result + sLineBreak;
      Result := Result + Format('addr=$%x line=%d info=%s', [info.VA, info.line, FStrInfos[info.IdxProcInfo]]);
    end;
  *)
end;

function TMapScanner.GetNextLine(MapFile: PMapFile): PAnsiChar;
var
  endFile: PAnsiChar;
  P: PAnsiChar;
begin
  Result := nil;
  P := MapFile.Position;
  endFile := MapFile^.endFile;
  while (P <> endFile) and (P^ <> #13) and (P^ <> #10) and (P^<>#0) do Inc(P);
  if P = endFile then exit;
  while (P^ = #13) or (P^ = #10) or (P^=#0) do
    begin
      P^ := #0;
      Inc(P);
    end;
  Result := MapFile.Position;
  MapFile.Position := P;
  While Result^ = ' ' do Inc(Result);
end;

function TMapScanner.GetVA(mapFile: PMapFile; var P: PAnsiChar; out VA: TAddr): Boolean;
var
  vaP, pw: PAnsiChar;
  c1, c2: AnsiChar;
  function CheckSegment: Boolean;
  var
    pd: PAnsiChar;
  begin
    pd := mapFile.Segment;
    while pd^ = pw^ do
      begin
        inc(pw);
        inc(pd);
      end;
    Result := (pw^=':') and (pd^=#0);
  end;

begin
    Result := false;
    pw := P;
    if not CheckSegment then exit;
    vaP := pw;
    while (pw^ <> ' ') and (pw^ <> #0) do Inc(pw);
    if pw = vaP then exit;
    c1 := vaP^;
    c2 := pw^;
    vaP^ := '$';
    Pw^ := #0;

    {$IFNDEF CPU64}
    Result := TryStrToUInt(string(vaP), PCardinal(@VA)^);
    {$ELSE}
    Result := TryStrToUInt64(vaP, PUInt64(@VA)^);
    {$ENDIF}
    if not Result then
      begin
        vaP^ := c1;
        pw^ := c2;
      end;

    Inc(pw);
    P := pw;
end;

procedure TMapScanner.LoadFromFile(const FileName: string);
var
  LV, LL: TList;
  idx: Integer;
  tStart, tEnd, tAmount: Cardinal;
  tStartM, tEndM, tAmountM: Cardinal;
  ms: TMemoryStream;
  map: TMapFile;

begin
//  tStart := GetTickCount;
  Clear;

  if not Assigned(FStrInfos) then
    FStrInfos := TSTringList.Create;

  LV := TList.Create;
  LL := TList.Create;
  ms := TMemoryStream.Create;
  try
    ms.LoadFromFile(FileName);
    map.Position := ms.Memory;
    map.endFile := map.Position + ms.Size;
    if ParseBase(@map) then
      begin
        // alloc memory
        SetLength(FBufMap, Map.BaseLen div SizeOf(Pointer));
        LV.Capacity := Length(FBufMap);
        LL.Capacity := Length(FBufMap);

        // do parse
        if ParseDetailed(@map) then
          if ParsePublicName(@map) then
            if ParsePublisValue(@map, LV) then
              while ParseLineInfo(@map, idx) do
                ParseLineNumber(@map, idx, LL);
      end;
//    tStartM := GetTickCount;
    MergeAddr(LL, LV);
//    tEndM := GetTickCount;
  finally
    ms.Free;
    LV.Free;
    LL.Free;
  end;
  FBase := map.Base;
//  tEnd := GetTickCount;
//  tAmount := tEnd - tStart;
//  tAmountM := tEndM - tStartM;
end;

function TMapScanner.GetNewMapInfo: PMapInfo;
begin
  Result := nil;
  if FIndexBufMap = Length(FBufMap) then exit;
  Result := @FBufMap[FIndexBufMap];
  Inc(FIndexBufMap);
end;

procedure TMapScanner.MergeAddr(LL, LV: TList);
  function _SortCmp(Item1, Item2: PMapInfo): Integer;
  begin
    Result := Item1.RVA - Item2.RVA
  end;
var
  i, IdxLine, IdxProc, lenLine, idxPrev: Integer;
  mapLine, mapProc: PMapInfo;
  newBuf: TMapBuf;

begin
 // if LL.Count = 0 then exit;
  Assert((LL.Count > 0) and (LV.Count > 0), '');
  // init
  SetLength(FList, LL.Count+LV.Count);
  i := 0;
  idxLine := 0;
  idxProc := 0;
  idxPrev := 0;
  mapProc := LV[0];
  lenLine := LL.Count;
  LL.Sort(@_SortCmp);
  LV.Sort(@_SortCmp);

  // merge line + proc
  while (idxLine < lenLine) do
    begin
      if mapProc <> nil then
        begin
          mapLine := LL[idxLine];
          if mapLine.VA = mapProc.VA then
            begin
              mapProc.line := mapLine.line;
              mapProc.IdxUnitInfo := mapLine.IdxUnitInfo;
              FList[i] := mapProc;
              idxPrev := i;
              Inc(idxProc);
              if idxProc < LV.Count then
                mapProc := LV[idxProc] else
                mapProc :=nil;
            end
          else if mapLine.VA < mapProc.VA then
            begin
              FList[i] := mapLine;
              mapLine.IdxProcInfo := idxPrev;
            end
          else
            begin
              FList[i] := mapProc;
              idxPrev := i;
              Inc(i);
              Inc(idxProc);
              if idxProc < LV.Count then
                mapProc := LV[idxProc] else
                mapProc :=nil;
              Continue;
            end
        end
      else
        FList[i] := LL[idxLine];
      Inc(i);
      Inc(idxLine);
    end;
  SetLength(FList, i);

  // realoc new memory, save items. imitation sort
  SetLength(newBuf, i);
  mapProc := @newBuf[0];
  mapLine := FList[0];
  idxLine := 0;
  for i := 0 to Length(FList)-1 do
    begin
      lenLine := IntPtr(FList[i]) - IntPtr(mapLine);
      if IntPtr(FList[i]) - IntPtr(mapLine) <> SizeOf(TMapInfo) * idxLine then
        begin
          Move(mapLine^, mapProc^, SizeOf(TMapInfo) * idxLine);
          mapProc := @newBuf[i];
          mapLine := FList[i];
          idxLine := 0;
        end;
      FList[i] := @newBuf[i];
      Inc(idxLine);
    end;
  if idxLIne > 0 then
    Move(mapLine^, mapProc^, SizeOf(TMapInfo) * idxLine);

  // validate link to ParentProc
  for i := 0 to Length(FLIst)-1 do
    if not FList[i].IsProc then
        FList[i].ParentProc := @newBuf[Flist[i].IdxProcInfo];
  FBufMap := NewBuf;
end;

function TMapScanner.ParseBase(MapFile: PMapFile): Boolean;
const
  str_start = 'Start';
var
  P, P1: PAnsiChar;
begin
  Result := false;
  P := nil;
  while AnsiStrLComp(P, str_start, 5) <> 0 do
    begin
      P := GetNextLine(MapFile);
      if P = nil then exit;
    end;

  while (P <> nil) and not Result do
    begin
      P := GetNextLine(MapFile);
      P1 :=  P;
      while (P^ <> ':') and (P^ <> #0) do Inc(P);
      if P^ = #0 then Continue;
      P^ := '$';
      MapFile.Segment := P1;

      P1 := P;
      while (P^ <> ' ') and (P^ <> #0) do Inc(P);
      if P^ = #0 then Continue;
      P^ := #0;
      {$IFNDEF CPU64}
      if not TryStrToInt(string(P1), Integer(MapFile^.Base)) then Continue;
      {$ELSE}
      if not TryStrToUInt(P1, MapFile^.Base) then Continue;
      {$ENDIF}
      P1^ := #0;


      P1 :=  P;
      P^ := '$';
      while (P^ <> ' ') and (P^ <> #0) do Inc(P);
      if P^ = #0 then Continue;
      (P-1)^ := #0;
      {$IFNDEF CPU64}
      if not TryStrToInt(string(P1), Integer(MapFile^.BaseLen)) then Continue;
      {$ELSE}
      if not TryStrToUInt(P1, MapFile^.BaseLen) then Continue;
      {$ENDIF}
      Inc(P);

      MapFile^.SegmentName :=  P;
      while (P^ <> ' ') and (P^ <> #0) do Inc(P);
      Result :=  P <> MapFile^.SegmentName;
      P^ := #0;
    end;
end;

function TMapScanner.ParseDetailed(MapFile: PMapFile): Boolean;
const
  str_name = 'Address';//'Publics by Name';
var
  P: PAnsiChar;
begin
  Result := false;
  P := nil;
  while AnsiStrLComp(P, str_name, 7) <> 0 do
    begin
      P := GetNextLine(MapFile);
      if P = nil then exit;
    end;
  Result := true;
end;

function TMapScanner.ParseLineInfo(MapFile: PMapFile; var Index: Integer): Boolean;

var
  VP, Info, P: PAnsiChar;
begin
  Result := false;
  P := GetNextLine(MapFile);
  while not Result and (P <> nil) do
    begin
      VP := P;
      while (P^ <> ' ') and (P^ <> #0) do Inc(P);
      if P^ = #0  then exit;
      P^ := #0;
      if  AnsiStrLComp('Line', VP, 4) = 0 then
        begin
          Inc(P);
          while (P^ <> ' ') and (P^ <> #0) do Inc(P);
          if P^ = ' ' then Inc(P);
          while (P^ <> '(') and (P^ <> #0) do Inc(P);
          if P^ = '(' then Inc(P);
          VP := P;
          while (P^ <> ')') and (P^ <> #0) do Inc(P);
          if P^ <> #0  then
            begin
              P^ := #0;
              Info := VP;
              Inc(P, 2);
              while (P^ <> ' ') and (P^ <> #0) do Inc(P);
              if P^ = ' ' then Inc(P);
              VP := P;
              while (P^ <> ' ') and (P^ <> #0) do Inc(P);
              P^ := #0;
              Result := AnsiStrComp(MapFile.SegmentName, VP) = 0;
            end;
        end;
      if Result then
        Index := FStrInfos.Add(string(Info)) else
        P := GetNextLine(MapFile);
    end;
end;

function TMapScanner.ParseLineNumber(MapFile: PMapFile; IndexUnit: Integer; L: TList): Boolean;
var
  P, PW: PAnsiChar;
  Line, Addr: TAddr;
  mapInfo: PMapInfo;

  function GetLineNumber: Boolean;
  var
    vaP, PS: PAnsiChar;
    c: AnsiChar;
  begin
    Result := false;
    vaP := PW;
    PS := PW;
    while (PW^ <> ' ') and (PW^ <> #0) do Inc(PW);
    if PW^ = #0 then
      begin
        PW := PS;
        exit;
      end;
    c := PW^;
    PW^ := #0;
    Inc(PW);
    if
      {$IFNDEF CPU64}
        TryStrToUInt(string(vaP), PCardinal(@Line)^)
      {$ELSE}
        Result := TryStrToUInt64(vaP, PUInt64(@Line)^)
      {$ENDIF} then
    Result := GetVA(mapFile, PW, addr);
    if not Result then
      begin
        (PW-1)^ := c;
        PW := PS;
      end
    else while (PW^ = ' ') do Inc(PW);

  end;
begin
  Result := false;
  P := GetNextLine(MapFile);
  PW := P;
  while not Result and (P <> nil) do
    begin
      while GetLineNumber do
        if addr <> 0 then
        begin
          MapInfo := GetNewMapInfo;
          MapInfo.RVA         := addr;
          MapINfo.VA          := addr + MapFile.Base;
          MapInfo.IsProc      := false;
          MapInfo.ParentProc  := nil;
          MapINfo.IdxUnitInfo := IndexUnit;
          MapInfo.line        := line;
          L.Add(MapInfo);
        end;

      Result := PW = P;
      if not Result then
        begin
          P := GetNextLine(MapFile);
          PW := P;
        end
      else
        MapFile.Position := P;
    end;

end;

function TMapScanner.ParsePublicName(MapFile: PMapFile): Boolean;
const
  str_name = 'Address';//'Publics by Value';
var
  P: PAnsiChar;
begin
  Result := false;
  P := nil;
  while AnsiStrLComp(P, str_name, 7) <> 0 do
    begin
      P := GetNextLine(MapFile);
      if P = nil then exit;
    end;
  Result := true;
end;

function TMapScanner.ParsePublisValue(MapFile: PMapFile; L: TList): Boolean;
const
  str_Line = 'Line numbers for';
var
  P: PAnsiChar;
  MapInfo: PMapInfo;
  NameProc: string;
  addr: TAddr;

  function GetPublicInfo: Boolean;
  label
    repDot;
  var
    VP: PAnsiChar;
  begin
    Result := false;
    while P^ = ' ' do Inc(P);
    if P^ = #0 then exit;
    VP := P;
    // skip double dot.
    repDot:
    while (P^ <> ' ') and (P^ <> '.') and (P^ <> #0) do Inc(P);
    if P^ = '.' then
      if (P+1)^ = '.' then exit else
        begin
          Inc(p);
          goto repDot;
        end;
    P^ := #0;
    NameProc := string(VP);
    Result := true;
  end;

begin
  Result := false;
  P := GetNextLine(MapFile);
  while not Result and (P <> nil) do
    begin
      if GetVA(MapFile, P, addr) then
        begin
          if GetPublicInfo then
            begin
                MapInfo := GetNewMapInfo;
                MapInfo.RVA         := addr;
                MapINfo.VA          := addr + MapFile.Base;
                MapInfo.IsProc      := true;
                MapInfo.ParentProc  := nil;
                MapINfo.IdxProcInfo := FStrInfos.Add(NameProc);
                MapInfo.line        := -1;
                L.Add(MapInfo);
            end
        end
      else if AnsiStrLComp(P, str_Line, 16) = 0 then
        begin
          MapFile.Position := P;
          Result := true;
          break;
        end;
      P := GetNextLine(MapFile);
    end;
end;

function TMapScanner.SearchMapInfoVA(VA: TAddr): PMapInfo;
var
  Index, lo, hi: Integer;
  nearMap: PMapInfo;
begin
  result := nil;
  nearMap := nil;
  lo := 0;
  hi := Length(FList)-1;

  While lo <= hi do
    begin
      if FList[lo].VA = Flist[hi].VA then
        begin
          if FList[lo].VA = VA then
            Result := FList[lo];
          break;
        end  ;


      Index := Round(lo + ((VA  - Flist[lo].VA) * ((hi -lo) / (FList[hi].VA - FList[lo].VA))));
      if (Index < lo) or (Index > hi) then break;

      if VA = FList[Index].VA then
        begin
          Result := FList[Index];
          exit;
        end
      else if VA < FList[index].VA then
        begin
          hi := index - 1;
          if FList[hi].VA < VA then
            nearMap := FList[hi];
        end
      else
        begin
          nearMap := FList[Index];
          lo := index + 1;
        end;
    end;
  if Result = nil then
    Result := nearMap;
end;

function TMapScanner.SearchMapInfoRVA(RVA: TAddr): PMapInfo;
var
  Index, lo, hi: Integer;
  nearMap: PMapInfo;
begin
  result := nil;
  lo := 0;
  hi := Length(FList)-1;
  nearMap := nil;
  While lo <= hi do
    begin
      if FList[lo].RVA = Flist[hi].RVA then
        begin
          if FList[lo].RVA = RVA then
            Result := FList[lo];
          break;
        end  ;


      Index := Round(lo + ((RVA  - Flist[lo].RVA) * ((hi -lo) / (FList[hi].RVA - FList[lo].RVA))));
      if (Index < lo) or (Index > hi) then break;

      if RVA = FList[Index].RVA then
        begin
          Result := FList[Index];
          exit;
        end
      else if RVA < FList[index].RVA then
        begin
          hi := index - 1;
          if FList[hi].RVA < RVA then
            nearMap := FList[hi];
        end
      else
        begin
          nearMap := FList[Index];
          lo := index + 1;
        end;
    end;
  if Result = nil then
    Result := nearMap;
end;



end.
