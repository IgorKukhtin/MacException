unit ExcSysInfo;
interface
uses
  System.Classes,
  System.Types,
  Posix.Errno,
  Macapi.CoreFoundation,
  Macapi.Foundation,
  Posix.SysTypes,
  Posix.SysSysctl,
  System.SysUtils
  ;

  function NumberOfCPU: Integer;
  function MaxProcesses : Integer;
  function MemSize : Int64;
  function KernelVersion : String;
  function HostName: string;
  function OSType: string;
  function OSVersionRaw: string;
  function Machine: string;
  function Model: string;

  procedure GetClockInfo(List: TStrings);
  function GetUserName(FULLUserName: Boolean): string;

implementation

//https://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man3/sysctl.3.html
//https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/sysctl.8.html

function NSUserName: Pointer; cdecl; external '/System/Library/Frameworks/Foundation.framework/Foundation' name _PU +'NSUserName';
function NSFullUserName: Pointer; cdecl; external '/System/Library/Frameworks/Foundation.framework/Foundation' name _PU + 'NSFullUserName';

//==============================================================================
function GetUserName(FULLUserName: Boolean): string;
begin
  if not FULLUserName then
    Result := TNSString.Wrap(NSUserName).UTF8String else
    Result := TNSString.Wrap(NSFullUserName).UTF8String
end;

//==============================================================================

function GetsysctlIntValue(mib: TIntegerDynArray): integer;
var
  len : size_t;
  res : integer;
begin
   len := sizeof(Result);
   res:=sysctl(@mib[0], 2, @Result, @len, nil, 0);
   if res<>0 then
    Result:=-1;// RaiseLastOSError;
end;

function GetsysctlInt64Value(mib: TIntegerDynArray): Int64;
var
  len : size_t;
  res : integer;
begin
   len := sizeof(Result);
   res:=sysctl(@mib[0], 2, @Result, @len, nil, 0);
   if res<>0 then
     Result:=-1; //RaiseLastOSError;
end;

function GetsysctlStrValue(mib: TIntegerDynArray): AnsiString;
var
  len : size_t;
  p   : PAnsiChar;
  res : integer;
begin
   Result:='';
   res:=sysctl(@mib[0], 2, nil, @len, nil, 0);
   if (len>0) and (res=0)  then
   begin
     GetMem(p, len);
     try
       res:=sysctl(@mib[0], 2, p, @len, nil, 0);
       if res=0 then
        Result:=p;
     finally
       FreeMem(p);
     end;
   end;
end;

//==============================================================================

function NumberOfCPU: Integer;
begin
  Result := GetsysctlInt64Value(TIntegerDynArray.Create(CTL_HW, HW_NCPU));
end;

function MaxProcesses : Integer;
begin
  Result := GetsysctlIntValue(TIntegerDynArray.Create(CTL_KERN, KERN_MAXPROC));
end;

function MemSize : Int64;
begin
  Result := GetsysctlInt64Value(TIntegerDynArray.Create(CTL_HW, HW_MEMSIZE));
end;

function KernelVersion : string;
begin
  Result := GetsysctlStrValue(TIntegerDynArray.Create(CTL_KERN, KERN_VERSION));
end;

function HostName: string;
begin
  Result := GetsysctlStrValue(TIntegerDynArray.Create(CTL_KERN, KERN_HOSTNAME));
end;

function OSType: string;
begin
  Result := GetsysctlStrValue(TIntegerDynArray.Create(CTL_KERN, KERN_OSTYPE));
end;

function OSVersionRaw: string;
begin
  Result := GetsysctlStrValue(TIntegerDynArray.Create(CTL_KERN, KERN_OSVERSION));
end;

function Machine: string;
begin
  Result := GetsysctlStrValue(TIntegerDynArray.Create(CTL_HW, HW_MACHINE));
end;

function Model: string;
begin
  Result := GetsysctlStrValue(TIntegerDynArray.Create(CTL_HW, HW_MODEL));
end;

procedure GetClockInfo(List: TStrings);
type
 clockinfo = record
    hz      : Integer;
    tick    : Integer;
    tickadj : Integer;
    stathz  : Integer;
    profhz  : Integer;
  end;

(*
struct clockinfo {
    int hz;     /* clock frequency */
    int tick;       /* micro-seconds per hz tick */
    int tickadj;/* clock skew rate for adjtime() */
    int stathz;     /* statistics clock frequency */
    int profhz;     /* profiling clock frequency */
};
*)

var
  mib : array[0..1] of Integer;
  res : Integer;
  len : size_t;
  clock : clockinfo;
begin
 FillChar(clock, sizeof(clock), 0);
 mib[0] := CTL_KERN;
 mib[1] := KERN_CLOCKRATE;
 len := sizeof(clock);
 res:=sysctl(@mib, Length(mib), @clock, @len, nil, 0);
 if res<>0 then
   exit;//RaiseLastOSError;

 List.add(Format('clock frequency             %d',[clock.hz]));
 List.add(Format('micro-seconds per hz tick   %d',[clock.tick]));
 List.add(Format('clock skew rate for adjtime %d',[clock.tickadj]));
 List.add(Format('statistics clock frequency  %d',[clock.stathz]));
 List.add(Format('profiling clock frequency   %d',[clock.profhz]));
end;

end.
