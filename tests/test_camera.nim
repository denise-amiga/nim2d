import std/unittest
import std/math
import nim2d
import nim2d/camera

# The camera math needs only the window size and the camera fields, so it tests
# headlessly on a bare Nim2d with no GPU device. attach/detach use the transform
# stack on the GPU context and are left to the running example.

proc bare(w, h: int32): Nim2d =
  Nim2d(width: w, height: h)

const eps = 1e-7

suite "camera":
  test "newCamera defaults and setters":
    let cam = newCamera()
    check cam.x == 0.0 and cam.y == 0.0
    check cam.scale == 1.0 and cam.rotation == 0.0
    cam.lookAt(30, -10)
    check cam.x == 30.0 and cam.y == -10.0
    cam.move(5, 5)
    check cam.x == 35.0 and cam.y == -5.0
    cam.zoom(2.0)
    check cam.scale == 2.0
    cam.rotate(0.5)
    check abs(cam.rotation - 0.5) < eps
    cam.lookAt((1.0, 2.0))
    check cam.x == 1.0 and cam.y == 2.0

  test "the looked-at point lands at the window center":
    let n = bare(800, 600)
    let cam = newCamera(120, -40, 2.0, 0.7)
    let s = n.toScreen(cam, (cam.x, cam.y))
    check abs(s.x - 400.0) < eps
    check abs(s.y - 300.0) < eps

  test "zoom and offset map to the right pixel":
    let n = bare(800, 600)
    let cam = newCamera(0, 0, 2.0) # no rotation
    let s = n.toScreen(cam, (10.0, 0.0))
    check abs(s.x - 420.0) < eps # 400 + 10*2
    check abs(s.y - 300.0) < eps

  test "rotation turns the view":
    let n = bare(800, 600)
    let cam = newCamera(0, 0, 1.0, PI / 2) # quarter turn
    let s = n.toScreen(cam, (10.0, 0.0)) # +x world becomes +y screen
    check abs(s.x - 400.0) < 1e-6
    check abs(s.y - 310.0) < 1e-6

  test "toWorld is the inverse of toScreen":
    let n = bare(1024, 768)
    let cams = [
      newCamera(0, 0, 1.0, 0.0),
      newCamera(250, -130, 1.8, 0.0),
      newCamera(-60, 90, 0.5, 1.2),
      newCamera(33, 33, 3.3, -2.4),
    ]
    let pts: array[4, Vec2] =
      [(0.0, 0.0), (123.0, -45.0), (-900.0, 510.0), (12.5, 7.25)]
    for cam in cams:
      for p in pts:
        let back = n.toWorld(cam, n.toScreen(cam, p))
        check abs(back.x - p.x) < 1e-6
        check abs(back.y - p.y) < 1e-6

  test "follow eases toward the target without overshooting":
    let cam = newCamera(0, 0)
    cam.follow((100.0, 0.0), 1.0 / 60.0, 8.0)
    check cam.x > 0.0 and cam.x < 100.0 # moved part way, did not jump past
    let before = cam.x
    cam.follow((100.0, 0.0), 1.0 / 60.0, 8.0)
    check cam.x > before # keeps closing in

  test "lerp blends two cameras":
    let a = newCamera(0, 0, 1.0, 0.0)
    let b = newCamera(100, 200, 3.0, 1.0)
    let mid = lerp(a, b, 0.5)
    check abs(mid.x - 50.0) < eps
    check abs(mid.y - 100.0) < eps
    check abs(mid.scale - 2.0) < eps
    check abs(mid.rotation - 0.5) < eps
    let at0 = lerp(a, b, 0.0)
    check at0.x == a.x and at0.scale == a.scale
    let at1 = lerp(a, b, 1.0)
    check at1.x == b.x and at1.rotation == b.rotation
