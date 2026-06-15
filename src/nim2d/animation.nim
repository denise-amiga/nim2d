## Sprite-sheet animation, cutting frames from a grid and playing them over time.
##
## A sprite sheet packs an animation's frames into one image, laid out in a grid.
## A `SpriteSheet` wraps that image and the frame size and hands you any cell as a
## `Quad`. An `Animation` is a list of those cells played in order, each held for a
## while, which you advance from your update and draw each frame. One sheet can
## feed several animations, which is how a character keeps a separate walk cycle
## for each way it faces.
##
## You build a sheet with `newSpriteSheet`, then an animation with `newAnimation`
## (frames given as (column, row) cells) or `rowAnimation` (a whole row, left to
## right). `update` moves it along by the current frame's time, `draw` paints the
## frame where you ask, and `quad` hands you that frame if you would rather draw
## it yourself. Frames can share one duration or each carry their own.
##
## This is an opt-in module, imported on its own with `import nim2d/animation`.
## The core engine does not pull it in.

import types
import image

type
  SpriteSheet* = ref object
    ## An image cut into a grid of equal cells. `cols` and
    ## `rows` are worked out from the image and the frame
    ## size.
    image*: Image
    frameWidth*, frameHeight*: int
    cols*, rows*: int

  Animation* = ref object
    ## A run of frames from a sheet, each shown for its duration. Advance it with
    ## `update` and show it with `draw`. Build one with `newAnimation` or
    ## `rowAnimation`.
    sheet: SpriteSheet
    frames: seq[Quad]
    durations: seq[float]
    loop: bool
    time: float
    index: int
    playing: bool
    finished: bool

proc newSpriteSheet*(image: Image, frameWidth, frameHeight: int): SpriteSheet =
  ## Wrap `image` as a grid of `frameWidth` by `frameHeight` cells. The number of
  ## columns and rows comes from the image size, so a 96 by 144 image cut into 32
  ## by 36 cells is 3 columns and 4 rows.
  SpriteSheet(
    image: image,
    frameWidth: frameWidth,
    frameHeight: frameHeight,
    cols: image.width.int div frameWidth,
    rows: image.height.int div frameHeight,
  )

proc frameCount*(sheet: SpriteSheet): int =
  ## How many cells the sheet holds, columns times rows.
  sheet.cols * sheet.rows

proc quad*(sheet: SpriteSheet, col, row: int): Quad =
  ## The cell at (col, row) as a `Quad`, ready to hand to a texture's `draw`.
  ## Columns and rows count from zero, left to right and top to bottom.
  newQuad(
    (col * sheet.frameWidth).float,
    (row * sheet.frameHeight).float,
    sheet.frameWidth.float,
    sheet.frameHeight.float,
    sheet.image.width.float,
    sheet.image.height.float,
  )

proc newAnimation*(
    sheet: SpriteSheet, frames: openArray[(int, int)], frameTime: float, loop = true
): Animation =
  ## An animation over the given `frames`, each a (column, row) cell of `sheet`,
  ## every frame held for `frameTime` seconds. With `loop` it runs forever,
  ## otherwise it stops and holds on the last frame. Raises ValueError with no
  ## frames or a `frameTime` that is not positive.
  if frames.len == 0:
    raise newException(ValueError, "an animation needs at least one frame")
  if frameTime <= 0.0:
    raise newException(ValueError, "frame time must be positive")
  var qs: seq[Quad]
  var ds: seq[float]
  for f in frames:
    let (c, r) = f
    qs.add sheet.quad(c, r)
    ds.add frameTime
  Animation(sheet: sheet, frames: qs, durations: ds, loop: loop, playing: true)

proc newAnimation*(
    sheet: SpriteSheet,
    frames: openArray[(int, int)],
    durations: openArray[float],
    loop = true,
): Animation =
  ## An animation whose frames each carry their own duration, so a pose can linger
  ## while others flick past. `durations` must be the same length as `frames`, and
  ## every duration must be positive. Raises ValueError otherwise.
  if frames.len == 0:
    raise newException(ValueError, "an animation needs at least one frame")
  if frames.len != durations.len:
    raise newException(ValueError, "frames and durations must be the same length")
  for d in durations:
    if d <= 0.0:
      raise newException(ValueError, "every frame duration must be positive")
  var qs: seq[Quad]
  for f in frames:
    let (c, r) = f
    qs.add sheet.quad(c, r)
  Animation(sheet: sheet, frames: qs, durations: @durations, loop: loop, playing: true)

proc rowAnimation*(
    sheet: SpriteSheet, row: int, frameTime: float, loop = true
): Animation =
  ## An animation of a whole row, every column left to right, each frame held for
  ## `frameTime`. Handy when a sheet puts one cycle per row.
  var frames: seq[(int, int)]
  for c in 0 ..< sheet.cols:
    frames.add (c, row)
  newAnimation(sheet, frames, frameTime, loop)

proc update*(anim: Animation, dt: float) =
  ## Advance the animation by `dt` seconds, stepping to later frames as their
  ## time runs out and wrapping around when it loops. A paused or finished
  ## animation does not advance, and a non-looping one stops on its last frame and
  ## then reports `done`. A single-frame animation holds that frame, so it only
  ## moves once it has more than one. Frame durations are positive by
  ## construction, so the time always drains.
  if not anim.playing or anim.finished:
    return
  anim.time += dt
  while anim.time >= anim.durations[anim.index]:
    anim.time -= anim.durations[anim.index]
    if anim.index + 1 < anim.frames.len:
      inc anim.index
    elif anim.loop:
      anim.index = 0
    else:
      anim.finished = true
      break

proc quad*(anim: Animation): Quad =
  ## The current frame as a `Quad`.
  anim.frames[anim.index]

proc draw*(
    anim: Animation,
    nim2d: Nim2d,
    x, y: float,
    scale = 1.0,
    angle = 0.0,
    ox = 0.0,
    oy = 0.0,
) =
  ## Draw the current frame at (x, y), scaled uniformly by `scale`, turned by
  ## `angle` radians about the origin (ox, oy) given in unscaled frame pixels.
  anim.sheet.image.draw(
    nim2d, anim.frames[anim.index], x, y, angle, scale, scale, ox, oy
  )

proc currentFrame*(anim: Animation): int =
  ## The index of the frame showing now, counting from zero.
  anim.index

proc frameCount*(anim: Animation): int =
  ## How many frames the animation runs through.
  anim.frames.len

proc done*(anim: Animation): bool =
  ## True once a non-looping animation has reached and stopped on its last frame.
  anim.finished

proc reset*(anim: Animation) =
  ## Send the animation back to its first frame so it plays again from the start.
  anim.time = 0.0
  anim.index = 0
  anim.finished = false

proc setFrame*(anim: Animation, i: int) =
  ## Jump straight to frame `i`, clamped to the range, and clear the elapsed time
  ## on it. Useful to park an animation on a resting pose.
  anim.index = clamp(i, 0, anim.frames.len - 1)
  anim.time = 0.0
  anim.finished = false

proc pause*(anim: Animation) =
  ## Stop advancing on `update`, holding the current frame.
  anim.playing = false

proc resume*(anim: Animation) =
  ## Start advancing again after a `pause`.
  anim.playing = true
