# Input and timing

Input arrives through callbacks you assign on the engine, the same way as `draw` and `update`.

## Keyboard

`keydown` and `keyup` fire once when a key goes down or comes back up. They hand you an `SDL_Scancode`, which names the physical key. The scancode names are re-exported by nim2d, so you can use them directly.

```nim
n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  if scancode == SDL_SCANCODE_ESCAPE:
    nim2d.running = false
```

For movement that should continue while a key is held, the callbacks aren't what you want, since they only fire on the edges. Ask `isKeyDown` each frame instead.

```nim
n2d.update = proc(nim2d: Nim2d, dt: float) =
  if isKeyDown(SDL_SCANCODE_LEFT): x -= 200 * dt
  if isKeyDown(SDL_SCANCODE_RIGHT): x += 200 * dt
```

To receive typed characters, turn on text input with `startTextInput` and set a `textinput` callback. The text arrives already decoded as a UTF-8 string, so a key and its shifted or accented form come through correctly. `stopTextInput` turns it back off.

```nim
n2d.load = proc(nim2d: Nim2d) =
  nim2d.startTextInput()

n2d.textinput = proc(nim2d: Nim2d, text: string) =
  buffer.add text
```

## Mouse

`mousemove` gives the cursor position and how far it moved since the last event. `mousepressed` and `mousereleased` give the position, the button number, and how many clicks in quick succession. Button 1 is left, 2 is middle, 3 is right. All the coordinates are floats.

```nim
n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  cursorX = x
  cursorY = y

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button, clicks: uint8) =
  if button == 1:
    spawnAt(x, y)
```

Like the keyboard, the mouse can be polled instead of waited on. `mousePosition` returns where the cursor is, with `mouseX` and `mouseY` if you only want one, and `isMouseDown` tells you whether a button is held. The scroll wheel comes through a `mousewheel` callback, where y is the usual vertical scroll.

```nim
n2d.mousewheel = proc(nim2d: Nim2d, x, y: float) =
  zoom += y * 0.1

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let m = mousePosition()
  if isMouseDown(1):
    paint(m.x, m.y)
```

## Gamepads

Controllers are opened for you when they connect. The `gamepadpressed` and `gamepadreleased` callbacks give you the controller id and which button, and `gamepadaxis` gives the id, the axis, and a value from -1 to 1 (triggers go 0 to 1). The buttons and axes use the SDL3 names, like `SDL_GAMEPAD_BUTTON_SOUTH` and `SDL_GAMEPAD_AXIS_LEFTX`. You can also poll with `isGamepadDown` and `gamepadAxis`, and `connectedGamepads` lists what's plugged in.

```nim
n2d.gamepadpressed = proc(nim2d: Nim2d, id: SDL_JoystickID, button: SDL_GamepadButton) =
  if button == SDL_GAMEPAD_BUTTON_SOUTH:
    jump()
```

## Window events

There are callbacks for window changes too, like `window_resized`, `window_focus_gained`, `window_focus_lost`, `window_minimized` and so on, plus `window_close` when someone closes the window. Each one is a `proc(nim2d: Nim2d)`. The quit callback runs when the program is shutting down.

```nim
n2d.window_focus_lost = proc(nim2d: Nim2d) =
  paused = true
```

## Timing

`update` already receives `dt`, the seconds since the last frame, which is what you multiply speeds by so motion stays the same regardless of frame rate. If you need timing elsewhere, `getTime` returns seconds as a high-resolution number, `getDelta` returns the same `dt` as the last frame, and `getFPS` returns the current frames per second. `sleep` pauses for a number of seconds.

```nim
nim2d.print("fps: " & $int(nim2d.getFPS), 16, 16)
```

## Quitting

Set `nim2d.running` to false to end the loop, or just close the window.
