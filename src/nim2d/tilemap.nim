## Load and draw tile maps made in LDtk (https://ldtk.io).
##
## LDtk saves a project as one JSON file. This reads that file into a small model
## the engine can draw and query: a project holds its tilesets and levels, a level
## holds its layers (in bottom-to-top draw order), and a layer holds either placed
## tiles, an IntGrid (a grid of integers for collision or logic), or entities with
## their typed fields. AutoLayer tiles are baked into the file by LDtk, so this
## reads finished tiles and never runs the editor's rules.
##
## `parseLdtk` turns the JSON text into the model with no GPU, which is what makes
## it testable headlessly and what lets you bake a level in with `staticRead`.
## `loadLdtk` reads the file and also loads each tileset image, resolved relative
## to the file, so the example only needs one call. The tileset PNGs are loaded
## from disk either way, since that is how the engine loads any image.
##
## `draw` paints a level, `intGridAt` reads the collision grid to feed `collide`,
## and the level, layer and entity-field lookups pull the rest out by name.
##
## This is an opt-in module, imported on its own with `import nim2d/tilemap`. The
## core engine does not pull it in.

import std/[json, os, strutils, tables]
import types
import image

type
  LdtkLayerKind* = enum
    ## The kind of a layer: hand-placed `Tiles`, rule-painted `AutoLayer`, an
    ## `IntGrid` of per-cell integers for collision or logic, or `Entities`.
    lkTiles
    lkAutoLayer
    lkIntGrid
    lkEntities

  LdtkTile* = object
    ## One placed tile, positioned in level-local pixels with its
    ## source region already cut from the tileset (flips baked
    ## into the texcoords).
    x*, y*: float
    quad*: Quad
    alpha*: float
    tileId*: int

  LdtkEntity* = object
    ## An entity instance: where it sits, how big it is, an optional sprite tile,
    ## and its custom fields reached through the `get*` accessors.
    identifier*: string
    gridX*, gridY*: int
    x*, y*: float ## level-local pixel position
    width*, height*: int
    pivotX*, pivotY*: float
    hasTile*: bool
    tile*: Quad
    tilesetUid*: int
    tileset*: Image ## the image the tile is cut from, or nil
    fields*: Table[string, JsonNode]

  LdtkLayer* = object
    ## One layer of a level. By its `kind` it holds placed `tiles`, an `intGrid`,
    ## or `entities`. Tiles are positioned in level-local pixels.
    identifier*: string
    kind*: LdtkLayerKind
    cWid*, cHei*: int
    gridSize*: int
    offsetX*, offsetY*: float
    opacity*: float
    tilesetUid*: int
    tileset*: Image ## the tileset image these tiles are drawn from, or nil
    tiles*: seq[LdtkTile]
    intGrid*: seq[int] ## row-major, length cWid*cHei, 0 for empty
    entities*: seq[LdtkEntity]

  LdtkLevel* = ref object
    ## A single level: its position in the world, its size, background color, the
    ## identifiers of its neighbours, and its layers in bottom-to-top draw order.
    identifier*: string
    iid*: string
    worldX*, worldY*: int
    pxWid*, pxHei*: int
    bgColor*: Color
    neighbours*: seq[string] ## identifiers of adjacent levels
    layers*: seq[LdtkLayer] ## bottom-to-top, ready to draw in order
    fields*: Table[string, JsonNode]

  LdtkTileset* = object
    ## A tileset definition: the image its tiles are cut from and the cell size.
    uid*: int
    identifier*: string
    relPath*: string ## empty for LDtk's internal tilesets
    pxWid*, pxHei*: int
    gridSize*: int
    image*: Image ## loaded by loadLdtk, nil after parseLdtk alone

  LdtkProject* = ref object ## A loaded LDtk project: its tilesets and its levels.
    jsonVersion*: string
    tilesets*: seq[LdtkTileset]
    levels*: seq[LdtkLevel]

const supportedJsonVersion = "1.5.3"

# --- small JSON helpers -----------------------------------------------------

func jarr(n: JsonNode, key: string): seq[JsonNode] =
  let c = n{key}
  if c != nil and c.kind == JArray:
    c.getElems
  else:
    @[]

func parseHexColor(s: string): Color =
  ## LDtk colors are "#RRGGBB". Anything unexpected falls back to opaque white.
  if s.len >= 7 and s[0] == '#':
    try:
      return (
        parseHexInt(s[1 .. 2]).uint8,
        parseHexInt(s[3 .. 4]).uint8,
        parseHexInt(s[5 .. 6]).uint8,
        255'u8,
      )
    except ValueError:
      discard
  (255'u8, 255'u8, 255'u8, 255'u8)

