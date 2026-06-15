import std/unittest
import nim2d
import nim2d/animation

# The sheet geometry and the animation timing are pure logic, so they test
# headlessly on a bare Image with no GPU texture behind it. Only `draw` would
# touch the device, and these tests never call it.

proc sheet96x144(): SpriteSheet =
  # 96 by 144 image cut into 32 by 36 cells: 3 columns, 4 rows.
  newSpriteSheet(Image(width: 96, height: 144), 32, 36)

const eps = 1e-5

suite "sprite sheet":
  test "columns and rows come from the image and frame size":
    let s = sheet96x144()
    check s.cols == 3
    check s.rows == 4
    check s.frameCount == 12

  test "a cell maps to the right texcoords and size":
    let s = sheet96x144()
    let q = s.quad(1, 0) # second column, first row
    check abs(q.u0.float - 32.0 / 96.0) < eps
    check abs(q.v0.float - 0.0) < eps
    check abs(q.u1.float - 64.0 / 96.0) < eps
    check abs(q.v1.float - 36.0 / 144.0) < eps
    check q.w == 32.0'f32
    check q.h == 36.0'f32
    let last = s.quad(2, 3) # bottom-right cell
    check abs(last.u1.float - 1.0) < eps
    check abs(last.v1.float - 1.0) < eps

suite "animation timing":
  test "frames advance as their time runs out":
    let s = sheet96x144()
    let a = newAnimation(s, @[(0, 0), (1, 0), (2, 0)], 0.1)
    check a.currentFrame == 0
    check a.frameCount == 3
    a.update(0.05)
    check a.currentFrame == 0 # 0.05 < 0.1, still the first frame
    a.update(0.06)
    check a.currentFrame == 1 # crossed 0.1
    a.update(0.1)
    check a.currentFrame == 2

  test "a looping animation wraps back to the start":
    let s = sheet96x144()
    let a = newAnimation(s, @[(0, 0), (1, 0)], 0.1, loop = true)
    a.update(0.1)
    check a.currentFrame == 1
    a.update(0.1)
    check a.currentFrame == 0 # wrapped
    check not a.done

  test "a non-looping animation stops and holds on the last frame":
    let s = sheet96x144()
    let a = newAnimation(s, @[(0, 0), (1, 0), (2, 0)], 0.1, loop = false)
    a.update(1.0) # well past the end
    check a.currentFrame == 2
    check a.done
    a.update(1.0) # no further movement
    check a.currentFrame == 2

  test "per-frame durations hold each frame for its own time":
    let s = sheet96x144()
    let a = newAnimation(s, @[(0, 0), (1, 0)], @[0.1, 0.5])
    a.update(0.1)
    check a.currentFrame == 1
    a.update(0.4)
    check a.currentFrame == 1 # 0.4 < 0.5, the long frame lingers
    a.update(0.15)
    check a.currentFrame == 0 # 0.55 crossed 0.5 and wrapped, 0.05 left on frame 0

  test "rowAnimation runs a whole row":
    let s = sheet96x144()
    let a = rowAnimation(s, 2, 0.1)
    check a.frameCount == 3
    check a.quad == s.quad(0, 2)

  test "reset, setFrame, pause and resume":
    let s = sheet96x144()
    let a = newAnimation(s, @[(0, 0), (1, 0), (2, 0)], 0.1)
    a.update(0.1)
    check a.currentFrame == 1
    a.reset()
    check a.currentFrame == 0
    a.setFrame(2)
    check a.currentFrame == 2
    a.setFrame(99) # clamped to the last frame
    check a.currentFrame == 2
    a.pause()
    a.update(1.0)
    check a.currentFrame == 2 # paused, no movement
    a.reset()
    a.resume()
    a.update(0.1)
    check a.currentFrame == 1

  test "a single-frame non-looping animation finishes after its frame's time":
    let s = sheet96x144()
    let a = newAnimation(s, @[(0, 0)], 0.2, loop = false)
    check not a.done
    a.update(0.1)
    check a.currentFrame == 0 and not a.done
    a.update(0.2) # past the frame's 0.2s
    check a.currentFrame == 0 # still the only frame
    check a.done
    let b = newAnimation(s, @[(0, 0)], 0.2, loop = true)
    b.update(5.0) # a looping single frame just holds, never hangs or finishes
    check b.currentFrame == 0 and not b.done

  test "an invalid animation is rejected":
    let s = sheet96x144()
    expect ValueError:
      discard newAnimation(s, newSeq[(int, int)](0), 0.1) # no frames
    expect ValueError:
      discard newAnimation(s, @[(0, 0), (1, 0)], @[0.1]) # lengths differ
    expect ValueError:
      discard newAnimation(s, @[(0, 0)], 0.0) # frame time not positive
    expect ValueError:
      discard newAnimation(s, @[(0, 0), (1, 0)], @[0.1, -0.2]) # negative duration
