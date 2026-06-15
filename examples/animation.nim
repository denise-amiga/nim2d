## A warrior you walk around a field of grass, showing the animation module. Move
## with WASD or the arrow keys. The warrior sheet has four rows, one per facing
## (up, right, down, left), each a three-frame walk cycle that plays while he
## moves and parks on the standing frame when he stops. The ground is grass tiles
## scattered with a seeded random, so it looks the same every run.
##
## The grass tiles come from the Ground Sprite Pack,
## https://opengameart.org/content/ground-sprite-pack, licensed CC-BY 4.0. The
## warrior comes from Antifarea's RPG Sprite Set 1 (enlarged, transparent
## background),
## https://opengameart.org/content/antifareas-rpg-sprite-set-1-enlarged-w-transparent-background,
## licensed CC-BY 3.0.
##
## Esc quits.

import std/os
import nim2d
import nim2d/animation

const
  TileSrc = 32 # grass tiles are 32 by 32
  TileScale = 2.0
  Tile = (TileSrc.float * TileScale).int # 64 on screen
  Cols = 13
  Rows = 9
  W = Cols * Tile # 832
  H = Rows * Tile # 576
  FrameW = 32 # warrior frame size, the 96x144 sheet is 3 by 4
  FrameH = 36
  WarriorScale = 3.0
  Speed = 150.0

# row order in the warrior sheet
const
  dirUp = 0
  dirRight = 1
  dirDown = 2
  dirLeft = 3

let n2d =
  newNim2d("nim2d - animation", 100, 60, W.cint, H.cint, (24'u8, 26'u8, 32'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 16)

let grass = [
  newImage(n2d, getAppDir() / "grass1.png"),
  newImage(n2d, getAppDir() / "grass2.png"),
  newImage(n2d, getAppDir() / "grass3.png"),
]
for g in grass:
  g.setFilter(filNearest) # crisp pixels when scaled up

# a fixed scatter of grass tiles, the same on every run
var ground: array[Cols, array[Rows, int]]
var rng = newRng(20260613'u64)
for c in 0 ..< Cols:
  for r in 0 ..< Rows:
    ground[c][r] = rng.randomInt(0, grass.len - 1)

let warriorImg = newImage(n2d, getAppDir() / "warrior_m.png")
warriorImg.setFilter(filNearest)
let sheet = newSpriteSheet(warriorImg, FrameW, FrameH)
# one walk cycle per facing, each the three frames of its row
let walk = [
  rowAnimation(sheet, dirUp, 0.12),
  rowAnimation(sheet, dirRight, 0.12),
  rowAnimation(sheet, dirDown, 0.12),
  rowAnimation(sheet, dirLeft, 0.12),
]

const
  halfW = FrameW.float / 2 * WarriorScale
  halfH = FrameH.float / 2 * WarriorScale

var
  pos: Vec2 = (W.float / 2, H.float / 2)
  facing = dirDown
  moving = false

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  if key == Key.escape:
    nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  var d: Vec2
  if isDown(Key.left) or isDown(Key.a):
    d.x -= 1
  if isDown(Key.right) or isDown(Key.d):
    d.x += 1
  if isDown(Key.up) or isDown(Key.w):
    d.y -= 1
  if isDown(Key.down) or isDown(Key.s):
    d.y += 1

  moving = d.x != 0 or d.y != 0
  if moving:
    # pick a facing from the movement, with left and right winning a diagonal
    if d.y < 0:
      facing = dirUp
    elif d.y > 0:
      facing = dirDown
    if d.x > 0:
      facing = dirRight
    elif d.x < 0:
      facing = dirLeft
    pos += d.normalized * (Speed * dt)
    pos.x = clamp(pos.x, halfW, W.float - halfW)
    pos.y = clamp(pos.y, halfH, H.float - halfH)
    walk[facing].update(dt)
  else:
    walk[facing].reset() # so the next step starts from the first frame

n2d.draw = proc(nim2d: Nim2d) =
  # the ground layer
  for c in 0 ..< Cols:
    for r in 0 ..< Rows:
      grass[ground[c][r]].draw(
        nim2d, (c * Tile).float, (r * Tile).float, 0, TileScale, TileScale
      )

  # a soft shadow under the warrior so he sits on the ground
  nim2d.setColor(rgba(0, 0, 0, 70))
  nim2d.circle(pos.x, pos.y + halfH - 6, 20, true)

  # the warrior, walking when he moves and resting on the standing frame when not
  if moving:
    walk[facing].draw(
      nim2d, pos.x, pos.y, WarriorScale, 0.0, FrameW.float / 2, FrameH.float / 2
    )
  else:
    warriorImg.draw(
      nim2d,
      sheet.quad(1, facing),
      pos.x,
      pos.y,
      0,
      WarriorScale,
      WarriorScale,
      FrameW.float / 2,
      FrameH.float / 2,
    )

  nim2d.setColor(rgba(8, 10, 16, 170))
  nim2d.rectangle(10, 10, 320, 32, true, roundness = 6)
  nim2d.setFont(font)
  nim2d.setColor(rgb(225, 232, 245))
  nim2d.print("WASD or arrows to move    Esc to quit", 22, 18)

n2d.play()
