program test2;

//
//  Original source: sunvox_lib-2.0e/sunvox_lib/examples/c/test2.c
//              md5: faf41e7d829ab88b173e8b49bcd4fec4
//  Ported to pascal by Doj
//

//
// * Creating a new module
// * Loading the module from disk
// * Connecting the module to the main Output
// * Sending some events to the module
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
  mod_num, mod_num2: TSunvoxInt;
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

    //
    // Read curve 0 from MultiSynth:
    //
    // sv_lock_slot( 0 );
    // int multisynth = sv_new_module( 0, 'MultiSynth', 'MultiSynth', 0, 0, 0 );
    // sv_unlock_slot( 0 );
    // float curve_data[ 1024 ];
    // int len = sv_module_curve( 0, multisynth, 1, curve_data, 0, 0 );
    // printf( 'Curve length: %d\n', len );
    // for( int i = 0; i < len; i++ ) printf( '%d: %f\n', i, curve_data[ i ] );
    //

    //Create Generator module:
    sv_lock_slot(0);
    mod_num := sv_new_module(0, 'Generator', 'Generator', 0, 0, 0);
    sv_unlock_slot(0);
    if mod_num >= 0 then begin
      Writeln('New module created: ', mod_num);
      //Connect the new module to the Main Output:
      sv_lock_slot(0);
      sv_connect_module(0, mod_num, 0);
      sv_unlock_slot(0);
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

    //Load module and play it:
    mod_num2 := -1;
    if LOAD_FROM_FILE then begin
        //Load from disk:
        mod_num2 := sv_load_module(0, 'organ.sunsynth', 0, 0, 0);
    end else begin
        //Or load from the memory buffer:
        size := 0;
        data := load_file('organ.sunsynth', @size);
        if data <> nil then begin
          mod_num2 := sv_load_module_from_memory(0, data, UInt32(size), 0, 0, 0);
          FreeMem(data);
        end;
    end;
    if mod_num2 >= 0 then begin
        Writeln('Module loaded: ', mod_num2);
        //Connect the new module to the Main Output:
        sv_lock_slot(0);
        sv_connect_module(0, mod_num2, 0);
        sv_unlock_slot(0);
        //Send Note ON:
        Writeln('Note ON');
        sv_send_event(0, 0, 64, 128, mod_num2 + 1, 0, 0);
        Sleep(1000);
        //Send Note OFF:
        Writeln('Note OFF');
        sv_send_event(0, 0, NOTECMD_NOTE_OFF, 0, 0, 0, 0);
    end else begin
        Writeln(stderr, 'Can''t load the module');
    end;

    Sleep(1000);

    sv_close_slot(0);
    sv_deinit();
  end else begin
    Writeln(stderr, 'sv_init() error ', ver);
  end;

  sv_unload_dll;
end.
