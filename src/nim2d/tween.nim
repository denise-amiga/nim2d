## Easing curves and value tweens for animating over time.
##
## Motion that runs at a constant rate looks mechanical. Easing shapes that
## motion so it starts gently, ends gently, overshoots and springs back, or
## bounces to a stop, which is what makes a menu slide or a character hop feel
## alive. This module carries the easing curves a love2d game usually pulls from
## a separate library, and a small value tween that walks a number or a point
## from a start to a target over a set time.
##
## `ease` takes one of the `Easing` curves and a time from 0 to 1 and returns the
## eased position, also from 0 to 1, though the `back` and `elastic` curves go a
## little past the ends on purpose. Hand that to `lerp` and you can ease anything
## you can interpolate, a number, a `Vec2` or a `Color`.
##
## For the common case of moving one value to another over a few seconds, a
## `Tween` holds the start, the target, the duration and the curve. You advance
## it each frame with `update`, read where it is with `value`, and ask `done`
## when it has arrived. `newTween` also takes a `Vec2`, so a position tweens the
## same way a single number does.
##
## This is an opt-in module, imported on its own with `import nim2d/tween`. The
## core engine does not pull it in.

import std/math
import types
import nim2d/math as m

type Easing* {.pure.} = enum
  ## A choice of easing curve. The names follow the usual convention, an `In`
  ## curve starts slow and speeds up, an `Out` curve starts fast and eases into
  ## the target, and an `InOut` curve does both, slow at each end and quick
  ## through the middle. `linear` has no easing at all and moves at a constant
  ## rate. `back` overshoots a little before settling, `elastic` springs past
  ## and wobbles in, and `bounce` lands like a dropped ball.
  linear
  quadIn
  quadOut
  quadInOut
  cubicIn
  cubicOut
  cubicInOut
  quartIn
  quartOut
  quartInOut
  quintIn
  quintOut
  quintInOut
  sineIn
  sineOut
  sineInOut
  expoIn
  expoOut
  expoInOut
  circIn
  circOut
  circInOut
  backIn
  backOut
  backInOut
  elasticIn
  elasticOut
  elasticInOut
  bounceIn
  bounceOut
  bounceInOut

const
  backC1 = 1.70158
  backC2 = backC1 * 1.525
  backC3 = backC1 + 1.0
  elasticC4 = (2.0 * PI) / 3.0
  elasticC5 = (2.0 * PI) / 4.5

func bounceCurve(t: float): float =
  ## The `bounceOut` shape on its own, since the in and in-out bounces are built
  ## from it.
  const
    n1 = 7.5625
    d1 = 2.75
  if t < 1.0 / d1:
    n1 * t * t
  elif t < 2.0 / d1:
    let u = t - 1.5 / d1
    n1 * u * u + 0.75
  elif t < 2.5 / d1:
    let u = t - 2.25 / d1
    n1 * u * u + 0.9375
  else:
    let u = t - 2.625 / d1
    n1 * u * u + 0.984375

func ease*(easing: Easing, t: float): float =
  ## Map a time `t`, from 0 at the start to 1 at the end, through the curve
  ## `easing` and return the eased position. Times outside 0 to 1 are clamped
  ## first. The result mostly stays within 0 to 1, but `back` and `elastic`
  ## reach past the ends, which is where their snap comes from.
  let t = clamp(t, 0.0, 1.0)
  case easing
  of linear:
    t
  of quadIn:
    t * t
  of quadOut:
    1.0 - (1.0 - t) * (1.0 - t)
  of quadInOut:
    if t < 0.5:
      2.0 * t * t
    else:
      1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
  of cubicIn:
    t * t * t
  of cubicOut:
    1.0 - pow(1.0 - t, 3.0)
  of cubicInOut:
    if t < 0.5:
      4.0 * t * t * t
    else:
      1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
  of quartIn:
    t * t * t * t
  of quartOut:
    1.0 - pow(1.0 - t, 4.0)
  of quartInOut:
    if t < 0.5:
      8.0 * t * t * t * t
    else:
      1.0 - pow(-2.0 * t + 2.0, 4.0) / 2.0
  of quintIn:
    t * t * t * t * t
  of quintOut:
    1.0 - pow(1.0 - t, 5.0)
  of quintInOut:
    if t < 0.5:
      16.0 * t * t * t * t * t
    else:
      1.0 - pow(-2.0 * t + 2.0, 5.0) / 2.0
  of sineIn:
    1.0 - cos(t * PI / 2.0)
  of sineOut:
    sin(t * PI / 2.0)
  of sineInOut:
    -(cos(PI * t) - 1.0) / 2.0
  of expoIn:
    if t == 0.0:
      0.0
    else:
      pow(2.0, 10.0 * t - 10.0)
  of expoOut:
    if t == 1.0:
      1.0
    else:
      1.0 - pow(2.0, -10.0 * t)
  of expoInOut:
    if t == 0.0:
      0.0
    elif t == 1.0:
      1.0
    elif t < 0.5:
      pow(2.0, 20.0 * t - 10.0) / 2.0
    else:
      (2.0 - pow(2.0, -20.0 * t + 10.0)) / 2.0
  of circIn:
    1.0 - sqrt(1.0 - t * t)
  of circOut:
    sqrt(1.0 - (t - 1.0) * (t - 1.0))
  of circInOut:
    if t < 0.5:
      (1.0 - sqrt(1.0 - pow(2.0 * t, 2.0))) / 2.0
    else:
      (sqrt(1.0 - pow(-2.0 * t + 2.0, 2.0)) + 1.0) / 2.0
  of backIn:
    backC3 * t * t * t - backC1 * t * t
  of backOut:
    1.0 + backC3 * pow(t - 1.0, 3.0) + backC1 * pow(t - 1.0, 2.0)
  of backInOut:
    if t < 0.5:
      (pow(2.0 * t, 2.0) * ((backC2 + 1.0) * 2.0 * t - backC2)) / 2.0
    else:
      (pow(2.0 * t - 2.0, 2.0) * ((backC2 + 1.0) * (t * 2.0 - 2.0) + backC2) + 2.0) / 2.0
  of elasticIn:
    if t == 0.0:
      0.0
    elif t == 1.0:
      1.0
    else:
      -pow(2.0, 10.0 * t - 10.0) * sin((t * 10.0 - 10.75) * elasticC4)
  of elasticOut:
    if t == 0.0:
      0.0
    elif t == 1.0:
      1.0
    else:
      pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * elasticC4) + 1.0
  of elasticInOut:
    if t == 0.0:
      0.0
    elif t == 1.0:
      1.0
    elif t < 0.5:
      -(pow(2.0, 20.0 * t - 10.0) * sin((20.0 * t - 11.125) * elasticC5)) / 2.0
    else:
      pow(2.0, -20.0 * t + 10.0) * sin((20.0 * t - 11.125) * elasticC5) / 2.0 + 1.0
  of bounceIn:
    1.0 - bounceCurve(1.0 - t)
  of bounceOut:
    bounceCurve(t)
  of bounceInOut:
    if t < 0.5:
      (1.0 - bounceCurve(1.0 - 2.0 * t)) / 2.0
    else:
      (1.0 + bounceCurve(2.0 * t - 1.0)) / 2.0

