#version 450

/*
    Pixel AA v1.1 by fishku
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

    With sharpness = 1.0, using the same gamma-correct blending, and disabling
    subpixel anti-aliasing, results are identical to the "pixellate" shader.

    Changelog:
    v1.1: Better subpixel sampling.
    v1.0: Initial release.
*/

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

#include "shared.slang"

void main() {
    if (param.PIX_AA_SUBPX < 0.5) {
        FragColor = vec4(
            sample_aa(Source, param.SourceSize, param.OutputSize, pix_coord,
                      param.PIX_AA_GAMMA > 0.5, param.PIX_AA_SHARP),
            1.0);
    } else {
        // Subpixel sampling: Shift the sampling by 1/3rd of an output pixel,
        // assuming that the output size is at monitor resolution.
        for (int i = -1; i < 2; ++i) {
            const vec2 subpix_offset =
                vec2((param.PIX_AA_SUBPX_BGR < 0.5 ? i : -i) / 3.0, 0.0);
            const vec2 subpix_coord = pix_coord + subpix_offset *
                                                      param.OutputSize.zw *
                                                      param.SourceSize.xy;
            FragColor[i + 1] = sample_aa(
                Source, param.SourceSize, param.OutputSize, subpix_coord,
                param.PIX_AA_GAMMA > 0.5, param.PIX_AA_SHARP)[i + 1];
        }
        FragColor[3] = 1.0;
    }
}
