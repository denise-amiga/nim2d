## A particle system: an emitter that spawns short-lived particles, moves them,
## fades them between a start and end size and color, and draws them in one
## batch. Configure it with the setters, call `update` each frame and `draw` to
## show it. With no texture the particles are colored squares; with a texture
## they are textured quads.

import std/[math, random]
import types
import transform
import backend/renderer
import graphics

type
  Particle = object
    x, y, vx, vy, life, maxLife, rot, spin: float

  ParticleSystem* = ref object
    ## An emitter that spawns short-lived particles and animates them. Without
    ## a texture the particles are colored squares; with one they are textured
    ## quads.
    texture*: Texture
    particles: seq[Particle]
    maxParticles: int
    active: bool
    accumulator: float
    px, py: float
    rate: float
    lifeMin, lifeMax: float
    speedMin, speedMax: float
    direction, spread: float
    ax, ay: float
    sizeStart, sizeEnd: float
    colStart, colEnd: Color
    spinMin, spinMax: float

proc newParticleSystem*(texture: Texture = nil, maxParticles = 2000): ParticleSystem =
  ## A particle system, optionally drawing a texture per particle. Configure it
  ## with the setters, `update` it every frame and `draw` it to show it.
  ParticleSystem(
    texture: texture,
    maxParticles: maxParticles,
    active: true,
    rate: 50,
    lifeMin: 1,
    lifeMax: 1,
    speedMin: 0,
    speedMax: 0,
    direction: 0,
    spread: 0,
    ax: 0,
    ay: 0,
    sizeStart: 8,
    sizeEnd: 8,
    colStart: (255'u8, 255'u8, 255'u8, 255'u8),
    colEnd: (255'u8, 255'u8, 255'u8, 255'u8),
    spinMin: 0,
    spinMax: 0,
  )

proc setPosition*(ps: ParticleSystem, x, y: float) =
  ## Move the emitter; new particles spawn here.
  ps.px = x
  ps.py = y

proc setEmissionRate*(ps: ParticleSystem, rate: float) =
  ## How many particles spawn per second.
  ps.rate = rate

proc setParticleLifetime*(ps: ParticleSystem, min, max: float) =
  ## How long each particle lives, in seconds, picked from this range.
  ps.lifeMin = min
  ps.lifeMax = max

proc setSpeed*(ps: ParticleSystem, min, max: float) =
  ## The initial speed of each particle, picked from this range.
  ps.speedMin = min
  ps.speedMax = max

proc setDirection*(ps: ParticleSystem, radians: float) =
  ## The direction particles fly out in.
  ps.direction = radians

proc setSpread*(ps: ParticleSystem, radians: float) =
  ## The angle of the cone around the direction that particles scatter into.
  ps.spread = radians

proc setLinearAcceleration*(ps: ParticleSystem, ax, ay: float) =
  ## A constant acceleration on every particle, like gravity or wind.
  ps.ax = ax
  ps.ay = ay

proc setSizes*(ps: ParticleSystem, startSize, endSize: float) =
  ## Each particle's size fades from start to end over its life.
  ps.sizeStart = startSize
  ps.sizeEnd = endSize

proc setColors*(ps: ParticleSystem, startColor, endColor: Color) =
  ## Each particle's color fades from start to end over its life. Fading the
  ## end alpha to 0 makes particles dissolve.
  ps.colStart = startColor
  ps.colEnd = endColor

proc setSpin*(ps: ParticleSystem, min, max: float) =
  ## How fast each particle rotates, in radians per second, from this range.
  ps.spinMin = min
  ps.spinMax = max

proc start*(ps: ParticleSystem) =
  ## Resume emitting after `stop`.
  ps.active = true

proc stop*(ps: ParticleSystem) =
  ## Stop emitting. Particles already alive keep moving until they expire.
  ps.active = false

proc isActive*(ps: ParticleSystem): bool =
  ## Whether the emitter is emitting.
  ps.active

proc count*(ps: ParticleSystem): int =
  ## How many particles are alive right now.
  ps.particles.len

