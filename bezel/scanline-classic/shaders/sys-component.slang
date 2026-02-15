#version 450

// Filename: sys-component.slang
//
// Copyright (C) 2025-2026 W. M. Martinez
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
// System-level component amplifier and filter
// -------------------------------
// Input: Voltage (RGB color space)
// Output: Voltage (YC color space)
//
// Encodes RGB into a chosen luma-chroma color space (YIQ / YPbPr / YUV / YDbDr / YCbCr),
// then optionally bandlimits each component with a horizontal Gaussian (lobe technique) to
// approximate analog system bandwidth. Component-wise SYS_GAIN/SYS_BIAS are applied after filtering.
//
// Notes:
// - YDbDr is implemented by first computing YUV, then scaling chroma:
//     Db = (1.333 / 0.436) * U  ≈  3.05688 * U
//     Dr = (-1.333 / 0.615) * V ≈ -2.16829 * V
// - Filtering is performed in the color space domain, not RGB, to better emulate analog chains.
// - Bypasses:
//     SYS_COMPONENT_BYPASS          -> output source RGB unmodified (skip color conversion + filter)
//     SYS_COMPONENT_FILTER_BYPASS   -> convert to selected color space and apply SYS_GAIN/BIAS, but skip filtering

#include "common.inc"
#include "color.inc"
#include "modulation.inc"

#include "menus/parameters/sys-component.inc"
#include "menus/parameters/sys-timing.inc"

#pragma name SysComponent
#pragma format R16G16B16A16_SFLOAT

#pragma parameter SYS_COMPONENT_BYPASS "Bypass system component stage" 0.0 0.0 1.0 1.0
#pragma parameter SYS_COMPONENT_FILTER_BYPASS "Bypass system component filter" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameHSize;
    uint FrameCount;
    float OriginalFPS;

    // Timing parameters for timebase computation
    float V_FREQ_MODE;
    float V_FREQ;
    float SHORTEN_ODD_FIELD_TIME;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float H_BLANK_FUZZ;

    // Color model selection
    float YC_MODEL;

    // Per-component analog bandlimit (MHz/dB), mapped via sigma601
    float SYS_BANDWIDTH_Y;
    float SYS_BANDWIDTH_U;
    float SYS_BANDWIDTH_V;
    float SYS_CUTOFF_ATTEN_Y;
    float SYS_CUTOFF_ATTEN_U;
    float SYS_CUTOFF_ATTEN_V;
} config;

// Short-hand macros

#define V_FREQ_MODE config.V_FREQ_MODE
#define V_FREQ config.V_FREQ
#define SHORTEN_ODD_FIELD_TIME config.SHORTEN_ODD_FIELD_TIME
#define SC_FREQ_MODE config.SC_FREQ_MODE
#define SC_FREQ config.SC_FREQ
#define PIXEL_CLOCK_MODE config.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK config.PIXEL_CLOCK
#define H_FREQ_MODE config.H_FREQ_MODE
#define H_FREQ config.H_FREQ
#define H_BLANK_FUZZ config.H_BLANK_FUZZ

#define YC_MODEL config.YC_MODEL

#define SYS_BANDWIDTH_Y config.SYS_BANDWIDTH_Y
#define SYS_BANDWIDTH_U config.SYS_BANDWIDTH_U
#define SYS_BANDWIDTH_V config.SYS_BANDWIDTH_V
#define SYS_CUTOFF_ATTEN_Y config.SYS_CUTOFF_ATTEN_Y
#define SYS_CUTOFF_ATTEN_U config.SYS_CUTOFF_ATTEN_U
#define SYS_CUTOFF_ATTEN_V config.SYS_CUTOFF_ATTEN_V

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;

    // Bypasses
    float SYS_COMPONENT_BYPASS;        // 0 or 1
    float SYS_COMPONENT_FILTER_BYPASS; // 0 or 1

    // Post-filter gain/bias per component
    float SYS_GAIN_Y;
    float SYS_GAIN_U;
    float SYS_GAIN_V;
    float SYS_BIAS_Y;
    float SYS_BIAS_U;
    float SYS_BIAS_V;
} global;

#define SYS_COMPONENT_BYPASS global.SYS_COMPONENT_BYPASS
#define SYS_COMPONENT_FILTER_BYPASS global.SYS_COMPONENT_FILTER_BYPASS

