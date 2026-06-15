## Immediate-mode 2D shapes, broken into triangles for the batch renderer.
##
## SDL2_gfx, the old primitive backend, has no SDL3 successor, so every shape is
## turned into triangles or edges here and fed to the GPU batcher. Angles are in
## radians. Outlines are drawn as quad strips.
##
## Coordinates use Nim's default `float` for ergonomics and get converted to
## float32 only when building GPU vertices.

import std/math
import types
import transform
import backend/renderer
import nim2d/math as m # triangulate / isConvex for concave polygon fill

# --- helpers ---------------------------------------------------------------

func norm(c: Color): tuple[r, g, b, a: float32] =
  (c.r.float32 / 255, c.g.float32 / 255, c.b.float32 / 255, c.a.float32 / 255)

proc emitColored(nim2d: Nim2d, verts: openArray[Vertex], idx: openArray[uint32]) =
  nim2d.gpu.addGeometry(pkColored, nim2d.blend, nil, verts, idx)

proc mkVert(x, y: float, c: tuple[r, g, b, a: float32]): Vertex =
  Vertex(x: x.float32, y: y.float32, u: 0, v: 0, r: c.r, g: c.g, b: c.b, a: c.a)

proc fillFan(nim2d: Nim2d, center: Vec2, rim: openArray[Vec2]) =
  ## Triangle fan from `center` around `rim` (convex shapes / sectors).
  if rim.len < 2:
    return
  let c = norm(nim2d.color)
  var verts = newSeq[Vertex](rim.len + 1)
  verts[0] = mkVert(center.x, center.y, c)
  for i, p in rim:
    verts[i + 1] = mkVert(p.x, p.y, c)
  var idx = newSeq[uint32]()
  for i in 0 ..< rim.len - 1:
    idx.add 0'u32
    idx.add uint32(i + 1)
    idx.add uint32(i + 2)
  nim2d.emitColored(verts, idx)