type
  Tween* = object
    ## A single number easing from a start value to a target over a fixed time.
    ## Advance it each frame with `update`, read where it is now with `value`,
    ## and check `done` to know when it has arrived. Build one with `newTween`.
    startValue, target: float
    duration, elapsed: float
    easing: Easing

  VecTween* = object
    ## A point easing from a start position to a target over a fixed time, the
    ## `Vec2` counterpart of `Tween`. Both coordinates run on the one curve, so it
    ## is what you reach for to slide something from one place to another.
    startValue, target: Vec2
    duration, elapsed: float
    easing: Easing

func newTween*(start, target, duration: float, easing = Easing.linear): Tween =
  ## A tween of a single number from `start` to `target` over `duration` seconds
  ## following `easing`. A duration of zero or less finishes at once.
  Tween(
    startValue: start,
    target: target,
    duration: max(duration, 0.0),
    elapsed: 0.0,
    easing: easing,
  )

func newTween*(start, target: Vec2, duration: float, easing = Easing.linear): VecTween =
  ## A tween of a point from `start` to `target` over `duration` seconds
  ## following `easing`.
  VecTween(
    startValue: start,
    target: target,
    duration: max(duration, 0.0),
    elapsed: 0.0,
    easing: easing,
  )

proc update*(tw: var Tween, dt: float) =
  ## Advance the tween by `dt` seconds. It holds at the target once the duration
  ## is up, so calling it past the end is harmless.
  tw.elapsed = clamp(tw.elapsed + dt, 0.0, tw.duration)

proc update*(tw: var VecTween, dt: float) =
  ## Advance the tween by `dt` seconds, holding at the target once it is done.
  tw.elapsed = clamp(tw.elapsed + dt, 0.0, tw.duration)

func progress*(tw: Tween): float =
  ## How far along the tween is before easing, from 0 at the start to 1 at the
  ## end. This is the raw time fraction, not the eased value.
  if tw.duration <= 0.0:
    1.0
  else:
    tw.elapsed / tw.duration

func progress*(tw: VecTween): float =
  ## How far along the tween is before easing, from 0 to 1.
  if tw.duration <= 0.0:
    1.0
  else:
    tw.elapsed / tw.duration

func value*(tw: Tween): float =
  ## The current number, the start and target blended by the eased progress.
  ## Read this each frame and assign it to whatever you are animating.
  m.lerp(tw.startValue, tw.target, ease(tw.easing, tw.progress))

func value*(tw: VecTween): Vec2 =
  ## The current point, the start and target blended by the eased progress.
  m.lerp(tw.startValue, tw.target, ease(tw.easing, tw.progress))

func done*(tw: Tween): bool =
  ## True once the tween has reached its target.
  tw.elapsed >= tw.duration

func done*(tw: VecTween): bool =
  ## True once the tween has reached its target.
  tw.elapsed >= tw.duration

proc reset*(tw: var Tween) =
  ## Send the tween back to its start so it runs again from the beginning.
  tw.elapsed = 0.0

proc reset*(tw: var VecTween) =
  ## Send the tween back to its start so it runs again from the beginning.
  tw.elapsed = 0.0