#define SYS_GAIN_Y global.SYS_GAIN_Y
#define SYS_GAIN_U global.SYS_GAIN_U
#define SYS_GAIN_V global.SYS_GAIN_V
#define SYS_BIAS_Y global.SYS_BIAS_Y
#define SYS_BIAS_U global.SYS_BIAS_U
#define SYS_BIAS_V global.SYS_BIAS_V

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec3 gain;
layout(location = 2) out vec3 bias;
layout(location = 3) out vec3 sigma;
layout(location = 4) out TimebaseConfig tb;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Precompute per-component sigmas (in texels) from MHz/dB specs.
    // We reuse the vec3 return as (Y, U/Db, V/Dr).
    tb = compute_timebase(
        config.FrameCount,
        vTexCoord,
        config.OriginalSize.xy,
        config.OutputSize.xy,
        config.FrameHSize.x,
        config.OriginalFPS,
        SC_FREQ_MODE,
        SC_FREQ,
        PIXEL_CLOCK,
        PIXEL_CLOCK_MODE,
        H_FREQ_MODE,
        H_FREQ,
        V_FREQ_MODE,
        V_FREQ,
        H_BLANK_FUZZ,
        SHORTEN_ODD_FIELD_TIME);

    sigma.x = sigma_tb(tb, SYS_BANDWIDTH_Y, SYS_CUTOFF_ATTEN_Y);
    sigma.y = sigma_tb(tb, SYS_BANDWIDTH_U, SYS_CUTOFF_ATTEN_U);
    sigma.z = sigma_tb(tb, SYS_BANDWIDTH_V, SYS_CUTOFF_ATTEN_V);

    // Amplifier
    gain = vec3(
        pow(10.0, SYS_GAIN_Y / 20.0),
        pow(10.0, SYS_GAIN_U / 20.0),
        pow(10.0, SYS_GAIN_V / 20.0));
    bias = vec3(
        SYS_BIAS_Y * 10e-3,
        SYS_BIAS_U * 10e-3,
        SYS_BIAS_V * 10e-3);
}

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec3 gain;
layout(location = 2) in vec3 bias;
layout(location = 3) in vec3 sigma;
layout(location = 4) in TimebaseConfig tb;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Full stage bypass: pass through RGB
    if (SYS_COMPONENT_BYPASS >= 1.0) {
        FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
        return;
    }

    // Filter bypass: convert once and apply SYS_GAIN/BIAS only
    if (SYS_COMPONENT_FILTER_BYPASS >= 1.0) {
        vec3 yc = rgb_to_luma_chroma(texture(Source, vTexCoord).rgb, YC_MODEL);
        yc = gain * (yc + bias);
        FragColor = vec4(yc, 1.0);
        return;
    }

    // Horizontal coordinate handling using nearest pixel center (no vertical shift)
    vec2 UV  = vTexCoord * config.OutputSize.xy;
    float baseIndex = floor(UV.x + 0.5);       // round to nearest integer pixel index
    float baseCenter = baseIndex + 0.5;        // pixel center in pixel units
    float Ax = UV.x - baseCenter;              // offset from center in [-0.5, 0.5]
    vec2 Tex = vec2(baseCenter * config.OutputSize.z,
                    (floor(UV.y) + 0.5) * config.OutputSize.w);
    vec2 dx  = vec2(config.OutputSize.z, 0.0); // one texel to the right

    // Accumulators and weights for Y, U/Db, V/Dr
    vec3 accum = vec3(0.0);
    vec3 wsum  = vec3(0.0);

    // Center sample
    vec3 rgb0 = texture(Source, Tex).rgb;
    vec3 yc_c = rgb_to_luma_chroma(rgb0, YC_MODEL);

    float wy = gaussian(Ax, sigma.x);
    float wu = gaussian(Ax, sigma.y);
    float wv = gaussian(Ax, sigma.z);

    accum += vec3(wy * yc_c.x, wu * yc_c.y, wv * yc_c.z);
    wsum  += vec3(wy, wu, wv);

    // Symmetric lobes with early exit
    for (int n = 1; n <= 16; ++n) {
        float nf = float(n);
        // Symmetric distances: right = n - Ax, left = n + Ax
        float wy_r = gaussian(nf - Ax, sigma.x);
        float wy_l = gaussian(nf + Ax, sigma.x);
        float wu_r = gaussian(nf - Ax, sigma.y);
        float wu_l = gaussian(nf + Ax, sigma.y);
        float wv_r = gaussian(nf - Ax, sigma.z);
        float wv_l = gaussian(nf + Ax, sigma.z);

        // Early out if all components negligible on both sides
        if (wy_r < FILTER_THRESHOLD && wy_l < FILTER_THRESHOLD &&
            wu_r < FILTER_THRESHOLD && wu_l < FILTER_THRESHOLD &&
            wv_r < FILTER_THRESHOLD && wv_l < FILTER_THRESHOLD)
            break;

        vec3 rgbr = texture(Source, Tex + nf * dx).rgb;
        vec3 rgbl = texture(Source, Tex - nf * dx).rgb;

        vec3 yc_r = rgb_to_luma_chroma(rgbr, YC_MODEL);
        vec3 yc_l = rgb_to_luma_chroma(rgbl, YC_MODEL);

        // Accumulate right and left for each component
        accum.x += wy_r * yc_r.x + wy_l * yc_l.x;
        accum.y += wu_r * yc_r.y + wu_l * yc_l.y;
        accum.z += wv_r * yc_r.z + wv_l * yc_l.z;

        wsum.x  += wy_r + wy_l;
        wsum.y  += wu_r + wu_l;
        wsum.z  += wv_r + wv_l;
    }

    // Normalize and apply per-component SYS_GAIN/SYS_BIAS
    vec3 outyc = accum / max(wsum, vec3(EPS));
    outyc = gain * (outyc + bias);

    // Emit in the selected luma-chroma space
    FragColor = vec4(outyc, 1.0);
}