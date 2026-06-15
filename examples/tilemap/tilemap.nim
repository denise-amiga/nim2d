## A square you walk and jump around a cave loaded from LDtk. The level, its
## tiles and its collision all come from `AutoLayers_1_basic.ldtk`: the tiles are
## drawn straight from the file, and the IntGrid layer (value 1 = solid) is what
## the player bumps into. Move with A/D or the arrow keys, jump with Space or W
## (you get a second jump in the air), R puts the player back at the start, Esc
## quits. The view is zoomed in and follows the player, so you only see part of
## the cave at a time.
##
## The cave tileset is "Cavernas" by Adam Saltsman
## (https://adamatomic.itch.io/cavernas), released into the public domain.
##
## Everything runs in the level's own pixel space (8px tiles) and is scaled up on
## the way to the screen, which keeps the collision math in whole tiles.

import std/[os, math]
import nim2d
import nim2d/tilemap

const
  W = 832
  H = 576
  MapScale = 5.0 # zoomed in, so the window shows only part of the level
  Grid = 8.0
  PW = 6.0 # the player square, a touch under a tile so it fits 1-wide gaps
  PH = 6.0
  MoveSpeed = 70.0
  Accel = 520.0 # ramp up to MoveSpeed rather than snapping to it
  Friction = 640.0 # and ease back to a stop when there is no input
  Gravity = 420.0
  JumpVel = -135.0
  MaxFall = 180.0 # capped so a fast fall never steps past a 1-tile floor
  MaxJumps = 2 # ground jump plus one in the air
  SolidLayer = "IntGrid_layer"
  Solid = 1

let n2d =
  newNim2d("nim2d - tilemap", 100, 60, W.cint, H.cint, (20'u8, 22'u8, 30'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 15)

let project = loadLdtk(n2d, getAppDir() / "AutoLayers_1_basic.ldtk")
let level = project.levels[0]
for ts in project.tilesets:
  if ts.image != nil:
    ts.image.setFilter(filNearest) # crisp pixels when scaled up

let
  levelW = level.pxWid.float
  levelH = level.pxHei.float

var
  px, py: float
  vx, vy: float
  onGround = false
  jumpsUsed = 0

proc approach(cur, target, maxDelta: float): float =
  ## Move `cur` toward `target` by at most `maxDelta`.
  if cur < target:
    min(cur + maxDelta, target)
  elif cur > target:
    max(cur - maxDelta, target)
  else:
    cur

proc isSolid(cx, cy: int): bool =
  level.intGridAt(SolidLayer, cx, cy) == Solid

proc hits(x, y: float): bool =
  ## Does the player rectangle at (x, y) overlap any solid cell?
  let
    x0 = int(x / Grid)
    x1 = int((x + PW - 0.001) / Grid)
    y0 = int(y / Grid)
    y1 = int((y + PH - 0.001) / Grid)
  for cy in y0 .. y1:
    for cx in x0 .. x1:
      if isSolid(cx, cy):
        return true
  false

proc spawn() =
  ## Start on solid ground near the middle: an empty cell, clear above, with a
  ## solid cell under it.
  let
    cols = level.pxWid div int(Grid)
    rows = level.pxHei div int(Grid)
  var
    best = (cx: cols div 2, cy: 1)
    bestDist = high(int)
  for cy in 1 ..< rows - 1:
    for cx in 0 ..< cols:
      if not isSolid(cx, cy) and not isSolid(cx, cy - 1) and isSolid(cx, cy + 1):
        let d = abs(cx - cols div 2) + abs(cy - rows div 2)
        if d < bestDist:
          bestDist = d
          best = (cx, cy)
  px = best.cx.float * Grid + (Grid - PW) / 2
  py = best.cy.float * Grid + (Grid - PH)
  vx = 0
  vy = 0
  jumpsUsed = 0

spawn()

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  case key
  of Key.space, Key.w, Key.up:
    if jumpsUsed < MaxJumps:
      vy = JumpVel
      inc jumpsUsed
  of Key.r:
    spawn()
  of Key.escape:
    nim2d.running = false
  else:
    discard

n2d.keyup = proc(nim2d: Nim2d, key: Key) =
  # releasing jump while still rising cuts it short, so a tap is a small hop
  case key
  of Key.space, Key.w, Key.up:
    if vy < 0:
      vy = vy * 0.45
  else:
    discard

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let step = min(dt, 0.033) # keep one frame from stepping past a tile

  var dir = 0.0
  if isDown(Key.left) or isDown(Key.a):
    dir -= 1
  if isDown(Key.right) or isDown(Key.d):
    dir += 1
  if dir != 0:
    vx = approach(vx, dir * MoveSpeed, Accel * step)
  else:
    vx = approach(vx, 0.0, Friction * step)
  vy = min(vy + Gravity * step, MaxFall)

  # horizontal move, then snap flush to a wall if it lands inside one
  var nx = clamp(px + vx * step, 0.0, levelW - PW)
  if hits(nx, py):
    if vx > 0:
      nx = floor((nx + PW) / Grid) * Grid - PW
    elif vx < 0:
      nx = (floor(nx / Grid) + 1) * Grid
    vx = 0
  px = nx

  # vertical move, then snap to floor or ceiling
  var ny = clamp(py + vy * step, 0.0, levelH - PH)
  onGround = false
  if hits(px, ny):
    if vy > 0:
      ny = floor((ny + PH) / Grid) * Grid - PH
      onGround = true
    elif vy < 0:
      ny = (floor(ny / Grid) + 1) * Grid
    vy = 0
  py = ny
  if py >= levelH - PH: # the bottom edge of the level acts as ground
    onGround = true
  if onGround:
    jumpsUsed = 0

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.clear(level.bgColor.r, level.bgColor.g, level.bgColor.b)

  # a camera that centers on the player and stops at the edges of the map
  let
    mapW = levelW * MapScale
    mapH = levelH * MapScale
    camX = clamp((px + PW / 2) * MapScale - W.float / 2, 0.0, max(0.0, mapW - W.float))
    camY = clamp((py + PH / 2) * MapScale - H.float / 2, 0.0, max(0.0, mapH - H.float))

  level.draw(nim2d, -camX, -camY, MapScale)

  nim2d.setColor(rgb(245, 190, 80))
  nim2d.rectangle(
    px * MapScale - camX, py * MapScale - camY, PW * MapScale, PH * MapScale, true
  )
  nim2d.setColor(rgb(120, 80, 20))
  nim2d.rectangle(
    px * MapScale - camX, py * MapScale - camY, PW * MapScale, PH * MapScale, false
  )

  nim2d.setColor(rgba(8, 10, 16, 175))
  nim2d.rectangle(8, 8, 388, 30, true, roundness = 6)
  nim2d.setFont(font)
  nim2d.setColor(rgb(230, 235, 245))
  nim2d.print("A/D or arrows    Space to jump (double)    R reset    Esc quit", 18, 14)

n2d.play()
