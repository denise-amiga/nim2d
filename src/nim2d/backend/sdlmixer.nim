## Minimal SDL3_mixer 3.x binding (the core sdl3_nim binding doesn't cover it).
## Linked directly via -lSDL3_mixer (see config.nims).
##
## SDL3_mixer 3.x replaced the old SDL2_mixer calls with a track-based model: a
## `MIX_Mixer` owns the device, a `MIX_Audio` is loaded sound data, and a
## `MIX_Track` plays one `MIX_Audio` with its own gain, pitch and position. Only
## the parts nim2d uses are bound here.

import sdl

type
  MIX_Mixer* = object
  MIX_Audio* = object
  MIX_Track* = object

  MIX_Point3D* = object
    x*, y*, z*: cfloat

  MIX_StereoGains* = object
    left*, right*: cfloat

proc MIX_Init*(): bool {.cdecl, importc: "MIX_Init".}
proc MIX_Quit*() {.cdecl, importc: "MIX_Quit".}

proc MIX_CreateMixerDevice*(devid: SDL_AudioDeviceID,
  spec: ptr SDL_AudioSpec): ptr MIX_Mixer {.cdecl, importc: "MIX_CreateMixerDevice".}
proc MIX_DestroyMixer*(mixer: ptr MIX_Mixer) {.cdecl, importc: "MIX_DestroyMixer".}

proc MIX_LoadAudio*(mixer: ptr MIX_Mixer, path: cstring,
  predecode: bool): ptr MIX_Audio {.cdecl, importc: "MIX_LoadAudio".}
proc MIX_DestroyAudio*(audio: ptr MIX_Audio) {.cdecl, importc: "MIX_DestroyAudio".}
proc MIX_GetAudioDuration*(audio: ptr MIX_Audio): Sint64 {.cdecl, importc: "MIX_GetAudioDuration".}
proc MIX_AudioFramesToMS*(audio: ptr MIX_Audio, frames: Sint64): Sint64 {.cdecl, importc: "MIX_AudioFramesToMS".}
proc MIX_AudioMSToFrames*(audio: ptr MIX_Audio, ms: Sint64): Sint64 {.cdecl, importc: "MIX_AudioMSToFrames".}

proc MIX_CreateTrack*(mixer: ptr MIX_Mixer): ptr MIX_Track {.cdecl, importc: "MIX_CreateTrack".}
proc MIX_DestroyTrack*(track: ptr MIX_Track) {.cdecl, importc: "MIX_DestroyTrack".}
proc MIX_SetTrackAudio*(track: ptr MIX_Track, audio: ptr MIX_Audio): bool {.cdecl, importc: "MIX_SetTrackAudio".}

proc MIX_PlayTrack*(track: ptr MIX_Track, options: SDL_PropertiesID): bool {.cdecl, importc: "MIX_PlayTrack".}
proc MIX_StopTrack*(track: ptr MIX_Track, fadeOutFrames: Sint64): bool {.cdecl, importc: "MIX_StopTrack".}
proc MIX_StopAllTracks*(mixer: ptr MIX_Mixer, fadeOutMs: Sint64): bool {.cdecl, importc: "MIX_StopAllTracks".}
proc MIX_PauseTrack*(track: ptr MIX_Track): bool {.cdecl, importc: "MIX_PauseTrack".}
proc MIX_ResumeTrack*(track: ptr MIX_Track): bool {.cdecl, importc: "MIX_ResumeTrack".}
proc MIX_TrackPlaying*(track: ptr MIX_Track): bool {.cdecl, importc: "MIX_TrackPlaying".}
proc MIX_TrackPaused*(track: ptr MIX_Track): bool {.cdecl, importc: "MIX_TrackPaused".}

proc MIX_SetTrackPlaybackPosition*(track: ptr MIX_Track, frames: Sint64): bool {.cdecl, importc: "MIX_SetTrackPlaybackPosition".}
proc MIX_GetTrackPlaybackPosition*(track: ptr MIX_Track): Sint64 {.cdecl, importc: "MIX_GetTrackPlaybackPosition".}
proc MIX_TrackMSToFrames*(track: ptr MIX_Track, ms: Sint64): Sint64 {.cdecl, importc: "MIX_TrackMSToFrames".}
proc MIX_TrackFramesToMS*(track: ptr MIX_Track, frames: Sint64): Sint64 {.cdecl, importc: "MIX_TrackFramesToMS".}

proc MIX_SetTrackLoops*(track: ptr MIX_Track, numLoops: cint): bool {.cdecl, importc: "MIX_SetTrackLoops".}
proc MIX_GetTrackLoops*(track: ptr MIX_Track): cint {.cdecl, importc: "MIX_GetTrackLoops".}

proc MIX_SetTrackGain*(track: ptr MIX_Track, gain: cfloat): bool {.cdecl, importc: "MIX_SetTrackGain".}
proc MIX_GetTrackGain*(track: ptr MIX_Track): cfloat {.cdecl, importc: "MIX_GetTrackGain".}
proc MIX_SetMixerGain*(mixer: ptr MIX_Mixer, gain: cfloat): bool {.cdecl, importc: "MIX_SetMixerGain".}
proc MIX_GetMixerGain*(mixer: ptr MIX_Mixer): cfloat {.cdecl, importc: "MIX_GetMixerGain".}

proc MIX_SetTrackFrequencyRatio*(track: ptr MIX_Track, ratio: cfloat): bool {.cdecl, importc: "MIX_SetTrackFrequencyRatio".}
proc MIX_GetTrackFrequencyRatio*(track: ptr MIX_Track): cfloat {.cdecl, importc: "MIX_GetTrackFrequencyRatio".}

proc MIX_SetTrack3DPosition*(track: ptr MIX_Track, position: ptr MIX_Point3D): bool {.cdecl, importc: "MIX_SetTrack3DPosition".}
proc MIX_SetTrackStereo*(track: ptr MIX_Track, gains: ptr MIX_StereoGains): bool {.cdecl, importc: "MIX_SetTrackStereo".}

# Play-option property names are C #defines in the header, bound here as consts.
const MIX_PROP_PLAY_LOOPS_NUMBER* = "SDL_mixer.play.loops"
