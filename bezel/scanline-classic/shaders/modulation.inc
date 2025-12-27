/* Filename: modulation.inc

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

// Shared modulation and demodulation functions for composite and S-Video processing

const float NTSC_FSC = 3.579545e6;
const float PAL_FSC = 4.433618750e6;
const float PAL_M_FSC = 3.575611e6;

#define NTSC_H_FREQ (NTSC_FSC / 227.5) // ≈15.734 kHz
const float PAL_H_FREQ = 15.625e3;
#define PAL_M_H_FREQ (PAL_M_FSC / 227.25) // ≈15.734 kHz

const float NTSC_V_FREQ = 59.94;
const float PAL_V_FREQ = 50.0;
const float PAL_M_V_FREQ = 59.94;

// Timebase and subcarrier configuration
struct TimebaseConfig {
    float field;
    float field_phase;
    float h_freq_hz;
    float sc_freq_hz;
    float pixel_time;
    float pixel_time_px;
    float h_pixels;
    float v_lines_per_field;
    float v_lines_per_frame;
    float is_interlaced;
    float pixels_per_line;
};

// Phase normalization helper. Keeps phase bounded in [-PI, PI].
// Prefer calling this at the call site right before trig for best optimizer behavior.
float normalize_phase(float phase) {
    return mod(phase + PI, 2.0 * PI) - PI;
}

// Optimized sincos helper - computes both sin and cos in one call
// Returns vec2(sin(phase), cos(phase))
// NOTE: During migration, call sites should pre-normalize using normalize_phase()
// and use sincos_phase_raw(). This function is kept for backward compatibility
// and will be simplified to the raw form after all call sites are updated.
vec2 sincos_phase(float phase) {
    return vec2(sin(phase), cos(phase));
}

// Raw variant without internal normalization. Caller must ensure phase is bounded.
vec2 sincos_phase_raw(float phase) {
    return vec2(sin(phase), cos(phase));
}

// Vec2 overloads. The convention in this codebase uses phase.x for sin and phase.y for cos.
vec2 sincos_phase(vec2 phase) {
    return vec2(sin(phase.x), cos(phase.y));
}

vec2 sincos_phase_raw(vec2 phase) {
    return vec2(sin(phase.x), cos(phase.y));
}

// Compute carrier phase with precision-preserving normalization
// Uses fract() to keep phase bounded and prevent floating-point drift
// over long runtimes or high line numbers
float compute_carrier_phase(float t, float sc_freq_hz, float field_phase) {
    // Use fract to keep phase bounded and preserve precision
    // Normalize by extracting only fractional cycles to keep values small
    float cycles = sc_freq_hz * t;
    float fractional_cycles = fract(cycles);
    float phase = 2.0 * PI * fractional_cycles + field_phase;
    // Ensure phase is in [-PI, PI] so downstream callers may safely use raw trig
    return normalize_phase(phase);
}

// Compute complete timebase configuration for composite/S-Video processing
// Assumptions:
//   - Vertical line index derived from v_lines_per_field (includes blanking as needed).
//   - tex_coord.y ∈ [0,1] spans the field; floor(tex_coord.y * v_lines_per_field) gives line number.
// If you need active-only line indexing, reintroduce an original_height parameter or scale.
TimebaseConfig compute_timebase(
    uint frame_count,
    vec2 tex_coord,
    vec2 original_size,
    vec2 output_size,
    float core_refresh_hz,
    float sc_freq_mode,
    float sc_freq_custom_mhz,
    float pixel_clock_mhz,
    float pixel_clock_mode,
    float h_freq_mode,
    float h_freq_custom_khz,
    float v_freq_mode,
    float custom_v_freq,
    float h_blank_fuzz,
    float shorten_odd_field_time)
{
    TimebaseConfig config;

    // Field number cycling (retain existing modulus behavior)
    config.field = float(frame_count % 12u);

    float line = floor(tex_coord.y * original_size.y);

    int standard;
    // Subcarrier frequency derivation
    if (sc_freq_mode < 0.5) {
        // Auto mode: choose based on refresh rate
        if (core_refresh_hz > 55.0) {
            config.sc_freq_hz = NTSC_FSC;
            standard = 0;
        } else {
            config.sc_freq_hz = PAL_FSC;
            standard = 1;
        }
    } else if (sc_freq_mode < 1.5) {
        config.sc_freq_hz = NTSC_FSC;
        standard = 0;
    } else if (sc_freq_mode < 2.5) {
        config.sc_freq_hz = PAL_FSC;
        standard = 1;
    } else if (sc_freq_mode < 3.5) {
        config.sc_freq_hz = PAL_M_FSC;
        standard = 2;
    } else {
        config.sc_freq_hz = sc_freq_custom_mhz * 1.0e6;
        standard = 3;
    }

    // Pixel clock derivation
    float pixel_clock_hz;
    if (pixel_clock_mode < 0.5) {
        // Fixed
        pixel_clock_hz = pixel_clock_mhz * 1.0e6;
    } else {
        // Multiple of subcarrier
        float multiplier = pixel_clock_mhz;
        pixel_clock_hz = config.sc_freq_hz * multiplier;
    }

    // Horizontal frequency derivation
    if (h_freq_mode < 0.5) {
        // Standard
        if (standard == 0) {
            config.h_freq_hz = NTSC_H_FREQ;
        } else if (standard == 1) {
            config.h_freq_hz = PAL_H_FREQ;
        } else if (standard == 2) {
            config.h_freq_hz = PAL_M_H_FREQ;
        } else {
            // Guess from core refresh rate
            if (core_refresh_hz > 55.0)
                config.h_freq_hz = NTSC_H_FREQ;
            else
                config.h_freq_hz = PAL_H_FREQ;
        }
    } else if (h_freq_mode < 1.5) {
        // From pixel clock
        float divisor = h_freq_custom_khz;
        config.h_freq_hz = pixel_clock_hz / divisor;
    } else {
        // Custom
        config.h_freq_hz = h_freq_custom_khz * 1.0e3;
    }

    // Derive number of lines per field
    if (v_freq_mode < 2.5 || v_freq_mode > 3.5) {
        config.v_lines_per_field = round(2.0 * config.h_freq_hz / core_refresh_hz) / 2.0;
    } else {
        // Divisor is the same as number of lines per field
        config.v_lines_per_field = custom_v_freq;
    }

    // Detect interlacing early: original height significantly larger than lines per field
    // Interlaced: original_size.y ≈ 2 × v_lines_per_field (e.g., 480 vs 262.5)
    // Progressive: original_size.y ≈ v_lines_per_field
    float interlace_ratio = original_size.y / config.v_lines_per_field;
    bool is_interlaced = (interlace_ratio > 1.5);
    config.is_interlaced = is_interlaced ? 1.0 : 0.0;

    // Detect NTSC vs PAL based on vertical frequency
    // NTSC: ~59.94-60 Hz, PAL: ~50 Hz
    bool is_ntsc = (core_refresh_hz > 55.0 && config.v_lines_per_field < 350.0);
    bool is_pal = (!is_ntsc && config.v_lines_per_field < 350.0);

    // Calculate lines per frame
    if (is_ntsc) {
        config.v_lines_per_frame = 526.0;
    } else if (is_pal) {
        config.v_lines_per_frame = 626.0;
    } else {
        config.v_lines_per_frame = config.v_lines_per_field * 2.0 + 2.0;
    }

    // For interlaced content, add one extra line to even fields (field 0, 2, 4, ...)
    // This simulates the extra scanline in the second field of interlaced video
    if (is_interlaced) {
        float field_parity = mod(config.field, 2.0);
        if (field_parity < 0.5) {
            // Even field: add one line
            config.v_lines_per_field += 1.0;
        }
    }

    // Vertical field frequency derivation
    float v_freq;
    if (v_freq_mode < 0.5) {
        v_freq = config.h_freq_hz / config.v_lines_per_field;
    } else if (v_freq_mode < 1.5) {
        v_freq = NTSC_V_FREQ;
    } else if (v_freq_mode < 2.5) {
        v_freq = PAL_V_FREQ;
    } else if (v_freq_mode < 3.5) {
        float divisor = custom_v_freq;
        v_freq = config.h_freq_hz / divisor;
    } else {
        v_freq = custom_v_freq;
    }

    // Calculate pixel time and total horizontal pixels
    float total_cycles = pixel_clock_hz / config.h_freq_hz;
    h_blank_fuzz /= 100.0;  // Convert percentage to fraction
    float clock_factor = round(total_cycles * h_blank_fuzz / original_size.x);
    float total_pixels = total_cycles / clock_factor;

    config.pixel_time = 1.0 / (config.h_freq_hz * total_pixels);

    // Field phase with intelligent odd-field timing adjustment
    float field_time = 1.0 / v_freq;
    config.field_phase = field_time * config.field * 2.0 * PI * config.sc_freq_hz;
    
    // Apply odd-field timing adjustment based on standard and scan type
    float odd_field_adjust = 0.0;
    if (shorten_odd_field_time > 0.5) {
        float odd_time_adjust = original_size.x / 256.0 * config.pixel_time;
        
        if (is_ntsc) {
            // NTSC: Apply shortening only for progressive scan
            if (!is_interlaced) {
                odd_field_adjust = -odd_time_adjust;
            }
            // Interlaced NTSC: bypass (no adjustment)
        } else {
            // PAL: Different behavior based on scan type
            if (is_interlaced) {
                // Interlaced PAL: lengthen odd field (positive adjustment)
                odd_field_adjust = odd_time_adjust;
            }
            // Progressive PAL: bypass (no adjustment)
        }
    }
    
    config.field_phase += ceil(config.field / 2.0) * odd_field_adjust * 2.0 * PI * config.sc_freq_hz;
    config.field_phase = mod(config.field_phase, 2.0 * PI) - PI;

    // Scale factors for output size
    float h_scale = max(floor(output_size.x / total_pixels), 1.0);
    float v_scale = max(floor(output_size.y / config.v_lines_per_field), 1.0);

    // Per-output-pixel time (cycles-per-pixel scaling)
    config.pixel_time_px = config.pixel_time / h_scale;

    // Total horizontal pixels (active + blanking)
    config.h_pixels = total_pixels;

    config.pixels_per_line = v_scale;

    return config;
}

// Estimate Blackman-Harris 4-term lowpass filter response at given frequency
// Used for VSB sideband gain estimation in chroma demodulation
// Returns approximate magnitude response (0.0 = stopband, 1.0 = passband)
float blackman_harris_lpf_response(float freq_mhz, float cutoff_mhz)
{
    // Normalized frequency relative to cutoff
    float f_norm = freq_mhz / cutoff_mhz;
    
    if (f_norm <= 0.9) {
        // Passband: flat response within 90% of cutoff
        return 1.0;
    } else if (f_norm >= 1.2) {
        // Stopband: ~92 dB rejection ≈ 0 beyond 120% of cutoff
        return 0.0;
    } else {
        // Transition band: smooth cosine taper (approximates BH4 rolloff)
        // Maps [0.9, 1.2] → [0, π] for smooth transition
        float t = (f_norm - 0.9) / 0.3;
        return 0.5 * (1.0 + cos(PI * t));
    }
}

// Compute VSB chroma gain factors for arbitrary subcarrier and IQ cutoff
// Returns vec2(i_gain, q_gain) accounting for sideband attenuation
// Inputs:
//   sc_freq_hz      - Subcarrier frequency in Hz
//   iq_cutoff_mhz   - IQ lowpass cutoff frequency in MHz
//   i_bw_mhz        - I channel bandwidth (single-sided) in MHz
//   q_bw_mhz        - Q channel bandwidth (single-sided) in MHz
vec2 compute_vsb_chroma_gain(float sc_freq_hz, float iq_cutoff_mhz, 
                             float i_bw_mhz, float q_bw_mhz)
{
    float f_sc_mhz = sc_freq_hz * 1.0e-6;
    
    // I channel sideband edges
    float i_lower = f_sc_mhz - i_bw_mhz;
    float i_upper = f_sc_mhz + i_bw_mhz;
    float i_lower_gain = blackman_harris_lpf_response(i_lower, iq_cutoff_mhz);
    float i_upper_gain = blackman_harris_lpf_response(i_upper, iq_cutoff_mhz);
    
    // Q channel sideband edges
    float q_lower = f_sc_mhz - q_bw_mhz;
    float q_upper = f_sc_mhz + q_bw_mhz;
    float q_lower_gain = blackman_harris_lpf_response(q_lower, iq_cutoff_mhz);
    float q_upper_gain = blackman_harris_lpf_response(q_upper, iq_cutoff_mhz);
    
    // Average both sidebands (DSB→VSB conversion factor)
    vec2 gains;
    gains.x = 0.5 * (i_lower_gain + i_upper_gain);  // I channel
    gains.y = 0.5 * (q_lower_gain + q_upper_gain);  // Q channel
    
    return max(gains, vec2(0.1));  // Prevent divide-by-zero
}

// Compute Gaussian low-pass sigma (in texels) from timebase and cutoff spec.
// Inputs:
//   tb                 - TimebaseConfig with pixel_time_px set
//   cutoff_freq_mhz    - Desired cutoff frequency in MHz (analog domain)
//   cutoff_atten_db    - Target attenuation at cutoff in dB (e.g., 3 dB)
// Derivation:
//   Time-domain Gaussian kernel: w(x) = exp(-x²/(2σ²))
//   Frequency response magnitude:  |H(f)| = exp(-2π²σ²f²)
//   Design constraint: |H(f_c)| = a = 10^(-A/20), where A = cutoff_atten_db
//   Solving for σ:
//     a = exp(-2π²σ²f_c²)
//     ln a = -2π²σ²f_c²
//     σ² = -ln a / (2π²f_c²)
//     σ = sqrt(-ln a) / (√2 π f_c) = sqrt(-2 ln a) / (2π f_c)
//   Equivalent forms:
//     Original:   σ = sqrt(-2 ln(10^(-A/20))) / (2π f_c)
//     Simplified: σ = sqrt((A/10) ln 10) / (2π f_c)
//   where f_c is in cycles per pixel: f_c = cutoff_freq_hz * pixel_time_px
float sigma_tb(TimebaseConfig tb, float cutoff_freq_mhz, float cutoff_atten_db)
{
    // Convert cutoff to cycles-per-pixel
    float f_c_px = cutoff_freq_mhz * 1.0e6 * tb.pixel_time_px;

    // Guard: require positive frequency scale and attenuation
    if (f_c_px <= 0.0 || cutoff_atten_db <= 0.0)
        return 0.0;

    // Simplified stable form avoids pow/log on tiny values
    const float LN10 = 2.3025850929940459; // ln(10) high-precision constant
    float factor = (cutoff_atten_db * LN10) * 0.1; // (A/10)·ln(10) = -2·ln(a)

    // σ in texels
    float sigma = sqrt(factor) / (2.0 * PI * f_c_px);
    return sigma;
}