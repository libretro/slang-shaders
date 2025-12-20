#version 450

// Filename: yc-composite.slang
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
// Y/C to composite conversion with filtering
// -------------------------------------------
// Input: Luma (R) and chroma (G) signals from sys-yc.slang
// Output: Composite baseband signal (R16_SFLOAT)

#include "common.inc"
#include "modulation.inc"
#include "bandlimit.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/sys-encode.inc"
#include "menus/parameters/sys-yc.inc"

#pragma name YCComposite
#pragma format R16G16_SFLOAT

#pragma parameter BYPASS_YC_FILTER "Bypass Y/C filter (off, on)" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OriginalFPS;
    float BYPASS_YC_FILTER;
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
    float CHROMA_BANDPASS_WIDTH;
    float CHROMA_EDGE_ATTEN_DB;
    float LUMA_LOWPASS_CUTOFF;
    float LUMA_LOWPASS_ATTEN;
    float LUMA_NOTCH_ENABLE;
    float LUMA_NOTCH_WIDTH;
    float LUMA_NOTCH_ATTEN_DB;
    float YC_MONITOR;
} config;

#define BYPASS_YC_FILTER config.BYPASS_YC_FILTER

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
#define CHROMA_BANDPASS_WIDTH config.CHROMA_BANDPASS_WIDTH
#define CHROMA_EDGE_ATTEN_DB config.CHROMA_EDGE_ATTEN_DB
#define LUMA_LOWPASS_CUTOFF config.LUMA_LOWPASS_CUTOFF
#define LUMA_LOWPASS_ATTEN config.LUMA_LOWPASS_ATTEN
#define LUMA_NOTCH_ENABLE config.LUMA_NOTCH_ENABLE
#define LUMA_NOTCH_WIDTH config.LUMA_NOTCH_WIDTH
#define LUMA_NOTCH_ATTEN_DB config.LUMA_NOTCH_ATTEN_DB

