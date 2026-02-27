#version 450

// Filename: digital-upsample.slang
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
// Digital RGB/YCbCr Upsampling stage
// ----------------------------
// Input: RGB/YCbCr video
// Output: Upsampled RGB/YCbCr video
//
// Performs upsampling with Kaiser-windowed sinc interpolation.
// Provides ~62 dB stopband rejection with ≤0.5 dB passband ripple.
// Uses zero-insertion approach optimized for integer scale factors.
// Tap count automatically determined based on scale factors.

#include "common.inc"
#include "digital.inc"
#include "window.inc"

#include "menus/parameters/digital-component.inc"
#include "menus/parameters/digital-upsample.inc"

#pragma name DigitalUpsample
#pragma format A2B10G10R10_UNORM_PACK32

#pragma parameter UPSAMPLE_BYPASS "Bypass upsampling stage" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;

    float WORKING_BITS;
    float UPSAMPLE_BYPASS;
    float UPSAMPLER_INPUT;
    float GAMMA_CORRECT_BLENDING;
} config;

#define UPSAMPLE_BYPASS config.UPSAMPLE_BYPASS
#define WORKING_BITS config.WORKING_BITS
#define KAISER_BETA 5.87  // Default value for ~62 dB stopband attenuation
#define TRANSITION_WIDTH 0.15  // Default transition width factor, max 0.5 dB passband ripple
#define UPSAMPLER_INPUT config.UPSAMPLER_INPUT
#define GAMMA_CORRECT_BLENDING config.GAMMA_CORRECT_BLENDING

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

// Helper functions for gamma correction
vec3 to_linear(vec3 c) {
    if (GAMMA_CORRECT_BLENDING < 0.5) {
        return c; // No gamma correction
    } else if (GAMMA_CORRECT_BLENDING < 1.5) {
        return c * c; // Fast: square
    } else {
        return sdr_linear(c); // Accurate
    }
}

