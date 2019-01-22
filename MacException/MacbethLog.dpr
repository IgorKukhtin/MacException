program MacbethLog;
uses
  System.IOUtils,
  System.StartUpCopy,
  FMX.Forms,
  MainUnit in 'MainUnit.pas' {MainForm},
  ExcFormReport in 'ExcFormReport.pas' {ExcReportForm},
  ExcSysInfo in 'ExcSysInfo.pas',
  mapScan in 'mapScan.pas',
  ExcHandler in 'ExcHandler.pas',
  EcxStackTrace in 'EcxStackTrace.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;

end.
