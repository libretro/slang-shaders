#version 450

// Filename: composite-prefilter.slang
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
// Composite separation filter (without initial modulation)
// ----------------------------------------------------------------
// Input: Composite baseband signal (from iq-demod.slang)
// Output: Separated Y and C signals + original composite passthrough

#include "common.inc"
#include "modulation.inc"
#include "bandlimit.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/sys-encode.inc"
#include "menus/parameters/composite.inc"

#pragma parameter BYPASS_PREFILTER "Bypass prefilter (off, on)" 0.0 0.0 1.0 1.0
#pragma parameter COMB_ADJUST_X "Comb filter phase adjustment X (texels)" 0.0 -10.0 10.0 0.01
#pragma parameter COMB_ADJUST_Y "Comb filter phase adjustment Y (texels)" 0.0 -10.0 10.0 0.01

#pragma name CompositePreFilter
#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OriginalFPS;
    float BYPASS_PREFILTER;
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
    float COLOR_FILTER_MODE;
    float NOTCH_WIDTH;
    float NOTCH_ATTEN_DB;
    float BANDPASS_WIDTH;
    float BANDPASS_ATTEN_DB;
    float BW_MODE;
    float COMB_FILTER_LUMA_ADAPT;
    float COMB_FILTER_CHROMA_ADAPT;
    float COMB_ADJUST_X;
    float COMB_ADJUST_Y;
} config;

#define COMB_ADJUST_X config.COMB_ADJUST_X
#define COMB_ADJUST_Y config.COMB_ADJUST_Y

#define BYPASS_PREFILTER config.BYPASS_PREFILTER

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

#define COLOR_FILTER_MODE config.COLOR_FILTER_MODE

#define NOTCH_WIDTH config.NOTCH_WIDTH
#define NOTCH_ATTEN_DB config.NOTCH_ATTEN_DB

#define BANDPASS_ATTEN_DB config.BANDPASS_ATTEN_DB
#define BANDPASS_WIDTH config.BANDPASS_WIDTH

#define COMB_FILTER_LUMA_ADAPT config.COMB_FILTER_LUMA_ADAPT
#define COMB_FILTER_CHROMA_ADAPT config.COMB_FILTER_CHROMA_ADAPT

