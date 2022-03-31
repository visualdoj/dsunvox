program test5;

//
//  Original source: sunvox_lib-2.0e/sunvox_lib/examples/c/test5.c
//              md5: 369bd2a85363ce7dc78ffeba6e3c98db
//  Ported to pascal by Doj
//

//
// * Using SunVox as a filter for some user-generated signal
//   (with export to WAV)
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
  mod1, mod2, mod3: TSunvoxInt;
  buf, in_buf: Pointer;
  out_frames, out_bytes, cur_frame: TSunvoxInt;
  pos, new_pos: TSunvoxInt;
  size: SizeUInt;
  i: Int32;
  phase, v: TSunvoxInt;
  a: Single;
  in_int16: PInt16;
  in_float32: PSingle;
begin
  SysSetCtrlBreakHandler(@CtrlBreakHandler);

  if sv_load_dll <> 0 then begin
    Writeln(stderr, 'Sunvox loader error: ' + svGetLoaderError);
    Halt(1);
  end;

  flags := SV_INIT_FLAG_USER_AUDIO_CALLBACK or SV_INIT_FLAG_ONE_THREAD;
  if g_sv_sample_type = 2 then begin
    flags := flags or SV_INIT_FLAG_AUDIO_INT16;
  end else
    flags := flags or SV_INIT_FLAG_AUDIO_FLOAT32;
  ver := sv_init(nil, g_sv_sample_rate, g_sv_channels_num, flags);
  if ver >= 0 then begin
    major  := (ver shr 16) and 255;
    minor1 := (ver shr 8 ) and 255;
    minor2 := ver and 255;
    Writeln('SunVox lib version: ', major, '.', minor1, '.', minor2);

    sv_open_slot(0);

    sv_volume(0, 256);
    sv_lock_slot(0);
    mod1 := sv_new_module(0, 'Input', 'Input', 96, 0, 0);
    mod2 := sv_new_module(0, 'Flanger', 'Flanger', 64, 0, 0);
    mod3 := sv_new_module(0, 'Reverb', 'Reverb', 32, 0, 0);
    Writeln('Input: ', mod1);
    Writeln('Flanger: ', mod2);
    Writeln('Reverb: ', mod3);
    sv_connect_module(0, mod1, mod2); //Input -> Flanger
    sv_connect_module(0, mod2, mod3); //Flanger -> Reverb
    sv_connect_module(0, mod3, 0); //Reverb -> Output
    sv_unlock_slot(0);
    sv_update_input();

    //Saving the audio stream to the WAV file:
    //(audio format: 16/32-bit stereo interleaved (LRLRLRLR...))
    Assign(F, 'audio_stream2.wav');
    {$PUSH}{$I-} ReWrite(F); {$POP}
    if IOResult = 0 then begin
      buf    := GetMem(g_sv_buffer_size * g_sv_channels_num * g_sv_sample_type); //Output audio buffer
      in_buf := GetMem(g_sv_buffer_size * g_sv_channels_num * g_sv_sample_type); //Input audio buffer
      out_frames := g_sv_sample_rate * 8; //8 seconds
      out_bytes := out_frames * g_sv_sample_type * g_sv_channels_num;
      cur_frame := 0;

      //WAV header:
      WriteStr('RIFF');
      WriteU32(4 + 24 + 8 + out_bytes);
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
      WriteU32(g_sv_sample_rate * g_sv_channels_num * g_sv_sample_type); //bytes per second
      WriteU16(g_sv_channels_num * g_sv_sample_type); //block align
      WriteU16(g_sv_sample_type * 8); //bits

      //WAV DATA:
      WriteStr('data');
      WriteU32(out_bytes);
      pos := 0;
      while keep_running and (cur_frame < out_frames) do begin
        size := g_sv_buffer_size;
        if cur_frame + size > out_frames then
          size := out_frames - cur_frame;

        //Generate the input:
        if g_sv_sample_type = 2 then begin
          //16bit:
          in_int16 := in_buf;
          for i := 0 to size - 1 do begin
            phase := cur_frame + i;
            a := sin(phase / 4096.0);
            Inc(phase, Round(a * 1024 * 8));
            v := (phase and 511) - 256;
            v := Round(v * 64 * a);
            in_int16[0] := v; //left channel
            in_int16[1] := v; //right channel
            Inc(in_int16, g_sv_channels_num);
          end;
        end else begin
          //32bit float:
          in_float32 := in_buf;
          for i := 0 to size - 1 do begin
            phase := cur_frame + i;
            a := sin(phase / 4096.0);
            Inc(phase, Round(a * 1024 * 8));
            v := (phase and 511) - 256;
            v := Round(v * 64 * a);
            in_float32[0] := v / 32768; //left channel
            in_float32[1] := v / 32768; //right channel
            Inc(in_float32, g_sv_channels_num);
          end;
        end;

        //Send it to SunVox and read the filtered output:
        sv_audio_callback2(
            buf, //output buffer
            size, //output buffer length (frames)
            0, //latency (frames)
            sv_get_ticks(), //output time in system ticks
            Ord(g_sv_sample_type = 4), //input type: 0 - int16; 1 - float32
            g_sv_channels_num, //input channels
            in_buf //input buffer
        );

        Inc(cur_frame, size);

        //Save this data to the file:
        {$PUSH}{$I-} BlockWrite(F, buf^, size * g_sv_channels_num * g_sv_sample_type); {$POP}
        CheckIOResult;

        //Print some info:
        new_pos := (100 * cur_frame) div out_frames;
        if pos <> new_pos then begin
          Writeln(pos, ' %');
          pos := new_pos;
        end;
      end;
      Close(F);
      FreeMem(buf);
      FreeMem(in_buf);
    end else begin
      Writeln('Can''t open the file');
    end;

    sv_close_slot(0);

    sv_deinit();
  end else begin
    Writeln('sv_init() error ', ver);
  end;

  sv_unload_dll;
end.
