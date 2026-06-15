import std/unittest
import nim2d/schedule

# The scheduler is pure logic with no GPU device, so it tests headlessly. The
# callbacks bump local counters, which is enough to see when each fires, how
# often, and in what order.

suite "after":
  test "fires once after the delay, then is gone":
    let s = newScheduler()
    var fired = 0
    let bump = proc() =
      inc fired
    s.after(1.0, bump)
    s.update(0.5)
    check fired == 0
    s.update(0.6) # crosses 1.0
    check fired == 1
    s.update(5.0) # already removed, no second fire
    check fired == 1

  test "a single large step still fires":
    let s = newScheduler()
    var fired = 0
    let bump = proc() =
      inc fired
    s.after(0.2, bump)
    s.update(10.0)
    check fired == 1

  test "cancel before it fires keeps it from firing":
    let s = newScheduler()
    var fired = 0
    let bump = proc() =
      inc fired
    let id = s.after(1.0, bump)
    s.cancel(id)
    s.update(5.0)
    check fired == 0

suite "every":
  test "fires on each interval and catches up a big step":
    let s = newScheduler()
    var ticks = 0
    let bump = proc() =
      inc ticks
    s.every(1.0, bump)
    s.update(1.0)
    check ticks == 1
    s.update(2.5) # crosses two more interval marks
    check ticks == 3

  test "count limits the number of fires":
    let s = newScheduler()
    var ticks = 0
    let bump = proc() =
      inc ticks
    s.every(0.5, bump, count = 3)
    s.update(10.0)
    check ticks == 3
    s.update(10.0)
    check ticks == 3

  test "cancel stops a repeating timer":
    let s = newScheduler()
    var ticks = 0
    let bump = proc() =
      inc ticks
    let id = s.every(1.0, bump)
    s.update(1.0)
    check ticks == 1
    s.cancel(id)
    s.update(5.0)
    check ticks == 1

suite "during":
  test "ticks every frame and finishes with onDone":
    let s = newScheduler()
    var total = 0.0
    var ticks = 0
    var done = 0
    let tick = proc(dt: float) =
      total += dt
      inc ticks
    let finish = proc() =
      inc done
    s.during(1.0, tick, finish)
    s.update(0.4)
    check ticks == 1 and done == 0
    s.update(0.4)
    check ticks == 2 and done == 0
    s.update(0.4) # crosses 1.0
    check ticks == 3 and done == 1
    check abs(total - 1.2) < 1e-9
    s.update(1.0) # gone, no more ticks
    check ticks == 3 and done == 1

suite "chaining and clear":
  test "a callback can schedule another timer for next frame":
    let s = newScheduler()
    var a = 0
    var b = 0
    let inner = proc() =
      inc b
    let first = proc() =
      inc a
      s.after(1.0, inner)
    s.after(1.0, first)
    s.update(1.0) # fires a and schedules b
    check a == 1 and b == 0 # b waits for the next update
    s.update(1.0) # now b fires
    check b == 1

  test "clear drops everything":
    let s = newScheduler()
    var n = 0
    let bump = proc() =
      inc n
    s.every(0.5, bump)
    s.after(0.3, bump)
    s.clear()
    s.update(10.0)
    check n == 0
