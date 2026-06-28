#!/usr/bin/env bash
# Compile the built-in shaders from GLSL (shaders/) to SPIR-V, MSL and DXIL blobs
# in the library source tree (src/nim2d/backend/shaders/). Driven by `make
# shaders`; see shaders.mk for how to get glslc and the shadercross CLI.
#
# The DXIL step (for the Direct3D 12 backend on Windows) needs a shadercross built
# with DXC. A shadercross without DXC cannot emit DXIL, so set DXIL=0 to skip it
# and keep the committed DXIL blobs; the SPIR-V and MSL blobs still regenerate.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/shaders"
OUT="$ROOT/src/nim2d/backend/shaders"
GLSLC="${GLSLC:-glslc}"
SHADERCROSS="${SHADERCROSS:-shadercross}"
DXIL="${DXIL:-1}"

gen() {
  local src="$1" stage="$2" name="$3"
  "$GLSLC" -fshader-stage="$stage" "$SRC/$src" -o "$OUT/$name.spv"
  "$SHADERCROSS" "$OUT/$name.spv" -s SPIRV -d MSL -t "$stage" -e main -o "$OUT/$name.metal"
  if [ "$DXIL" != "0" ]; then
    "$SHADERCROSS" "$OUT/$name.spv" -s SPIRV -d DXIL -t "$stage" -e main -o "$OUT/$name.dxil"
  fi
}

gen vertex.vert  vertex   vertex
gen color.frag   fragment color
gen texture.frag fragment texture
echo "shaders compiled to $OUT"
