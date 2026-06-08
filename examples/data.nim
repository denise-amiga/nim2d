## A window-free tour of the data module: base64 and hex, the four hash
## functions, compression in each format, and integer packing. Because it never
## opens a window it doubles as a quick smoke test.

import std/strutils
import nim2d/data

let msg = "Pack my box with five dozen liquor jugs."

echo "message: ", msg
echo "base64:  ", encode(msg)
echo "hex:     ", encode(msg, hex = true)
echo "decoded: ", decodeString(encode(msg))

echo ""
echo "md5:     ", digest(hfMD5, msg)
echo "sha1:    ", digest(hfSHA1, msg)
echo "sha256:  ", digest(hfSHA256, msg)
echo "sha512:  ", digest(hfSHA512, msg)

echo ""
let blob = "nim2d ".repeat(256)
for fmt in [compZlib, compGzip, compDeflate]:
  let packed = compress(blob, fmt)
  let ok = decompressString(packed, fmt) == blob
  echo fmt, ": ", blob.len, " -> ", packed.len, " bytes, round-trips: ", ok

echo ""
let bytes = pack("<i H b", 70000, 513, -3)
echo "packed:   ", bytes
echo "unpacked: ", unpack("<i H b", bytes)
