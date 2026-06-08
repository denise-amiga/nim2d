# System

A handful of platform bits, thin wrappers over SDL3. `getOS` returns the operating system name, like "macOS", "Linux" or "Windows", and `getProcessorCount` returns the number of logical CPU cores.

The clipboard is `getClipboardText`, `setClipboardText` and `hasClipboardText`, and `openURL` opens a link in the default browser.

`getPowerInfo` reports the battery as a tuple: the state, which is one of "battery", "charging", "charged", "nobattery" or "unknown", the charge percent, and the seconds of charge left, with -1 for the last two when they cannot be told.

```nim
echo "running on ", getOS(), " with ", getProcessorCount(), " cores"
n2d.setClipboardText("copied from the game")
let power = getPowerInfo()
if power.state == "battery" and power.percent < 20:
  warnLowBattery()
```
