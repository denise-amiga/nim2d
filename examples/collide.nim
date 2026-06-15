## A live reference for the collide module. Each panel demonstrates one test,
## reacting to the mouse. Hover a panel and a probe shape appears, turning green
## when the test reports a hit, so you can see exactly what each function does.
##
## The four `pointIn` panels fill when the cursor is inside the shape. The
## overlap panels show a probe you drag against a fixed shape. The resolve panels
## draw the probe pushed back out of a solid box by the vector the resolve
## returns, and the segment panel crosses a moving line over a fixed one.
##
## There is nothing to win here and no movement keys. Move the mouse, press Esc
## to quit.

import std/[math, os]
import nim2d
import nim2d/collide

const
  W = 900
  H = 620
  Margin = 22.0
  Gap = 14.0
  TopBar = 54.0
  Cols = 4
  Rows = 3
  CellW = (W.float - 2 * Margin - (Cols - 1).float * Gap) / Cols.float
  CellH = (H.float - TopBar - Margin - (Rows - 1).float * Gap) / Rows.float

type Demo = enum
  dPointRect = "pointInRect"
  dPointCircle = "pointInCircle"
  dPointTri = "pointInTriangle"
  dPointPoly = "pointInPolygon"
  dRects = "rectsOverlap"
  dCircles = "circlesOverlap"
  dCircleRect = "circleRectOverlap"
  dSegments = "segmentsIntersect"
  dResolveCircle = "resolveCircleRect"
  dResolveRect = "resolveRect"

const demos = [
  dPointRect, dPointCircle, dPointTri, dPointPoly, dRects, dCircles, dCircleRect,
  dSegments, dResolveCircle, dResolveRect,
]

let n2d =
  newNim2d("nim2d - collide", 110, 70, W.cint, H.cint, (16'u8, 18'u8, 26'u8, 255'u8))
let titleFont = newFont(getAppDir() / "font.ttf", 22)
let labelFont = newFont(getAppDir() / "font.ttf", 14)

let
  panel = rgb(24, 27, 37)
  edge = rgb(46, 52, 70)
  idle = rgb(95, 108, 145)
  hit = rgb(80, 205, 110)
  probe = rgb(120, 200, 255)
  solid = rgb(70, 78, 104)

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  if key == Key.escape:
    nim2d.running = false

proc clampIn(m: Vec2, x, y, w, h, pad: float): Vec2 =
  ## The mouse pinned inside a panel's content area, with room for a shape.
  (clamp(m.x, x + pad, x + w - pad), clamp(m.y, y + pad, y + h - pad))

