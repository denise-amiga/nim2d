#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct Uniforms
{
    float4x4 mvp;
};

struct main0_out
{
    float2 vUV [[user(locn0)]];
    float4 vColor [[user(locn1)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float2 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
    float4 color [[attribute(2)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant Uniforms& u [[buffer(0)]])
{
    main0_out out = {};
    out.gl_Position = u.mvp * float4(in.position, 0.0, 1.0);
    out.vUV = in.uv;
    out.vColor = in.color;
    return out;
}

