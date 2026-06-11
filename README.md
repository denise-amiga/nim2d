# nim2d

[![Tests](https://github.com/beshrkayali/nim2d/actions/workflows/tests.yml/badge.svg)](https://github.com/beshrkayali/nim2d/actions/workflows/tests.yml)

nim2d is a 2D game framework for Nim, in the spirit of love2d. It is built on SDL3 and SDL's GPU API, licensed under zlib, and runs on macOS, Linux and Windows. It covers drawing (shapes, images, text, canvases, fragment shaders, a transform stack, sprite batches, meshes and particle systems), keyboard, mouse, gamepad and touch input, audio, a seeded random and noise module, CPU pixel buffers, the filesystem, data encoding and compression, window and system controls, background threads, and rigid-body physics through Box2D. The renderer is an SDL_GPU batch renderer. Images load through SDL3_image, text through SDL3_ttf, and sound through SDL3_mixer. Shaders are authored in GLSL and compiled ahead of time to SPIR-V and MSL, so the engine draws on both Vulkan and Metal; `newShader` also accepts Metal Shading Language source directly for Metal-only use.

## Documentation

Guides are in `docs/`, with screenshots rendered by the engine itself. An API reference is generated from the source with `make docs`, and `make serve` builds and serves everything locally. `make shots` re-renders the screenshots.

## Building

You need Nim 2.0 or newer and the SDL3 libraries (SDL3, SDL3_image, SDL3_ttf, SDL3_mixer). The physics module also needs Box2D.

macOS:

```sh
brew install sdl3 sdl3_image sdl3_ttf sdl3_mixer
brew install box2d   # only for physics
```

On Linux, install the SDL3 development packages or build them from source. On Windows, use the prebuilt MinGW development packages. The CI workflow in `.github/workflows/tests.yml` builds them on all three platforms for reference. nim2d uses the [sdl3_nim](https://github.com/dinau/sdl3_nim) binding, pulled in by nimble, with local bindings for SDL3_image, SDL3_ttf and SDL3_mixer. It links SDL3 at build time with `--dynlibOverride` (set in `config.nims`), so the libraries must be installed when you build. Set `NIM2D_SDL_PREFIX` to point at a non-default install location.

## Running

```sh
nimble examples              # build and run examples/all.nim
nim c -r examples/snake.nim  # or any other example
nimble test                  # headless unit tests
```

The examples are listed in `docs/examples.md`.

## Tests

`nimble test` runs the headless suite: math, data, filesystem, image buffers, audio helpers, system queries and thread channels. The physics check needs Box2D and runs on its own with `nim c -r tests/physics_smoke.nim`. CI runs on macOS, Linux and Windows.

## Dependencies

- Nim 2.0 or newer
- SDL3, SDL3_image, SDL3_ttf, SDL3_mixer
- [sdl3_nim](https://github.com/dinau/sdl3_nim), [zippy](https://github.com/guzba/zippy) and [nimcrypto](https://github.com/cheatfate/nimcrypto), pulled in by nimble
- Box2D, only for the physics module
- glslc and the SDL_shadercross CLI, only to regenerate the built-in shaders with `make shaders`

## License

Released under the zlib license.
