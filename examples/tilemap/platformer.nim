## A square walks, jumps and climbs around a platformer world loaded from LDtk.
## The four levels of the project sit next to each other in world space (one
## above, one below, one to the right of the main one), joined at the ladders, so
## this draws them all at their world positions and lets you roam the whole thing.
## A camera from the camera module follows the player but stays inside the part
## it is in, so it never shows the empty space around a level and the next part
## comes into view as you cross into it.
##
## The level draws several layers, the player starts at the `Player` entity, the
## mobs patrol between the waypoints on their `patrol` field, and touching a mob
## or falling out of a level sends you back to the start. Chests and doors are
## drawn as markers, and the Collisions IntGrid has dirt (1) and stone (3) as
## solid with a ladder value (2) you climb.
##
## A/D or Left/Right move, Space jumps (with a second jump in the air), W/Up and
## S/Down climb a ladder, R puts the player back at the start, Esc quits.
##
## The art is "Sunny Land" by Ansimuz (https://ansimuz.itch.io/sunny-land-pixel-game-art),
## released under CC0.

import std/[os, math]
import nim2d
import nim2d/tilemap
import nim2d/collide
import nim2d/camera

const
  W = 832
  H = 576
  MapScale = 3.0
  Grid = 16.0
  PW = 12.0
  PH = 14.0
  MoveSpeed = 140.0
  Accel = 1040.0
  Friction = 1280.0
  Gravity = 840.0
  JumpVel = -270.0
  MaxFall = 360.0
  ClimbSpeed = 95.0
  MaxJumps = 2
  MobW = 12.0
  MobH = 14.0
  MobSpeed = 55.0
  FollowSpeed = 9.0
  SolidLayer = "Collisions"
  LadderVal = 2

