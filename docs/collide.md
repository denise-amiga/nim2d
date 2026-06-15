# Collide

.. contents::

Plenty of games need to know whether two things are touching without the weight of a full physics engine. The collide module is that lighter option, plain geometry on rectangles, circles, polygons and line segments, with no SDL or renderer behind it, so it costs nothing to call and tests headlessly. It is opt-in, imported on its own with `import nim2d/collide`, and the core engine does not pull it in.

Shapes are described the same way you draw them. A rectangle is a top-left corner with a width and height, the same arguments `rectangle` takes, and a circle is a center and a radius, the same as `circle`. So you hand collision the very numbers you hand drawing, with nothing to convert in between. When you do need real dynamics, stacking, joints and forces, the [physics module](physics.html) is there instead. This is for the common cases that just need a yes or no, or a small nudge.

## Is a point inside a shape

The `pointIn` family answers whether a point sits inside a shape, which is what a mouse hover or a hit check comes down to. The point comes first as a `Vec2`, so `mousePosition()` drops straight in.

```nim
if pointInRect(mousePosition(), button.x, button.y, button.w, button.h):
  highlight(button)

if pointInCircle((px, py), boss.x, boss.y, boss.r): ...
if pointInTriangle(p, a, b, c): ...
if pointInPolygon(p, @[(0.0, 0.0), (40.0, 0.0), (20.0, 30.0)]): ...
```

`pointInTriangle` does not care which way the triangle winds, and `pointInPolygon` works for concave outlines as well as convex ones, so a point in the notch of an L shape reads as outside the way you would expect.

## Do two shapes overlap

The `Overlap` family takes two shapes and returns a bool. Touching counts as overlapping, so a shape that has just reached the edge of another is already reported as a hit.

```nim
if rectsOverlap(a.x, a.y, a.w, a.h, b.x, b.y, b.w, b.h): ...
if circlesOverlap(a.x, a.y, a.r, b.x, b.y, b.r): ...
if circleRectOverlap(ball.x, ball.y, ball.r, wall.x, wall.y, wall.w, wall.h): ...
```

There is also `segmentsIntersect`, which tells you whether two line segments cross. It is the building block for a line-of-sight check or a laser, where you test the segment from one point to another against the edges of every wall in the way.

```nim
proc canSee(a, b: Vec2): bool =
  for w in walls:
    if segmentsIntersect(a, b, (w.x, w.y), (w.x + w.w, w.y)) or
       segmentsIntersect(a, b, (w.x + w.w, w.y), (w.x + w.w, w.y + w.h)) or
       segmentsIntersect(a, b, (w.x + w.w, w.y + w.h), (w.x, w.y + w.h)) or
       segmentsIntersect(a, b, (w.x, w.y + w.h), (w.x, w.y)):
      return false
  true
```

## Pushing shapes apart

A bool is enough to know a hit happened, but to stop a body passing through a wall you need to know how far to move it back. `resolveRect` and `resolveCircleRect` return that move, the smallest push that takes the first shape out of the second, along whichever axis it is least buried in. They return (0, 0) when the shapes are already clear, so you can add the result to a position every frame without checking first.

```nim
for wall in walls:
  let mtv = resolveCircleRect(player.x, player.y, player.r, wall.x, wall.y, wall.w, wall.h)
  player.x += mtv.x
  player.y += mtv.y
```

Because the push comes straight out of the nearest edge, a body that walks into a wall at an angle slides along it rather than sticking. To make that feel right, cancel the part of the velocity that points into the wall after the push, keeping only the part that runs along it.

```nim
if mtv.x != 0 or mtv.y != 0:
  let n = mtv.normalized
  let into = dot(vel, n)
  if into < 0: vel -= n * into     # drop the speed going into the wall, keep the slide
```

`resolveRect` does the same for two rectangles, and it stays correct even when one rectangle has slipped fully inside the other, pushing it out the nearest side rather than only as far as the overlap is deep.

The collide example is a live reference for all of this. It lays out a panel for each test and reacts to the mouse, so you can hover a panel, drag a probe shape against the fixed one, and watch the test light up green on a hit. The resolve panels draw the probe pushed back out of a solid box by the vector the resolve returns.
