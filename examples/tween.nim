## A chart of every easing curve in the tween module. Each cell plots one curve,
## with t running left to right and the eased value bottom to top, and a dot
## traces along it on a shared clock so you can see the motion as well as the
## shape. The rows are the curve families and the columns are the in, out and
## in-out variants. The dashed levels mark 0 and 1, so the curves that overshoot,
## back and elastic, visibly cross them.
##
## The ball along the top rides one curve at a time using a `VecTween`, easing a
## point from the left tick to the right one, then picking the next curve on each
## loop. That is the value-tween side of the module, the same `newTween`, `update`
## and `value` you would use to slide a menu in or hop a character.
##
## Space pauses, R restarts, Esc quits.

import std/os
import nim2d
import nim2d/tween

const
  W = 980
  H = 760
  Margin = 24.0
  GutterW = 96.0
  ColGap = 16.0
  TopBand = 136.0
  HeaderH = 24.0
  HintH = 30.0
  GridTop = TopBand + HeaderH
  GridLeft = Margin + GutterW
  GridRight = W.float - Margin
  GridW = GridRight - GridLeft
  ColW = (GridW - 2.0 * ColGap) / 3.0
  GridBottom = H.float - HintH
  GridH = GridBottom - GridTop
  RowGap = 8.0
  RowH = (GridH - 9.0 * RowGap) / 10.0
  PlotMin = -0.32 # vertical headroom so overshoot stays inside the cell
  PlotMax = 1.32
  LoopTime = 1.9
  HoldTime = 0.5
  RunY = 104.0
  RunLeft = GridLeft + 20.0
  RunRight = W.float - 160.0

type Family = tuple[name: string, curves: array[3, Easing]]

const families: array[10, Family] = [
  (name: "quad", curves: [Easing.quadIn, Easing.quadOut, Easing.quadInOut]),
  (name: "cubic", curves: [Easing.cubicIn, Easing.cubicOut, Easing.cubicInOut]),
  (name: "quart", curves: [Easing.quartIn, Easing.quartOut, Easing.quartInOut]),
  (name: "quint", curves: [Easing.quintIn, Easing.quintOut, Easing.quintInOut]),
  (name: "sine", curves: [Easing.sineIn, Easing.sineOut, Easing.sineInOut]),
  (name: "expo", curves: [Easing.expoIn, Easing.expoOut, Easing.expoInOut]),
  (name: "circ", curves: [Easing.circIn, Easing.circOut, Easing.circInOut]),
  (name: "back", curves: [Easing.backIn, Easing.backOut, Easing.backInOut]),
  (name: "elastic", curves: [Easing.elasticIn, Easing.elasticOut, Easing.elasticInOut]),
  (name: "bounce", curves: [Easing.bounceIn, Easing.bounceOut, Easing.bounceInOut]),
]

const familyColors = [
  rgb(120, 200, 255),
  rgb(120, 230, 205),
  rgb(150, 230, 130),
  rgb(205, 230, 120),
  rgb(245, 220, 120),
  rgb(245, 180, 110),
  rgb(245, 145, 120),
  rgb(235, 130, 175),
  rgb(200, 145, 235),
  rgb(150, 165, 240),
]

# the featured tour the top runner cycles through, one curve per loop
const tour = [
  Easing.quadInOut, Easing.cubicOut, Easing.backOut, Easing.elasticOut,
  Easing.bounceOut, Easing.sineInOut, Easing.expoOut, Easing.backInOut,
  Easing.elasticInOut, Easing.circInOut,
]

const runStart: Vec2 = (RunLeft, RunY)
const runEnd: Vec2 = (RunRight, RunY)

