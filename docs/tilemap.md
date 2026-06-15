# Tilemap

.. contents::

[LDtk](https://ldtk.io) is a free level editor. You paint tiles, mark collision on an integer grid, and place entities with typed fields, and it saves the whole project as one JSON file. The tilemap module reads that file and hands the level back as something the engine can draw and query. It is opt-in, imported on its own with `import nim2d/tilemap`, and the core engine does not pull it in.

It reads the main `.ldtk` JSON. The auto-layer tiles, the ones LDtk paints from rules while you edit, are baked into that file, so the module reads finished tiles and never runs the rules itself. Two LDtk save modes are not read yet: a project that saves each level to its own `.ldtkl` file, and a multi-world project that keeps its levels under a `worlds` array. The loader prints a warning when it meets either, so for now keep the levels embedded in the one `.ldtk` file, which is the default.

## Loading a project

`loadLdtk` reads the file and loads each tileset image named inside it, resolved relative to the file, so one call gives you a project ready to draw.

```nim
import nim2d
import nim2d/tilemap

let project = loadLdtk(n2d, getAppDir() / "cave.ldtk")
let level = project.levels[0]                  # or project.level("Cave")
```

A project holds its `tilesets` and its `levels`. Pick a level by index, or by name with `project.level(identifier)`. To bake the level data into the program instead, `parseLdtk(text)` does the JSON half on its own with no device, so `parseLdtk(staticRead("cave.ldtk"))` gives you the model. It does not touch the GPU, so follow it with `project.loadTilesets(n2d, baseDir)` to load the tileset images from disk and attach them, otherwise `draw` has no image and skips every tile layer.

The tileset images are ordinary engine images, so for pixel art switch them to nearest sampling once after loading.

```nim
for ts in project.tilesets:
  if ts.image != nil:
    ts.image.setFilter(filNearest)
```

## Drawing a level

`draw` paints a level with its top-left at the position you pass, scaled up by `scale`. Layers draw from the bottom up, so an upper layer covers the ones below, and the empty space between tiles is left alone, ready for you to clear to the level's own background color first.

```nim
n2d.draw = proc(nim2d: Nim2d) =
  nim2d.clear(level.bgColor.r, level.bgColor.g, level.bgColor.b)
  level.draw(nim2d, 0, 0, 3)
```

## Collision from the IntGrid

An IntGrid layer is a grid of integers, which is how LDtk marks collision and other per-cell logic, with 0 meaning empty. `intGridAt` reads the value at a cell, returning 0 for a cell that is out of range or a layer that is not there, so you never have to bounds-check first. You pick which value means solid and test against it.

```nim
proc solid(cx, cy: int): bool =
  level.intGridAt("Collisions", cx, cy) == 1
```

A cell is a pixel position divided by the layer's grid size, which `layerGridSize` gives you. From there it is the usual box-against-tiles test, and `collide` has the pieces for resolving it. The example does exactly this for a square that walks and jumps around the cave.

## Entities and their fields

`entities` returns every instance with a given identifier, across the level's entity layers. Each carries its grid and pixel position, its size and pivot, and its custom fields, read by name and type.

```nim
for door in level.entities("Door"):
  if door.getBool("locked"):
    lockUp(door.x, door.y)

let start = level.entities("Player")[0]
player.moveTo(start.x, start.y)
```

The field readers are `getInt`, `getFloat`, `getBool`, `getStr` (which also covers multiline text, file paths and enum values), `getColor` and `getPoint`, each taking a default for when the field is missing or unset, plus `getPoints` for an `Array<Point>` field such as a patrol path.

The tilemap example loads the cave from `AutoLayers_1_basic.ldtk`, draws it scaled up, and walks a square around it that bumps into the walls the IntGrid marks. A second example in the same folder, `platformer.nim`, loads the LDtk platformer sample to show the rest: several layers drawn at once, the player placed at a `Player` entity, mobs patrolling the waypoints from their `patrol` field, the four levels drawn together in world space with a camera following the player from one to the next, and a collision grid with more than one solid value, including a ladder you climb.
