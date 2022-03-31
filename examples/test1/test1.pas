program test1;

//
//  Original source: sunvox_lib-2.0e/sunvox_lib/examples/c/test1.c
//              md5: 7d557f7c272542c3743199af2a806bc9
//  Ported to pascal by Doj
//

//
// * Loading SunVox project (song) from file/memory
// * Displaying information about the project, pattern and modules
// * Sending Note ON/OFF events to the module (synth)
// * Playing the project
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

procedure show_pattern(slot: TSunvoxInt; pat_num: TSunvoxInt);
const
  h2c: PAnsiChar = '0123456789ABCDEF';
var
  nn: Psunvox_note;
  x, y, tracks, lines: TSunvoxInt;
  pat_name: PAnsiChar;
  l, t: Int32;
  evt: array [0 .. 15 - 1] of AnsiChar;
  note_num, vel, module: TSunvoxInt;
begin
  nn := sv_get_pattern_data(slot, pat_num);
  if nn = nil then
    Exit;

  x        := sv_get_pattern_x(slot, pat_num); //time (line number)
  y        := sv_get_pattern_y(slot, pat_num); //vertical position on timeline
  tracks   := sv_get_pattern_tracks(slot, pat_num); //number of tracks
  lines    := sv_get_pattern_lines(slot, pat_num); //number of lines
  pat_name := sv_get_pattern_name(slot, pat_num);
  if pat_name = nil then
    pat_name := '';

  Writeln('Pattern ', pat_num, ' "', pat_name, '": ',
          x, ' ', y, ' ',
          tracks, 'x', lines);

  for t := 0 to tracks - 1 do begin
    Write('NNVVMMCCEEXXYY | ');
  end;
  Writeln;

  for l := 0 to lines - 1 do begin
    for t := 0 to tracks - 1 do begin
      FillChar(evt[0], Length(evt), Ord(' '));
      evt[High(evt)] := #0;
      // Note:
      if (nn^.note > 0) and (nn^.note < 128) then begin
        note_num := nn^.note - 1;
        evt[0] := 'CcDdEFfGgAaB'[note_num mod 12];
        evt[1] := AnsiChar(Ord('0') + note_num div 12); //octave
      end;
      if nn^.note = NOTECMD_NOTE_OFF then begin
        evt[0] := '=';
        evt[1] := '=';
      end;
      //Velocity:
      if nn^.vel <> 0 then begin
        vel := nn^.vel - 1;
        evt[2] := h2c[(vel shr 4) and 15];
        evt[3] := h2c[vel and 15];
      end;
      //Module:
      if nn^.module <> 0 then begin
        module := nn^.module - 1;
        evt[4] := h2c[(module shr 4) and 15];
        evt[5] := h2c[module and 15];
      end;
      //Ctl:
      if nn^.ctl <> 0 then begin
        evt[6] := h2c[(nn^.ctl shr 12) and 15 ];
        evt[7] := h2c[(nn^.ctl shr 8)  and 15 ];
        evt[8] := h2c[(nn^.ctl shr 4)  and 15 ];
        evt[9] := h2c[nn^.ctl and 15];
      end;
      //Ctl val:
      if nn^.ctl_val <> 0 then begin
        evt[10] := h2c[(nn^.ctl_val shr 12) and 15];
        evt[11] := h2c[(nn^.ctl_val shr 8)  and 15];
        evt[12] := h2c[(nn^.ctl_val shr 4)  and 15];
        evt[13] := h2c[nn^.ctl_val and 15];
      end;
      //Show the event:
      Write(PAnsiChar(@evt[0]), ' | ');
      Inc(nn);
    end;
    Writeln;
  end;
end;

var
  LOAD_FROM_FILE: Boolean = True;
  SONG_FILENAME: AnsiString = 'song01.sunvox';
  ver, major, minor1, minor2, res, mm: TSunvoxInt;
  file_size: SizeUInt;
  data: Pointer;
  i, s: Int32;
  flags: UInt32;
  input_slots, output_slots: TSunvoxInt;
  inputs, outputs: PSunvoxInt;
  number_of_inputs, number_of_outputs: TSunvoxInt;
  xy, ft: UInt32;
  x, y, finetune, relnote: TSunvoxInt;
  m: TSunvoxInt;
