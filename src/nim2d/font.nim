## Text rendering via SDL_ttf 3.x.
##
## A TrueType string is rasterized once to a white texture with
## TTF_RenderText_Blended and kept in a per-font cache, reused across frames with
## the draw color applied as a tint, so the same string is not uploaded again
## every frame. Drawing is one quad. UTF-8 in, no rune-pointer juggling.

import std/[strutils, tables]
import types
import backend/sdl
import backend/sdlttf
import backend/renderer
import image
import imagedata

const GlyphCacheMax = 512
  ## Max distinct strings kept rasterized per font (white textures, tinted at
  ## draw). LRU-evicted past this. Static UI text never approaches it; changing
  ## text (a clock, a score) trickles in and old values fall out.

var ttfReady = false

proc ensureTtf() =
  if not ttfReady:
    if not TTF_Init():
      raise newException(CatchableError, "TTF_Init failed: " & $SDL_GetError())
    ttfReady = true

proc newFont*(filename: string, size: cint): Font =
  ## Open a TrueType font at the given pixel size. Raises IOError when the
  ## file cannot be opened.
  ensureTtf()
  let f = TTF_OpenFont(filename.cstring, size.cfloat)
  if f == nil:
    raise newException(
      IOError, "could not open font '" & filename & "': " & $SDL_GetError()
    )
  Font(font: cast[pointer](f), size: size)

proc newImageFont*(
    nim2d: Nim2d, data: ImageData, glyphs: string, spacing: int32 = 1
): Font =
  ## A bitmap font from a glyph sheet. The glyphs sit in a row separated by
  ## columns of the sheet's top-left pixel color, and `glyphs` lists the
  ## characters in that order. It is sampled crisply (nearest) and tinted by the
  ## current color, like the TTF path. Good for pixel-art text.
  let sep = data.getPixel(0, 0)
  var xs, ws: seq[int32]
  var x = 0'i32
  while x < data.width:
    while x < data.width and data.getPixel(x, 0) == sep:
      inc x
      # skip separators
    if x >= data.width:
      break
    let start = x
    while x < data.width and data.getPixel(x, 0) != sep:
      inc x
      # the glyph run
    xs.add start
    ws.add(x - start)
  let img = nim2d.newImage(data)
  img.setFilter(filNearest)
  Font(
    img: img,
    glyphSet: glyphs,
    glyphX: xs,
    glyphW: ws,
    imgH: data.height,
    spacing: spacing,
    size: data.height,
  )

proc newImageFont*(nim2d: Nim2d, filename, glyphs: string, spacing: int32 = 1): Font =
  ## A bitmap font loaded from an image file. See the other overload.
  nim2d.newImageFont(newImageData(filename), glyphs, spacing)

proc destroy*(nim2d: Nim2d, font: Font) =
  ## Free a font's handles right away rather than waiting for it to be collected.
  ## The font is unusable afterwards. Use it when you load and drop many fonts,
  ## say on a level change; otherwise a font frees itself when it goes out of use.
  if font == nil:
    return
  if font.font != nil:
    TTF_CloseFont(cast[ptr TTF_Font](font.font))
    font.font = nil
  if font.img != nil:
    nim2d.destroy(font.img)
    font.img = nil
  # Release the cached glyph textures right away too. Not called mid-draw, so the
  # immediate release is safe (no pending command list references them).
  font.glyphCache.clear()

proc getAscent*(font: Font): int =
  ## How far the font reaches above the baseline, in pixels. A bitmap font
  ## reports its glyph height, since it draws from the top.
  if font.img != nil:
    return font.imgH.int
  TTF_GetFontAscent(cast[ptr TTF_Font](font.font)).int

proc getDescent*(font: Font): int =
  ## How far the font reaches below the baseline, as a negative pixel count.
  ## A bitmap font reports 0.
  if font.img != nil:
    return 0
  TTF_GetFontDescent(cast[ptr TTF_Font](font.font)).int

proc getHeight*(font: Font): int =
  ## The font's line height in pixels.
  if font.img != nil:
    return font.imgH.int
  TTF_GetFontHeight(cast[ptr TTF_Font](font.font)).int

