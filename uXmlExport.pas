unit uXmlExport;

interface

uses
  NativeXml,
  VCL.Dialogs, VCL.Forms,
  Windows, ShellApi, ActiveX,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.FB,
  FireDAC.Phys.FBDef, FireDAC.FMXUI.Wait, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.Client, Data.DB,
  FireDAC.Comp.DataSet, FireDAC.Stan.Intf,
  System.IniFiles, System.IOUtils, System.Types, System.UITypes,
  System.SysUtils, System.Classes, System.Variants;

type
  TOnProgressValue = procedure(AValue: integer) of object;
  TOnProgressMax = procedure(AMax: integer) of object;
  TOnProgressText = procedure(AMsg: string) of object;
  TOnActive = procedure(AActive: Boolean) of object;

  TXmlExport = class(TThread)
    { Сброс выгрузки, т.е. полная остановка. Файлы выгруженные до этого момента
      сохраняются по установленному пути }
    Reset: Boolean;
    { Обработчик активности выгрузки. Возвращет True - идет выгрузка,
      False - выгрузка остановлена }
    OnActive: TOnActive;
    { Обработчик прогресса выгрузки, возвращает AValue - текущее значение прогресса }
    OnProgressValue: TOnProgressValue;
    { Обработчик прогресса выгрузки, возвращает AMax - текущее максимальное значение прогресса }
    OnProgressMax: TOnProgressMax;
    { Обработчик тестовых сообещние, возвращает AMsg - информационное сообщение }
    OnProgressText: TOnProgressText;
    { Xml-шаблон, по которому будет делаться выгрузка }
    Xml: string;
    { Sql-запрос, по которобу будет формироваться набор данных для выгрузки }
    Sql: string;
    { Корневой каталог выгрузки, если не указан, то КАТАЛОГ_ЗАПУСКА\exportfiles }
    Directory: string;
    { Наименование поля из запроса, по которому будут группироваться файлы выгрузки.
      Группировка происходит по каталогам с именами вида: ИМЯПОЛЯ_ЗНАЧЕНИЕПОЛЯ
      в каталоге Directory }
    GroupingField: string;
    { Наименование поля из запроса, по которому будут формироваться имена, выгружаемых
      файлов. Если файл с таким именем уже существует в каталоге, то к его имени добавляется инкремент }
    FilenameField: string;
    { В значении True удаляется декларация <?xml ... ?> в выгружаемых файлах }
    DeleteDeclaration: boolean;
    { В значении True удаляются пустые элементы <node/> и <node></node> }
    DeleteEmptyNodes: boolean;
    { В значении True, после завершения выгрузки или сброса, открывается корневой каталог выгрузки }
    OpenDirectory: boolean;
    { Параметр даты начала :STARTDATE в запросе, допускается отсутствие параметра }
    StartDate: TDateTime;
    { Параметр даты завершения :ENDDATE в запросе, допускается отсутствие параметра }
    EndDate: TDateTime;
  private
    FDatabase           : TFDConnection;
    FQuery              : TFDQuery;
    FActive             : boolean;
    FProgressValue      : integer;
    FProgressMax        : integer;
    FProgressIncrement  : boolean;
    FProgressText       : string;
    FExceptionMessage   : string;

    procedure SetReset(const Value: Boolean);
    procedure SetDirectory(const Value: string);

    property FReset: Boolean read Reset write SetReset;
    property FOnActive: TOnActive read OnActive write OnActive;
    property FOnProgressValue: TOnProgressValue read OnProgressValue write OnProgressValue;
    property FOnProgressMax: TOnProgressMax read OnProgressMax write OnProgressMax;
    property FOnProgressText: TOnProgressText read OnProgressText write OnProgressText;
    property FXml: string read Xml write Xml;
    property FSql: string read Sql write Sql;
    property FDirectory: string read Directory write SetDirectory;
    property FGroupingField: string read GroupingField write GroupingField;
    property FFilenameField: string read FilenameField write FilenameField;
    property FDeleteDeclaration: boolean read DeleteDeclaration write DeleteDeclaration;
    property FDeleteEmptyNodes: boolean read DeleteEmptyNodes write DeleteEmptyNodes;
    property FOpenDirectory: boolean read OpenDirectory write OpenDirectory;
    property FStartDate: TDateTime read StartDate write StartDate;
    property FEndDate: TDateTime read EndDate write EndDate;

    function QueryActive(ASql: string): Boolean;
    procedure QueryFetchAll;
    procedure QueryReopen;
    procedure QueryFirst;
    function QueryRecordCount: integer;
    procedure QueryParsing;

    procedure CreateDirDef(ADirectory: string; ADefDirectory: string = '');

    { Âîçâðàùàåò ñôîðìèðîâàííîå èìÿ ôàéëà äëÿ òåêóùåãî íàáîðà äàííûõ,
      âèäà: Directory\FilenameFieldValue(èíêðåìåíò).xml }
    function GetFilename(ADirectory, AFieldName: string; AInc: integer): string;
    { Âîçâðàùàåò ñôîðìèðîâàííîå èìÿ êàòàëîãà äëÿ òåêóùåãî íàáîðà äàííûõ,
      âèäà: Directory\GroupingFieldName_GroupingFieldValue }
    function GetGroupingDir(ATemplateDir, AFieldName: string): string;

    { Ïàðñèíã âõîäÿùåãî xml ïîä íàáîð äàííûõ }
    procedure XmlParse(AQuery: TFDQuery; ANode: TXmlNode);

    { ïðîöåäóðû äëÿ Synchronize-âûçîâîâ }
    procedure Active;
    procedure ProgressValue;
    procedure ProgressMax;
    procedure ProgressText;
    procedure ShowExceptionMessage;

    { Synchronize-âûçîâû }
    procedure SyncActive(AActive: boolean);
    procedure SyncProgressValue(AValue: integer);
    procedure SyncProgressMax(AMax: integer);
    procedure SyncProgressText(AMsg: string);
    procedure SyncShowExceptionMessage(AMsg: string);

    procedure Execute; override;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    procedure Run;
  end;

