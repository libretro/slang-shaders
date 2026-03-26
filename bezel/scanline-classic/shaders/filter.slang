#version 450

// Filename: filter.slang
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

#pragma name Filter
#pragma format R16_SFLOAT

#include "common.inc"
#include "bandlimit.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/famicom.inc"

#pragma include_optional "../config/options.cfg"

#ifdef OPTION_DEBUG
#pragma parameter DEBUG_FILTER_HEADER " —— Debug Filter —— " 0.0 0.0 0.0 0.0
#pragma parameter FILTER_BANDLIMIT_BYPASS "Filter bandlimit bypass" 0.0 0.0 1.0 1.0
#pragma parameter FILTER_DPD_BYPASS "Filter DPD bypass" 0.0 0.0 1.0 1.0
#endif  // OPTION_DEBUG

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameHSize;
    uint FrameCount;
    float OriginalFPS;
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

#ifdef OPTION_DEBUG
    float FILTER_BANDLIMIT_BYPASS;
    float FILTER_DPD_BYPASS;
#endif

    float FILTER_BANDWIDTH;
    float FILTER_CUTOFF_ATTEN;
    float FILTER_DPD_AMOUNT_NS;
    float FILTER_DPD_CURVE;
    float FILTER_DPD_IN_MIN;
    float FILTER_DPD_IN_MAX;
} config;

#ifdef OPTION_DEBUG
#define FILTER_BANDLIMIT_BYPASS config.FILTER_BANDLIMIT_BYPASS
#define FILTER_DPD_BYPASS config.FILTER_DPD_BYPASS
#endif  // OPTION_DEBUG

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

#define FILTER_BANDWIDTH config.FILTER_BANDWIDTH
#define FILTER_CUTOFF_ATTEN config.FILTER_CUTOFF_ATTEN
#define FILTER_DPD_AMOUNT_NS config.FILTER_DPD_AMOUNT_NS
#define FILTER_DPD_CURVE config.FILTER_DPD_CURVE
#define FILTER_DPD_IN_MIN config.FILTER_DPD_IN_MIN
#define FILTER_DPD_IN_MAX config.FILTER_DPD_IN_MAX

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float sigma;
layout(location = 2) out float pixel_time_px;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    TimebaseConfig tb = compute_timebase(
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

    sigma = sigma_tb(tb, FILTER_BANDWIDTH, FILTER_CUTOFF_ATTEN);
    pixel_time_px = tb.pixel_time_px;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float sigma;
layout(location = 2) in float pixel_time_px;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float sample_r_linear_x(vec2 uv, vec4 outputSize, sampler2D source)
{
    float x = uv.x * outputSize.x - 0.5;
    float x0 = floor(x);
    float frac_x = x - x0;

    float x0c = clamp(x0, 0.0, outputSize.x - 1.0);
    float x1c = clamp(x0 + 1.0, 0.0, outputSize.x - 1.0);

    vec2 uv0 = vec2((x0c + 0.5) * outputSize.z, uv.y);
    vec2 uv1 = vec2((x1c + 0.5) * outputSize.z, uv.y);

    float s0 = texture(source, uv0).r;
    float s1 = texture(source, uv1).r;
    return mix(s0, s1, frac_x);
}

float dpd_sample_r(vec2 uv, vec4 outputSize, sampler2D source, float pixelTimePx)
{
    float raw = sample_r_linear_x(uv, outputSize, source);

#ifdef OPTION_DEBUG
    if (FILTER_DPD_BYPASS > 0.5)
        return raw;
#endif

    float inSpan = max(FILTER_DPD_IN_MAX - FILTER_DPD_IN_MIN, EPS);
    float normalized = clamp((raw - FILTER_DPD_IN_MIN) / inSpan, 0.0, 1.0);
    float nonlinear = pow(normalized, max(FILTER_DPD_CURVE, 0.01));

    float delaySec = FILTER_DPD_AMOUNT_NS * 1.0e-9 * nonlinear;
    float delayPx = delaySec / max(pixelTimePx, EPS);
    vec2 delayedUv = uv + vec2(-delayPx * outputSize.z, 0.0);

    return sample_r_linear_x(delayedUv, outputSize, source);
}

float bandlimit_convolve_gaussian_x_r(vec2 uv, vec4 outputSize, sampler2D source, float sigmaR, float pixelTimePx)
{
    vec2 uvPx = uv * outputSize.xy;

    float baseIndex = floor(uvPx.x + 0.5);
    float baseCenter = baseIndex + 0.5;
    float offsetX = uvPx.x - baseCenter;

    float baseX = baseCenter * outputSize.z;
    float baseY = (floor(uvPx.y) + 0.5) * outputSize.w;
    vec2 tex = vec2(baseX, baseY);

    float w0 = gaussian(offsetX, sigmaR);
    float color = w0 * dpd_sample_r(tex, outputSize, source, pixelTimePx);
    float wsum = w0;

    vec2 dx = vec2(outputSize.z, 0.0);

    for (int n = 1; n <= 8; ++n) {
        float nf = float(n);
        float wr = gaussian(nf - offsetX, sigmaR);
        float wl = gaussian(nf + offsetX, sigmaR);

        if (wr < FILTER_THRESHOLD && wl < FILTER_THRESHOLD)
            break;

        float pr = dpd_sample_r(tex + nf * dx, outputSize, source, pixelTimePx);
        float pl = dpd_sample_r(tex - nf * dx, outputSize, source, pixelTimePx);

        color += wr * pr + wl * pl;
        wsum += wr + wl;
    }

    return color / wsum;
}

void main()
{

#ifdef OPTION_DEBUG
    if (FILTER_BANDLIMIT_BYPASS > 0.5) {
        float sourceR = texture(Source, vTexCoord).r;
        FragColor = vec4(sourceR, 0.0, 0.0, 1.0);
        return;
    }
#endif

    float filteredR = bandlimit_convolve_gaussian_x_r(vTexCoord, config.OutputSize, Source, sigma, pixel_time_px);
    FragColor = vec4(filteredR, 0.0, 0.0, 1.0);
}
