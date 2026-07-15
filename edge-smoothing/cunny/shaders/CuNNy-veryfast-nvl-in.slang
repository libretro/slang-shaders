#version 450

#pragma format R8G8B8A8_UNORM

layout(push_constant) uniform Push
{
    vec4 cunny_veryfast_nvl_inputSize;
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
layout(set = 0, binding = 2) uniform sampler2D cunny_veryfast_nvl_input;

#define V4 vec4
#define V3 vec3
#define MF float
#include "CuNNy-rgb-common.inc"
#define mad(a, b, c) ((a) * (b) + (c))
#define MulAdd(v, m, acc) (((m) * (v)) + (acc))

#define L0(x, y) cunny_fetch_luma(cunny_veryfast_nvl_input, params.cunny_veryfast_nvl_inputSize, pos, ivec2(int(x), int(y)))

void main()
{
    ivec2 output_pixel = cunny_output_pixel(params.OutputSize.xy);
    const ivec2 macro_grid = ivec2(2, 1);
    ivec2 logical_size = max(ivec2(params.OutputSize.xy) / macro_grid, ivec2(1));
    ivec2 tile = min(output_pixel / logical_size, macro_grid - ivec2(1));
    int phase_index = tile.y * 2 + tile.x;
    ivec2 pos = output_pixel - tile * logical_size;
    float s0_0_0, s0_0_1, s0_0_2, s0_1_0, s0_1_1, s0_1_2, s0_2_0, s0_2_1, s0_2_2;
    vec4 result = vec4(0.0);
    if (phase_index == 0)
    {
        s0_0_0 = L0(-1.0, -1.0);
        s0_0_1 = L0(0.0, -1.0);
        s0_0_2 = L0(1.0, -1.0);
        s0_1_0 = L0(-1.0, 0.0);
        s0_1_1 = L0(0.0, 0.0);
        s0_1_2 = L0(1.0, 0.0);
        s0_2_0 = L0(-1.0, 1.0);
        s0_2_1 = L0(0.0, 1.0);
        s0_2_2 = L0(1.0, 1.0);
        result += V4(-6.888e-02, -6.888e-02, -6.888e-02, -6.888e-02) * s0_0_0;
        result += V4(-1.549e-01, -1.549e-01, -1.549e-01, -1.549e-01) * s0_0_1;
        result += V4(-1.108e-01, -1.108e-01, -1.108e-01, -1.108e-01) * s0_0_2;
        result += V4(-1.392e-01, -1.392e-01, -1.392e-01, -1.392e-01) * s0_1_0;
        result += V4(-5.328e-02, -5.280e-02, -5.328e-02, -5.305e-02) * s0_1_1;
        result += V4(-6.413e-02, -6.404e-02, -6.413e-02, -6.413e-02) * s0_1_2;
        result += V4(-1.563e-01, -1.563e-01, -1.563e-01, -1.563e-01) * s0_2_0;
        result += V4(-7.254e-02, -7.254e-02, -7.254e-02, -7.254e-02) * s0_2_1;
        result += V4(-4.679e-02, -4.720e-02, -4.679e-02, -4.725e-02) * s0_2_2;
        result += V4(-6.993e-04, -2.343e-04, -6.993e-04, -3.475e-04);
        result = max(result, 0.0);
    }
    else if (phase_index == 1)
    {
        s0_0_0 = L0(-1.0, -1.0);
        s0_0_1 = L0(0.0, -1.0);
        s0_0_2 = L0(1.0, -1.0);
        s0_1_0 = L0(-1.0, 0.0);
        s0_1_1 = L0(0.0, 0.0);
        s0_1_2 = L0(1.0, 0.0);
        s0_2_0 = L0(-1.0, 1.0);
        s0_2_1 = L0(0.0, 1.0);
        s0_2_2 = L0(1.0, 1.0);
        result += V4(1.851e-01, -4.871e-03, -3.070e-02, 1.101e-02) * s0_0_0;
        result += V4(7.661e-02, -6.060e-02, -9.364e-01, -1.294e-01) * s0_0_1;
        result += V4(1.214e-01, 9.223e-01, 8.652e-01, 6.247e-01) * s0_0_2;
        result += V4(3.154e-01, -6.001e-03, 2.772e-02, -1.979e-03) * s0_1_0;
        result += V4(-5.801e-01, 7.592e-02, 1.241e-01, -1.242e-02) * s0_1_1;
        result += V4(-1.627e-01, -9.043e-01, -5.475e-02, -1.605e-01) * s0_1_2;
        result += V4(5.394e-02, 1.075e-02, -8.110e-03, 7.134e-03) * s0_2_0;
        result += V4(1.842e-01, -1.932e-02, -5.528e-03, -3.423e-02) * s0_2_1;
        result += V4(2.033e-02, -1.645e-02, 1.672e-02, 2.765e-02) * s0_2_2;
        result += V4(3.500e-03, 2.636e-04, 3.864e-04, 4.680e-03);
        result = max(result, 0.0);
    }
    FragColor = result;
}
