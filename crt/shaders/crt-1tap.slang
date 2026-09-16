#version 450

/*
    crt-1tap v1.4 by fishku
    Copyright (C) 2023-2026
    Public domain license (CC0)

    Extremely fast and lightweight dynamic scanline shader.
    Contrasty and sharp output. Easy to configure.
    Can be combined with other shaders.

    How it works: Uses a single texture "tap" per pixel, hence the name.
    Exploits bilinear interpolation plus local coordinate distortion to shape
    horizontal interpolation. A normalized smooth-sign function controls its
    transition slope. The sampled color defines a sharp periodic beam whose
    coverage is integrated analytically over each output pixel's vertical
    footprint. This provides stable scanline anti-aliasing at arbitrary scales.

    Changelog:
    v1.4: Add periodic box-filtered scanlines; Improve composability and
          horizontal interpolation.
    v1.3: Fix horizontal sampling artifact at the left edge.
    v1.2: Better scanline sharpness; Minor cleanups.
    v1.1: Update license; Better defaults; Don't compute alpha.
    v1.0: Initial release.
*/

// clang-format off
#pragma parameter CRT1TAP_SETTINGS "=== CRT-1tap v1.4 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter MIN_THICK "Scanline thickness of dark pixels" 0.1 0.0 1.0 0.05
#pragma parameter MAX_THICK "Scanline thickness of bright pixels" 0.95 0.0 1.0 0.05
#pragma parameter H_SMOOTH "Horizontal smoothing" 0.8 0.0 1.0 0.05
#pragma parameter V_SMOOTH "Vertical smoothing" 1.0 0.5 4.0 0.05
#pragma parameter SUBPX_POS "Scanline subpixel position" 0.0 -0.5 0.5 0.01
#pragma parameter THICK_FALLOFF "Reduction / increase of thinner scanlines" 0.45 0.2 2.0 0.05
// clang-format on

layout(push_constant) uniform Push {
    vec4 OutputSize;
    vec4 OriginalSize;
    float MIN_THICK;
    float MAX_THICK;
    float H_SMOOTH;
    float V_SMOOTH;
    float SUBPX_POS;
    float THICK_FALLOFF;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
}
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vSrcCoord;

void main() {
    gl_Position = global.MVP * Position;
    vSrcCoord = TexCoord * param.OriginalSize.xy - vec2(0.5, param.SUBPX_POS);
}

#pragma stage fragment
layout(location = 0) in vec2 vSrcCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;
layout(set = 0, binding = 2) uniform sampler2D Original;

vec3 get_beam_width(vec3 signal) {
    const vec3 shaped_signal = pow(clamp(signal, 0.0, 1.0), param.THICK_FALLOFF.xxx);
    return min(mix(param.MIN_THICK.xxx, param.MAX_THICK.xxx, shaped_signal), vec3(1.0));
}

vec3 get_beam_prefix(float y, vec3 width) {
    const float cell = floor(y);
    const float phase = y - cell;
    return cell * width + clamp(vec3(phase - 0.5) + 0.5 * width, vec3(0.0), width);
}

void main() {
    const float src_x = vSrcCoord.x;
    const float src_x_int = floor(src_x);
    const float src_x_fract = src_x - src_x_int;

    // Symmetric sigmoid with a configurable slope at the midpoint.
    const float h_slope = mix(6.0, 1.0, param.H_SMOOTH);
    const float x = 2.0 * src_x_fract - 1.0;
    const float src_x_offset =
        0.5 + 0.5 * h_slope * x * inversesqrt(1.0 + (h_slope * h_slope - 1.0) * x * x);
    const float sample_x = (src_x_int + src_x_offset + 0.5) * param.OriginalSize.z;

    const float src_y = vSrcCoord.y;
    const float row_center = floor(src_y) + 0.5;
    const vec3 signal = texture(Source, vec2(sample_x, row_center * param.OriginalSize.w)).rgb;

    const vec3 width = get_beam_width(signal);
    const float filter_height = param.OriginalSize.y * param.OutputSize.w * param.V_SMOOTH;
    const float half_filter_height = 0.5 * filter_height;
    const vec3 area = get_beam_prefix(src_y + half_filter_height, width) -
                      get_beam_prefix(src_y - half_filter_height, width);

    FragColor.rgb = signal * area * (1.0 / filter_height);
}
