program test3;

//
//  Original source: sunvox_lib-2.0e/sunvox_lib/examples/c/test3.c
//              md5: 14e7792acdd65e174ed1dbd4f3d78af9
//  Ported to pascal by Doj
//

//
// * Creating a new Sampler and loading XI-file (set of samples) into it
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

uses
  SysUtils, // for Sleep
  dsunvox in '../../dsunvox.pas';

var
  keep_running: Boolean = True;
function CtrlBreakHandler(param: Boolean): Boolean;
begin
  keep_running := False;
  Exit(True);
end;

function load_file(name: PAnsiChar; file_size: PSizeUInt): Pointer;
var
  F: File of Byte;
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

var
  LOAD_FROM_FILE: Boolean = True;
  ver, major, minor1, minor2: TSunvoxInt;
  mod_num: TSunvoxInt;
  size: SizeUInt;
  data: Pointer;
begin
  SysSetCtrlBreakHandler(@CtrlBreakHandler);

  if sv_load_dll <> 0 then begin
    Writeln(stderr, 'Sunvox loader error: ' + svGetLoaderError);
    Halt(1);
  end;

  ver := sv_init(nil, 44100, 2, 0);
  if ver >= 0 then begin
    major  := (ver shr 16) and 255;
    minor1 := (ver shr 8)  and 255;
    minor2 := ver and 255;
    Writeln('SunVox lib version: ', major, '.', minor1, '.', minor2);

    sv_open_slot(0);

    //Create Sampler module:
    sv_lock_slot(0);
    mod_num := sv_new_module(0, 'Sampler', 'Sampler', 0, 0, 0);
    sv_unlock_slot(0);

    if mod_num >= 0 then begin
      Writeln('New module created: ', mod_num);

      //Connect the new module to the Main Output:
      sv_lock_slot(0);
      sv_connect_module(0, mod_num, 0);
      sv_unlock_slot(0);

      //Load a sample:
      if LOAD_FROM_FILE then begin
        //from disk:
        sv_sampler_load(0, mod_num, 'flute.xi', -1);
      end else begin
        //or from the memory buffer:
        size := 0;
        data := load_file('flute.xi', @size);
        if data <> nil then begin
          sv_sampler_load_from_memory(0, mod_num, data, UInt32(size), -1);
          FreeMem(data);
        end;
      end;

      //Send Note ON:
      Writeln('Note ON');
      sv_send_event(0, 0, 64, 128, mod_num + 1, 0, 0);
      Sleep(1000);

      //Send Note OFF:
      Writeln('Note OFF');
      sv_send_event(0, 0, NOTECMD_NOTE_OFF, 0, 0, 0, 0);
      Sleep(1000);
    end else begin
      Writeln(stderr, 'Can''t create the new module\n');
    end;

    while keep_running do begin
      Sleep(1000);
    end;

    sv_close_slot(0);
    sv_deinit();
  end else begin
    Writeln(stderr, 'sv_init() error ', ver);
  end;

  sv_unload_dll;
end.
