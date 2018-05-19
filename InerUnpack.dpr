program InerUnpack;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.ZLib,
  System.AnsiStrings,

  Winapi.Windows,
  IdZLib,

  System.Zip,

  Xander.Console.Final in 'Xander.Console.Final.pas';

procedure RaiseError(const Text: string);
begin
  WriteLn('[!] Failed to unpack base!');
  WriteLn('[!] Reason: ', Text);
end;

procedure Init;
const
  BASE_SIGNATURE = 'application/x-irenproject.ru-testDocument';
var
  F: File of Byte;

  FileName: string;
  OutputFileName: string;

  &File: TFileStream;

  CRC: Cardinal;
  BaseSize: Int64;
  UBaseSize: Int64;

  BaseData: PByte;

  BaseNameLen: Integer;
  BaseNameStr: UTF8String;

  Decompress: TDecompressionStream;
  Stream: TMemoryStream;
  BytesRead: Integer;

  ZIPFileName: AnsiString;
  ZIPFileNameLen: Integer;

  UData: PByte;
  Data: array[0..1023] of Byte;
begin
  FileName := ParamStr(1);

  if not FileExists(FileName) then
  begin
    RaiseError('File doesn''t exist.');
    Exit;
  end;

  WriteLn('Base File: ', FileName);
  WriteLn('Starting parse...');

  &File := TFileStream.Create(FileName, fmOpenRead);

  &File.Seek(-4, soEnd);
  &File.Read(CRC, SizeOf(CRC));
  WriteLn('Base CRC: $', IntToHex(CRC, 8));

  &File.Seek(-12, soEnd);
  &File.Read(BaseSize, SizeOf(BaseSize));
  WriteLn('Base Size: ', BaseSize);

  &File.Seek(-12 - BaseSize, soEnd);

  BaseData := GetMemory(BaseSize);

  &File.Read(BaseData^, BaseSize);

  if System.AnsiStrings.StrComp(PAnsiChar(BaseData), BASE_SIGNATURE) = 0 then
  begin
    RaiseError('Invalid base signature.');
    Exit;
  end;

  &File.Free;

  Inc(BaseData, Length(BASE_SIGNATURE));
  Dec(BaseSize, Length(BASE_SIGNATURE));

  BaseNameLen := PInteger(BaseData)^;
  Inc(BaseData, SizeOf(Integer));
  Dec(BaseSize, SizeOf(Integer));

  SetLength(BaseNameStr, BaseNameLen);
  Move(BaseData^, BaseNameStr[1], BaseNameLen);
  Inc(BaseData, BaseNameLen);
  Dec(BaseSize, BaseNameLen);

  WriteLn('Base Name: ', BaseNameStr);
  WriteLn;

  WriteLn('Decompressing base...');

  Stream := TMemoryStream.Create;
  Stream.Write(BaseData^, BaseSize);
  Stream.Seek(0, soBeginning);

  Decompress := TDecompressionStream.Create(Stream);

  UData := AllocMem(SizeOf(Data));
  UBaseSize := 0;
  repeat
    BytesRead := Decompress.Read(Data[0], SizeOf(Data));
    Move(Data[0], UData[UBaseSize], BytesRead);

    Inc(UBaseSize, BytesRead);
    UData := ReallocMemory(UData, UBaseSize + SizeOf(Data));
  until BytesRead <> SizeOf(Data);

  UData := ReallocMemory(UData, UBaseSize);

  WriteLn('Base successfully decompressed (', BaseSize, ' -> ', UBaseSize, ')');

  if PInteger(@UData[0])^ <> $04034B50 then
  begin
    RaiseError('Uncompressed base is not a ZIP archive.');
    Exit;
  end;

  ZIPFileNameLen := PWord(@UData[26])^;
  SetLength(ZIPFileName, ZIPFileNameLen);
  Move(UData[30], ZIPFileName[1], ZIPFileNameLen);

  OutputFileName := Format('%s\%s.zip',
    [ExtractFileDir(FileName), ChangeFileExt(string(ZIPFileName), '')]);

  AssignFile(F, OutputFileName);
  ReWrite(F);
  BlockWrite(F, UData^, UBaseSize);
  CloseFile(F);

  WriteLn('Uncompressed ZIP saved to "', OutputFileName, '".');

  Decompress.Free;
end;

begin
  SetConsoleTitle('InerUnpack 1.0.0');

  WriteLn('***********************************************************');
  WriteLn('IrerProject.ru Base Unpacker | 1.0.0 | Alexander B. | 2017');
  WriteLn('***********************************************************');
  WriteLn;

  if ParamCount <> 1 then
  begin
    WriteLn('File is not set. Please, launch software with command line like below.');
    WriteLn('Syntax: ', ExtractFileName(ParamStr(0)), ' <FileName>');
  end
  else
    Init;
end.
