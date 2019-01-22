unit ExcHandler;
interface

uses
  SysUtils;

type
  TStackPrintMethod = (spmFrame, spmRaw);

var
  FramePrintMethod: set of TStackPrintMethod = [spmFrame, spmRaw];

implementation

uses mapScan, EcxStackTrace;

const
  MaxDepth =  32;   //<  глубина печати стека

type
    PStackTrace = ^TStackTrace;
    TStackTrace = array[0..MaxDepth - 1] of NativeUInt;

    PStackInfo = ^TStackInfo;
    TStackInfo = array [0..2] of PStackTrace;



procedure CleanUpStackInfo(Info: Pointer);
var
  ps: PStackInfo absolute Info;
begin
  FreeMem(ps^[0]);
  FreeMem(ps^[1]);
  FreeMem(ps);
end;


function AllocateStackeTrace: PStackTrace;
begin
  GetMem(Result, SizeOf(TStackTrace));
  FillChar(Result^, SizeOf(TStackTrace), 0);
end;

function GetExceptionStackInfo(P: PExceptionRecord): Pointer;
var
  Base: NativeUInt;
  ps: PStackInfo absolute Result;
begin

  {
    Указатель на кадр испорчен предыдущим вызовом.
    Восстанавливаем его, но обязательно проверяем версию среды и по необходимости
    вносим правки.
    Сейчас в ebp находится адрес текущей функции. Смещение до валидного фрейма $30

    The pointer to the frame is corrupted by the previous call.
    Restore it, but be sure to check the version of the IDE and, if necessary, make changes.
    Now EBP is the address of the current function. Offset to valid frame $30

      ----------------------------------

      +$30 = $0C + $04 + $04 + $18 + $04

      prev call  - add esp          -$0С
      prev call  - return addres    -$04
      cur  call  - puch ebp         -$04
      cur  call  - add esp, -$18    -$18 (the  size local varibles)
      cur  call  - push ebx         -$04
      ----------------------------------
                                    -$30
    }
  asm
    // get valid frame pointer
    mov Base, ebp
    // restor frame pointer
    mov eax, [esp+$30]
    mov [ebp], eax
  end;

  GetMem(Result, SizeOf(TStackInfo));
  ps^[0] := nil;
  ps^[1]  := nil;

  if P.ExceptObject is EExternal then
    ps^[2] := Pointer(EExternal(P.ExceptObject).ExceptionAddress) else
    ps^[2] := P.ExceptionAddr;

  // frame
  if  spmFrame in FramePrintMethod then
    begin
      ps^[0] := AllocateStackeTrace;
      frame_backtrace_vl(PNativeUInt(ps^[0]), Base, 0, MaxDepth-1);
    end;

  // raw
  if spmRaw in FramePrintMethod then
    begin
      ps^[1] := AllocateStackeTrace;
      raw_backtrace_vl(PNativeUInt(ps^[1]), Base, NativeUInt(P.ExceptionAddr), 0, MaxDepth-1);
    end;
end;


function GetStackInfoString(Info: Pointer): string;
var
  AllocationStackTrace: PStackTrace;
  ps: PStackInfo absolute Info;
  addr: NativeUInt;
begin
  Result := '';
  if ps^[0] <> nil then
    Result := sLineBreak+sLineBreak+'  ____FRAME-BASED____'+SlineBreak+SlineBreak + LogStackTrace(PNativeUInt(ps^[0]), MaxDepth);
  if ps^[1] <> nil then
    Result := Result + sLineBreak+sLineBreak+'  ____RAW____'+SlineBreak+SlineBreak + LogStackTrace(PNativeUInt(ps^[1]), MaxDepth);
  addr := NativeUInt(ExceptAddr);
  Result := sLineBreak+sLineBreak+'   ____EXCEPTADDR___'+sLineBreak+sLineBreak+LogStackTrace(PNativeUInt(@ps^[2]), 1)+ Result;

end;

procedure ExceptProcHandler(ExceptObject: TObject; ExceptAddr: Pointer);
begin

end;

procedure ExceptionAcquiredHandler(Obj: {$IFDEF AUTOREFCOUNT}TObject{$ELSE}Pointer{$ENDIF});
begin

end;


procedure installExc;
begin
  Exception.GetExceptionStackInfoProc := GetExceptionStackInfo;
  Exception.CleanUpStackInfoProc      := CleanUpStackInfo;
  Exception.GetStackInfoStringProc    := GetStackInfoString;
  // todo debug
//  ExceptionAcquired                   := ExceptionAcquiredHandler;
//  ExceptProc                          := ExceptProcHandler;
end;

procedure releaseExc;
begin
  Exception.GetExceptionStackInfoProc := nil;
  Exception.CleanUpStackInfoProc      := nil;
  Exception.GetStackInfoStringProc    := nil;
end;





initialization
  installExc;
finalization
  releaseExc;

end.
