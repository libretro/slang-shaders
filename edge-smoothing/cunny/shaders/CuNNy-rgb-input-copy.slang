#version 450

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "CuNNy-rgb-common.inc"

void main()
{
    ivec2 pixel = cunny_output_pixel(params.OutputSize.xy);
    FragColor = texelFetch(Source, cunny_clamp_coord(pixel, params.SourceSize.xy), 0);
}
