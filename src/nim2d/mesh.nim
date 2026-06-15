## Meshes: a list of vertices you control, drawn as triangles, a triangle fan,
## or a triangle strip, with an optional texture. Build a vertex with
## `meshVertex`, make the mesh with `newMesh`, and draw it.

import types
import graphics
import backend/renderer

type
  MeshDraw* = enum
    ## How a mesh's vertices form triangles: independent triples, a fan around
    ## the first vertex, or a strip.
    mdTriangles
    mdFan
    mdStrip

  Mesh* = ref object
    ## A list of vertices you control, drawn as triangles with an optional
    ## texture. Without one the vertex colors show directly, which is how you
    ## make gradients.
    verts*: seq[Vertex]
    texture*: Texture
    mode*: MeshDraw

proc meshVertex*(
    x, y: float, u = 0.0, v = 0.0, color: Color = (255'u8, 255'u8, 255'u8, 255'u8)
): Vertex =
  ## A mesh vertex from a position, texture coordinates from 0 to 1, and a
  ## color.
  Vertex(
    x: x.float32,
    y: y.float32,
    u: u.float32,
    v: v.float32,
    r: color.r.float32 / 255,
    g: color.g.float32 / 255,
    b: color.b.float32 / 255,
    a: color.a.float32 / 255,
  )

proc newMesh*(verts: seq[Vertex], mode = mdTriangles, texture: Texture = nil): Mesh =
  ## A mesh from vertices built with `meshVertex`. Pass a texture to map it
  ## across the vertices' texture coordinates.
  Mesh(verts: verts, mode: mode, texture: texture)

proc meshIndices(mode: MeshDraw, n: int): seq[uint32] =
  case mode
  of mdTriangles:
    var i = 0
    while i + 2 < n:
      result.add uint32(i)
      result.add uint32(i + 1)
      result.add uint32(i + 2)
      i += 3
  of mdFan:
    for i in 1 ..< n - 1:
      result.add 0'u32
      result.add uint32(i)
      result.add uint32(i + 1)
  of mdStrip:
    for i in 0 ..< n - 2:
      if (i and 1) == 0:
        result.add uint32(i)
        result.add uint32(i + 1)
        result.add uint32(i + 2)
      else:
        result.add uint32(i + 1)
        result.add uint32(i)
        result.add uint32(i + 2)

proc draw*(mesh: Mesh, nim2d: Nim2d, x = 0.0, y = 0.0) =
  ## Draw the mesh, optionally offset by (x, y), through the current transform.
  if mesh.verts.len < 3:
    return
  let idx = meshIndices(mesh.mode, mesh.verts.len)
  let kind = if mesh.texture != nil: pkTextured else: pkColored
  let tex = if mesh.texture != nil: mesh.texture.tex else: nil
  nim2d.push()
  nim2d.translate(x, y)
  nim2d.gpu.addGeometry(kind, nim2d.blend, tex, mesh.verts, idx)
  nim2d.pop()
