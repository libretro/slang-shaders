#version 450
// The MIT License(MIT)
//
// Copyright(c) 2022 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files(the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and / or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// NVIDIA Image Scaling SDK - v1.0.3 (NVScaler), ported from the compute-shader
// reference to a RetroArch single-pass slang fragment shader. The per-output-pixel
// math (edge map, directional polyphase filtering, USM) is preserved verbatim; the
// thread-group/LDS work-sharing of the original is replaced with direct texelFetch
// of the 6x6 luma support. SDR path only. Coefficient banks are the unmodified
// kPhaseCount=64, 6-tap coef_scale / coef_usm tables from NIS_Config.h.
#pragma name NIS_SCALER

// filter_linear0 = true
// scale_type0    = viewport
// scale0         = 1.0

#pragma parameter NIS_SHARPNESS "NIS Sharpness" 0.5 0.0 1.0 0.05

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float NIS_SHARPNESS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define kPhaseCount 64
#define kSupportSize 6

// --- Coefficient banks (verbatim from NIS_Config.h, taps 6-7 are zero pad, dropped) ---
const float coefScaler[64][6] = float[64][6](
    float[6](0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000),
    float[6](0.002900, -0.012700, 1.000000, 0.013200, -0.003400, 0.000000),
    float[6](0.006300, -0.024900, 0.998500, 0.026900, -0.006800, 0.000000),
    float[6](0.008800, -0.036100, 0.995600, 0.041500, -0.010300, 0.000500),
    float[6](0.011700, -0.047400, 0.993200, 0.056200, -0.014200, 0.000500),
    float[6](0.014200, -0.057600, 0.989700, 0.071300, -0.018100, 0.000500),
    float[6](0.016600, -0.067400, 0.984400, 0.087400, -0.022000, 0.001000),
    float[6](0.018600, -0.076200, 0.978500, 0.104000, -0.026400, 0.001500),
    float[6](0.020500, -0.085000, 0.972700, 0.120600, -0.030800, 0.002000),
    float[6](0.022500, -0.092800, 0.964800, 0.138200, -0.035200, 0.002400),
    float[6](0.023900, -0.100600, 0.957500, 0.155800, -0.039600, 0.002900),
    float[6](0.025400, -0.107400, 0.948700, 0.173800, -0.043900, 0.003400),
    float[6](0.026400, -0.113800, 0.939000, 0.192900, -0.048800, 0.004400),
    float[6](0.027800, -0.119100, 0.928200, 0.211900, -0.053700, 0.004900),
    float[6](0.028800, -0.124500, 0.917000, 0.231000, -0.058100, 0.005900),
    float[6](0.029300, -0.129400, 0.905800, 0.251000, -0.063000, 0.006300),
    float[6](0.030300, -0.133300, 0.892600, 0.271000, -0.067900, 0.007300),
    float[6](0.030800, -0.136700, 0.878900, 0.291500, -0.072800, 0.008300),
    float[6](0.030800, -0.140100, 0.865700, 0.312000, -0.077600, 0.009300),
    float[6](0.031300, -0.142600, 0.850600, 0.333000, -0.082500, 0.010300),
    float[6](0.031300, -0.144500, 0.835400, 0.354000, -0.087400, 0.011200),
    float[6](0.031300, -0.146000, 0.819300, 0.375500, -0.092300, 0.012200),
    float[6](0.031300, -0.147000, 0.802200, 0.396500, -0.096700, 0.013700),
    float[6](0.030800, -0.147900, 0.785600, 0.418500, -0.101600, 0.014600),
    float[6](0.030300, -0.147900, 0.768100, 0.439900, -0.106000, 0.015600),
    float[6](0.029800, -0.147900, 0.750500, 0.461400, -0.110400, 0.016600),
    float[6](0.029300, -0.147000, 0.731400, 0.482900, -0.114700, 0.018100),
    float[6](0.028800, -0.146000, 0.711900, 0.504900, -0.118700, 0.019000),
    float[6](0.027800, -0.144500, 0.692900, 0.526400, -0.122600, 0.020000),
    float[6](0.027300, -0.143100, 0.672400, 0.547900, -0.126000, 0.021500),
    float[6](0.026400, -0.141100, 0.652800, 0.569300, -0.129900, 0.022500),
    float[6](0.025400, -0.138700, 0.632300, 0.590300, -0.132800, 0.023400),
    float[6](0.024400, -0.135700, 0.611300, 0.611300, -0.135700, 0.024400),
    float[6](0.023400, -0.132800, 0.590300, 0.632300, -0.138700, 0.025400),
    float[6](0.022500, -0.129900, 0.569300, 0.652800, -0.141100, 0.026400),
    float[6](0.021500, -0.126000, 0.547900, 0.672400, -0.143100, 0.027300),
    float[6](0.020000, -0.122600, 0.526400, 0.692900, -0.144500, 0.027800),
    float[6](0.019000, -0.118700, 0.504900, 0.711900, -0.146000, 0.028800),
    float[6](0.018100, -0.114700, 0.482900, 0.731400, -0.147000, 0.029300),
    float[6](0.016600, -0.110400, 0.461400, 0.750500, -0.147900, 0.029800),
    float[6](0.015600, -0.106000, 0.439900, 0.768100, -0.147900, 0.030300),
    float[6](0.014600, -0.101600, 0.418500, 0.785600, -0.147900, 0.030800),
    float[6](0.013700, -0.096700, 0.396500, 0.802200, -0.147000, 0.031300),
    float[6](0.012200, -0.092300, 0.375500, 0.819300, -0.146000, 0.031300),
    float[6](0.011200, -0.087400, 0.354000, 0.835400, -0.144500, 0.031300),
    float[6](0.010300, -0.082500, 0.333000, 0.850600, -0.142600, 0.031300),
    float[6](0.009300, -0.077600, 0.312000, 0.865700, -0.140100, 0.030800),
    float[6](0.008300, -0.072800, 0.291500, 0.878900, -0.136700, 0.030800),
    float[6](0.007300, -0.067900, 0.271000, 0.892600, -0.133300, 0.030300),
    float[6](0.006300, -0.063000, 0.251000, 0.905800, -0.129400, 0.029300),
    float[6](0.005900, -0.058100, 0.231000, 0.917000, -0.124500, 0.028800),
    float[6](0.004900, -0.053700, 0.211900, 0.928200, -0.119100, 0.027800),
    float[6](0.004400, -0.048800, 0.192900, 0.939000, -0.113800, 0.026400),
    float[6](0.003400, -0.043900, 0.173800, 0.948700, -0.107400, 0.025400),
    float[6](0.002900, -0.039600, 0.155800, 0.957500, -0.100600, 0.023900),
    float[6](0.002400, -0.035200, 0.138200, 0.964800, -0.092800, 0.022500),
    float[6](0.002000, -0.030800, 0.120600, 0.972700, -0.085000, 0.020500),
    float[6](0.001500, -0.026400, 0.104000, 0.978500, -0.076200, 0.018600),
    float[6](0.001000, -0.022000, 0.087400, 0.984400, -0.067400, 0.016600),
    float[6](0.000500, -0.018100, 0.071300, 0.989700, -0.057600, 0.014200),
    float[6](0.000500, -0.014200, 0.056200, 0.993200, -0.047400, 0.011700),
    float[6](0.000500, -0.010300, 0.041500, 0.995600, -0.036100, 0.008800),
    float[6](0.000000, -0.006800, 0.026900, 0.998500, -0.024900, 0.006300),
    float[6](0.000000, -0.003400, 0.013200, 1.000000, -0.012700, 0.002900)
);

