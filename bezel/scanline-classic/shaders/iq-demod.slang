#version 450

// Filename: iq-demod.slang
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
// IQ baseband demodulation shader for VSB (matches new mod pipeline)
// -----------------------------------------------------------------
// Input: Complex IQ baseband (R16G16_SFLOAT, RG channels) from iq-mod.slang
// Output: Recovered composite baseband (R16_SFLOAT)
//
// Demod strategies:
// Method 0 (Hilbert): composite = I_lp - Hilbert{Q_lp}
//   Uses H{H{x}} = -x identity to restore vestigial sideband
// Method 1 (Weighted): composite = I_lp + alpha * Q_lp
//   Direct weighted combination where alpha accounts for VSB asymmetry
// - Blackman-Harris 4-term windowed-sinc lowpass with adaptive taps

#include "common.inc"
#include "modulation.inc"
#include "window.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/sys-encode.inc"
#include "menus/parameters/rf.inc"

#pragma parameter BYPASS_IQ_DEMOD "Bypass IQ demod (off, on)" 0.0 0.0 1.0 1.0

#pragma name IQDemod
#pragma format R16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OriginalFPS;
    float BYPASS_IQ_DEMOD;
    float IQ_DEMOD_Q_WEIGHT;
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
    float USB_BANDWIDTH;
    float LSB_BANDWIDTH;
} config;

#define BYPASS_IQ_DEMOD config.BYPASS_IQ_DEMOD
#define IQ_DEMOD_Q_WEIGHT config.IQ_DEMOD_Q_WEIGHT
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
#define USB_BANDWIDTH config.USB_BANDWIDTH
#define LSB_BANDWIDTH config.LSB_BANDWIDTH

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

// VSB baseband parameters (must match iq-mod.slang)
#define VSB_I_CUTOFF_MHZ USB_BANDWIDTH
#define VSB_Q_CUTOFF_MHZ LSB_BANDWIDTH

// Hamming windowed-sinc lowpass (matched to iq-filter.slang)
// Stopband: ~43 dB, minimal ringing (~1.5% overshoot)
// Analytical tap count formula: N = 3.3 / transition_width
const float HAMMING_TRANSITION_CONST = 3.3;  // Hamming -43 dB stopband
const float TRANSITION_FACTOR = 0.15;        // 15% of cutoff frequency

// Hilbert demod removed; weighted method only

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float fc_i_norm;      // I cutoff normalized
layout(location = 2) out float fc_q_norm;      // Q cutoff normalized
layout(location = 3) out float taps_i;         // I tap count
layout(location = 4) out float taps_q;         // Q tap count
layout(location = 5) out TimebaseConfig tb;

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

    // Compute output texture sample rate
    float sample_rate_hz = 1.0 / tb.pixel_time_px;

    // Normalize per-channel cutoffs
    fc_i_norm = (VSB_I_CUTOFF_MHZ * 1.0e6) / sample_rate_hz;
    fc_q_norm = (VSB_Q_CUTOFF_MHZ * 1.0e6) / sample_rate_hz;

    // Analytical tap count design for Hamming window
    // Formula: N = HAMMING_TRANSITION_CONST / transition_width
    // Transition band = TRANSITION_FACTOR × cutoff frequency
    
    // I channel: wider bandwidth → narrower transition → fewer taps needed
    float transition_i = TRANSITION_FACTOR * fc_i_norm;
    float taps_i_calc = HAMMING_TRANSITION_CONST / max(transition_i, 0.01);
    
    // Q channel: narrower bandwidth → needs more taps for sharp cutoff
    float transition_q = TRANSITION_FACTOR * fc_q_norm;
    float taps_q_calc = HAMMING_TRANSITION_CONST / max(transition_q, 0.01);
    
    // Round to even numbers for symmetric FIR
    taps_i = ceil(taps_i_calc * 0.5) * 2.0;
    taps_q = ceil(taps_q_calc * 0.5) * 2.0;
    
    // Clamp to reasonable bounds (avoid degenerate or excessive tap counts)
    taps_i = clamp(taps_i, 8.0, 32.0);
    taps_q = clamp(taps_q, 12.0, 56.0);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float fc_i_norm;
layout(location = 2) in float fc_q_norm;
layout(location = 3) in float taps_i;
layout(location = 4) in float taps_q;
layout(location = 5) in TimebaseConfig tb;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    if (BYPASS_IQ_DEMOD > 0.5) {
        // Passthrough I as composite for quick debug
        vec2 iq_passthru = texture(Source, vTexCoord).rg;
        FragColor = vec4(iq_passthru.r, 0.0, 0.0, 1.0);
        return;
    }

    vec2 UV = vTexCoord * config.OutputSize.xy;
    float line = floor(UV.y) / tb.pixels_per_line;
    float baseIndex = floor(UV.x);
    float baseCenter = baseIndex + 0.5;
    float Ax = UV.x - baseCenter;

    vec2 Tex = vec2(
        baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);

    // IQ input (RG channels)
    vec2 iq0 = texture(Source, Tex).rg;
    vec2 dx = vec2(config.OutputSize.z, 0.0);

    // Lowpass I and Q separately (matched to modulator)
    float I_lp = 0.0, I_w = 0.0;
    float Q_lp = 0.0, Q_w = 0.0;

    // Center coefficients
    float c0_i = sinc_lowpass_hamming(-Ax, fc_i_norm, taps_i);
    float c0_q = sinc_lowpass_hamming(-Ax, fc_q_norm, taps_q);
    I_lp = c0_i * iq0.r; I_w = c0_i;
    Q_lp = c0_q * iq0.g; Q_w = c0_q;
    
    // Hilbert at center is zero for odd kernel, skip

    int max_i = int(taps_i);
    int max_q = int(taps_q);
    int max_n = max(max_i, max_q);
    
    for (int n = 1; n <= 56; ++n) {
        if (n > max_n)
            break;
        float nf = float(n);

        float coeff_mag = 0.0;

        vec2 iq_r = texture(Source, Tex + nf * dx).rg;
        vec2 iq_l = texture(Source, Tex - nf * dx).rg;

        if (n <= max_i) {
            float cr_i = sinc_lowpass_hamming(nf - Ax, fc_i_norm, taps_i);
            float cl_i = sinc_lowpass_hamming(-nf - Ax, fc_i_norm, taps_i);
            I_lp += cr_i * iq_r.r + cl_i * iq_l.r;
            I_w  += cr_i + cl_i;
            coeff_mag = max(coeff_mag, abs(cr_i) + abs(cl_i));
        }

        if (n <= max_q) {
            float cr_q = sinc_lowpass_hamming(nf - Ax, fc_q_norm, taps_q);
            float cl_q = sinc_lowpass_hamming(-nf - Ax, fc_q_norm, taps_q);
            float qr = iq_r.g, ql = iq_l.g;
            Q_lp += cr_q * qr + cl_q * ql;
            Q_w  += cr_q + cl_q;
            coeff_mag = max(coeff_mag, abs(cr_q) + abs(cl_q));
        }

        if (coeff_mag < FILTER_THRESHOLD)
            break;
    }

    // Normalize
    I_lp /= max(I_w, EPS);
    Q_lp /= max(Q_w, EPS);
    
    // Weighted demodulation only
    // composite = I_lp + alpha * Q_lp
    // where alpha ≈ -K_VSB (vestige/full ratio, typically -0.27 for NTSC)
    float composite = I_lp + IQ_DEMOD_Q_WEIGHT * Q_lp;
    
    FragColor = vec4(composite, 0.0, 0.0, 1.0);
}
