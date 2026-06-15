## The starfield grown into a small fake-3D shmup. Enemies dive at the camera
## over a perspective ground grid, getting bigger as they close in. Steer with
## the arrow keys or the mouse, hold space or the left mouse button to fire,
## and survive waves that keep getting faster and denser. Between waves the
## ship jumps to warp speed on its way to the next stretch of space. R
## restarts after a game over, ESC quits.

import std/[algorithm, math, os, random]
import nim2d

const
  W = 900
  H = 640
  Cx = W / 2
  Cy = H / 2
  Focal = 400.0 # screen = center + world * Focal / depth
  ZFar = 12.0 # enemies spawn this deep
  ZShip = 1.6 # the ship floats just in front of the camera
  ZNear = 1.0 # anything closer has flown past
  StarCount = 300
  ShipRangeX = 1.05
  ShipRangeTop = -0.7
  ShipRangeBottom = 0.88

type
  Star = object
    x, y, z, pz: float

  EnemyKind = enum
    ekDiamond
    ekDart
    ekHex

  Enemy = object
    kind: EnemyKind
    x, y, z: float
    spin: float
    hp: int

  Shot = object
    x, y, z, pz: float

  Shard = object
    x, y, z, vx, vy, rot, spin, life, maxLife: float
    color: Color

var
  stars: seq[Star]
  enemies: seq[Enemy]
  shots: seq[Shot]
  shards: seq[Shard]
  shipX, shipY: float
  tilt: float # -1 to 1, banks the ship while strafing
  mouseTX, mouseTY: float # where the mouse wants the ship, in world units
  mouseActive: bool # the last steering input was the mouse
  score: int
  lives: int
  level: int
  elapsed: float
  spawnIn: float # seconds until the next enemy appears
  cooldown: float # seconds until the gun can fire again
  shield: float # invulnerability left after taking a hit
  gridOff: float # scroll offset of the ground grid rows
  jump: float # warp jump time left
  jumpDur: float # full length of the current jump
  jumpF: float # 0 to 1, how deep into warp the jump is right now
  shake: float # camera shake time left
  dead: bool

