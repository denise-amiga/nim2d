## Sprite batches: many copies of one texture built up together and drawn in one
## go. Add sprites with `add`, draw the whole thing with `draw`, and `clear` to
## start over. The current color set with `setColor` tints sprites added after it.

import types
import transform
import graphics
import backend/renderer

type SpriteBatch* = ref object
  texture*: Texture
  color*: Color
  verts: seq[Vertex]
  indices: seq[uint32]

proc newSpriteBatch*(image: Texture): SpriteBatch =
  SpriteBatch(texture: image, color: (255'u8, 255'u8, 255'u8, 255'u8))

proc setColor*(batch: SpriteBatch, r, g, b: uint8, a: uint8 = 255) =
  batch.color = (r, g, b, a)

proc clear*(batch: SpriteBatch) =
  batch.verts.setLen(0)
  batch.indices.setLen(0)

proc count*(batch: SpriteBatch): int = batch.verts.len div 4

proc addRegion(batch: SpriteBatch, w, h, x, y, angle, sx, sy, ox, oy: float,
               u0, v0, u1, v1: float32) =
  let tr = identity().translate(x, y).rotate(angle).scale(sx, sy)
  let (x0, y0) = tr.apply(0 - ox, 0 - oy)
  let (x1, y1) = tr.apply(w - ox, 0 - oy)
  let (x2, y2) = tr.apply(w - ox, h - oy)
  let (x3, y3) = tr.apply(0 - ox, h - oy)
  let c = (batch.color.r.float32 / 255, batch.color.g.float32 / 255,
           batch.color.b.float32 / 255, batch.color.a.float32 / 255)
  let base = uint32(batch.verts.len)
  template vtx(px, py, tu, tv: untyped): Vertex =
    Vertex(x: px.float32, y: py.float32, u: tu, v: tv, r: c[0], g: c[1], b: c[2], a: c[3])
  batch.verts.add vtx(x0, y0, u0, v0)
  batch.verts.add vtx(x1, y1, u1, v0)
  batch.verts.add vtx(x2, y2, u1, v1)
  batch.verts.add vtx(x3, y3, u0, v1)
  for i in [0'u32, 1, 2, 0, 2, 3]: batch.indices.add base + i

proc add*(batch: SpriteBatch, x, y: float, angle = 0.0, sx = 1.0, sy = 1.0,
          ox = 0.0, oy = 0.0) =
  batch.addRegion(batch.texture.width.float, batch.texture.height.float,
                  x, y, angle, sx, sy, ox, oy, 0, 0, 1, 1)

proc add*(batch: SpriteBatch, quad: Quad, x, y: float, angle = 0.0, sx = 1.0,
          sy = 1.0, ox = 0.0, oy = 0.0) =
  batch.addRegion(quad.w.float, quad.h.float, x, y, angle, sx, sy, ox, oy,
                  quad.u0, quad.v0, quad.u1, quad.v1)

proc draw*(batch: SpriteBatch, nim2d: Nim2d, x = 0.0, y = 0.0) =
  if batch.verts.len == 0: return
  nim2d.push()
  nim2d.translate(x, y)
  nim2d.gpu.addGeometry(pkTextured, nim2d.blend, batch.texture.tex,
                        batch.verts, batch.indices)
  nim2d.pop()
