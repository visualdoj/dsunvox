program test8;

//
//  Original source: sunvox_lib-2.0e/sunvox_lib/examples/c/test8.c
//              md5: 5dddff29bcf31bbb1a15f6643174a4ea
//  Ported to pascal by Doj
//

//
// * Saving the project to the file
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

var
  ver, major, minor1, minor2, mod_num: TSunvoxInt;
begin
  if sv_load_dll <> 0 then begin
    Writeln(stderr, 'Sunvox loader error: ' + svGetLoaderError);
    Halt(1);
  end;

  ver := sv_init(nil, 44100, 2, 0);
  if ver >= 0 then begin
    major  := (ver shr 16) and 255;
    minor1 := (ver shr 8 ) and 255;
    minor2 := ver and 255;
    Writeln('SunVox lib version: ', major, '.', minor1, '.', minor2);

    sv_open_slot(0);

    //Add some module:
    sv_lock_slot(0);
    mod_num := sv_new_module(0, 'Generator', 'Generator', 0, 0, 0); //create GENERATOR
    sv_connect_module(0, mod_num, 0); //connect GENERATOR to 0.OUTPUT
    sv_unlock_slot(0);

    //Save the project file:
    sv_save(0, 'myproj.sunvox');

    sv_close_slot(0);
    sv_deinit();
  end else begin
    Writeln('sv_init() error ', ver);
  end;

  sv_unload_dll;
end.
