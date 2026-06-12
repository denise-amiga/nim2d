# System

A handful of platform bits, thin wrappers over SDL3. `getOS` returns the operating system name, like "macOS", "Linux" or "Windows", and `getProcessorCount` returns the number of logical CPU cores. Controls for the window itself, like fullscreen, resizing and message boxes, live on the [input page](input.html).

The clipboard is `getClipboardText`, `setClipboardText` and `hasClipboardText`, and `openURL` opens a link in the default browser.

`getPowerInfo` reports the battery as a tuple: the state, which is one of "battery", "charging", "charged", "nobattery" or "unknown", the charge percent, and the seconds of charge left, with -1 for the last two when they cannot be told.

```nim
echo "running on ", getOS(), " with ", getProcessorCount(), " cores"
setClipboardText("copied from the game")
let power = getPowerInfo()
if power.state == "battery" and power.percent < 20:
  warnLowBattery()
```

## Threads

For work that should not stall a frame, like loading, decoding or generation, the thread module runs it off to the side. A `Thread2d` runs a top-level proc marked `{.thread.}`, and a typed `Channel2d` passes messages between threads, with each message copied as it crosses so nothing is shared by accident. SDL, the GPU and all drawing belong to the main thread, so a worker computes and sends, and the main loop receives and draws.

```nim
var progress = newChannel[int]()

proc worker() {.thread.} =
  for step in 1 .. 100:
    crunch(step)
    progress.send(step)

n2d.load = proc(nim2d: Nim2d) =
  discard newThread(worker)

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let (got, step) = progress.tryReceive()
  if got: percent = step
```

The channel is a module-level global because a thread proc carries no captured state, so both sides have to be able to name it. `receive` blocks until a message arrives, `tryReceive` returns immediately with a flag, `peek` counts what is waiting, and `join` waits for a thread to finish. `close` frees a channel once the threads using it are done. The threads example runs a prime count this way while a spinner proves the main loop never blocks.
