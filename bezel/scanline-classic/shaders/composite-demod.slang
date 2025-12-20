#version 450

/* Filename: composite-demod.slang

   Copyright (C) 2025 W. M. Martinez

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>. */

#include "common.inc"
#include "color.inc"
#include "bandlimit.inc"
#include "modulation.inc"

#include "menus/parameters/user-video.inc"
#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/composite.inc"

#pragma name CompositeDemod
#pragma format R16G16B16A16_SFLOAT

#pragma parameter BYPASS_COMPOSITE_DEMOD "Bypass composite demodulation (off, on)" 0.0 0.0 1.0 1.0
#pragma parameter COMPOSITE_DEMOD_FILTER_BYPASS "Bypass composite demodulation filter (off, on)" 0.0 0.0 1.0 1.0
#pragma parameter CORRELATION "Correlation" 0.5 0.0 1.0 0.01
#pragma parameter COMB_ADJUST_X "Comb filter phase adjustment X (texels)" 0.0 -10.0 10.0 0.01
#pragma parameter COMB_ADJUST_Y "Comb filter phase adjustment Y (texels)" 0.0 -10.0 10.0 0.01

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OriginalFPS;
    float BYPASS_COMPOSITE_DEMOD;
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
    float COMB_FILTER_2D;
    float DISPLAY_BANDWIDTH_Y;
    float DISPLAY_BANDWIDTH_C;
    float DISPLAY_CUTOFF_ATTEN_Y;
    float DISPLAY_CUTOFF_ATTEN_C;
    float BW_MODE;
    float USER_COLOR;   // Color (%)
    float USER_TINT;    // Tint (degrees)
    float PAL_DECODER_MODE;  // PAL decoder mode (0=simple, 1=delay-line, 2=adaptive)
} config;

#define USER_COLOR config.USER_COLOR
#define USER_TINT config.USER_TINT
#define BYPASS_COMPOSITE_DEMOD config.BYPASS_COMPOSITE_DEMOD

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
#define COMB_FILTER_2D config.COMB_FILTER_2D

#define DISPLAY_BANDWIDTH_Y config.DISPLAY_BANDWIDTH_Y
#define DISPLAY_BANDWIDTH_C config.DISPLAY_BANDWIDTH_C

#define DISPLAY_CUTOFF_ATTEN_Y config.DISPLAY_CUTOFF_ATTEN_Y
#define DISPLAY_CUTOFF_ATTEN_C config.DISPLAY_CUTOFF_ATTEN_C

#define BW_MODE config.BW_MODE
#define PAL_DECODER_MODE config.PAL_DECODER_MODE

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    float DECODER_TYPE; // Decoder type (0=YIQ, 1=YPbPr, 2=PAL)
    float DECODER_SETUP;
    float USER_MONOCHROME; // Monochrome mode (off, B&W, sepia)
    float COMB_ADJUST_X;
    float COMB_ADJUST_Y;
    float COMPOSITE_DEMOD_FILTER_BYPASS;
    float CORRELATION;
} global;

