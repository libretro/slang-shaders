#version 450

// Filename: digital-ycc-filter.slang
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
// Digital YCC lowpass filter for baseband YCbCr
// --------------------------------------------
// Input: baseband YCbCr (Y in R, Cb in G, Cr in B)
// Output: baseband YCbCr (filtered)
//
// Applies Gaussian lowpass filters per channel with decimation-based
// bandwidth control. Operates horizontally on already-demodulated data.

#include "common.inc"
#include "digital.inc"
#include "window.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/digital-component.inc"

#pragma name DigitalYCCFilter
#pragma format A2B10G10R10_UNORM_PACK32

#pragma parameter DIGITAL_YC_FILTER_BYPASS "Bypass digital YC filter" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameHSize;
    uint FrameCount;
    float OriginalFPS;
    float WORKING_BITS;
    float DIGITAL_YC_FILTER_BYPASS;
    float DIGITAL_Y_FILTER_DECIMATION;
    float DIGITAL_Cb_FILTER_DECIMATION;
    float DIGITAL_Cr_FILTER_DECIMATION;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float V_FREQ_MODE;
    float V_FREQ;
    float SHORTEN_ODD_FIELD_TIME;
    float H_BLANK_FUZZ;
} config;

#define DIGITAL_YC_FILTER_BYPASS config.DIGITAL_YC_FILTER_BYPASS
#define WORKING_BITS config.WORKING_BITS
#define DIGITAL_Y_FILTER_DECIMATION config.DIGITAL_Y_FILTER_DECIMATION
#define DIGITAL_Cb_FILTER_DECIMATION config.DIGITAL_Cb_FILTER_DECIMATION
#define DIGITAL_Cr_FILTER_DECIMATION config.DIGITAL_Cr_FILTER_DECIMATION
#define SC_FREQ_MODE config.SC_FREQ_MODE
#define SC_FREQ config.SC_FREQ
#define PIXEL_CLOCK_MODE config.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK config.PIXEL_CLOCK
#define H_FREQ_MODE config.H_FREQ_MODE
#define H_FREQ config.H_FREQ
#define V_FREQ_MODE config.V_FREQ_MODE
#define V_FREQ config.V_FREQ
#define SHORTEN_ODD_FIELD_TIME config.SHORTEN_ODD_FIELD_TIME
#define H_BLANK_FUZZ config.H_BLANK_FUZZ

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float sigma_cb;
layout(location = 2) out float sigma_cr;
layout(location = 3) out float sigma_y;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    
    // Compute complete timebase configuration
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
    
    // Baseband lowpass widths from decimation (MHz)
    const float FIXED_ATTEN_DB = 3.0;

    float cutoff_freq_cb_mhz = (0.5 / DIGITAL_Cb_FILTER_DECIMATION) / (tb.pixel_time_px * 1.0e6);
    float cutoff_freq_cr_mhz = (0.5 / DIGITAL_Cr_FILTER_DECIMATION) / (tb.pixel_time_px * 1.0e6);
    float cutoff_freq_y_mhz  = (0.5 / DIGITAL_Y_FILTER_DECIMATION)  / (tb.pixel_time_px * 1.0e6);

    sigma_cb = sigma_tb(tb, max(cutoff_freq_cb_mhz, 1.0e-6), FIXED_ATTEN_DB);
    sigma_cr = sigma_tb(tb, max(cutoff_freq_cr_mhz, 1.0e-6), FIXED_ATTEN_DB);
    sigma_y  = sigma_tb(tb, max(cutoff_freq_y_mhz,  1.0e-6), FIXED_ATTEN_DB);
}

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float sigma_cb;
layout(location = 2) in float sigma_cr;
layout(location = 3) in float sigma_y;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    if (DIGITAL_YC_FILTER_BYPASS > 0.5) {
        FragColor = texture(Source, vTexCoord);
        return;
    }

    // Skip filtering at decimation factor 1 (bypass)
    if (DIGITAL_Cb_FILTER_DECIMATION <= 1.0 && DIGITAL_Cr_FILTER_DECIMATION <= 1.0 && DIGITAL_Y_FILTER_DECIMATION <= 1.0) {
        FragColor = texture(Source, vTexCoord);
        return;
    }

    // Compute sub-pixel offset from pixel center (matching composite-prefilter approach)
    vec2 UV = vTexCoord * config.OutputSize.xy;
    float baseIndex = floor(UV.x);
    float baseCenter = baseIndex + 0.5;
    float Ax = UV.x - baseCenter;
    
    // Sample at pixel center
    vec2 Tex = vec2(
        baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);
    vec2 dx_vec = vec2(config.OutputSize.z, 0.0);
    
    vec3 pixel0 = texture(Source, Tex).rgb;
    
    // Initialize accumulators for both Y and C channels
    float luma_filtered = 0.0;
    float cb_filtered = 0.0;
    float cr_filtered = 0.0;
    float weight_sum_y = 0.0;
    float weight_sum_cb = 0.0;
    float weight_sum_cr = 0.0;
    
    // Process center tap for both channels
    bool filter_y = DIGITAL_Y_FILTER_DECIMATION > 1.0;
    bool filter_cb = DIGITAL_Cb_FILTER_DECIMATION > 1.0;
    bool filter_cr = DIGITAL_Cr_FILTER_DECIMATION > 1.0;
    
    if (filter_y) {
        float g_y0 = gaussian(Ax, sigma_y);
        luma_filtered += g_y0 * pixel0.r;
        weight_sum_y += g_y0;
    } else {
        luma_filtered = pixel0.r;
    }
    
    float g_cb0 = gaussian(Ax, sigma_cb);
    float g_cr0 = gaussian(Ax, sigma_cr);
    cb_filtered += g_cb0 * pixel0.g;
    cr_filtered += g_cr0 * pixel0.b;
    weight_sum_cb += g_cb0;
    weight_sum_cr += g_cr0;
    
    // Combined loop for both Y and C processing
    for (int n = 1; n <= 16; ++n) {
        float nf = float(n);
        
        // Compute Gaussian weights for both channels
        float g_y_r  = gaussian(nf - Ax, sigma_y);
        float g_y_l  = gaussian(nf + Ax, sigma_y);
        float g_cb_r = gaussian(nf - Ax, sigma_cb);
        float g_cb_l = gaussian(nf + Ax, sigma_cb);
        float g_cr_r = gaussian(nf - Ax, sigma_cr);
        float g_cr_l = gaussian(nf + Ax, sigma_cr);

        // Early exit when all channels below threshold
        bool y_done  = !filter_y || (g_y_r  < FILTER_THRESHOLD && g_y_l  < FILTER_THRESHOLD);
        bool cb_done = !filter_cb || (g_cb_r < FILTER_THRESHOLD && g_cb_l < FILTER_THRESHOLD);
        bool cr_done = !filter_cr || (g_cr_r < FILTER_THRESHOLD && g_cr_l < FILTER_THRESHOLD);

        if (y_done && cb_done && cr_done)
            break;
        
        // Sample with boundary checks - treat out-of-bounds as neutral (0.5 for YCC)
        vec2 tex_right = Tex + nf * dx_vec;
        vec2 tex_left = Tex - nf * dx_vec;
        
        vec4 sample_right = (tex_right.x >= 0.0 && tex_right.x <= 1.0) 
            ? texture(Source, tex_right) 
            : vec4(0.0, 0.5, 0.5, 1.0);
        vec4 sample_left = (tex_left.x >= 0.0 && tex_left.x <= 1.0) 
            ? texture(Source, tex_left) 
            : vec4(0.0, 0.5, 0.5, 1.0);
        
        // Process Y channel
        if (!y_done) {
            luma_filtered += g_y_r * sample_right.r + g_y_l * sample_left.r;
            weight_sum_y += g_y_r + g_y_l;
        }
        
        // Process Cb channel
        if (!cb_done) {
            cb_filtered += g_cb_r * sample_right.g + g_cb_l * sample_left.g;
            weight_sum_cb += g_cb_r + g_cb_l;
        }

        // Process Cr channel
        if (!cr_done) {
            cr_filtered += g_cr_r * sample_right.b + g_cr_l * sample_left.b;
            weight_sum_cr += g_cr_r + g_cr_l;
        }
    }
    
    // Normalize results
    if (filter_y && weight_sum_y > 0.0)
        luma_filtered /= weight_sum_y;
    
    if (filter_cb && weight_sum_cb > 0.0)
        cb_filtered /= weight_sum_cb;
    else if (!filter_cb)
        cb_filtered = pixel0.g;

    if (filter_cr && weight_sum_cr > 0.0)
        cr_filtered /= weight_sum_cr;
    else if (!filter_cr)
        cr_filtered = pixel0.b;

    // Quantize to working bit depth
    int bits = int(WORKING_BITS + 0.5);

    vec3 ycbcr = vec3(luma_filtered, cb_filtered, cr_filtered);

    // Quantize to working bit depth (6, 8, or 10 bits)
    if (bits == 6) {
        ycbcr = quantize_6bit(ycbcr);
    } else if (bits == 8) {
        ycbcr = quantize_8bit(ycbcr);
    } else if (bits == 10) {
        ycbcr = quantize_10bit(ycbcr);
    } else {
        ycbcr = quantize(ycbcr, bits);
    }

    // Output: filtered Y in R, filtered Cb in G, filtered Cr in B
    FragColor = vec4(luma_filtered, cb_filtered, cr_filtered, 1.0);
}
