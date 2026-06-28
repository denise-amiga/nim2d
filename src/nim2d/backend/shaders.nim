## Built-in shaders for the 2D batch renderer.
##
## Each shader is authored once in GLSL in the repo's `shaders/` directory and
## compiled offline by `make shaders` into three blobs next to this module:
## SPIR-V for the Vulkan backend (Linux, and Windows), MSL for the Metal backend
## (macOS, iOS) and DXIL for the Direct3D 12 backend (Windows). The renderer picks
## the matching blob at runtime from `SDL_GetGPUShaderFormats`. All blobs are
## committed, so an ordinary build needs no shader toolchain.
##
## The SPIR-V and DXIL entry points are `main`; the MSL entry point is `main0`,
## since SPIRV-Cross renames `main` when it transpiles (`main` is reserved in MSL).

const
  VertexSPIRV* = staticRead("shaders/vertex.spv")
  VertexMSL* = staticRead("shaders/vertex.metal")
  VertexDXIL* = staticRead("shaders/vertex.dxil")
  FragmentColorSPIRV* = staticRead("shaders/color.spv")
  FragmentColorMSL* = staticRead("shaders/color.metal")
  FragmentColorDXIL* = staticRead("shaders/color.dxil")
  FragmentTextureSPIRV* = staticRead("shaders/texture.spv")
  FragmentTextureMSL* = staticRead("shaders/texture.metal")
  FragmentTextureDXIL* = staticRead("shaders/texture.dxil")
