#version 450

// Filename: limiter-sdr.slang
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
// Voltage limiter (SDR output range)
// -----------------
// Input: Voltage
// Output: Voltage
//
// Clips and normalizes voltage to range defined by IRE limits.
//
// There are two techniques for limiting here: hard clipping and soft
// clipping.  Hard clipping simply clamps the value to the min/max
// limits, while soft clipping uses a transfer function to gently roll
// off the signal as it approaches the limits, reducing harsh
// transitions that can cause artifacts.
//
// Most output should remain linear due to the linear range mapping
// directly to SDR range (default settings), but the soft limiter will
// apply distortion to signals that have been modified by the
// amplifiers in the previous stages to go beyond 100 IRE.

#include "common.inc"
#include "color.inc"
#include "tools/zebra.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/user-common.inc"
#include "menus/parameters/user-uncommon.inc"
#include "menus/parameters/colorimetry.inc"
#include "menus/parameters/output-tonemap.inc"
#include "menus/parameters/limiter.inc"

#pragma name Limiter
#pragma format R16G16B16A16_SFLOAT

#pragma parameter SHARPNENER_BYPASS "Bypass sharpener" 0.0 0.0 1.0 1.0
#pragma parameter LIMITER_BYPASS "Bypass voltage limiter" 0.0 0.0 1.0 1.0
#pragma parameter LIMITER_DEBUG_OUT_OF_RANGE "Limiter: show out-of-range colors" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    // Timing and source geometry (added for sharpness bandpass)
    vec4 OriginalSize;    // .xy size, .zw inv size
    vec4 OutputSize;
    vec4 FrameSize;
    uint FrameCount;
    float OriginalFPS;    // Vertical frequency (Hz)
    float V_FREQ_MODE;
    float V_FREQ;
    float SHORTEN_ODD_FIELD_TIME;
    float SC_FREQ_MODE;
    float SC_FREQ;        // Custom subcarrier frequency (MHz)
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float H_BLANK_FUZZ;

    // User video adjustments
    float USER_GAMMA;
    // User sharpness (percentage 0-100 from user-common.inc)
    float USER_SHARPNESS;
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

#define USER_GAMMA config.USER_GAMMA
#define USER_SHARPNESS config.USER_SHARPNESS


layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    float W_Y;
    // Color conversion circuitry (RGB matrix type)
    float NTSC_CONVERSION;
    float NTSC_CONVERSION_WEIGHT;
    float COLORIMETRY_PRESET;
    float R_X;
    float R_Y;
    float G_X;
    float G_Y;
    float B_X;
    float B_Y;
    float W_X;

    // Limiter
    float SHARPNENER_BYPASS;
    float LIMITER_BYPASS;
    float LIMITER_TYPE;
    float LIMITER_COMPRESSION_POINT;
    float LIMITER_MAX_OUTPUT;
    float LIMITER_DEBUG_OUT_OF_RANGE;

} global;

#define W_Y global.W_Y

#define NTSC_CONVERSION global.NTSC_CONVERSION
#define NTSC_CONVERSION_WEIGHT global.NTSC_CONVERSION_WEIGHT
#define COLORIMETRY_PRESET global.COLORIMETRY_PRESET
#define R_X global.R_X
#define R_Y global.R_Y
#define G_X global.G_X
#define G_Y global.G_Y
#define B_X global.B_X
#define B_Y global.B_Y
#define W_X global.W_X

#define SHARPNENER_BYPASS global.SHARPNENER_BYPASS

