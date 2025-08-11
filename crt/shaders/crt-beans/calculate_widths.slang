#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    float MaxSpotSize;
    float MinSpotSize;
} params;

#pragma format R16G16B16A16_SFLOAT

#include "parameters_common.inc"

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

void main() {
    ivec2 pix_loc = ivec2(floor(vTexCoord * params.SourceSize.xy));
    vec3 sample_value = texelFetch(Source, pix_loc, 0).rgb;
    vec3 width_rcp =  1.0 / (params.MinSpotSize * params.MaxSpotSize - sqrt(sample_value) * (params.MinSpotSize * params.MaxSpotSize - params.MaxSpotSize));
    FragColor.rgb = width_rcp;
}
