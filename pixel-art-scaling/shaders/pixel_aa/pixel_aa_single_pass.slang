#version 450

// See the main shader file for copyright and other information.

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
layout(location = 1) out vec2 trans_lb;
layout(location = 2) out vec2 trans_ub;
layout(location = 3) out vec2 sub_tx_offset;
layout(location = 4) out float trans_slope;

void main() {
    gl_Position = global.MVP * Position;
    tx_coord = TexCoord * param.SourceSize.xy;

    calculate_pixel_aa_params(param.SourceSize.xy * param.OutputSize.zw, param.PIX_AA_SHARP,
                              uint(param.PIX_AA_SUBPX_ORIENTATION), param.Rotation, trans_lb,
                              trans_ub, trans_slope, sub_tx_offset);
}

#pragma stage fragment
layout(location = 0) in vec2 tx_coord;
layout(location = 1) in vec2 trans_lb;
layout(location = 2) in vec2 trans_ub;
layout(location = 3) in vec2 sub_tx_offset;
layout(location = 4) in float trans_slope;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    FragColor.rgb =
        param.PIX_AA_SUBPX < 0.5
            ? pixel_aa_gamma(Source, tx_coord, param.SourceSize.zw, trans_lb, trans_ub, trans_slope)
            : pixel_aa_subpx_gamma(Source, tx_coord, sub_tx_offset, param.SourceSize.zw, trans_lb,
                                   trans_ub, trans_slope);
}
