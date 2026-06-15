## A scene stack the loop dispatches to, for menus, levels and pause screens.
##
## A game is usually several screens, a title menu, the play field, a pause
## overlay, a game-over screen, each with its own update, draw and input. Wiring
## all of that into one set of callbacks behind a mode flag gets tangled. The
## scene module keeps each screen as its own `Scene`, and a `SceneManager`
## decides which one is live. You override the parts of a scene you care about,
## and the manager calls them at the right time.
##
## A scene is a `ref object of Scene` with methods you override. `enter` and
## `leave` are the setup and teardown hooks, `update` and `draw` run each frame,
## and the input methods (`keydown`, `mousepressed` and the rest) mirror the
## engine callbacks. Every method has a do-nothing default, so you write only the
## ones a scene actually needs, and the scene's own fields hold its state.
##
## The manager holds a stack. `switch` replaces the top scene, `push` lays a new
## one over it, and `pop` drops back to the one beneath, which is how a pause
## screen sits on top of the still-visible game. The top scene gets update and
## input, while draw runs over the whole stack from the bottom up, so an overlay
## that does not clear shows what is under it. `newSceneManager` takes over the
## engine's update, draw and input callbacks, so once it is wired the live scene
## receives everything on its own.
##
## This is an opt-in module, imported on its own with `import nim2d/scene`. The
## core engine does not pull it in.

import types

type Scene* = ref object of RootObj
  ## The base every scene inherits from. Make your own with
  ## `type TitleScene = ref object of Scene`, give it whatever fields it needs to
  ## hold its state, and override the methods below for the behavior you want.

method enter*(scene: Scene, nim2d: Nim2d) {.base.} =
  ## Called when the scene becomes live, from `push` or `switch`. Set up or
  ## reset the scene's state here. The default does nothing.
  discard

method leave*(scene: Scene, nim2d: Nim2d) {.base.} =
  ## Called when the scene stops being live, from `pop`, `switch` or `clear`.
  ## Tear down or save here. The default does nothing.
  discard

method update*(scene: Scene, nim2d: Nim2d, dt: float) {.base.} =
  ## Advance the scene by `dt` seconds. Only the top scene is updated. The
  ## default does nothing.
  discard

method draw*(scene: Scene, nim2d: Nim2d) {.base.} =
  ## Draw the scene. The whole stack is drawn from the bottom up, so a scene
  ## pushed on top draws over the ones below. The default does nothing.
  discard

method keydown*(scene: Scene, nim2d: Nim2d, key: Key) {.base.} =
  ## A key going down, delivered to the top scene. The default does nothing.
  discard

method keyup*(scene: Scene, nim2d: Nim2d, key: Key) {.base.} =
  ## A key coming back up, delivered to the top scene. The default does nothing.
  discard

method mousemove*(scene: Scene, nim2d: Nim2d, x, y, dx, dy: float) {.base.} =
  ## Mouse motion, the position and the distance moved, to the top scene.
  discard

method mousepressed*(
    scene: Scene, nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8
) {.base.} =
  ## A mouse button press, to the top scene. The default does nothing.
  discard

method mousereleased*(
    scene: Scene, nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8
) {.base.} =
  ## A mouse button release, to the top scene. The default does nothing.
  discard

method mousewheel*(scene: Scene, nim2d: Nim2d, x, y: float) {.base.} =
  ## The scroll wheel, to the top scene. The default does nothing.
  discard

method textinput*(scene: Scene, nim2d: Nim2d, text: string) {.base.} =
  ## Typed text as UTF-8, to the top scene, once text input is on. The default
  ## does nothing.
  discard

method gamepadpressed*(
    scene: Scene, nim2d: Nim2d, id: GamepadId, button: GamepadButton
) {.base.} =
  ## A controller button press, to the top scene. The default does nothing.
  discard

method gamepadreleased*(
    scene: Scene, nim2d: Nim2d, id: GamepadId, button: GamepadButton
) {.base.} =
  ## A controller button release, to the top scene. The default does nothing.
  discard

method gamepadaxis*(
    scene: Scene, nim2d: Nim2d, id: GamepadId, axis: GamepadAxis, value: float
) {.base.} =
  ## Stick or trigger motion, to the top scene. The default does nothing.
  discard

type SceneManager* = ref object
  ## Holds the scene stack and routes the engine's
  ## callbacks to it. Make one with `newSceneManager`.
  stack: seq[Scene]
  nim2d: Nim2d

