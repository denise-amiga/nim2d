#!/usr/bin/env bash
# Regenerate the built-in shader blobs from the GLSL sources: SPIR-V for the
# Vulkan backend and MSL for the Metal backend. Needs glslc (shaderc) and the
# SDL_shadercross CLI; set GLSLC / SHADERCROSS to point at them if they are not
# on PATH. The .spv and .metal outputs are committed, so this only needs running
# when a shader source changes, not as part of a normal build.
set -e
cd "$(dirname "$0")"
GLSLC="${GLSLC:-glslc}"
SHADERCROSS="${SHADERCROSS:-shadercross}"

gen() {
  local src="$1" stage="$2" name="$3"
  "$GLSLC" -fshader-stage="$stage" "$src" -o "$name.spv"
  "$SHADERCROSS" "$name.spv" -s SPIRV -d MSL -t "$stage" -e main -o "$name.metal"
}

gen vertex.vert  vertex   vertex
gen color.frag   fragment color
gen texture.frag fragment texture
echo "shaders regenerated (spv + metal)"
