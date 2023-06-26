#version 450

/*
    Pixel AA v1.0 by fishku
    Copyright (C) 2023
    Public domain license (CC0)

    Features:
    - Sharp upscaling with anti-aliasing
    - Subpixel upscaling
    - Sharpness can be controlled
    - Gamma correct blending
    - Integer scales result in pixel-perfect scaling
    - Can use bilinear filtering for max. performance

    Inspired by:
    https://www.shadertoy.com/view/MlB3D3
    by d7samurai
    and:
    https://www.youtube.com/watch?v=d6tp43wZqps
    by t3ssel8r

    With sharpness = 1.0, using gamma-correct blending, and disabling subpixel
    anti-aliasing, results are identical to the "pixellate" shader.

    Changelog:
    v1.0: Initial release.
*/

// clang-format off
#pragma parameter PIX_AA_SETTINGS "=== Pixel AA v1.0 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter PIX_AA_SHARP "Pixel AA sharpening amount" 1.0 1.0 4.0 0.05
#pragma parameter PIX_AA_GAMMA "Enable gamma-correct blending" 1.0 0.0 1.0 1.0
#pragma parameter PIX_AA_SUBPX "Enable subpixel AA" 0.0 0.0 1.0 1.0
#pragma parameter PIX_AA_SUBPX_BGR "Use BGR subpx. instead of RGB" 0.0 0.0 1.0 1.0
// clang-format on

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float PIX_AA_SHARP;
    float PIX_AA_GAMMA;
    float PIX_AA_SUBPX;
    float PIX_AA_SUBPX_BGR;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 pix_coord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    pix_coord = vTexCoord * param.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 pix_coord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Similar to smoothstep, but has a configurable slope at x = 0.5.
// Original smoothstep has a slope of 1.5 at x = 0.5
#define INSTANTIATE_SLOPESTEP(T)                               \
    T slopestep(T edge0, T edge1, T x, float slope) {          \
        x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);    \
        const T s = sign(x - 0.5);                             \
        const T o = (1.0 + s) * 0.5;                           \
        return o - 0.5 * s * pow(2.0 * (o - s * x), T(slope)); \
    }
INSTANTIATE_SLOPESTEP(float)
INSTANTIATE_SLOPESTEP(vec2)

vec3 to_lin(vec3 x) { return pow(x, vec3(2.2)); }

vec3 to_srgb(vec3 x) { return pow(x, vec3(1.0 / 2.2)); }

// Params:
// pix_coord: Coordinate in source pixel coordinates
// px_size_uv: 1 / source resolution
vec3 sample_aa(sampler2D tex, vec2 pix_coord, vec2 px_size_uv,
               bool gamma_correct, float sharpness) {
    const vec2 tx_size = clamp(fwidth(pix_coord), 1.0e-5, 1.0);
    const vec2 tx_coord = pix_coord - 0.5 * tx_size;
    const vec2 tx_coord_i = floor(tx_coord);
    const vec2 tx_offset =
        slopestep(1.0 - tx_size, vec2(1.0), fract(tx_coord), sharpness);
    // With gamma correct blending, we have to do 4 taps and blend manually.
    // Without it, we can make use of a single tap using bilinear interpolation.
    if (gamma_correct) {
        const vec3 samples[] = {
            to_lin(texture(tex, (tx_coord_i + 0.5) * px_size_uv).rgb),
            to_lin(
                texture(tex, (tx_coord_i + vec2(1.5, 0.5)) * px_size_uv).rgb),
            to_lin(
                texture(tex, (tx_coord_i + vec2(0.5, 1.5)) * px_size_uv).rgb),
            to_lin(texture(tex, (tx_coord_i + 1.5) * px_size_uv).rgb)};
        return to_srgb(mix(mix(samples[0], samples[1], tx_offset.x),
                           mix(samples[2], samples[3], tx_offset.x),
                           tx_offset.y));
    } else {
        return texture(tex, (tx_coord_i + 0.5 + tx_offset) * px_size_uv).rgb;
    }
}

void main() {
    if (param.PIX_AA_SUBPX < 0.5) {
        FragColor =
            vec4(sample_aa(Source, pix_coord, param.SourceSize.zw,
                           param.PIX_AA_GAMMA > 0.5, param.PIX_AA_SHARP),
                 1.0);
    } else {
        // Subpixel sampling: Shift the sampling by 1/3rd of an output pixel,
        // assuming that the output size is at monitor resolution.
        for (int i = -1; i < 2; ++i) {
            const vec2 subpix_coord =
                pix_coord +
                vec2((param.PIX_AA_SUBPX_BGR < 0.5 ? i : -i) / 3.0, 0.0) *
                    param.OutputSize.zw * param.SourceSize.xy;
            FragColor[i + 1] =
                sample_aa(Source, subpix_coord, param.SourceSize.zw,
                          param.PIX_AA_GAMMA > 0.5, param.PIX_AA_SHARP)[i + 1];
        }
        FragColor[3] = 1.0;
    }
}
