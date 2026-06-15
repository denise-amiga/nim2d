## A 2D camera: a movable, zoomable and rotatable view onto your world.
##
## A game world is usually bigger than the window, so you keep object positions
## in world coordinates and let a camera decide what part of that world the
## window shows. You make a camera with `newCamera`, point it at a world spot
## with `lookAt` or let it trail a target with `follow`, then wrap your world
## drawing in `attach` and `detach` (or the `withCamera` block). Everything drawn
## in between is placed through the camera, so the point it looks at sits in the
## middle of the window, scaled by the zoom and turned by the rotation.
##
## `toScreen` and `toWorld` convert a point between the two coordinate spaces,
## which is what you need to pin a label above a world object or to find the
## world spot under the mouse. `lerp` blends two cameras, so easing from one view
## to another is a single call.
##
## This is an opt-in module, imported on its own with `import nim2d/camera`. The
## core engine does not pull it in.

import std/math
import types
import graphics
import nim2d/math as m

type Camera* = ref object
  ## A view onto the world. `x` and `y` are the world point the camera looks
  ## at, which lands in the center of the window. `scale` is the zoom, where
  ## values above one zoom in and below one zoom out, and `rotation` turns the
  ## view by that many radians. The fields are public, so reading and setting
  ## them directly is fine alongside the helpers below.
  x*, y*: float
  scale*: float
  rotation*: float

proc newCamera*(x = 0.0, y = 0.0, scale = 1.0, rotation = 0.0): Camera =
  ## A camera looking at world point (x, y) with the given zoom and rotation.
  ## With the defaults it sits at the origin, unzoomed and unrotated.
  Camera(x: x, y: y, scale: scale, rotation: rotation)

proc lookAt*(cam: Camera, x, y: float) =
  ## Point the camera at world coordinate (x, y), so that spot moves to the
  ## center of the window.
  cam.x = x
  cam.y = y

proc lookAt*(cam: Camera, p: Vec2) =
  ## Point the camera at a world position.
  cam.x = p.x
  cam.y = p.y

proc move*(cam: Camera, dx, dy: float) =
  ## Shift the camera by (dx, dy) in world units.
  cam.x += dx
  cam.y += dy

proc zoom*(cam: Camera, factor: float) =
  ## Multiply the current zoom by `factor`. A factor of 1.1 zooms in a little,
  ## 0.9 zooms out. To set the zoom outright, assign `cam.scale` instead.
  cam.scale *= factor

proc rotate*(cam: Camera, by: float) =
  ## Turn the view by `by` radians, added to the current rotation.
  cam.rotation += by

proc follow*(cam: Camera, target: Vec2, dt: float, speed = 8.0) =
  ## Ease the camera toward `target` over this frame instead of snapping to it,
  ## which gives a smooth trailing follow. `speed` sets how quickly it catches
  ## up, with higher being snappier. The step is scaled by `dt`, so the motion
  ## looks the same whatever the frame rate.
  let t = 1.0 - exp(-speed * dt)
  cam.x = m.lerp(cam.x, target.x, t)
  cam.y = m.lerp(cam.y, target.y, t)

proc lerp*(a, b: Camera, t: float): Camera =
  ## A new camera blended between `a` and `b` by `t`, where 0 gives `a` and 1
  ## gives `b`. Position, zoom and rotation are each interpolated linearly, so
  ## animating `t` from 0 to 1 eases the whole view from one camera to the other.
  ## That is how you make a smooth cut when switching between two cameras.
  Camera(
    x: m.lerp(a.x, b.x, t),
    y: m.lerp(a.y, b.y, t),
    scale: m.lerp(a.scale, b.scale, t),
    rotation: m.lerp(a.rotation, b.rotation, t),
  )

proc attach*(nim2d: Nim2d, cam: Camera) =
  ## Start drawing through `cam`. It pushes a transform so the world point the
  ## camera looks at lands in the center of the window, scaled by the zoom and
  ## turned by the rotation. Draw your world in world coordinates after this,
  ## then call `detach` to go back to plain screen coordinates. Pairs of attach
  ## and detach must match, the same way `push` and `pop` do.
  nim2d.push()
  nim2d.translate(nim2d.width.float / 2, nim2d.height.float / 2)
  nim2d.scale(cam.scale, cam.scale)
  nim2d.rotate(cam.rotation)
  nim2d.translate(-cam.x, -cam.y)

proc detach*(nim2d: Nim2d) =
  ## Undo the transform that `attach` pushed, returning to screen coordinates so
  ## you can draw a HUD on top.
  nim2d.pop()

template withCamera*(nim2d: Nim2d, cam: Camera, body: untyped) =
  ## Run `body` drawing through `cam`, then detach afterwards. Everything inside
  ## the block is in world coordinates. This is the scoped form of `attach` and
  ## `detach`, so the detach is never forgotten.
  nim2d.attach(cam)
  body
  nim2d.detach()

proc toScreen*(nim2d: Nim2d, cam: Camera, world: Vec2): Vec2 =
  ## Where the world point `world` lands on the screen, in pixels, given the
  ## camera. Use it to draw screen-space things, like a label or a health bar,
  ## that should stay glued to something in the world as the camera moves.
  let r = m.rotated((world.x - cam.x, world.y - cam.y), cam.rotation)
  (nim2d.width.float / 2 + r.x * cam.scale, nim2d.height.float / 2 + r.y * cam.scale)

proc toWorld*(nim2d: Nim2d, cam: Camera, screen: Vec2): Vec2 =
  ## The world point under a screen pixel, the inverse of `toScreen`. The common
  ## use is turning the mouse position into a world position, so a click lands on
  ## the right spot whatever the camera is doing.
  let sx = (screen.x - nim2d.width.float / 2) / cam.scale
  let sy = (screen.y - nim2d.height.float / 2) / cam.scale
  let r = m.rotated((sx, sy), -cam.rotation)
  (cam.x + r.x, cam.y + r.y)
