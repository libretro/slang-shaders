#version 450

// Filename: display-svideo.slang
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
// S-Video display decoder: demodulate + filter
// --------------------------------------------
// Input: YC (Y in R, modulated chroma in G)
// Output: RGB (decoded)
//
// This shader performs only the decoding path from svideo.slang:
//  - derives carrier phase from timing
//  - demodulates modulated chroma (no encode step)
//  - applies Gaussian low-pass for luma/chroma
//  - outputs RGB

#include "common.inc"
#include "color.inc"
#include "modulation.inc"

#include "menus/parameters/user-video.inc"
#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/svideo.inc"

#pragma name DisplaySVideo
#pragma format R16G16B16A16_SFLOAT

#pragma parameter BYPASS_SVIDEO "Bypass S-Video processing (0=Off, 1=On)" 0.0 0.0 1.0 1.0
#pragma parameter SVIDEO_FILTER_BYPASS "S-Video filter bypass (use center sample)" 0.0 0.0 1.0 1.0

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
    float USER_COLOR;
    float USER_TINT;
    float USER_MONOCHROME;
    float DISPLAY_BANDWIDTH_Y;
    float DISPLAY_BANDWIDTH_C;
    float DISPLAY_CUTOFF_ATTEN_Y;
    float DISPLAY_CUTOFF_ATTEN_C;
} config;

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

#define USER_COLOR config.USER_COLOR
#define USER_TINT config.USER_TINT
#define USER_MONOCHROME config.USER_MONOCHROME

#define DISPLAY_BANDWIDTH_Y config.DISPLAY_BANDWIDTH_Y
#define DISPLAY_BANDWIDTH_C config.DISPLAY_BANDWIDTH_C
#define DISPLAY_CUTOFF_ATTEN_Y config.DISPLAY_CUTOFF_ATTEN_Y
#define DISPLAY_CUTOFF_ATTEN_C config.DISPLAY_CUTOFF_ATTEN_C

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    float BYPASS_SVIDEO;
    float SVIDEO_FILTER_BYPASS;
    float BW_MODE;
    float DECODER_SETUP;
    float DECODER_PAL;
} global;

#define BYPASS_SVIDEO global.BYPASS_SVIDEO
#define SVIDEO_FILTER_BYPASS global.SVIDEO_FILTER_BYPASS
#define BW_MODE global.BW_MODE
#define DECODER_SETUP global.DECODER_SETUP
#define DECODER_PAL global.DECODER_PAL

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec3 sigma;
layout(location = 2) out float c_gain;
layout(location = 3) out float c_phase;
layout(location = 4) out CarrierPhaseConfig carrier;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Timebase for carrier phase
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

    // Gaussian sigmas from bandwidth/attenuation
    sigma.x = sigma_tb(tb, DISPLAY_BANDWIDTH_Y, DISPLAY_CUTOFF_ATTEN_Y);
    sigma.y = sigma_tb(tb, DISPLAY_BANDWIDTH_C, DISPLAY_CUTOFF_ATTEN_C);
    sigma.z = sigma.y;

    // User chroma gain/phase
    c_gain = 2.0 * USER_COLOR / 100.0;
    c_phase = PI * USER_TINT / 180.0;

    carrier = extract_carrier_phase(tb);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec3 sigma;