proc spawnOne(ps: ParticleSystem) =
  if ps.particles.len >= ps.maxParticles:
    return
  let life = rand(ps.lifeMin .. ps.lifeMax)
  let speed = rand(ps.speedMin .. ps.speedMax)
  let ang = ps.direction + rand(-ps.spread / 2 .. ps.spread / 2)
  ps.particles.add Particle(
    x: ps.px,
    y: ps.py,
    vx: cos(ang) * speed,
    vy: sin(ang) * speed,
    life: life,
    maxLife: life,
    rot: rand(0.0 .. TAU),
    spin: rand(ps.spinMin .. ps.spinMax),
  )

proc emit*(ps: ParticleSystem, count: int) =
  ## Spawn `count` particles right now, regardless of the emission rate.
  for _ in 0 ..< count:
    ps.spawnOne()

proc update*(ps: ParticleSystem, dt: float) =
  ## Advance the system by `dt` seconds: spawn, move, age and retire particles.
  ## Call every frame from the `update` callback.
  if ps.active and ps.rate > 0:
    ps.accumulator += dt * ps.rate
    while ps.accumulator >= 1:
      ps.spawnOne()
      ps.accumulator -= 1
  var i = 0
  while i < ps.particles.len:
    template p(): untyped =
      ps.particles[i]

    p.vx += ps.ax * dt
    p.vy += ps.ay * dt
    p.x += p.vx * dt
    p.y += p.vy * dt
    p.rot += p.spin * dt
    p.life -= dt
    if p.life <= 0:
      ps.particles[i] = ps.particles[^1]
      ps.particles.setLen(ps.particles.len - 1)
    else:
      inc i

func lerp(a, b, t: float): float =
  a + (b - a) * t

func lerpCol(a, b: Color, t: float): Color =
  (
    uint8(lerp(a.r.float, b.r.float, t)),
    uint8(lerp(a.g.float, b.g.float, t)),
    uint8(lerp(a.b.float, b.b.float, t)),
    uint8(lerp(a.a.float, b.a.float, t)),
  )

proc draw*(ps: ParticleSystem, nim2d: Nim2d, x = 0.0, y = 0.0) =
  ## Draw every live particle in one batch, optionally offset by (x, y).
  if ps.particles.len == 0:
    return
  let textured = ps.texture != nil
  var verts = newSeqOfCap[Vertex](ps.particles.len * 4)
  var idx = newSeqOfCap[uint32](ps.particles.len * 6)
  for pt in ps.particles:
    let f = 1.0 - pt.life / pt.maxLife
    let size = lerp(ps.sizeStart, ps.sizeEnd, f)
    let col = lerpCol(ps.colStart, ps.colEnd, f)
    let r = col.r.float32 / 255
    let g = col.g.float32 / 255
    let b = col.b.float32 / 255
    let a = col.a.float32 / 255
    let tr = identity().translate(pt.x, pt.y).rotate(pt.rot)
    let h = size / 2
    let (x0, y0) = tr.apply(-h, -h)
    let (x1, y1) = tr.apply(h, -h)
    let (x2, y2) = tr.apply(h, h)
    let (x3, y3) = tr.apply(-h, h)
    let base = uint32(verts.len)
    verts.add Vertex(x: x0.float32, y: y0.float32, u: 0, v: 0, r: r, g: g, b: b, a: a)
    verts.add Vertex(x: x1.float32, y: y1.float32, u: 1, v: 0, r: r, g: g, b: b, a: a)
    verts.add Vertex(x: x2.float32, y: y2.float32, u: 1, v: 1, r: r, g: g, b: b, a: a)
    verts.add Vertex(x: x3.float32, y: y3.float32, u: 0, v: 1, r: r, g: g, b: b, a: a)
    for k in [0'u32, 1, 2, 0, 2, 3]:
      idx.add base + k
  let kind = if textured: pkTextured else: pkColored
  let tex = if textured: ps.texture.tex else: nil
  nim2d.push()
  nim2d.translate(x, y)
  nim2d.gpu.addGeometry(kind, nim2d.blend, tex, verts, idx)
  nim2d.pop()
