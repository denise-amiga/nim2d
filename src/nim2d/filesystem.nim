## Reading and writing files through a small virtual filesystem.
##
## A `Filesystem` knows two places. The save directory is writable and is where
## `write`, `append`, `createDirectory` and `remove` act; you pick it once with
## `setIdentity`, which uses the platform's per-user preferences path. The
## source directory is read-only and is where the program was launched from. You
## can add more read directories with `mount`. Reading searches the save
## directory first, then the source directory, then the mounts.
##
## Names are relative and stay inside the sandbox, so a name with a leading slash
## or a `..` part is rejected rather than reaching outside the chosen
## directories. This builds on std/os and the platform path helpers rather than
## SDL's asynchronous Storage API, which buys nothing extra on desktop.

import std/os
import std/strutils
import std/sets
import std/options
import std/times
import types
import backend/sdl

type
  FileItemKind* = enum
    ## What a name points at. `fikOther` covers symlinks to non-files, devices
    ## and anything that is neither a plain file nor a directory.
    fikFile, fikDirectory, fikOther

  FileInfo2d* = object
    ## What `getInfo` reports about a name.
    kind*: FileItemKind
    size*: int64          ## size in bytes (0 for directories)
    modtime*: int64       ## last modification time, Unix seconds

# --- helpers ---------------------------------------------------------------

proc validRelative(name: string): bool =
  ## A name is usable only if it is relative and never steps out of the sandbox.
  if name.len == 0: return false
  if isAbsolute(name): return false
  for part in name.split({'/', '\\'}):
    if part == "..": return false
  true

proc readRoots(fs: Filesystem): seq[string] =
  result = @[]
  if fs.saveDir.len > 0: result.add fs.saveDir
  if fs.sourceDir.len > 0: result.add fs.sourceDir
  for m in fs.mounts: result.add m

proc resolveRead(fs: Filesystem, name: string): string =
  ## The first existing path for `name` across the search roots, or "".
  if not validRelative(name): return ""
  for root in fs.readRoots():
    let p = root / name
    if fileExists(p) or dirExists(p): return p
  ""

proc saveWritePath(fs: Filesystem, name: string): string =
  ## Validate `name`, make sure its parent directory exists, and return the full
  ## path under the save directory.
  if fs.saveDir.len == 0:
    raise newException(IOError, "no save directory set; call setIdentity first")
  if not validRelative(name):
    raise newException(IOError, "invalid file name '" & name & "'")
  result = fs.saveDir / name
  let parent = result.parentDir
  if parent.len > 0: createDir(parent)

# --- construction / identity -----------------------------------------------

proc newFilesystem*(): Filesystem =
  ## Create a filesystem with the source directory set to the program's base
  ## path and no save identity yet.
  result = Filesystem(mounts: @[])
  let bp = SDL_GetBasePath()   # SDL owns this string, do not free it
  if bp != nil:
    result.sourceDir = $bp
  else:
    result.sourceDir = getCurrentDir()

proc setIdentity*(fs: Filesystem, org, app: string) =
  ## Set the org and app folder names used for the save directory, and create
  ## it. Call once before reading or writing saves.
  let p = SDL_GetPrefPath(org.cstring, app.cstring)
  if p == nil:
    raise newException(IOError, "could not open save directory: " & $SDL_GetError())
  fs.saveDir = $p
  SDL_free(cast[pointer](p))   # SDL allocated this string, free it with SDL_free
  fs.identitySet = true

proc setIdentity*(fs: Filesystem, app: string) =
  ## Set just the app folder name for the save directory, with an empty org.
  fs.setIdentity("", app)

proc getSaveDirectory*(fs: Filesystem): string =
  ## The absolute path of the writable save directory, or "" if no identity has
  ## been set.
  fs.saveDir

proc getSourceDirectory*(fs: Filesystem): string =
  ## The absolute path of the read-only source directory.
  fs.sourceDir

# --- mounts ----------------------------------------------------------------

