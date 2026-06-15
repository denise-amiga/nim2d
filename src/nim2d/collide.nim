## Lightweight collision tests for games that do not want full Box2D.
##
## This is plain geometry on rectangles, circles, polygons and line segments,
## with no SDL or renderer dependency, so it tests headlessly and costs nothing
## to call. Rectangles are given the same way `rectangle` draws them, as a
## top-left corner (x, y) with a width and height, and circles as a center and a
## radius, so you pass collision the same numbers you pass drawing.
##
## There are three kinds of test here. The `pointIn*` family asks whether a point
## sits inside a shape, which is what you use for a mouse hover or a hit check.
## The `*Overlap` family asks whether two shapes touch, returning a bool. The
## `resolve*` pair goes one step further and returns the smallest move that
## pushes one shape out of another, so a body can slide along a wall instead of
## stopping dead or passing through.
##
## When you need real dynamics, stacking, joints and forces, reach for the
## physics module instead. This is the cheap option for the common cases.
##
## It is an opt-in module, imported on its own with `import nim2d/collide`. The
## core engine does not pull it in.

import std/math
import types

# --- internal helpers -------------------------------------------------------

func orient(a, b, c: Vec2): float =
  ## Twice the signed area of triangle a, b, c. Positive, negative or zero tells
  ## you which side of the line a->b the point c is on.
  (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

func onSegment(a, b, p: Vec2): bool =
  ## True when p, already known to be collinear with a and b, lies between them.
  p.x >= min(a.x, b.x) and p.x <= max(a.x, b.x) and p.y >= min(a.y, b.y) and
    p.y <= max(a.y, b.y)

# --- point in shape ---------------------------------------------------------

func pointInRect*(p: Vec2, x, y, w, h: float): bool =
  ## Whether point `p` is inside the rectangle with top-left (x, y) and the given
  ## width and height. The edges count as inside.
  p.x >= x and p.x <= x + w and p.y >= y and p.y <= y + h

func pointInCircle*(p: Vec2, cx, cy, r: float): bool =
  ## Whether point `p` is inside the circle centered at (cx, cy) with radius r.
  let dx = p.x - cx
  let dy = p.y - cy
  dx * dx + dy * dy <= r * r

func pointInTriangle*(p, a, b, c: Vec2): bool =
  ## Whether point `p` is inside the triangle a, b, c. The winding does not
  ## matter, and points on an edge count as inside.
  let d1 = orient(p, a, b)
  let d2 = orient(p, b, c)
  let d3 = orient(p, c, a)
  let hasNeg = d1 < 0 or d2 < 0 or d3 < 0
  let hasPos = d1 > 0 or d2 > 0 or d3 > 0
  not (hasNeg and hasPos)

func pointInPolygon*(p: Vec2, poly: openArray[Vec2]): bool =
  ## Whether point `p` is inside the polygon outlined by `poly`, by counting how
  ## many times a ray crosses the edges. Works for convex and concave outlines
  ## without holes. Fewer than three points is never inside.
  if poly.len < 3:
    return false
  var inside = false
  var j = poly.len - 1
  for i in 0 ..< poly.len:
    let pi = poly[i]
    let pj = poly[j]
    if (pi.y > p.y) != (pj.y > p.y) and
        p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x:
      inside = not inside
    j = i
  inside

# --- overlap tests ----------------------------------------------------------

func rectsOverlap*(ax, ay, aw, ah, bx, by, bw, bh: float): bool =
  ## Whether two rectangles overlap. Each is a top-left corner with a width and
  ## height, the same as `rectangle` takes. Touching edges count as overlapping.
  ax <= bx + bw and ax + aw >= bx and ay <= by + bh and ay + ah >= by

func circlesOverlap*(ax, ay, ar, bx, by, br: float): bool =
  ## Whether two circles overlap, each a center and a radius.
  let dx = ax - bx
  let dy = ay - by
  let rr = ar + br
  dx * dx + dy * dy <= rr * rr

func circleRectOverlap*(cx, cy, r, rx, ry, rw, rh: float): bool =
  ## Whether a circle (center, radius) overlaps a rectangle (top-left, size).
  ## The test finds the rectangle point nearest the circle center and checks
  ## whether it falls within the radius.
  let nx = clamp(cx, rx, rx + rw)
  let ny = clamp(cy, ry, ry + rh)
  let dx = cx - nx
  let dy = cy - ny
  dx * dx + dy * dy <= r * r

func segmentsIntersect*(a1, a2, b1, b2: Vec2): bool =
  ## Whether the line segment a1->a2 crosses the segment b1->b2, touching ends
  ## included. Useful for a line-of-sight check or a laser against walls.
  let d1 = orient(b1, b2, a1)
  let d2 = orient(b1, b2, a2)
  let d3 = orient(a1, a2, b1)
  let d4 = orient(a1, a2, b2)
  if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and
      ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
    return true
  # collinear or touching, where an endpoint sits on the other segment
  if d1 == 0 and onSegment(b1, b2, a1):
    return true
  if d2 == 0 and onSegment(b1, b2, a2):
    return true
  if d3 == 0 and onSegment(a1, a2, b1):
    return true
  if d4 == 0 and onSegment(a1, a2, b2):
    return true
  false

# --- resolution -------------------------------------------------------------

func resolveRect*(ax, ay, aw, ah, bx, by, bw, bh: float): Vec2 =
  ## The smallest move to apply to rectangle A so it no longer overlaps
  ## rectangle B, pushing along whichever axis it is least buried in. Returns
  ## (0, 0) when they are already clear, so you can add it to A's position
  ## unconditionally.
  let overlapX = min(ax + aw, bx + bw) - max(ax, bx)
  let overlapY = min(ay + ah, by + bh) - max(ay, by)
  if overlapX <= 0 or overlapY <= 0:
    return (0.0, 0.0)
  # the least move on each axis that separates them, taking the smaller of the
  # push to either side. Working from the two side distances rather than the
  # overlap depth keeps it right when one rectangle sits fully inside the other.
  let left = ax + aw - bx
  let right = bx + bw - ax
  let moveX =
    if left < right:
      -left
    else:
      right
  let up = ay + ah - by
  let down = by + bh - ay
  let moveY =
    if up < down:
      -up
    else:
      down
  if abs(moveX) <= abs(moveY):
    (moveX, 0.0)
  else:
    (0.0, moveY)

func resolveCircleRect*(cx, cy, r, rx, ry, rw, rh: float): Vec2 =
  ## The smallest move to apply to the circle so it no longer overlaps the
  ## rectangle. It pushes straight away from the nearest edge, which is what lets
  ## a round body slide along a wall. Returns (0, 0) when they are clear.
  let nx = clamp(cx, rx, rx + rw)
  let ny = clamp(cy, ry, ry + rh)
  let dx = cx - nx
  let dy = cy - ny
  let d2 = dx * dx + dy * dy
  if d2 > r * r:
    return (0.0, 0.0)
  if d2 > 1e-12:
    let d = sqrt(d2)
    let push = r - d
    return (dx / d * push, dy / d * push)
  # the center is inside the rectangle, so push out along the nearest edge
  let left = cx - rx
  let right = rx + rw - cx
  let top = cy - ry
  let bottom = ry + rh - cy
  let m = min(min(left, right), min(top, bottom))
  if m == left:
    (-(left + r), 0.0)
  elif m == right:
    (right + r, 0.0)
  elif m == top:
    (0.0, -(top + r))
  else:
    (0.0, bottom + r)