const float coefUSM[64][6] = float[64][6](
    float[6](0.000000, -0.600100, 1.200200, -0.600100, 0.000000, 0.000000),
    float[6](0.002900, -0.608400, 1.198700, -0.590300, -0.002900, 0.000000),
    float[6](0.004900, -0.614700, 1.195800, -0.579100, -0.006800, 0.000500),
    float[6](0.007300, -0.619600, 1.189000, -0.565900, -0.010300, 0.000000),
    float[6](0.009300, -0.623500, 1.180200, -0.551300, -0.015100, 0.000000),
    float[6](0.011200, -0.626500, 1.169900, -0.535200, -0.019500, 0.000500),
    float[6](0.012200, -0.627000, 1.158200, -0.518100, -0.025900, 0.000500),
    float[6](0.014200, -0.628400, 1.145500, -0.500500, -0.031700, 0.000500),
    float[6](0.015600, -0.626500, 1.127400, -0.479000, -0.038600, 0.000500),
    float[6](0.016600, -0.623500, 1.108900, -0.457000, -0.045400, 0.001000),
    float[6](0.017600, -0.618700, 1.087900, -0.434600, -0.053200, 0.001000),
    float[6](0.018100, -0.613800, 1.065900, -0.410200, -0.061500, 0.001500),
    float[6](0.019000, -0.606900, 1.040500, -0.384300, -0.069800, 0.001500),
    float[6](0.019500, -0.600600, 1.016100, -0.357400, -0.079600, 0.002000),
    float[6](0.020000, -0.592800, 0.989300, -0.328600, -0.089800, 0.002400),
    float[6](0.020000, -0.582000, 0.958000, -0.298800, -0.100100, 0.002900),
    float[6](0.020000, -0.572800, 0.929200, -0.269000, -0.110400, 0.003400),
    float[6](0.020000, -0.562000, 0.897500, -0.236800, -0.122600, 0.003900),
    float[6](0.020500, -0.549800, 0.864300, -0.204600, -0.134300, 0.004400),
    float[6](0.020000, -0.537100, 0.830100, -0.170900, -0.146500, 0.004900),
    float[6](0.019500, -0.523900, 0.794400, -0.136700, -0.158700, 0.005400),
    float[6](0.019500, -0.510700, 0.759800, -0.102100, -0.172400, 0.005900),
    float[6](0.019000, -0.496600, 0.723100, -0.064900, -0.186500, 0.006300),
    float[6](0.018600, -0.481900, 0.684600, -0.028800, -0.199700, 0.006800),
    float[6](0.018600, -0.466800, 0.646000, 0.009300, -0.214400, 0.007300),
    float[6](0.017600, -0.450700, 0.605500, 0.047900, -0.229000, 0.008300),
    float[6](0.017100, -0.437000, 0.569300, 0.085900, -0.244600, 0.008800),
    float[6](0.016100, -0.419900, 0.528300, 0.125500, -0.259800, 0.009800),
    float[6](0.016100, -0.404800, 0.488300, 0.165500, -0.275400, 0.010300),
    float[6](0.015100, -0.388700, 0.449700, 0.204100, -0.291000, 0.010700),
    float[6](0.014200, -0.371100, 0.407200, 0.244600, -0.306600, 0.011700),
    float[6](0.013700, -0.355500, 0.367200, 0.285200, -0.322800, 0.012200),
    float[6](0.013200, -0.339400, 0.326200, 0.326200, -0.339400, 0.013200),
    float[6](0.012200, -0.322800, 0.285200, 0.367200, -0.355500, 0.013700),
    float[6](0.011700, -0.306600, 0.244600, 0.407200, -0.371100, 0.014200),
    float[6](0.010700, -0.291000, 0.204100, 0.449700, -0.388700, 0.015100),
    float[6](0.010300, -0.275400, 0.165500, 0.488300, -0.404800, 0.016100),
    float[6](0.009800, -0.259800, 0.125500, 0.528300, -0.419900, 0.016100),
    float[6](0.008800, -0.244600, 0.085900, 0.569300, -0.437000, 0.017100),
    float[6](0.008300, -0.229000, 0.047900, 0.605500, -0.450700, 0.017600),
    float[6](0.007300, -0.214400, 0.009300, 0.646000, -0.466800, 0.018600),
    float[6](0.006800, -0.199700, -0.028800, 0.684600, -0.481900, 0.018600),
    float[6](0.006300, -0.186500, -0.064900, 0.723100, -0.496600, 0.019000),
    float[6](0.005900, -0.172400, -0.102100, 0.759800, -0.510700, 0.019500),
    float[6](0.005400, -0.158700, -0.136700, 0.794400, -0.523900, 0.019500),
    float[6](0.004900, -0.146500, -0.170900, 0.830100, -0.537100, 0.020000),
    float[6](0.004400, -0.134300, -0.204600, 0.864300, -0.549800, 0.020500),
    float[6](0.003900, -0.122600, -0.236800, 0.897500, -0.562000, 0.020000),
    float[6](0.003400, -0.110400, -0.269000, 0.929200, -0.572800, 0.020000),
    float[6](0.002900, -0.100100, -0.298800, 0.958000, -0.582000, 0.020000),
    float[6](0.002400, -0.089800, -0.328600, 0.989300, -0.592800, 0.020000),
    float[6](0.002000, -0.079600, -0.357400, 1.016100, -0.600600, 0.019500),
    float[6](0.001500, -0.069800, -0.384300, 1.040500, -0.606900, 0.019000),
    float[6](0.001500, -0.061500, -0.410200, 1.065900, -0.613800, 0.018100),
    float[6](0.001000, -0.053200, -0.434600, 1.087900, -0.618700, 0.017600),
    float[6](0.001000, -0.045400, -0.457000, 1.108900, -0.623500, 0.016600),
    float[6](0.000500, -0.038600, -0.479000, 1.127400, -0.626500, 0.015600),
    float[6](0.000500, -0.031700, -0.500500, 1.145500, -0.628400, 0.014200),
    float[6](0.000500, -0.025900, -0.518100, 1.158200, -0.627000, 0.012200),
    float[6](0.000500, -0.019500, -0.535200, 1.169900, -0.626500, 0.011200),
    float[6](0.000000, -0.015100, -0.551300, 1.180200, -0.623500, 0.009300),
    float[6](0.000000, -0.010300, -0.565900, 1.189000, -0.619600, 0.007300),
    float[6](0.000500, -0.006800, -0.579100, 1.195800, -0.614700, 0.004900),
    float[6](0.000000, -0.002900, -0.590300, 1.198700, -0.608400, 0.002900)
);

