unit sunvox_examples;
// -- by Doj, public domain

//
//  Utily module for simplifying writing sunvox examples
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  dsunvox;

var
  keep_running: Boolean = True;

function CtrlBreakHandler(param: Boolean): Boolean;

function load_file(name: PAnsiChar; file_size: PSizeUInt): Pointer;



implementation

function CtrlBreakHandler(param: Boolean): Boolean;
begin
  keep_running := False;
  Exit(True);
end;

function load_file(name: PAnsiChar; file_size: PSizeUInt): Pointer;
var
  F: File;
  size: SizeUInt;
begin
  Result := nil;

  Assign(F, name);
{$I-}
  Reset(F);
{$I+}
  if IOResult <> 0 then
    Exit;

  size := FileSize(F); //get file size

  Writeln('file ', name, ' size: ', size, ' bytes\n');
  if size > 0 then begin
    Result := GetMem(size);
    if Result <> nil then begin
      BlockRead(F, Result^, size);
      if file_size <> nil then
        file_size^ := size;
    end;
  end;

  Close(F);
end;

initialization
  SysSetCtrlBreakHandler(@CtrlBreakHandler);

  if sv_load_dll <> 0 then begin
    Writeln(stderr, 'Sunvox loader error: ' + svGetLoaderError);
    Halt(1);
  end;

finalization
  sv_unload_dll;
end.
