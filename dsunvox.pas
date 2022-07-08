unit dsunvox;
// -- by Doj, public domain
//    (see implementation section for full license)

//
//  Port of header for the sunvox library 2.0.
//

{$MODE FPC}
{$PACKRECORDS C}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  dynlibs;

const
  NOTECMD_NOTE_OFF        = 128;
  NOTECMD_ALL_NOTES_OFF   = 129; // send "note off" to all modules
  NOTECMD_CLEAN_SYNTHS    = 130; // put all modules into standby
                                 // state (stop and clear all internal buffers)
  NOTECMD_STOP            = 131;
  NOTECMD_PLAY            = 132;
  NOTECMD_SET_PITCH       = 133; // set the pitch specified in column XXYY,
                                 // where 0x0000 - highest possible pitch,
                                 // 0x7800 - lowest pitch (note C0); one semitone = 0x100
type
Psunvox_note = ^sunvox_note;
sunvox_note = record
  note:     UInt8;  // NN: 0 - nothing;
                    //     1..127 - note num;
                    //     128 - note off;
                    //     129, 130... - see NOTECMD_* defines
  vel:      UInt8;  // VV: Velocity 1..129; 0 - default
  module:   UInt16; // MM: 0 - nothing; 1..65535 - module number + 1
  ctl:      UInt16; // 0xCCEE: CC: 1..127 - controller number + 1; EE - effect
  ctl_val:  UInt16; // 0xXXYY: controller value or effect parameter
end;

// Flags for sv_init():
const
  SV_INIT_FLAG_NO_DEBUG_OUTPUT = 1 shl 0;
  SV_INIT_FLAG_USER_AUDIO_CALLBACK = 1 shl 1;
        // Offline mode:
        // system-dependent audio stream will not be created;
        // user calls sv_audio_callback() to get the next piece of sound stream
  SV_INIT_FLAG_OFFLINE = 1 shl 1;
        // Same as SV_INIT_FLAG_USER_AUDIO_CALLBACK
  SV_INIT_FLAG_AUDIO_INT16 = 1 shl 2;
        // Desired sample type of the output sound stream : int16_t
  SV_INIT_FLAG_AUDIO_FLOAT32 = 1 shl 3;
        // Desired sample type of the output sound stream : float
        // The actual sample type may be different, if SV_INIT_FLAG_USER_AUDIO_CALLBACK is not set
  SV_INIT_FLAG_ONE_THREAD = 1 shl 4;
        // Audio callback and song modification are in single thread
        // Use it with SV_INIT_FLAG_USER_AUDIO_CALLBACK only

// Flags for sv_get_time_map():
const
  SV_TIME_MAP_SPEED = 0;
  SV_TIME_MAP_FRAMECNT = 1;

// Flags for sv_get_module_flags():
const
  SV_MODULE_FLAG_EXISTS   = 1 shl 0;
  SV_MODULE_FLAG_EFFECT   = 1 shl 1;
  SV_MODULE_FLAG_MUTE     = 1 shl 2;
  SV_MODULE_FLAG_SOLO     = 1 shl 3;
  SV_MODULE_FLAG_BYPASS   = 1 shl 4;
  SV_MODULE_INPUTS_OFF    = 16;
  SV_MODULE_INPUTS_MASK   = 255 shl SV_MODULE_INPUTS_OFF;
  SV_MODULE_OUTPUTS_OFF   = 16 + 8;
  SV_MODULE_OUTPUTS_MASK 	= 255 shl SV_MODULE_OUTPUTS_OFF;

const
{$IF Defined(WINDOWS) or Defined(MSWINDOWS)}
    SUNVOX_LIBNAME = 'sunvox.dll';
{$ELSEIF Defined(DARWIN)}
    SUNVOX_LIBNAME = 'sunvox.dylib' ;
{$ELSE} // Linux-like
    SUNVOX_LIBNAME = './sunvox.so';
{$ENDIF}



type
  TSunvoxInt = Int32;       // assume LP64
  PSunvoxInt = ^TSunvoxInt;