randomize()
let n2d =
  newNim2d("nim2d - starfield", 130, 80, W.cint, H.cint, (4'u8, 4'u8, 10'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
let bigFont = newFont(getAppDir() / "font.ttf", 56)
n2d.setFont(font)

proc proj(x, y, z: float): Vec2 =
  (Cx + x * Focal / z, Cy + y * Focal / z)

# Each kind's collision radius in world units, approach speed factor and score.
proc radius(k: EnemyKind): float =
  case k
  of ekDiamond: 0.16
  of ekDart: 0.12
  of ekHex: 0.20

proc pace(k: EnemyKind): float =
  case k
  of ekDiamond: 1.0
  of ekDart: 1.5
  of ekHex: 0.6

proc bounty(k: EnemyKind): int =
  case k
  of ekDiamond: 100
  of ekDart: 150
  of ekHex: 250

proc hue(k: EnemyKind): Color =
  case k
  of ekDiamond:
    rgb(220, 70, 200)
  of ekDart:
    rgb(255, 120, 60)
  of ekHex:
    rgb(50, 170, 165)

proc boom(x, y, z: float, c: Color, n: int) =
  for _ in 0 ..< n:
    let ang = rand(0.0 .. TAU)
    let sp = rand(0.25 .. 1.1)
    let life = rand(0.3 .. 0.6)
    shards.add Shard(
      x: x,
      y: y,
      z: z,
      vx: cos(ang) * sp,
      vy: sin(ang) * sp,
      rot: rand(0.0 .. TAU),
      spin: rand(-9.0 .. 9.0),
      life: life,
      maxLife: life,
      color: c,
    )

proc resetStar(s: var Star) =
  s.x = rand(-W.float .. W.float)
  s.y = rand(-H.float .. H.float)
  s.z = rand(1.0 .. W.float)
  s.pz = s.z

proc startJump(seconds: float) =
  jump = seconds
  jumpDur = seconds

proc reset() =
  enemies.setLen(0)
  shots.setLen(0)
  shards.setLen(0)
  shipX = 0
  shipY = 0.45
  mouseTX = shipX
  mouseTY = shipY
  mouseActive = false
  tilt = 0
  score = 0
  lives = 3
  level = 1
  elapsed = 0
  spawnIn = 0.6
  cooldown = 0
  shield = 0
  shake = 0
  dead = false
  startJump(2.4) # the opening warp into the first wave

for _ in 0 ..< StarCount:
  var s: Star
  resetStar(s)
  stars.add s
reset()

proc spawnEnemy() =
  # The roster widens as the waves go on: darts join in wave 2, hexes in 3.
  let top =
    if level >= 3:
      2
    elif level >= 2:
      1
    else:
      0
  let kind = EnemyKind(rand(top))
  enemies.add Enemy(
    kind: kind,
    x: rand(-0.95 .. 0.95),
    y: rand(-0.55 .. 0.75),
    z: ZFar,
    spin: rand(0.0 .. TAU),
    hp: (if kind == ekHex: 2 else: 1),
  )

proc hitShip() =
  dec lives
  shield = 2.0
  shake = 0.55
  boom(shipX, shipY, ZShip, rgb(255, 160, 60), 16)
  if lives <= 0:
    dead = true

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  case key
  of Key.escape:
    nim2d.running = false
  of Key.r:
    if dead:
      reset()
  else:
    discard

n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  # Map the cursor back through the projection to a world position at the
  # ship's depth, so the ship sits under the pointer.
  mouseTX = clamp((x - Cx) * ZShip / Focal, -ShipRangeX, ShipRangeX)
  mouseTY = clamp((y - Cy) * ZShip / Focal, ShipRangeTop, ShipRangeBottom)
  mouseActive = true

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let approach = min(4.0, 1.55 + 0.28 * (level - 1).float)

  # The warp jump and the backdrop keep moving even on the game-over screen.
  if jump > 0:
    jump -= dt
  jumpF =
    if jump > 0:
      sin(PI * clamp(1.0 - jump / jumpDur, 0.0, 1.0))
    else:
      0.0
  let warp = (22.0 + 4.0 * level.float) * (1.0 + 10.0 * jumpF)
  for s in stars.mitems:
    s.pz = s.z
    s.z -= warp * dt * 60.0
    if s.z < 1:
      resetStar(s)
  gridOff += approach * 0.9 * dt * (1.0 + 5.0 * jumpF)
  if shake > 0:
    shake -= dt

  var i = 0
  while i < shards.len:
    template d(): untyped =
      shards[i]

    d.x += d.vx * dt
    d.y += d.vy * dt
    d.rot += d.spin * dt
    d.life -= dt
    if d.life <= 0:
      shards.del(i)
    else:
      inc i

  if dead:
    return
  elapsed += dt
  let wave = 1 + int(elapsed / 20)
  if wave > level:
    level = wave
    startJump(1.8) # hyperjump between waves
  if shield > 0:
    shield -= dt

  # Steering. Arrow keys take over from the mouse and the mouse takes over as
  # soon as it moves; the tilt follows the real sideways speed to bank the ship.
  let prevX = shipX
  var mx = 0.0
  var my = 0.0
  if isDown(Key.left):
    mx -= 1
  if isDown(Key.right):
    mx += 1
  if isDown(Key.up):
    my -= 1
  if isDown(Key.down):
    my += 1
  if mx != 0 or my != 0:
    mouseActive = false
    shipX = clamp(shipX + mx * 1.6 * dt, -ShipRangeX, ShipRangeX)
    shipY = clamp(shipY + my * 1.3 * dt, ShipRangeTop, ShipRangeBottom)
  elif mouseActive:
    shipX += (mouseTX - shipX) * min(1.0, 14.0 * dt)
    shipY += (mouseTY - shipY) * min(1.0, 14.0 * dt)
  if dt > 0:
    tilt += (clamp((shipX - prevX) / dt / 1.6, -1.0, 1.0) - tilt) * 10.0 * dt

  cooldown -= dt
  if (isDown(Key.space) or isMouseDown(MouseButton.left)) and cooldown <= 0:
    shots.add Shot(x: shipX, y: shipY - 0.03, z: ZShip + 0.05, pz: ZShip + 0.05)
    cooldown = 0.16

  if jump <= 0: # between dimensions nothing new shows up
    spawnIn -= dt
    if spawnIn <= 0:
      spawnEnemy()
      spawnIn = max(0.3, 1.15 - 0.08 * level.float) * rand(0.7 .. 1.3)

  i = 0
  while i < enemies.len:
    template e(): untyped =
      enemies[i]

    let prevZ = e.z
    e.z -= approach * pace(e.kind) * dt
    e.spin += 2.2 * dt
    case e.kind
    of ekDart:
      e.x += (shipX - e.x) * 0.5 * dt
    # darts steer toward you
    of ekDiamond:
      e.x += sin(elapsed * 2.0 + e.spin) * 0.15 * dt
    of ekHex:
      discard
    if prevZ >= ZShip and e.z < ZShip and shield <= 0 and
        distance(e.x, e.y, shipX, shipY) < radius(e.kind) + 0.1:
      hitShip()
      enemies.del(i)
      continue
    if e.z < ZNear:
      enemies.del(i)
      continue
    inc i

  var si = 0
  while si < shots.len:
    template sh(): untyped =
      shots[si]

    sh.pz = sh.z
    sh.z += 14.0 * dt
    # A little aim assist: the bolt drifts toward the nearest enemy still
    # ahead of it, so a shot that looks on target connects.
    var bestI = -1
    var bestD = 0.5
    for ei in 0 ..< enemies.len:
      if enemies[ei].z > sh.z:
        let d = distance(enemies[ei].x, enemies[ei].y, sh.x, sh.y)
        if d < bestD:
          bestD = d
          bestI = ei
    if bestI >= 0:
      sh.x += (enemies[bestI].x - sh.x) * 3.0 * dt
      sh.y += (enemies[bestI].y - sh.y) * 3.0 * dt
    var spent = false
    var ei = 0
    while ei < enemies.len:
      template e(): untyped =
        enemies[ei]

      # The depth test sweeps the distance the bolt covered this frame, and
      # the lateral test is generous, since exact world distances read as
      # unfair on screen once the perspective squeezes everything together.
      if e.z >= sh.pz - 0.3 and e.z <= sh.z + 0.3 and
          distance(e.x, e.y, sh.x, sh.y) < radius(e.kind) * 1.4 + 0.04:
        dec e.hp
        spent = true
        if e.hp <= 0:
          score += bounty(e.kind)
          boom(e.x, e.y, e.z, hue(e.kind), 12)
          enemies.del(ei)
        break
      inc ei
    if spent or sh.z > ZFar:
      shots.del(si)
    else:
      inc si

proc drawEnemy(nim2d: Nim2d, e: Enemy) =
  let p = proj(e.x, e.y, e.z)
  let s = radius(e.kind) * Focal / e.z
  case e.kind
  of ekDiamond:
    nim2d.transformed(move = p, angle = e.spin):
      nim2d.setColor(hue(e.kind))
      nim2d.rectangle(-s, -s, s * 2, s * 2, true)
      nim2d.setColor(12, 4, 16)
      nim2d.rectangle(-s * 0.45, -s * 0.45, s * 0.9, s * 0.9, true)
  of ekDart:
    nim2d.transformed(move = p, angle = sin(e.spin) * 0.4):
      nim2d.setColor(hue(e.kind))
      nim2d.triangle(0, s * 1.3, s, -s * 0.9, -s, -s * 0.9, true)
      nim2d.setColor(110, 25, 10)
      nim2d.triangle(0, s * 0.55, s * 0.45, -s * 0.5, -s * 0.45, -s * 0.5, true)
  of ekHex:
    var xs, ys: array[6, float]
    for k in 0 .. 5:
      let a = e.spin * 0.5 + k.float / 6.0 * TAU
      xs[k] = p.x + cos(a) * s
      ys[k] = p.y + sin(a) * s
    nim2d.setColor(
      if e.hp == 1:
        rgb(255, 130, 100)
      else:
        hue(e.kind)
    )
    nim2d.polygon(xs, ys, true)
    nim2d.setColor(8, 30, 30)
    nim2d.circle(p.x, p.y, s * 0.4, true)

proc drawShip(nim2d: Nim2d) =
  if shield > 0 and (int(elapsed * 12) mod 2 == 0):
    return # blink while hit
  let p = proj(shipX, shipY, ZShip)
  let s = 0.11 * Focal / ZShip
  # Seen from behind, nose aimed at the vanishing point its path converges
  # on, plus a bank in the direction it is strafing.
  let aim = arctan2(Cx - p.x, -(Cy - p.y))
  nim2d.transformed(move = p, angle = aim * 0.6 + tilt * 0.3):
    # delta wings sweeping back toward the camera
    nim2d.setColor(120, 200, 255)
    nim2d.triangle(0, -s * 1.5, -s * 1.5, s * 0.95, -s * 0.2, s * 0.8, true)
    nim2d.triangle(0, -s * 1.5, s * 1.5, s * 0.95, s * 0.2, s * 0.8, true)
    nim2d.setColor(70, 140, 210)
    nim2d.triangle(0, -s * 1.5, -s * 0.5, s * 0.9, s * 0.5, s * 0.9, true)
    nim2d.setColor(235, 240, 255)
    nim2d.triangle(-s * 1.5, s * 0.95, -s * 1.1, s * 0.9, -s * 0.95, s * 0.55, true)
    nim2d.triangle(s * 1.5, s * 0.95, s * 1.1, s * 0.9, s * 0.95, s * 0.55, true)
    nim2d.setColor(15, 30, 60)
    nim2d.triangle(0, -s * 0.9, -s * 0.2, s * 0.1, s * 0.2, s * 0.1, true)
    # engine glow facing the camera, brighter while at warp
    nim2d.withBlend(bmAdd):
      let flick = 0.16 + 0.05 * sin(elapsed * 47) + 0.12 * jumpF
      for ex in [-0.27, 0.27]:
        nim2d.setColor(255, 140, 50)
        nim2d.circle(ex * s, s * 0.92, s * flick * 1.7, true)
        nim2d.setColor(255, 235, 170)
        nim2d.circle(ex * s, s * 0.92, s * flick, true)

n2d.draw = proc(nim2d: Nim2d) =
  # Camera shake after a hit, and a low rumble while the warp jump peaks.
  let rumble = 16.0 * pow(max(0.0, shake) / 0.55, 2.0) + 3.0 * jumpF
  let shaking = rumble > 0.05
  if shaking:
    nim2d.push()
    nim2d.translate(rand(-1.0 .. 1.0) * rumble, rand(-1.0 .. 1.0) * rumble)

  # The ground: a wide grid of rails running to the horizon, with rows
  # rolling toward the camera.
  nim2d.setColor(80, 55, 130, 120)
  for k in -5 .. 5:
    let gx = k.float * 0.8
    nim2d.line(@[proj(gx, 1.05, ZNear), proj(gx, 1.05, ZFar)])
  for k in 0 .. 8:
    let zr = ZNear + floorMod(k.float * 1.4 - gridOff, ZFar - ZNear)
    nim2d.line(@[proj(-4.0, 1.05, zr), proj(4.0, 1.05, zr)], 1.0 + 1.5 / zr)

  for s in stars:
    let sx = Cx + (s.x / s.z) * Cx
    let sy = Cy + (s.y / s.z) * Cy
    let px = Cx + (s.x / s.pz) * Cx
    let py = Cy + (s.y / s.pz) * Cy
    let b = uint8(max(0.0, min(1.0, 1.0 - s.z / W.float)) * 200)
    nim2d.setColor(b, b, 230'u8)
    nim2d.line(@[(px, py), (sx, sy)], (1.0 - s.z / W.float) * 2.5 + 0.5)

  # Far enemies first so the close ones overlap them.
  enemies.sort(
    proc(a, b: Enemy): int =
      cmp(b.z, a.z)
  )
  for e in enemies:
    nim2d.drawEnemy(e)

  nim2d.withBlend(bmAdd):
    for sh in shots:
      nim2d.setColor(140, 255, 170)
      nim2d.line(@[proj(sh.x, sh.y, sh.pz), proj(sh.x, sh.y, sh.z)], 3)

  for d in shards:
    let p = proj(d.x, d.y, d.z)
    let s = 0.035 * Focal / d.z * (d.life / d.maxLife)
    nim2d.transformed(move = p, angle = d.rot):
      nim2d.setColor(d.color.withAlpha(int(255 * d.life / d.maxLife)))
      nim2d.triangle(0, -s, s, s, -s, s, true)

  nim2d.drawShip()
  if shaking:
    nim2d.pop()

  # A wash of light at the peak of the jump, with the wave announcement.
  if jumpF > 0.02:
    nim2d.setColor(150, 180, 255, uint8(70.0 * jumpF))
    nim2d.rectangle(0, 0, W.float, H.float, true)
    nim2d.withFont(bigFont):
      nim2d.setColor(235, 240, 255, uint8(min(255.0, 320.0 * jumpF)))
      let ww = bigFont.getSize("WAVE " & $level).w.float
      nim2d.print("WAVE " & $level, Cx - ww / 2, Cy - 140)

  nim2d.setColor(235, 240, 255)
  nim2d.print("score " & $score, 16, 12)
  nim2d.print("wave " & $level, Cx - 40, 12)
  for k in 0 ..< lives:
    let lx = W.float - 30 - k.float * 28
    nim2d.setColor(120, 200, 255)
    nim2d.triangle(lx, 14, lx + 16, 34, lx - 16, 34, true)

  if dead:
    nim2d.setColor(0, 0, 0, 170)
    nim2d.rectangle(0, 0, W.float, H.float, true)
    nim2d.withFont(bigFont):
      nim2d.setColor(255, 120, 120)
      let gw = bigFont.getSize("GAME OVER").w.float
      nim2d.print("GAME OVER", Cx - gw / 2, Cy - 90)
    nim2d.setColor(235, 240, 255)
    nim2d.print("score " & $score & "   wave " & $level, Cx - 90, Cy)
    nim2d.print("press R to restart", Cx - 85, Cy + 36)

n2d.play()