func buildTileQuad(srcX, srcY, size, tsW, tsH: int, f: int): Quad =
  ## A source region for a tile, with the LDtk flip bits applied by swapping
  ## texcoords (bit 0 is an X flip, bit 1 a Y flip), which keeps the size positive.
  result = newQuad(srcX.float, srcY.float, size.float, size.float, tsW.float, tsH.float)
  # Pull the texcoords in by half a texel. Without this the edge sits exactly on a
  # texel boundary, and when the map scrolls at a fractional offset the sampler can
  # round into the neighbouring tile in the atlas, flickering as thin seams.
  let
    ix = 0.5'f32 / tsW.float32
    iy = 0.5'f32 / tsH.float32
  result.u0 += ix
  result.u1 -= ix
  result.v0 += iy
  result.v1 -= iy
  if (f and 1) != 0:
    swap(result.u0, result.u1)
  if (f and 2) != 0:
    swap(result.v0, result.v1)

# --- parsing ----------------------------------------------------------------

proc parseFields(n: JsonNode): Table[string, JsonNode] =
  for fi in n.jarr("fieldInstances"):
    result[fi["__identifier"].getStr] = fi{"__value"}

proc parseEntity(
    n: JsonNode, tilesets: Table[int, LdtkTileset], offsetX, offsetY: float
): LdtkEntity =
  result.identifier = n["__identifier"].getStr
  result.tilesetUid = -1
  let g = n.jarr("__grid")
  if g.len == 2:
    result.gridX = g[0].getInt
    result.gridY = g[1].getInt
  let p = n.jarr("px")
  if p.len == 2:
    # entity px is layer-local, the same as tile px, so apply the layer offset too
    result.x = offsetX + p[0].getFloat
    result.y = offsetY + p[1].getFloat
  result.width = n{"width"}.getInt
  result.height = n{"height"}.getInt
  let piv = n.jarr("__pivot")
  if piv.len == 2:
    result.pivotX = piv[0].getFloat
    result.pivotY = piv[1].getFloat
  let tile = n{"__tile"}
  if tile != nil and tile.kind == JObject:
    result.hasTile = true
    result.tilesetUid = tile{"tilesetUid"}.getInt(-1)
    if tilesets.hasKey(result.tilesetUid):
      let ts = tilesets[result.tilesetUid]
      result.tile = newQuad(
        tile{"x"}.getFloat,
        tile{"y"}.getFloat,
        tile{"w"}.getFloat,
        tile{"h"}.getFloat,
        ts.pxWid.float,
        ts.pxHei.float,
      )
  result.fields = parseFields(n)

proc parseLayer(n: JsonNode, tilesets: Table[int, LdtkTileset]): LdtkLayer =
  result.identifier = n["__identifier"].getStr
  result.kind =
    case n["__type"].getStr
    of "Tiles": lkTiles
    of "AutoLayer": lkAutoLayer
    of "IntGrid": lkIntGrid
    else: lkEntities
  result.cWid = n{"__cWid"}.getInt
  result.cHei = n{"__cHei"}.getInt
  result.gridSize = n{"__gridSize"}.getInt
  result.offsetX = n{"__pxTotalOffsetX"}.getFloat
  result.offsetY = n{"__pxTotalOffsetY"}.getFloat
  result.opacity = n{"__opacity"}.getFloat(1.0)

  let tsUid = n{"__tilesetDefUid"}.getInt(-1)
  result.tilesetUid = tsUid
  var size = result.gridSize
  if tsUid >= 0 and tilesets.hasKey(tsUid):
    let ts = tilesets[tsUid]
    size = ts.gridSize
  # gridTiles (Tiles layers) and autoLayerTiles (AutoLayer and IntGrid) both draw
  for key in ["gridTiles", "autoLayerTiles"]:
    for t in n.jarr(key):
      let px = t["px"]
      let src = t["src"]
      var tile = LdtkTile(
        x: result.offsetX + px[0].getFloat,
        y: result.offsetY + px[1].getFloat,
        alpha: t{"a"}.getFloat(1.0),
        tileId: t{"t"}.getInt,
      )
      if tsUid >= 0 and tilesets.hasKey(tsUid):
        let ts = tilesets[tsUid]
        tile.quad = buildTileQuad(
          src[0].getInt, src[1].getInt, size, ts.pxWid, ts.pxHei, t{"f"}.getInt
        )
      result.tiles.add tile

  for v in n.jarr("intGridCsv"):
    result.intGrid.add v.getInt
  for e in n.jarr("entityInstances"):
    result.entities.add parseEntity(e, tilesets, result.offsetX, result.offsetY)

