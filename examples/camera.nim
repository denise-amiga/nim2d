## Two cameras over one world. You pilot a glowing orb across a world that is
## wider than the window, and you flip between two views of it with space. A
## PILOT camera trails the orb up close, and a MAP camera pulls back and tilts
## to show the whole place at once. The switch is a single eased blend between
## the two cameras, so the view glides rather than cuts.
##
## The point is the camera module. The MAP view is how you spot where the other
## gate is; the PILOT view is how you fly there. Light both gates to link them.
## Click anywhere to drop a ping, which lands on the right world spot in either
## view because the click goes through `toWorld`. The gate name tags are pinned
## with `toScreen`, and turn into edge arrows when a gate is off the screen.
##
## Move with WASD or the arrows, space switches the camera, R resets, Esc quits.

import std/[math, os]
import nim2d
import nim2d/camera

const
  W = 960
  H = 600
  WorldMinX = -900.0
  WorldMaxX = 900.0
  WorldMinY = -560.0
  WorldMaxY = 560.0

let n2d =
  newNim2d("nim2d - camera", 120, 80, W.cint, H.cint, (10'u8, 11'u8, 20'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 20)
let bigFont = newFont(getAppDir() / "font.ttf", 52)

type
  Portal = object
    pos: Vec2
    color: Color
    name: string
    radius: float
    lit: bool

  Ripple = object
    pos: Vec2
    age: float

  Star = object
    pos: Vec2
    size: float
    phase: float

var
  camPilot = newCamera(0.0, 0.0, 1.5) # close follow view
  camMap = newCamera(0.0, 0.0, 0.46, 0.04) # tilted overview of the whole world
  active = 0 # which camera is chosen: 0 pilot, 1 map
  blend = 0.0 # eased toward `active`, drives the view between the two
  orb: Vec2
  vel: Vec2
  trail: seq[Vec2]
  portals: seq[Portal]
  ripples: seq[Ripple]
  stars: seq[Star]
  time = 0.0
  won = false
  winTimer = 0.0

proc smoothstep(t: float): float =
  let x = clamp(t, 0.0, 1.0)
  x * x * (3.0 - 2.0 * x)

proc currentView(): Camera =
  ## The camera actually rendered this frame: the two cameras blended by where
  ## the switch is, with a small zoom-out dip in the middle of a switch so the
  ## move feels like a camera pulling back and pushing in again.
  let s = smoothstep(blend)
  result = lerp(camPilot, camMap, s)
  result.scale = result.scale * (1.0 - 0.18 * sin(s * PI))

proc reset() =
  orb = (0.0, 0.0)
  vel = (0.0, 0.0)
  trail.setLen(0)
  ripples.setLen(0)
  won = false
  winTimer = 0.0
  active = 0
  blend = 0.0
  camPilot.lookAt(orb)
  portals =
    @[
      Portal(
        pos: (-660.0, -250.0), color: rgb(90, 150, 240), name: "BLUE GATE", radius: 60
      ),
      Portal(
        pos: (700.0, 290.0), color: rgb(245, 150, 60), name: "AMBER GATE", radius: 60
      ),
    ]
  var rng = newRng(424242'u64)
  stars.setLen(0)
  for _ in 0 ..< 320:
    stars.add Star(
      pos: (
        rng.random(WorldMinX - 120, WorldMaxX + 120),
        rng.random(WorldMinY - 120, WorldMaxY + 120),
      ),
      size: rng.random(1.2, 3.2),
      phase: rng.random(0.0, TAU),
    )

reset()

# --- world drawing (everything here is in world coordinates) ----------------

proc drawStars(nim2d: Nim2d) =
  for s in stars:
    let b = 0.35 + 0.55 * (0.5 + 0.5 * sin(time * 1.5 + s.phase))
    nim2d.setColor(gray(int(b * 210), int(120 + b * 120)))
    nim2d.points([s.pos], s.size)

proc drawWorldFrame(nim2d: Nim2d) =
  nim2d.setColor(rgb(46, 54, 86).withAlpha(120))
  nim2d.rectangle(
    WorldMinX,
    WorldMinY,
    WorldMaxX - WorldMinX,
    WorldMaxY - WorldMinY,
    false,
    roundness = 44,
  )

proc drawPath(nim2d: Nim2d) =
  let a = portals[0].pos
  let b = portals[1].pos
  for i in 0 .. 36:
    let p = lerp(a, b, i.float / 36.0)
    nim2d.setColor(gray(110).withAlpha(45))
    nim2d.circle(p.x, p.y, 3, true)

proc drawPortals(nim2d: Nim2d) =
  for p in portals:
    let pulse = 0.5 + 0.5 * sin(time * 2.0 + (if p.lit: 0.0 else: 1.6))
    nim2d.withBlend(bmAdd):
      let glow = (if p.lit: 110 else: 45).float * (0.6 + 0.4 * pulse)
      nim2d.setColor(p.color.withAlpha(int(glow)))
      nim2d.circle(p.pos.x, p.pos.y, p.radius * 1.7, true, 40)
    for k in 0 .. 2:
      let rr = p.radius * (0.5 + 0.28 * k.float) + (if p.lit: pulse * 8 else: 0.0)
      nim2d.setColor(p.color.withAlpha(if p.lit: 235 else: 120))
      nim2d.circle(p.pos.x, p.pos.y, rr, false, 48)
    nim2d.setColor(
      if p.lit:
        p.color
      else:
        p.color.withAlpha(70)
    )
    nim2d.circle(p.pos.x, p.pos.y, p.radius * 0.32, true)

proc drawRipples(nim2d: Nim2d) =
  for r in ripples:
    let t = clamp(r.age / 1.4, 0.0, 1.0)
    nim2d.setColor(rgb(180, 220, 255).withAlpha(int((1.0 - t) * 150)))
    nim2d.circle(r.pos.x, r.pos.y, 8 + t * 70, false, 40)

proc drawTrail(nim2d: Nim2d) =
  nim2d.withBlend(bmAdd):
    for i, p in trail:
      let t = i.float / max(1, trail.len).float
      nim2d.setColor(rgb(120, 220, 255).withAlpha(int(t * t * 120)))
      nim2d.circle(p.x, p.y, 4 + t * 8, true)

proc drawOrb(nim2d: Nim2d) =
  nim2d.withBlend(bmAdd):
    nim2d.setColor(rgb(120, 220, 255).withAlpha(60))
    nim2d.circle(orb.x, orb.y, 34, true)
    nim2d.setColor(rgb(150, 235, 255).withAlpha(120))
    nim2d.circle(orb.x, orb.y, 20, true)
  nim2d.setColor(rgb(225, 250, 255))
  nim2d.circle(orb.x, orb.y, 12, true)

proc drawBeam(nim2d: Nim2d) =
  let w = 4.0 + 3.0 * sin(time * 6.0)
  nim2d.withBlend(bmAdd):
    nim2d.setColor(rgb(200, 240, 255).withAlpha(150))
    nim2d.line(@[portals[0].pos, portals[1].pos], w)

# --- screen-space drawing (HUD, markers) ------------------------------------

proc drawMarkers(nim2d: Nim2d, view: Camera) =
  ## Pin a name tag over each gate with `toScreen`. When a gate is off the
  ## screen, point an arrow at it from the edge instead.
  let c: Vec2 = (W.float / 2, H.float / 2)
  let margin = 46.0
  nim2d.setFont(font)
  for p in portals:
    let sp = nim2d.toScreen(view, p.pos)
    let onScreen =
      sp.x > margin and sp.x < W.float - margin and sp.y > margin and
      sp.y < H.float - margin
    if onScreen:
      let label = p.name & (if p.lit: "  *" else: "")
      let sz = font.getSize(label)
      let tx = sp.x - sz.w.float / 2
      let ty = sp.y - p.radius * view.scale - 34
      nim2d.setColor(rgba(10, 12, 22, 170))
      nim2d.rectangle(
        tx - 8, ty - 4, sz.w.float + 16, sz.h.float + 8, true, roundness = 6
      )
      nim2d.setColor(
        if p.lit:
          p.color
        else:
          p.color.withAlpha(190)
      )
      nim2d.print(label, tx, ty)
    else:
      let dir = normalized((sp.x - c.x, sp.y - c.y))
      let halfx = W.float / 2 - margin
      let halfy = H.float / 2 - margin
      let tx =
        if abs(dir.x) > 1e-5:
          halfx / abs(dir.x)
        else:
          1e9
      let ty =
        if abs(dir.y) > 1e-5:
          halfy / abs(dir.y)
        else:
          1e9
      let reach = min(tx, ty)
      let edge: Vec2 = (c.x + dir.x * reach, c.y + dir.y * reach)
      let ang = arctan2(dir.y, dir.x)
      nim2d.transformed(move = edge, angle = ang):
        nim2d.setColor(p.color)
        nim2d.triangle(15, 0, -11, 9, -11, -9, true)

proc drawHud(nim2d: Nim2d) =
  nim2d.setFont(font)
  nim2d.setColor(rgba(8, 10, 18, 165))
  nim2d.rectangle(14, 14, 372, 78, true, roundness = 10)
  nim2d.setColor(rgb(235, 240, 255))
  nim2d.print(
    "Camera: " &
      (if active == 0: "PILOT  (follow, zoomed in)" else: "MAP  (overview, tilted)"),
    28,
    26,
  )
  let lit = (if portals[0].lit: 1 else: 0) + (if portals[1].lit: 1 else: 0)
  nim2d.setColor(rgb(150, 160, 185))
  nim2d.print("gates linked: " & $lit & " / 2", 28, 58)
  nim2d.setColor(rgb(120, 130, 155))
  nim2d.print(
    "move WASD or arrows    space switch camera    click to ping    R reset    Esc quit",
    20,
    H.float - 32,
  )
  if won:
    let a = clamp(winTimer * 2.0, 0.0, 1.0)
    nim2d.setColor(rgba(6, 8, 16, int(a * 150)))
    nim2d.rectangle(0, 0, W.float, H.float, true)
    nim2d.setFont(bigFont)
    nim2d.setColor(rgb(180, 240, 255))
    let msg = "Gates Linked"
    nim2d.print(msg, W.float / 2 - bigFont.getSize(msg).w.float / 2, H.float / 2 - 60)
    nim2d.setFont(font)
    nim2d.setColor(rgb(200, 210, 230))
    let sub = "press R to play again"
    nim2d.print(sub, W.float / 2 - font.getSize(sub).w.float / 2, H.float / 2 + 14)

# --- callbacks --------------------------------------------------------------

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  case key
  of Key.space, Key.tab:
    active = 1 - active
  of Key.r:
    reset()
  of Key.escape:
    nim2d.running = false
  else:
    discard

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  ripples.add Ripple(pos: nim2d.toWorld(currentView(), (x, y)), age: 0)

n2d.update = proc(nim2d: Nim2d, dt: float) =
  time += dt
  blend += (active.float - blend) * (1.0 - exp(-9.0 * dt))

  var dir: Vec2
  if isDown(Key.left) or isDown(Key.a):
    dir.x -= 1
  if isDown(Key.right) or isDown(Key.d):
    dir.x += 1
  if isDown(Key.up) or isDown(Key.w):
    dir.y -= 1
  if isDown(Key.down) or isDown(Key.s):
    dir.y += 1
  if dir.lengthSq > 0:
    vel += dir.normalized * (2200.0 * dt)
  vel *= exp(-3.0 * dt) # friction, independent of frame rate
  orb += vel * dt
  orb.x = clamp(orb.x, WorldMinX, WorldMaxX)
  orb.y = clamp(orb.y, WorldMinY, WorldMaxY)

  trail.add orb
  if trail.len > 28:
    trail.delete(0)

  camPilot.follow(orb, dt, 6.0)

  var live: seq[Ripple]
  for r in ripples:
    if r.age < 1.4:
      live.add Ripple(pos: r.pos, age: r.age + dt)
  ripples = live

  if not won:
    var allLit = true
    for p in portals.mitems:
      if not p.lit and distance(orb, p.pos) < p.radius:
        p.lit = true
      if not p.lit:
        allLit = false
    if allLit:
      won = true
  else:
    winTimer += dt

n2d.draw = proc(nim2d: Nim2d) =
  let view = currentView()
  nim2d.withCamera(view):
    nim2d.drawStars()
    nim2d.drawWorldFrame()
    nim2d.drawPath()
    nim2d.drawRipples()
    nim2d.drawPortals()
    nim2d.drawTrail()
    nim2d.drawOrb()
    if won:
      nim2d.drawBeam()
  nim2d.drawMarkers(view)
  nim2d.drawHud()

n2d.play()
