import std/unittest
import std/os
import nim2d/tilemap

# parseLdtk is pure, so it tests headlessly with no GPU. The real sample shipped
# with the example is the fixture for the realistic case, and a two-level inline
# project exercises layer order, the flip bits, layer offset/opacity/alpha,
# multiple tilesets, entity tiles and fields, and neighbour resolution
# deterministically. loadLdtk and draw need a device and are left to the example.

const fixture =
  currentSourcePath().parentDir / ".." / "examples" / "tilemap" /
  "AutoLayers_1_basic.ldtk"

const platformerFixture =
  currentSourcePath().parentDir / ".." / "examples" / "tilemap" /
  "Typical_2D_platformer_example.ldtk"

const inlineProject =
  """
{
  "jsonVersion": "1.5.3",
  "defs": { "tilesets": [
    { "uid": 1, "identifier": "ts1", "relPath": "ts1.png", "pxWid": 16, "pxHei": 16, "tileGridSize": 8 },
    { "uid": 2, "identifier": "ts2", "relPath": "ts2.png", "pxWid": 32, "pxHei": 32, "tileGridSize": 16 }
  ]},
  "levels": [
    {
      "identifier": "A", "iid": "aaa", "worldX": 0, "worldY": 0, "pxWid": 16, "pxHei": 16,
      "__bgColor": "#102030",
      "__neighbours": [ {"dir": "e", "levelIid": "bbb"}, {"dir": "w", "levelIid": "zzz"} ],
      "layerInstances": [
        {
          "__identifier": "Entities", "__type": "Entities", "__cWid": 2, "__cHei": 2,
          "__gridSize": 8, "__pxTotalOffsetX": 2, "__pxTotalOffsetY": -4, "__opacity": 1,
          "__tilesetDefUid": null,
          "entityInstances": [
            { "__identifier": "Spawn", "__grid": [1,1], "px": [8,8], "width": 8, "height": 8,
              "__pivot": [0,0], "__tile": { "tilesetUid": 1, "x": 8, "y": 0, "w": 8, "h": 8 },
              "fieldInstances": [
                {"__identifier": "Integer", "__type": "Int", "__value": 42},
                {"__identifier": "Name", "__type": "String", "__value": "hero"},
                {"__identifier": "Flag", "__type": "Bool", "__value": true},
                {"__identifier": "Tint", "__type": "Color", "__value": "#FF8800"},
                {"__identifier": "Spot", "__type": "Point", "__value": {"cx": 3, "cy": 4}},
                {"__identifier": "Path", "__type": "Array<Point>", "__value": [{"cx": 1, "cy": 2}, {"cx": 3, "cy": 4}]},
                {"__identifier": "Speed", "__type": "Float", "__value": 1.5},
                {"__identifier": "Whole", "__type": "Float", "__value": 2}
              ]
            }
          ]
        },
        {
          "__identifier": "Floor", "__type": "Tiles", "__cWid": 2, "__cHei": 2,
          "__gridSize": 16, "__pxTotalOffsetX": 0, "__pxTotalOffsetY": 0, "__opacity": 1,
          "__tilesetDefUid": 2,
          "gridTiles": [ { "px": [0,0], "src": [16,0], "f": 0, "t": 5, "a": 1 } ]
        },
        {
          "__identifier": "Walls", "__type": "IntGrid", "__cWid": 2, "__cHei": 2,
          "__gridSize": 8, "__pxTotalOffsetX": 4, "__pxTotalOffsetY": -8, "__opacity": 0.5,
          "__tilesetDefUid": 1,
          "intGridCsv": [0, 1, 1, 0],
          "autoLayerTiles": [
            { "px": [16,16], "src": [8,0], "f": 1, "t": 1, "a": 0.25 },
            { "px": [0,0],   "src": [8,0], "f": 2, "t": 1, "a": 1 },
            { "px": [0,0],   "src": [8,0], "f": 3, "t": 1, "a": 1 }
          ]
        }
      ]
    },
    {
      "identifier": "B", "iid": "bbb", "worldX": 16, "worldY": 0, "pxWid": 16, "pxHei": 16,
      "__bgColor": "#000000", "layerInstances": []
    }
  ]
}
"""

proc close(a: float32, b: float): bool =
  abs(a.float - b) < 1e-6

suite "parse the real sample":
  test "tileset, level and the IntGrid layer come through":
    let p = parseLdtk(readFile(fixture))
    check p.jsonVersion == "1.5.3"
    check p.tilesets.len == 1
    check p.tilesets[0].identifier == "Cavernas_by_Adam_Saltsman"
    check p.tilesets[0].pxWid == 96 and p.tilesets[0].pxHei == 256
    check p.tilesets[0].gridSize == 8
    check p.levels.len == 1
    let lv = p.levels[0]
    check lv.pxWid == 296 and lv.pxHei == 208
    check lv.layers.len == 1
    check lv.layers[0].kind == lkIntGrid
    check lv.layers[0].tiles.len == 984 # auto-rendered cave tiles
    check lv.layers[0].intGrid.len == 962 # 37 * 26 collision cells
    check lv.layerGridSize("IntGrid_layer") == 8