proc parseLdtk*(jsonText: string): LdtkProject =
  ## Parse an LDtk project from its JSON text into the model, without a GPU or any
  ## image loading. Use this to test headlessly or to bake a level in through
  ## `staticRead`; call `loadTilesets` afterwards to draw it. Raises ValueError on
  ## malformed JSON.
  let root =
    try:
      parseJson(jsonText)
    except JsonParsingError as e:
      raise newException(ValueError, "invalid LDtk JSON: " & e.msg)
  result = LdtkProject(jsonVersion: root{"jsonVersion"}.getStr)
  if result.jsonVersion.len > 0 and
      result.jsonVersion.split('.')[0] != supportedJsonVersion.split('.')[0]:
    stderr.writeLine(
      "nim2d/tilemap: LDtk jsonVersion " & result.jsonVersion &
        " is a different major version than the supported " & supportedJsonVersion &
        ", parsing may be incomplete"
    )

  var byUid: Table[int, LdtkTileset]
  for t in root{"defs"}.jarr("tilesets"):
    let ts = LdtkTileset(
      uid: t["uid"].getInt,
      identifier: t{"identifier"}.getStr,
      relPath: t{"relPath"}.getStr(""),
      pxWid: t{"pxWid"}.getInt,
      pxHei: t{"pxHei"}.getInt,
      gridSize: t{"tileGridSize"}.getInt,
    )
    result.tilesets.add ts
    byUid[ts.uid] = ts

  # two LDtk save modes are not read yet, so warn rather than fail silently: a
  # project that saves levels to separate .ldtkl files (its levels arrive with no
  # layers), and a multi-world project whose levels live under worlds[].
  if root{"externalLevels"}.getBool(false):
    stderr.writeLine(
      "nim2d/tilemap: this project saves levels to separate .ldtkl files, which " &
        "are not loaded, so the levels come through with no layers"
    )
  if root.jarr("levels").len == 0 and root.jarr("worlds").len > 0:
    stderr.writeLine(
      "nim2d/tilemap: this project keeps its levels under worlds[], which is not " &
        "read, so no levels were loaded"
    )

  # first pass: collect levels and an iid -> identifier map for neighbours
  var iidToIdent: Table[string, string]
  let levelNodes = root.jarr("levels")
  for ln in levelNodes:
    iidToIdent[ln{"iid"}.getStr] = ln{"identifier"}.getStr

  for ln in levelNodes:
    let lv = LdtkLevel(
      identifier: ln{"identifier"}.getStr,
      iid: ln{"iid"}.getStr,
      worldX: ln{"worldX"}.getInt,
      worldY: ln{"worldY"}.getInt,
      pxWid: ln{"pxWid"}.getInt,
      pxHei: ln{"pxHei"}.getInt,
      bgColor: parseHexColor(ln{"__bgColor"}.getStr("#000000")),
      fields: parseFields(ln),
    )
    for nb in ln.jarr("__neighbours"):
      let id = iidToIdent.getOrDefault(nb{"levelIid"}.getStr, "")
      if id.len > 0:
        lv.neighbours.add id
    # layerInstances come top-first; store bottom-to-top so draw is a forward loop
    var layers: seq[LdtkLayer]
    for li in ln.jarr("layerInstances"):
      layers.add parseLayer(li, byUid)
    for i in countdown(layers.high, 0):
      lv.layers.add layers[i]
    result.levels.add lv

# --- loading images ---------------------------------------------------------

proc loadTilesets*(project: LdtkProject, nim2d: Nim2d, baseDir: string) =
  ## Load each tileset's PNG into an image, resolving its path relative to
  ## `baseDir` (the folder the `.ldtk` file lives in). Tilesets with no path, like
  ## LDtk's internal icons, are skipped. Then point every layer at its tileset
  ## image so `draw` is self-contained.
  var imgByUid: Table[int, Image]
  for i in 0 ..< project.tilesets.len:
    if project.tilesets[i].relPath.len > 0:
      let full = baseDir / project.tilesets[i].relPath
      if fileExists(full):
        project.tilesets[i].image = newImage(nim2d, full)
        imgByUid[project.tilesets[i].uid] = project.tilesets[i].image

  # attach each layer and entity to the image of the tileset it was cut against
  for lv in project.levels:
    for li in 0 ..< lv.layers.len:
      lv.layers[li].tileset = imgByUid.getOrDefault(lv.layers[li].tilesetUid, nil)
      for ei in 0 ..< lv.layers[li].entities.len:
        lv.layers[li].entities[ei].tileset =
          imgByUid.getOrDefault(lv.layers[li].entities[ei].tilesetUid, nil)

proc loadLdtk*(nim2d: Nim2d, path: string): LdtkProject =
  ## Read an LDtk file, parse it, and load its tileset images from the same
  ## folder. This is the one call an example or game needs. Raises IOError if the
  ## file cannot be read.
  let text =
    try:
      readFile(path)
    except IOError, OSError:
      raise newException(IOError, "could not read LDtk file '" & path & "'")
  result = parseLdtk(text)
  result.loadTilesets(nim2d, path.parentDir)

# --- drawing ----------------------------------------------------------------