const
  ArrayEscapeChars: array of Char = ['\', '/', '|', '"', ':', '?'];

implementation


function EscapeChars(AStr: string; AChars: array of Char): string;
var
  TmpStr: string;
  I: integer;
begin
  TmpStr := AStr;
  for I := 0 to Length(AChars) do
    begin
      TmpStr := StringReplace(TmpStr, AChars[I], '', [rfReplaceAll, rfIgnoreCase])
    end;
  Result := TmpStr;
end;


{###############################################################################

  TXmlExport

###############################################################################}
destructor TXmlExport.Destroy;
begin
  FreeAndNil(FQuery);
  Terminate;
  WaitFor;
end;

constructor TXmlExport.Create(AConnection: TFDConnection);
begin
  inherited Create(True);
  FreeOnTerminate := True;

  FQuery := TFDQuery.Create(Application);
  FQuery.Connection := AConnection;

  SetReset(False);
end;

procedure TXmlExport.Execute;
begin
  inherited;
  CoInitialize(nil);
  QueryParsing;
  CoUninitialize;
end;

procedure TXmlExport.Run;
begin
  Priority := tpNormal;
  Resume;
end;

procedure TXmlExport.CreateDirDef(ADirectory, ADefDirectory: string);
begin
  if ADirectory = EmptyStr then
    SetDirectory(ADefDirectory);
  CreateDir(ADirectory);
end;

procedure TXmlExport.Active;
begin
  if Assigned(OnActive) then
    OnActive(FActive);
end;

procedure TXmlExport.ProgressMax;
begin
  if Assigned(OnProgressMax) then
    OnProgressMax(FProgressMax);
end;

procedure TXmlExport.ProgressText;
begin
  if Assigned(OnProgressText) then
    OnProgressText(FProgressText);
end;

procedure TXmlExport.ProgressValue;
begin
  if Assigned(OnProgressValue) then
    OnProgressValue(FProgressValue);
end;

procedure TXmlExport.SetDirectory(const Value: string);
begin
  if Value = EmptyStr then
    Directory := GetCurrentDir + '\exportfiles'
  else
    Directory := Value;
end;

procedure TXmlExport.SetReset(const Value: Boolean);
begin
  Reset := Value;
end;

procedure TXmlExport.ShowExceptionMessage;
begin
  ShowMessage(FExceptionMessage);
end;

procedure TXmlExport.SyncActive(AActive: boolean);
begin
  FActive := AActive;
  Synchronize(Active);
end;

procedure TXmlExport.SyncProgressMax(AMax: integer);
begin
  FProgressMax := AMax;
  Synchronize(ProgressMax);
end;

procedure TXmlExport.SyncProgressText(AMsg: string);
begin
  FProgressText := AMsg;
  Synchronize(ProgressText);
end;

procedure TXmlExport.SyncProgressValue(AValue: integer);
begin
  FProgressValue := AValue;
  Synchronize(ProgressValue);
end;

procedure TXmlExport.SyncShowExceptionMessage(AMsg: string);
begin
  FExceptionMessage := AMsg;
  Synchronize(ShowExceptionMessage);
end;

function TXmlExport.GetGroupingDir(ATemplateDir, AFieldName: string): string;
var
  Field: TField;
begin
  Result := ATemplateDir;
  Field := FQuery.FindField(AFieldName);
  if Field <> nil then
    begin
      Result := ATemplateDir + '\' + Field.FieldName + '_' + EscapeChars(VarToStr(Field.Value), ArrayEscapeChars);
      CreateDir(Result);
    end;
end;

function TXmlExport.GetFilename(ADirectory, AFieldName: string; AInc: integer): string;
var
  Field: TField;
  Filename, FilenameTmp: string;
  J: integer;
begin
  Result := IntToStr(AInc);
  Field := FQuery.FindField(AFieldName);
  if Field <> nil then
    begin
      Filename := EscapeChars(VarToStr(Field.Value), ArrayEscapeChars);
      FilenameTmp := Filename;
      J := 1;
      while FileExists(ADirectory + '\' + Filename + '.xml') do
        begin
          Filename := FilenameTmp + '(' + IntToStr(J) + ')';
          inc(J);
        end;
      Result := Filename;
    end;
end;

procedure TXmlExport.QueryParsing;
var
  I: integer;
  Xml: TNativeXml;
  RowCount: integer;
  ExportDirectory: string;
  Filename: string;
begin
  try
    RowCount := 0;
    SyncActive(True);
    SyncProgressValue(0);
    SyncProgressText('');
    try

      RowCount := QueryRecordCount;

      if not QueryActive(FSql) then
        exit;

      if RowCount = 0 then
        begin
          SyncProgressText('Нет данных для представления');
          exit;
        end;

      CreateDirDef(FDirectory, GetCurrentDir + '\expportfiles');

      SyncProgressMax(RowCount);

      I := 1;

      while not FQuery.Eof do
        begin

          if FReset then
            begin
              SyncProgressValue(0);
              SyncProgressText('Сброс');
              exit;
            end;

            SyncProgressValue(FQuery.RecNo);

            ExportDirectory := GetGroupingDir(FDirectory, FGroupingField);
            Filename := GetFilename(ExportDirectory, FFilenameField, I);

            Xml := TNativeXml.Create(Application);
            try

              Xml.XmlFormat := xfReadable;

              Xml.ReadFromString(FXml);

              if Xml.Root = nil then
                begin
                  SyncProgressText('Некорректный шаблон');
                  exit;
                end;

              XmlParse(FQuery, Xml.Root);

              if FDeleteEmptyNodes then
                Xml.Root.DeleteEmptyNodes;

              if FDeleteDeclaration then
                Xml.Canonicalize;

              try
                Xml.SaveToFile(ExportDirectory + '\' + Filename + '.xml');
              except on e: exception do
                begin
                  SyncShowExceptionMessage(e.Message);
                  exit;
                end;
              end;

            finally
              FreeAndNil(Xml);
            end;

          inc(I);
          FQuery.Next;
        end;

    except on e: exception do
      SyncShowExceptionMessage(e.Message);
    end;

  finally
    if FOpenDirectory then
      ShellExecute(0, 'Explore', PChar(FDirectory), nil, nil, SW_SHOWNORMAL);
    SyncActive(False);
  end;
end;


//##############################################################################
procedure TXmlExport.XmlParse(AQuery: TFDQuery; ANode: TXmlNode);
var
  I, J: integer;
  AttrName, AttrValue: string;
begin
  if ANode = nil then
    exit;
  try
    { перебираем все атрибуты текущей ноды и заменяем значения }
    if ANode.AttributeCount > 0 then
      begin
        for J := 0 to ANode.AttributeCount-1 do
          begin
            AttrName := ANode.AttributeName[J];
            AttrValue := ANode.AttributeValue[J];
            if not(AQuery.FindField(UpperCase(UpperCase(AttrValue))) = nil) then
              Anode.AttributeByName[AttrName].Value := AQuery.FieldByName(UpperCase(AttrValue)).Text;
          end;
      end;
    { если у текущей ноды есть потомки, то парсим }
    if ANode.NodeCount > 0 then
      begin
        for I := 0 to ANode.NodeCount-1 do
          begin
            { если в результатах запроса есть поле с названием значения элемента, то
              подставляем значение этого поля в элемент }
            if not(AQuery.FindField(UpperCase(ANode.Nodes[I].Value)) = nil) then
              ANode.Nodes[I].Value := AQuery.FieldByName(UpperCase(ANode.Nodes[I].Value)).Text;
              { если есть потомки, то уходим в рекурсию }
            if(ANode.Nodes[I].NodeCount > 0)then
              XmlParse(AQuery, ANode.Nodes[I]);
          end;
      end;
  except on E: Exception do
    begin
      SyncShowExceptionMessage(e.Message);
      exit;
    end;
  end;
end;
//##############################################################################

function TXmlExport.QueryActive(ASql: string): Boolean;
var
  I: integer;
begin
  Result := False;
  try
    FQuery.SQL.Text := ASql;
    for I := 0 to FQuery.ParamCount-1 do
      begin
        if FQuery.Params.Items[I].Name = 'STARTDATE' then
          FQuery.ParamByName('STARTDATE').Value := IntToStr(Trunc(FStartDate));

        if FQuery.Params.Items[I].Name = 'ENDDATE' then
          FQuery.ParamByName('ENDDATE').Value := IntToStr(Trunc(FEndDate));
      end;

    FQuery.Active := True;
    if not FQuery.Active then
      exit;

    Result := True;
  except on E: Exception do
    SyncShowExceptionMessage(e.Message);
  end;
end;

procedure TXmlExport.QueryFetchAll;
begin
  try
    FQuery.FetchAll;
  except
  end;
end;

procedure TXmlExport.QueryFirst;
begin
  try
    FQuery.First;
  except
  end;
end;

function TXmlExport.QueryRecordCount: integer;
begin
  Result := 0;
  try
    if not QueryActive('select count(*) from (' +#13#10+ FSql +#13#10+ ')') then
      exit;
    Result := FQuery.FindField('COUNT').AsInteger;
  except
  end;
end;

procedure TXmlExport.QueryReopen;
begin
  try
    FQuery.Close;
    FQuery.Open;
  except
  end;
end;



end.
