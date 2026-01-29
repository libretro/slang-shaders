#version 450

/* Filename: svideo.slang

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
   along with this program.  If not, see <https://www.gnu.org/licenses/>.


    S-Video (Y/C) demodulation + low-pass reconstruction

    Overview
    --------
    This shader simulates an S-Video (Y/C) signal path and reconstructs baseband
    luma/chroma suitable for downstream display processing. The input texture is
    interpreted as:
      - R: Luma (Y)
      - G: Quadrature chroma component (U-like, 90°)
      - B: In-phase chroma component (V-like, 0°)
    These baseband U/V components are modulated against a color subcarrier to
    form a scalar chroma signal c(t) at the local carrier phase. The shader then
    demodulates and low-pass filters chroma to reject 2·fSC images and recover
    U′/V′, while luma is filtered independently with a higher bandwidth.

    Signal model
    ------------
    Let ω = 2π·fSC and φ = field_phase. For a given sample time t:
      c(t) = U·sin(ωt + φ) + V·cos(ωt + φ)
    We estimate baseband chroma via quadrature demod + low-pass:
      U_est = 2·LPF{ c(t)·sin(ωt + φ) }
      V_est = 2·LPF{ c(t)·cos(ωt + φ) }
    In practice:
      - Accumulate symmetric Gaussian taps horizontally.
      - Use σY and σC to control bandwidth and roll-off independently.
      - The factor 2 recovers correct baseband amplitude after LPF removes
        double-frequency terms (cos/sin at 2·ω).

    Timebase and subcarrier
    -----------------------
    Time per pixel and carrier phase are derived via compute_timebase():
      - V_LINES_PER_FIELD is computed internally from V_FREQ and core refresh rate
      - H frequency: H_FREQ_HZ derived from timing mode parameters
      - Total pixels per line derived from PIXEL_CLOCK and H_FREQ_HZ
      - Pixel time: pixel_time = LINE_TIME / total_pixels, where LINE_TIME = 1/H_FREQ_HZ
      - Subcarrier frequency fSC:
          SC_FREQ_MODE = 0 (Auto): Derived from H rate and pixel clock
          SC_FREQ_MODE = 1 (NTSC): fSC = NTSC_FSC
          SC_FREQ_MODE = 2 (PAL):  fSC = PAL_FSC
          SC_FREQ_MODE = 3 (Custom): fSC = SC_FREQ (MHz) · 1e6
      - Field phase:
          field_phase = mod(FIELD_TIME · field · 2π·fSC - Δt_odd · 2π·fSC, 2π) - π
        with FIELD_TIME = 1/V_FREQ and:
          Δt_odd = ceil(field/2) · odd_time_adjust · SHORTEN_ODD_FIELD_TIME
        Here odd_time_adjust = (OriginalSize.x / 256) · pixel_time, which approximates
        the half-line offset behavior at common horizontal sizes.

    Demodulation and filtering
    --------------------------
    For each horizontal sample:
      1) Compute per-sample carrier phase using precision-safe accumulation:
          phase = 2π · fract(fSC · t) + field_phase
        where t = line · LINE_TIME + x · pixel_time.
      2) Form local sin/cos with a single paired call:
          carrier = (sin(phase), cos(phase))
      3) Chroma projection:
          chroma = U · carrier.x + V · carrier.y
      4) Remodulate for quadrature LP extraction (per sample):
          U′_sample = 2 · chroma · carrier.x
          V′_sample = 2 · chroma · carrier.y
      5) Accumulate symmetric Gaussian lobes horizontally with σY/σC.
        Early exit once both weights fall below FILTER_THRESHOLD.

    Output mapping
    --------------
    - Normal: R = filtered Y, G = filtered U′, B = filtered V′
    - BW modes:
        1: Y-only to all channels
        2: C-only (scalar chroma) to all channels
        3: YC split (R=Y, B=C, G=0)
      The center-sample fast path can be enabled with SVIDEO_FILTER_BYPASS.

    Performance and precision
    -------------------------
    - Carrier math is optimized via:
        • phase = 2π·fract(fSC·t) + field_phase  (keeps phase bounded)
        • a single “sincos” pair (sincos_phase) per sample
      This avoids large-argument trig loss and removes repeated mod() calls.
    - Gaussian accumulation does up to 32 taps per side with early exit. σY/σC
      and FILTER_THRESHOLD control cost/quality.

    Parameters (UI)
    ---------------
    - BYPASS_SVIDEO: Bypass shader
    - SVIDEO_FILTER_BYPASS: Use center-sample demod (skip Gaussian)
    - V_FREQ_MODE: Vertical frequency mode (0=Core, 1=NTSC, 2=PAL, 3=From H, 4=Custom)
    - V_FREQ: Custom vertical frequency (Hz) when mode is Custom
    - SHORTEN_ODD_FIELD_TIME: Enable odd-field timing offset (interlaced behavior)
    - SC_FREQ_MODE:
        0 Auto   • derive from H rate and total pixels
        1 NTSC   • fSC = 3.579545 MHz
        2 PAL    • fSC = 4.43361875 MHz
        3 Custom • fSC = SC_FREQ (MHz)
    - SC_FREQ: Custom fSC in MHz when mode is Custom
    - PIXEL_CLOCK_MODE: Pixel clock mode (0=Fixed MHz, 1=Multiple of subcarrier)
    - PIXEL_CLOCK: Pixel clock in MHz or multiplier (determines total horizontal pixels)
    - H_FREQ_MODE: Horizontal frequency mode (0=Standard, 1=From pixel clock, 2=Custom)
    - H_FREQ: Custom H frequency or divisor (kHz or cycles)
    - H_BLANK_FUZZ: Horizontal blanking adjustment (%)
    - DISPLAY_BANDWIDTH_Y/C: Display bandwidth (MHz) for Y and C
    - DISPLAY_CUTOFF_ATTEN_Y/C: Gaussian cutoff attenuation (dB)
    - BW_MODE: 0=Normal, 1=BW (Y-only), 2=Y, 3=C, 4=Y+C split

    Implementation notes
    --------------------
    - Dependencies:
        • common.h: PI, EPS, helpers
        • color.h: NTSC_FSC, PAL_FSC constants
        • bandlimit.inc: sigma601() for bandwidth→σ mapping
        • modulation.inc: sincos_phase(), compute_carrier_phase()
    - Coordinates:
        • Timing uses OriginalSize.{x,y} for subcarrier derivation and line index,
          matching composite.slang’s behavior.
        • Sampling uses OutputSize to locate the current pixel, then converts to Source space.
    - Threshold:
        • FILTER_THRESHOLD = 1/510 controls early exit on both Y/C lobes.
    - Odd field adjust:
        • odd_time_adjust = (OriginalSize.x / 256) · pixel_time; scaled to approximate
          half-line shortening for interlaced fields across common widths.

    Tuning tips
    -----------
    - NTSC: SC_FREQ_MODE=1, V_FREQ_MODE=1 (59.94 Hz, 262.5 lines computed)
    - PAL:  SC_FREQ_MODE=2, V_FREQ_MODE=2 (50.00 Hz, 312.5 lines computed)
    - Reduce dot crawl/zipper: Increase DISPLAY_CUTOFF_ATTEN_C or reduce DISPLAY_BANDWIDTH_C
    - Sharper luma: Increase DISPLAY_BANDWIDTH_Y, balance with C to avoid color bleeding
    - If phase jitter appears over long runs, ensure timing parameters reflect the source
      so timebase derivation aligns well; otherwise pick NTSC/PAL mode explicitly.
*/

