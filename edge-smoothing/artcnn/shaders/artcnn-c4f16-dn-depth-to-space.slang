#version 450

// Based on ArtCNN_C4F16_DN.glsl.
// Original ArtCNN shaders are MIT licensed by Joao Chrisostomo and Kacper Michajlow.
// ArtCNN project: https://github.com/Artoriuz/ArtCNN/
// See ../LICENSE for the ArtCNN license text.

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 conv2d_6Size;
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
layout(set = 0, binding = 2) uniform sampler2D conv2d_6;

#define V4 vec4
#define M4 mat4
#include "artcnn-common.inc"

void main()
{
    ivec2 output_pixel = artcnn_output_pixel(params.OutputSize.xy);
    ivec2 base = output_pixel >> 1;
    ivec2 phase = output_pixel & ivec2(1);
    vec4 packed = artcnn_fetch4(conv2d_6, params.conv2d_6Size, base);
    float value = packed[phase.y * 2 + phase.x];
    FragColor = vec4(clamp(value, 0.0, 1.0), 0.0, 0.0, 1.0);
}
