#version 450

// Filename: iq-mod.slang
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
// IQ baseband modulation shader for VSB
// -----------------------------------------------------------------
// Input: Component voltage signal (RGB)
// Output: Complex IQ baseband representation (R16G16_SFLOAT)
// 
// This shader models VSB modulation in complex baseband (I/Q) form:
// - Consumes analytic baseband (R=I, G=Q) from composite-iq.slang
// - Applies asymmetric lowpass filtering (I: 4.2 MHz, Q: 0.75 MHz)
// - Per-channel bypass: I filter, Q filter
// - Optional overall I/Q bypass for quick debugging
// - Operates entirely at baseband (no RF carrier)

// Includes trimmed to what is needed for timebase and windowed sinc
#include "common.inc"
#include "window.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/rf.inc"

// Bypass & control parameters
#pragma parameter BYPASS_IQ_MOD "Bypass I/Q filtering (off,on)" 0.0 0.0 1.0 1.0
#pragma parameter BYPASS_I_FILTER "Bypass I lowpass (off,on)" 0.0 0.0 1.0 1.0
#pragma parameter BYPASS_Q_FILTER "Bypass Q lowpass (off,on)" 0.0 0.0 1.0 1.0

#pragma name IQMod
#pragma format R16G16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameSize;
    uint FrameCount;
    float OriginalFPS;
    float BYPASS_IQ_MOD;
    float BYPASS_I_FILTER;
    float BYPASS_Q_FILTER;
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
    float USB_ROLL_OFF;
    float LSB_ROLL_OFF;
} config;

#define BYPASS_IQ_MOD      config.BYPASS_IQ_MOD
#define BYPASS_I_FILTER    config.BYPASS_I_FILTER
#define BYPASS_Q_FILTER    config.BYPASS_Q_FILTER
#define V_FREQ_MODE        config.V_FREQ_MODE
#define V_FREQ             config.V_FREQ
#define SHORTEN_ODD_FIELD_TIME config.SHORTEN_ODD_FIELD_TIME
#define SC_FREQ_MODE       config.SC_FREQ_MODE
#define SC_FREQ            config.SC_FREQ
#define PIXEL_CLOCK_MODE   config.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK        config.PIXEL_CLOCK
#define H_FREQ_MODE        config.H_FREQ_MODE
#define H_FREQ             config.H_FREQ
#define H_BLANK_FUZZ       config.H_BLANK_FUZZ

#define USB_BANDWIDTH       config.USB_BANDWIDTH
#define LSB_BANDWIDTH       config.LSB_BANDWIDTH
#define USB_ROLL_OFF        config.USB_ROLL_OFF
#define LSB_ROLL_OFF        config.LSB_ROLL_OFF

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

// VSB baseband parameters
#define VSB_I_CUTOFF_MHZ USB_BANDWIDTH
#define VSB_Q_CUTOFF_MHZ LSB_BANDWIDTH

// Hamming windowed-sinc filter design (asymmetric per channel)
// Stopband: ~43 dB, minimal ringing (~1.5% overshoot)
// Analytical tap count formula: N = 3.3 / transition_width
// Transition width = TRANSITION_FACTOR × fc_norm (normalized cutoff)
const float HAMMING_TRANSITION_CONST = 3.3; // Hamming -43 dB stopband

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float fc_i_norm;          // I channel cutoff (normalized)
layout(location = 2) out float fc_q_norm;          // Q channel cutoff (normalized)
layout(location = 3) out float taps_i;             // I channel tap count (even)
layout(location = 4) out float taps_q;             // Q channel tap count (even)
layout(location = 5) out TimebaseConfig tb;

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

    float transition_i = USB_ROLL_OFF / USB_BANDWIDTH;
    float transition_q = LSB_ROLL_OFF / LSB_BANDWIDTH;
    
    // Normalize cutoff frequencies to sample rate (cycles per sample)
    fc_i_norm = (VSB_I_CUTOFF_MHZ * 1.0e6) * tb.pixel_time_px;
    fc_q_norm = (VSB_Q_CUTOFF_MHZ * 1.0e6) * tb.pixel_time_px;

    // Analytical tap count design for Hamming window
    // Formula: N = HAMMING_TRANSITION_CONST / transition_width
    // Transition band = TRANSITION_FACTOR × cutoff frequency    
    float taps_i_calc = HAMMING_TRANSITION_CONST / max(transition_i * fc_i_norm, EPS);
    float taps_q_calc = HAMMING_TRANSITION_CONST / max(transition_q * fc_q_norm, EPS);
    
    // Round to odd numbers for symmetric FIR (center + pairs)
    taps_i = int(ceil(taps_i_calc));
    if (int(mod(taps_i, 2.0)) == 0) taps_i += 1.0;
    taps_q = int(ceil(taps_q_calc));
    if (int(mod(taps_q, 2.0)) == 0) taps_q += 1.0;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float fc_i_norm;