#define BW_MODE config.BW_MODE

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float sigma_bp;
layout(location = 2) out float sigma_notch;
layout(location = 3) out TimebaseConfig tb;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    tb = compute_timebase(
        config.FrameCount,
        vTexCoord,
        config.OriginalSize.xy,
        config.OutputSize.xy,
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
 
    // Enforce minimum edge attenuation to guarantee ~48 dB DC rejection for chroma
    const float TARGET_DC_ATTEN_DB = 48.0;
    float f_sc_mhz = tb.sc_freq_hz * 1.0e-6; // Hz → MHz
    float bw_to_fsc_ratio = BANDPASS_WIDTH / (2.0 * max(f_sc_mhz, 1e-6));
    float bandpass_edge_atten_min = TARGET_DC_ATTEN_DB * bw_to_fsc_ratio * bw_to_fsc_ratio;
    float bandpass_edge_atten_db = max(bandpass_edge_atten_min, BANDPASS_ATTEN_DB);
    bandpass_edge_atten_db = clamp(bandpass_edge_atten_db, 0.1, 20.0);

    sigma_bp = sigma_tb(tb, max(BANDPASS_WIDTH, 1e-6), bandpass_edge_atten_db);
    sigma_notch = sigma_tb(tb, NOTCH_WIDTH, NOTCH_ATTEN_DB);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float sigma_bp;
layout(location = 2) in float sigma_notch;
layout(location = 3) in TimebaseConfig tb;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Compute correlation coefficient between two samples
// Simple point correlation: returns similarity in [0, 1]
float compute_point_correlation(float ref, float cmp) {
    float diff = abs(ref - cmp);
    float sum = ref + cmp;
    return 1.0 - (diff / max(sum, EPS));
}

void main()
{
    if (BYPASS_PREFILTER > 0.5) {
        FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
        return;
    }

    // Input composite baseband from previous stage
    vec2 UV = vTexCoord * config.OutputSize.xy;
    float line = floor(UV.y) / tb.pixels_per_line;
    float baseIndex = floor(UV.x);
    float baseCenter = baseIndex + 0.5;
    float Ax = UV.x - baseCenter;

    vec2 Tex = vec2(
        baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);
    vec2 dx = vec2(config.OutputSize.z, 0.0);
  
    // Center sample - input is already composite baseband from iq-demod.slang
    float composite0 = texture(Source, Tex).r;

    // Notch/bandpass filtering (always computed for modes < 0.5 and as fallback)
    float y_notch = 0.0;
    float c_notch = 0.0;
    
    if (COLOR_FILTER_MODE < 0.5 || COLOR_FILTER_MODE >= 2.0) {
        // Chroma bandpass accumulators
        float c_accum = 0.0;
        float sum_c = 0.0;
        // Notch accumulators (shared loop)
        float notch_accum = 0.0;
        float sum_notch = 0.0;

        // Subcarrier cycles per pixel for modulation (cycles/pixel)
        float f_sc_px = tb.sc_freq_hz * tb.pixel_time_px;

        // Center weights (include fractional horizontal offset Ax)
        float g_bp0 = gaussian(Ax, sigma_bp);
        float w_bp0 = g_bp0 * cos(2.0 * PI * f_sc_px * Ax);

        c_accum += w_bp0 * composite0;
        sum_c += g_bp0;

        float g_notch0 = gaussian(Ax, sigma_notch);
        float w_notch0 = g_notch0 * cos(2.0 * PI * f_sc_px * Ax);
        notch_accum += w_notch0 * composite0;
        sum_notch += g_notch0;

        // Bandpass + notch filter: shared symmetric lobed processing with early exit
        for (int n = 1; n <= 24; ++n) {
            float nf = float(n);

            float g_bp_r = gaussian(nf - Ax, sigma_bp);
            float g_bp_l = gaussian(nf + Ax, sigma_bp);
            float g_notch_r = gaussian(nf - Ax, sigma_notch);
            float g_notch_l = gaussian(nf + Ax, sigma_notch);

            if (g_bp_r < FILTER_THRESHOLD && g_bp_l < FILTER_THRESHOLD && g_notch_r < FILTER_THRESHOLD && g_notch_l < FILTER_THRESHOLD)
                break;

            // Right
            vec2 Tex_r = Tex + nf * dx;
            float comp_r = texture(Source, Tex_r).r;
            float w_bp_r = g_bp_r * cos(2.0 * PI * f_sc_px * (nf - Ax));
            float w_notch_r = g_notch_r * cos(2.0 * PI * f_sc_px * (nf - Ax));

            // Left
            vec2 Tex_l = Tex - nf * dx;
            float comp_l = texture(Source, Tex_l).r;
            float w_bp_l = g_bp_l * cos(2.0 * PI * f_sc_px * (nf + Ax));
            float w_notch_l = g_notch_l * cos(2.0 * PI * f_sc_px * (nf + Ax));

            c_accum += w_bp_r * comp_r + w_bp_l * comp_l;
            sum_c += g_bp_r + g_bp_l;

            notch_accum += w_notch_r * comp_r + w_notch_l * comp_l;
            sum_notch += g_notch_r + g_notch_l;
        }

        // Reconstruct chroma with modulated Gaussian band-pass (centered at f_sc)
        float c_bp = 2.0 * c_accum / max(sum_c, EPS);
        float notch_component = 2.0 * notch_accum / max(sum_notch, EPS);

        // Notch luma
        y_notch = composite0 - notch_component;

        // Bandpass chroma
        c_notch = c_bp;
    }

    // Comb filter path (only compute for COLOR_FILTER_MODE >= 1.0)
    vec2 color_comb = vec2(0.0);

    if (COLOR_FILTER_MODE >= 1.0) {
        // Calculate intrinsic system phase shift per line (independent of user hue)
        float cycles_per_line = tb.sc_freq_hz / tb.h_freq_hz;
        float frac_cycles = fract(cycles_per_line);
        float system_phase_shift = 2.0 * PI * frac_cycles;
        if (system_phase_shift > PI) {
            system_phase_shift -= 2.0 * PI;
        }

        // Correct for system phase shift to achieve ideal 180° alignment
        float sc_phase_inc_per_px = 2.0 * PI * tb.sc_freq_hz * tb.pixel_time_px;
        float target_phase = PI;
        float phase_correction_needed = target_phase - system_phase_shift;

        // Horizontal offset in pixels to achieve target phase
        float dx_phase_offset_px = phase_correction_needed / sc_phase_inc_per_px;

        // Reduce to one subcarrier period to avoid excessive offsets
        float period_px = 2.0 * PI / sc_phase_inc_per_px;
        dx_phase_offset_px -= round(dx_phase_offset_px / period_px) * period_px;

        vec2 dxy = vec2(-dx_phase_offset_px * config.OutputSize.z, -tb.pixels_per_line * config.OutputSize.w);

        // Sample phase-aligned taps
        float comb_taps_composite = texture(Source, Tex + dxy).r;

        if (COLOR_FILTER_MODE >= 0.5) {
            // Mode 1: Simple comb filter using parallel single-tap filter
            
            // Single-tap filter
            float y1 = 0.5 * (composite0 + comb_taps_composite);
            float c1 = 0.5 * (composite0 - comb_taps_composite);
            if (COLOR_FILTER_MODE >= 1.5) {
                // Mode 2: Adaptive comb filter using magnitude-based correlation
                float composite_corr = compute_point_correlation(abs(composite0), abs(comb_taps_composite));

                // Smoothly mix using +/-0.05 transition around adapt thresholds
                float luma_w = smoothstep(COMB_FILTER_LUMA_ADAPT - 0.05, COMB_FILTER_LUMA_ADAPT + 0.05, composite_corr);
                float chroma_w = smoothstep(COMB_FILTER_CHROMA_ADAPT - 0.05, COMB_FILTER_CHROMA_ADAPT + 0.05, composite_corr);

                color_comb.r = mix(y_notch, y1, luma_w);
                color_comb.g = mix(c_notch, c1, chroma_w);
                color_comb.g = mix(c_notch, c1, chroma_w);
            } else {
                // Fixed-weight simple comb filter output
                color_comb = vec2(y1, c1);
            }
        }
    }

    // Select color filter mode
    vec2 color;
    float y_out;
    float c_out;
    
    if (COLOR_FILTER_MODE < 0.5) {
        // Mode 0: Notch filter output only
        y_out = y_notch;
        c_out = c_notch;
        color = vec2(y_out, c_out);
    } else if (COLOR_FILTER_MODE < 1.5) {
        // Mode 1: Simple comb filter (fixed weights, no adaptation)
        y_out = color_comb.r;
        c_out = color_comb.g;
        color = vec2(y_out, c_out);
    } else {
        // Mode 2: Adaptive comb filter with notch fallback
        y_out = color_comb.r;
        c_out = color_comb.g;
        color = vec2(y_out, c_out);
    }

    // BW monitor modes: route either luma-only or chroma-only to all channels
    if (BW_MODE < 0.5) {
        // Normal output (no user scaling applied here)
    } else if (BW_MODE < 1.5) {
        color = vec2(y_out, c_out);
    } else if (BW_MODE < 2.5) {
        color = vec2(y_out, 0.0);
    } else if (BW_MODE < 3.5) {
        color = vec2(0.0, c_out);
    } else {
        color = vec2(y_out, c_out);
    }

    FragColor = vec4(color, vec2(composite0, 1.0));
}