#define LIMITER_BYPASS global.LIMITER_BYPASS
#define LIMITER_TYPE global.LIMITER_TYPE
#define LIMITER_COMPRESSION_POINT global.LIMITER_COMPRESSION_POINT
#define LIMITER_MAX_OUTPUT global.LIMITER_MAX_OUTPUT
#define LIMITER_DEBUG_OUT_OF_RANGE global.LIMITER_DEBUG_OUT_OF_RANGE

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out mat3 CorrectionMatrix;
layout(location = 4) out vec4 sharpness_filters;
layout(location = 5) out TimebaseConfig tb;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Prepare NTSC conversion matrix if needed
    CorrectionMatrix = mat3(1.0);

    if (NTSC_CONVERSION > 0.5) {
        // Set up reference conversion matrix (NTSC C)
        const Colorimetry reference = Colorimetry(
            vec2(0.670, 0.330),
            vec2(0.210, 0.710),
            vec2(0.140, 0.080),
            vec2(0.310, 0.316));
        const vec3 wref_XYZ = NTSC_TO_XYZ * WHITE;
        mat3 ref_to_XYZ = NTSC_TO_XYZ;

        // Set up colorimetry
        Colorimetry colorimetry;

        if (COLORIMETRY_PRESET < 0.5) {
            // Custom
            colorimetry = Colorimetry(
                vec2(R_X, R_Y),
                vec2(G_X, G_Y),
                vec2(B_X, B_Y),
                vec2(W_X, W_Y));
        } else if (COLORIMETRY_PRESET < 1.5) {
            // Rec. 601
            colorimetry = Colorimetry(
                vec2(0.630, 0.340),
                vec2(0.310, 0.595),
                vec2(0.155, 0.070),
                vec2(0.3127, 0.3290));
        } else if (COLORIMETRY_PRESET < 2.5) {
            // Japanese phosphors, D93
            colorimetry = Colorimetry(
                vec2(0.618, 0.350),
                vec2(0.280, 0.605),
                vec2(0.152, 0.063),
                vec2(0.2832, 0.2971));
        } else if (COLORIMETRY_PRESET < 3.5) {
            // EBU Tech 3213
            colorimetry = Colorimetry(
                vec2(0.640, 0.330),
                vec2(0.290, 0.600),
                vec2(0.150, 0.060),
                vec2(0.3127, 0.3290));
        } else {
            // Rec. 709
            colorimetry = Colorimetry(
                vec2(0.640, 0.330),
                vec2(0.300, 0.600),
                vec2(0.150, 0.060),
                vec2(0.3127, 0.3290));
        }

        // Modify colorimetry with a distance factor
        colorimetry.red_xy = reference.red_xy + (colorimetry.red_xy - reference.red_xy) * NTSC_CONVERSION_WEIGHT;
        colorimetry.green_xy = reference.green_xy + (colorimetry.green_xy - reference.green_xy) * NTSC_CONVERSION_WEIGHT;
        colorimetry.blue_xy = reference.blue_xy + (colorimetry.blue_xy - reference.blue_xy) * NTSC_CONVERSION_WEIGHT;

        vec3 wout_XYZ = xyY_to_XYZ(vec3(colorimetry.white_xy.x, colorimetry.white_xy.y, 1.0));
        vec3 red_XYZ = xyY_to_XYZ(vec3(colorimetry.red_xy.x, colorimetry.red_xy.y, 1.0));
        vec3 green_XYZ = xyY_to_XYZ(vec3(colorimetry.green_xy.x, colorimetry.green_xy.y, 1.0));
        vec3 blue_XYZ = xyY_to_XYZ(vec3(colorimetry.blue_xy.x, colorimetry.blue_xy.y, 1.0));
        mat3 RGB_to_XYZ = get_RGB_to_XYZ(red_XYZ, green_XYZ, blue_XYZ, wout_XYZ);

        // Compute reference white in XYZ space
        wout_XYZ = RGB_to_XYZ * WHITE;

        // Apply chromatic adaptation to reference matrix
        ref_to_XYZ = bradford_linear(wref_XYZ, wout_XYZ) * ref_to_XYZ;

        // Compute correction matrix
        CorrectionMatrix = inverse(RGB_to_XYZ) * ref_to_XYZ;
    }

    // Compute timebase with actual vertex TexCoord (per-vertex)
    tb = compute_timebase(
        config.FrameCount,
        vTexCoord,
        config.OriginalSize.xy,
        config.OutputSize.xy,
        config.FrameSize.xy,
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

    // Emphasis design parameters using timebase
    if (SHARPNENER_BYPASS < 0.5) {
    float emphasis_center_hz = 3.1e6;
    float emphasis2_center_hz = 4.3e6;
    float emphasis_sigma = sigma_tb(tb, 0.6, 3.0);
    float emphasis2_sigma = sigma_tb(tb, 0.4, 3.0);
    sharpness_filters = vec4(emphasis_center_hz, emphasis_sigma, emphasis2_center_hz, emphasis2_sigma);
    } else {
        sharpness_filters = vec4(0.0);
    }
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in mat3 CorrectionMatrix;
layout(location = 4) in vec4 sharpness_filters;
layout(location = 5) in TimebaseConfig tb;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec3 color = texture(Source, vTexCoord).rgb;

    // Sharpness bandpass + harmonic (modulated Gaussian) before any other processing.
    float sharpness = USER_SHARPNESS / 100.0;

    if (sharpness > 0.0 && SHARPNENER_BYPASS < 0.5) {
        float emphasis_center_hz = sharpness_filters.x;
        float emphasis_sigma = sharpness_filters.y;
        float emphasis2_center_hz = sharpness_filters.z;
        float emphasis2_sigma = sharpness_filters.w;

        // Horizontal lattice setup
        vec2 UV = vTexCoord * config.OutputSize.xy;
        float line = floor(UV.y) / tb.pixels_per_line;
        float baseIndex = floor(UV.x);
        float baseCenter = baseIndex + 0.5;
        float Ax = UV.x - baseCenter; // [-0.5,0.5]
        vec2 TexCenter = vec2(
            baseCenter * config.OutputSize.z,
            (floor(UV.y) + 0.5) * config.OutputSize.w);
        vec2 dx = vec2(config.OutputSize.z, 0.0);

        float t0 = line / tb.h_freq_hz + baseCenter * tb.pixel_time_px;
        float emphasis_phase0 = 2.0 * PI * emphasis_center_hz * t0;
        float emphasis2_phase0 = 2.0 * PI * emphasis2_center_hz * t0;

        float w_emphasis0 = gaussian(Ax, emphasis_sigma);
        float w_emphasis2_0 = gaussian(Ax, emphasis2_sigma);

        vec3 c0 = texture(Source, TexCenter).rgb;
        vec3 band_color = w_emphasis0 * c0 * cos(emphasis_phase0);
        vec3 band2_color = w_emphasis2_0 * c0 * cos(emphasis2_phase0);
        float wsum = w_emphasis0;
        float wsum2 = w_emphasis2_0;

        for (int n = 1; n <= 10; ++n) {
            float nf = float(n);
            float w_emphasis_r = gaussian(nf - Ax, emphasis_sigma);
            float w_emphasis_l = gaussian(nf + Ax, emphasis_sigma);
            float w_emphasis2_r = gaussian(nf - Ax, emphasis2_sigma);
            float w_emphasis2_l = gaussian(nf + Ax, emphasis2_sigma);
            if (w_emphasis_r < FILTER_THRESHOLD && w_emphasis_l < FILTER_THRESHOLD &&
                w_emphasis2_r < FILTER_THRESHOLD && w_emphasis2_l < FILTER_THRESHOLD)
                break;

            float offsetR = baseCenter + nf;
            float tR = line / tb.h_freq_hz + offsetR * tb.pixel_time_px;
            vec3 cR = texture(Source, TexCenter + nf * dx).rgb;
            float emphasis_phaseR = 2.0 * PI * emphasis_center_hz * tR;
            float emphasis2_phaseR = 2.0 * PI * emphasis2_center_hz * tR;

            float offsetL = baseCenter - nf;
            float tL = line / tb.h_freq_hz + offsetL * tb.pixel_time_px;
            vec3 cL = texture(Source, TexCenter - nf * dx).rgb;
            float emphasis_phaseL = 2.0 * PI * emphasis_center_hz * tL;
            float emphasis2_phaseL = 2.0 * PI * emphasis2_center_hz * tL;

            band_color += w_emphasis_r * cR * cos(emphasis_phaseR) + w_emphasis_l * cL * cos(emphasis_phaseL);
            band2_color += w_emphasis2_r * cR * cos(emphasis2_phaseR) + w_emphasis2_l * cL * cos(emphasis2_phaseL);
            wsum += w_emphasis_r + w_emphasis_l;
            wsum2 += w_emphasis2_r + w_emphasis2_l;
        }

        band_color /= max(wsum, FILTER_THRESHOLD);
        band2_color /= max(wsum2, FILTER_THRESHOLD);

        float demod_mod = 2.0 * cos(emphasis_phase0);
        vec3 emphasis_component = band_color * demod_mod;

        float demod_mod2 = 2.0 * cos(emphasis2_phase0);
        vec3 emphasis2_component = band2_color * demod_mod2;

        // Non-linear gain mapping for stronger high sharpness
        float primary_gain = sharpness * (1.0 + 0.6 * sharpness * sharpness);
        float harm2_gain = mix(0.3, 0.55, sharpness * sharpness);

        // Energy-based soft limiter to tame overshoots
        float energy = dot(emphasis_component, emphasis_component);
        float energy_limit = 1.0 / (1.0 + energy * 12.0 * primary_gain);

        // Apply boosted gains
        color += primary_gain * energy_limit * emphasis_component;
        color += primary_gain * harm2_gain * energy_limit * emphasis2_component;
    }

    // Clamp negative voltages to zero
    color = max(color, vec3(0.0));

    if (NTSC_CONVERSION > 0.5) {
        // Apply NTSC conversion matrix
        color = CorrectionMatrix * color;
    }

    // Bypass limiter, but translate to expected unit
    if (LIMITER_BYPASS >= 1.0) {
        FragColor = vec4(color, 1.0);
        return;
    }

    float compression = LIMITER_COMPRESSION_POINT * 10e-3; // Convert IRE to V

    if (LIMITER_TYPE > 0.5) {
        // Hard limiter
        color = clamp(color, 0.0, compression);
        FragColor = vec4(color, 1.0);
        return;
    }

    // Soft limiter
    float peak = LIMITER_MAX_OUTPUT * 10e-3; // Convert IRE to V
    float distortion = peak - compression;

    if (any(greaterThan(color, vec3(compression)))) {
        // Hyperbolic tangent gives us a smooth roll-off
        vec3 softColor = distortion * tanh((color - compression) / distortion) + compression;

        color = min(color, softColor);        
    }

    // Apply user video adjustments
    float gamma = (2.4 - USER_GAMMA / 10.0) / 2.4; // Map USER_GAMMA 0-1 to fraction of 2.4

    // Preserve extended values for proper handling
    if (color.r < 1.0)
        color.r = pow(color.r, gamma);
    if (color.g < 1.0)
        color.g = pow(color.g, gamma);
    if (color.b < 1.0)
        color.b = pow(color.b, gamma);

    // Debug: Visualize out-of-range colors with zebra pattern
    if (LIMITER_DEBUG_OUT_OF_RANGE >= 1.0) {
        color = zebra(color, 0.0, compression, vTexCoord, config.OutputSize.xy, config.FrameCount, 1.0);
    }

    FragColor = vec4(color, 1.0);
}