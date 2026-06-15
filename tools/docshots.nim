## Renders the screenshots used by the documentation.
##
## Run it from the repository root (`make shots`). It opens one window, renders
## each scene into an off-screen canvas at twice its logical size, reads the
## pixels back with `newImageData(canvas)`, downsamples to the logical size on
## the CPU for smooth edges, and writes a PNG per scene into docs/assets.
##
## A scene draws with a fixed timestep so the output is the same on every run.
## The physics scene needs Box2D installed.

import std/[math, os]
import nim2d
import nim2d/physics

const OutDir = "docs/assets"
const Dt = 1.0 / 60.0

type Scene = object
  name: string
  w, h: int32 # logical size of the saved image
  frames: int # frames to run before the capture
  bg: Color
  init: proc(n: Nim2d)
  tick: proc(n: Nim2d, t, dt: float)
  draw: proc(n: Nim2d, t: float, shot: Canvas)

let n2d = newNim2d(
  "nim2d docs shots", 80, 80, 760, 460, (18'u8, 18'u8, 24'u8, 255'u8), stencil = true
)

# Shared assets. The fonts and the logo come from the examples folder.
let labelFont = newFont("examples/font.ttf", 16)
let textFont = newFont("examples/font.ttf", 26)
let bigFont = newFont("examples/font.ttf", 44)
let heroFont = newFont("examples/font.ttf", 88)
let logo = n2d.newImage("examples/Nim-logo.png")

# A small checkerboard texture for the textured mesh.
let checker = block:
  var data = newImageData(8, 8)
  data.mapPixel(
    proc(x, y: int32, c: Color): Color =
      if (x + y) mod 2 == 0:
        (60'u8, 170'u8, 165'u8, 255'u8)
      else:
        (235'u8, 238'u8, 245'u8, 255'u8)
  )
  let img = n2d.newImage(data)
  img.setFilter(filNearest)
  img

var rng = newRng(20260610)

proc downsample(src: ImageData): ImageData =
  ## Average each 2x2 block into one pixel, halving the image.
  result = newImageData(src.width div 2, src.height div 2)
  for y in 0'i32 ..< result.height:
    for x in 0'i32 ..< result.width:
      var r, g, b, a = 0
      for dy in 0'i32 .. 1:
        for dx in 0'i32 .. 1:
          let c = src.getPixel(x * 2 + dx, y * 2 + dy)
          r += c.r.int
          g += c.g.int
          b += c.b.int
          a += c.a.int
      result.setPixel(
        x, y, (uint8(r div 4), uint8(g div 4), uint8(b div 4), uint8(a div 4))
      )

proc starShape(
    cx, cy, outer, inner: float, points: int, rot = 0.0
): tuple[xs, ys: seq[float]] =
  for i in 0 ..< points * 2:
    let r = if i mod 2 == 0: outer else: inner
    let a = rot + PI * i.float / points.float - PI / 2
    result.xs.add cx + cos(a) * r
    result.ys.add cy + sin(a) * r

var scenes: seq[Scene]

# --- hello: the first program in getting started -----------------------------

