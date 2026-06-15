import std/unittest
import std/os
import std/options
import std/sequtils
import nim2d/types
import nim2d/filesystem

# These run headless. We point a Filesystem at temp directories directly instead
# of calling setIdentity, which would write under the real user preferences path.

suite "filesystem (temp-dir round trip)":
  test "write, read, append and lines":
    let save = getTempDir() / "nim2d_fs_a"
    removeDir(save)
    createDir(save)
    try:
      let fs = Filesystem(saveDir: save, sourceDir: "", mounts: @[])
      fs.write("hello.txt", "hi")
      check fs.read("hello.txt") == "hi"
      fs.append("hello.txt", "\nthere")
      check fs.read("hello.txt") == "hi\nthere"
      var got: seq[string]
      for line in fs.lines("hello.txt"):
        got.add line
      check got == @["hi", "there"]
      check fs.exists("hello.txt")
      check not fs.exists("nope.txt")
    finally:
      removeDir(save)

  test "directories, byte writes, getInfo and remove":
    let save = getTempDir() / "nim2d_fs_b"
    removeDir(save)
    createDir(save)
    try:
      let fs = Filesystem(saveDir: save, mounts: @[])
      fs.createDirectory("sub")
      fs.write("sub/data.bin", @[1'u8, 2, 3, 4])
      check fs.read("sub/data.bin").len == 4
      check "sub" in fs.getDirectoryItems("")
      let info = fs.getInfo("sub/data.bin")
      check info.isSome
      check info.get.kind == fikFile
      check info.get.size == 4
      check info.get.modtime > 0
      check fs.remove("sub/data.bin")
      check not fs.exists("sub/data.bin")
      check fs.remove("sub") # now empty
      check not fs.exists("sub")
    finally:
      removeDir(save)

  test "reads fall through to source and mounts, listing deduplicates":
    let save = getTempDir() / "nim2d_fs_c_save"
    let src = getTempDir() / "nim2d_fs_c_src"
    let mnt = getTempDir() / "nim2d_fs_c_mnt"
    for d in [save, src, mnt]:
      removeDir(d)
      createDir(d)
    try:
      writeFile(src / "shared.txt", "from-source")
      writeFile(mnt / "extra.txt", "from-mount")
      writeFile(save / "shared.txt", "from-save")
      let fs = Filesystem(saveDir: save, sourceDir: src, mounts: @[])
      fs.mount(mnt)
      check fs.read("shared.txt") == "from-save" # save directory wins
      check fs.read("extra.txt") == "from-mount"
      let items = fs.getDirectoryItems("")
      check items.count("shared.txt") == 1 # listed once across roots
      check "extra.txt" in items
      check fs.unmount(mnt)
      check not fs.exists("extra.txt")
    finally:
      for d in [save, src, mnt]:
        removeDir(d)

  test "sandbox rejects names that escape the save directory":
    let save = getTempDir() / "nim2d_fs_d"
    removeDir(save)
    createDir(save)
    try:
      let fs = Filesystem(saveDir: save, mounts: @[])
      expect IOError:
        fs.write("../escape.txt", "no")
      expect IOError:
        fs.write("/abs.txt", "no")
      check not fs.exists("../escape.txt")
    finally:
      removeDir(save)
