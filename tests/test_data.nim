import std/unittest
import std/strutils   # repeat
import nim2d/data

suite "data (encoding / hashing / compression / packing)":
  test "base64 round-trips and matches known vectors":
    check encode("") == ""
    check encode("f") == "Zg=="
    check encode("fo") == "Zm8="
    check encode("foobar") == "Zm9vYmFy"
    check decodeString(encode("hello, nim2d")) == "hello, nim2d"
    let bytes = @[0'u8, 255, 1, 128, 64]
    check decode(encode(bytes)) == bytes

  test "hex round-trips and matches a known vector":
    check encode("foobar", hex = true) == "666f6f626172"
    check decodeString("666f6f626172", hex = true) == "foobar"
    let bytes = @[0'u8, 15, 255, 16]
    check encode(bytes, hex = true) == "000fff10"
    check decode("000fff10", hex = true) == bytes
    expect ValueError:
      discard decode("abc", hex = true)   # odd length

  test "digests match known vectors and are lowercase hex":
    check digest(hfMD5, "") == "d41d8cd98f00b204e9800998ecf8427e"
    check digest(hfMD5, "abc") == "900150983cd24fb0d6963f7d28e17f72"
    check digest(hfSHA1, "") == "da39a3ee5e6b4b0d3255bfef95601890afd80709"
    check digest(hfSHA256, "") ==
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    check digest(hfSHA256, "abc") ==
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    check digest(hfSHA512, "") ==
      "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce4" &
      "7d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
    check digestRaw(hfSHA256, "abc".toOpenArrayByte(0, 2)).len == 32

  test "compression round-trips in every format":
    let payload = "nim2d ".repeat(64)   # repetitive so it actually shrinks
    for fmt in [compZlib, compGzip, compDeflate]:
      let packed = compress(payload, fmt)
      check packed.len < payload.len
      check decompressString(packed, fmt) == payload

  test "pack lays out bytes by width and endianness":
    check pack("<i", 1) == @[1'u8, 0, 0, 0]
    check pack(">i", 1) == @[0'u8, 0, 0, 1]
    check pack("<h", 258) == @[2'u8, 1]          # 0x0102
    check pack(">h", 258) == @[1'u8, 2]
    check pack("bb", -1, 127) == @[255'u8, 127]

  test "unpack inverts pack including signed values":
    check unpack("<i", pack("<i", 70000)) == @[70000'i64]
    check unpack(">l", pack(">l", -5)) == @[-5'i64]
    check unpack("<hHb", pack("<hHb", -2, 40000, -1)) == @[-2'i64, 40000, -1]
    expect ValueError:
      discard unpack("<i", @[1'u8, 2])   # too short
    expect ValueError:
      discard pack("<i")                 # missing argument
