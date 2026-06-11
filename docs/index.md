# nim2d

nim2d is a small 2D game engine for Nim, in the spirit of love2d. You open a window, set a few callbacks for loading, updating and drawing, and call `play`. The rest is a box of parts: shapes, images, text, canvases, shaders, input, sound, physics, and the plain-Nim modules for random numbers, noise, files and data.

.. image:: assets/hero.png
   :width: 740
   :alt: shapes, a bezier curve and text rendered by nim2d

It runs on macOS, Linux and Windows through SDL3 and its GPU API, drawing on Metal or Vulkan depending on the platform. Every screenshot in these docs was rendered by nim2d itself, by a small tool that draws each scene into a canvas, reads the pixels back and saves a PNG.

The docs come in two parts. The guides are hand-written and walk through how things work, and the API reference is generated from the source so it always matches the code.

- [Getting started](getting-started.html), from `brew install` to a window with a circle in it
- [Drawing](drawing.html), shapes, images, text, particles, canvases and shaders
- [Input and timing](input.html), keyboard, mouse, gamepads and the clock
- [Math](math.html), seeded random, noise, Bezier curves and vectors
- [Data](data.html), encoding, hashing, compression and packing
- [Files](filesystem.html), the save directory and reading what you ship
- [Audio](audio.html), loading and playing sounds
- [System](system.html), clipboard, battery and other platform bits
- [Physics](physics.html), rigid bodies on Box2D
- [Examples](examples.html), the runnable demos in the repository
- [API reference](api/nim2d.html), the main module, with links to every other module under it
- [Symbol index](api/theindex.html), every type and proc in one list