scenes.add Scene(
  name: "hello",
  w: 640,
  h: 480,
  frames: 1,
  bg: (89'u8, 157'u8, 220'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    n.setColor(255, 120, 60)
    n.circle(320, 240, 80, true),
)

# --- hero: the front-page image ----------------------------------------------

scenes.add Scene(
  name: "hero",
  w: 760,
  h: 300,
  frames: 1,
  bg: (16'u8, 17'u8, 26'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    var dots = newRng(7)
    for _ in 0 ..< 90:
      let x = dots.random(760.0)
      let y = dots.random(300.0)
      n.setColor(gray(120 + dots.randomInt(0, 100), 120 + dots.randomInt(0, 120)))
      n.points([(x, y)], 1.0 + dots.random(1.5))
    n.setColor(255, 120, 60)
    n.circle(520, 110, 52, true)
    n.setColor(sky.withAlpha(230))
    n.transformed(move = vec2(630, 180), angle = 0.35):
      n.rectangle(-38, -38, 76, 76, true, roundness = 14)
    let star = starShape(540, 230, 44, 18, 5, rot = 0.2)
    n.setColor(gold)
    n.polygon(star.xs, star.ys, true)
    let curve =
      newBezierCurve(@[(40.0, 260.0), (240.0, 140.0), (430.0, 300.0), (700.0, 60.0)])
    n.setColor(teal.withAlpha(180))
    n.line(curve.render(60), 4)
    n.withFont(heroFont):
      n.setColor(235, 240, 255)
      n.print("nim2d", 44, 88),
)

# --- shapes -------------------------------------------------------------------

scenes.add Scene(
  name: "shapes",
  w: 560,
  h: 360,
  frames: 1,
  bg: (24'u8, 26'u8, 38'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    n.setColor(sky)
    n.circle(80, 90, 50, true)
    n.setColor(lime)
    n.ellipse(220, 90, 64, 40)
    n.setColor(orange)
    n.rectangle(310, 46, 96, 88, true, roundness = 16)
    n.setColor(magenta)
    n.triangle(450, 134, 500, 40, 540, 120, true)
    let star = starShape(80, 260, 56, 24, 5)
    n.setColor(gold)
    n.polygon(star.xs, star.ys, true)
    n.setColor(cyan)
    n.arc(220, 270, 52, PI * 0.8, PI * 2.2)
    n.setColor(red)
    n.pie(220, 270, 38, PI * 0.25, PI * 0.95, true)
    n.setColor(green)
    n.line(@[(310.0, 310.0), (350.0, 210.0), (400.0, 290.0), (450.0, 220.0)], 8)
    n.setColor(235, 240, 255)
    for gy in 0 .. 3:
      for gx in 0 .. 4:
        n.points([(470.0 + gx.float * 18, 230.0 + gy.float * 18)], 4),
)

# --- colors: the named palette -------------------------------------------------

scenes.add Scene(
  name: "colors",
  w: 560,
  h: 250,
  frames: 1,
  bg: (24'u8, 26'u8, 38'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    let named: seq[(string, Color)] =
      @[
        ("red", red),
        ("orange", orange),
        ("yellow", yellow),
        ("lime", lime),
        ("green", green),
        ("teal", teal),
        ("cyan", cyan),
        ("sky", sky),
        ("blue", blue),
        ("navy", navy),
        ("purple", purple),
        ("magenta", magenta),
        ("pink", pink),
        ("brown", brown),
        ("gold", gold),
        ("white", white),
        ("lightgray", lightgray),
        ("darkgray", darkgray),
      ]
    n.withFont(labelFont):
      for i, (name, c) in named:
        let col = i mod 6
        let row = i div 6
        let x = 20.0 + col.float * 88
        let y = 18.0 + row.float * 78
        n.setColor(c)
        n.rectangle(x, y, 76, 42, true, roundness = 8)
        n.setColor(200, 205, 215)
        n.print(name, x + 2, y + 48),
)

# --- transforms ----------------------------------------------------------------

scenes.add Scene(
  name: "transforms",
  w: 560,
  h: 360,
  frames: 100,
  bg: (20'u8, 22'u8, 32'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    let cx = 280.0
    let cy = 180.0
    n.setColor(gold)
    n.circle(cx, cy, 26, true)
    let cols = [sky, orange, magenta]
    for i in 0 .. 2:
      let orbit = 66.0 + i.float * 46
      n.setColor(gray(70).withAlpha(90))
      n.circle(cx, cy, orbit, false, segments = 64)
      n.push()
      n.translate(cx, cy)
      n.rotate(t * (0.9 - i.float * 0.22) + i.float * 2.1)
      n.translate(orbit, 0)
      n.push()
      n.rotate(t * 2.4)
      n.setColor(cols[i])
      n.rectangle(-13, -13, 26, 26, true, roundness = 4)
      n.pop()
      n.rotate(t * 3.0)
      n.translate(26, 0)
      n.setColor(lightgray)
      n.circle(0, 0, 5, true)
      n.pop(),
)

# --- images and quads -----------------------------------------------------------

scenes.add Scene(
  name: "images",
  w: 560,
  h: 260,
  frames: 1,
  bg: (228'u8, 231'u8, 238'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    let w = logo.getWidth.float
    let h = logo.getHeight.float
    let s = 120.0 / h
    let lw = w * s
    logo.draw(n, 20, 60, 0, s, s)
    logo.draw(n, 170 + lw / 2, 60 + 60, 0.4, s, s, w / 2, h / 2)
    logo.setColorMod(60, 130, 240)
    logo.setAlphaMod(160)
    logo.draw(n, 320, 60, 0, s, s)
    logo.setColorMod(255, 255, 255)
    logo.setAlphaMod(255)
    let frame = newQuad(0, 0, w / 2, h / 2, w, h)
    logo.draw(n, frame, 470, 60, 0, s, s)
    n.withFont(labelFont):
      n.setColor(70, 76, 92)
      n.print("draw", 20, 200)
      n.print("rotated", 170, 200)
      n.print("tinted, faded", 320, 200)
      n.print("a quad", 470, 200),
)

# --- text: TrueType and a bitmap font -------------------------------------------

const digitPatterns =
  @[
    @["###", "#.#", "#.#", "#.#", "###"], # 0
    @[".#.", "##.", ".#.", ".#.", "###"], # 1
    @["###", "..#", "###", "#..", "###"], # 2
    @["###", "..#", "###", "..#", "###"], # 3
    @["#.#", "#.#", "###", "..#", "..#"], # 4
    @["###", "#..", "###", "..#", "###"], # 5
    @["###", "#..", "###", "#.#", "###"], # 6
    @["###", "..#", "..#", "..#", "..#"], # 7
    @["###", "#.#", "###", "#.#", "###"], # 8
    @["###", "#.#", "###", "..#", "###"], # 9
    @["...", "...", "...", "...", "..."], # space
  ]

proc makePixelFont(n: Nim2d): Font =
  ## The same hand-drawn 3x5 digit font the bitmapfont example builds.
  let total = int32(1 + "0123456789 ".len * 4)
  var sheet = newImageData(total, 5, (255'u8, 0'u8, 255'u8, 255'u8))
  var px = 1
  for pat in digitPatterns:
    for ry in 0 ..< 5:
      for cx in 0 ..< 3:
        if pat[ry][cx] == '#':
          sheet.setPixel(int32(px + cx), int32(ry), (240'u8, 240'u8, 245'u8, 255'u8))
        else:
          sheet.setPixel(int32(px + cx), int32(ry), (0'u8, 0'u8, 0'u8, 0'u8))
    px += 4
  n.newImageFont(sheet, "0123456789 ", 1)

var pixelFont: Font

scenes.add Scene(
  name: "text",
  w: 560,
  h: 300,
  frames: 1,
  bg: (16'u8, 18'u8, 28'u8, 255'u8),
  init: proc(n: Nim2d) =
    pixelFont = makePixelFont(n),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    n.withFont(bigFont):
      n.setColor(235, 240, 255)
      n.print("Héllo, wörld", 24, 16)
    n.withFont(textFont):
      n.setColor(sky)
      n.print("TrueType text in any color,", 24, 78)
      n.setColor(orange)
      n.print("rotated", 24, 142, -0.25)
      n.setColor(150, 160, 185)
      n.print("or scaled", 200, 124, 0, 1.4, 1.4)
    n.withFont(pixelFont):
      n.setColor(120, 220, 255)
      n.print("8 0 0 8 5", 24, 170, 0, 10, 10)
      n.setColor(255, 170, 90)
      n.print("0123456789", 24, 246, 0, 5, 5),
)

# --- particles -------------------------------------------------------------------

var fountain: ParticleSystem

scenes.add Scene(
  name: "particles",
  w: 560,
  h: 360,
  frames: 110,
  bg: (10'u8, 10'u8, 16'u8, 255'u8),
  init: proc(n: Nim2d) =
    fountain = newParticleSystem()
    fountain.setEmissionRate(400)
    fountain.setParticleLifetime(0.5, 1.2)
    fountain.setSpeed(120, 300)
    fountain.setDirection(-PI / 2)
    fountain.setSpread(0.7)
    fountain.setLinearAcceleration(0, 320)
    fountain.setSizes(8, 1)
    fountain.setColors((255'u8, 210'u8, 90'u8, 255'u8), (255'u8, 60'u8, 40'u8, 0'u8))
    fountain.setPosition(280, 330),
  tick: proc(n: Nim2d, t, dt: float) =
    fountain.update(dt)
    if abs(t - 1.55) < dt / 2:
      fountain.setPosition(410, 130)
      fountain.emit(260)
      fountain.setPosition(280, 330)
  ,
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    n.withBlend(bmAdd):
      fountain.draw(n),
)

# --- meshes ----------------------------------------------------------------------

scenes.add Scene(
  name: "mesh",
  w: 560,
  h: 260,
  frames: 1,
  bg: (24'u8, 26'u8, 38'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    let tri = newMesh(
      @[
        meshVertex(0, 180, color = (255'u8, 60'u8, 60'u8, 255'u8)),
        meshVertex(170, 180, color = (60'u8, 220'u8, 90'u8, 255'u8)),
        meshVertex(85, 20, color = (70'u8, 120'u8, 255'u8, 255'u8)),
      ]
    )
    tri.draw(n, 30, 30)
    let strip = newMesh(
      @[
        meshVertex(0, 0, color = (255'u8, 210'u8, 90'u8, 255'u8)),
        meshVertex(0, 160, color = (255'u8, 90'u8, 40'u8, 255'u8)),
        meshVertex(130, 0, color = (255'u8, 120'u8, 200'u8, 255'u8)),
        meshVertex(130, 160, color = (120'u8, 60'u8, 220'u8, 255'u8)),
      ],
      mode = mdStrip,
    )
    strip.draw(n, 250, 40)
    let textured = newMesh(
      @[
        meshVertex(60, 0, 0.5, 0, color = (255'u8, 255'u8, 255'u8, 255'u8)),
        meshVertex(120, 60, 1, 0.5, color = (120'u8, 200'u8, 255'u8, 255'u8)),
        meshVertex(60, 120, 0.5, 1, color = (255'u8, 255'u8, 255'u8, 255'u8)),
        meshVertex(0, 60, 0, 0.5, color = (255'u8, 170'u8, 90'u8, 255'u8)),
      ],
      mode = mdFan,
      texture = checker,
    )
    textured.draw(n, 415, 60),
)

# --- canvas ----------------------------------------------------------------------

var emblem: Canvas

scenes.add Scene(
  name: "canvas",
  w: 560,
  h: 280,
  frames: 2,
  bg: (20'u8, 22'u8, 32'u8, 255'u8),
  init: proc(n: Nim2d) =
    emblem = n.newCanvas(192, 192),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    # Draw the emblem into its own canvas, supersampled like the shot itself.
    n.setCanvas(emblem)
    n.clear(40, 42, 60)
    n.push()
    n.origin()
    n.scale(2, 2)
    n.setColor(255, 220, 90)
    n.circle(48, 48, 34, true)
    n.setColor(40, 42, 60)
    n.circle(60, 40, 26, true)
    n.setColor(teal)
    n.rectangle(10, 10, 76, 76, false, roundness = 12)
    n.pop()
    n.setCanvas(shot)
    # Stamp the one canvas many times, like any image.
    for i in 0 .. 4:
      let x = 70.0 + i.float * 105
      let sc = 0.5 + 0.14 * i.float
      emblem.setColorMod(uint8(255 - i * 30), 255, uint8(200 + i * 10))
      emblem.draw(n, x, 140, i.float * 0.3, 0.5 * sc, 0.5 * sc, 96, 96)
    emblem.setColorMod(255, 255, 255),
)

# --- stencil and scissor -----------------------------------------------------------

scenes.add Scene(
  name: "stencil",
  w: 560,
  h: 280,
  frames: 1,
  bg: (24'u8, 26'u8, 38'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    # Left: diagonal stripes clipped to a star-shaped stencil mask.
    let star = starShape(140, 140, 110, 48, 5)
    n.stencil(
      proc(n: Nim2d) =
        n.polygon(star.xs, star.ys, true)
    )
    for i in 0 .. 16:
      n.setColor(if i mod 2 == 0: orange else: gold)
      n.line(@[(i.float * 36 - 140, 280.0), (i.float * 36, 0.0)], 14)
    n.stencilStop()
    # Right: concentric circles clipped by a scissor rectangle. The scissor is
    # given in render-target pixels and ignores the transform, so the values
    # are doubled to land on the supersampled canvas.
    n.setScissor(660, 100, 380, 360)
    for i in 0 .. 7:
      n.setColor(lerp(sky, navy, i.float / 7))
      n.circle(425, 140, 130 - i.float * 16, true)
    n.setScissor()
    n.setColor(gray(120))
    n.rectangle(330, 50, 190, 180, false),
)

# --- noise, triangulation and a bezier curve ---------------------------------------

var noiseImg: Image

scenes.add Scene(
  name: "noise",
  w: 560,
  h: 300,
  frames: 1,
  bg: (20'u8, 22'u8, 32'u8, 255'u8),
  init: proc(n: Nim2d) =
    let data = newImageData(130, 130)
    data.mapPixel(
      proc(x, y: int32, c: Color): Color =
        let v = noise(x.float * 0.06, y.float * 0.06)
        let w = noise(x.float * 0.18, y.float * 0.18, 4.0)
        let m = uint8(clamp((v * 0.75 + w * 0.25) * 255, 0, 255))
        (uint8(m.float * 0.4), uint8(m.float * 0.75), m, 255'u8)
    )
    noiseImg = n.newImage(data),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    noiseImg.draw(n, 20, 20, 0, 2, 2)
    let star = starShape(390, 100, 70, 28, 7, rot = 0.3)
    n.setColor(gold)
    n.polygon(star.xs, star.ys, true)
    let curve =
      newBezierCurve(@[(310.0, 270.0), (390.0, 150.0), (470.0, 290.0), (540.0, 180.0)])
    n.setColor(cyan)
    n.line(curve.render(50), 4)
    n.setColor(lightgray)
    for p in curve.points:
      n.circle(p.x, p.y, 4, true),
)

# --- a user shader ------------------------------------------------------------------

const plasmaSpv = staticRead("../examples/plasma.spv")
const plasmaMsl = staticRead("../examples/plasma.metal")
var plasma: Shader

scenes.add Scene(
  name: "shader",
  w: 560,
  h: 320,
  frames: 80,
  bg: (0'u8, 0'u8, 0'u8, 255'u8),
  init: proc(n: Nim2d) =
    plasma = n.newShader(plasmaSpv, plasmaMsl, uniformFloats = 4),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    plasma.send([t.float32, 1120'f32, 640'f32, 0'f32])
    n.setShader(plasma)
    n.setColor(255, 255, 255)
    n.rectangle(0, 0, 560, 320, true)
    n.setShader(),
)

# --- physics ------------------------------------------------------------------------

const PxPerMeter = 50.0
var phWorld: World
var phBoxes: seq[tuple[body: Body, half: float]]
var phBalls: seq[tuple[body: Body, radius: float]]

var phScene =
  Scene(name: "physics", w: 560, h: 360, frames: 150, bg: (20'u8, 22'u8, 32'u8, 255'u8))
phScene.init = proc(n: Nim2d) =
  phWorld = newWorld(0.0, 10.0)
  phBoxes.setLen(0)
  phBalls.setLen(0)
  let ground = phWorld.newBody(5.6, 6.9, btStatic)
  ground.addBox(5.6, 0.3)
  let wallL = phWorld.newBody(0.1, 3.6, btStatic)
  wallL.addBox(0.1, 3.6)
  let wallR = phWorld.newBody(11.1, 3.6, btStatic)
  wallR.addBox(0.1, 3.6)
  var drop = newRng(11)
  for i in 0 ..< 14:
    let x = 2.2 + (i mod 7).float * 1.1 + drop.random(-0.18, 0.18)
    let y = -0.5 - (i div 7).float * 1.2
    let b = phWorld.newBody(x, y, btDynamic)
    b.addBox(0.32, 0.32, restitution = 0.15)
    phBoxes.add((b, 0.32))
  for i in 0 ..< 5:
    let b = phWorld.newBody(3.0 + i.float * 1.3, -3.0 - drop.random(1.0), btDynamic)
    b.addCircle(0.26, restitution = 0.4)
    phBalls.add((b, 0.26))
phScene.tick = proc(n: Nim2d, t, dt: float) =
  phWorld.update(dt)
phScene.draw = proc(n: Nim2d, t: float, shot: Canvas) =
  n.setColor(60, 66, 82)
  n.rectangle(0, 6.6 * PxPerMeter, 560, 30, true)
  for (b, half) in phBoxes:
    let (x, y) = b.position
    n.transformed(move = vec2(x * PxPerMeter, y * PxPerMeter), angle = b.angle):
      n.setColor(orange)
      n.rectangle(
        -half * PxPerMeter,
        -half * PxPerMeter,
        half * 2 * PxPerMeter,
        half * 2 * PxPerMeter,
        true,
        roundness = 3,
      )
  for (b, radius) in phBalls:
    let (x, y) = b.position
    let r = radius * PxPerMeter
    n.setColor(sky)
    n.circle(x * PxPerMeter, y * PxPerMeter, r, true)
    n.setColor(navy)
    let a = b.angle
    n.line(
      @[
        (x * PxPerMeter, y * PxPerMeter),
        (x * PxPerMeter + cos(a) * r, y * PxPerMeter + sin(a) * r),
      ],
      2,
    )
scenes.add phScene

# --- snake and pong, as they look in the examples ------------------------------------

scenes.add Scene(
  name: "snake",
  w: 468,
  h: 356,
  frames: 1,
  bg: (16'u8, 20'u8, 24'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    const Cell = 26.0
    const TopBar = 44.0
    proc cellRect(c: tuple[x, y: int], pad: float) =
      n.rectangle(
        c.x.float * Cell + pad,
        c.y.float * Cell + TopBar + pad,
        Cell - pad * 2,
        Cell - pad * 2,
        true,
        5,
      )

    n.setColor(22, 28, 34)
    n.rectangle(0, TopBar, 468, 356 - TopBar, true)
    n.setColor(235, 90, 90)
    cellRect((13, 3), 3)
    let body = [(6, 7), (6, 6), (6, 5), (7, 5), (8, 5), (8, 6), (9, 6), (10, 6)]
    for i, c in body:
      if i == 0:
        n.setColor(150, 240, 130)
      else:
        n.setColor(90, 200, 110)
      cellRect(c, 2)
    n.withFont(textFont):
      n.setColor(235, 240, 255)
      n.print("score: 7", 14, 8),
)

scenes.add Scene(
  name: "pong",
  w: 480,
  h: 300,
  frames: 1,
  bg: (12'u8, 14'u8, 20'u8, 255'u8),
  draw: proc(n: Nim2d, t: float, shot: Canvas) =
    n.setColor(60, 70, 90)
    var y = 8.0
    while y < 300:
      n.rectangle(238, y, 4, 14, true)
      y += 24
    n.withFont(bigFont):
      n.setColor(150, 160, 180)
      n.print("3", 180, 16)
      n.print("5", 276, 16)
    n.setColor(120, 200, 255)
    n.rectangle(24, 96, 12, 70, true)
    n.setColor(255, 150, 120)
    n.rectangle(444, 150, 12, 70, true)
    n.setColor(245, 245, 255)
    n.rectangle(300, 160, 10, 10, true),
)

# --- starfield -------------------------------------------------------------------------

type Star = object
  x, y, z, pz: float

var stars: seq[Star]

var sfScene =
  Scene(name: "starfield", w: 560, h: 360, frames: 70, bg: (4'u8, 4'u8, 10'u8, 255'u8))
sfScene.init = proc(n: Nim2d) =
  stars.setLen(0)
  for _ in 0 ..< 300:
    let z = rng.random(1.0, 560.0)
    stars.add Star(
      x: rng.random(-560.0, 560.0), y: rng.random(-360.0, 360.0), z: z, pz: z
    )
sfScene.tick = proc(n: Nim2d, t, dt: float) =
  for s in stars.mitems:
    s.pz = s.z
    s.z -= 28.0 * dt * 60.0
    if s.z < 1:
      s.x = rng.random(-560.0, 560.0)
      s.y = rng.random(-360.0, 360.0)
      s.z = 560.0
      s.pz = s.z
sfScene.draw = proc(n: Nim2d, t: float, shot: Canvas) =
  # A frame of the starfield shmup: the perspective grid, diving enemies,
  # shots and the player's ship, composed the way the example draws them.
  let cx = 280.0
  let cy = 180.0
  let focal = 250.0
  proc proj(x, y, z: float): Vec2 =
    (cx + x * focal / z, cy + y * focal / z)

  n.setColor(80, 55, 130, 120)
  for k in -5 .. 5:
    let gx = k.float * 0.8
    n.line(@[proj(gx, 1.05, 1.0), proj(gx, 1.05, 12.0)])
  for k in 0 .. 8:
    let zr = 1.0 + floorMod(k.float * 1.4 - 0.6, 11.0)
    n.line(@[proj(-4.0, 1.05, zr), proj(4.0, 1.05, zr)], 1.0 + 1.5 / zr)
  for s in stars:
    let sx = cx + (s.x / s.z) * cx
    let sy = cy + (s.y / s.z) * cy
    let px = cx + (s.x / s.pz) * cx
    let py = cy + (s.y / s.pz) * cy
    let b = uint8(max(0.0, min(1.0, 1.0 - s.z / 560.0)) * 200)
    n.setColor(b, b, 230'u8)
    n.line(@[(px, py), (sx, sy)], (1.0 - s.z / 560.0) * 2.5 + 0.5)
  # a far diamond, a hex tank, a weaving diamond and a dart closing in
  for (dx, dy, dz, spin) in [(0.75, 0.42, 9.0, 1.8), (0.4, -0.25, 3.2, 0.7)]:
    let p = proj(dx, dy, dz)
    let s = 0.16 * focal / dz
    n.transformed(move = p, angle = spin):
      n.setColor(220, 70, 200)
      n.rectangle(-s, -s, s * 2, s * 2, true)
      n.setColor(12, 4, 16)
      n.rectangle(-s * 0.45, -s * 0.45, s * 0.9, s * 0.9, true)
  block:
    let p = proj(-0.55, 0.05, 6.0)
    let s = 0.2 * focal / 6.0
    var xs, ys: array[6, float]
    for k in 0 .. 5:
      let a = 0.4 + k.float / 6.0 * TAU
      xs[k] = p.x + cos(a) * s
      ys[k] = p.y + sin(a) * s
    n.setColor(teal)
    n.polygon(xs, ys, true)
    n.setColor(8, 30, 30)
    n.circle(p.x, p.y, s * 0.4, true)
  block:
    let p = proj(-0.12, 0.3, 2.1)
    let s = 0.12 * focal / 2.1
    n.transformed(move = p, angle = 0.2):
      n.setColor(255, 120, 60)
      n.triangle(0, s * 1.3, s, -s * 0.9, -s, -s * 0.9, true)
      n.setColor(110, 25, 10)
      n.triangle(0, s * 0.55, s * 0.45, -s * 0.5, -s * 0.45, -s * 0.5, true)
  n.withBlend(bmAdd):
    n.setColor(140, 255, 170)
    n.line(@[proj(-0.05, 0.45, 2.4), proj(-0.05, 0.45, 2.9)], 3)
    n.line(@[proj(-0.05, 0.45, 4.6), proj(-0.05, 0.45, 5.2)], 3)
  block:
    let p = proj(-0.05, 0.5, 1.6)
    let s = 0.11 * focal / 1.6
    n.transformed(move = p, angle = 0.1):
      n.setColor(120, 200, 255)
      n.triangle(0, -s * 1.5, -s * 1.5, s * 0.95, -s * 0.2, s * 0.8, true)
      n.triangle(0, -s * 1.5, s * 1.5, s * 0.95, s * 0.2, s * 0.8, true)
      n.setColor(70, 140, 210)
      n.triangle(0, -s * 1.5, -s * 0.5, s * 0.9, s * 0.5, s * 0.9, true)
      n.setColor(235, 240, 255)
      n.triangle(-s * 1.5, s * 0.95, -s * 1.1, s * 0.9, -s * 0.95, s * 0.55, true)
      n.triangle(s * 1.5, s * 0.95, s * 1.1, s * 0.9, s * 0.95, s * 0.55, true)
      n.setColor(15, 30, 60)
      n.triangle(0, -s * 0.9, -s * 0.2, s * 0.1, s * 0.2, s * 0.1, true)
      n.withBlend(bmAdd):
        for ex in [-0.27, 0.27]:
          n.setColor(255, 140, 50)
          n.circle(ex * s, s * 0.92, s * 0.3, true)
          n.setColor(255, 235, 170)
          n.circle(ex * s, s * 0.92, s * 0.17, true)
  n.withFont(labelFont):
    n.setColor(235, 240, 255)
    n.print("score 4350", 12, 8)
    n.print("wave 3", cx - 24, 8)
  for k in 0 .. 2:
    let lx = 560.0 - 22 - k.float * 22
    n.setColor(120, 200, 255)
    n.triangle(lx, 10, lx + 9, 22, lx - 9, 22, true)
scenes.add sfScene

# --- the harness --------------------------------------------------------------------

var sceneIdx = 0
var drawn = 0
var shotCanvas: Canvas

proc startScene(n: Nim2d) =
  let s = scenes[sceneIdx]
  shotCanvas = n.newCanvas(s.w * 2, s.h * 2)
  drawn = 0
  if s.init != nil:
    s.init(n)
  echo "rendering ", s.name, " (", s.w, "x", s.h, ", ", s.frames, " frames)"

proc capture(n: Nim2d, s: Scene) =
  let img = downsample(n.newImageData(shotCanvas))
  img.encode(OutDir / s.name & ".png")
  echo "  wrote ", OutDir / s.name & ".png"

createDir(OutDir)

n2d.load = proc(n: Nim2d) =
  startScene(n)

n2d.update = proc(n: Nim2d, dt: float) =
  # The canvas holds a frame once it has been drawn and that frame submitted,
  # which is the case here because update runs before the next frame starts.
  if drawn >= scenes[sceneIdx].frames:
    capture(n, scenes[sceneIdx])
    inc sceneIdx
    if sceneIdx >= scenes.len:
      n.running = false
    else:
      startScene(n)

n2d.draw = proc(n: Nim2d) =
  if sceneIdx >= scenes.len:
    return
  let s = scenes[sceneIdx]
  let t = drawn.float * Dt
  if s.tick != nil:
    s.tick(n, t, Dt)
  n.setCanvas(shotCanvas)
  n.clear(s.bg.r, s.bg.g, s.bg.b)
  n.push()
  n.scale(2, 2)
  s.draw(n, t, shotCanvas)
  n.pop()
  n.setCanvas()
  shotCanvas.draw(n, 10, 10, 0, 0.45, 0.45)
  inc drawn

n2d.play()
echo "done: ", scenes.len, " screenshots in ", OutDir
