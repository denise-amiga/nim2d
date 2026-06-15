import std/unittest
import nim2d
import nim2d/collide

# The collide module is pure geometry, so all of it tests headlessly with no GPU
# device. Where a resolve returns a push vector, the test applies it and checks
# the shapes end up exactly touching, not still overlapping.

suite "collide point tests":
  test "pointInRect inside, edge and outside":
    check pointInRect((5.0, 5.0), 0, 0, 10, 10)
    check pointInRect((0.0, 0.0), 0, 0, 10, 10) # corner counts as inside
    check pointInRect((10.0, 5.0), 0, 0, 10, 10) # edge counts as inside
    check not pointInRect((11.0, 5.0), 0, 0, 10, 10)
    check not pointInRect((5.0, -1.0), 0, 0, 10, 10)

  test "pointInCircle inside, on the rim and outside":
    check pointInCircle((0.0, 0.0), 0, 0, 5)
    check pointInCircle((5.0, 0.0), 0, 0, 5) # on the rim counts
    check not pointInCircle((5.1, 0.0), 0, 0, 5)
    check not pointInCircle((4.0, 4.0), 0, 0, 5) # sqrt(32) > 5

  test "pointInTriangle for both windings":
    let a = (0.0, 0.0)
    let b = (10.0, 0.0)
    let c = (0.0, 10.0)
    check pointInTriangle((2.0, 2.0), a, b, c)
    check not pointInTriangle((8.0, 8.0), a, b, c)
    check pointInTriangle((2.0, 2.0), a, c, b) # reversed winding, same result

  test "pointInPolygon for convex and concave outlines":
    let square: seq[Vec2] = @[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)]
    check pointInPolygon((5.0, 5.0), square)
    check not pointInPolygon((15.0, 5.0), square)
    # an L shape: the notch at (3, 3) is outside, the bars are inside
    let ell: seq[Vec2] =
      @[(0.0, 0.0), (4.0, 0.0), (4.0, 2.0), (2.0, 2.0), (2.0, 4.0), (0.0, 4.0)]
    check pointInPolygon((1.0, 1.0), ell)
    check pointInPolygon((3.0, 1.0), ell)
    check not pointInPolygon((3.0, 3.0), ell)
    check not pointInPolygon((1.0, 1.0), @[(0.0, 0.0), (1.0, 1.0)]) # too few points

suite "collide overlap tests":
  test "rectsOverlap separate, touching, overlapping, contained":
    check rectsOverlap(0, 0, 10, 10, 5, 5, 10, 10)
    check rectsOverlap(0, 0, 10, 10, 10, 0, 10, 10) # touching edge counts
    check not rectsOverlap(0, 0, 10, 10, 11, 0, 10, 10)
    check rectsOverlap(0, 0, 100, 100, 40, 40, 10, 10) # B inside A

  test "circlesOverlap":
    check circlesOverlap(0, 0, 5, 8, 0, 5) # gap 8 < 10
    check circlesOverlap(0, 0, 5, 10, 0, 5) # exactly touching
    check not circlesOverlap(0, 0, 5, 11, 0, 5)

  test "circleRectOverlap center, corner and miss":
    check circleRectOverlap(5, 5, 3, 0, 0, 20, 20) # center inside
    check circleRectOverlap(-2, -2, 3, 0, 0, 20, 20) # near corner, within radius
    check not circleRectOverlap(-4, -4, 3, 0, 0, 20, 20) # corner too far

  test "segmentsIntersect crossing, parallel, collinear, touching":
    check segmentsIntersect((0.0, 0.0), (10.0, 10.0), (0.0, 10.0), (10.0, 0.0))
    check not segmentsIntersect((0.0, 0.0), (10.0, 0.0), (0.0, 5.0), (10.0, 5.0))
    check segmentsIntersect((0.0, 0.0), (10.0, 0.0), (5.0, 0.0), (15.0, 0.0))
      # collinear overlap
    check segmentsIntersect((0.0, 0.0), (10.0, 0.0), (5.0, 0.0), (5.0, 10.0)) # T touch
    check not segmentsIntersect((0.0, 0.0), (1.0, 0.0), (5.0, 5.0), (6.0, 6.0))

suite "collide resolution":
  test "resolveRect pushes out along the shallow axis":
    let mtv = resolveRect(0, 0, 10, 10, 8, 0, 10, 10)
    check mtv == (-2.0, 0.0)
    # applying it leaves the rectangles exactly touching, no longer overlapping
    let overlapX = min(0.0 + mtv.x + 10, 8.0 + 10) - max(0.0 + mtv.x, 8.0)
    check abs(overlapX) < 1e-9
    check resolveRect(0, 0, 10, 10, 50, 50, 10, 10) == (0.0, 0.0)
    # one rectangle fully inside the other pushes out the nearest side, not just
    # as far as the overlap is deep
    let inside = resolveRect(40, 40, 10, 10, 0, 0, 100, 100)
    check inside == (-50.0, 0.0)
    # applying it leaves A's right edge exactly on B's left edge
    let edge = 40.0 + inside.x + 10.0
    check abs(edge - 0.0) < 1e-9

  test "resolveCircleRect pushes a circle clear of the rectangle":
    let mtv = resolveCircleRect(5, -3, 10, 0, 0, 20, 20)
    check abs(mtv.x - 0.0) < 1e-9
    check abs(mtv.y - (-7.0)) < 1e-9
    check resolveCircleRect(50, 50, 5, 0, 0, 20, 20) == (0.0, 0.0)

  test "resolveCircleRect with the center inside pushes fully out":
    let mtv = resolveCircleRect(5, 5, 4, 0, 0, 20, 20) # nearest edge is the left
    check mtv == (-9.0, 0.0) # 5 to the edge plus the radius
    # after the push the circle is clear of the rectangle interior
    check not circleRectOverlap(5 + mtv.x - 1e-6, 5 + mtv.y, 4, 0, 0, 20, 20)
