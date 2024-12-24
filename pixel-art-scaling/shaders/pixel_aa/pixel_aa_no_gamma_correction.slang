#version 450

// See main shader file for copyright and other information.

#include "parameters.inc"
#include "shared.inc"

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint Rotation;
    float PIX_AA_SHARP;
    float PIX_AA_SUBPX;
    float PIX_AA_SUBPX_ORIENTATION;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 tx_coord;
layout(location = 1) out vec2 tx_per_px;

void main() {
    gl_Position = global.MVP * Position;
    tx_coord = TexCoord * param.SourceSize.xy;
    tx_per_px = param.SourceSize.xy * param.OutputSize.zw;
}

#pragma stage fragment
layout(location = 0) in vec2 tx_coord;
layout(location = 1) in vec2 tx_per_px;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    FragColor.rgb =
        pixel_aa(Source, tx_per_px, param.SourceSize.zw, tx_coord, param.PIX_AA_SHARP,
                 param.PIX_AA_SUBPX > 0.5, uint(param.PIX_AA_SUBPX_ORIENTATION), param.Rotation);
}