suite "the inline project":
  let project = parseLdtk(inlineProject)
  let a = project.level("A")

  test "layers are stored bottom-to-top with their kinds":
    check a.layers.len == 3
    check a.layers[0].identifier == "Walls" and a.layers[0].kind == lkIntGrid
    check a.layers[1].identifier == "Floor" and a.layers[1].kind == lkTiles
    check a.layers[2].identifier == "Entities" and a.layers[2].kind == lkEntities

  test "colors parse from hex":
    check a.bgColor.r == 16 and a.bgColor.g == 32 and a.bgColor.b == 48

  test "intGridAt reads cells and clamps out of range to 0":
    check a.intGridAt("Walls", 0, 0) == 0
    check a.intGridAt("Walls", 1, 0) == 1
    check a.intGridAt("Walls", 0, 1) == 1
    check a.intGridAt("Walls", 1, 1) == 0
    check a.intGridAt("Walls", 9, 9) == 0 # out of range
    check a.intGridAt("Missing", 0, 0) == 0 # no such layer

  test "the flip bits swap the right texcoords":
    let t = a.layers[0].tiles
    check t.len == 3
    # src [8,0] of a 16x16 sheet is u 0.5..1.0, v 0..0.5
    check t[0].quad.u0 > t[0].quad.u1 and t[0].quad.v0 < t[0].quad.v1 # f=1, X only
    check t[1].quad.u0 < t[1].quad.u1 and t[1].quad.v0 > t[1].quad.v1 # f=2, Y only
    check t[2].quad.u0 > t[2].quad.u1 and t[2].quad.v0 > t[2].quad.v1 # f=3, both

  test "layer offset, opacity and per-tile alpha carry onto tiles":
    check a.layers[0].opacity == 0.5
    check a.layers[0].tiles[0].x == 20.0 # px 16 + offset 4
    check a.layers[0].tiles[0].y == 8.0 # px 16 + offset -8
    check a.layers[0].tiles[0].alpha == 0.25

  test "each layer keeps its own tileset and cuts quads from it":
    check a.layers[0].tilesetUid == 1
    check a.layers[1].tilesetUid == 2
    check a.layers[2].tilesetUid == -1 # the Entities layer has no tileset
    # the Floor tile is cut against the 32x32 tileset, not the 16x16 one
    check close(a.layers[1].tiles[0].quad.w, 16.0)
    # u0 near 0.5 (16/32, give or take the half-texel inset) shows it was cut from
    # the 32px-wide atlas, not the 16px one (where it would be ~1.0)
    check a.layers[1].tiles[0].quad.u0 > 0.45 and a.layers[1].tiles[0].quad.u0 < 0.55

  test "an entity carries its position, tile and typed fields":
    let spawns = a.entities("Spawn")
    check spawns.len == 1
    let s = spawns[0]
    check s.gridX == 1 and s.gridY == 1
    check s.x == 10.0 and s.y == 4.0 # px (8,8) + the layer offset (2,-4)
    check s.hasTile and s.tilesetUid == 1
    check close(s.tile.u0, 0.5) and close(s.tile.v0, 0.0)
    check close(s.tile.u1, 1.0) and close(s.tile.v1, 0.5)
    check close(s.tile.w, 8.0) and close(s.tile.h, 8.0)
    check s.getInt("Integer") == 42
    check s.getStr("Name") == "hero"
    check s.getBool("Flag")
    let tint = s.getColor("Tint")
    check tint.r == 255 and tint.g == 136 and tint.b == 0
    let spot = s.getPoint("Spot")
    check spot.cx == 3 and spot.cy == 4
    let path = s.getPoints("Path")
    check path.len == 2
    check path[0].cx == 1 and path[0].cy == 2
    check path[1].cx == 3 and path[1].cy == 4
    check s.getPoints("Missing").len == 0
    check s.getFloat("Speed") == 1.5
    check s.getFloat("Whole") == 2.0 # a whole number stored as an int still reads
    check s.getFloat("Missing", -1.0) == -1.0
    check s.getInt("Missing", -1) == -1

  test "neighbour iids resolve to identifiers and unknown ones drop":
    check a.neighbours == @["B"] # "bbb" resolves to B, the bogus "zzz" is dropped

suite "parse the platformer sample":
  let p = parseLdtk(readFile(platformerFixture))

  test "all four levels load":
    check p.levels.len == 4

  test "the SunnyLand tileset and the internal one both come through":
    var sunny = false
    var internal = false
    for ts in p.tilesets:
      if ts.identifier == "SunnyLand_by_Ansimuz":
        sunny = true
        check ts.pxWid == 368 and ts.pxHei == 336 and ts.gridSize == 16
        check ts.relPath.len > 0
      if ts.relPath.len == 0:
        internal = true # LDtk's internal icon atlas, with no path
    check sunny and internal

  test "the start level has a Player entity and a Collisions grid":
    let start = p.level("Your_typical_2D_platformer")
    check start != nil
    check start.entities("Player").len == 1
    check start.layerGridSize("Collisions") == 16

  test "a level's neighbours resolve to real level identifiers":
    let start = p.level("Your_typical_2D_platformer")
    check start.neighbours.len == 3
    for nb in start.neighbours:
      check p.level(nb) != nil

suite "errors":
  test "malformed JSON is rejected":
    expect ValueError:
      discard parseLdtk("{ not valid json ")
