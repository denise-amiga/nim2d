import std/unittest
import nim2d
import nim2d/scene

# The scene stack is logic, so it tests headlessly on a bare Nim2d with no GPU
# device. A Probe scene records each hook it receives into a shared log, which is
# enough to check what the manager dispatches, in what order, and to whom. The
# probe overrides draw to only record, so nothing actually renders.

var events: seq[string]

type Probe = ref object of Scene
  tag: string

method enter(s: Probe, n: Nim2d) =
  events.add s.tag & ".enter"

method leave(s: Probe, n: Nim2d) =
  events.add s.tag & ".leave"

method update(s: Probe, n: Nim2d, dt: float) =
  events.add s.tag & ".update"

method draw(s: Probe, n: Nim2d) =
  events.add s.tag & ".draw"

method keydown(s: Probe, n: Nim2d, key: Key) =
  events.add s.tag & ".key"

# The remaining input methods record their name and arguments, so a forwarder
# that routes to the wrong method or threads the wrong arguments is caught.

method keyup(s: Probe, n: Nim2d, key: Key) =
  events.add s.tag & ".keyup:" & $key

method mousemove(s: Probe, n: Nim2d, x, y, dx, dy: float) =
  events.add s.tag & ".mousemove:" & $int(x) & "," & $int(y) & "," & $int(dx) & "," &
    $int(dy)

method mousepressed(
    s: Probe, n: Nim2d, x, y: float, button: MouseButton, clicks: uint8
) =
  events.add s.tag & ".mousepressed:" & $int(x) & "," & $int(y) & "," & $button & "," &
    $clicks

method mousereleased(
    s: Probe, n: Nim2d, x, y: float, button: MouseButton, clicks: uint8
) =
  events.add s.tag & ".mousereleased:" & $int(x) & "," & $int(y) & "," & $button & "," &
    $clicks

method mousewheel(s: Probe, n: Nim2d, x, y: float) =
  events.add s.tag & ".mousewheel:" & $int(x) & "," & $int(y)

method textinput(s: Probe, n: Nim2d, text: string) =
  events.add s.tag & ".textinput:" & text

method gamepadpressed(s: Probe, n: Nim2d, id: GamepadId, button: GamepadButton) =
  events.add s.tag & ".gamepadpressed:" & $int(id) & "," & $button

method gamepadreleased(s: Probe, n: Nim2d, id: GamepadId, button: GamepadButton) =
  events.add s.tag & ".gamepadreleased:" & $int(id) & "," & $button

method gamepadaxis(s: Probe, n: Nim2d, id: GamepadId, axis: GamepadAxis, value: float) =
  events.add s.tag & ".gamepadaxis:" & $int(id) & "," & $axis & "," & $value

proc bare(): Nim2d =
  Nim2d(width: 320, height: 240)

suite "scene stack":
  test "push and pop run enter and leave and track current":
    events = @[]
    let mgr = newSceneManager(bare())
    let a = Probe(tag: "A")
    mgr.push(a)
    check mgr.current == a.Scene
    check mgr.count == 1
    check events == @["A.enter"]
    mgr.pop()
    check mgr.count == 0
    check mgr.current == nil
    check events == @["A.enter", "A.leave"]

  test "an initial scene is pushed by the constructor":
    events = @[]
    let mgr = newSceneManager(bare(), Probe(tag: "M"))
    check mgr.count == 1
    check events == @["M.enter"]

  test "update and input reach the top scene only":
    events = @[]
    let n = bare()
    let mgr = newSceneManager(n)
    mgr.push(Probe(tag: "A"))
    mgr.push(Probe(tag: "B"))
    events = @[]
    n.update(n, 0.016)
    n.keydown(n, Key.space)
    check events == @["B.update", "B.key"]

  test "every input forwarder routes to the top scene with its arguments intact":
    events = @[]
    let n = bare()
    let mgr = newSceneManager(n)
    mgr.push(Probe(tag: "A"))
    mgr.push(Probe(tag: "B")) # B is on top
    events = @[]
    n.keyup(n, Key.a)
    n.mousemove(n, 1, 2, 3, 4)
    n.mousepressed(n, 10, 20, MouseButton.right, 2)
    n.mousereleased(n, 11, 21, MouseButton.middle, 1)
    n.mousewheel(n, 5, 6)
    n.textinput(n, "hi")
    n.gamepadpressed(n, GamepadId(7), GamepadButton.south)
    n.gamepadreleased(n, GamepadId(8), GamepadButton.east)
    n.gamepadaxis(n, GamepadId(9), GamepadAxis.leftX, 0.5)
    check events ==
      @[
        "B.keyup:a", "B.mousemove:1,2,3,4", "B.mousepressed:10,20,right,2",
        "B.mousereleased:11,21,middle,1", "B.mousewheel:5,6", "B.textinput:hi",
        "B.gamepadpressed:7,south", "B.gamepadreleased:8,east",
        "B.gamepadaxis:9,leftX,0.5",
      ]

  test "pop reveals the scene beneath as the live one":
    events = @[]
    let n = bare()
    let mgr = newSceneManager(n)
    let a = Probe(tag: "A")
    mgr.push(a)
    mgr.push(Probe(tag: "B"))
    events = @[]
    mgr.pop()
    check events == @["B.leave"]
    check mgr.current == a.Scene
    check mgr.count == 1
    events = @[]
    n.update(n, 0.016)
    n.keydown(n, Key.escape)
    check events == @["A.update", "A.key"]

  test "pop on an empty stack does nothing":
    let mgr = newSceneManager(bare())
    mgr.pop()
    check mgr.count == 0
    check mgr.current == nil

  test "draw runs the whole stack from the bottom up":
    events = @[]
    let n = bare()
    let mgr = newSceneManager(n)
    mgr.push(Probe(tag: "A"))
    mgr.push(Probe(tag: "B"))
    events = @[]
    n.draw(n)
    check events == @["A.draw", "B.draw"]

  test "switch replaces the top and leaves the rest in place":
    events = @[]
    let n = bare()
    let mgr = newSceneManager(n)
    mgr.push(Probe(tag: "A"))
    mgr.push(Probe(tag: "B"))
    events = @[]
    mgr.switch(Probe(tag: "C"))
    check events == @["B.leave", "C.enter"]
    check mgr.count == 2 # A is still underneath
    events = @[]
    n.draw(n)
    check events == @["A.draw", "C.draw"]

  test "switch on an empty stack is just a push":
    events = @[]
    let mgr = newSceneManager(bare())
    mgr.switch(Probe(tag: "A"))
    check mgr.count == 1
    check events == @["A.enter"]

  test "clear leaves every scene from the top down":
    events = @[]
    let mgr = newSceneManager(bare())
    mgr.push(Probe(tag: "A"))
    mgr.push(Probe(tag: "B"))
    events = @[]
    mgr.clear()
    check events == @["B.leave", "A.leave"]
    check mgr.count == 0

  test "an empty manager dispatches to nothing":
    events = @[]
    let n = bare()
    discard newSceneManager(n)
    n.update(n, 0.016)
    n.draw(n)
    n.keydown(n, Key.escape)
    check events.len == 0
