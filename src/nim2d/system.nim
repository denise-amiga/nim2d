## Small platform queries and actions.
##
## The OS name and processor count, clipboard read and write, opening a URL in
## the browser, and battery and power info. These are thin wrappers over SDL3.

import backend/sdl

proc getOS*(): string =
  ## The name of the operating system, like "macOS", "Linux" or "Windows".
  $SDL_GetPlatform()

proc getProcessorCount*(): int =
  ## The number of logical CPU cores.
  SDL_GetNumLogicalCPUCores().int

proc getClipboardText*(): string =
  ## The current clipboard text, or an empty string if there is none.
  let p = SDL_GetClipboardText()
  if p == nil:
    return ""
  result = $p
  SDL_free(cast[pointer](p)) # SDL allocated this string, free it with SDL_free

proc setClipboardText*(text: string) =
  ## Put text on the clipboard.
  discard SDL_SetClipboardText(text.cstring)

proc hasClipboardText*(): bool =
  ## Whether the clipboard holds any text.
  SDL_HasClipboardText()

proc openURL*(url: string): bool =
  ## Open a URL in the default browser. Returns false on failure.
  SDL_OpenURL(url.cstring)

proc getPowerInfo*(): tuple[state: string, percent: int, seconds: int] =
  ## Battery state, charge percent and seconds of charge left. The state is one
  ## of "battery", "charging", "charged", "nobattery" or "unknown", and percent
  ## and seconds are -1 when they cannot be determined.
  var secs, pct: cint = -1
  let st = SDL_GetPowerInfo(addr secs, addr pct)
  let state =
    case st
    of SDL_POWERSTATE_ON_BATTERY: "battery"
    of SDL_POWERSTATE_CHARGING: "charging"
    of SDL_POWERSTATE_CHARGED: "charged"
    of SDL_POWERSTATE_NO_BATTERY: "nobattery"
    else: "unknown"
  (state, pct.int, secs.int)