vec3 to_gamma(vec3 c) {
    if (GAMMA_CORRECT_BLENDING < 0.5) {
        return c; // No gamma correction
    } else if (GAMMA_CORRECT_BLENDING < 1.5) {
        return sqrt(c); // Fast: sqrt
    } else {
        return sdr_gamma(c); // Accurate
    }
}

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
    
    // Compute scale factors (truncate to integers for zero-insertion)
    scale = floor(config.OutputSize.xy / config.SourceSize.xy);
    
    // Normalized cutoff frequency: always 0.5 for zero-insertion upsampling
    fc_norm = vec2(0.5);
    
    // Improved Kaiser tap count formula incorporating scale factor
    // Derived from: N = (A_s - 13) / (14.6 * (Δf / f_s))
    // where transition band Δf/f_s = TRANSITION_WIDTH / scale
    // Therefore: N = (A_s - 13) * scale / (14.6 * TRANSITION_WIDTH)
    // This ensures tap count scales linearly with upsampling ratio for consistent quality
    float A_s = 8.0 + 2.285 * KAISER_BETA;  // Stopband attenuation (dB)
    const float KAISER_DESIGN_CONST = 14.6;  // Standard Kaiser design constant
    
    vec2 taps_calc = (A_s - 13.0) * scale / (KAISER_DESIGN_CONST * TRANSITION_WIDTH);
    
    // Round to odd numbers for symmetric filtering
    taps.x = ceil(taps_calc.x);
    if (mod(taps.x, 2.0) == 0.0) taps.x += 1.0;
    taps.y = ceil(taps_calc.y);
    if (mod(taps.y, 2.0) == 0.0) taps.y += 1.0;
    
    // Clamp to reasonable range
    taps = clamp(taps, vec2(5.0), vec2(65.0));
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
    // Bypass check
    if (UPSAMPLE_BYPASS > 0.5) {
        FragColor = texture(Source, vTexCoord);
        return;
    }
    
    // Check if upsampling is needed
    if (scale.x < 1.001 && scale.y < 1.001) {
        // No upsampling needed: direct pass-through
        FragColor = texture(Source, vTexCoord);
        return;
    }

    // Map this output pixel into source space
    vec2 output_pixel = vTexCoord * config.OutputSize.xy;
    vec2 source_pixel = output_pixel / scale;
    
    // Base source index and fractional phase (source-space)
    float src_idx = source_pixel.x;
    float base_idx = floor(src_idx);
    float frac = src_idx - (base_idx + 0.5);  // phase relative to source pixel center
    
    // Source pixel center for sampling
    vec2 src_center = vec2(base_idx + 0.5, floor(source_pixel.y) + 0.5);
    
    // Apply separable 2D Kaiser-windowed sinc filtering
    vec3 sum = vec3(0.0);
    float weight_sum = 0.0;
    
    int max_tap_half_x = int(floor(taps.x * 0.5));
    int scale_x = int(scale.x);

    // Center tap first
    {
        float window0;
        float weight0 = sinc_lowpass_kaiser(-frac, fc_norm.x, taps.x, KAISER_BETA, window0);
        
        vec2 sample_coord = src_center * config.SourceSize.zw;
        vec3 color0;
        if (sample_coord.x >= 0.0 && sample_coord.x <= 1.0) {
            color0 = texture(Source, sample_coord).rgb;
        } else {
            // Out of bounds: use (0, 0.5, 0.5) for YCC, (0, 0, 0) for RGB
            color0 = (UPSAMPLER_INPUT > 0.5) ? vec3(0.0, 0.5, 0.5) : vec3(0.0);
        }
        
        if (UPSAMPLER_INPUT < 0.5)
            color0 = to_linear(color0);
        sum += color0 * weight0;
        weight_sum += weight0;
    }

    // Iterate all integer source offsets within the tap width
    for (int dx = 1; dx <= 16; ++dx) {
        if (dx > max_tap_half_x)
            break;

        float fx_pos = float(dx) - frac;
        float fx_neg = float(-dx) - frac;

        float window_pos;
        float window_neg;
        float weight_pos = sinc_lowpass_kaiser(fx_pos, fc_norm.x, taps.x, KAISER_BETA, window_pos);
        float weight_neg = sinc_lowpass_kaiser(fx_neg, fc_norm.x, taps.x, KAISER_BETA, window_neg);

        if (window_pos < FILTER_THRESHOLD && window_neg < FILTER_THRESHOLD)
            break;

        if (window_pos >= FILTER_THRESHOLD) {
            vec2 sample_pos = src_center + vec2(float(dx), 0.0);
            vec2 sample_coord = sample_pos * config.SourceSize.zw;
            vec3 color;
            if (sample_coord.x >= 0.0 && sample_coord.x <= 1.0) {
                color = texture(Source, sample_coord).rgb;
            } else {
                // Out of bounds: use (0, 0.5, 0.5) for YCC, (0, 0, 0) for RGB
                color = (UPSAMPLER_INPUT > 0.5) ? vec3(0.0, 0.5, 0.5) : vec3(0.0);
            }
            if (UPSAMPLER_INPUT < 0.5)
                color = to_linear(color);
            sum += color * weight_pos;
            weight_sum += weight_pos;
        }

        if (window_neg >= FILTER_THRESHOLD) {
            vec2 sample_pos = src_center + vec2(float(-dx), 0.0);
            vec2 sample_coord = sample_pos * config.SourceSize.zw;
            vec3 color;
            if (sample_coord.x >= 0.0 && sample_coord.x <= 1.0) {
                color = texture(Source, sample_coord).rgb;
            } else {
                // Out of bounds: use (0, 0.5, 0.5) for YCC, (0, 0, 0) for RGB
                color = (UPSAMPLER_INPUT > 0.5) ? vec3(0.0, 0.5, 0.5) : vec3(0.0);
            }
            if (UPSAMPLER_INPUT < 0.5)
                color = to_linear(color);
            sum += color * weight_neg;
            weight_sum += weight_neg;
        }
    }
    
    // Normalize to preserve gain
    vec3 result = sum / max(weight_sum, EPS);

    // For RGB input, apply gamma correction if needed
    if (UPSAMPLER_INPUT < 0.5) {
        result = to_gamma(result);
    }

    // Quantize to working bit depth
    int bits = int(WORKING_BITS + 0.5);

    // Quantize to working bit depth (6, 8, or 10 bits)
    if (bits == 6) {
        result = quantize_6bit(result);
    } else if (bits == 8) {
        result = quantize_8bit(result);
    } else if (bits == 10) {
        result = quantize_10bit(result);
    } else {
        result = quantize(result, bits);    
    }
    
    FragColor = vec4(result, 1.0);
}