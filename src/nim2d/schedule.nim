## Timers that fire callbacks, advanced from your update.
##
## Games are full of things that should happen later or on a beat. Spawn a wave
## every few seconds, flash a message for half a second, fire a shot after a
## short wind-up, blink a cursor. Wiring each of those up as its own countdown
## variable is repetitive. A `Scheduler` keeps the counters for you. You hand it
## a delay and a callback, advance it once per frame from `update`, and it calls
## the callback when the time comes.
##
## `after` runs a callback once after a delay. `every` runs one on a repeat, for
## a set number of times or forever. `during` calls a callback every frame for a
## stretch of time, handing it the frame's `dt`, which suits an effect that has
## to run continuously for a moment, like a shake or a fade. Each returns a
## `TimerId` you can hand to `cancel`, and `clear` drops every timer at once.
##
## The callbacks are ordinary closures, so they capture whatever they need from
## around them, and a callback may schedule or cancel more timers, including
## itself. A timer added from inside a callback waits until the next update to
## run.
##
## This is an opt-in module, imported on its own with `import nim2d/schedule`.
## The core engine does not pull it in.

type
  TimerId* = int
    ## Identifies a scheduled timer, handed back by `after`, `every`
    ## and `during` and accepted by `cancel`.

  TimerKind = enum
    tkAfter
    tkEvery
    tkDuring

  Timer = object
    id: int
    kind: TimerKind
    interval: float # delay for after, interval for every, duration for during
    elapsed: float
    count: int # every only, remaining fires, -1 for forever
    dead: bool
    action: proc() # after and every
    tick: proc(dt: float) # during
    onDone: proc() # during

  Scheduler* = ref object
    ## Holds the live timers. Make one with `newScheduler`
    ## and advance it every frame with `update`.
    timers: seq[Timer]
    nextId: int

proc newScheduler*(): Scheduler =
  ## An empty scheduler. Advance it once per frame with `update`, and add timers
  ## with `after`, `every` and `during`.
  Scheduler(timers: @[], nextId: 1)

proc after*(s: Scheduler, delay: float, action: proc()): TimerId {.discardable.} =
  ## Run `action` once, `delay` seconds from now. Returns an id you can pass to
  ## `cancel` to call it off before it fires.
  result = s.nextId
  inc s.nextId
  s.timers.add Timer(id: result, kind: tkAfter, interval: delay, action: action)

proc every*(
    s: Scheduler, interval: float, action: proc(), count = -1
): TimerId {.discardable.} =
  ## Run `action` every `interval` seconds. It repeats forever by default, or
  ## pass `count` to stop after that many fires. Returns an id for `cancel`.
  result = s.nextId
  inc s.nextId
  s.timers.add Timer(
    id: result, kind: tkEvery, interval: interval, action: action, count: count
  )

proc during*(
    s: Scheduler, duration: float, action: proc(dt: float), onDone: proc() = nil
): TimerId {.discardable.} =
  ## Call `action` every frame for `duration` seconds, handing it the frame's
  ## `dt`, then call `onDone` once if it is set. Good for an effect that has to
  ## run continuously for a fixed time. Returns an id for `cancel`.
  result = s.nextId
  inc s.nextId
  s.timers.add Timer(
    id: result, kind: tkDuring, interval: duration, tick: action, onDone: onDone
  )

proc cancel*(s: Scheduler, id: TimerId) =
  ## Stop the timer with this id, whether or not it has fired. An id that is not
  ## there is ignored, so cancelling twice is safe.
  for i in 0 ..< s.timers.len:
    if s.timers[i].id == id:
      s.timers[i].dead = true
      break

proc clear*(s: Scheduler) =
  ## Drop every timer. Safe to call from inside a callback.
  for i in 0 ..< s.timers.len:
    s.timers[i].dead = true

proc update*(s: Scheduler, dt: float) =
  ## Advance every timer by `dt` seconds and fire the callbacks that come due.
  ## Call this once a frame from your own update with the same `dt`. A timer a
  ## callback adds during this call does not run until the next one.
  # Iterate by index over the timers that existed at the start of the frame, so
  # timers a callback schedules are left for the next update. Callbacks only ever
  # mark a timer dead, never remove it, which keeps these indices valid even when
  # the seq grows. The dead ones are dropped once the pass is done.
  let n = s.timers.len
  for i in 0 ..< n:
    if s.timers[i].dead:
      continue
    case s.timers[i].kind
    of tkAfter:
      s.timers[i].elapsed += dt
      if s.timers[i].elapsed >= s.timers[i].interval:
        s.timers[i].dead = true
        let act = s.timers[i].action
        if act != nil:
          act()
    of tkEvery:
      s.timers[i].elapsed += dt
      while not s.timers[i].dead and s.timers[i].interval > 0.0 and
          s.timers[i].elapsed >= s.timers[i].interval:
        s.timers[i].elapsed -= s.timers[i].interval
        let act = s.timers[i].action
        if act != nil:
          act()
        if s.timers[i].count > 0:
          dec s.timers[i].count
          if s.timers[i].count == 0:
            s.timers[i].dead = true
    of tkDuring:
      s.timers[i].elapsed += dt
      let tk = s.timers[i].tick
      if tk != nil:
        tk(dt)
      if s.timers[i].elapsed >= s.timers[i].interval:
        s.timers[i].dead = true
        let od = s.timers[i].onDone
        if od != nil:
          od()

  # compact, dropping finished and cancelled timers while keeping the order
  var w = 0
  for r in 0 ..< s.timers.len:
    if not s.timers[r].dead:
      if w != r:
        s.timers[w] = s.timers[r]
      inc w
  s.timers.setLen(w)
