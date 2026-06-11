## Frame timing and the clock.

import backend/sdl
import types

proc getTime*(): float =
  ## Seconds since SDL init, as a high-resolution value.
  float(SDL_GetPerformanceCounter()) / float(SDL_GetPerformanceFrequency())

proc getDelta*(nim2d: Nim2d): float =
  ## Seconds elapsed between the previous two frames.
  nim2d.dt

proc getFPS*(nim2d: Nim2d): float =
  ## The current frames per second, from the last frame's timing.
  nim2d.fps

proc sleep*(seconds: float) =
  ## Pause the calling thread for a number of seconds.
  SDL_Delay(Uint32(seconds * 1000))
