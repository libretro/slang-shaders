#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    float YIQ;
} params;

#pragma format R16G16B16A16_SFLOAT

#include "parameters_common.inc"
#include "parameters_sampled.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(binding = 1) uniform sampler2D Source;

#define GAMMA_YIQ_MAT mat3x3(0.30, 0.599, 0.213, 0.59, -0.2773, -0.5251, 0.11, -0.3217, 0.3121)

vec3 gamma_to_yiq(vec3 rgb) {
    return GAMMA_YIQ_MAT * rgb;
}

void main() {
    ivec2 pix_loc = ivec2(int(floor(vTexCoord.x * params.SourceSize.x)), int(floor(vTexCoord.y * params.SourceSize.y)));
    vec3 rgb = texelFetch(Source, pix_loc, 0).rgb;

    // We assume the input is in native CRT gamma, and convert to YIQ
    // if necessary.
    if (params.YIQ > 0.5) {
        rgb = gamma_to_yiq(rgb);
    }

    FragColor.rgb = rgb;
}
