#version 450

#pragma format R8G8B8A8_UNORM

layout(push_constant) uniform Push
{
    vec4 cunny_faster_nvl_inputSize;
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
layout(set = 0, binding = 2) uniform sampler2D cunny_faster_nvl_input;

#define V4 vec4
#define V3 vec3
#define MF float
#include "CuNNy-rgb-common.inc"
#define mad(a, b, c) ((a) * (b) + (c))
#define MulAdd(v, m, acc) (((m) * (v)) + (acc))

#define L0(x, y) cunny_fetch_luma(cunny_faster_nvl_input, params.cunny_faster_nvl_inputSize, pos, ivec2(int(x), int(y)))

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
        result += V4(1.353e-01, 1.984e-02, 1.211e-02, 7.598e-01) * s0_0_0;
        result += V4(-3.271e-01, 1.228e-02, -7.949e-01, -7.767e-01) * s0_0_1;
        result += V4(2.191e-02, 5.508e-03, 3.210e-03, 1.244e-02) * s0_0_2;
        result += V4(-7.642e-02, -2.865e-02, -5.194e-03, 1.476e-02) * s0_1_0;
        result += V4(7.368e-01, -3.904e-02, 7.920e-01, 1.424e-02) * s0_1_1;
        result += V4(-5.454e-03, -1.669e-02, -4.788e-03, -2.104e-02) * s0_1_2;
        result += V4(-2.345e-03, -1.705e-01, -5.146e-03, -3.928e-03) * s0_2_0;
        result += V4(-5.449e-02, 4.110e-01, 6.028e-03, 1.676e-03) * s0_2_1;
        result += V4(2.678e-04, 1.965e-02, -2.196e-03, -5.237e-04) * s0_2_2;
        result += V4(9.737e-03, 3.376e-04, -6.982e-05, 1.065e-04);
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
        result += V4(-1.652e-02, 1.962e-02, 3.038e-01, -2.677e-02) * s0_0_0;
        result += V4(-1.923e-03, 5.059e-01, 3.410e-01, 4.174e-02) * s0_0_1;
        result += V4(2.057e-02, -5.037e-03, 1.729e-01, -6.058e-03) * s0_0_2;
        result += V4(9.685e-03, -4.657e-03, -2.844e-01, 5.297e-01) * s0_1_0;
        result += V4(-8.027e-01, -1.428e-02, -5.293e-01, -2.466e-01) * s0_1_1;
        result += V4(6.826e-01, 1.992e-02, -2.191e-01, 5.138e-02) * s0_1_2;
        result += V4(8.427e-04, -2.452e-02, 5.649e-02, -1.625e-03) * s0_2_0;
        result += V4(1.616e-01, 1.001e-02, 2.011e-02, 4.106e-02) * s0_2_1;
        result += V4(-5.201e-02, 6.417e-03, 1.263e-01, -2.240e-02) * s0_2_2;
        result += V4(-1.634e-03, 6.261e-03, 7.272e-03, 1.764e-03);
        result = max(result, 0.0);
    }
    FragColor = result;
}
