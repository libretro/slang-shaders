#version 450

/*
    Authentic GBC v1.0 by fishku
    Copyright (C) 2024
    Public domain license (CC0)

    Attempts to render GBC subpixels authentically.

    Reference photos:
    - https://gbcc.dev/technology/subpixels.jpg

    Changelog:
    v1.0: Initial release.
*/

#include "parameters.slang"
#include "shared.slang"

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 tx_coord;
layout(location = 2) out vec2 px_coord;
layout(location = 3) out vec2 tx_to_px;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    tx_coord = TexCoord * param.SourceSize.xy;
    px_coord = TexCoord * param.OutputSize.xy;
    tx_to_px = param.OutputSize.xy * param.SourceSize.zw;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 tx_coord;
layout(location = 2) in vec2 px_coord;
layout(location = 3) in vec2 tx_to_px;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const vec2 subpx_ratio = vec2(0.3, 0.91);
const vec2 notch_ratio = vec2(0.115, 0.166);

float rect_coverage(vec2 px_coord, vec4 rect) {
    vec2 coverage = clamp(rect.zw, px_coord - 0.5, px_coord + 0.5) -
                    clamp(rect.xy, px_coord - 0.5, px_coord + 0.5);
    return coverage.x * coverage.y;
}

float subpx_coverage(vec2 px_coord, vec2 subpx_orig, vec2 subpx_size,
                     vec2 notch_size) {
    return rect_coverage(px_coord, vec4(subpx_orig, subpx_orig + subpx_size)) -
           rect_coverage(
               px_coord,
               vec4(subpx_orig.x, subpx_orig.y + subpx_size.y - notch_size.y,
                    subpx_orig.x + notch_size.x, subpx_orig.y + subpx_size.y));
}

vec3 pixel_color(vec2 px_coord, vec2 px_size, vec2 px_orig) {
    const vec2 subpx_size = subpx_ratio * px_size;
    const vec2 notch_size = notch_ratio * px_size;
    return vec3(subpx_coverage(px_coord,
                               px_orig + vec2(1.0 / 3.0 - subpx_ratio.x,
                                              1.0 - subpx_ratio.y) *
                                             0.5 * px_size,
                               subpx_size, notch_size),
                subpx_coverage(
                    px_coord,
                    px_orig + vec2(1.0 - subpx_ratio.x, 1.0 - subpx_ratio.y) *
                                  0.5 * px_size,
                    subpx_size, notch_size),
                subpx_coverage(px_coord,
                               px_orig + vec2(5.0 / 3.0 - subpx_ratio.x,
                                              1.0 - subpx_ratio.y) *
                                             0.5 * px_size,
                               subpx_size, notch_size));
}

void main() {
    // Figure out 4 nearest texels in source texture
    vec2 tx_coord_i;
    const vec2 tx_coord_f = modf(tx_coord, tx_coord_i);
    const vec2 tx_coord_off = step(vec2(0.5), tx_coord_f) * 2.0 - 1.0;
    const vec2 tx_origins[] = {
        tx_coord_i, tx_coord_i + vec2(tx_coord_off.x, 0.0),
        tx_coord_i + vec2(0.0, tx_coord_off.y), tx_coord_i + tx_coord_off};

    // Sample.
    // Apply square for fast "gamma correction".
    vec3 samples[] = {
        texture(Source, (tx_origins[0] + 0.5) * param.SourceSize.zw).rgb,
        texture(Source, (tx_origins[1] + 0.5) * param.SourceSize.zw).rgb,
        texture(Source, (tx_origins[2] + 0.5) * param.SourceSize.zw).rgb,
        texture(Source, (tx_origins[3] + 0.5) * param.SourceSize.zw).rgb};
    samples[0] *= samples[0];
    samples[1] *= samples[1];
    samples[2] *= samples[2];
    samples[3] *= samples[3];

    const vec3 res =
        samples[0] * pixel_color(px_coord, tx_to_px, tx_origins[0] * tx_to_px) +
        samples[1] * pixel_color(px_coord, tx_to_px, tx_origins[1] * tx_to_px) +
        samples[2] * pixel_color(px_coord, tx_to_px, tx_origins[2] * tx_to_px) +
        samples[3] * pixel_color(px_coord, tx_to_px, tx_origins[3] * tx_to_px);

    // Apply sqrt for fast "gamma correction"
    FragColor = vec4(sqrt(res), 1.0);
}
