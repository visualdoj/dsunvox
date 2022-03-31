program test7;

//
//  Original source: sunvox_lib-2.0e/sunvox_lib/examples/c/test7.c
//              md5: 42a1d9db5605287a431ec264218f9413
//  Ported to pascal by Doj
//

//
// * Playback synchronization on different slots
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

function load(slot: TSunvoxInt; name: PAnsiChar): TSunvoxInt;
begin
  Result := sv_load(slot, name);
  if Result <> 0 then begin
    Writeln('Can''t load ', name, ': error ', Result, '.');
  end else
    Writeln(name, ' loaded');
end;

var
  ver: TSunvoxInt;
  major, minor1, minor2, slot1, slot2: TSunvoxInt;
  i: Int32;
  p: TSunvoxInt;
begin
  SysSetCtrlBreakHandler(@CtrlBreakHandler);

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

    slot1 := 0;
    slot2 := 1;
    sv_open_slot(slot1);
    sv_open_slot(slot2);

    load(slot1, 'song03.sunvox');
    sv_play_from_beginning(slot1);
    Writeln('Playing slot1...');

    i := 0;
    while keep_running do begin
      Writeln('status: ', sv_end_of_song(slot1) = 0, ' ', sv_end_of_song(slot2) = 0);
      if i = 5 then begin
        //It's time to load and start song04.sunvox on slot2:
        load(slot2, 'song04.sunvox');
        sv_pause(slot2); //make slot2 suspended
        sv_play_from_beginning(slot2); //SLOT2: prepare to play
        Writeln('Prepare to play slot2 (waiting for sync)...');
        p := sv_find_pattern(slot1, 'SYNC'); //SLOT1: find a pattern named "SYNC"
        if p >= 0 then begin
          //Here we use lock/unlock, because it is important to execute the following commands at the same time
          sv_lock_slot(slot1);
          //Write STOP (effect 30) command to the pattern (track 1; line 0):
          sv_set_pattern_event(
            slot1, p,
            1, //track
            0, //line
            -1, //note (NN); skipped
            -1, //velocity (VV); skipped
            -1, //module (MM); skipped
            $0030, //0xCCEE (controller and effect)
            -1 //0xXXYY (ctl/effect parameter); skipped
          );
          sv_sync_resume(slot2); //SLOT2: wait for sync (effect $33 from the "SYNC" pattern) and resume
          sv_unlock_slot(slot1);
        end;
      end;
      if i = 16 then begin
        //Stop slot2 and play slot1:
        sv_pause(slot1); //make slot1 suspended
        p := sv_find_pattern(slot1, 'SYNC'); //SLOT1: find a pattern named "SYNC"
        if p >= 0 then begin
          //Remove STOP (effect 30) command from the pattern (track 1; line 0)
          sv_set_pattern_event(
            slot1, p,
            1, //track
            0, //line
            -1, //note (NN); skipped
            -1, //velocity (VV); skipped
            -1, //module (MM); skipped
            0, //0xCCEE (controller and effect)
            -1 //0xXXYY (ctl/effect parameter); skipped
          );
        end;
        sv_play_from_beginning(slot1); //SLOT1: prepare to play
        Writeln('Prepare to play slot1 again (waiting for sync)...');
        p := sv_find_pattern(slot2, 'SYNC'); //SLOT2: find a pattern named "SYNC"
        if p >= 0 then begin
          sv_lock_slot(slot2);
          //Write STOP (effect 30) command to the pattern (track 1; line 0)
          sv_set_pattern_event(
            slot2, p,
            1, //track
            0, //line
            -1, //note (NN); skipped
            -1, //velocity (VV); skipped
            -1, //module (MM); skipped
            $0030, //0xCCEE (controller and effect)
            -1 //0xXXYY (ctl/effect parameter); skipped
           );
           sv_sync_resume(slot1); //SLOT1: wait for sync (effect 0x33 from the "SYNC" pattern) and resume
           sv_unlock_slot(slot2);
        end;
      end;
      Sleep(1000);
      Inc(i);
    end;

    sv_close_slot(slot1);
    sv_close_slot(slot2);
    sv_deinit();
  end else begin
    Writeln('sv_init() error ', ver);
  end;

  sv_unload_dll;
end.
