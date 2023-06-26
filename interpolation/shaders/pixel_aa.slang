#version 450

/*
    Pixel AA v1.0 by fishku
    Copyright (C) 2023
    Public domain license (CC0)

    Features:
    - Sharp upscaling with antialiasing
    - Integer scales result in pixel-perfect scaling
    - Sharpness can be controlled
    - Gamma correct blending
    - Can use bilinear filtering for max. performance

    Inspired by:
    https://www.shadertoy.com/view/MlB3D3
    by d7samurai
    and:
    https://www.youtube.com/watch?v=d6tp43wZqps
    by t3ssel8r

    For sharpness = 1.0 and using gamma-correct blending, results are
    practically identical to the "pixellate" shader.

    Changelog:
    v1.0: Initial release.
*/

// clang-format off
#pragma parameter PIX_AA_SETTINGS "=== Pixel AA v1.0 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter PIX_AA_SHARP "Pixel AA sharpening" 1.0 1.0 4.0 0.05
#pragma parameter PIX_AA_GAMMA "Gamma-correct blending" 1.0 0.0 1.0 1.0
// clang-format on

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float PIX_AA_SHARP;
    float PIX_AA_GAMMA;
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
#define INSTANTIATE_SLOPESTEP(T)                               \
    T slopestep(T edge0, T edge1, T x, float slope) {          \
        x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);    \
        const T s = sign(x - 0.5);                             \
        const T o = (1.0 + s) * 0.5;                           \
        return o - 0.5 * s * pow(2.0 * (o - s * x), T(slope)); \
    }
INSTANTIATE_SLOPESTEP(float)
INSTANTIATE_SLOPESTEP(vec2)

vec2 get_texel_size(vec2 pix_coord) {
    return clamp(fwidth(pix_coord), 1.0e-5, 1.0);
}

vec2 get_texel_coord(vec2 pix_coord, vec2 texel_size) {
    return pix_coord - 0.5 * texel_size;
}

vec2 get_texel_offset(vec2 texel_size, vec2 texel_coord, float sharpness) {
    return slopestep(1.0 - texel_size, vec2(1.0), fract(texel_coord),
                     sharpness);
}

vec3 to_lin(vec3 x) { return pow(x, vec3(2.2)); }

vec3 to_srgb(vec3 x) { return pow(x, vec3(1.0 / 2.2)); }

void main() {
    const vec2 tx_size = get_texel_size(pix_coord);
    const vec2 tx_coord = get_texel_coord(pix_coord, tx_size);
    const vec2 tx_coord_i = floor(tx_coord);
    const vec2 tx_offset =
        get_texel_offset(tx_size, tx_coord, param.PIX_AA_SHARP);
    // With gamma correct blending, we have to do 4 taps.
    // Without it, we can get away with a single tap using bilinear
    // interpolation.
    if (param.PIX_AA_GAMMA > 0.5) {
        const vec3 samples[] = {
            to_lin(
                texture(Source, (tx_coord_i + 0.5) * param.SourceSize.zw).rgb),
            to_lin(texture(Source,
                           (tx_coord_i + vec2(1.5, 0.5)) * param.SourceSize.zw)
                       .rgb),
            to_lin(texture(Source,
                           (tx_coord_i + vec2(0.5, 1.5)) * param.SourceSize.zw)
                       .rgb),
            to_lin(
                texture(Source, (tx_coord_i + 1.5) * param.SourceSize.zw).rgb)};
        FragColor = vec4(
            to_srgb(mix(mix(samples[0], samples[1], tx_offset.x),
                        mix(samples[2], samples[3], tx_offset.x), tx_offset.y)),
            1.0);
    } else {
        FragColor = vec4(texture(Source, (tx_coord_i + 0.5 + tx_offset) *
                                             param.SourceSize.zw)
                             .rgb,
                         1.0);
    }
}
