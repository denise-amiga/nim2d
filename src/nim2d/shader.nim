## User fragment shaders.
##
## `newShader` takes Metal Shading Language source for a fragment function named
## "frag", which replaces the built-in fragment stage while the shader is set.
## A standard preamble (the metal header and the VSOutput struct the built-in
## vertex shader produces) is prepended for you, so the source you pass is just
## the fragment function. It takes the vertex output through stage_in, a texture
## and sampler at slot 0, and, when you ask for a uniform, a fragment uniform
## buffer at slot 0. The exact signature is in the Shaders section of the docs
## and in the shader example.
##
## Inside the function, in.uv and in.color come from the vertex, in.position.xy
## is the pixel position, tex is the current texture (a white pixel when drawing
## shapes), and the uniform is filled by `send`.
##
## This is Metal only. A cross-platform path (GLSL or HLSL through
## SDL_shadercross) is not wired up yet.

import types
import backend/renderer

const Preamble = """
#include <metal_stdlib>
using namespace metal;
struct VSOutput { float4 position [[position]]; float2 uv [[user(locn0)]]; float4 color [[user(locn1)]]; };
"""

proc newShader*(nim2d: Nim2d, fragmentSrc: string, uniformFloats = 0): Shader =
  ## Compile a fragment shader. `uniformFloats` is how many float32 the fragment
  ## uniform holds (0 for none); fill it later with `send`.
  result = Shader(hasUniform: uniformFloats > 0)
  if uniformFloats > 0:
    result.uniform = newSeq[byte](uniformFloats * sizeof(float32))
  result.pipelines = nim2d.gpu.createShaderPipelines(Preamble & fragmentSrc,
                                                     result.hasUniform)

proc send*(shader: Shader, values: openArray[float32]) =
  ## Fill the fragment uniform buffer with float32 values.
  if not shader.hasUniform or values.len == 0: return
  let n = min(values.len * sizeof(float32), shader.uniform.len)
  copyMem(addr shader.uniform[0], unsafeAddr values[0], n)

proc setShader*(nim2d: Nim2d, shader: Shader) =
  ## Draw with this shader until it is unset.
  nim2d.gpu.curShader = shader

proc setShader*(nim2d: Nim2d) =
  ## Go back to the built-in shaders.
  nim2d.gpu.curShader = nil