#define DECODER_TYPE global.DECODER_TYPE
#define DECODER_SETUP global.DECODER_SETUP
#define USER_MONOCHROME global.USER_MONOCHROME
#define COMB_ADJUST_X global.COMB_ADJUST_X
#define COMB_ADJUST_Y global.COMB_ADJUST_Y
#define COMPOSITE_DEMOD_FILTER_BYPASS global.COMPOSITE_DEMOD_FILTER_BYPASS
#define CORRELATION global.CORRELATION

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 sigma;
layout(location = 2) out float c_gain;
layout(location = 3) out float c_phase;
layout(location = 4) out mat3 toRGB;
layout(location = 7) out TimebaseConfig tb;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Precompute timebase config for fragment stage
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

    // Precompute per-component sigmas for fragment stage
    sigma.x = sigma_tb(tb, DISPLAY_BANDWIDTH_Y, DISPLAY_CUTOFF_ATTEN_Y);
    sigma.y = sigma_tb(tb, DISPLAY_BANDWIDTH_C, DISPLAY_CUTOFF_ATTEN_C);

    // Precompute user color gain/phase
    c_gain = 2.0 * USER_COLOR / 100.0;
    c_phase = PI * USER_TINT / 180.0;

    // Select appropriate color space conversion matrix
    // DECODER_TYPE: 0.0=YIQ, 1.0=YPbPr, 2.0=PAL
    // YIQ: NTSC standard with 33° I axis, 123° Q axis (relative to burst phase)
    // YUV: PAL standard with U at 0°, V at 90°
    // YPbPr: Component video standard
    if (DECODER_TYPE < 0.5) {
        toRGB = YIQ_TO_RGB;  // YIQ mode
    } else if (DECODER_TYPE < 1.5) {
        toRGB = YPbPr_TO_RGB;  // YPbPr mode
    } else {
        toRGB = YUV_TO_RGB;  // PAL mode
    }
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in vec2 sigma;
layout(location = 2) in float c_gain;
layout(location = 3) in float c_phase;
layout(location = 4) in mat3 toRGB;
layout(location = 7) in TimebaseConfig tb;
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
    if (BYPASS_COMPOSITE_DEMOD >= 1.0) {
        FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
        return;
    }
    
    // Optimized symmetric lobed approach with early exit
    // Horizontal coordinate handling: nearest pixel center (no Y shift)
    vec2 UV = vTexCoord * config.OutputSize.xy;
    float line = floor(UV.y) / tb.pixels_per_line;
    float baseIndex = floor(UV.x); // nearest pixel index
    float baseCenter = baseIndex + 0.5;  // pixel center coordinate
    float Ax = UV.x - baseCenter;        // offset in [-0.5, 0.5]
    vec2 Tex = vec2(
        baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);
    vec2 dx = vec2(config.OutputSize.z, 0.0);

    vec3 wsum = vec3(0.0);
    
    // Process center sample
    float t0 = line / tb.h_freq_hz + baseCenter * tb.pixel_time_px;

    // R is Y, G is C
    vec3 pixel0 = texture(Source, Tex).rgb;
    float phase_inc_px = 2.0 * PI * tb.sc_freq_hz * tb.pixel_time_px;
    float phase0_full = compute_carrier_phase(t0, tb.sc_freq_hz, tb.field_phase) + c_phase;
    float phase_prev_center = compute_carrier_phase(t0 - (1.0 / tb.h_freq_hz), tb.sc_freq_hz, tb.field_phase);
    phase0_full = normalize_phase(phase0_full);
    phase_prev_center = normalize_phase(phase_prev_center);
    vec2 carrier0;

    float composite0 = pixel0.r;
    float chroma0 = pixel0.g;
    float bypass = pixel0.b;

    // Compute phase-neutral carrier (PAL delay line handles alternation via add/subtract)
    carrier0 = sincos_phase_raw(vec2(phase0_full));

    // PAL V polarity correction: delay line subtraction produces alternating sign
    float pal_v_sign = 1.0 - 2.0 * floor(mod(line, 2.0)) * step(1.5, DECODER_TYPE);

    // Delay-line control flags and offsets
    bool use_delay_line = PAL_DECODER_MODE > 0.5;
    float dx_phase_offset_px = 0.0;
    float system_phase_shift = 0.0;

    // Compute phase offset correction for delay-line (constant per system)
    if (DECODER_TYPE > 1.5 && use_delay_line) {
        // Calculate intrinsic system phase shift per line (independent of user hue)
        float cycles_per_line = tb.sc_freq_hz / tb.h_freq_hz;
        float frac_cycles = fract(cycles_per_line);
        system_phase_shift = 2.0 * PI * frac_cycles;
        if (system_phase_shift > PI) {
            system_phase_shift -= 2.0 * PI;
        }

        // Correct for system phase shift to achieve ideal 0° alignment
        float target_phase = 0.0;
        float phase_correction_needed = target_phase - system_phase_shift;

        // Horizontal offset in pixels to achieve target phase
        dx_phase_offset_px = phase_correction_needed / phase_inc_px;

        // Reduce to one subcarrier period to avoid excessive offsets
        float period_px = 2.0 * PI / phase_inc_px;
        dx_phase_offset_px -= round(dx_phase_offset_px / period_px) * period_px;

        // Scale to pixels per texel
        dx_phase_offset_px += COMB_ADJUST_X;
    }

    // Monitor mode: use center sample directly (bypass filter)
    float y_out = composite0;
    float c_out = chroma0;
    
    vec3 demod0;

    demod0.r = composite0;

    float CORRELATION_MIN = CORRELATION - 0.05;
    float CORRELATION_MAX = CORRELATION + 0.05;
    
    // PAL decoder mode selection (phase-corrected delay-line, simple, or adaptive)
    if (DECODER_TYPE > 1.5) {
        bool effective_delay_line = use_delay_line;

        // ADAPTIVE: blend delay-line with correlation based on phase error magnitude
        if (PAL_DECODER_MODE > 1.5) {
            // Check for external phase error (e.g., incorrect hue knob)
            float actual_phase_shift = normalize_phase(phase0_full - phase_prev_center);
            float phase_error = normalize_phase(actual_phase_shift - system_phase_shift);
            float phase_error_mag = abs(phase_error);
            
            const float PHASE_ERROR_MIN = 0.017453; // 1 degree in radians
            const float PHASE_ERROR_MAX = 0.087266; // 5 degrees in radians
            
            // Blend factor: 0 = correlation decides, 1 = force delay-line
            float phase_blend = smoothstep(PHASE_ERROR_MIN, PHASE_ERROR_MAX, phase_error_mag);

            vec2 dy = vec2(-dx_phase_offset_px * config.OutputSize.z, -tb.pixels_per_line * config.OutputSize.w);
            vec3 pal_delay = texture(Source, Tex + dy).rgb;
            
            float correlation = compute_point_correlation(chroma0, pal_delay.g);
            float correlation_weight = smoothstep(CORRELATION_MIN, CORRELATION_MAX, correlation);
            
            vec2 simple_uv = vec2(
                2.0 * chroma0 * carrier0.x,
                pal_v_sign * 2.0 * chroma0 * carrier0.y);
            
            vec2 delay_uv = vec2(
                (chroma0 + pal_delay.g) * carrier0.x,
                pal_v_sign * (chroma0 - pal_delay.g) * carrier0.y);
            
            // Use max to prioritize delay-line whenever either cue is strong
            float delay_weight = max(phase_blend, correlation_weight);
            demod0.gb = mix(simple_uv, delay_uv, delay_weight);
        } else if (use_delay_line) {
            // DELAY: Phase-corrected PAL delay-line demodulation
            vec2 dxy = vec2(-dx_phase_offset_px * config.OutputSize.z, -tb.pixels_per_line * config.OutputSize.w);
            vec3 pal_delay = texture(Source, Tex + dxy).rgb;

            demod0.g = (chroma0 + pal_delay.g) * carrier0.x;
            demod0.b = pal_v_sign * (chroma0 - pal_delay.g) * carrier0.y;
        } else {
            // SIMPLE: Direct demodulation without delay-line
            demod0.g = 2.0 * chroma0 * carrier0.x;
            demod0.b = pal_v_sign * 2.0 * chroma0 * carrier0.y;
        }
    } else {
        // Non-PAL decoders (YIQ, YPbPr)
        demod0.g = 2.0 * chroma0 * carrier0.x;
        demod0.b = 2.0 * chroma0 * carrier0.y;
    }
    
    // Center weights for all filter modes
    float w_y0 = gaussian(Ax, sigma.x);
    float w_c0 = gaussian(Ax, sigma.y);

    vec3 color = vec3(0.0);
    
    color += vec3(w_y0 * demod0.r, w_c0 * demod0.g, w_c0 * demod0.b);
    wsum += vec3(w_y0, w_c0, w_c0);

    // Symmetric lobed processing with early exit
    if (COMPOSITE_DEMOD_FILTER_BYPASS < 0.5) {
        for (int n = 1; n <= 20; ++n) {
            float nf = float(n);
            // Symmetric distances: right = n - Ax, left = n + Ax
            float w_y_r = gaussian(nf - Ax, sigma.x);
            float w_y_l = gaussian(nf + Ax, sigma.x);
            float w_c_r = gaussian(nf - Ax, sigma.y);
            float w_c_l = gaussian(nf + Ax, sigma.y);
            if (w_y_r < FILTER_THRESHOLD && w_y_l < FILTER_THRESHOLD &&
                w_c_r < FILTER_THRESHOLD && w_c_l < FILTER_THRESHOLD)
                break;

            // Right sample (output pixel lattice)
            vec3 pixelR = texture(Source, Tex + nf * dx).rgb;
            // Compute exact phase at right tap position to avoid drift
            float phaseR_full = normalize_phase(phase0_full + phase_inc_px * nf);
            float phase_prev_R = normalize_phase(phase_prev_center + phase_inc_px * nf);
            vec2 carrierR = sincos_phase_raw(vec2(phaseR_full));
            float compositeR = pixelR.r;
            float chromaR = pixelR.g;
            vec3 demodR;

            if (DECODER_TYPE > 1.5) {
                bool effective_delay_line = use_delay_line;

                // ADAPTIVE: blend delay-line with correlation based on phase error magnitude
                if (PAL_DECODER_MODE > 1.5) {
                    // Check for external phase error at this sample position
                    float actual_phase_shift = normalize_phase(phaseR_full - phase_prev_R);
                    float phase_error = normalize_phase(actual_phase_shift - system_phase_shift);
                    float phase_error_mag = abs(phase_error);
                    
                    const float PHASE_ERROR_MIN = 0.017453; // 1 degree in radians
                    const float PHASE_ERROR_MAX = 0.087266; // 5 degrees in radians
                    
                    float phase_blend = smoothstep(PHASE_ERROR_MIN, PHASE_ERROR_MAX, phase_error_mag);

                    vec2 dxy = vec2((nf - dx_phase_offset_px) * dx.x, -tb.pixels_per_line * config.OutputSize.w);
                    vec3 pal_delay = texture(Source, Tex + dxy).rgb;

                    float correlation = compute_point_correlation(chromaR, pal_delay.g);
                    float correlation_weight = smoothstep(CORRELATION_MIN, CORRELATION_MAX, correlation);
                    
                    vec2 simple_uv = vec2(
                        2.0 * chromaR * carrierR.x,
                        pal_v_sign * 2.0 * chromaR * carrierR.y);
                    
                    vec2 delay_uv = vec2(
                        (chromaR + pal_delay.g) * carrierR.x,
                        pal_v_sign * (chromaR - pal_delay.g) * carrierR.y);
                    
                    float delay_weight = max(phase_blend, correlation_weight);
                    vec2 mixed_uv = mix(simple_uv, delay_uv, delay_weight);
                    
                    demodR = vec3(compositeR, mixed_uv.x, mixed_uv.y);
                } else if (use_delay_line) {
                    // DELAY: Phase-corrected PAL delay-line
                    vec2 dxy = vec2((nf - dx_phase_offset_px) * dx.x, -tb.pixels_per_line * config.OutputSize.w);
                    vec3 pal_delay = texture(Source, Tex + dxy).rgb;

                    demodR = vec3(
                        compositeR,
                        (chromaR + pal_delay.g) * carrierR.x,
                        pal_v_sign * (chromaR - pal_delay.g) * carrierR.y);
                } else {
                    // SIMPLE: Direct demodulation
                    demodR = vec3(
                        compositeR,
                        2.0 * chromaR * carrierR.x,
                        pal_v_sign * 2.0 * chromaR * carrierR.y);
                }
            } else {
                demodR = vec3(
                    compositeR,
                    2.0 * chromaR * carrierR.x,
                    2.0 * chromaR * carrierR.y);
            }

            // Left sample (output pixel lattice)
            vec3 pixelL = texture(Source, Tex - nf * dx).rgb;
            // Compute exact phase at left tap position to avoid drift
            float phaseL_full = normalize_phase(phase0_full - phase_inc_px * nf);
            float phase_prev_L = normalize_phase(phase_prev_center - phase_inc_px * nf);
            vec2 carrierL = sincos_phase_raw(vec2(phaseL_full));
            float compositeL = pixelL.r;
            float chromaL = pixelL.g;
            vec3 demodL;

            if (DECODER_TYPE > 1.5) {
                bool effective_delay_line = use_delay_line;

                // ADAPTIVE: blend delay-line with correlation based on phase error magnitude
                if (PAL_DECODER_MODE > 1.5) {
                    // Check for external phase error at this sample position
                    float actual_phase_shift = normalize_phase(phaseL_full - phase_prev_L);
                    float phase_error = normalize_phase(actual_phase_shift - system_phase_shift);
                    float phase_error_mag = abs(phase_error);
                    
                    const float PHASE_ERROR_MIN = 0.017453; // 1 degree in radians
                    const float PHASE_ERROR_MAX = 0.087266; // 5 degrees in radians
                    
                    float phase_blend = smoothstep(PHASE_ERROR_MIN, PHASE_ERROR_MAX, phase_error_mag);

                    vec2 dxy = vec2((-nf - dx_phase_offset_px) * dx.x, -tb.pixels_per_line * config.OutputSize.w);
                    vec3 pal_delay = texture(Source, Tex + dxy).rgb;

                    float correlation = compute_point_correlation(chromaL, pal_delay.g);
                    float correlation_weight = smoothstep(CORRELATION_MIN, CORRELATION_MAX, correlation);
                    
                    vec2 simple_uv = vec2(
                        2.0 * chromaL * carrierL.x,
                        pal_v_sign * 2.0 * chromaL * carrierL.y);
                    
                    vec2 delay_uv = vec2(
                        (chromaL + pal_delay.g) * carrierL.x,
                        pal_v_sign * (chromaL - pal_delay.g) * carrierL.y);
                    
                    float delay_weight = max(phase_blend, correlation_weight);
                    vec2 mixed_uv = mix(simple_uv, delay_uv, delay_weight);
                    
                    demodL = vec3(compositeL, mixed_uv.x, mixed_uv.y);
                } else if (use_delay_line) {
                    // DELAY: Phase-corrected PAL delay-line
                    vec2 dxy = vec2((-nf - dx_phase_offset_px) * dx.x, -tb.pixels_per_line * config.OutputSize.w);
                    vec3 pal_delay = texture(Source, Tex + dxy).rgb;

                    demodL = vec3(
                        compositeL,
                        (chromaL + pal_delay.g) * carrierL.x,
                        pal_v_sign * (chromaL - pal_delay.g) * carrierL.y);
                } else {
                    // SIMPLE: Direct demodulation
                    demodL = vec3(
                        compositeL,
                        2.0 * chromaL * carrierL.x,
                        pal_v_sign * 2.0 * chromaL * carrierL.y);
                }
            } else {
                demodL = vec3(
                    compositeL,
                    2.0 * chromaL * carrierL.x,
                    2.0 * chromaL * carrierL.y);
            }
            

            color.r += w_y_r * demodR.r + w_y_l * demodL.r;
            color.g += w_c_r * demodR.g + w_c_l * demodL.g;
            color.b += w_c_r * demodR.b + w_c_l * demodL.b;
            wsum.x += w_y_r + w_y_l;
            wsum.y += w_c_r + w_c_l;
            wsum.z += w_c_r + w_c_l;
            
        }

        // Normalize
        color /= max(wsum, vec3(EPS));
    }

    float chroma = color.g * carrier0.x + color.b * carrier0.y;

    if (COMB_FILTER_2D > 0.5) {
        if (COLOR_FILTER_MODE < 0.5) {
            // Notch
        } else if (COLOR_FILTER_MODE < 1.5) {
            // Comb filter
            color.r = bypass - chroma;
            chroma = bypass - color.r;
            color.gb = 2.0 * chroma * carrier0;
        } else if (COLOR_FILTER_MODE < 2.5) {
            // Notch + Comb
            float y_notch = color.r;
            vec2 c_notch = color.gb;
            float y_comb = bypass - chroma;
            chroma = bypass - color.r;
            vec2 c_comb = 2.0 * chroma * carrier0;

            color = 0.5 * (vec3(y_notch, c_notch) + vec3(y_comb, c_comb));
        }
    }

    if (USER_MONOCHROME > 0.5) {
        // Monochrome modes
        float mono;

        if (USER_MONOCHROME < 1.5) {
            // Standard black & white
            color.g = 0.0;
            color.b = 0.0;
        } else {
            // Sepia tone - apply warm tint in YIQ space
            vec3 yiq = color;

            // Convert current color space to YIQ if needed
            if (DECODER_TYPE > 0.5) {
                if (DECODER_TYPE < 1.5) {
                    yiq = RGB_TO_YIQ * YPbPr_TO_RGB * color;
                } else {
                    yiq = RGB_TO_YIQ * YUV_TO_RGB * color;
                }
            }

            // Apply sepia toning in YIQ
            yiq.g = 0.1;  // Orange-cyan (I channel)
            yiq.b = 0.0;  // Green-magenta (Q channel)

            // Convert back to current color space
            if (DECODER_TYPE < 0.5) {
                color = yiq;
            } else if (DECODER_TYPE < 1.5) {
                color = RGB_TO_YPbPr * YIQ_TO_RGB * yiq;
            } else {
                color = RGB_TO_YUV * YIQ_TO_RGB * yiq;
            }
        }
    }

    // Correct for setup if necessary
    if (DECODER_SETUP > 0.5) {
        color.r = (color.r - 0.075) / 0.925;
    }

    // Apply user color
    color.gb *= vec2(c_gain);

    if (BW_MODE < 0.5) {
        color = toRGB * color;
    } else if (BW_MODE < 1.5) {
        color = vec3(bypass);
    } else if (BW_MODE < 2.5) {
        color = vec3(y_out);
    } else if (BW_MODE < 3.5) {
        color = vec3(c_out);
    } else {
        color = vec3(y_out, c_out, c_out);
    }

    FragColor = vec4(color, 1.0);
}