proc draw*(level: LdtkLevel, nim2d: Nim2d, x = 0.0, y = 0.0, scale = 1.0) =
  ## Draw the level with its top-left at (x, y), every pixel scaled by `scale`.
  ## Layers paint bottom to top. Call `loadLdtk` (or `loadTilesets`) first, or the
  ## tile layers have no image to draw and are skipped.
  for li in 0 ..< level.layers.len:
    let img = level.layers[li].tileset
    if img == nil:
      continue
    let op = level.layers[li].opacity
    let baseA = img.tint.a # fold into per-tile alpha, then restore, so a
    for t in level.layers[li].tiles: # caller-set fade survives the draw
      img.setAlphaMod(uint8(clamp(op * t.alpha, 0.0, 1.0) * baseA.float + 0.5))
      img.draw(nim2d, t.quad, x + t.x * scale, y + t.y * scale, 0, scale, scale)
    img.setAlphaMod(baseA)

# --- queries ----------------------------------------------------------------

proc level*(project: LdtkProject, identifier: string): LdtkLevel =
  ## The level with this identifier, or nil if there is none.
  for lv in project.levels:
    if lv.identifier == identifier:
      return lv
  nil

proc intGridAt*(level: LdtkLevel, layerIdentifier: string, cx, cy: int): int =
  ## The IntGrid value at cell (cx, cy) of the named layer, or 0 (empty) when the
  ## layer is missing or the cell is out of range. A game checks this against its
  ## own "solid" value and feeds the result to `collide`.
  for li in 0 ..< level.layers.len:
    if level.layers[li].identifier == layerIdentifier and
        level.layers[li].kind == lkIntGrid:
      let w = level.layers[li].cWid
      let h = level.layers[li].cHei
      if cx < 0 or cy < 0 or cx >= w or cy >= h:
        return 0
      let idx = cy * w + cx
      if idx >= level.layers[li].intGrid.len: # a short or truncated CSV
        return 0
      return level.layers[li].intGrid[idx]
  0

proc layerGridSize*(level: LdtkLevel, layerIdentifier: string): int =
  ## The cell size in pixels of the named layer, or 0 if there is no such layer.
  for li in 0 ..< level.layers.len:
    if level.layers[li].identifier == layerIdentifier:
      return level.layers[li].gridSize
  0

proc entities*(level: LdtkLevel, identifier: string): seq[LdtkEntity] =
  ## Every entity instance with the given identifier, across the level's entity
  ## layers.
  for li in 0 ..< level.layers.len:
    for e in level.layers[li].entities:
      if e.identifier == identifier:
        result.add e

# --- entity field accessors -------------------------------------------------

proc getInt*(e: LdtkEntity, field: string, default = 0): int =
  ## An Int field, or `default` if it is missing or unset.
  let v = e.fields.getOrDefault(field)
  if v != nil and v.kind == JInt: v.getInt else: default

proc getFloat*(e: LdtkEntity, field: string, default = 0.0): float =
  ## A Float field, or `default` if it is missing or unset.
  let v = e.fields.getOrDefault(field)
  if v != nil and v.kind in {JInt, JFloat}: v.getFloat else: default

proc getBool*(e: LdtkEntity, field: string, default = false): bool =
  ## A Bool field, or `default` if it is missing or unset.
  let v = e.fields.getOrDefault(field)
  if v != nil and v.kind == JBool: v.getBool else: default

proc getStr*(e: LdtkEntity, field: string, default = ""): string =
  ## A String, Multilines, FilePath or enum field as text, or `default` if it is
  ## missing or unset.
  let v = e.fields.getOrDefault(field)
  if v != nil and v.kind == JString: v.getStr else: default

proc getColor*(
    e: LdtkEntity, field: string, default = (255'u8, 255'u8, 255'u8, 255'u8)
): Color =
  ## A Color field, or `default` if it is missing or unset.
  let v = e.fields.getOrDefault(field)
  if v != nil and v.kind == JString:
    parseHexColor(v.getStr)
  else:
    default

proc getPoint*(e: LdtkEntity, field: string): tuple[cx, cy: int] =
  ## A Point field as grid coordinates, or (0, 0) if it is missing or unset.
  let v = e.fields.getOrDefault(field)
  if v != nil and v.kind == JObject:
    (v{"cx"}.getInt, v{"cy"}.getInt)
  else:
    (0, 0)

proc getPoints*(e: LdtkEntity, field: string): seq[tuple[cx, cy: int]] =
  ## An `Array<Point>` field as grid coordinates in order, empty when the field
  ## is missing or unset. Handy for a patrol path or a marked-out region.
  let v = e.fields.getOrDefault(field)
  if v != nil and v.kind == JArray:
    for p in v.getElems:
      if p.kind == JObject:
        result.add (p{"cx"}.getInt, p{"cy"}.getInt)