// --- Config constants derived in-shader from the sharpness slider (SDR path).
// Mirrors NVScalerUpdateConfig() in NIS_Config.h. ---
float kDetectRatio, kDetectThres, kMinContrastRatio, kRatioNorm;
float kContrastBoost, kEps, kSharpStartY, kSharpScaleY;
float kSharpStrengthMin, kSharpStrengthScale, kSharpLimitMin, kSharpLimitScale;

void NISConfigSDR(float sharpness) {
    sharpness = clamp(sharpness, 0.0, 1.0);
    float slider = sharpness - 0.5;
    float MaxScale   = (slider >= 0.0) ? 1.25 : 1.75;
    float MinScale   = (slider >= 0.0) ? 1.25 : 1.0;
    float LimitScale = (slider >= 0.0) ? 1.25 : 1.0;

    kDetectRatio      = 2.0 * 1127.0 / 1024.0;
    kDetectThres      = 64.0 / 1024.0;
    kMinContrastRatio = 2.0;
    float kMaxContrastRatio = 10.0;

    kSharpStartY = 0.45;
    float kSharpEndY = 0.9;
    kSharpStrengthMin   = max(0.0, 0.4 + slider * MinScale * 1.2);
    float kSharpStrengthMax = 1.6 + slider * MaxScale * 1.8;
    kSharpLimitMin      = max(0.1, 0.14 + slider * LimitScale * 0.32);
    float kSharpLimitMax    = 0.5 + slider * LimitScale * 0.6;

    kRatioNorm          = 1.0 / (kMaxContrastRatio - kMinContrastRatio);
    kSharpScaleY        = 1.0 / (kSharpEndY - kSharpStartY);
    kSharpStrengthScale = kSharpStrengthMax - kSharpStrengthMin;
    kSharpLimitScale    = kSharpLimitMax - kSharpLimitMin;
    kContrastBoost      = 1.0;
    kEps                = 1.0 / 255.0;
}

