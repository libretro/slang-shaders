#version 450

#pragma format R8G8B8A8_UNORM

layout(push_constant) uniform Push
{
    vec4 cunny_veryfast_nvl_conv2Size;
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
layout(set = 0, binding = 2) uniform sampler2D cunny_veryfast_nvl_conv2;
layout(set = 0, binding = 3) uniform sampler2D cunny_veryfast_nvl_input;

#define V4 vec4
#define V3 vec3
#define MF float
#include "CuNNy-rgb-common.inc"
#define mad(a, b, c) ((a) * (b) + (c))
#define MulAdd(v, m, acc) (((m) * (v)) + (acc))

#define L0(x, y) cunny_fetch_macro4(cunny_veryfast_nvl_conv2, params.cunny_veryfast_nvl_conv2Size, pos, ivec2(int(x), int(y)), ivec2(0, 0), ivec2(1, 1))

void main()
{
    ivec2 output_pixel = cunny_output_pixel(params.OutputSize.xy);
    ivec2 pos = output_pixel >> 1;
    ivec2 phase = output_pixel & ivec2(1);
    vec4 s0_0_0, s0_0_1, s0_0_2, s0_1_0, s0_1_1, s0_1_2, s0_2_0, s0_2_1, s0_2_2;
    vec4 r0 = vec4(0.0);
    s0_0_0 = L0(-1.0, -1.0);
    s0_0_1 = L0(0.0, -1.0);
    s0_0_2 = L0(1.0, -1.0);
    s0_1_0 = L0(-1.0, 0.0);
    s0_1_1 = L0(0.0, 0.0);
    s0_1_2 = L0(1.0, 0.0);
    s0_2_0 = L0(-1.0, 1.0);
    s0_2_1 = L0(0.0, 1.0);
    s0_2_2 = L0(1.0, 1.0);
    r0 += mul(s0_0_0, M4(-8.466e-03, 8.423e-03, -1.341e-02, 8.400e-03, 4.039e-02, 1.243e-02, 3.053e-03, 2.236e-02, -9.043e-02, -4.385e-02, 1.099e-02, -4.289e-03, 2.522e-02, -1.250e-02, 1.207e-02, -6.843e-04));
    r0 += mul(s0_0_1, M4(2.039e-02, 2.086e-02, 7.522e-03, -3.699e-02, 1.700e-01, 1.294e-01, -2.264e-02, 4.882e-03, -2.046e-02, -6.568e-02, -3.262e-03, 1.502e-02, 4.650e-02, 7.837e-02, -1.792e-03, 6.150e-03));
    r0 += mul(s0_0_2, M4(1.362e-03, -4.553e-03, -5.095e-03, -1.786e-02, 1.193e-02, 6.665e-02, 9.653e-03, -1.117e-02, -6.344e-03, -1.285e-03, 6.389e-04, -1.254e-04, -2.810e-02, -9.490e-03, 2.764e-03, 1.519e-02));
    r0 += mul(s0_1_0, M4(6.046e-02, -5.579e-02, 4.086e-02, -2.594e-02, -2.222e-01, 6.714e-02, 1.642e-01, 1.251e-02, 2.124e-01, 2.800e-02, -2.271e-01, -1.145e-01, 1.470e-01, 2.230e-03, -2.017e-01, 2.901e-02));
    r0 += mul(s0_1_1, M4(-6.934e-01, 6.074e-01, -3.916e-01, 3.975e-01, -1.182e-01, -1.321e+00, 5.566e-01, 3.135e-02, -1.213e-01, 1.228e-01, -2.879e-02, -1.585e-01, 3.785e-01, 3.936e-01, -3.096e-01, -5.809e-01));
    r0 += mul(s0_1_2, M4(5.465e-02, 1.837e-02, 6.128e-03, -2.014e-02, 2.840e-02, 1.509e-01, -1.450e-02, 1.985e-01, 8.899e-03, -6.614e-02, -1.062e-02, -8.987e-03, -3.886e-02, 5.009e-02, 1.448e-02, 3.161e-02));
    r0 += mul(s0_2_0, M4(-1.064e-02, 1.822e-02, 1.365e-03, -1.041e-02, -6.714e-02, -4.944e-02, -1.042e-01, -3.769e-02, 2.007e-01, 2.301e-02, 5.776e-01, 1.213e-01, 3.036e-03, 1.199e-02, 1.776e-02, 4.685e-03));
    r0 += mul(s0_2_1, M4(5.676e-02, 9.702e-03, -2.397e-01, 2.686e-01, 1.734e-02, 2.728e-02, 8.738e-02, -3.604e-01, -1.548e-01, 9.495e-02, -2.007e-01, 3.917e-01, -3.189e-02, -2.570e-02, 6.957e-02, 7.940e-02));
    r0 += mul(s0_2_2, M4(-1.035e-02, -2.055e-04, 3.797e-02, 3.525e-02, 2.739e-02, 1.148e-02, -1.547e-03, 3.837e-02, -5.462e-03, -7.788e-02, 4.641e-03, -1.392e-01, 8.643e-03, -7.950e-03, -8.491e-03, -1.800e-02));
    r0 += V4(-5.434e-06, 1.445e-05, -9.457e-05, -3.159e-05);
    float residual = cunny_phase_component(r0, phase);
    vec3 base = cunny_manual_bilinear_rgb(cunny_veryfast_nvl_input, params.cunny_veryfast_nvl_inputSize, output_pixel, params.OutputSize.xy);
    float y = dot(base, vec3(0.299, 0.587, 0.114));
    float u = dot(base, vec3(-0.169, -0.331, 0.5));
    float v = dot(base, vec3(0.5, -0.419, -0.081));
    float y_new = clamp(y + residual, 0.0, 1.0);
    vec3 rgb = vec3(y_new - 0.00093 * u + 1.401687 * v, y_new - 0.3437 * u - 0.71417 * v, y_new + 1.77216 * u + 0.00099 * v);
    FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
