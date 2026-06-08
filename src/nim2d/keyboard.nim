## Keyboard polling and text input.
##
## `keydown` and `keyup` callbacks (see events) tell you about edges. For things
## that should keep happening while a key is held, ask `isKeyDown` each frame.

import backend/sdl
import types

proc isKeyDown*(scancode: SDL_Scancode): bool =
  ## Whether a physical key is currently held down.
  let state = cast[ptr UncheckedArray[bool]](SDL_GetKeyboardState(nil))
  if state == nil: return false
  state[ord(scancode)]

proc startTextInput*(nim2d: Nim2d) =
  ## Begin receiving `textinput` events for typed characters.
  discard SDL_StartTextInput(nim2d.gpu.window)

proc stopTextInput*(nim2d: Nim2d) =
  discard SDL_StopTextInput(nim2d.gpu.window)
