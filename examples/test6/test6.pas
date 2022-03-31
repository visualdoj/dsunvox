program test6;

//
//  Original source: sunvox_lib-2.0e/sunvox_lib/examples/c/test6.c
//              md5: e61e329954167581745768793eba13f6
//  Ported to pascal by Doj
//

//
// * Loading different projects into different slots and playing them
//   simultaneously
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
  ver, major, minor1, minor2: TSunvoxInt;
  slot1, slot2, res: TSunvoxInt;
  i: Int32;
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
    Writeln('Current sample rate: ', sv_get_sample_rate());

    slot1 := 0;
    slot2 := 1;
    sv_open_slot(slot1);
    sv_open_slot(slot2);

    res := -1;
    res := sv_load(slot1, 'song01.sunvox');
    if res = 0 then begin
      Writeln('Project 1 loaded.');
    end else
      Writeln('Load error ', res);
    res := sv_load(slot2, 'song02.sunvox');
    if res = 0 then begin
      Writeln('Project 2 loaded.');
    end else
      Writeln('Load error ', res);

    Writeln('Project 1 name: ', sv_get_song_name(slot1));
    Writeln('Project 2 name: ', sv_get_song_name(slot2));

    sv_pause(slot1);
    sv_pause(slot2);

    sv_play_from_beginning(slot1);
    sv_play_from_beginning(slot2);

    i := 0;
    while keep_running do begin
      if i and 1 <> 0 then begin
        sv_resume(slot1);
      end else
        sv_pause(slot1);
      if i and 2 <> 0 then begin
        sv_resume( slot2 );
      end else
        sv_pause( slot2 );
      Writeln('Slot states: ', i and 1 <> 0, ' '
                             , i and 2 <> 0);
      sleep(1000);
      Inc(i);
    end;

    sv_close_slot(slot1);
    sv_close_slot(slot2);
    sv_deinit();
  end else begin
    Writeln('sv_init() error', ver);
  end;

  sv_unload_dll;
end.
