unit EcxStackTrace;
interface
uses
  SysUtils, MapScan, Classes,
  Posix.Base;

function raw_backtrace_vl(StackTrace: PNativeUInt; Base, FirstCaller, Skip, Count: NativeUInt): NativeUInt;
function frame_backtrace_vl(StackTrace: PNativeUInt; Base, Skip, Count: NativeUInt): NativeUInt;
function GetStackPointer: Pointer;

implementation


function GetStackPointer: Pointer;
asm
        {$IFDEF CPU32BITS}
        MOV     EAX, ESP
        {$ENDIF CPU32}
        {$IFDEF CPU64BITS}
        MOV     RAX, RSP
        {$ENDIF CPU64}
end;


type
    PStackTrace = ^TStackTrace;
    TStackTrace = array[0..MaxInt div Sizeof(NativeUint)- 1] of NativeUInt;


    //  Get TOP of stack
{+ {                                               \
+   pthread_t self_id;                            \
+                                                 \
+   self_id = pthread_self ();                    \
+   start = pthread_get_stackaddr_np (self_id);   \
+   size = pthread_get_stacksize_np (self_id);    \
+   end = (char *)start + size;                   \
+
 while (0)*)
 }

function pthread_get_stackaddr_np(p: NativeUInt): NativeUInt; cdecl; external libpthread name _PU + 'pthread_get_stackaddr_np';
function pthread_self: NativeUInt; cdecl; external libpthread name _PU + 'pthread_self';

function GetStackTop: NativeUInt;
var
  id: NativeUInt;
begin
  id := pthread_self();
  Result := pthread_get_stackaddr_np(id);
end;

// find range  address into map file
function ValidCodeAddr(Addr: NativeUInt): Boolean;
var
  info: PMapInfo;
begin
  Result := GetMapScanner.FindMapInfo(Addr, 0, info);
end;


// Validate that the code address is a valid code site
//
// Information from Intel Manual 24319102(2).pdf, Download the 6.5 MBs from:
// http://developer.intel.com/design/pentiumii/manuals/243191.htm
// Instruction format, Chapter 2 and The CALL instruction: page 3-53, 3-54
function ValidCallSite(CodeAddr: NativeUInt; out CallInstructionSize: NativeUint): Boolean;
var
  CodeDWORD4: NativeUInt;
  CodeDWORD8: NativeUInt;
  C4P, C8P: PNativeUInt;
  RM1, RM2, RM5: Byte;