n2d.draw = proc(nim2d: Nim2d) =
  let mouse = mousePosition()

  nim2d.setFont(titleFont)
  nim2d.setColor(235, 240, 255)
  nim2d.print("collide tests, live under the mouse", Margin, 12)

  for i, demo in demos:
    let col = i mod Cols
    let row = i div Cols
    let cx = Margin + col.float * (CellW + Gap)
    let cy = TopBar + row.float * (CellH + Gap)

    nim2d.setColor(panel)
    nim2d.rectangle(cx, cy, CellW, CellH, true, roundness = 8)
    nim2d.setColor(edge)
    nim2d.rectangle(cx, cy, CellW, CellH, false, roundness = 8)
    nim2d.withFont(labelFont):
      nim2d.setColor(165, 175, 200)
      nim2d.print($demo, cx + 12, cy + 9)

    # the content area below the title, and its center
    let ix = cx + 16
    let iy = cy + 34
    let iw = CellW - 32
    let ih = CellH - 46
    let mid: Vec2 = (ix + iw / 2, iy + ih / 2)
    let active = pointInRect(mouse, cx, cy, CellW, CellH)

    case demo
    of dPointRect:
      let rw = 96.0
      let rh = 58.0
      let on = pointInRect(mouse, mid.x - rw / 2, mid.y - rh / 2, rw, rh)
      nim2d.setColor(if on: hit else: idle)
      nim2d.rectangle(mid.x - rw / 2, mid.y - rh / 2, rw, rh, on, roundness = 5)
    of dPointCircle:
      let on = pointInCircle(mouse, mid.x, mid.y, 40)
      nim2d.setColor(if on: hit else: idle)
      nim2d.circle(mid.x, mid.y, 40, on)
    of dPointTri:
      let a: Vec2 = (mid.x, mid.y - 42)
      let b: Vec2 = (mid.x - 50, mid.y + 34)
      let c: Vec2 = (mid.x + 50, mid.y + 34)
      let on = pointInTriangle(mouse, a, b, c)
      nim2d.setColor(if on: hit else: idle)
      nim2d.triangle(a.x, a.y, b.x, b.y, c.x, c.y, on)
    of dPointPoly:
      var xs, ys: seq[float]
      var pts: seq[Vec2]
      for k in 0 ..< 5:
        let ang = -PI / 2 + k.float / 5.0 * TAU
        let p: Vec2 = (mid.x + cos(ang) * 44, mid.y + sin(ang) * 44)
        pts.add p
        xs.add p.x
        ys.add p.y
      let on = pointInPolygon(mouse, pts)
      nim2d.setColor(if on: hit else: idle)
      nim2d.polygon(xs, ys, on)
    of dRects:
      let fw = 68.0
      let fh = 50.0
      nim2d.setColor(idle)
      nim2d.rectangle(mid.x - fw / 2, mid.y - fh / 2, fw, fh, false, roundness = 4)
      if active:
        let mw = 54.0
        let mh = 42.0
        let p = clampIn(mouse, ix, iy, iw, ih, 28)
        let on = rectsOverlap(
          mid.x - fw / 2, mid.y - fh / 2, fw, fh, p.x - mw / 2, p.y - mh / 2, mw, mh
        )
        nim2d.setColor(if on: hit else: probe)
        nim2d.rectangle(p.x - mw / 2, p.y - mh / 2, mw, mh, true, roundness = 4)
    of dCircles:
      nim2d.setColor(idle)
      nim2d.circle(mid.x, mid.y, 34, false)
      if active:
        let p = clampIn(mouse, ix, iy, iw, ih, 26)
        let on = circlesOverlap(mid.x, mid.y, 34, p.x, p.y, 24)
        nim2d.setColor(if on: hit else: probe)
        nim2d.circle(p.x, p.y, 24, true)
    of dCircleRect:
      let fw = 84.0
      let fh = 54.0
      nim2d.setColor(idle)
      nim2d.rectangle(mid.x - fw / 2, mid.y - fh / 2, fw, fh, false, roundness = 4)
      if active:
        let p = clampIn(mouse, ix, iy, iw, ih, 24)
        let on = circleRectOverlap(p.x, p.y, 22, mid.x - fw / 2, mid.y - fh / 2, fw, fh)
        nim2d.setColor(if on: hit else: probe)
        nim2d.circle(p.x, p.y, 22, true)
    of dSegments:
      let s1: Vec2 = (ix + 8, iy + ih - 8)
      let s2: Vec2 = (ix + iw - 8, iy + 10)
      nim2d.setColor(idle)
      nim2d.line(@[s1, s2], 3)
      if active:
        let anchor: Vec2 = (ix + 8, iy + 8)
        let tip = clampIn(mouse, ix, iy, iw, ih, 2)
        let on = segmentsIntersect(s1, s2, anchor, tip)
        nim2d.setColor(if on: hit else: probe)
        nim2d.line(@[anchor, tip], 3)
    of dResolveCircle:
      let fw = 84.0
      let fh = 54.0
      let fx = mid.x - fw / 2
      let fy = mid.y - fh / 2
      nim2d.setColor(solid)
      nim2d.rectangle(fx, fy, fw, fh, true, roundness = 4)
      if active:
        let p = clampIn(mouse, ix, iy, iw, ih, 22)
        let mtv = resolveCircleRect(p.x, p.y, 22, fx, fy, fw, fh)
        if mtv.x != 0 or mtv.y != 0:
          nim2d.setColor(rgb(245, 90, 80).withAlpha(110))
          nim2d.circle(p.x, p.y, 22, true) # where it would overlap
          nim2d.setColor(245, 150, 60)
          nim2d.line(@[p, (p.x + mtv.x, p.y + mtv.y)], 2) # the push vector
        nim2d.setColor(probe)
        nim2d.circle(p.x + mtv.x, p.y + mtv.y, 22, true) # pushed clear
    of dResolveRect:
      let fw = 78.0
      let fh = 54.0
      let fx = mid.x - fw / 2
      let fy = mid.y - fh / 2
      nim2d.setColor(solid)
      nim2d.rectangle(fx, fy, fw, fh, true, roundness = 4)
      if active:
        let mw = 50.0
        let mh = 40.0
        let p = clampIn(mouse, ix, iy, iw, ih, 26)
        let mx = p.x - mw / 2
        let my = p.y - mh / 2
        let mtv = resolveRect(mx, my, mw, mh, fx, fy, fw, fh)
        if mtv.x != 0 or mtv.y != 0:
          nim2d.setColor(rgb(245, 90, 80).withAlpha(110))
          nim2d.rectangle(mx, my, mw, mh, true, roundness = 4)
          nim2d.setColor(245, 150, 60)
          nim2d.line(@[(p.x, p.y), (p.x + mtv.x, p.y + mtv.y)], 2)
        nim2d.setColor(probe)
        nim2d.rectangle(mx + mtv.x, my + mtv.y, mw, mh, true, roundness = 4)

  # the cursor, so the point tests have a visible point
  nim2d.setColor(white.withAlpha(170))
  nim2d.line(@[(mouse.x - 7, mouse.y), (mouse.x + 7, mouse.y)])
  nim2d.line(@[(mouse.x, mouse.y - 7), (mouse.x, mouse.y + 7)])

n2d.play()
