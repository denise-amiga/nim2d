# Audio

A sound is a `Source`. You load one from a file and then play it, pause it, change its volume and so on. Loading takes a kind: a static source decodes all the way into memory, which suits short effects you play often, and a streaming source decodes as it plays, which suits music. WAV, OGG, MP3, FLAC and tracker files all work, since SDL_mixer does the decoding.

```nim
let music = n2d.newSource("music.ogg", stStream)
let shot = n2d.newSource("shot.wav", stStatic)
music.setLooping(true)
music.play()
```

The controls are what you would expect. `play` starts a source, or restarts it if it is already going, `pause` and `resume` hold and continue it, `stop` ends it and rewinds, and `rewind` and `seek` move the position, with `tell` reporting it in seconds. `isPlaying` and `isPaused` report the state, and `duration` is the length in seconds.

`setVolume` sets a source's loudness from 0 to 1, and `setPitch` changes its pitch, which also changes its speed since the two move together. `setLooping` decides whether it repeats.

For positional sound, `setPosition` places a source in space so it pans left or right and fades with distance, and `clearPosition` turns that off. The listener sits at the origin by default, and `setListenerPosition` moves it, which shifts every positioned source to match. On the engine itself, `setVolume` is the master volume over everything and `stopAll` stops every source at once.

```nim
shot.setPosition(playerX - enemyX, 0)
shot.play()
```

If the machine has no audio device, which is the usual case on a build server, audio quietly turns itself off and every call here does nothing, so the same code still runs. `audioAvailable` tells you whether sound is on.
