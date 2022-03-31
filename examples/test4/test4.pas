program test4;

//
//  Original source: sunvox_lib-2.0e/sunvox_lib/examples/c/test4.c
//              md5: fd3be47b25f8ffb8c98cc69143a2db89
//  Ported to pascal by Doj
//

//
// * Loading SunVox project (song) from file
// * Exporting audio to the WAV file
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
  SONG_FILENAME: AnsiString = 'song01.sunvox';
  g_sv_sample_rate:  TSunvoxInt = 44100; //Hz
  g_sv_channels_num: TSunvoxInt = 2; //1 - mono; 2 - stereo; only stereo supported in the current version
  g_sv_buffer_size:  TSunvoxInt = 1024; //Audio buffer size (number of frames)
  g_sv_sample_type:  TSunvoxInt = 2; //2 - 16bit; 4 - 32bit float;

var
  F: File of Byte;

procedure CheckIOResult;
begin
  if IOResult <> 0 then begin
    Writeln(stderr, 'Failed writing to file, ', FilePos(F));
    Halt(1);
  end;
end;

procedure WriteStr(const S: AnsiString); inline;
begin
  {$PUSH}{$I-} BlockWrite(F, S[1], Length(S)); {$POP}
  CheckIOResult;
end;

procedure WriteU32(Value: UInt32); inline;
begin
  {$PUSH}{$I-} BlockWrite(F, Value, 4); {$POP}
  CheckIOResult;
end;

procedure WriteU16(Value: UInt16); inline;
begin
  {$PUSH}{$I-} BlockWrite(F, Value, 2); {$POP}
  CheckIOResult;
end;

var
  flags: TSunvoxInt;
  ver, major, minor1, minor2: TSunvoxInt;
  frame_size, song_len_frames, song_len_bytes, cur_frame: TSunvoxInt;
  buf: Pointer;
  pos, new_pos: TSunvoxInt;
  frames_num: TSunvoxInt;
begin
  SysSetCtrlBreakHandler(@CtrlBreakHandler);

  if sv_load_dll <> 0 then begin
    Writeln(stderr, 'Sunvox loader error: ' + svGetLoaderError);
    Halt(1);
  end;

  if ParamStr(1) <> '' then
    SONG_FILENAME := ParamStr(1);

  flags := SV_INIT_FLAG_USER_AUDIO_CALLBACK or SV_INIT_FLAG_ONE_THREAD;
  if g_sv_sample_type = 2 then begin
    flags := flags or SV_INIT_FLAG_AUDIO_INT16;
  end else
    flags := flags or SV_INIT_FLAG_AUDIO_FLOAT32;
  ver := sv_init(nil, g_sv_sample_rate, g_sv_channels_num, flags);
  if ver >= 0 then begin
    major  := (ver shr 16) and 255;
    minor1 := (ver shr 8)  and 255;
    minor2 := ver and 255;
    Writeln('SunVox lib version: ', major, '.', minor1, '.', minor2);

    sv_open_slot(0);

    Writeln('Loading SunVox song from file...');
    if sv_load(0, PAnsiChar(SONG_FILENAME)) = 0 then begin
      Writeln('Loaded.');
    end else
      Writeln('Load error.');
    sv_volume(0, 256);

    sv_play_from_beginning(0);

    //Saving the audio stream to the WAV file:
    //(audio format: 16/32-bit stereo interleaved (LRLRLRLR...))
    Assign(F, 'audio_stream.wav');
    {$PUSH}{$I-} ReWrite(F); {$POP}
    if IOResult = 0 then begin
      frame_size := g_sv_channels_num * g_sv_sample_type; //bytes per frame

      buf := GetMem(g_sv_buffer_size * frame_size); //Audio buffer
      song_len_frames := sv_get_song_length_frames(0);
      song_len_bytes := song_len_frames * frame_size;
      cur_frame := 0;

      //WAV header:
      WriteStr('RIFF');
      WriteU32(4 + 24 + 8 + song_len_bytes);
      WriteStr('WAVE');

      //WAV FORMAT:
      WriteStr('fmt ');
      WriteU32(16);
      if g_sv_sample_type = 4 then begin //format
        WriteU16(3);
      end else
        WriteU16(1);
      WriteU16(g_sv_channels_num); //channels
      WriteU32(g_sv_sample_rate); //frames per second
      WriteU32(g_sv_sample_rate * frame_size); //bytes per second
      WriteU16(frame_size); //block align
      WriteU16(g_sv_sample_type * 8); //bits

      //WAV DATA:
      WriteStr('data');
      WriteU32(song_len_bytes);
      pos := 0;
      while keep_running and (cur_frame < song_len_frames) do begin
        //Get the next piece of audio:
        frames_num := g_sv_buffer_size;
        if cur_frame + frames_num > song_len_frames then
          frames_num := song_len_frames - cur_frame;
        sv_audio_callback(buf, frames_num, 0, sv_get_ticks());
        Inc(cur_frame, frames_num);

        //Save this data to the file:
        {$PUSH}{$I-} BlockWrite(F, buf^, frames_num * frame_size); {$POP}
        CheckIOResult;

        //Print some info:
        new_pos := (cur_frame * 100) div song_len_frames;
        if pos <> new_pos then begin
          Writeln('Playing position: ', pos, ' %');
          pos := new_pos;
        end;
      end;
      Close(F);
      FreeMem(buf);
    end else begin
      Writeln(stderr, 'Can''t open the file');
    end;

    sv_stop(0);

    sv_close_slot(0);

    sv_deinit;
  end else begin
    Writeln('sv_init() error ', ver);
  end;

  sv_unload_dll;
end.
