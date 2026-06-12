# Input and timing

.. contents::

Input arrives through callbacks you assign on the engine, the same way as `draw` and `update`.

## Keyboard

`keydown` and `keyup` fire once when a key goes down or comes back up. They hand you a `Key`, a nim2d enum that names the key, used qualified like `Key.escape`, `Key.space` or `Key.a`. A key with no name in the enum arrives as `Key.unknown`.

```nim
n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  if key == Key.escape:
    nim2d.running = false
```

For movement that should continue while a key is held, the callbacks aren't what you want, since they only fire on the edges. Ask `isDown` each frame instead.

```nim
n2d.update = proc(nim2d: Nim2d, dt: float) =
  if isDown(Key.left): x -= 200 * dt
  if isDown(Key.right): x += 200 * dt
```

To receive typed characters, turn on text input with `startTextInput` and set a `textinput` callback. The text arrives already decoded as a UTF-8 string, so a key and its shifted or accented form come through correctly. `stopTextInput` turns it back off.

```nim
n2d.load = proc(nim2d: Nim2d) =
  nim2d.startTextInput()

n2d.textinput = proc(nim2d: Nim2d, text: string) =
  buffer.add text
```

## Mouse

`mousemove` gives the cursor position and how far it moved since the last event. `mousepressed` and `mousereleased` give the position, the button, and how many clicks in quick succession. The button is a `MouseButton`, one of `MouseButton.left`, `.middle`, `.right`, `.x1` or `.x2`. All the coordinates are floats.

```nim
n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  cursorX = x
  cursorY = y

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  if button == MouseButton.left:
    spawnAt(x, y)
```

Like the keyboard, the mouse can be polled instead of waited on. `mousePosition` returns where the cursor is, with `mouseX` and `mouseY` if you only want one, and `isMouseDown` tells you whether a button is held. The scroll wheel comes through a `mousewheel` callback, where y is the usual vertical scroll.

```nim
n2d.mousewheel = proc(nim2d: Nim2d, x, y: float) =
  zoom += y * 0.1

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let m = mousePosition()
  if isMouseDown(MouseButton.left):
    paint(m.x, m.y)
```

The cursor and capture have their own controls. `setMouseVisible` shows or hides the pointer and `isMouseVisible` reports it. `setRelativeMode` captures the mouse and hides the cursor so `mousemove` reports movement deltas without the pointer getting stuck at a screen edge, which is what you want for steering by mouse motion or for mouse-look, and `isRelativeMode` reads it back. `setMouseGrabbed` confines the cursor to the window, `isMouseGrabbed` reads that back, and `setMousePosition` warps the cursor to a spot.

## Gamepads

Controllers are opened for you when they connect. The `gamepadpressed` and `gamepadreleased` callbacks give you the controller id and which button, and `gamepadaxis` gives the id, the axis, and a value from -1 to 1 (triggers go 0 to 1). The button is a `GamepadButton` and the axis a `GamepadAxis`, both named for an Xbox-style pad: the face buttons are `GamepadButton.south`, `.east`, `.west` and `.north` (A, B, X, Y), and the sticks are `GamepadAxis.leftX`, `.leftY` and so on. You can also poll with `isGamepadDown` and `gamepadAxis`, and `connectedGamepads` lists what's plugged in.

```nim
n2d.gamepadpressed = proc(nim2d: Nim2d, id: GamepadId, button: GamepadButton) =
  if button == GamepadButton.south:
    jump()
```

## Touch

Touch arrives the same two ways. The `touchpressed`, `touchmoved` and `touchreleased` callbacks each give a finger id, the position in pixels, and the pressure, so multi-touch is a matter of keeping the ids apart. `getTouches` polls the live set of fingers instead, returning the same fields for every finger currently down. On a desktop the trackpad usually shows up as a touch device, which is handy for trying it out.

```nim
n2d.touchpressed = proc(nim2d: Nim2d, id: int64, x, y, pressure: float) =
  rippleAt(x, y)

n2d.update = proc(nim2d: Nim2d, dt: float) =
  for finger in nim2d.getTouches():
    paint(finger.x, finger.y)
```

## Window events

There are callbacks for window changes too, like `window_resized`, `window_focus_gained`, `window_focus_lost`, `window_minimized` and so on, plus `window_close` when someone closes the window. Each one is a `proc(nim2d: Nim2d)`. The quit callback runs once when the loop ends, however it ends, just before everything is torn down, so it is the place to save state.

```nim
n2d.window_focus_lost = proc(nim2d: Nim2d) =
  paused = true
```

## Window control

Beyond `getWidth`, `getHeight` and `getSize`, there are controls for the window itself. `setTitle` sets the title, `setSize` resizes it and `setResizable` decides whether the user can. `setFullscreen` switches to fullscreen and back, and `isFullscreen` reads the state. `minimize`, `maximize` and `restore` do what they say. `getDesktopDimensions` gives the primary display's resolution, `setIcon` takes an ImageData for the window icon, and `showMessageBox` pops up a simple message and waits for it to be dismissed.

```nim
n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  if key == Key.f:
    nim2d.setFullscreen(not nim2d.isFullscreen)
```

`setVSync` turns vertical sync off or back on. With it off the loop runs as fast as it can, which is useful for benchmarking; `dt` keeps everything moving at the right speed either way. Passing `highDpi = true` to `newNim2d` asks for a backing buffer at the display's real pixel resolution, so on a 2x display the drawable, and what `getWidth` and `getHeight` report, is twice the window's point size; `getDPIScale` tells you the ratio, and mouse positions arrive already scaled to match.

## Timing

`update` already receives `dt`, the seconds since the last frame, which is what you multiply speeds by so motion stays the same regardless of frame rate. If you need timing elsewhere, `getTime` returns seconds as a high-resolution number, `getDelta` returns the same `dt` as the last frame, and `getFPS` returns the current frames per second. `sleep` pauses for a number of seconds.

```nim
nim2d.print("fps: " & $int(nim2d.getFPS), 16, 16)
```

## Quitting

Set `nim2d.running` to false to end the loop, or just close the window. Either way the quit callback gets its turn before teardown.
