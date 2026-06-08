## A fragment shader running over a fullscreen rectangle: an animated plasma.
## ESC quits. (Metal only for now.)

import std/os
import nim2d

const
  W = 800
  H = 600

let n2d = newNim2d("nim2d - shader", 140, 90, W.cint, H.cint, (0'u8, 0'u8, 0'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
n2d.setFont(font)

# The uniform u holds time in x and the resolution in y, z.
const plasmaFrag = """
fragment float4 frag(VSOutput in [[stage_in]],
                     texture2d<float> tex [[texture(0)]],
                     sampler smp [[sampler(0)]],
                     constant float4& u [[buffer(0)]]) {
  float t = u.x;
  float2 res = float2(u.y, u.z);
  float2 p = in.position.xy / res * 6.0;
  float v = sin(p.x + t) + sin(p.y + t) + sin((p.x + p.y) + t) + sin(length(p) + t);
  float3 col = 0.5 + 0.5 * cos(t + v + float3(0.0, 2.0, 4.0));
  return float4(col, 1.0) * in.color;
}
"""

let plasma = n2d.newShader(plasmaFrag, uniformFloats = 4)
var t = 0.0

n2d.keydown = proc(nim2d: Nim2d, sc: SDL_Scancode) =
  if sc == SDL_SCANCODE_ESCAPE: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt

n2d.draw = proc(nim2d: Nim2d) =
  plasma.send([t.float32, W.float32, H.float32, 0'f32])
  nim2d.setShader(plasma)
  nim2d.setColor(255, 255, 255)
  nim2d.rectangle(0, 0, W.float, H.float, true)
  nim2d.setShader()

  nim2d.setColor(240, 240, 250)
  nim2d.print("a fragment shader over a fullscreen rectangle", 16, 14)

n2d.play()