float getY(vec3 rgb) {
    return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}

// 6x6 luma support, global so helpers can index it without copying.
float P[6][6];

// Sobel-style 3x3 edge classifier at base offset (bi,bj) into P. Mirrors GetEdgeMap().
vec4 GetEdgeMap(int bi, int bj) {
    float g_0   = abs(P[0+bi][0+bj] + P[0+bi][1+bj] + P[0+bi][2+bj] - P[2+bi][0+bj] - P[2+bi][1+bj] - P[2+bi][2+bj]);
    float g_45  = abs(P[1+bi][0+bj] + P[0+bi][0+bj] + P[0+bi][1+bj] - P[2+bi][1+bj] - P[2+bi][2+bj] - P[1+bi][2+bj]);
    float g_90  = abs(P[0+bi][0+bj] + P[1+bi][0+bj] + P[2+bi][0+bj] - P[0+bi][2+bj] - P[1+bi][2+bj] - P[2+bi][2+bj]);
    float g_135 = abs(P[1+bi][0+bj] + P[2+bi][0+bj] + P[2+bi][1+bj] - P[0+bi][1+bj] - P[0+bi][2+bj] - P[1+bi][2+bj]);

    float g_0_90_max   = max(g_0, g_90);
    float g_0_90_min   = min(g_0, g_90);
    float g_45_135_max = max(g_45, g_135);
    float g_45_135_min = min(g_45, g_135);

    if (g_0_90_max + g_45_135_max == 0.0)
        return vec4(0.0);

    float e_0_90   = min(g_0_90_max / (g_0_90_max + g_45_135_max), 1.0);
    float e_45_135 = 1.0 - e_0_90;

    bool c_0_90    = (g_0_90_max > (g_0_90_min * kDetectRatio)) && (g_0_90_max > kDetectThres) && (g_0_90_max > g_45_135_min);
    bool c_45_135  = (g_45_135_max > (g_45_135_min * kDetectRatio)) && (g_45_135_max > kDetectThres) && (g_45_135_max > g_0_90_min);
    bool c_g_0_90  = (g_0_90_max == g_0);
    bool c_g_45_135= (g_45_135_max == g_45);

    float f_e_0_90   = (c_0_90 && c_45_135) ? e_0_90   : 1.0;
    float f_e_45_135 = (c_0_90 && c_45_135) ? e_45_135 : 1.0;

    float weight_0   = (c_0_90 &&  c_g_0_90)   ? f_e_0_90   : 0.0;
    float weight_90  = (c_0_90 && !c_g_0_90)   ? f_e_0_90   : 0.0;
    float weight_45  = (c_45_135 &&  c_g_45_135)? f_e_45_135 : 0.0;
    float weight_135 = (c_45_135 && !c_g_45_135)? f_e_45_135 : 0.0;

    return vec4(weight_0, weight_90, weight_45, weight_135);
}

