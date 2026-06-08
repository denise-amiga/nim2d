## Mouse polling. The `mousemove`, `mousepressed`, `mousereleased` and
## `mousewheel` callbacks (see events) cover edges; these read the live state.

import backend/sdl
import types

proc mousePosition*(): Vec2 =
  ## Cursor position relative to the window.
  var x, y: cfloat
  discard SDL_GetMouseState(addr x, addr y)
  (x.float, y.float)

proc mouseX*(): float = mousePosition().x
proc mouseY*(): float = mousePosition().y

proc isMouseDown*(button: int = 1): bool =
  ## Whether a mouse button is held. 1 is left, 2 is middle, 3 is right.
  var x, y: cfloat
  let state = SDL_GetMouseState(addr x, addr y)
  let mask = SDL_MouseButtonFlags(1'u32 shl (button - 1))
  (state and mask) != 0
