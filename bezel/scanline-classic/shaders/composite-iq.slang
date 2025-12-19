#version 450

// Filename: composite-iq.slang
//
// Copyright (C) 2025 W. M. Martinez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// Analytic baseband extraction: composite → I + jQ (R16G16_SFLOAT)
// -----------------------------------------------------------------
// Input: Composite baseband (from composite-mod.slang)
// Output: Analytic baseband (I = R, Q = G)

#include "common.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/sys-encode.inc"

#pragma parameter HILBERT_BYPASS "Bypass Hilbert transform (I only)" 0.0 0.0 1.0 1.0

#pragma name CompositeIQ
#pragma format R16G16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    float HILBERT_BYPASS;
} config;

#define HILBERT_BYPASS config.HILBERT_BYPASS

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

// Hilbert transform taps (fixed, odd-only). Windowing is implicit by truncation.
const int HILBERT_TAPS = 31; // odd length preferred for Type III FIR

// Minimal vertex stage: passes through texture coordinates
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord_out;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord_out = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord_in;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    if (HILBERT_BYPASS > 0.5) {
        vec3 rgb = texture(Source, vTexCoord_in).rgb;
        FragColor = vec4(rgb.r, 0.0, 0.0, 1.0);
        return;
    }

    vec2 UV = vTexCoord_in * config.OutputSize.xy;
    float baseCenter = floor(UV.x) + 0.5;
    float Ax = UV.x - baseCenter;
    vec2 Tex = vec2(baseCenter * config.OutputSize.z, (floor(UV.y) + 0.5) * config.OutputSize.w);
    vec2 dx = vec2(config.OutputSize.z, 0.0);

    float i_analytic = texture(Source, Tex).r;
    float q_analytic = 0.0;
    float q_wsum = 0.0;

    for (int n = 1; n <= 31; n += 2) {
        float nf = float(n);

        // Right sample
        float comp_r = texture(Source, Tex + nf * dx).r;
        float pos_r = nf - Ax;
        float h_r = (2.0 / PI) * pow(sin(PI * pos_r * 0.5), 2.0) / pos_r;

        // Left sample
        float comp_l = texture(Source, Tex - nf * dx).r;
        float pos_l = -nf - Ax;
        float h_l = (2.0 / PI) * pow(sin(PI * pos_l * 0.5), 2.0) / pos_l;
        
        q_analytic += h_r * comp_r + h_l * comp_l;
        q_wsum += abs(h_r) + abs(h_l);

        // Early exit once coefficients fall below significance
        if (abs(h_r) < FILTER_THRESHOLD && abs(h_l) < FILTER_THRESHOLD)
            break;
    }
    q_analytic /= max(q_wsum, EPS);

    FragColor = vec4(i_analytic, q_analytic, 0.0, 1.0);
}
