## Three scenes and the manager moving between them. A title scene switches to
## the play scene, the play scene pushes a pause scene over itself, and the pause
## scene pops back or returns to the title. Each scene keeps its own state in its
## own fields, draws its own screen, and handles its own input.
##
## The pause scene is the reason for a stack rather than a single current scene.
## It does not clear the screen, so the play scene underneath stays visible and
## the pause panel sits on top of it, because draw runs the whole stack from the
## bottom up.
##
## Title: Enter plays, Esc quits. Play: arrows or WASD move, P or Esc pauses.
## Pause: Enter resumes, M returns to the title.

import std/[math, os, strformat]
import nim2d
import nim2d/scene

const
  W = 800
  H = 600

let n2d =
  newNim2d("nim2d - scene", 100, 60, W.cint, H.cint, (14'u8, 16'u8, 28'u8, 255'u8))
let big = newFont(getAppDir() / "font.ttf", 40)
let mid = newFont(getAppDir() / "font.ttf", 22)
let small = newFont(getAppDir() / "font.ttf", 16)

var scenes: SceneManager

proc centerPrint(n: Nim2d, font: Font, text: string, y: float) =
  n.setFont(font)
  n.print(text, W.float / 2 - font.getSize(text).w.float / 2, y)

type
  TitleScene = ref object of Scene
    t: float

  PlayScene = ref object of Scene
    pos: Vec2
    t: float

  PauseScene = ref object of Scene

# --- title ------------------------------------------------------------------

method enter(s: TitleScene, n: Nim2d) =
  s.t = 0.0

method update(s: TitleScene, n: Nim2d, dt: float) =
  s.t += dt

method draw(s: TitleScene, n: Nim2d) =
  n.clear(14, 16, 28)
  let pulse = 0.6 + 0.4 * sin(s.t * 3.0)
  n.setColor(rgb(int(120 + pulse * 110), int(180 + pulse * 60), 255))
  n.centerPrint(big, "nim2d scenes", H.float / 2 - 80)
  n.setColor(rgb(150, 160, 185))
  n.centerPrint(mid, "press Enter to play", H.float / 2 + 10)
  n.centerPrint(small, "Esc to quit", H.float / 2 + 50)

method keydown(s: TitleScene, n: Nim2d, key: Key) =
  case key
  of Key.enter, Key.space:
    scenes.switch(PlayScene())
  of Key.escape:
    n.running = false
  else:
    discard

# --- play -------------------------------------------------------------------

method enter(s: PlayScene, n: Nim2d) =
  s.pos = (W.float / 2, H.float / 2)
  s.t = 0.0

method update(s: PlayScene, n: Nim2d, dt: float) =
  s.t += dt
  var d: Vec2
  if isDown(Key.left) or isDown(Key.a):
    d.x -= 1
  if isDown(Key.right) or isDown(Key.d):
    d.x += 1
  if isDown(Key.up) or isDown(Key.w):
    d.y -= 1
  if isDown(Key.down) or isDown(Key.s):
    d.y += 1
  s.pos += d.normalized * (300.0 * dt)
  s.pos.x = clamp(s.pos.x, 24.0, W.float - 24.0)
  s.pos.y = clamp(s.pos.y, 24.0, H.float - 24.0)

method draw(s: PlayScene, n: Nim2d) =
  n.clear(18, 28, 24)
  # a faint grid so the motion is easy to read
  n.setColor(rgb(32, 46, 40))
  for gx in countup(0, W, 40):
    n.line(@[(gx.float, 0.0), (gx.float, H.float)], 1.0)
  for gy in countup(0, H, 40):
    n.line(@[(0.0, gy.float), (W.float, gy.float)], 1.0)
  n.withBlend(bmAdd):
    n.setColor(rgb(120, 230, 170).withAlpha(70))
    n.circle(s.pos.x, s.pos.y, 28, true)
  n.setColor(rgb(170, 245, 200))
  n.circle(s.pos.x, s.pos.y, 14, true)
  n.setFont(small)
  n.setColor(rgb(150, 175, 165))
  n.print(&"play   {s.t:5.1f}s", 18, 16)
  n.print("arrows or WASD to move    P or Esc to pause", 18, H.float - 30)

method keydown(s: PlayScene, n: Nim2d, key: Key) =
  case key
  of Key.p, Key.escape:
    scenes.push(PauseScene())
  else:
    discard

# --- pause (an overlay, drawn on top of the play scene) ---------------------

method draw(s: PauseScene, n: Nim2d) =
  # no clear, so the play scene below stays visible under the panel
  n.setColor(rgba(8, 10, 18, 170))
  n.rectangle(0, 0, W.float, H.float, true)
  n.setColor(rgb(150, 170, 255))
  n.rectangle(W.float / 2 - 200, H.float / 2 - 90, 400, 180, false, roundness = 12)
  n.setColor(rgb(220, 228, 248))
  n.centerPrint(mid, "Paused", H.float / 2 - 56)
  n.setColor(rgb(150, 160, 185))
  n.centerPrint(small, "Enter to resume", H.float / 2 - 4)
  n.centerPrint(small, "M for the title", H.float / 2 + 30)

method keydown(s: PauseScene, n: Nim2d, key: Key) =
  case key
  of Key.enter, Key.space:
    scenes.pop()
  of Key.m:
    scenes.pop() # drop the pause overlay
    scenes.switch(TitleScene()) # then replace play with the title
  else:
    discard

# Assign the manager before pushing, so the scenes can reach it through `scenes`
# the moment their enter runs.
scenes = newSceneManager(n2d)
scenes.push(TitleScene())
n2d.play()
