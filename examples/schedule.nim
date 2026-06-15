## A scheduler driving a small clockwork. A metronome runs on `every`, pulsing
## the ring in the middle on each beat. Every beat also queues an offbeat with
## `after`, halfway to the next one, and every fourth beat starts a `during`
## sweep that fills the bar at the top over its run. The feed on the right lists
## the callbacks as they fire, so you can watch the timing happen.
##
## Click anywhere to queue a short burst, four drops marching out from the cursor
## one `after` at a time. Space cancels and re-arms the metronome, C clears every
## timer at once, and Esc quits.

import std/[math, os, strformat]
import nim2d
import nim2d/schedule

const
  W = 900
  H = 600
  Margin = 24.0
  BeatTime = 0.6
  RingX = 250.0
  RingY = 330.0
  BaseR = 56.0
  BarX = Margin
  BarY = 92.0
  BarW = 380.0
  BarH = 12.0
  FeedX = 600.0
  FeedTop = 150.0

const
  accent = rgb(120, 200, 255)
  offColor = rgb(245, 205, 120)
  sweepColor = rgb(150, 230, 160)
  dropColor = rgb(235, 150, 200)
  dimText = rgb(150, 160, 185)

let n2d =
  newNim2d("nim2d - schedule", 100, 60, W.cint, H.cint, (16'u8, 18'u8, 26'u8, 255'u8))
let small = newFont(getAppDir() / "font.ttf", 13)
let big = newFont(getAppDir() / "font.ttf", 26)

type Drop = object
  pos: Vec2
  life: float

var
  sched = newScheduler()
  time = 0.0
  beatCount = 0
  beatFlash = 0.0
  offFlash = 0.0
  duringFill = 0.0
  duringActive = false
  drops: seq[Drop]
  feed: seq[tuple[t: float, msg: string]]
  metroId: TimerId
  metroOn = false

proc logEvent(msg: string) =
  feed.insert((t: time, msg: msg), 0)
  if feed.len > 10:
    feed.setLen(10)

proc onBeat() =
  inc beatCount
  beatFlash = 1.0
  logEvent("every: beat " & $beatCount)

  let offbeat = proc() =
    offFlash = 1.0
    logEvent("after: offbeat")
  sched.after(BeatTime * 0.5, offbeat)

  if beatCount mod 4 == 0:
    duringActive = true
    duringFill = 0.0
    let sweep = proc(dt: float) =
      duringFill += dt / BeatTime
    let sweepDone = proc() =
      duringActive = false
      logEvent("during: sweep done")
    sched.during(BeatTime, sweep, sweepDone)

proc armMetronome() =
  metroId = sched.every(BeatTime, onBeat)
  metroOn = true

proc dropAt(p: Vec2, delay: float) =
  let land = proc() =
    drops.add Drop(pos: p, life: 1.0)
  sched.after(delay, land)

armMetronome()

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  case key
  of Key.space:
    if metroOn:
      sched.cancel(metroId)
      metroOn = false
      logEvent("cancel: metronome")
    else:
      armMetronome()
      logEvent("every: metronome on")
  of Key.c:
    # drop every timer and wipe the board back to empty, so the clear is plain to
    # see rather than looking like a pause
    sched.clear()
    metroOn = false
    drops.setLen(0)
    feed.setLen(0)
    duringActive = false
    duringFill = 0.0
    beatCount = 0
    beatFlash = 0.0
    offFlash = 0.0
  of Key.escape:
    nim2d.running = false
  else:
    discard

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  for k in 0 ..< 4:
    let p: Vec2 = (x + k.float * 26.0, y)
    dropAt(p, 0.12 * (k + 1).float)

n2d.update = proc(nim2d: Nim2d, dt: float) =
  time += dt
  sched.update(dt)
  beatFlash *= exp(-7.0 * dt)
  offFlash *= exp(-9.0 * dt)
  var live: seq[Drop]
  for d in drops:
    if d.life > 0.03:
      live.add Drop(pos: d.pos, life: d.life * exp(-2.6 * dt))
  drops = live

proc drawHeader(nim2d: Nim2d) =
  nim2d.setFont(big)
  nim2d.setColor(rgb(232, 238, 252))
  nim2d.print("Scheduler", Margin, 16)
  nim2d.setFont(small)
  nim2d.setColor(dimText)
  nim2d.print(&"t {time:6.1f}s     beats {beatCount}", Margin, 54)
  let status = if metroOn: "metronome on" else: "metronome off (space to start)"
  nim2d.setColor(
    if metroOn:
      sweepColor
    else:
      rgb(210, 130, 120)
  )
  nim2d.print(status, 230, 54)

proc drawSweep(nim2d: Nim2d) =
  nim2d.setColor(rgb(46, 52, 70))
  nim2d.rectangle(BarX, BarY, BarW, BarH, false, roundness = 4)
  if duringActive:
    nim2d.setColor(sweepColor)
    nim2d.rectangle(
      BarX, BarY, BarW * clamp(duringFill, 0.0, 1.0), BarH, true, roundness = 4
    )
  nim2d.setFont(small)
  nim2d.setColor(dimText)
  nim2d.print("during: a sweep on every fourth beat", BarX, BarY + 18)

proc drawRing(nim2d: Nim2d) =
  let r = BaseR + beatFlash * 38.0
  nim2d.withBlend(bmAdd):
    nim2d.setColor(accent.withAlpha(int(35 + beatFlash * 120)))
    nim2d.circle(RingX, RingY, r * 1.35, true, 52)
  nim2d.setColor(accent)
  nim2d.circle(RingX, RingY, r, false, 56)
  nim2d.setColor(accent.withAlpha(int(110 + beatFlash * 130)))
  nim2d.circle(RingX, RingY, r * 0.46, true)
  nim2d.setFont(small)
  nim2d.setColor(dimText)
  let lbl = &"every {BeatTime:.1f}s"
  nim2d.print(lbl, RingX - small.getSize(lbl).w.float / 2, RingY + BaseR + 56)

  # the offbeat, flashing halfway between beats
  let oy = RingY - BaseR - 40
  nim2d.withBlend(bmAdd):
    nim2d.setColor(offColor.withAlpha(int(30 + offFlash * 200)))
    nim2d.circle(RingX, oy, 8.0 + offFlash * 9.0, true)
  nim2d.setColor(dimText)
  nim2d.print(
    "after: offbeat", RingX - small.getSize("after: offbeat").w.float / 2, oy - 30
  )

proc drawDrops(nim2d: Nim2d) =
  for d in drops:
    let rr = 6.0 + (1.0 - d.life) * 30.0
    nim2d.setColor(dropColor.withAlpha(int(d.life * 210)))
    nim2d.circle(d.pos.x, d.pos.y, rr, false, 28)

proc drawFeed(nim2d: Nim2d) =
  nim2d.setFont(small)
  nim2d.setColor(dimText)
  nim2d.print("events", FeedX, FeedTop - 28)
  var y = FeedTop
  for i, e in feed:
    let fade = 1.0 - i.float / (feed.len.float + 2.0)
    nim2d.setColor(rgb(214, 220, 236).withAlpha(int(50 + fade * 190)))
    nim2d.print(&"{e.t:6.1f}  {e.msg}", FeedX, y)
    y += 22.0

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.drawHeader()
  nim2d.drawSweep()
  nim2d.drawRing()
  nim2d.drawDrops()
  nim2d.drawFeed()
  nim2d.setFont(small)
  nim2d.setColor(dimText)
  nim2d.print(
    "click to queue a burst    space metronome    C clear    Esc quit",
    Margin,
    H.float - 26,
  )

n2d.play()