vec4 GetInterpEdgeMap(vec4 e00, vec4 e01, vec4 e10, vec4 e11, float fx, float fy) {
    vec4 h0 = mix(e00, e01, fx);
    vec4 h1 = mix(e10, e11, fx);
    return mix(h0, h1, fy);
}

float CalcLTI(float p0, float p1, float p2, float p3, float p4, float p5, int phase_index) {
    bool selector = (phase_index <= kPhaseCount / 2);
    float sel = selector ? p0 : p3;
    float a_min = min(min(p1, p2), sel);
    float a_max = max(max(p1, p2), sel);
    sel = selector ? p2 : p5;
    float b_min = min(min(p3, p4), sel);
    float b_max = max(max(p3, p4), sel);

    float a_cont = a_max - a_min;
    float b_cont = b_max - b_min;
    float cont_ratio = max(a_cont, b_cont) / (min(a_cont, b_cont) + kEps);
    return (1.0 - clamp((cont_ratio - kMinContrastRatio) * kRatioNorm, 0.0, 1.0)) * kContrastBoost;
}

float EvalPoly6(float pxl[6], int phase_int) {
    phase_int = clamp(phase_int, 0, 63);
    float y = 0.0;
    for (int i = 0; i < 6; ++i) y += coefScaler[phase_int][i] * pxl[i];
    float y_usm = 0.0;
    for (int i = 0; i < 6; ++i) y_usm += coefUSM[phase_int][i] * pxl[i];

    float y_scale = 1.0 - clamp((y - kSharpStartY) * kSharpScaleY, 0.0, 1.0);
    float y_sharpness = y_scale * kSharpStrengthScale + kSharpStrengthMin;
    y_usm *= y_sharpness;
    float y_sharpness_limit = (y_scale * kSharpLimitScale + kSharpLimitMin) * y;
    y_usm = min(y_sharpness_limit, max(-y_sharpness_limit, y_usm));
    y_usm *= CalcLTI(pxl[0], pxl[1], pxl[2], pxl[3], pxl[4], pxl[5], phase_int);
    return y + y_usm;
}

