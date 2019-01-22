unit MainUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, System.Messaging,
  FMX.Controls.Presentation, FMX.StdCtrls,
  FMX.ScrollBox, FMX.Memo, ExcFormReport;

type
  TMainForm = class(TForm)
    btnDivByZero: TButton;
    btnAccesWrite0: TButton;
    btnExzception: TButton;
    btnTryExceptRaise: TButton;
    lblUnhandled: TLabel;
    lblHandled: TLabel;
    btnTryExceptDiv: TButton;
    btnTryExceptAV: TButton;
    btnCheckRaiseList: TButton;
    procedure btnDivByZeroClick(Sender: TObject);
    procedure btnAccesWrite0Click(Sender: TObject);
    procedure btnExzceptionClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnTryExceptRaiseClick(Sender: TObject);
    procedure btnTryExceptDivClick(Sender: TObject);
    procedure btnTryExceptAVClick(Sender: TObject);
    procedure btnCheckRaiseListClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

uses
  System.IOUtils;

{$R *.fmx}

procedure TMainForm.btnAccesWrite0Click(Sender: TObject);
var
  p: PChar;
begin
  P := nil;
  P^ := 'a';
end;

procedure TMainForm.btnTryExceptAVClick(Sender: TObject);
begin
  try
    btnAccesWrite0Click(nil);
  except
    on E:Exception do
      Application.ShowException(E);
  end;
end;

procedure TMainForm.btnTryExceptDivClick(Sender: TObject);
begin
  try
    btnDivByZeroClick(nil);
  except
    on E:Exception do
      Application.ShowException(E);
  end;
end;

procedure TMainForm.btnTryExceptRaiseClick(Sender: TObject);
begin
  try
    btnExzceptionClick(nil);
  except
    on E:Exception do
      Application.ShowException(E);
  end;
end;

procedure TMainForm.btnCheckRaiseListClick(Sender: TObject);
var
  List: TList;
begin
  List.Add(nil);
end;

procedure TMainForm.btnDivByZeroClick(Sender: TObject);
var
  i: Integer;
begin
  i :=0;
  i := 5 div i;
end;

procedure TMainForm.btnExzceptionClick(Sender: TObject);
begin
  raise Exception.Create('simple exception');
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  TExcReportForm.RegisterExceptHandler;
end;


end.