layout(location = 2) in float fc_q_norm;
layout(location = 3) in float taps_i;
layout(location = 4) in float taps_q;
layout(location = 5) in TimebaseConfig tb;
layout(location = 0) out vec4 FragColor;
// Source is the analytic signal produced by composite-iq.slang: R=I, G=Q
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Input here is already composite→analytic

    vec2 UV = vTexCoord * config.OutputSize.xy;
    float line = floor(UV.y) / tb.pixels_per_line;
    float baseIndex = floor(UV.x);
    float baseCenter = baseIndex + 0.5;
    float Ax = UV.x - baseCenter;
    
    vec2 Tex = vec2(
        baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);

    vec2 dx = vec2(config.OutputSize.z, 0.0);
    int max_tap_i = int(taps_i);
    int max_tap_q = int(taps_q);
    int max_tap = max(max_tap_i, max_tap_q);
    
    // Central sample from analytic input
    vec2 iq0 = texture(Source, Tex).rg;

    if (BYPASS_IQ_MOD > 0.5) {
        FragColor = vec4(iq0.r, iq0.g, 0.0, 1.0); // pass-through analytic
        return;
    }

    // Apply asymmetric lowpass filtering for VSB to the analytic input
    float i_signal = 0.0;
    float i_wsum = 0.0;
    if (BYPASS_I_FILTER > 0.5) {
        i_signal = iq0.r;
        i_wsum = 1.0;
        max_tap_i = 0; // skip loop accumulation
    } else {
        float coeff0_i = sinc_lowpass_hamming(-Ax, fc_i_norm, taps_i);
        i_signal = coeff0_i * iq0.r;
        i_wsum = coeff0_i;
    }
    
    float q_signal = 0.0;
    float q_wsum = 0.0;
    if (BYPASS_Q_FILTER > 0.5) {
        q_signal = iq0.g;
        q_wsum = 1.0;
        max_tap_q = 0;
    } else {
        float coeff0_q = sinc_lowpass_hamming(-Ax, fc_q_norm, taps_q);
        q_signal = coeff0_q * iq0.g;
        q_wsum = coeff0_q;
    }
    
    // Convolve both channels with neighboring samples (single texture fetch per offset)
    int n_pairs = int(floor(max_tap * 0.5));

    for (int n = 1; n <= 45; ++n) {
        if (n > n_pairs)
            break;
        
        float nf = float(n);
        
        // Neighbor analytic samples
        vec2 tex_r = Tex + nf * dx;
        vec2 tex_l = Tex - nf * dx;

        float coeff_mag = 0.0;
        float coeff_r_i = 0.0;
        float coeff_l_i = 0.0;
        float coeff_r_q = 0.0;
        float coeff_l_q = 0.0;

        // Apply lowpass filter coefficients
        if (n <= max_tap_i) {
            coeff_r_i = sinc_lowpass_hamming(nf - Ax, fc_i_norm, taps_i);
            coeff_l_i = sinc_lowpass_hamming(-nf - Ax, fc_i_norm, taps_i);
            coeff_mag = max(coeff_mag, abs(coeff_r_i) + abs(coeff_l_i));
        }

        // Q channel (may use fewer/more taps); skip when beyond taps_q
        if (n <= max_tap_q) {
            coeff_r_q = sinc_lowpass_hamming(nf - Ax, fc_q_norm, taps_q);
            coeff_l_q = sinc_lowpass_hamming(-nf - Ax, fc_q_norm, taps_q);
            coeff_mag = max(coeff_mag, abs(coeff_r_q) + abs(coeff_l_q));
        }

        if (coeff_mag < FILTER_THRESHOLD)
            break;

        vec2 iq_r = texture(Source, tex_r).rg;
        vec2 iq_l = texture(Source, tex_l).rg;

        i_signal += coeff_r_i * iq_r.r + coeff_l_i * iq_l.r;
        i_wsum += coeff_r_i + coeff_l_i;

        q_signal += coeff_r_q * iq_r.g + coeff_l_q * iq_l.g;
        q_wsum += coeff_r_q + coeff_l_q;
    }
    
    // Normalize filters to maintain unity gain
    i_signal /= max(i_wsum, EPS);
    q_signal /= max(q_wsum, EPS);
      
    // Output complex IQ: (I, Q) in RG channels
    FragColor = vec4(i_signal, q_signal, 0.0, 1.0);
}
