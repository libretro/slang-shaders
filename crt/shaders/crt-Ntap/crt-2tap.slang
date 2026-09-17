#version 450

/*
    crt-2tap v1.0 by fishku
    Copyright (C) 2023-2026
    Public domain license (CC0)

    Lightweight dynamic scanline shader with exact vertical box filtering.

    Horizontal interpolation uses two neighboring texels from each source row
    through a single bilinear tap. A normalized smooth-sign function transforms
    the interpolation coordinate. Sampled colors are squared before vertical
    filtering and square-root encoded afterwards to approximate linear-light
    blending without an extra pass.

    Each output pixel is treated as a box in source-texel space. The two rows
    surrounding its center are sampled separately. Each row's color and beam
    pattern are extended periodically through the half-space on its side of
    their shared boundary, then integrated analytically over the box.
*/

// clang-format off
#pragma parameter CRT2TAP_SETTINGS "=== CRT-2tap v1.0 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter MIN_THICK "Scanline thickness of dark pixels" 0.1 0.0 1.2 0.05
#pragma parameter MAX_THICK "Scanline thickness of bright pixels" 0.95 0.0 1.2 0.05
#pragma parameter H_SMOOTH "Horizontal smoothing" 0.8 0.0 1.0 0.05
#pragma parameter V_SMOOTH "Vertical smoothing" 1.0 0.5 4.0 0.05
#pragma parameter SUBPX_POS "Scanline subpixel position" 0.31 -0.5 0.5 0.01
#pragma parameter THICK_FALLOFF "Reduction / increase of thinner scanlines" 0.45 0.2 2.0 0.05
// clang-format on

#include "shared.inc"

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

void main() {
    const float sample_x = get_sample_x(vSrcCoord.x);

    const float src_y = vSrcCoord.y;
    const float row0 = floor(src_y - 0.5);
    const float row1 = row0 + 1.0;
    const float row0_center = row0 + 0.5;
    const float sample_y0 = row0_center * param.OriginalSize.w;
    const float sample_y1 = sample_y0 + param.OriginalSize.w;

    const vec3 signal0 = texture(Source, vec2(sample_x, sample_y0)).rgb;
    const vec3 signal1 = texture(Source, vec2(sample_x, sample_y1)).rgb;
    const vec3 linear0 = signal0 * signal0;
    const vec3 linear1 = signal1 * signal1;

    const float filter_height = param.OriginalSize.y * param.OutputSize.w * param.V_SMOOTH;
    const float inv_filter_height = 1.0 / filter_height;
    const float pixel_lb = src_y - 0.5 * filter_height;
    const float pixel_ub = src_y + 0.5 * filter_height;

    const vec3 width0 = get_beam_width(signal0);
    const vec3 width1 = get_beam_width(signal1);
    const float boundary = row0_center + 0.5;
    const float split = clamp(boundary, pixel_lb, pixel_ub);
    const vec3 area0 = get_beam_prefix(split, width0) - get_beam_prefix(pixel_lb, width0);
    const vec3 area1 = get_beam_prefix(pixel_ub, width1) - get_beam_prefix(split, width1);

    FragColor.rgb = sqrt((linear0 * area0 + linear1 * area1) * inv_filter_height);
}
