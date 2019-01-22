unit ExcFormReport;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, ExcSysInfo;

type
  TExcReportForm = class(TForm)
    mm: TMemo;
    btnOK: TButton;
    procedure btnOKClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    class procedure ExceptionAcquiredHandler(Obj: {$IFDEF AUTOREFCOUNT}TObject{$ELSE}Pointer{$ENDIF}); static;
    class procedure ExceptProcHandler(ExceptObject: TObject; ExceptAddr: Pointer); static;
    class procedure ExceptionHandler(Sender: TObject; E: Exception);
    class function BuildReport(ExceptObject: TObject; ExceptAddr: Pointer): string;

  public
    { Public declarations }
    class procedure RegisterExceptHandler;
  end;


implementation

{$R *.fmx}


var
  ReportForm: TExcReportForm;

procedure ShowReport(const s: string);
begin
  if not Assigned(ReportForm) then
    ReportForm := TExcReportForm.Create(Application);
  if ReportForm.Visible then
    ReportForm.mm.Lines.Add(s) else
    begin
      ReportForm.mm.Lines.Text := s;
      ReportForm.Show;
    end;
end;

procedure TExcReportForm.btnOKClick(Sender: TObject);
begin
  Close;
end;

class function TExcReportForm.BuildReport(ExceptObject: TObject;
  ExceptAddr: Pointer): string;
var
  list: TStrings;
  OSVersion: TOSVersion;
  E: Exception absolute ExceptObject;
  s: string;
  m1: Int64;
  m2: Double;
begin
  list := TStringList.Create;
  try
    list.Add('----------------'+DateToStr(Now)+ FormatDateTime(' hh:nn:ss.zzz', Now)+'----------------'+sLineBreak);
    list.Add(Format('OS:'#9#9#9#9' %s #%s ', [OSVersion.ToString, OSVersionRaw]));
    list.Add(Format('HostName:'#9#9' %s', [HostName]));
    list.Add(Format('User:'#9#9#9' %s (%s)', [GetUserName(false), GetUserName(true)]));
    list.Add(Format('OSType:'#9#9#9' %s', [OSType]));
    list.Add(Format('Machine:'#9#9' %s', [Machine]));
    list.Add(Format('Model:'#9#9#9' %s', [Model]));
    list.Add(Format('Kernel version:'#9' %s', [KernelVersion]));
    list.Add(Format('CPUs:'#9#9#9' %d', [NumberOfCPU]));
    m1 := MemSize ;  //b
    m2 := MemSize / 1024 / 1024; // mb
    list.Add(Format('RAM size:'#9#9' %d B / %.2f MB / %.2f GB', [m1, m2, m2 / 1024]));

    if ExceptObject is Exception then
      begin
        s := Format('ExceptionClass: %s '+sLineBreak+'ExceptionMessage: %s', [E.ClassName, E.Message]);
        list.Add('');
        list.Add('stack trace:');
        list.Add(E.StackTrace);
      end
    else if ExceptObject <> nil then
      begin
        s := Format('ExceptionClass: %s '+sLineBreak+'ExceptionMessage: UNKNOWN', [ExceptObject.ClassName]);
      end
    else
      begin
        s := 'ExceptionClass: UNKNOWN '+sLineBreak+'ExceptionMessage: UNKNOWN';
      end;
    list.Insert(1, s+sLineBreak);
    Result := list.Text;
  finally
    list.free;
  end;
end;

class procedure TExcReportForm.ExceptionAcquiredHandler(Obj: Pointer);
begin
  ShowReport(BuildReport(Obj, ExceptAddr));
end;

class procedure TExcReportForm.ExceptionHandler(Sender: TObject; E: Exception);
begin
  ShowReport(BuildReport(E, ExceptAddr));
end;

class procedure TExcReportForm.ExceptProcHandler(ExceptObject: TObject;
  ExceptAddr: Pointer);
begin
  ShowReport(BuildReport(ExceptObject, ExceptAddr));
end;

procedure TExcReportForm.FormCreate(Sender: TObject);
begin
{$IFDEF MSWINDOWS}
    mm.TextSettings.Font.Family := 'Consolas';
    mm.StyledSettings :=  mm.StyledSettings - [TStyledSetting.Family]
{$ENDIF}
{$IFDEF ANDROID}
    mm.TextSettings.Font.Family := 'monospace';
    mm.StyledSettings :=  mm.StyledSettings - [TStyledSetting.Family]
{$ENDIF}
{$IFDEF MACOS}
    mm.TextSettings.Font.Family := 'Menlo';
    mm.TextSettings.Font.Size := mm.TextSettings.Font.Size - 1;
    mm.StyledSettings :=  mm.StyledSettings - [TStyledSetting.Family,TStyledSetting.Size];

{$ENDIF}
end;

class procedure TExcReportForm.RegisterExceptHandler;
begin
  Application.OnException := TExcReportForm.ExceptionHandler;
  ExceptProc := @TExcReportForm.ExceptProcHandler;
  ExceptionAcquired := @TExcReportForm.ExceptionAcquiredHandler;
end;

end.