proc segQuad(nim2d: Nim2d, p0, p1: Vec2, width: float) =
  ## A line segment as a quad of the given width.
  let dx = p1.x - p0.x
  let dy = p1.y - p0.y
  let len = sqrt(dx * dx + dy * dy)
  if len <= 0:
    return
  let nx = -dy / len * (width / 2)
  let ny = dx / len * (width / 2)
  let c = norm(nim2d.color)
  let verts = [
    mkVert(p0.x + nx, p0.y + ny, c),
    mkVert(p1.x + nx, p1.y + ny, c),
    mkVert(p1.x - nx, p1.y - ny, c),
    mkVert(p0.x - nx, p0.y - ny, c),
  ]
  nim2d.emitColored(verts, [0'u32, 1, 2, 0, 2, 3])

proc discAt(nim2d: Nim2d, cx, cy, r: float, segs: int) =
  ## A filled disc, used to round off line joins so segments meet without a gap.
  let c = norm(nim2d.color)
  var verts = @[mkVert(cx, cy, c)]
  for i in 0 .. segs:
    let a = TAU * i.float / segs.float
    verts.add mkVert(cx + cos(a) * r, cy + sin(a) * r, c)
  var idx: seq[uint32]
  for i in 1 .. segs:
    idx.add [0'u32, uint32(i), uint32(i + 1)]
  nim2d.emitColored(verts, idx)

proc polyline(nim2d: Nim2d, pts: openArray[Vec2], closed: bool, width = 1.0) =
  if pts.len < 2:
    return
  for i in 0 ..< pts.len - 1:
    nim2d.segQuad(pts[i], pts[i + 1], width)
  if closed and pts.len > 2:
    nim2d.segQuad(pts[^1], pts[0], width)
  # Round joins: fill the corner at each vertex where two segments meet. Thin
  # lines don't need it. Open lines keep flat ends; closed ones join all round.
  if width > 1.5:
    let r = width / 2
    let segs = max(8, int(r))
    if closed:
      for p in pts:
        nim2d.discAt(p.x, p.y, r, segs)
    elif pts.len > 2:
      for i in 1 ..< pts.len - 1:
        nim2d.discAt(pts[i].x, pts[i].y, r, segs)

proc fillConvexFan(nim2d: Nim2d, pts: openArray[Vec2]) =
  ## Fan fill from the polygon centroid (correct for convex polygons).
  if pts.len < 3:
    return
  var cx, cy: float
  for p in pts:
    cx += p.x
    cy += p.y
  cx /= pts.len.float
  cy /= pts.len.float
  var rim = newSeq[Vec2](pts.len + 1)
  for i, p in pts:
    rim[i] = p
  rim[^1] = pts[0]
  nim2d.fillFan((cx, cy), rim)

proc fillPolygon(nim2d: Nim2d, pts: openArray[Vec2]) =
  ## Fill a polygon that may be concave. Convex outlines take the cheap centroid
  ## fan; concave ones are split into triangles by ear clipping. Input that
  ## cannot be triangulated (self-intersecting or degenerate) falls back to the
  ## fan, so drawing never raises.
  if pts.len < 3:
    return
  if m.isConvex(pts):
    nim2d.fillConvexFan(pts)
    return
  var idx: seq[uint32]
  try:
    idx = m.triangulate(pts)
  except ValueError:
    nim2d.fillConvexFan(pts)
    return
  let c = norm(nim2d.color)
  var verts = newSeq[Vertex](pts.len)
  for i, p in pts:
    verts[i] = mkVert(p.x, p.y, c)
  nim2d.emitColored(verts, idx)

iterator arcPoints(cx, cy, rx, ry, a1, a2: float, segments: int): Vec2 =
  let steps = max(segments, 1)
  for i in 0 .. steps:
    let t = a1 + (a2 - a1) * (i.float / steps.float)
    yield (cx + cos(t) * rx, cy + sin(t) * ry)

# --- state -----------------------------------------------------------------

proc setColor*(nim2d: Nim2d, r, g, b: uint8, a: uint8 = 255) =
  ## Set the color used by shapes and text until it is changed again. Channels
  ## are bytes from 0 to 255, and alpha defaults to fully opaque.
  nim2d.color = (r, g, b, a)

proc setColor*(nim2d: Nim2d, c: Color) =
  ## Set the draw color from a Color, so named colors, `rgb`, `gray` and hex all
  ## work: `setColor(orange)`, `setColor(rgb(255, 120, 60))`, `setColor(color("#ff7a3c"))`.
  nim2d.color = c

proc setBackgroundColor*(nim2d: Nim2d, r, g, b: uint8, a: uint8 = 255) =
  ## Set the color the window clears to at the start of every frame.
  nim2d.background = (r, g, b, a)

proc setBackgroundColor*(nim2d: Nim2d, c: Color) =
  ## Set the background color from a Color.
  nim2d.background = c

proc setBlendMode*(nim2d: Nim2d, mode: BlendMode) =
  ## Set how drawing mixes with what is already there: `bmAlpha` (the default),
  ## `bmAdd` for brightening glow effects, `bmMod` to darken, `bmNone` to
  ## overwrite without blending.
  nim2d.blend = mode

proc setBlendMode*(nim2d: Nim2d, mode: string) =
  ## Set the blend mode by name: "blend" or "alpha", "add", "mod" or
  ## "multiply". Anything else turns blending off.
  nim2d.blend =
    case mode
    of "blend", "alpha": bmAlpha
    of "add": bmAdd
    of "mod", "multiply": bmMod
    else: bmNone

# --- transform stack -------------------------------------------------------

proc push*(nim2d: Nim2d) =
  ## Save the current transform so a later `pop` restores it.
  nim2d.gpu.transformStack.add nim2d.gpu.transform

proc pop*(nim2d: Nim2d) =
  ## Restore the transform saved by the matching `push`.
  if nim2d.gpu.transformStack.len > 0:
    nim2d.gpu.transform = nim2d.gpu.transformStack.pop()

proc origin*(nim2d: Nim2d) =
  ## Reset the current transform to the identity.
  nim2d.gpu.transform = identity()

proc translate*(nim2d: Nim2d, dx, dy: float) =
  ## Shift the coordinate system by (dx, dy). Everything drawn afterwards moves
  ## with it.
  nim2d.gpu.transform = nim2d.gpu.transform.translate(dx, dy)

proc rotate*(nim2d: Nim2d, radians: float) =
  ## Turn the coordinate system around the current origin.
  nim2d.gpu.transform = nim2d.gpu.transform.rotate(radians)

proc scale*(nim2d: Nim2d, sx, sy: float) =
  ## Stretch the coordinate system by sx and sy.
  nim2d.gpu.transform = nim2d.gpu.transform.scale(sx, sy)

proc shear*(nim2d: Nim2d, kx, ky: float) =
  ## Slant the coordinate system by the factors kx and ky.
  nim2d.gpu.transform = nim2d.gpu.transform.shear(kx, ky)

# --- scissor ---------------------------------------------------------------

proc setScissor*(nim2d: Nim2d, x, y, w, h: float) =
  ## Clip drawing to a rectangle until the scissor is cleared.
  nim2d.gpu.curScissor =
    Scissor(on: true, x: x.int32, y: y.int32, w: w.int32, h: h.int32)

proc setScissor*(nim2d: Nim2d) =
  ## Stop clipping.
  nim2d.gpu.curScissor = Scissor(on: false)

# --- shapes ----------------------------------------------------------------

proc circle*(nim2d: Nim2d, x, y, radius: float, filled = false, segments = 48) =
  ## A circle centered at (x, y), outlined by default and solid with `filled`.
  ## More `segments` make it rounder, fewer make it cheaper.
  var rim = newSeq[Vec2]()
  for p in arcPoints(x, y, radius, radius, 0, TAU, segments):
    rim.add p
  if filled:
    nim2d.fillFan((x, y), rim)
  else:
    nim2d.polyline(rim, closed = false)

proc ellipse*(nim2d: Nim2d, x, y, rx, ry: float, filled = false, segments = 48) =
  ## An ellipse centered at (x, y) with the radii rx and ry.
  var rim = newSeq[Vec2]()
  for p in arcPoints(x, y, rx, ry, 0, TAU, segments):
    rim.add p
  if filled:
    nim2d.fillFan((x, y), rim)
  else:
    nim2d.polyline(rim, closed = false)

proc arc*(nim2d: Nim2d, x, y, radius, a1, a2: float, segments = 48) =
  ## Part of a circle outline between the angles a1 and a2, in radians measured
  ## clockwise from the right (y points down).
  var pts = newSeq[Vec2]()
  for p in arcPoints(x, y, radius, radius, a1, a2, segments):
    pts.add p
  nim2d.polyline(pts, closed = false)

proc pie*(nim2d: Nim2d, x, y, radius, a1, a2: float, filled = false, segments = 48) =
  ## A wedge from the center (x, y) between the angles a1 and a2, like a slice
  ## of pie. Outlined by default, solid with `filled`.
  var rim = newSeq[Vec2]()
  for p in arcPoints(x, y, radius, radius, a1, a2, segments):
    rim.add p
  if filled:
    nim2d.fillFan((x, y), rim)
  else:
    nim2d.polyline(rim, closed = false)
    nim2d.segQuad((x, y), rim[0], 1)
    nim2d.segQuad((x, y), rim[^1], 1)

proc roundedRectPoints(x, y, w, h, r: float, seg = 8): seq[Vec2] =
  let rr = min(r, min(w, h) / 2)
  result = @[]
  for p in arcPoints(x + w - rr, y + rr, rr, rr, -PI / 2, 0, seg):
    result.add p
  for p in arcPoints(x + w - rr, y + h - rr, rr, rr, 0, PI / 2, seg):
    result.add p
  for p in arcPoints(x + rr, y + h - rr, rr, rr, PI / 2, PI, seg):
    result.add p
  for p in arcPoints(x + rr, y + rr, rr, rr, PI, 3 * PI / 2, seg):
    result.add p

proc rectangle*(nim2d: Nim2d, x, y, w, h: float, filled = false, roundness = 0.0) =
  ## A rectangle with its top-left corner at (x, y). A `roundness` above zero
  ## rounds the corners by that radius.
  if roundness > 0:
    let pts = roundedRectPoints(x, y, w, h, roundness)
    if filled:
      nim2d.fillConvexFan(pts)
    else:
      nim2d.polyline(pts, closed = true)
  else:
    let pts = @[(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    if filled:
      nim2d.fillConvexFan(pts)
    else:
      nim2d.polyline(pts, closed = true)

proc triangle*(nim2d: Nim2d, x1, y1, x2, y2, x3, y3: float, filled = false) =
  ## A triangle through three points.
  let pts = @[(x1, y1), (x2, y2), (x3, y3)]
  if filled:
    nim2d.fillConvexFan(pts)
  else:
    nim2d.polyline(pts, closed = true)

proc polygon*(nim2d: Nim2d, xs, ys: openArray[float], filled = false) =
  ## A closed polygon through the points given as parallel x and y arrays. The
  ## fill works for concave outlines too, so a star or an arrow fills
  ## correctly. Raises ValueError when the arrays differ in length or hold
  ## fewer than 3 points.
  if xs.len != ys.len:
    raise newException(ValueError, "polygon: x and y must have equal length")
  if xs.len < 3:
    raise newException(ValueError, "polygon: need at least 3 points")
  var pts = newSeq[Vec2](xs.len)
  for i in 0 ..< xs.len:
    pts[i] = (xs[i], ys[i])
  if filled:
    nim2d.fillPolygon(pts)
  else:
    nim2d.polyline(pts, closed = true)

proc line*(nim2d: Nim2d, points: openArray[Vec2], width = 1.0) =
  ## A polyline through the points. Lines wider than a couple of pixels get
  ## round joins where segments meet.
  nim2d.polyline(points, closed = false, width)

proc points*(nim2d: Nim2d, pts: openArray[Vec2], size = 1.0) =
  ## A square dot of the given size at each point.
  let c = norm(nim2d.color)
  let h = size / 2
  for p in pts:
    let verts = [
      mkVert(p.x - h, p.y - h, c),
      mkVert(p.x + h, p.y - h, c),
      mkVert(p.x + h, p.y + h, c),
      mkVert(p.x - h, p.y + h, c),
    ]
    nim2d.emitColored(verts, [0'u32, 1, 2, 0, 2, 3])

proc stencil*(nim2d: Nim2d, mask: proc(nim2d: Nim2d)) =
  ## Draw `mask` into the stencil buffer, then clip following drawing to where the
  ## mask drew. The mask shapes themselves are not visible. Call `stencilStop` to
  ## stop clipping. Needs a window created with `stencil = true`; without it this
  ## does nothing and drawing is unclipped.
  if not nim2d.gpu.stencilEnabled:
    return
  nim2d.gpu.stencilMode = 1
  mask(nim2d)
  nim2d.gpu.stencilMode = 2

proc stencilStop*(nim2d: Nim2d) =
  ## Stop clipping to the stencil mask; drawing appears everywhere again.
  nim2d.gpu.stencilMode = 0