layout(location = 2) in float c_gain;
layout(location = 3) in float c_phase;
layout(location = 4) in CarrierPhaseConfig carrier;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    if (BYPASS_SVIDEO >= 1.0) {
        FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
        return;
    }

    // Position and base center
    vec2 UV = vTexCoord * config.OutputSize.xy;
    float baseIndex = floor(UV.x);
    float baseCenter = baseIndex + 0.5;
    float Ax = UV.x - baseCenter;
    vec2 Tex = vec2(baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);
    vec2 dx = vec2(config.OutputSize.z, 0.0);

    // Carrier phase for center sample
    float line = floor(UV.y);
    float t0 = line / carrier.h_freq_hz + baseCenter * carrier.pixel_time_px;
    float phase_inc_px = 2.0 * PI * carrier.sc_freq_hz * carrier.pixel_time_px;

    float pal_v_sign = 1.0 - 2.0 * floor(mod(line, 2.0)) * DECODER_PAL;

    vec3 pixel0 = texture(Source, Tex).rgb;
    float phase0 = compute_carrier_phase(t0, carrier.sc_freq_hz, carrier.field_phase);
    float phase0_user = normalize_phase(phase0 + c_phase);
    phase0 = normalize_phase(phase0);
    vec2 carrier0 = sincos_phase_raw(phase0);
    vec2 carrier0_user = sincos_phase_raw(phase0_user);

    // Input chroma already modulated: use directly
    float chroma_mod0 = pixel0.g;

    float y_out = pixel0.r;
    float c_out = chroma_mod0;

    float y0 = pixel0.r;
    float chroma_u0 = chroma_mod0 * 2.0 * carrier0_user.x;
    float chroma_v0 = chroma_mod0 * 2.0 * carrier0_user.y * pal_v_sign;

    vec3 accum = vec3(0.0);
    vec3 wsum = vec3(0.0);

    // Center weights
    float wy0 = gaussian(Ax, sigma.x);
    float wc0 = gaussian(Ax, sigma.y);
    accum += vec3(wy0 * y0, wc0 * chroma_u0, wc0 * chroma_v0);
    wsum  += vec3(wy0, wc0, wc0);

    // Symmetric lobes with early exit
    if (SVIDEO_FILTER_BYPASS < 1.0) {
        for (int n = 1; n <= 16; ++n) {
            float nf = float(n);
            float wy_r = gaussian(nf - Ax, sigma.x);
            float wy_l = gaussian(nf + Ax, sigma.x);
            float wc_r = gaussian(nf - Ax, sigma.y);
            float wc_l = gaussian(nf + Ax, sigma.y);

            if (wy_r < FILTER_THRESHOLD && wy_l < FILTER_THRESHOLD &&
                wc_r < FILTER_THRESHOLD && wc_l < FILTER_THRESHOLD)
                break;

            // Right tap
            vec3 pixelR = texture(Source, Tex + nf * dx).rgb;
            float phaseR = normalize_phase(phase0 + phase_inc_px * nf);
            float phaseR_user = normalize_phase(phase0_user + phase_inc_px * nf);
            vec2 carrierR = sincos_phase_raw(phaseR);
            vec2 carrierR_user = sincos_phase_raw(phaseR_user);
            float chroma_modR = pixelR.g;
            float chroma_uR = chroma_modR * 2.0 * carrierR_user.x;
            float chroma_vR = chroma_modR * 2.0 * carrierR_user.y * pal_v_sign;

            // Left tap
            vec3 pixelL = texture(Source, Tex - nf * dx).rgb;
            float phaseL = normalize_phase(phase0 - phase_inc_px * nf);
            float phaseL_user = normalize_phase(phase0_user - phase_inc_px * nf);
            vec2 carrierL = sincos_phase_raw(phaseL);
            vec2 carrierL_user = sincos_phase_raw(phaseL_user);
            float chroma_modL = pixelL.g;
            float chroma_uL = chroma_modL * 2.0 * carrierL_user.x;
            float chroma_vL = chroma_modL * 2.0 * carrierL_user.y * pal_v_sign;

            accum.x += wy_r * pixelR.r + wy_l * pixelL.r;
            accum.y += wc_r * chroma_uR + wc_l * chroma_uL;
            accum.z += wc_r * chroma_vR + wc_l * chroma_vL;
            wsum.x  += wy_r + wy_l;
            wsum.y  += wc_r + wc_l;
            wsum.z  += wc_r + wc_l;
        }
    }

    vec3 yc = accum / max(wsum, vec3(EPS));

    // Apply user chroma gain
    yc.gb *= vec2(c_gain);

    // Convert YPbPr -> RGB
    // Optional monochrome/sepia
    if (USER_MONOCHROME > 0.5) {
        if (USER_MONOCHROME < 1.5) {
            yc.g = 0.0;
            yc.b = 0.0;
        } else {
            vec3 yiq = yc;
            yiq.g = 0.1;
            yiq.b = 0.0;
            yc = RGB_TO_YPbPr * YIQ_TO_RGB * yiq;
        }
    }

    // Decoder setup removal
    if (DECODER_SETUP > 0.5) {
        yc.r = (yc.r - 0.075) / 0.925;
        y_out = (y_out - 0.075) / 0.925;
    }

    // Apply user chroma gain already done above

    vec3 color = yc;

    // BW modes
    if (BW_MODE < 0.5) {
        color = YPbPr_TO_RGB * color;
    } else if (BW_MODE < 1.5) {
        color = vec3(y_out + c_out);
    } else if (BW_MODE < 2.5) {
        color = vec3(y_out);
    } else if (BW_MODE < 3.5) {
        color = vec3(c_out);
    } else {
        color = vec3(y_out, c_out, c_out);
    }

    FragColor = vec4(color, 1.0);
}
