# Data

The data module is encoding, hashing, compression and byte packing. None of it touches the screen, so you can use it anywhere.

## Base64 and hex

`encode` turns bytes or a string into base64, or into hex when you pass `hex = true`. `decode` gives you back the bytes, and `decodeString` gives back a string for when you know the payload was text.

```nim
let s = encode("hello")               # base64
let h = encode("hello", hex = true)   # hex
let back = decodeString(s)            # "hello"
```

## Hashing

`digest` returns the hash of a string or bytes as lowercase hex. The function is the first argument: `hfMD5`, `hfSHA1`, `hfSHA256` or `hfSHA512`. `digestRaw` gives the raw bytes instead.

```nim
echo digest(hfSHA256, "hello")
```

The proc is called `digest` rather than `hash` so it does not clash with the standard library's `hash` when you import both.

## Compression

`compress` shrinks bytes or a string, and `decompress` expands them again. The format is `compZlib`, `compGzip` or `compDeflate`, and an optional level runs from 1 for fastest to 9 for smallest, with -1 as a sensible middle. `decompressString` gives back a string.

```nim
let packed = compress(bigText, compZlib)
let text = decompressString(packed, compZlib)
```

Use the same format for `decompress` that you used to compress. Deflate has no header to detect, so it has to match.

## Packing

`pack` writes integers into bytes following a small format string, and `unpack` reads them back. The codes are `b` and `B` for one byte, `h` and `H` for two, `i` and `I` for four, and `l` and `L` for eight, with the lowercase ones signed. A `<` switches to little-endian and a `>` to big-endian, with little-endian the default, and spaces in the format are ignored.

```nim
let bytes = pack("<i h b", 70000, 513, -3)
let values = unpack("<i h b", bytes)    # @[70000, 513, -3]
```
