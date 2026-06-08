## Gamepads.
##
## Controllers are opened automatically when they connect (the event loop calls
## openGamepad), and the `gamepadpressed`, `gamepadreleased` and `gamepadaxis`
## callbacks report input. You can also poll with `isGamepadDown` and
## `gamepadAxis`. Untested without a controller to hand, but built on the SDL3
## gamepad API.

import std/tables
import backend/sdl

var pads: Table[SDL_JoystickID, ptr SDL_Gamepad]

proc openGamepad*(id: SDL_JoystickID) =
  if id notin pads:
    let g = SDL_OpenGamepad(id)
    if g != nil: pads[id] = g

proc closeGamepad*(id: SDL_JoystickID) =
  if id in pads:
    SDL_CloseGamepad(pads[id])
    pads.del(id)

proc connectedGamepads*(): seq[SDL_JoystickID] =
  for id in pads.keys: result.add id

proc isGamepadDown*(id: SDL_JoystickID, button: SDL_GamepadButton): bool =
  if id in pads: SDL_GetGamepadButton(pads[id], button) else: false

proc gamepadAxis*(id: SDL_JoystickID, axis: SDL_GamepadAxis): float =
  ## Axis value from -1 to 1 (triggers run 0 to 1).
  if id in pads: SDL_GetGamepadAxis(pads[id], axis).float / 32767.0 else: 0.0
