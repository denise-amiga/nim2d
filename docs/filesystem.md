# Files

Reading and writing files goes through `n2d.fs`, a small virtual filesystem. It knows two places. The save directory is the one writable spot, meant for save games and settings, and it lives in the per-user location the operating system sets aside for your program. The source directory is read-only and is where the program was launched from, which is where the assets you ship live.

Before you can write saves you set an identity, which picks the save directory's folder names. Do this once near the start.

```nim
n2d.fs.setIdentity("mygame")
# or with an organization name as well:
n2d.fs.setIdentity("mystudio", "mygame")
```

`write` and `append` put data in the save directory, creating any missing folders along the way. `read` returns a whole file as a string, and `lines` walks it a line at a time. Reading searches the save directory first, then the source directory, then anything you mounted, so a file you have saved shadows the one you shipped.

```nim
n2d.fs.write("save.txt", "level 3\nscore 1200")
if n2d.fs.exists("save.txt"):
  for line in n2d.fs.lines("save.txt"):
    echo line
```

`mount` adds another directory to search when reading and `unmount` removes it. `getDirectoryItems` lists the names in a directory across every search location with duplicates removed, `createDirectory` makes a folder in the save directory, `remove` deletes a file or an empty folder from it, and `getInfo` reports a name's kind, size and modification time.

Names are always relative and stay inside the sandbox, so a name with a leading slash or a `..` in it is refused rather than reaching outside the save and source directories. `getSaveDirectory` and `getSourceDirectory` tell you where those two places actually are on disk.