proc getSize*(font: Font, text: string): tuple[w, h: int32] =
  ## The width and height in pixels that `text` would take when printed.
  if font.img != nil:
    var w = 0'i32
    for c in text:
      let idx = font.glyphSet.find(c)
      if idx >= 0 and idx < font.glyphW.len:
        w += font.glyphW[idx] + font.spacing
      else:
        w += font.imgH div 2
    return (w, font.imgH)
  var w, h: cint
  discard TTF_GetStringSize(
    cast[ptr TTF_Font](font.font), text.cstring, csize_t(text.len), addr w, addr h
  )
  (w.int32, h.int32)

proc print*(
    nim2d: Nim2d,
    text: string,
    x, y: float,
    angle: float = 0,
    sx: float = 1,
    sy: float = 1,
) =
  ## Draw `text` in the current color using the current font. Call inside `draw`.
  if nim2d.font == nil or text.len == 0:
    return
  let fnt = nim2d.font
  if fnt.img != nil:
    # Bitmap font: one quad per glyph. Rotation is not applied per call; for
    # rotated bitmap text, wrap the call in the transform stack.
    fnt.img.tint = nim2d.color
    var penX = x
    for c in text:
      let idx = fnt.glyphSet.find(c)
      if idx >= 0 and idx < fnt.glyphX.len:
        let q = newQuad(
          fnt.glyphX[idx].float,
          0,
          fnt.glyphW[idx].float,
          fnt.imgH.float,
          fnt.img.width.float,
          fnt.img.height.float,
        )
        fnt.img.draw(nim2d, q, penX, y, 0, sx, sy)
        penX += (fnt.glyphW[idx].float + fnt.spacing.float) * sx
      else:
        penX += fnt.imgH.float * 0.5 * sx
    return
  if fnt.font == nil:
    return
  # Rasterizing and uploading a new GPU texture for every print call, every
  # frame, churns the renderer's resource budget hard enough that Vulkan and D3D
  # run out after a few minutes and the GPU hangs (Metal tolerates the churn, so
  # it only showed on Windows). So each distinct string is rasterized once in
  # white and kept in a per-font cache, then reused with this call's color and
  # alpha applied as the draw tint, so every color and fade of a string shares
  # the one cached texture.
  inc fnt.cacheClock
  var glyphs: Texture
  fnt.glyphCache.withValue(text, cached):
    glyphs = cached.tex
    cached.tick = fnt.cacheClock # touch, for LRU
  do:
    let f = cast[ptr TTF_Font](fnt.font)
    let white = SDL_Color(r: 255, g: 255, b: 255, a: 255)
    var surf = TTF_RenderText_Blended(f, text.cstring, csize_t(text.len), white)
    if surf == nil:
      return
    if surf.format != SDL_PIXELFORMAT_RGBA32:
      let conv = SDL_ConvertSurface(surf, SDL_PIXELFORMAT_RGBA32)
      SDL_DestroySurface(surf)
      if conv == nil:
        return
      surf = conv
    let w = surf.w
    let h = surf.h
    var tex: ptr SDL_GPUTexture
    try:
      tex = nim2d.gpu.createTextureFromPixels(surf.pixels, w, h, surf.pitch)
    finally:
      SDL_DestroySurface(surf)
    glyphs =
      Texture(tex: tex, width: w, height: h, tint: (255'u8, 255'u8, 255'u8, 255'u8))
    # Bound the cache, dropping the least-recently-used string. Hand its texture
    # to the renderer to release after the frame submits, since it may have been
    # drawn this frame and still sit in the pending command list, where releasing
    # it now would be a use-after-free of that draw. Then clear the wrapper so its
    # own destructor does not release it a second time.
    if fnt.glyphCache.len >= GlyphCacheMax:
      var oldKey: string
      var oldTick = high(uint64)
      for k, v in fnt.glyphCache:
        if v.tick < oldTick:
          oldTick = v.tick
          oldKey = k
      let dead = fnt.glyphCache[oldKey].tex
      if dead != nil and dead.tex != nil:
        nim2d.gpu.addTempTexture(dead.tex)
        dead.tex = nil
      fnt.glyphCache.del(oldKey)
    fnt.glyphCache[text] = (tex: glyphs, tick: fnt.cacheClock)
  glyphs.tint = nim2d.color # this call's color and alpha, over the white texture
  glyphs.draw(nim2d, x, y, angle, sx, sy)
