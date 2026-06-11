## Encoding, hashing, compression and byte packing.
##
## This is pure CPU work with no GPU or window involved. It covers base64 and
## hex, message digests (md5, sha1, sha256, sha512) returned as lowercase hex,
## compression in the zlib, gzip and deflate formats, and a small integer
## packer. Hex and base64 are reversible, digests are one-way, and the digest
## proc is named `digest` rather than `hash` so it does not shadow
## `std/hashes.hash` for code that imports both.

import std/base64
import zippy

{.push warning[Deprecated]: off.}
import std/md5
{.pop.}

import nimcrypto/hash
import nimcrypto/sha
import nimcrypto/sha2

type
  HashFunction* = enum
    ## The supported message-digest algorithms.
    hfMD5, hfSHA1, hfSHA256, hfSHA512

  CompressFormat* = enum
    ## The compressed container formats: zlib, gzip and raw deflate.
    compZlib, compGzip, compDeflate

# --- byte / string helpers -------------------------------------------------

proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  if s.len > 0:
    copyMem(addr result[0], unsafeAddr s[0], s.len)

proc toString(data: openArray[byte]): string =
  result = newString(data.len)
  if data.len > 0:
    copyMem(addr result[0], unsafeAddr data[0], data.len)

# --- hex -------------------------------------------------------------------

const hexDigits = "0123456789abcdef"

func hexValue(c: char): int =
  case c
  of '0'..'9': ord(c) - ord('0')
  of 'a'..'f': ord(c) - ord('a') + 10
  of 'A'..'F': ord(c) - ord('A') + 10
  else: raise newException(ValueError, "hex: invalid digit '" & c & "'")

proc hexEncode(data: openArray[byte]): string =
  result = newStringOfCap(data.len * 2)
  for b in data:
    result.add hexDigits[int(b shr 4)]
    result.add hexDigits[int(b and 0x0f)]

proc hexDecode(s: string): seq[byte] =
  if s.len mod 2 != 0:
    raise newException(ValueError, "hex: odd-length string")
  result = newSeqOfCap[byte](s.len div 2)
  var i = 0
  while i < s.len:
    result.add byte((hexValue(s[i]) shl 4) or hexValue(s[i + 1]))
    i += 2

# --- base64 / hex encoding -------------------------------------------------

proc encode*(data: openArray[byte], hex = false): string =
  ## Encode raw bytes as base64, or as lowercase hex when `hex` is true.
  if hex: hexEncode(data) else: base64.encode(data)

proc encode*(s: string, hex = false): string =
  ## Encode a string's bytes as base64, or as hex when `hex` is true.
  if hex: hexEncode(s.toOpenArrayByte(0, s.high)) else: base64.encode(s)

proc decode*(s: string, hex = false): seq[byte] =
  ## Decode a base64 (or hex) string back to raw bytes.
  if hex: hexDecode(s) else: toBytes(base64.decode(s))

proc decodeString*(s: string, hex = false): string =
  ## Decode base64 or hex to a string, for when the payload is known text.
  if hex: toString(hexDecode(s)) else: base64.decode(s)

# --- hashing ---------------------------------------------------------------

proc digestRaw*(fn: HashFunction, data: openArray[byte]): seq[byte] =
  ## Return the raw digest bytes of `data` under the chosen hash function.
  case fn
  of hfMD5:
    {.push warning[Deprecated]: off.}
    let d = toMD5(toString(data))
    {.pop.}
    result = newSeq[byte](16)
    for i in 0 .. 15: result[i] = d[i]
  of hfSHA1:
    result = @(sha1.digest(data).data)
  of hfSHA256:
    result = @(sha256.digest(data).data)
  of hfSHA512:
    result = @(sha512.digest(data).data)

proc digest*(fn: HashFunction, data: openArray[byte]): string =
  ## Return the lowercase hex digest of `data` under the chosen hash function.
  hexEncode(digestRaw(fn, data))

proc digest*(fn: HashFunction, s: string): string =
  ## Return the lowercase hex digest of a string.
  digest(fn, s.toOpenArrayByte(0, s.high))

# --- compression -----------------------------------------------------------

func toZippy(f: CompressFormat): CompressedDataFormat =
  case f
  of compZlib: dfZlib
  of compGzip: dfGzip
  of compDeflate: dfDeflate

proc compress*(data: openArray[byte], format = compZlib, level = -1): seq[byte] =
  ## Compress bytes with zlib, gzip or deflate. Level -1 is the default, 1 is
  ## fastest and 9 is smallest.
  zippy.compress(@data, level, toZippy(format))

proc compress*(s: string, format = compZlib, level = -1): seq[byte] =
  ## Compress a string's bytes.
  compress(s.toOpenArrayByte(0, s.high), format, level)

proc decompress*(data: openArray[byte], format = compZlib): seq[byte] =
  ## Reverse `compress` for the given format.
  zippy.uncompress(@data, toZippy(format))

proc decompressString*(data: openArray[byte], format = compZlib): string =
  ## Decompress to a string when the original payload was text.
  toString(decompress(data, format))

# --- integer packing -------------------------------------------------------
#
# The format string is a run of width codes, optionally switched between little
# and big endian by '<' and '>' (little is the default). Lowercase codes are
# signed, uppercase unsigned: b/B is one byte, h/H two, i/I four, l/L eight.
# Spaces are ignored.

proc codeSize(c: char): int =
  case c
  of 'b', 'B': 1
  of 'h', 'H': 2
  of 'i', 'I': 4
  of 'l', 'L': 8
  else: 0

proc pack*(format: string, args: varargs[int64]): seq[byte] =
  ## Pack integer args into bytes following a format string of width and
  ## endianness codes.
  result = @[]
  var little = true
  var argi = 0
  for ch in format:
    case ch
    of ' ': discard
    of '<', '=': little = true
    of '>': little = false
    of 'b', 'B', 'h', 'H', 'i', 'I', 'l', 'L':
      let size = codeSize(ch)
      if argi >= args.len:
        raise newException(ValueError, "pack: not enough arguments for format")
      let v = cast[uint64](args[argi])
      inc argi
      for k in 0 ..< size:
        let shift = (if little: k else: size - 1 - k) * 8
        result.add byte((v shr shift) and 0xff)
    else:
      raise newException(ValueError, "pack: unknown format char '" & ch & "'")
  if argi != args.len:
    raise newException(ValueError, "pack: more arguments than format codes")

proc unpack*(format: string, data: openArray[byte]): seq[int64] =
  ## Unpack bytes back into integers following the same format string used to
  ## pack them.
  result = @[]
  var little = true
  var pos = 0
  for ch in format:
    case ch
    of ' ': discard
    of '<', '=': little = true
    of '>': little = false
    of 'b', 'B', 'h', 'H', 'i', 'I', 'l', 'L':
      let size = codeSize(ch)
      let signed = ch in {'b', 'h', 'i', 'l'}
      if pos + size > data.len:
        raise newException(ValueError, "unpack: data too short for format")
      var v: uint64 = 0
      for k in 0 ..< size:
        let b = if little: data[pos + k] else: data[pos + size - 1 - k]
        v = v or (uint64(b) shl (k * 8))
      pos += size
      if signed and size < 8:
        let signBit = uint64(1) shl (size * 8 - 1)
        if (v and signBit) != 0:
          v = v or not ((uint64(1) shl (size * 8)) - 1)
      result.add cast[int64](v)
    else:
      raise newException(ValueError, "unpack: unknown format char '" & ch & "'")