//
// Functions
// (use the functions with the label "USE LOCK/UNLOCK" within the sv_lock_slot() / sv_unlock_slot() block only!)
//
var
  sv_init: function (config    : PAnsiChar;
                     freq      : TSunvoxInt;
                     channels  : TSunvoxInt;
                     flags     : UInt32): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_deinit: function: TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      // sv_init(), sv_deinit() - global sound system init/deinit
      // Parameters:
      //   config - string with additional configuration in the following format: "option_name=value|option_name=value";
      //            example: "buffer=1024|audiodriver=alsa|audiodevice=hw:0,0";
      //            use NULL for automatic configuration;
      //   freq - desired sample rate (Hz); min - 44100;
      //          the actual rate may be different, if SV_INIT_FLAG_USER_AUDIO_CALLBACK is not set;
      //   channels - only 2 supported now;
      //   flags - mix of the SV_INIT_FLAG_xxx flags.
      //

  sv_get_sample_rate: function: TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_sample_rate
      //
      //  get current sampling rate (it may differ from the frequency specified
      //  in sv_init())
      //

  sv_update_input: function: TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_update_input() -
      //  handle input ON/OFF requests to enable/disable input ports of the sound card
      //  (for example, after the Input module creation).
      //  Call it from the main thread only, where the SunVox sound stream is not locked.
      //

  sv_audio_callback: function (buf      : Pointer;
                               frames   : TSunvoxInt;
                               latency  : TSunvoxInt;
                               out_time : UInt32): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_audio_callback() - get the next piece of SunVox audio from the Output module.
      //  With sv_audio_callback() you can ignore the built-in SunVox sound output mechanism and use some other sound system.
      //  SV_INIT_FLAG_USER_AUDIO_CALLBACK flag in sv_init() must be set.
      //  Parameters:
      //    buf - destination buffer of type int16_t (if SV_INIT_FLAG_AUDIO_INT16 used in sv_init())
      //          or float (if SV_INIT_FLAG_AUDIO_FLOAT32 used in sv_init());
      //          stereo data will be interleaved in this buffer: LRLR... (LR is a single frame (Left+Right));
      //    frames - number of frames in destination buffer;
      //    latency - audio latency (in frames);
      //    out_time - buffer output time (in system ticks);
      //  Return values: 0 - silence, the output buffer is filled with zeros; 1 - the output buffer is filled.
      //  Example 1 (simplified, without accurate time sync) - suitable for most cases:
      //    sv_audio_callback( buf, frames, 0, sv_get_ticks() );
      //  Example 2 (accurate time sync) - when you need to maintain exact time intervals between incoming events (notes, commands, etc.):
      //    user_out_time = ... ; //output time in user time space (depends on your own implementation)
      //    user_cur_time = ... ; //current time in user time space
      //    user_ticks_per_second = ... ; //ticks per second in user time space
      //    user_latency = user_out_time - user_cur_time; //latency in user time space
      //    uint32_t sunvox_latency = ( user_latency * sv_get_ticks_per_second() ) / user_ticks_per_second; //latency in system time space
      //    uint32_t latency_frames = ( user_latency * sample_rate_Hz ) / user_ticks_per_second; //latency in frames
      //    sv_audio_callback( buf, frames, latency_frames, sv_get_ticks() + sunvox_latency );
      //

  sv_audio_callback2: function (buf         : Pointer;
                                frames      : TSunvoxInt;
                                latency     : TSunvoxInt;
                                out_time    : UInt32;
                                in_type     : TSunvoxInt;
                                in_channels : TSunvoxInt;
                                in_buf      : Pointer): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_audio_callback2() - send some data to the Input module and receive the filtered data from the Output module.
      //  It's the same as sv_audio_callback() but you also can specify the input buffer.
      //  Parameters:
      //    ...
      //    in_type - input buffer type: 0 - int16_t (16bit integer); 1 - float (32bit floating point);
      //    in_channels - number of input channels;
      //    in_buf - input buffer; stereo data must be interleaved in this buffer: LRLR... ; where the LR is the one frame (Left+Right channels);
      //

  sv_open_slot: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_close_slot: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_lock_slot: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_unlock_slot: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_open_slot(), sv_close_slot(), sv_lock_slot(), sv_unlock_slot() -
      //  open/close/lock/unlock sound slot for SunVox.
      //  You can use several slots simultaneously (each slot with its own SunVox engine).
      //  Use lock/unlock when you simultaneously read and modify SunVox data from different threads (for the same slot);
      //  example:
      //    thread 1: sv_lock_slot(0); sv_get_module_flags(0,mod1); sv_unlock_slot(0);
      //    thread 2: sv_lock_slot(0); sv_remove_module(0,mod2); sv_unlock_slot(0);
      //  Some functions (marked as "USE LOCK/UNLOCK") can't work without lock/unlock at all.
      //

  sv_load: function (slot: TSunvoxInt;
                     name: PAnsiChar): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_load_from_memory: function (slot      : TSunvoxInt;
                                 data      : Pointer;
                                 data_size : UInt32): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_load(), sv_load_from_memory() -
      //  load SunVox project from the file or from the memory block.
      //

  sv_save: function (slot: TSunvoxInt; name: PAnsiChar): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_save() - save project to the file;
      //

  sv_play: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_play_from_beginning: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_stop: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_pause: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_resume: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_sync_resume: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_play() - play from the current position;
      //  sv_play_from_beginning() - play from the beginning (line 0);
      //  sv_stop(): first call - stop playing; second call - reset all SunVox activity and switch the engine to standby mode;
      //  sv_pause() - pause the audio stream on the specified slot;
      //  sv_resume() - resume the audio stream on the specified slot;
      //  sv_sync_resume() - wait for sync (pattern effect 0x33 on any slot) and resume the audio stream on the specified slot;
      //

  sv_set_autostop: function (slot     : TSunvoxInt;
                             autostop : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_get_autostop: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_set_autostop(), sv_get_autostop() -
      //  autostop values: 0 - disable autostop; 1 - enable autostop.
      //  When autostop is OFF, the project plays endlessly in a loop.
      //

  sv_end_of_song: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_end_of_song() return values: 0 - song is playing now; 1 - stopped.
      //

  sv_rewind: function (slot     : TSunvoxInt;
                       line_num : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  Jump to the specified position (line number on the timeline).
      //
      //  Parameters:
      //
      //      slot / sv - slot number / SunVox object ID;
      //      line_num - line number on the timeline.
      //
      //  Return value: 0 (success) or negative error code.
      //

  sv_volume: function (slot : TSunvoxInt;
                       vol  : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_volume() - set volume from 0 (min) to 256 (max 100%);
      //  negative values are ignored;
      //  return value: previous volume;
      //

  sv_set_event_t: function (slot : TSunvoxInt;
                            _set : TSunvoxInt;
                            t    : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_set_event_t() - set the timestamp of events to be sent by sv_send_event()
      //  Parameters:
      //    slot;
      //    set: 1 - set; 0 - reset (use automatic time setting - the default mode);
      //    t: timestamp (in system ticks).
      //  Examples:
      //    sv_set_event_t( slot, 1, 0 ) //not specified - further events will be processed as quickly as possible
      //    sv_set_event_t( slot, 1, sv_get_ticks() ) //time when the events will be processed = NOW + sound latancy * 2
      //

  sv_send_event: function (slot      : TSunvoxInt;
                           track_num : TSunvoxInt;
                           note      : TSunvoxInt;
                           vel       : TSunvoxInt;
                           module    : TSunvoxInt;
                           ctl       : TSunvoxInt;
                           ctl_val   : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_send_event() - send an event (note ON, note OFF, controller change, etc.)
      //  Parameters:
      //    slot;
      //    track_num - track number within the pattern;
      //    note: 0 - nothing; 1..127 - note num; 128 - note off; 129, 130... - see NOTECMD_xxx defines;
      //    vel: velocity 1..129; 0 - default;
      //    module: 0 (empty) or module number + 1 (1..65535);
      //    ctl: 0xCCEE. CC - number of a controller (1..255). EE - effect;
      //    ctl_val: value of controller or effect.
      //

  sv_get_current_line: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      // Get current line number

  sv_get_current_line2: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      // Get current line number in fixed point format 27.5

  sv_get_current_signal_level: function (slot:    TSunvoxInt;
                                         channel: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      // From 0 to 255

  sv_get_song_name: function (slot: TSunvoxInt): PAnsiChar; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}

  sv_get_song_bpm: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}

  sv_get_song_tpl: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}

  sv_get_song_length_frames: function (slot: TSunvoxInt): UInt32; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_get_song_length_lines: function (slot: TSunvoxInt): UInt32; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_song_length_frames(), sv_get_song_length_lines() -
      //  get the project length.
      //  Frame is one discrete of the sound. Sample rate 44100 Hz means, that you hear 44100 frames per second.
      //

  sv_get_time_map: function (slot       : TSunvoxInt;
                             start_line : TSunvoxInt;
                             len        : TSunvoxInt;
                             dest       : PUInt32;
                             flags      : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_time_map()
      //  Parameters:
      //    slot;
      //    start_line - first line to read (usually 0);
      //    len - number of lines to read;
      //    dest - pointer to the buffer (size = len*sizeof(uint32_t)) for storing the map values;
      //    flags:
      //      SV_TIME_MAP_SPEED: dest[X] = BPM | ( TPL << 16 ) (speed at the beginning of line X);
      //      SV_TIME_MAP_FRAMECNT: dest[X] = frame counter at the beginning of line X;
      //  Return value: 0 if successful, or negative value in case of some error.
      //

//
//  Module functions
//

  sv_new_module: function (slot    : TSunvoxInt;
                           _type   : PAnsiChar;
                           name    : PAnsiChar;
                           x, y, z : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //  create a new module

  sv_remove_module: function (slot    : TSunvoxInt;
                              mod_num : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //  remove selected module

  sv_connect_module: function (slot        : TSunvoxInt;
                               source      : TSunvoxInt;
                               destination : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //  connect the source to the destination

  sv_disconnect_module: function (slot        : TSunvoxInt;
                                  source      : TSunvoxInt;
                                  destination : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //  disconnect the source from the destination;

  sv_load_module: function (slot      : TSunvoxInt;
                            file_name : PAnsiChar;
                            x, y, z   : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //  load a module or sample
      //  supported file formats: sunsynth, xi, wav, aiff
      //  return value: new module number
      //                or negative value in case of some error

  sv_load_module_from_memory: function (slot      : TSunvoxInt;
                                        data      : Pointer;
                                        data_size : UInt32;
                                        x, y, z   : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //  load a module or sample from the memory block;

  sv_sampler_load: function (slot           : TSunvoxInt;
                             sampler_module : TSunvoxInt;
                             file_name      : PAnsiChar;
                             sample_slot    : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //  load a sample to already created Sampler
      //  to replace the whole sampler - set sample_slot to -1

  sv_sampler_load_from_memory: function (slot           : TSunvoxInt;
                                         sampler_module : TSunvoxInt;
                                         data           : Pointer;
                                         data_size      : UInt32;
                                         sample_slot    : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  load a sample from the memory block
      //

  sv_get_number_of_modules: function (slot : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_number_of_modules() - get the number of module slots (not the actual number of modules).
      //  The slot can be empty or it can contain a module.
      //  Here is the code to determine that the module slot X is not empty: ( sv_get_module_flags( slot, X ) & SV_MODULE_FLAG_EXISTS ) != 0;
      //

  sv_find_module: function (slot : TSunvoxInt;
                            name : PAnsiChar): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_find_module() - find a module by name;
      //  return value: module number or -1 (if not found);
      //

  sv_get_module_flags: function (slot    : TSunvoxInt;
                                 mod_num : TSunvoxInt): UInt32; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  Get flags of the specified module.
      //
      //  Return value: SV_MODULE_FLAG_* or -1 (error).
      //

  sv_get_module_inputs : function (slot    : TSunvoxInt;
                                   mod_num : TSunvoxInt): PSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_get_module_outputs: function (slot    : TSunvoxInt;
                                   mod_num : TSunvoxInt): PSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_module_inputs(), sv_get_module_outputs() -
      //  get pointers to the int[] arrays with the input/output links.
      //  Number of input links = ( module_flags & SV_MODULE_INPUTS_MASK ) >> SV_MODULE_INPUTS_OFF.
      //  Number of output links = ( module_flags & SV_MODULE_OUTPUTS_MASK ) >> SV_MODULE_OUTPUTS_OFF.
      //  (this is not the actual number of connections: some links may be empty (value = -1))
      //

  sv_get_module_name: function (slot    : TSunvoxInt;
                                mod_num : TSunvoxInt): PAnsiChar; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}

  sv_get_module_xy: function (slot    : TSunvoxInt;
                              mod_num : TSunvoxInt): UInt32; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_module_xy() - get module XY coordinates packed in a single uint32 value:
      //  ( x & 0xFFFF ) | ( ( y & 0xFFFF ) << 16 )
      //  Normal working area: 0x0 ... 1024x1024
      //  Center: 512x512
      //  Use svUnpackModuleXY() macro to unpack X and Y.
      //

  sv_get_module_color: function (slot     : TSunvoxInt;
                                 mod_num  : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_module_color() - get module color in the following format: 0xBBGGRR
      //

  sv_get_module_finetune: function (slot    : TSunvoxInt;
                                    mod_num : TSunvoxInt): UInt32; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_module_finetune() - get the relative note and finetune of the module;
      //  return value: ( finetune & 0xFFFF ) | ( ( relative_note & 0xFFFF ) << 16 ).
      //  Use svUnpackModuleFinetune() function to unpack finetune and relative_note.
      //

  sv_get_module_scope2: function (slot            : TSunvoxInt;
                                  mod_num         : TSunvoxInt;
                                  channel         : TSunvoxInt;
                                  dest_buf        : PInt16;
                                  samples_to_read : UInt32): UInt32; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_module_scope2() return value = received number of samples (may be less or equal to samples_to_read).
      //  Example:
      //    int16_t buf[ 1024 ];
      //    int received = sv_get_module_scope2( slot, mod_num, 0, buf, 1024 );
      //    //buf[ 0 ] = value of the first sample (-32768...32767);
      //    //buf[ 1 ] = value of the second sample;
      //    //...
      //    //buf[ received - 1 ] = value of the last received sample;
      //

  sv_module_curve: function (slot       : TSunvoxInt;
                             mod_num    : TSunvoxInt;
                             curve_num  : TSunvoxInt;
                             data       : PSingle;
                             len        : TSunvoxInt;
                             w          : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_module_curve() - access to the curve values of the specified module
      //  Parameters:
      //    slot;
      //    mod_num - module number;
      //    curve_num - curve number;
      //    data - destination or source buffer;
      //    len - number of items to read/write;
      //    w - read (0) or write (1).
      //  return value: number of items processed successfully.
      //
      //  Available curves (Y=CURVE[X]):
      //    MultiSynth:
      //      0 - X = note (0..127); Y = velocity (0..1); 128 items;
      //      1 - X = velocity (0..256); Y = velocity (0..1); 257 items;
      //      2 - X = note (0..127); Y = pitch (0..1); 128 items;
      //          pitch range: 0 ... 16384/65535 (note0) ... 49152/65535 (note128) ... 1; semitone = 256/65535;
      //    WaveShaper:
      //      0 - X = input (0..255); Y = output (0..1); 256 items;
      //    MultiCtl:
      //      0 - X = input (0..256); Y = output (0..1); 257 items;
      //    Analog Generator, Generator:
      //      0 - X = drawn waveform sample number (0..31); Y = volume (-1..1); 32 items;
      //

  sv_get_number_of_module_ctls: function (slot    : TSunvoxInt;
                                          mod_num : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}

  sv_get_module_ctl_name: function (slot    : TSunvoxInt;
                                    mod_num : TSunvoxInt;
                                    ctl_num : TSunvoxInt): PAnsiChar; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}

  sv_get_module_ctl_value: function (slot     : TSunvoxInt;
                                     mod_num  : TSunvoxInt;
                                     ctl_num  : TSunvoxInt;
                                     scaled   : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}

  sv_get_number_of_patterns: function (slot: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_number_of_patterns() - get the number of pattern slots (not the actual number of patterns).
      //  The slot can be empty or it can contain a pattern.
      //  Here is the code to determine that the pattern slot X is not empty: sv_get_pattern_lines( slot, X ) > 0;
      //

  sv_find_pattern: function (slot: TSunvoxInt;
                             name: PAnsiChar): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_find_pattern() - find a pattern by name;
      //  return value: pattern number or -1 (if not found);
      //

  sv_get_pattern_x: function (slot: TSunvoxInt; pat_num: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_get_pattern_y: function (slot: TSunvoxInt; pat_num: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_get_pattern_tracks: function (slot: TSunvoxInt; pat_num: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_get_pattern_lines: function (slot: TSunvoxInt; pat_num: TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_get_pattern_name: function (slot: TSunvoxInt; pat_num: TSunvoxInt): PAnsiChar; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_pattern_xxxx - get pattern information
      //  x - time (line number);
      //  y - vertical position on timeline;
      //  tracks - number of pattern tracks;
      //  lines - number of pattern lines;
      //  name - pattern name or NULL;
      //

  sv_get_pattern_data: function (slot     : TSunvoxInt;
                                 pat_num  : TSunvoxInt): Psunvox_note; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_pattern_data() - get the pattern buffer (for reading and writing)
      //  containing notes (events) in the following order:
      //    line 0: note for track 0, note for track 1, ... note for track X;
      //    line 1: note for track 0, note for track 1, ... note for track X;
      //    ...
      //    line X: ...
      //  Example:
      //    int pat_tracks = sv_get_pattern_tracks( slot, pat_num ); //number of tracks
      //    sunvox_note* data = sv_get_pattern_data( slot, pat_num ); //get the buffer with all the pattern events (notes)
      //    sunvox_note* n = &data[ line_number * pat_tracks + track_number ];
      //    ... and then do someting with note n ...
      //

  sv_set_pattern_event: function (slot    : TSunvoxInt;
                                  pat_num : TSunvoxInt;
                                  track   : TSunvoxInt;
                                  line    : TSunvoxInt;
                                  nn      : TSunvoxInt;
                                  vv      : TSunvoxInt;
                                  mm      : TSunvoxInt;
                                  ccee    : TSunvoxInt;
                                  xxyy    : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_set_pattern_event() - write the pattern event to the cell at the specified line and track
      //  nn,vv,mm,ccee,xxyy are the same as the fields of sunvox_note structure.
      //  Only non-negative values will be written to the pattern.
      //  Return value: 0 (sucess) or negative error code.
      //

  sv_get_pattern_event: function (slot    : TSunvoxInt;
                                  pat_num : TSunvoxInt;
                                  track   : TSunvoxInt;
                                  line    : TSunvoxInt;
                                  column  : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_pattern_event() - read a pattern event at the specified line and track
      //  column (field number):
      //     0 - note (NN);
      //     1 - velocity (VV);
      //     2 - module (MM);
      //     3 - controller number or effect (CCEE);
      //     4 - controller value or effect parameter (XXYY);
      //  Return value: value of the specified field or negative error code.
      //

  sv_pattern_mute: function (slot     : TSunvoxInt;
                             pat_num  : TSunvoxInt;
                             mute     : TSunvoxInt): TSunvoxInt; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_pattern_mute() - mute (1) / unmute (0) specified pattern;
      //  negative values are ignored;
      //  return value: previous state (1 - muted; 0 - unmuted) or -1 (error);
      //

  sv_get_ticks: function: UInt32; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
  sv_get_ticks_per_second: function: UInt32; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  SunVox engine uses system-provided time space, measured in system ticks (don't confuse it with the project ticks).
      //  These ticks are required for parameters of functions such as sv_audio_callback() and sv_set_event_t().
      //  Use sv_get_ticks() to get current tick counter (from 0 to 0xFFFFFFFF).
      //  Use sv_get_ticks_per_second() to get the number of system ticks per second.
      //

  sv_get_log: function (size: TSunvoxInt): PAnsiChar; {$IF Defined(WINDOWS) or Defined(MSWINDOWS)}stdcall;{$ELSE}cdecl;{$ENDIF}
      //
      //  sv_get_log() - get the latest messages from the log
      //  Parameters:
      //    size - max number of bytes to read.
      //  Return value: pointer to the null-terminated string with the latest log messages.
      //

procedure svUnpackModuleXY(in_xy: PtrUInt;
                           out out_x, out_y: TSunvoxInt); inline;
      // SV_GET_MODULE_XY in the original API

procedure svUnpackModuleFinetune(in_finetune: PtrUInt;
                                 out out_finetune: TSunvoxInt;
                                 out out_relative_note: TSunvoxInt); inline;
      // SV_GET_MODULE_FINETUNE in the original API

function  SV_PITCH_TO_FREQUENCY(in_pitch: Double): Double; inline;
function  SV_FREQUENCY_TO_PITCH(in_freq: Double): Double; inline;

function sv_load_dll(LibName: PAnsiChar = SUNVOX_LIBNAME): PtrInt;
function sv_unload_dll: PtrInt;

function svGetLoaderError: AnsiString;
      //  Returns human readable error description if sv_load_dll failed.
      //  Returns '' otherwise.

implementation

//  ---------------------------------------------------------------------------
//  This software is available under 2 licenses -- choose whichever you prefer.
//  ---------------------------------------------------------------------------
//  ALTERNATIVE A - MIT License
//  Copyright (c) 2021 Doj
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//  ---------------------------------------------------------------------------
//  ALTERNATIVE B - Public Domain (www.unlicense.org)
//  This is free and unencumbered software released into the public domain.
//  Anyone is free to copy, modify, publish, use, compile, sell, or distribute
//  this software, either in source code form or as a compiled binary, for any
//  purpose, commercial or non-commercial, and by any means.
//  In jurisdictions that recognize copyright laws, the author or authors of
//  this software dedicate any and all copyright interest in the software to
//  the public domain. We make this dedication for the benefit of the public at
//  large and to the detriment of our heirs and successors. We intend this
//  dedication to be an overt act of relinquishment in perpetuity of all
//  present and future rights to this software under copyright law.
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//  ---------------------------------------------------------------------------

var
  SunvoxLibrary: dynlibs.TLibHandle = dynlibs.NilHandle;
  SunvoxLoaderError: AnsiString = '';

procedure svUnpackModuleXY(in_xy: PtrUInt;
                           out out_x, out_y: TSunvoxInt); inline;
begin
  out_x := in_xy and $FFFF;
  if out_x and $8000 <> 0 then
    Dec(out_x, $10000);

  out_y := (in_xy shr 16) and $FFFF;
  if out_y and $8000 <> 0 then
    Dec(out_y, $10000);
end;

procedure svUnpackModuleFinetune(in_finetune: PtrUInt;
                                 out out_finetune: TSunvoxInt;
                                 out out_relative_note: TSunvoxInt); inline;
begin
  out_finetune := in_finetune and $FFFF;
  if out_finetune and $8000 <> 0 then
    Dec(out_finetune, $10000);

  out_relative_note := (in_finetune shr 16) and $FFFF;
  if out_relative_note and $8000 <> 0 then
    Dec(out_relative_note, $10000);
end;

function  SV_PITCH_TO_FREQUENCY(in_pitch: Double): Double; inline;
begin
  Exit(exp(ln(2) * (30720.0 - in_pitch) / 3072.0) * 16.333984375);
end;

function  SV_FREQUENCY_TO_PITCH(in_freq: Double): Double; inline;
begin
  Exit(30720 - ln(in_freq / 16.333984375) / ln(2) * 3072);
end;

function svGetProcAddr(ProcName: PAnsiChar): Pointer;
begin
  Result := GetProcedureAddress(SunvoxLibrary, ProcName);
  if (Result = nil) and (SunvoxLoaderError = '') then begin
    SunvoxLoaderError := 'no function ' + AnsiString(ProcName);
  end;
end;

function sv_load_dll(LibName: PAnsiChar = SUNVOX_LIBNAME): PtrInt;
begin
  SunvoxLoaderError := '';

  SunvoxLibrary := dynlibs.LoadLibrary(LibName);
  if SunvoxLibrary = dynlibs.NilHandle then begin
    SunvoxLoaderError := 'could not load library ' + AnsiString(LibName);
    Exit(-1);
  end;

  Pointer(sv_audio_callback)            := svGetProcAddr('sv_audio_callback');
  Pointer(sv_audio_callback2)           := svGetProcAddr('sv_audio_callback2');
  Pointer(sv_open_slot)                 := svGetProcAddr('sv_open_slot');
  Pointer(sv_close_slot)                := svGetProcAddr('sv_close_slot');
  Pointer(sv_lock_slot)                 := svGetProcAddr('sv_lock_slot');
  Pointer(sv_unlock_slot)               := svGetProcAddr('sv_unlock_slot');
  Pointer(sv_init)                      := svGetProcAddr('sv_init');
  Pointer(sv_deinit)                    := svGetProcAddr('sv_deinit');
  Pointer(sv_get_sample_rate)           := svGetProcAddr('sv_get_sample_rate');
  Pointer(sv_update_input)              := svGetProcAddr('sv_update_input');
  Pointer(sv_load)                      := svGetProcAddr('sv_load');
  Pointer(sv_load_from_memory)          := svGetProcAddr('sv_load_from_memory');
  Pointer(sv_save)                      := svGetProcAddr('sv_save');
  Pointer(sv_play)                      := svGetProcAddr('sv_play');
  Pointer(sv_play_from_beginning)       := svGetProcAddr('sv_play_from_beginning');
  Pointer(sv_stop)                      := svGetProcAddr('sv_stop');
  Pointer(sv_pause)                     := svGetProcAddr('sv_pause');
  Pointer(sv_resume)                    := svGetProcAddr('sv_resume');
  Pointer(sv_sync_resume)               := svGetProcAddr('sv_sync_resume');
  Pointer(sv_set_autostop)              := svGetProcAddr('sv_set_autostop');
  Pointer(sv_get_autostop)              := svGetProcAddr('sv_get_autostop');
  Pointer(sv_end_of_song)               := svGetProcAddr('sv_end_of_song');
  Pointer(sv_rewind)                    := svGetProcAddr('sv_rewind');
  Pointer(sv_volume)                    := svGetProcAddr('sv_volume');
  Pointer(sv_set_event_t)               := svGetProcAddr('sv_set_event_t');
  Pointer(sv_send_event)                := svGetProcAddr('sv_send_event');
  Pointer(sv_get_current_line)          := svGetProcAddr('sv_get_current_line');
  Pointer(sv_get_current_line2)         := svGetProcAddr('sv_get_current_line2');
  Pointer(sv_get_current_signal_level)  := svGetProcAddr('sv_get_current_signal_level');
  Pointer(sv_get_song_name)             := svGetProcAddr('sv_get_song_name');
  Pointer(sv_get_song_bpm)              := svGetProcAddr('sv_get_song_bpm');
  Pointer(sv_get_song_tpl)              := svGetProcAddr('sv_get_song_tpl');
  Pointer(sv_get_song_length_frames)    := svGetProcAddr('sv_get_song_length_frames');
  Pointer(sv_get_song_length_lines)     := svGetProcAddr('sv_get_song_length_lines');
  Pointer(sv_get_time_map)              := svGetProcAddr('sv_get_time_map');
  Pointer(sv_new_module)                := svGetProcAddr('sv_new_module');
  Pointer(sv_remove_module)             := svGetProcAddr('sv_remove_module');
  Pointer(sv_connect_module)            := svGetProcAddr('sv_connect_module');
  Pointer(sv_disconnect_module)         := svGetProcAddr('sv_disconnect_module');
  Pointer(sv_load_module)               := svGetProcAddr('sv_load_module');
  Pointer(sv_load_module_from_memory)   := svGetProcAddr('sv_load_module_from_memory');
  Pointer(sv_sampler_load)              := svGetProcAddr('sv_sampler_load');
  Pointer(sv_sampler_load_from_memory)  := svGetProcAddr('sv_sampler_load_from_memory');
  Pointer(sv_get_number_of_modules)     := svGetProcAddr('sv_get_number_of_modules');
  Pointer(sv_find_module)               := svGetProcAddr('sv_find_module');
  Pointer(sv_get_module_flags)          := svGetProcAddr('sv_get_module_flags');
  Pointer(sv_get_module_inputs)         := svGetProcAddr('sv_get_module_inputs');
  Pointer(sv_get_module_outputs)        := svGetProcAddr('sv_get_module_outputs');
  Pointer(sv_get_module_name)           := svGetProcAddr('sv_get_module_name');
  Pointer(sv_get_module_xy)             := svGetProcAddr('sv_get_module_xy');
  Pointer(sv_get_module_color)          := svGetProcAddr('sv_get_module_color');
  Pointer(sv_get_module_finetune)       := svGetProcAddr('sv_get_module_finetune');
  Pointer(sv_get_module_scope2)         := svGetProcAddr('sv_get_module_scope2');
  Pointer(sv_module_curve)              := svGetProcAddr('sv_module_curve');
  Pointer(sv_get_number_of_module_ctls) := svGetProcAddr('sv_get_number_of_module_ctls');
  Pointer(sv_get_module_ctl_name)       := svGetProcAddr('sv_get_module_ctl_name');
  Pointer(sv_get_module_ctl_value)      := svGetProcAddr('sv_get_module_ctl_value');
  Pointer(sv_get_number_of_patterns)    := svGetProcAddr('sv_get_number_of_patterns');
  Pointer(sv_find_pattern)              := svGetProcAddr('sv_find_pattern');
  Pointer(sv_get_pattern_x)             := svGetProcAddr('sv_get_pattern_x');
  Pointer(sv_get_pattern_y)             := svGetProcAddr('sv_get_pattern_y');
  Pointer(sv_get_pattern_tracks)        := svGetProcAddr('sv_get_pattern_tracks');
  Pointer(sv_get_pattern_lines)         := svGetProcAddr('sv_get_pattern_lines');
  Pointer(sv_get_pattern_name)          := svGetProcAddr('sv_get_pattern_name');
  Pointer(sv_get_pattern_data)          := svGetProcAddr('sv_get_pattern_data');
  Pointer(sv_set_pattern_event)         := svGetProcAddr('sv_set_pattern_event');
  Pointer(sv_get_pattern_event)         := svGetProcAddr('sv_get_pattern_event');
  Pointer(sv_pattern_mute)              := svGetProcAddr('sv_pattern_mute');
  Pointer(sv_get_ticks)                 := svGetProcAddr('sv_get_ticks');
  Pointer(sv_get_ticks_per_second)      := svGetProcAddr('sv_get_ticks_per_second');
  Pointer(sv_get_log)                   := svGetProcAddr('sv_get_log');

  if SunvoxLoaderError <> '' then
    Exit(-2);

  Exit(0);
end;

function sv_unload_dll: PtrInt;
begin
  if SunvoxLibrary <> dynlibs.NilHandle then begin
    dynlibs.UnloadLibrary(SunvoxLibrary);
    SunvoxLibrary := dynlibs.NilHandle;
  end;

  Exit(0);
end;

function svGetLoaderError: AnsiString;
begin
  Exit(SunvoxLoaderError);
end;

end.
