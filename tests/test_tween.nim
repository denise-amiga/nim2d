import std/unittest
import nim2d/tween

# The tween module is pure math with no GPU device, so all of it tests
# headlessly. The easing curves are checked at their ends and a few known
# midpoints, and the tweens are stepped by hand and read back.

const eps = 1e-9

suite "easing curves":
  test "every curve starts at 0 and ends at 1":
    for e in Easing:
      check abs(ease(e, 0.0)) < eps
      check abs(ease(e, 1.0) - 1.0) < eps

  test "times outside 0 to 1 are clamped":
    check ease(Easing.linear, -2.0) == 0.0
    check ease(Easing.linear, 5.0) == 1.0
    check ease(Easing.quadIn, -1.0) == 0.0
    check ease(Easing.cubicOut, 9.0) == 1.0

  test "known midpoints":
    check abs(ease(Easing.linear, 0.5) - 0.5) < eps
    check abs(ease(Easing.quadIn, 0.5) - 0.25) < eps
    check abs(ease(Easing.quadOut, 0.5) - 0.75) < eps
    check abs(ease(Easing.cubicIn, 0.5) - 0.125) < eps
    check abs(ease(Easing.quadInOut, 0.5) - 0.5) < eps
    check abs(ease(Easing.sineInOut, 0.5) - 0.5) < eps

  test "back and elastic reach past the ends":
    check ease(Easing.backOut, 0.5) > 1.0 # overshoots the target
    check ease(Easing.backIn, 0.3) < 0.0 # dips below the start
    check ease(Easing.elasticOut, 0.5) > 1.0

  test "bounce stays within 0 to 1":
    for i in 0 .. 20:
      let v = ease(Easing.bounceOut, i.float / 20.0)
      check v >= -eps and v <= 1.0 + eps

suite "value tween":
  test "a linear tween walks from start to target":
    var tw = newTween(0.0, 100.0, 2.0, Easing.linear)
    check tw.value == 0.0
    check not tw.done
    tw.update(1.0)
    check abs(tw.progress - 0.5) < eps
    check abs(tw.value - 50.0) < eps
    tw.update(1.0)
    check tw.done
    check abs(tw.value - 100.0) < eps

  test "stepping past the end holds at the target":
    var tw = newTween(0.0, 100.0, 2.0)
    tw.update(10.0)
    check tw.done
    check abs(tw.progress - 1.0) < eps
    check abs(tw.value - 100.0) < eps

  test "reset runs it again from the start":
    var tw = newTween(0.0, 100.0, 2.0)
    tw.update(2.0)
    check tw.done
    tw.reset()
    check tw.progress == 0.0
    check tw.value == 0.0
    check not tw.done

  test "the easing shapes the value, not just the ends":
    var tw = newTween(0.0, 100.0, 2.0, Easing.quadIn)
    tw.update(1.0) # halfway in time
    check abs(tw.value - 25.0) < eps # quadIn(0.5) = 0.25

  test "a zero or negative duration finishes at once":
    var z = newTween(5.0, 9.0, 0.0)
    check z.done
    check z.progress == 1.0
    check abs(z.value - 9.0) < eps
    var neg = newTween(0.0, 1.0, -3.0)
    check neg.done
    check abs(neg.value - 1.0) < eps

suite "vec tween":
  test "a point tweens both coordinates on one curve":
    var tw = newTween((0.0, 0.0), (10.0, 20.0), 1.0, Easing.linear)
    let mid = tw.value
    check mid.x == 0.0 and mid.y == 0.0
    tw.update(0.5)
    let half = tw.value
    check abs(half.x - 5.0) < eps
    check abs(half.y - 10.0) < eps
    tw.update(0.5)
    check tw.done
    let endp = tw.value
    check abs(endp.x - 10.0) < eps
    check abs(endp.y - 20.0) < eps