let n2d =
  newNim2d("nim2d - tween", 100, 60, W.cint, H.cint, (16'u8, 18'u8, 26'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 16)
let small = newFont(getAppDir() / "font.ttf", 13)
let big = newFont(getAppDir() / "font.ttf", 26)

var
  clock = newTween(0.0, 1.0, LoopTime, Easing.linear)
  hold = 0.0
  paused = false
  featured = 0
  runner = newTween(runStart, runEnd, LoopTime, tour[featured])

proc drawCell(nim2d: Nim2d, x, y: float, easing: Easing, col: Color, t: float) =
  const pad = 6.0
  let
    plotX = x + pad
    plotY = y + pad
    pw = ColW - 2.0 * pad
    ph = RowH - 2.0 * pad
    span = PlotMax - PlotMin
  proc plot(tt: float): Vec2 =
    (plotX + tt * pw, plotY + ph - (ease(easing, tt) - PlotMin) / span * ph)

  nim2d.setColor(rgb(26, 30, 42))
  nim2d.rectangle(x, y, ColW, RowH, true, roundness = 6)
  nim2d.setColor(rgb(46, 52, 70))
  nim2d.rectangle(x, y, ColW, RowH, false, roundness = 6)

  # the 0 and 1 levels, so overshoot past them is easy to spot
  let
    y0 = plotY + ph - (0.0 - PlotMin) / span * ph
    y1 = plotY + ph - (1.0 - PlotMin) / span * ph
  nim2d.setColor(gray(130).withAlpha(45))
  nim2d.line(@[(plotX, y0), (plotX + pw, y0)], 1.0)
  nim2d.line(@[(plotX, y1), (plotX + pw, y1)], 1.0)

  # a faint guide at the current time
  let gx = plotX + t * pw
  nim2d.setColor(gray(160).withAlpha(30))
  nim2d.line(@[(gx, plotY), (gx, plotY + ph)], 1.0)

  # the curve itself, sampled into a polyline
  var pts: seq[Vec2]
  const segs = 32
  for k in 0 .. segs:
    pts.add plot(k.float / segs.float)
  nim2d.setColor(col)
  nim2d.line(pts, 2.0)

  # the dot tracing the curve on the shared clock
  let d = plot(t)
  nim2d.setColor(rgb(255, 244, 214))
  nim2d.circle(d.x, d.y, 3.5, true)

proc drawTopBand(nim2d: Nim2d) =
  nim2d.setFont(big)
  nim2d.setColor(rgb(232, 238, 252))
  nim2d.print("Easing curves", Margin, 16)
  nim2d.setFont(small)
  nim2d.setColor(rgb(150, 160, 185))
  nim2d.print(
    "every easing in the tween module on one clock, with a ball up top riding one curve at a time",
    Margin, 52,
  )

  nim2d.setColor(gray(120).withAlpha(70))
  nim2d.line(@[(RunLeft, RunY), (RunRight, RunY)], 2.0)
  for ex in [RunLeft, RunRight]:
    nim2d.line(@[(ex, RunY - 7.0), (ex, RunY + 7.0)], 2.0)

  let p = runner.value
  let name = $tour[featured]
  nim2d.setFont(font)
  nim2d.setColor(rgb(255, 244, 214))
  nim2d.print(name, p.x - font.getSize(name).w.float / 2, RunY - 30)
  nim2d.withBlend(bmAdd):
    nim2d.setColor(rgb(255, 210, 120).withAlpha(80))
    nim2d.circle(p.x, p.y, 16, true)
  nim2d.setColor(rgb(255, 236, 180))
  nim2d.circle(p.x, p.y, 8, true)

proc drawHeaders(nim2d: Nim2d) =
  nim2d.setFont(small)
  const labels = ["ease in", "ease out", "ease in-out"]
  nim2d.setColor(rgb(160, 170, 195))
  for j in 0 .. 2:
    let cx = GridLeft + j.float * (ColW + ColGap)
    nim2d.print(
      labels[j], cx + ColW / 2 - small.getSize(labels[j]).w.float / 2, TopBand
    )

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  case key
  of Key.space:
    paused = not paused
  of Key.r:
    clock.reset()
    hold = 0.0
    featured = 0
    runner = newTween(runStart, runEnd, LoopTime, tour[featured])
  of Key.escape:
    nim2d.running = false
  else:
    discard

n2d.update = proc(nim2d: Nim2d, dt: float) =
  if paused:
    return
  clock.update(dt)
  runner.update(dt)
  if clock.done:
    hold += dt
    if hold >= HoldTime:
      hold = 0.0
      clock.reset()
      featured = (featured + 1) mod tour.len
      runner = newTween(runStart, runEnd, LoopTime, tour[featured])

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.drawTopBand()
  nim2d.drawHeaders()
  let t = clock.value
  for i in 0 .. families.high:
    let cy = GridTop + i.float * (RowH + RowGap)
    nim2d.setFont(font)
    nim2d.setColor(familyColors[i])
    let name = families[i].name
    nim2d.print(name, Margin, cy + RowH / 2 - font.getSize(name).h.float / 2)
    for j in 0 .. 2:
      let cx = GridLeft + j.float * (ColW + ColGap)
      nim2d.drawCell(cx, cy, families[i].curves[j], familyColors[i], t)
  nim2d.setFont(small)
  nim2d.setColor(rgb(120, 130, 155))
  nim2d.print("space pause    R restart    Esc quit", Margin, H.float - 22)

n2d.play()