float FilterNormal(int phase_x, int phase_y) {
    phase_x = clamp(phase_x, 0, 63);
    phase_y = clamp(phase_y, 0, 63);
    float h_acc = 0.0;
    for (int j = 0; j < 6; ++j) {
        float v_acc = 0.0;
        for (int i = 0; i < 6; ++i)
            v_acc += P[i][j] * coefScaler[phase_y][i];
        h_acc += v_acc * coefScaler[phase_x][j];
    }
    return h_acc;
}

float AddDirFilters(float fx, float fy, int fx_int, int fy_int, vec4 w) {
    float f = 0.0;
    if (w.x > 0.0) {
        float interp0Deg[6];
        for (int i = 0; i < 6; ++i) interp0Deg[i] = mix(P[i][2], P[i][3], fx);
        f += EvalPoly6(interp0Deg, fy_int) * w.x;
    }
    if (w.y > 0.0) {
        float interp90Deg[6];
        for (int i = 0; i < 6; ++i) interp90Deg[i] = mix(P[2][i], P[3][i], fy);
        f += EvalPoly6(interp90Deg, fx_int) * w.y;
    }
    if (w.z > 0.0) {
        float pphase_b45 = 0.5 + 0.5 * (fx - fy);
        float t[7];
        t[1] = mix(P[2][1], P[1][2], pphase_b45);
        t[3] = mix(P[3][2], P[2][3], pphase_b45);
        t[5] = mix(P[4][3], P[3][4], pphase_b45);
        {
            pphase_b45 = pphase_b45 - 0.5;
            float a = (pphase_b45 >= 0.0) ? P[0][2] : P[2][0];
            float b = (pphase_b45 >= 0.0) ? P[1][3] : P[3][1];
            float c = (pphase_b45 >= 0.0) ? P[2][4] : P[4][2];
            float d = (pphase_b45 >= 0.0) ? P[3][5] : P[5][3];
            t[0] = mix(P[1][1], a, abs(pphase_b45));
            t[2] = mix(P[2][2], b, abs(pphase_b45));
            t[4] = mix(P[3][3], c, abs(pphase_b45));
            t[6] = mix(P[4][4], d, abs(pphase_b45));
        }
        float interp45Deg[6];
        float pphase_p45 = fx + fy;
        if (pphase_p45 >= 1.0) {
            for (int i = 0; i < 6; ++i) interp45Deg[i] = t[i + 1];
            pphase_p45 -= 1.0;
        } else {
            for (int i = 0; i < 6; ++i) interp45Deg[i] = t[i];
        }
        f += EvalPoly6(interp45Deg, int(pphase_p45 * 64.0)) * w.z;
    }
    if (w.w > 0.0) {
        float pphase_b135 = 0.5 * (fx + fy);
        float t[7];
        t[1] = mix(P[3][1], P[4][2], pphase_b135);
        t[3] = mix(P[2][2], P[3][3], pphase_b135);
        t[5] = mix(P[1][3], P[2][4], pphase_b135);
        {
            pphase_b135 = pphase_b135 - 0.5;
            float a = (pphase_b135 >= 0.0) ? P[5][2] : P[3][0];
            float b = (pphase_b135 >= 0.0) ? P[4][3] : P[2][1];
            float c = (pphase_b135 >= 0.0) ? P[3][4] : P[1][2];
            float d = (pphase_b135 >= 0.0) ? P[2][5] : P[0][3];
            t[0] = mix(P[4][1], a, abs(pphase_b135));
            t[2] = mix(P[3][2], b, abs(pphase_b135));
            t[4] = mix(P[2][3], c, abs(pphase_b135));
            t[6] = mix(P[1][4], d, abs(pphase_b135));
        }
        float interp135Deg[6];
        float pphase_p135 = 1.0 + (fx - fy);
        if (pphase_p135 >= 1.0) {
            for (int i = 0; i < 6; ++i) interp135Deg[i] = t[i + 1];
            pphase_p135 -= 1.0;
        } else {
            for (int i = 0; i < 6; ++i) interp135Deg[i] = t[i];
        }
        f += EvalPoly6(interp135Deg, int(pphase_p135 * 64.0)) * w.w;
    }
    return f;
}

