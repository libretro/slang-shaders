#version 450

/*
    crt-2tap v1.0 by fishku
    Copyright (C) 2023-2026
    Public domain license (CC0)

    Lightweight dynamic scanline shader with exact vertical box filtering.

    Horizontal interpolation uses two neighboring texels from each source row
    through a single bilinear tap. The interpolation coordinate is transformed
    by a configurable power curve.

    Each output pixel is treated as a box in source-texel space. The two source
    rows that can intersect this box are sampled separately, and their sharp
    beam coverage is calculated analytically. This gives exact vertical area
    coverage for arbitrary source colors when vertically upscaling.
*/

// clang-format off
#pragma parameter CRT2TAP_SETTINGS "=== CRT-2tap v1.0 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter MIN_THICK "Scanline thickness of dark pixels" 0.1 0.0 1.2 0.05
#pragma parameter MAX_THICK "Scanline thickness of bright pixels" 0.95 0.0 1.2 0.05
#pragma parameter H_SHARP "Horizontal transition sharpness" 0.2 0.0 1.0 0.05
#pragma parameter AA_STRENGTH "Vertical AA strength" 1.0 0.5 4.0 0.05
#pragma parameter SUBPX_POS "Scanline subpixel position" 0.0 -0.5 0.5 0.01
#pragma parameter THICK_FALLOFF "Reduction / increase of thinner scanlines" 0.45 0.2 2.0 0.05
// clang-format on

layout(push_constant) uniform Push {
    vec4 OutputSize;
    vec4 SourceSize;
    float MIN_THICK;
    float MAX_THICK;
    float H_SHARP;
    float AA_STRENGTH;
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
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;
layout(set = 0, binding = 2) uniform sampler2D Original;

vec3 get_beam_radius(vec3 signal) {
    const vec3 thickness =
        mix(param.MIN_THICK.xxx, param.MAX_THICK.xxx, clamp(signal, 0.0, 1.0));
    return 0.5 * pow(thickness, param.THICK_FALLOFF.xxx);
}

vec3 get_beam_coverage(float pixel_lb, float pixel_ub, float row_center, vec3 radius,
                       float inv_pixel_height) {
    const vec3 beam_lb = vec3(row_center) - radius;
    const vec3 beam_ub = vec3(row_center) + radius;
    const vec3 overlap =
        max(min(vec3(pixel_ub), beam_ub) - max(vec3(pixel_lb), beam_lb), vec3(0.0));
    return overlap * inv_pixel_height;
}

void main() {
    const float src_x = vTexCoord.x * param.SourceSize.x - 0.5;
    const float src_x_int = floor(src_x);
    const float src_x_fract = src_x - src_x_int;

    // Symmetric power curve with a configurable slope at the midpoint.
    const float s = sign(src_x_fract - 0.5);
    const float o = 0.5 * (1.0 + s);
    const float h_slope = mix(1.0, 6.0, param.H_SHARP);
    const float src_x_offset =
        o - 0.5 * s * pow(2.0 * (o - s * src_x_fract), h_slope);
    const float sample_x = (src_x_int + src_x_offset + 0.5) * param.SourceSize.z;

    const float src_y = vTexCoord.y * param.SourceSize.y - param.SUBPX_POS;
    const float row0 = floor(src_y - 0.5);
    const float row1 = row0 + 1.0;
    const float row0_center = row0 + 0.5;
    const float row1_center = row1 + 0.5;

    const vec3 signal0 =
        texture(Source, vec2(sample_x, row0_center * param.SourceSize.w)).rgb;
    const vec3 signal1 =
        texture(Source, vec2(sample_x, row1_center * param.SourceSize.w)).rgb;

    const float filter_height =
        param.SourceSize.y * param.OutputSize.w * param.AA_STRENGTH;
    const float inv_filter_height =
        param.OutputSize.y * param.SourceSize.w / param.AA_STRENGTH;
    const float pixel_lb = src_y - 0.5 * filter_height;
    const float pixel_ub = src_y + 0.5 * filter_height;

    vec3 coverage0 =
        get_beam_coverage(pixel_lb, pixel_ub, row0_center, get_beam_radius(signal0),
                          inv_filter_height);
    vec3 coverage1 =
        get_beam_coverage(pixel_lb, pixel_ub, row1_center, get_beam_radius(signal1),
                          inv_filter_height);

    // Rows outside the source image represent black rather than clamped edge texels.
    coverage0 *= step(0.0, row0) * step(row0, param.SourceSize.y - 1.0);
    coverage1 *= step(0.0, row1) * step(row1, param.SourceSize.y - 1.0);

    FragColor.rgb = max(signal0 * coverage0, signal1 * coverage1);
}
