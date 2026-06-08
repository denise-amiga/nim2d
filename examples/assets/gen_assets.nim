## Generates the audio assets used by examples/audio.nim, so they are reproducible
## and free of any licensing question. Run it with `nim c -r gen_assets.nim` from
## this directory to (re)create blip.wav and music.wav.
##
## Both are 16-bit mono PCM WAV, which SDL_mixer decodes natively.
##
## The integer header fields are written in the host's native byte order, so this
## assumes a little-endian host, which is what nim2d targets. WAV is a
## little-endian format, so running this on a big-endian machine would write a
## malformed file.

import std/[math, streams]

const sampleRate = 44100

proc writeWav(path: string, samples: seq[int16]) =
  let s = newFileStream(path, fmWrite)
  doAssert s != nil
  let dataSize = samples.len * 2
  s.write("RIFF")
  s.write(uint32(36 + dataSize))
  s.write("WAVE")
  s.write("fmt ")
  s.write(uint32(16))               # PCM fmt chunk size
  s.write(uint16(1))                # PCM
  s.write(uint16(1))                # mono
  s.write(uint32(sampleRate))
  s.write(uint32(sampleRate * 2))   # byte rate (mono, 16-bit)
  s.write(uint16(2))                # block align
  s.write(uint16(16))               # bits per sample
  s.write("data")
  s.write(uint32(dataSize))
  for v in samples: s.write(v)
  s.close()

proc sample(freq, t, amp: float): int16 =
  int16(clamp(sin(t * freq * TAU) * amp, -1.0, 1.0) * 32000.0)

# A short percussive blip: a single tone with a fast exponential decay.
proc makeBlip(): seq[int16] =
  let dur = 0.18
  let n = int(dur * sampleRate)
  result = newSeq[int16](n)
  for i in 0 ..< n:
    let t = i.float / sampleRate
    let env = exp(-t * 22.0)
    result[i] = sample(880.0, t, env)

# A two second arpeggio that loops cleanly: four notes, each with an envelope
# that returns to zero, so the seam between repeats is silent.
proc makeMusic(): seq[int16] =
  let notes = [261.63, 329.63, 392.0, 523.25]   # C4 E4 G4 C5
  let noteDur = 0.5
  let perNote = int(noteDur * sampleRate)
  result = newSeq[int16](perNote * notes.len)
  for k, freq in notes:
    for i in 0 ..< perNote:
      let t = i.float / sampleRate
      # rise then fall so each note starts and ends near zero
      let env = sin(PI * (i.float / perNote.float)) * 0.5
      result[k * perNote + i] = sample(freq, t, env)

writeWav("blip.wav", makeBlip())
writeWav("music.wav", makeMusic())
echo "wrote blip.wav and music.wav"