proc mount*(fs: Filesystem, path: string) =
  ## Add a read directory to search when reading. Mounts are searched after the
  ## save and source directories, in the order they were added.
  if path notin fs.mounts:
    fs.mounts.add path

proc unmount*(fs: Filesystem, path: string): bool =
  ## Remove a previously mounted read directory. Returns true if it was mounted.
  let i = fs.mounts.find(path)
  if i >= 0:
    fs.mounts.delete(i)
    return true
  false

# --- reading ---------------------------------------------------------------

proc read*(fs: Filesystem, name: string): string =
  ## Read a whole file as a string, searching the save directory, then the
  ## source directory and mounts. Raises IOError if not found.
  let path = fs.resolveRead(name)
  if path.len == 0:
    raise newException(IOError, "could not read '" & name & "': not found")
  readFile(path)

iterator lines*(fs: Filesystem, name: string): string =
  ## Yield the file's lines one at a time without the trailing newline.
  let path = fs.resolveRead(name)
  if path.len == 0:
    raise newException(IOError, "could not read '" & name & "': not found")
  for line in system.lines(path):
    yield line

proc exists*(fs: Filesystem, name: string): bool =
  ## True if a file or directory by that name exists in any search root.
  fs.resolveRead(name).len > 0

proc getInfo*(fs: Filesystem, name: string): Option[FileInfo2d] =
  ## Type, size and modification time for a name if it exists, or none.
  let path = fs.resolveRead(name)
  if path.len == 0: return none(FileInfo2d)
  let info = getFileInfo(path)
  var kind = fikOther
  case info.kind
  of pcFile, pcLinkToFile: kind = fikFile
  of pcDir, pcLinkToDir: kind = fikDirectory
  some(FileInfo2d(kind: kind, size: info.size.int64,
                  modtime: info.lastWriteTime.toUnix))

proc getDirectoryItems*(fs: Filesystem, dir: string): seq[string] =
  ## The names (not full paths) of entries in a directory, merged across the
  ## search roots with duplicates removed. An empty dir lists the top-level
  ## entries of each search root.
  result = @[]
  if dir.len > 0 and not validRelative(dir): return
  var seen = initHashSet[string]()
  for root in fs.readRoots():
    let base = if dir.len == 0: root else: root / dir
    if dirExists(base):
      for _, path in walkDir(base, relative = true):
        if path notin seen:
          seen.incl path
          result.add path

# --- writing (save directory only) -----------------------------------------

proc write*(fs: Filesystem, name: string, data: string) =
  ## Write data to a file in the save directory, replacing it if it exists and
  ## creating parent directories as needed.
  writeFile(fs.saveWritePath(name), data)

proc write*(fs: Filesystem, name: string, data: openArray[byte]) =
  ## Write raw bytes to a file in the save directory, replacing it if it exists.
  let f = open(fs.saveWritePath(name), fmWrite)
  defer: f.close()
  if data.len > 0:
    discard f.writeBuffer(unsafeAddr data[0], data.len)

proc append*(fs: Filesystem, name: string, data: string) =
  ## Append data to the end of a file in the save directory, creating it if it
  ## does not exist.
  let f = open(fs.saveWritePath(name), fmAppend)
  defer: f.close()
  f.write(data)

proc createDirectory*(fs: Filesystem, dir: string) =
  ## Create a directory and any missing parents inside the save directory.
  if fs.saveDir.len == 0:
    raise newException(IOError, "no save directory set; call setIdentity first")
  if not validRelative(dir):
    raise newException(IOError, "invalid directory name '" & dir & "'")
  createDir(fs.saveDir / dir)

proc remove*(fs: Filesystem, name: string): bool =
  ## Delete a file or empty directory from the save directory. Returns true if
  ## something was removed.
  if fs.saveDir.len == 0 or not validRelative(name): return false
  let path = fs.saveDir / name
  if fileExists(path):
    removeFile(path)
    return true
  if dirExists(path):
    for _ in walkDir(path): return false   # not empty, leave it
    removeDir(path)
    return true
  false