begin
  // todo: 64 bit version

  // First check that the address is within range of our code segment!
  Result := CodeAddr > 8;
  if Result then
  begin
    C8P := PNativeUInt(CodeAddr - 8);
    C4P := PNativeUInt(CodeAddr - 4);
    Result := ValidCodeAddr(NativeUInt(C8P));

    // Now check to see if the instruction preceding the return address
    // could be a valid CALL instruction
    if Result then
    begin
      try
        CodeDWORD8 := PNativeUInt(C8P)^;
        CodeDWORD4 := PNativeUInt(C4P)^;
        // CodeDWORD8 = (ReturnAddr-5):(ReturnAddr-6):(ReturnAddr-7):(ReturnAddr-8)
        // CodeDWORD4 = (ReturnAddr-1):(ReturnAddr-2):(ReturnAddr-3):(ReturnAddr-4)

        // ModR/M bytes contain the following bits:
        // Mod        = (76)
        // Reg/Opcode = (543)
        // R/M        = (210)
        RM1 := (CodeDWORD4 shr 24) and $7;
        RM2 := (CodeDWORD4 shr 16) and $7;
        //RM3 := (CodeDWORD4 shr 8)  and $7;
        //RM4 :=  CodeDWORD4         and $7;
        RM5 := (CodeDWORD8 shr 24) and $7;
        //RM6 := (CodeDWORD8 shr 16) and $7;
        //RM7 := (CodeDWORD8 shr 8)  and $7;

        // Check the instruction prior to the potential call site.
        // We consider it a valid call site if we find a CALL instruction there
        // Check the most common CALL variants first
        if ((CodeDWORD8 and $FF000000) = $E8000000) then
          // 5 bytes, "CALL NEAR REL32" (E8 cd)
          CallInstructionSize := 5
        else
        if ((CodeDWORD4 and $F8FF0000) = $10FF0000) and not (RM1 in [4, 5]) then
          // 2 bytes, "CALL NEAR [EAX]" (FF /2) where Reg = 010, Mod = 00, R/M <> 100 (1 extra byte)
          // and R/M <> 101 (4 extra bytes)
          CallInstructionSize := 2
        else
        if ((CodeDWORD4 and $F8FF0000) = $D0FF0000) then
          // 2 bytes, "CALL NEAR EAX" (FF /2) where Reg = 010 and Mod = 11
          CallInstructionSize := 2
        else
        if ((CodeDWORD4 and $00FFFF00) = $0014FF00) then
          // 3 bytes, "CALL NEAR [EAX+EAX*i]" (FF /2) where Reg = 010, Mod = 00 and RM = 100
          // SIB byte not validated
          CallInstructionSize := 3
        else
        if ((CodeDWORD4 and $00F8FF00) = $0050FF00) and (RM2 <> 4) then
          // 3 bytes, "CALL NEAR [EAX+$12]" (FF /2) where Reg = 010, Mod = 01 and RM <> 100 (1 extra byte)
          CallInstructionSize := 3
        else
        if ((CodeDWORD4 and $0000FFFF) = $000054FF) then
          // 4 bytes, "CALL NEAR [EAX+EAX+$12]" (FF /2) where Reg = 010, Mod = 01 and RM = 100
          // SIB byte not validated
          CallInstructionSize := 4
        else
        if ((CodeDWORD8 and $FFFF0000) = $15FF0000) then
          // 6 bytes, "CALL NEAR [$12345678]" (FF /2) where Reg = 010, Mod = 00 and RM = 101
          CallInstructionSize := 6
        else
        if ((CodeDWORD8 and $F8FF0000) = $90FF0000) and (RM5 <> 4) then
          // 6 bytes, "CALL NEAR [EAX+$12345678]" (FF /2) where Reg = 010, Mod = 10 and RM <> 100 (1 extra byte)
          CallInstructionSize := 6
        else
        if ((CodeDWORD8 and $00FFFF00) = $0094FF00) then
          // 7 bytes, "CALL NEAR [EAX+EAX+$1234567]" (FF /2) where Reg = 010, Mod = 10 and RM = 100
          CallInstructionSize := 7
        else
        if ((CodeDWORD8 and $0000FF00) = $00009A00) then
          // 7 bytes, "CALL FAR $1234:12345678" (9A ptr16:32)
          CallInstructionSize := 7
        else
          Result := False;
        // Because we're not doing a complete disassembly, we will potentially report
        // false positives. If there is odd code that uses the CALL 16:32 format, we
        // can also get false negatives.
      except
        Result := False;
      end;
    end;
  end;
end;


//==============================================================================
function raw_backtrace_vl(StackTrace: PNativeUInt; Base, FirstCaller, Skip, Count: NativeUInt): NativeUInt;
var
  StackTop, PrevCaller, CallInstructionSize: NativeUInt;
  Stack: PStackTrace;
  StackPtr: PNativeUInt;
begin
  StackTop := GetStackTop;
  Stack := PStackTrace(StackTrace);
  if (Base = 0) or (Base > StackTop) then
    Base := NativeUInt(GetStackPointer);
  StackPtr := PNativeUInt(Base);

  Result := 0;
  // while in stack do..

  while (Count > 0) and (StackTop > NativeUInt(StackPtr)) do
    begin
      // wait caller on the stack
       if (FirstCaller <> 0) then
         begin
           if (StackPtr^ = FirstCaller) then
             begin
               FirstCaller := 0;
               Continue;
             end;
         end
       else
       // check addres and size instruction
       if ValidCallSite(StackPtr^, CallInstructionSize) and (StackPtr^ <> PrevCaller) then
        begin
          if Skip = 0 then
            begin
              // then pick up the callers address
              StackTrace^ :=  StackPtr^ - CallInstructionSize;
              // remember to callers address so that we don't report it repeatedly
              PrevCaller := StackPtr^;
              Inc(StackTrace);
              Inc(Result);
              Dec(Count);
            end
          else
            Dec(Skip);
        end;
      Inc(StackPtr);
    end;

end;

//==============================================================================
function frame_backtrace_vl(StackTrace: PNativeUInt; Base, Skip, Count: NativeUInt): NativeUInt;
var
  BaseBound, CallInstructionSize, PrevCaller, StackAddr: NativeUInt;
  i: Integer;
begin
  BaseBound := Base;
  Result := 0;
  for i := 0 to Count-1 do
    begin
      if (Base < BaseBound) or (Base = 0) then break;

      if skip = 0 then
        begin

          StackAddr := PNativeUInt(Base + 4)^;// SizeOf(NativeUInt)
          // check addres and size instruction
          if ValidCallSite(StackAddr, CallInstructionSize) then
            begin
              StackTrace^ :=  StackAddr - CallInstructionSize;
              Inc(StackTrace);
              Inc(Result);
            end;
        end
      else
        Dec(Skip);
      Base := PNativeUInt(Base)^;
    end;
end;

end.