void main() {
    NISConfigSDR(params.NIS_SHARPNESS);

    // Output pixel (viewport-res pass) -> source coordinate.
    ivec2 dst = ivec2(vTexCoord * params.OutputSize.xy);
    float kScaleX = params.SourceSize.x * params.OutputSize.z; // src/out
    float kScaleY = params.SourceSize.y * params.OutputSize.w;

    float srcX = (0.5 + float(dst.x)) * kScaleX - 0.5;
    float srcY = (0.5 + float(dst.y)) * kScaleY - 0.5;
    int ix0 = int(floor(srcX));
    int iy0 = int(floor(srcY));
    float fx = srcX - floor(srcX);
    float fy = srcY - floor(srcY);
    int fx_int = int(fx * float(kPhaseCount));
    int fy_int = int(fy * float(kPhaseCount));

    ivec2 maxc = ivec2(params.SourceSize.xy) - 1;
    for (int i = 0; i < 6; ++i) {
        for (int j = 0; j < 6; ++j) {
            ivec2 sp = clamp(ivec2(ix0 + (j - 2), iy0 + (i - 2)), ivec2(0), maxc);
            P[i][j] = getY(texelFetch(Source, sp, 0).rgb);
        }
    }

    // Directional edge weights from the 2x2 edge map straddling the sample point.
    vec4 e00 = GetEdgeMap(1, 1);
    vec4 e01 = GetEdgeMap(1, 2);
    vec4 e10 = GetEdgeMap(2, 1);
    vec4 e11 = GetEdgeMap(2, 2);
    vec4 w = GetInterpEdgeMap(e00, e01, e10, e11, fx, fy);

    float baseWeight = 1.0 - w.x - w.y - w.z - w.w;
    float opY  = FilterNormal(fx_int, fy_int) * baseWeight;
    opY       += AddDirFilters(fx, fy, fx_int, fy_int, w);

    // Bilinear chroma upscale + luma-delta reconstruction.
    vec2 coord = vec2((srcX + 0.5) * params.SourceSize.z, (srcY + 0.5) * params.SourceSize.w);
    vec3 op = textureLod(Source, coord, 0.0).rgb;
    float y = getY(op);
    float corr = opY - y;
    op += vec3(corr);

    FragColor = vec4(clamp(op, 0.0, 1.0), 1.0);
}