let n2d =
  newNim2d("nim2d - platformer", 100, 60, W.cint, H.cint, (20'u8, 22'u8, 30'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 15)

let project = loadLdtk(n2d, getAppDir() / "Typical_2D_platformer_example.ldtk")
for ts in project.tilesets:
  if ts.image != nil:
    ts.image.setFilter(filNearest)

let cam = newCamera(0, 0, MapScale)

type Mob = object
  x, y, w, h: float
  waypts: seq[float] # the world center-x positions it walks between
  wi: int
  forward: bool

var
  px, py: float # the player, in world pixels
  vx, vy: float
  onGround = false
  climbing = false
  jumpsUsed = 0
  deaths = 0
  mobs: seq[Mob]

proc approach(cur, target, maxDelta: float): float =
  if cur < target:
    min(cur + maxDelta, target)
  elif cur > target:
    max(cur - maxDelta, target)
  else:
    cur

proc worldValue(wx, wy: float): int =
  ## The Collisions value at a world pixel, found in whichever level covers it,
  ## or 0 when no level does.
  for lvl in project.levels:
    if wx >= lvl.worldX.float and wx < float(lvl.worldX + lvl.pxWid) and
        wy >= lvl.worldY.float and wy < float(lvl.worldY + lvl.pxHei):
      return lvl.intGridAt(
        SolidLayer,
        int((wx - lvl.worldX.float) / Grid),
        int((wy - lvl.worldY.float) / Grid),
      )
  0

proc solidAtWorld(wx, wy: float): bool =
  let v = worldValue(wx, wy)
  v == 1 or v == 3 # dirt and stone block, the ladder (2) does not

# the player box is under a tile in size, so its four corners sample every cell
# it can overlap
proc hits(x, y: float): bool =
  solidAtWorld(x, y) or solidAtWorld(x + PW - 0.001, y) or
    solidAtWorld(x, y + PH - 0.001) or solidAtWorld(x + PW - 0.001, y + PH - 0.001)

proc onLadder(x, y: float): bool =
  worldValue(x, y) == LadderVal or worldValue(x + PW - 0.001, y) == LadderVal or
    worldValue(x, y + PH - 0.001) == LadderVal or
    worldValue(x + PW - 0.001, y + PH - 0.001) == LadderVal

proc currentLevel(): LdtkLevel =
  ## The level whose rectangle holds the player's center, or nil when the player
  ## is in the empty space between levels.
  let
    cx = px + PW / 2
    cy = py + PH / 2
  for lvl in project.levels:
    if cx >= lvl.worldX.float and cx < float(lvl.worldX + lvl.pxWid) and
        cy >= lvl.worldY.float and cy < float(lvl.worldY + lvl.pxHei):
      return lvl
  nil

proc currentPart(): string =
  let lvl = currentLevel()
  if lvl != nil: lvl.identifier else: "between"

proc clampCamera(lvl: LdtkLevel) =
  ## Keep the view inside `lvl` so the camera never shows the empty space around
  ## the level. A level smaller than the view is centered in it instead.
  let
    halfW = W.float / 2 / cam.scale
    halfH = H.float / 2 / cam.scale
    lx0 = lvl.worldX.float
    lx1 = float(lvl.worldX + lvl.pxWid)
    ly0 = lvl.worldY.float
    ly1 = float(lvl.worldY + lvl.pxHei)
  cam.x =
    if lx1 - lx0 <= 2 * halfW:
      (lx0 + lx1) / 2
    else:
      clamp(cam.x, lx0 + halfW, lx1 - halfW)
  cam.y =
    if ly1 - ly0 <= 2 * halfH:
      (ly0 + ly1) / 2
    else:
      clamp(cam.y, ly0 + halfH, ly1 - halfH)

proc buildMobs() =
  ## Every mob in the world, at its world position, walking the waypoints from its
  ## `patrol` field.
  mobs = @[]
  for lvl in project.levels:
    for e in lvl.entities("Mob"):
      var wp = @[lvl.worldX.float + e.x]
      for p in e.getPoints("patrol"):
        wp.add lvl.worldX.float + p.cx.float * Grid + Grid / 2
      mobs.add Mob(
        x: lvl.worldX.float + e.x - MobW / 2,
        y: lvl.worldY.float + e.y - MobH,
        w: MobW,
        h: MobH,
        waypts: wp,
        wi: 0,
        forward: true,
      )

proc place() =
  ## Put the player at the world's `Player` entity (its pivot is its feet) and
  ## reset the mobs to their patrol start.
  for lvl in project.levels:
    let ps = lvl.entities("Player")
    if ps.len > 0:
      px = lvl.worldX.float + ps[0].x - PW / 2
      py = lvl.worldY.float + ps[0].y - PH
      break
  vx = 0
  vy = 0
  jumpsUsed = 0
  climbing = false
  buildMobs()

place()
cam.lookAt(px + PW / 2, py + PH / 2)
let startLevel = currentLevel()
if startLevel != nil:
  clampCamera(startLevel)

proc updateMobs(step: float) =
  for m in mobs.mitems:
    if m.waypts.len < 2:
      continue
    let
      target = m.waypts[m.wi]
      cx = m.x + m.w / 2
      d = target - cx
    if abs(d) <= MobSpeed * step:
      m.x = target - m.w / 2
      if m.forward:
        if m.wi == m.waypts.high:
          m.forward = false
          dec m.wi
        else:
          inc m.wi
      else:
        if m.wi == 0:
          m.forward = true
          inc m.wi
        else:
          dec m.wi
    else:
      m.x += (if d > 0: 1.0 else: -1.0) * MobSpeed * step

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  case key
  of Key.space:
    if climbing:
      climbing = false
      vy = JumpVel
      jumpsUsed = 1
    elif jumpsUsed < MaxJumps:
      vy = JumpVel
      inc jumpsUsed
  of Key.r:
    place()
  of Key.escape:
    nim2d.running = false
  else:
    discard

n2d.keyup = proc(nim2d: Nim2d, key: Key) =
  if key == Key.space and vy < 0:
    vy = vy * 0.45

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let step = min(dt, 0.033)
  let
    up = isDown(Key.w) or isDown(Key.up)
    down = isDown(Key.s) or isDown(Key.down)

  var dir = 0.0
  if isDown(Key.left) or isDown(Key.a):
    dir -= 1
  if isDown(Key.right) or isDown(Key.d):
    dir += 1
  if dir != 0:
    vx = approach(vx, dir * MoveSpeed, Accel * step)
  else:
    vx = approach(vx, 0.0, Friction * step)

  if onLadder(px, py) and (up or down):
    climbing = true
  if not onLadder(px, py):
    climbing = false
  if climbing:
    jumpsUsed = 0
    vy =
      if up:
        -ClimbSpeed
      elif down:
        ClimbSpeed
      else:
        0.0
  else:
    vy = min(vy + Gravity * step, MaxFall)

  var nx = px + vx * step
  if hits(nx, py):
    if vx > 0:
      nx = floor((nx + PW) / Grid) * Grid - PW
    elif vx < 0:
      nx = (floor(nx / Grid) + 1) * Grid
    vx = 0
  px = nx

  var ny = py + vy * step
  onGround = false
  if hits(px, ny):
    if vy > 0:
      ny = floor((ny + PH) / Grid) * Grid - PH
      onGround = true
    elif vy < 0:
      ny = (floor(ny / Grid) + 1) * Grid
    vy = 0
  py = ny
  if onGround:
    jumpsUsed = 0

  updateMobs(step)

  # death: falling out of every level, or touching a mob
  var died = currentLevel() == nil
  if not died:
    for m in mobs:
      if rectsOverlap(px, py, PW, PH, m.x, m.y, m.w, m.h):
        died = true
        break
  if died:
    inc deaths
    place()

  # the camera follows the player but stays inside the level it is in
  cam.follow((px + PW / 2, py + PH / 2), dt, FollowSpeed)
  let cl = currentLevel()
  if cl != nil:
    clampCamera(cl)

proc markerColor(identifier: string): Color =
  case identifier
  of "Chest":
    rgb(240, 200, 90)
  of "Door":
    rgb(150, 170, 230)
  else:
    rgb(200, 200, 200)

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.clear(
    project.levels[0].bgColor.r,
    project.levels[0].bgColor.g,
    project.levels[0].bgColor.b,
  )

  nim2d.withCamera(cam):
    # every level at its world position, the camera handles the zoom and scroll
    for lvl in project.levels:
      lvl.draw(nim2d, lvl.worldX.float, lvl.worldY.float)

    # chests and doors as markers, placed by their bounding box (px is the pivot)
    for lvl in project.levels:
      for li in 0 ..< lvl.layers.len:
        for e in lvl.layers[li].entities:
          if e.identifier != "Chest" and e.identifier != "Door":
            continue
          let
            col = markerColor(e.identifier)
            bx = lvl.worldX.float + e.x - e.pivotX * e.width.float
            by = lvl.worldY.float + e.y - e.pivotY * e.height.float
          nim2d.setColor(col.withAlpha(110))
          nim2d.rectangle(bx, by, e.width.float, e.height.float, true, roundness = 2)
          nim2d.setColor(col)
          nim2d.rectangle(bx, by, e.width.float, e.height.float, false, roundness = 2)

    # the mobs, plain red blobs
    for m in mobs:
      nim2d.setColor(rgb(225, 70, 75))
      nim2d.circle(m.x + m.w / 2, m.y + m.h / 2, m.w / 2 * 1.1, true)

    nim2d.setColor(rgb(245, 190, 80))
    nim2d.rectangle(px, py, PW, PH, true)
    nim2d.setColor(rgb(120, 80, 20))
    nim2d.rectangle(px, py, PW, PH, false)

  nim2d.setColor(rgba(8, 10, 16, 180))
  nim2d.rectangle(8, 8, 470, 50, true, roundness = 6)
  nim2d.setFont(font)
  nim2d.setColor(rgb(230, 235, 245))
  nim2d.print("A/D move    Space jump    W/S climb    R reset    Esc quit", 18, 14)
  nim2d.setColor(rgb(160, 170, 195))
  nim2d.print("part: " & currentPart() & "    deaths: " & $deaths, 18, 34)

n2d.play()