#define YC_MONITOR config.YC_MONITOR

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float sigma_bp;
layout(location = 2) out float sigma_lp;
layout(location = 3) out float sigma_notch;
layout(location = 4) out TimebaseConfig tb;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    tb = compute_timebase(
        config.FrameCount,
        vTexCoord,
        config.OriginalSize.xy,
        config.OutputSize.x,
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

    // Analytical bandpass edge attenuation for brightness preservation:
    // Calculate minimum attenuation needed for -48 dB DC rejection.
    // User can increase this via NOTCH_EDGE_ATTEN_DB without brightness loss.
    // Formula: A_edge_min = A_dc * (BW / (2*f_sc))^2
    const float TARGET_DC_ATTEN_DB = 48.0;
    float f_sc_mhz = tb.sc_freq_hz * 1.0e-6; // Convert Hz to MHz
    float bw_to_fsc_ratio = CHROMA_BANDPASS_WIDTH / (2.0 * max(f_sc_mhz, 1e-6));
    float bandpass_edge_atten_min = TARGET_DC_ATTEN_DB * bw_to_fsc_ratio * bw_to_fsc_ratio;
    
    // Use the maximum of calculated minimum and user parameter
    // This ensures brightness preservation while allowing user override
    float bandpass_edge_atten_db = max(bandpass_edge_atten_min, CHROMA_EDGE_ATTEN_DB);
    
    // Clamp to reasonable range
    bandpass_edge_atten_db = clamp(bandpass_edge_atten_db, 0.1, 20.0);
    
    sigma_bp = sigma_tb(tb, max(CHROMA_BANDPASS_WIDTH, 1e-6), bandpass_edge_atten_db);

    // Fixed notch width for luma rejection, independent of chroma bandpass
    sigma_notch = sigma_tb(tb, LUMA_NOTCH_WIDTH, LUMA_NOTCH_ATTEN_DB);

    // Luma lowpass sigma
    sigma_lp = sigma_tb(tb, max(LUMA_LOWPASS_CUTOFF, 1e-6), LUMA_LOWPASS_ATTEN);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float sigma_bp;
layout(location = 2) in float sigma_lp;
layout(location = 3) in float sigma_notch;
layout(location = 4) in TimebaseConfig tb;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Input: Y/C signal (luma in R, chroma in G)
    vec2 UV = vTexCoord * config.OutputSize.xy;
    float line = floor(UV.y);
    float baseIndex = floor(UV.x);
    float baseCenter = baseIndex + 0.5;
    float Ax = UV.x - baseCenter;

    vec2 Tex = vec2(baseCenter * config.OutputSize.z,
                    (line + 0.5) * config.OutputSize.w);
    vec2 dx = vec2(config.OutputSize.z, 0.0);

    // If bypass is enabled, just sum Y+C and output
    if (BYPASS_YC_FILTER > 0.5) {
        vec2 yc = texture(Source, Tex).rg;
        float y_out = yc.r;
        float c_bp = yc.g;
        vec2 color;
        if (YC_MONITOR < 0.5) {
            color = vec2(y_out + c_bp, 0.0);
        } else if (YC_MONITOR < 1.5) {
            color = vec2(y_out, 0.0);
        } else if (YC_MONITOR < 2.5) {
            color = vec2(c_bp, 0.0);
        } else {
            color = vec2(y_out, c_bp);
        }
        FragColor = vec4(color, 0.0, 1.0);
        return;
    }

    const float THRESHOLD = 1.0 / 255.0;

    // Center sample
    vec2 yc0 = texture(Source, Tex).rg;
    float luma0 = yc0.r;
    float chroma0 = yc0.g;

    // Accumulators
    float bp_accum_c = 0.0;     // chroma bandpass
    float notch_accum_y = 0.0;  // luma bandpass used for notch
    float sum_bp = 0.0;         // chroma bandpass weight sum
    float sum_notch = 0.0;      // luma notch bandpass weight sum
    float lp_accum_y = 0.0;     // luma lowpass
    float sum_lp = 0.0;         // luma lowpass weight sum

    // Subcarrier cycles per pixel for modulation (cycles/pixel)
    float f_sc_px = tb.sc_freq_hz * tb.pixel_time_px;

    // Center weights (include fractional horizontal offset Ax)
    float g_bp0 = gaussian(Ax, sigma_bp);
    float w_bp0 = g_bp0 * cos(2.0 * PI * f_sc_px * Ax);
    bp_accum_c += w_bp0 * chroma0;
    sum_bp += g_bp0;

    float g_notch0 = gaussian(Ax, sigma_notch);
    float w_notch0 = g_notch0 * cos(2.0 * PI * f_sc_px * Ax);
    notch_accum_y += w_notch0 * luma0;
    sum_notch += g_notch0;

    float g_lp0 = gaussian(Ax, sigma_lp);
    lp_accum_y += g_lp0 * luma0;
    sum_lp += g_lp0;

    // Combined symmetric lobes for chroma bandpass and luma lowpass
    for (int n = 1; n <= 64; ++n) {
        float nf = float(n);

        float g_bp_r = gaussian(nf - Ax, sigma_bp);
        float g_bp_l = gaussian(nf + Ax, sigma_bp);
        float g_notch_r = gaussian(nf - Ax, sigma_notch);
        float g_notch_l = gaussian(nf + Ax, sigma_notch);
        float g_lp_r = gaussian(nf - Ax, sigma_lp);
        float g_lp_l = gaussian(nf + Ax, sigma_lp);

        if (g_bp_r < THRESHOLD && g_bp_l < THRESHOLD &&
            g_notch_r < THRESHOLD && g_notch_l < THRESHOLD &&
            g_lp_r < THRESHOLD && g_lp_l < THRESHOLD)
            break;

        // Right/Left samples (fetch both Y and C together)
        vec2 Tex_r = Tex + nf * dx;
        vec2 yc_r = texture(Source, Tex_r).rg;
        vec2 Tex_l = Tex - nf * dx;
        vec2 yc_l = texture(Source, Tex_l).rg;

        // Chroma bandpass weights
        float w_bp_r = g_bp_r * cos(2.0 * PI * f_sc_px * (nf - Ax));
        float w_bp_l = g_bp_l * cos(2.0 * PI * f_sc_px * (nf + Ax));

        // Luma notch bandpass weights
        float w_notch_r = g_notch_r * cos(2.0 * PI * f_sc_px * (nf - Ax));
        float w_notch_l = g_notch_l * cos(2.0 * PI * f_sc_px * (nf + Ax));

        // Accumulate chroma bandpass and luma notch bandpass
        bp_accum_c += w_bp_r * yc_r.g + w_bp_l * yc_l.g;
        notch_accum_y += w_notch_r * yc_r.r + w_notch_l * yc_l.r;
        sum_bp += g_bp_r + g_bp_l;
        sum_notch += g_notch_r + g_notch_l;

        // Accumulate luma lowpass
        lp_accum_y += g_lp_r * yc_r.r + g_lp_l * yc_l.r;
        sum_lp += g_lp_r + g_lp_l;
    }

    // Reconstruct signals
    float c_bp = 2.0 * bp_accum_c / max(sum_bp, EPS);
    float y_bp_notch = 2.0 * notch_accum_y / max(sum_notch, EPS);
    float y_lp = lp_accum_y / max(sum_lp, EPS);

    // Complementary luma using its own bandpass for the notch
    float y_notch = y_lp - y_bp_notch;

    // Apply notch filter conditionally based on LUMA_NOTCH_ENABLE
    float y_out = (LUMA_NOTCH_ENABLE > 0.5) ? y_notch : y_lp;

    // Sum Y+C to create composite output (notch-filtered luma + bandpass chroma)
    vec2 color;
    if (YC_MONITOR < 0.5) {
        color = vec2(y_out + c_bp, 0.0);
    } else if (YC_MONITOR < 1.5) {
        color = vec2(y_out, 0.0);
    } else if (YC_MONITOR < 2.5) {
        color = vec2(c_bp, 0.0);
    } else {
        color = vec2(y_out, c_bp);
    }

    FragColor = vec4(color, 0.0, 1.0);
}