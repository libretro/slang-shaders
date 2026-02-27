#version 450

// Filename: hdr-test.slang
//
// Copyright (C) 2026 W. M. Martinez
//
// Licensed under the Apache License, Version 2.0(the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#pragma name HDRTestCard
#pragma format A2B10G10R10_UNORM_PACK32

#pragma parameter PQ_OUTPUT "PQ output (ST.2084)" 1.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float PQ_OUTPUT;
} params;

#define PQ_OUTPUT params.PQ_OUTPUT

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

float pq_oetf(float L)
{
    // ST.2084 PQ OETF, input normalized to 0..1 for 0..10000 nits.
    const float m1 = 2610.0 / 16384.0;
    const float m2 = 2523.0 / 32.0;
    const float c1 = 3424.0 / 4096.0;
    const float c2 = 2413.0 / 128.0;
    const float c3 = 2392.0 / 128.0;

    float Lm1 = pow(clamp(L, 0.0, 1.0), m1);
    return pow((c1 + c2 * Lm1) / (1.0 + c3 * Lm1), m2);
}

vec3 pq_encode_from_100nits(vec3 linear)
{
    const float max_nits = 10000.0;
    const float unit_nits = 100.0;

    vec3 L = max(linear, vec3(0.0)) * (unit_nits / max_nits);
    return vec3(pq_oetf(L.r), pq_oetf(L.g), pq_oetf(L.b));
}

vec3 render_test_card(vec2 uv)
{
    float out_gray = 0.0;
    vec3 out_color = vec3(0.0);

    const float safe_gain = 0.164;
    const float peak_gain = 0.312;

    float row = floor(uv.y * 6.0);
    if (row < 1.0) {
        // 10-step gray ramp, linear
        float step_index = floor(uv.x * 10.0);
        out_gray = clamp(step_index / 9.0, 0.0, 1.0);
        out_color = vec3(out_gray);
    } else if (row < 2.0) {
        // 10-step HDR ramp, logarithmic, 100 nits to 10000 nits (1 to 100)
        float step_index = floor(uv.x * 10.0);
        float t = clamp(step_index / 9.0, 0.0, 1.0);
        out_gray = pow(100.0, t);
        out_color = vec3(out_gray);
    } else if (row < 3.0) {
        // Safe gain then peak gain swatches
        out_gray = (uv.x < 0.5) ? safe_gain : peak_gain;
        out_color = vec3(out_gray);
    } else if (row < 4.0) {
        // 10-step HDR ramp, linear, 100 nits to 10000 nits (1 to 100)
        float step_index = floor(uv.x * 10.0);
        out_gray = 1.0 + step_index * (99.0 / 9.0);
        out_color = vec3(out_gray);
    } else if (row < 5.0) {
        // SDR color bars at 0.75
        float bar = floor(uv.x * 7.0);
        if (bar < 1.0) {
            out_color = vec3(1.0);
        } else if (bar < 2.0) {
            out_color = vec3(1.0, 1.0, 0.0);
        } else if (bar < 3.0) {
            out_color = vec3(0.0, 1.0, 1.0);
        } else if (bar < 4.0) {
            out_color = vec3(0.0, 1.0, 0.0);
        } else if (bar < 5.0) {
            out_color = vec3(1.0, 0.0, 1.0);
        } else if (bar < 6.0) {
            out_color = vec3(1.0, 0.0, 0.0);
        } else {
            out_color = vec3(0.0, 0.0, 1.0);
        }
        out_color *= 0.75;
    } else if (row < 6.0) {
        // HDR color bars at 4.0 (linear)
        float bar = floor(uv.x * 7.0);
        if (bar < 1.0) {
            out_color = vec3(1.0);
        } else if (bar < 2.0) {
            out_color = vec3(1.0, 1.0, 0.0);
        } else if (bar < 3.0) {
            out_color = vec3(0.0, 1.0, 1.0);
        } else if (bar < 4.0) {
            out_color = vec3(0.0, 1.0, 0.0);
        } else if (bar < 5.0) {
            out_color = vec3(1.0, 0.0, 1.0);
        } else if (bar < 6.0) {
            out_color = vec3(1.0, 0.0, 0.0);
        } else {
            out_color = vec3(0.0, 0.0, 1.0);
        }
        out_color *= 4.0;
    }

    return out_color;
}

void main()
{
    vec3 color = render_test_card(vTexCoord);

    if (PQ_OUTPUT > 0.5) {
        color = pq_encode_from_100nits(color);
    }

    FragColor = vec4(color, 1.0);
}
