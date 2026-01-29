#version 450

// Filename: decimate.slang
//
// Copyright (C) 2026 W. M. Martinez
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
// 0.5x horizontal antialiasing downsampler using Blackman-Harris 4-term windowed sinc.
// Higher stopband rejection (~92 dB) than Hamming for aggressive decimation.
// Input/Output are treated as analog (no quantization).
// 1D filter along X to limit bandwidth prior to decimation.
//
// Cutoff frequency set to fc = 0.5 * scale = 0.25 cycles/sample
// for uniform 0.5 downsampling.

#include "common.inc"
#include "window.inc"

#pragma name Decimate
#pragma format R16G16B16A16_SFLOAT

#pragma parameter BYPASS_DECIMATE_FILTER "Bypass decimation filter" 0.0 0.0 1.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

layout(push_constant) uniform Push
{
    vec4 SourceSize;   // xy = size, zw = 1/size
    vec4 OutputSize;   // xy = size, zw = 1/size
    float BYPASS_DECIMATE_FILTER;
} config;

#define BYPASS_DECIMATE_FILTER config.BYPASS_DECIMATE_FILTER

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 scale;
layout(location = 2) out vec2 fc_norm;
layout(location = 3) out vec2 taps;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Downsample ratio (assumed 0.5 horizontally; vertical stays 1.0)
    scale = config.OutputSize.xy / config.SourceSize.xy;

    // BH4 window: stronger stopband; modest width tuned for 0.5x decimation
    taps = vec2(41.0, 0.0);

    // Guarded cutoff: lower fc slightly to ensure ≥48 dB
    // attenuation at the decimation boundary (0.5 * scale.x).
    // BH4 half mainlobe width ≈ 2/N cycles/sample.
    const float GUARD_FRAC = 0.45;
    float half_width = 2.0 / taps.x;
    float fc = max(0.0, 0.5 * scale.x - GUARD_FRAC * half_width);
    fc_norm = vec2(fc, 0.0);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 scale;
layout(location = 2) in vec2 fc_norm;
layout(location = 3) in vec2 taps;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // If no horizontal downsampling (defensive), pass-through
    if (scale.x >= 0.999 || BYPASS_DECIMATE_FILTER > 0.5) {
        FragColor = texture(Source, vTexCoord);
        return;
    }

    // Map this output fragment to source pixel space
    vec2 out_px = vTexCoord * config.OutputSize.xy;
    vec2 src_px = out_px / scale;  // e.g., scale.x = 0.5 → src_px.x = out_px.x * 2

    // Horizontal source pixel center and fractional phase; vertical pass-through
    float base_x = floor(src_px.x);
    float frac_x = src_px.x - (base_x + 0.5);
    vec2 src_center = vec2(base_x + 0.5, floor(src_px.y) + 0.5);

    vec3 sum = vec3(0.0);
    float wsum = 0.0;

    int hx = int(floor(taps.x * 0.5));

    // Center tap first
    {
        float w_env0;
        float w0 = sinc_lowpass_bh4(-frac_x, fc_norm.x, taps.x, w_env0);
        vec3 c0 = texture(Source, src_center * config.SourceSize.zw).rgb;
        sum += c0 * w0;
        wsum += w0;
    }

    // Side lobes: fixed iteration cap with early break when beyond hx or envelope dies
    for (int dx = 1; dx <= 20; ++dx) {
        if (dx > hx)
            break;

        float fx_pos = float(dx) - frac_x;
        float fx_neg = float(-dx) - frac_x;

        float w_env_pos;
        float w_env_neg;
        float w_pos = sinc_lowpass_bh4(fx_pos, fc_norm.x, taps.x, w_env_pos);
        float w_neg = sinc_lowpass_bh4(fx_neg, fc_norm.x, taps.x, w_env_neg);

        if (w_env_pos < FILTER_THRESHOLD && w_env_neg < FILTER_THRESHOLD)
            break;

        if (w_env_pos >= FILTER_THRESHOLD) {
            vec2 sample_pos = src_center + vec2(float(dx), 0.0);
            vec2 coord = clamp(sample_pos * config.SourceSize.zw, vec2(0.0), vec2(1.0));
            vec3 c = texture(Source, coord).rgb;
            sum += c * w_pos;
            wsum += w_pos;
        }

        if (w_env_neg >= FILTER_THRESHOLD) {
            vec2 sample_pos = src_center + vec2(float(-dx), 0.0);
            vec2 coord = clamp(sample_pos * config.SourceSize.zw, vec2(0.0), vec2(1.0));
            vec3 c = texture(Source, coord).rgb;
            sum += c * w_neg;
            wsum += w_neg;
        }
    }

    vec3 result = sum / max(wsum, EPS);
    FragColor = vec4(result, 1.0);
}