#include "common.inc"
#include "color.inc"
#include "bandlimit.inc"
#include "modulation.inc"

#include "menus/parameters/user-video.inc"
#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/svideo.inc"
#include "menus/parameters/sys-encode.inc"

#pragma name SVideo
#pragma format R16G16B16A16_SFLOAT

#pragma parameter BYPASS_SVIDEO "Bypass S-Video processing (0=Off, 1=On)" 0.0 0.0 1.0 1.0
#pragma parameter SVIDEO_FILTER_BYPASS "S-Video filter bypass (use center sample)" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameSize;
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
    float USER_SHARPNESS;
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
#define USER_SHARPNESS config.USER_SHARPNESS
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
    float ENCODER_SETUP;
    float DECODER_SETUP;
    float PAL;
    float DECODER_TYPE;
} global;

#define BYPASS_SVIDEO global.BYPASS_SVIDEO
#define SVIDEO_FILTER_BYPASS global.SVIDEO_FILTER_BYPASS

#define BW_MODE global.BW_MODE

#define ENCODER_SETUP global.ENCODER_SETUP
#define DECODER_SETUP global.DECODER_SETUP
#define PAL global.PAL
#define DECODER_TYPE global.DECODER_TYPE

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

    // Precompute timebase config for fragment stage
    TimebaseConfig tb = compute_timebase(
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

    // Precompute per-component sigmas for fragment stage
    sigma.x = sigma_tb(tb, DISPLAY_BANDWIDTH_Y, DISPLAY_CUTOFF_ATTEN_Y);
    sigma.y = sigma_tb(tb, DISPLAY_BANDWIDTH_C, DISPLAY_CUTOFF_ATTEN_C);
    sigma.z = sigma.y; // sigma.z == sigma.y for chroma

    // Precompute user color gain/phase
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

    // Horizontal coordinate handling using nearest pixel center (keep Y center)
    vec2 UV = vTexCoord * config.OutputSize.xy;
    float baseIndex = floor(UV.x);         // nearest pixel index
    float baseCenter = baseIndex + 0.5;    // pixel center coordinate
    float Ax = UV.x - baseCenter;          // offset from center in [-0.5, 0.5]
    vec2 Tex = vec2(baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);
    vec2 dx  = vec2(config.OutputSize.z, 0.0);

    // Accumulators: vector (normal path) + scalar luma/chroma for BW modes
    vec3 accum = vec3(0.0);
    vec3 wsum  = vec3(0.0);

    // Center sample
    float line = floor(UV.y) / carrier.pixels_per_line;
    float t0 = line / carrier.h_freq_hz + baseCenter * carrier.pixel_time_px;

    // PAL V-axis alternation: simply invert V on odd lines
    float pal_v_sign = 1.0 - 2.0 * floor(mod(line, 2.0)) * PAL;
    float pal_v_sign_decoder = 1.0 - 2.0 * floor(mod(line, 2.0)) * DECODER_TYPE;

    vec3 pixel0 = texture(Source, Tex).rgb;
    float phase_inc_px = 2.0 * PI * carrier.sc_freq_hz * carrier.pixel_time_px;
    float phase0 = compute_carrier_phase(t0, carrier.sc_freq_hz, carrier.field_phase);
    float phase0_user = normalize_phase(phase0 + c_phase);
    phase0 = normalize_phase(phase0);
    vec2 carrier0 = sincos_phase_raw(phase0);
    vec2 carrier0_user = sincos_phase_raw(phase0_user);
    float chroma0 = pixel0.g * carrier0.x + pal_v_sign * pixel0.b * carrier0.y;

    float y_gain = 1.0;
    float y_offset = 0.0;

    if (ENCODER_SETUP > 0.5) {
        y_gain = 0.925;
        y_offset = 0.075;
    }

    // Monitor mode: use center sample directly (bypass filter)
    float y_out = y_gain * (pixel0.r + y_offset);
    float c_out = chroma0;

    vec3 yc0;
    yc0.r = y_out;
    yc0.g = chroma0 * 2.0 * carrier0_user.x;
    yc0.b = chroma0 * 2.0 * carrier0_user.y * pal_v_sign_decoder;

    vec3 color;

    // Optional filter bypass: use center-sample demodulated values directly
    if (SVIDEO_FILTER_BYPASS < 0.5) {
        float wy0 = gaussian(Ax, sigma.x);
        float wc0 = gaussian(Ax, sigma.y); // sigma.y == sigma.z for chroma

        accum += vec3(wy0 * yc0.r, wc0 * yc0.g, wc0 * yc0.b);
        wsum  += vec3(wy0, wc0, wc0);

        // Symmetric lobes
        // Limited to 16 iterations for faster shader compilation
        // Gaussian weights fall off rapidly, so early exit handles quality
        for (int n = 1; n <= 16; ++n) {
            float nf = float(n);
            // Symmetric distances: right = n - Ax, left = n + Ax
            float wy_r = gaussian(nf - Ax, sigma.x);
            float wy_l = gaussian(nf + Ax, sigma.x);
            float wc_r = gaussian(nf - Ax, sigma.y);
            float wc_l = gaussian(nf + Ax, sigma.y);
            if (wy_r < FILTER_THRESHOLD && wy_l < FILTER_THRESHOLD && wc_r < FILTER_THRESHOLD && wc_l < FILTER_THRESHOLD)
                break;

            vec3 pixelR = texture(Source, Tex + nf * dx).rgb;
            // Compute exact phase at right tap position to avoid drift
            float phaseR = normalize_phase(phase0 + phase_inc_px * nf);
            float phaseR_user = normalize_phase(phase0_user + phase_inc_px * nf);
            vec2 carrierR = sincos_phase_raw(phaseR);
            vec2 carrierR_user = sincos_phase_raw(phaseR_user);
            float chromaR = pixelR.g * carrierR.x + pal_v_sign * pixelR.b * carrierR.y;
            vec3 ycR;
            ycR.r = y_gain * (pixelR.r + y_offset);
            ycR.g = chromaR * 2.0 * carrierR_user.x;
            ycR.b = chromaR * 2.0 * carrierR_user.y * pal_v_sign_decoder;

            vec3 pixelL = texture(Source, Tex - nf * dx).rgb;
            // Compute exact phase at left tap position to avoid drift
            float phaseL = normalize_phase(phase0 - phase_inc_px * nf);
            float phaseL_user = normalize_phase(phase0_user - phase_inc_px * nf);
            vec2 carrierL = sincos_phase_raw(phaseL);
            vec2 carrierL_user = sincos_phase_raw(phaseL_user);
            float chromaL = pixelL.g * carrierL.x + pal_v_sign * pixelL.b * carrierL.y;
            vec3 ycL;
            ycL.r = y_gain * (pixelL.r + y_offset);
            ycL.g = chromaL * 2.0 * carrierL_user.x;
            ycL.b = chromaL * 2.0 * carrierL_user.y * pal_v_sign_decoder;

            accum.x += wy_r * ycR.x + wy_l * ycL.x;
            accum.y += wc_r * ycR.y + wc_l * ycL.y;
            accum.z += wc_r * ycR.z + wc_l * ycL.z;
            wsum.x  += wy_r + wy_l;
            wsum.y  += wc_r + wc_l;
            wsum.z  += wc_r + wc_l;
        }

        // Normalized outputs
        color = accum / max(wsum, vec3(EPS));
    } else {
        color = vec3(y_out, yc0.g, yc0.b);
    }

    if (USER_MONOCHROME > 0.5) {
        // Monochrome modes
        float mono;

        if (USER_MONOCHROME < 1.5) {
            // Standard black & white
            color.g = 0.0;
            color.b = 0.0;
        } else {
            // Sepia tone
            vec3 yiq = color;

            yiq.g = 0.1;
            yiq.b = 0.0;
            color = RGB_TO_YPbPr * YIQ_TO_RGB * yiq;
        }
    }

    // Correct setup
    if (DECODER_SETUP > 0.5) {
        color.r = (color.r - 0.075) / 0.925;
        y_out = (y_out - 0.075) / 0.925;
    }

    // Apply user color
    color.gb *= vec2(c_gain);

    // Convert to RGB
    if (BW_MODE < 0.5) {
        color = YPbPr_TO_RGB * color;
    } else if (BW_MODE < 1.5) {
        // BW mode: Y + C to Y channel
        color = vec3(y_out + c_out);
    } else if (BW_MODE < 2.5) {
        // Y mode
        color = vec3(y_out);
    } else if (BW_MODE < 3.5) {
        // C mode
        color = vec3(c_out);
    } else {
        // YC mode
        color = vec3(y_out, c_out, c_out);
    }

    FragColor = vec4(color, 1.0);
}