#version 450

#pragma format R8G8B8A8_UNORM

layout(push_constant) uniform Push
{
    vec4 cunny_fast_nvl_inputSize;
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
layout(set = 0, binding = 2) uniform sampler2D cunny_fast_nvl_input;

#define V4 vec4
#define V3 vec3
#define MF float
#include "CuNNy-rgb-common.inc"
#define mad(a, b, c) ((a) * (b) + (c))
#define MulAdd(v, m, acc) (((m) * (v)) + (acc))

#define L0(x, y) cunny_fetch_luma(cunny_fast_nvl_input, params.cunny_fast_nvl_inputSize, pos, ivec2(int(x), int(y)))

void main()
{
    ivec2 output_pixel = cunny_output_pixel(params.OutputSize.xy);
    const ivec2 macro_grid = ivec2(3, 1);
    ivec2 logical_size = max(ivec2(params.OutputSize.xy) / macro_grid, ivec2(1));
    ivec2 tile = min(output_pixel / logical_size, macro_grid - ivec2(1));
    int phase_index = tile.y * 3 + tile.x;
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
        result += V4(6.093e-02, 1.179e-03, 1.806e-02, -6.992e-02) * s0_0_0;
        result += V4(3.691e-01, -8.520e-02, 2.036e-01, 7.349e-02) * s0_0_1;
        result += V4(1.523e-02, 9.094e-02, -2.778e-02, -6.861e-03) * s0_0_2;
        result += V4(-7.544e-02, 1.298e-02, -3.757e-02, 3.096e-01) * s0_1_0;
        result += V4(-2.978e-01, -5.645e-01, -9.956e-03, -2.510e-01) * s0_1_1;
        result += V4(2.889e-02, 5.995e-01, 7.107e-02, -1.362e-02) * s0_1_2;
        result += V4(-3.925e-03, -1.148e-02, -2.253e-02, -1.005e-02) * s0_2_0;
        result += V4(1.529e-02, 6.681e-01, 3.094e-02, 5.111e-02) * s0_2_1;
        result += V4(2.772e-03, -7.090e-01, -4.582e-02, 1.679e-02) * s0_2_2;
        result += V4(3.827e-04, -2.238e-03, 2.436e-02, 1.030e-02);
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
        result += V4(3.015e-03, -4.224e-03, -2.180e-02, -2.643e-02) * s0_0_0;
        result += V4(-1.158e-02, 1.407e-02, 2.771e-02, 7.273e-02) * s0_0_1;
        result += V4(4.242e-03, -4.563e-03, 2.327e-02, -2.772e-02) * s0_0_2;
        result += V4(-1.040e-02, 2.754e-03, 1.169e-01, 9.726e-03) * s0_1_0;
        result += V4(-8.340e-01, -8.240e-01, -5.527e-01, -1.687e-01) * s0_1_1;
        result += V4(-1.516e-02, 8.145e-01, 3.788e-01, -2.730e-02) * s0_1_2;
        result += V4(9.480e-03, -2.408e-03, -2.715e-02, -2.228e-02) * s0_2_0;
        result += V4(8.431e-01, -2.199e-03, 4.065e-02, 2.382e-01) * s0_2_1;
        result += V4(9.945e-03, 5.921e-03, 4.050e-04, 2.319e-01) * s0_2_2;
        result += V4(2.205e-04, -5.557e-05, 3.012e-02, 1.121e-02);
        result = max(result, 0.0);
    }
    else if (phase_index == 2)
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
        result += V4(1.540e-02, 1.100e-02, 6.360e-02, 4.463e-01) * s0_0_0;
        result += V4(-8.737e-03, -1.135e-01, -8.099e-04, -3.525e-01) * s0_0_1;
        result += V4(-1.014e-02, -1.007e-02, -5.456e-02, -1.189e-01) * s0_0_2;
        result += V4(7.381e-01, -1.548e-01, 2.285e-01, -4.252e-01) * s0_1_0;
        result += V4(-7.441e-01, 5.611e-01, 4.398e-01, 5.656e-01) * s0_1_1;
        result += V4(1.063e-02, 3.516e-03, 3.635e-02, -1.155e-01) * s0_1_2;
        result += V4(-1.037e-02, -2.452e-02, -3.012e-01, -1.674e-01) * s0_2_0;
        result += V4(1.257e-02, -7.065e-02, -4.877e-01, -8.929e-02) * s0_2_1;
        result += V4(-5.354e-03, -6.593e-02, 6.959e-02, 2.536e-01) * s0_2_2;
        result += V4(-1.399e-04, 1.295e-03, -5.445e-04, -8.903e-04);
        result = max(result, 0.0);
    }
    FragColor = result;
}