begin
  SysSetCtrlBreakHandler(@CtrlBreakHandler);

  if sv_load_dll <> 0 then begin
    Writeln(stderr, 'Sunvox loader error: ' + svGetLoaderError);
    Halt(1);
  end;

  if ParamStr(1) <> '' then
    SONG_FILENAME := ParamStr(1);

  ver := sv_init(nil, 44100, 2, 0);
  if ver >= 0 then begin
    major  := (ver shr 16) and 255;
    minor1 := (ver shr 8)  and 255;
    minor2 := ver and 255;
    Writeln('SunVox lib version: ', major, '.', minor1, '.', minor2);
    Writeln('Current sample rate: ', sv_get_sample_rate);

    sv_open_slot(0);

    Writeln('Loading SunVox project file...');
    res := -1;
    if LOAD_FROM_FILE then begin
      //load from file:
      res := sv_load(0, PAnsiChar(SONG_FILENAME));
    end else begin
      //... or load from memory:
      file_size := 0;
      data := load_file(PAnsiChar(SONG_FILENAME), @file_size);
      if data <> nil then begin
        res := sv_load_from_memory(0, data, file_size);
        FreeMem(data);
      end;
    end;

    if res = 0 then begin
      Writeln('Loaded.');
    end else
      Writeln('Load error ', res, '.');

    //Set volume to 100%
    sv_volume(0, 256);

    Writeln('Project name: ', sv_get_song_name(0));
    mm := sv_get_number_of_modules(0);
    Writeln('Number of modules: ', mm);
    for i := 0 to mm - 1 do begin
      flags := sv_get_module_flags(0, i);
      if (flags and SV_MODULE_FLAG_EXISTS) = 0 then
        continue;
      input_slots  := (flags and SV_MODULE_INPUTS_MASK)  shr SV_MODULE_INPUTS_OFF;
      output_slots := (flags and SV_MODULE_OUTPUTS_MASK) shr SV_MODULE_OUTPUTS_OFF;
      inputs  := sv_get_module_inputs(0, i);
      outputs := sv_get_module_outputs(0, i);
      number_of_inputs  := 0;
      number_of_outputs := 0;
      xy := sv_get_module_xy(0, i);
      ft := sv_get_module_finetune(0, i);
      svUnpackModuleXY(xy, x, y);
      svUnpackModuleFinetune(ft, finetune, relnote);
      Writeln('module ', i, ': ', sv_get_module_name(0, i), '; x=', x, ' y=', y, ' finetune=', finetune, ' rel.note=', relnote);
      Writeln('  IO PORTS:');
      for s := 0 to input_slots - 1 do begin
        if inputs[s] >= 0 then begin
          Writeln('  input from module ', inputs[s]);
          Inc(number_of_inputs);
        end;
      end;
      for s := 0 to output_slots - 1 do begin
        if outputs[s] >= 0 then begin
          Writeln('  output to module ', outputs[s]);
          Inc(number_of_outputs);
        end;
      end;
      Writeln('  input slots: ', input_slots,
              '; output slots: ', output_slots,
              '; N of inputs: ', number_of_inputs,
              '; N of outputs: ', number_of_outputs,
              ';');
    end;

    //Show information about the first pattern:
    show_pattern(0, 0);

    //Send two events (Note ON) to the module 'Kicker':
    m := sv_find_module(0, 'Kicker');
    sv_set_event_t(0, 1, 0);
    sv_send_event(0, 0, 64, 129, m + 1, 0, 0); //track 0; note 64; velocity 129 (max);
    Sleep(1000);


    // Play the exact frequency in Hz:
    // (but the actual frequency will depend the module and its parameters)
    //
    // m := sv_find_module(0, 'Generator');
    // sv_send_event(0, 0, NOTECMD_SET_PITCH, 129, m + 1, 0, SV_FREQUENCY_TO_PITCH(440)); //440 Hz
    // Sleep(1000);
    // sv_send_event(0, 0, NOTECMD_NOTE_OFF, 0, 0, 0, 0);
    // Sleep(1000);

    sv_play_from_beginning( 0 );

    while keep_running do begin
      Writeln('Line counter: ',
        sv_get_current_line2(0) / 32,
        ' Module 7 -> ',
        sv_get_module_ctl_name(0, 7, 1), //Get controller name
        ' = ',
        sv_get_module_ctl_value(0, 7, 1, 0) //Get controller value
      );
      Sleep(1000);
    end;

    sv_stop(0);
    sv_close_slot(0);
    sv_deinit;
  end else begin
    Writeln(stderr, 'sv_init() error ', ver);
  end;

  sv_unload_dll;
end.