proc push*(mgr: SceneManager, scene: Scene) =
  ## Lay `scene` on top of the stack and call its `enter`. The scene below stays
  ## in place and keeps drawing under it, which is how an overlay like a pause
  ## screen works.
  mgr.stack.add scene
  scene.enter(mgr.nim2d)

proc pop*(mgr: SceneManager) =
  ## Drop the top scene, calling its `leave`, so the one beneath becomes live
  ## again. Does nothing on an empty stack.
  if mgr.stack.len > 0:
    let top = mgr.stack.pop()
    top.leave(mgr.nim2d)

proc switch*(mgr: SceneManager, scene: Scene) =
  ## Replace the top scene with `scene`, calling `leave` on the old top and
  ## `enter` on the new one. Anything deeper in the stack is left alone. On an
  ## empty stack this is the same as `push`.
  if mgr.stack.len > 0:
    let top = mgr.stack.pop()
    top.leave(mgr.nim2d)
  mgr.stack.add scene
  scene.enter(mgr.nim2d)

proc clear*(mgr: SceneManager) =
  ## Drop every scene, calling `leave` on each from the top down, leaving the
  ## stack empty.
  while mgr.stack.len > 0:
    let top = mgr.stack.pop()
    top.leave(mgr.nim2d)

proc current*(mgr: SceneManager): Scene =
  ## The live scene, the one on top of the stack, or `nil` when the stack is
  ## empty.
  if mgr.stack.len > 0:
    mgr.stack[^1]
  else:
    nil

proc count*(mgr: SceneManager): int =
  ## How many scenes are on the stack.
  mgr.stack.len

proc newSceneManager*(nim2d: Nim2d, initial: Scene = nil): SceneManager =
  ## Make a scene manager and point the engine's update, draw and input
  ## callbacks at it, so from here on the live scene receives them. Pass an
  ## `initial` scene to start with, or leave it out and `push` one yourself. An
  ## `initial` scene's `enter` runs during this call, before the manager is
  ## returned, so if that scene's `enter` needs to reach the manager, leave
  ## `initial` out and `push` it once the manager is assigned.
  let mgr = SceneManager(stack: @[], nim2d: nim2d)

  # Route each engine callback to the scene stack. Update and input reach the top
  # scene only; draw runs the whole stack from the bottom up so overlays work.
  nim2d.update = proc(n: Nim2d, dt: float) =
    if mgr.stack.len > 0:
      mgr.stack[^1].update(n, dt)
  nim2d.draw = proc(n: Nim2d) =
    for scene in mgr.stack:
      scene.draw(n)
  nim2d.keydown = proc(n: Nim2d, key: Key) =
    if mgr.stack.len > 0:
      mgr.stack[^1].keydown(n, key)
  nim2d.keyup = proc(n: Nim2d, key: Key) =
    if mgr.stack.len > 0:
      mgr.stack[^1].keyup(n, key)
  nim2d.mousemove = proc(n: Nim2d, x, y, dx, dy: float) =
    if mgr.stack.len > 0:
      mgr.stack[^1].mousemove(n, x, y, dx, dy)
  nim2d.mousepressed = proc(n: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
    if mgr.stack.len > 0:
      mgr.stack[^1].mousepressed(n, x, y, button, clicks)
  nim2d.mousereleased = proc(
      n: Nim2d, x, y: float, button: MouseButton, clicks: uint8
  ) =
    if mgr.stack.len > 0:
      mgr.stack[^1].mousereleased(n, x, y, button, clicks)
  nim2d.mousewheel = proc(n: Nim2d, x, y: float) =
    if mgr.stack.len > 0:
      mgr.stack[^1].mousewheel(n, x, y)
  nim2d.textinput = proc(n: Nim2d, text: string) =
    if mgr.stack.len > 0:
      mgr.stack[^1].textinput(n, text)
  nim2d.gamepadpressed = proc(n: Nim2d, id: GamepadId, button: GamepadButton) =
    if mgr.stack.len > 0:
      mgr.stack[^1].gamepadpressed(n, id, button)
  nim2d.gamepadreleased = proc(n: Nim2d, id: GamepadId, button: GamepadButton) =
    if mgr.stack.len > 0:
      mgr.stack[^1].gamepadreleased(n, id, button)
  nim2d.gamepadaxis = proc(n: Nim2d, id: GamepadId, axis: GamepadAxis, value: float) =
    if mgr.stack.len > 0:
      mgr.stack[^1].gamepadaxis(n, id, axis, value)

  result = mgr
  if initial != nil:
    mgr.push(initial)
