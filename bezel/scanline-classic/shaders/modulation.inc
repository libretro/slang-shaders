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

// Compute odd-field time adjustment for precise t00 incorporation
// This centralizes the odd-field logic so t00 can fully encapsulate all timing
float compute_odd_field_time_adjustment(
    float field, float shorten_odd_field_time,
    float pixel_time, float original_width,
    bool is_ntsc, bool is_interlaced)
{
    if (shorten_odd_field_time < 0.5)
        return 0.0;
    
    float odd_time_adjust = original_width / 256.0 * pixel_time;
    float adjustment = 0.0;
    
    if (is_ntsc) {
        // NTSC: Apply shortening only for progressive scan
        if (!is_interlaced) {
            adjustment = -odd_time_adjust;
        }
    } else {
        // PAL: Different behavior based on scan type
        if (is_interlaced) {
            // Interlaced PAL: lengthen odd field
            adjustment = odd_time_adjust;
        }
    }
    
    return ceil(field / 2.0) * adjustment;
}

// Discrete carrier phase: start from a precomputed base fractional cycle at t00
// (top-left pixel center within the field), then step by per-pixel and per-line
// cycle increments. Field progression and phase offset handled via field_phase parameter.
float compute_carrier_phase_discrete(
    float base_cycles,        // fract(sc_freq_hz * t00) where t00 is within-field time only
    float cycles_per_pixel,   // sc_freq_hz * pixel_time_px
    float cycles_per_line,    // sc_freq_hz / h_freq_hz
    float pixel_x,            // pixel index (use center: n + 0.5)
    float line,               // line index in output space
    float field_phase)        // field progression and timing adjustments as phase
{
    float fractional_cycles = fract(base_cycles + pixel_x * cycles_per_pixel + line * cycles_per_line);
    float phase = 2.0 * PI * fractional_cycles + field_phase;
    return normalize_phase(phase);
}

// ============================================================================
// Helper functions for modular compute_timebase
// ============================================================================

// Compute subcarrier frequency and identify video standard
// Returns standard: 0=NTSC, 1=PAL, 2=PAL-M, 3=custom
void compute_subcarrier_freq(
    float sc_freq_mode, float sc_freq_custom_mhz,
    float core_refresh_hz,
    out float sc_freq_hz, out int standard)
{
    if (sc_freq_mode < 0.5) {
        // Auto mode: choose based on refresh rate
        if (core_refresh_hz > 55.0) {
            sc_freq_hz = NTSC_FSC;
            standard = 0;
        } else {
            sc_freq_hz = PAL_FSC;
            standard = 1;
        }
    } else if (sc_freq_mode < 1.5) {
        sc_freq_hz = NTSC_FSC;
        standard = 0;
    } else if (sc_freq_mode < 2.5) {
        sc_freq_hz = PAL_FSC;
        standard = 1;
    } else if (sc_freq_mode < 3.5) {
        sc_freq_hz = PAL_M_FSC;
        standard = 2;
    } else {
        sc_freq_hz = sc_freq_custom_mhz * 1.0e6;
        standard = 3;
    }
}

// Compute pixel clock frequency from mode and parameters
float compute_pixel_clock(
    float pixel_clock_mode, float pixel_clock_mhz,
    float sc_freq_hz)
{
    if (pixel_clock_mode < 0.5) {
        return pixel_clock_mhz * 1.0e6;
    } else {
        return sc_freq_hz * pixel_clock_mhz;
    }
}

// Compute horizontal frequency from mode, standard, and parameters
void compute_h_freq(
    float h_freq_mode, int standard, float h_freq_custom_khz,
    float pixel_clock_hz, float core_refresh_hz,
    out float h_freq_hz)
{
    if (h_freq_mode < 0.5) {
        // Standard
        if (standard == 0) {
            h_freq_hz = NTSC_H_FREQ;
        } else if (standard == 1) {
            h_freq_hz = PAL_H_FREQ;
        } else if (standard == 2) {
            h_freq_hz = PAL_M_H_FREQ;
        } else {
            // Guess from core refresh rate
            if (core_refresh_hz > 55.0)
                h_freq_hz = NTSC_H_FREQ;
            else
                h_freq_hz = PAL_H_FREQ;
        }
    } else if (h_freq_mode < 1.5) {
        // From pixel clock
        h_freq_hz = pixel_clock_hz / h_freq_custom_khz;
    } else {
        // Custom
        h_freq_hz = h_freq_custom_khz * 1.0e3;
    }
}

// Compute vertical lines per field based on mode and parameters
float compute_v_lines_per_field(
    float v_freq_mode, float h_freq_hz,
    float core_refresh_hz, float custom_v_freq)
{
    if (v_freq_mode < 2.5 || v_freq_mode > 3.5) {
        return round(h_freq_hz / core_refresh_hz);
    } else {
        return custom_v_freq;
    }
}

// Detect interlacing and video standard type
void detect_scan_mode(
    float original_height, float v_lines_per_field,
    float core_refresh_hz,
    out bool is_interlaced, out bool is_ntsc, out bool is_pal)
{
    // Detect interlacing: original height significantly larger than lines per field
    float interlace_ratio = original_height / v_lines_per_field;
    is_interlaced = (interlace_ratio > 1.5);

    // Detect NTSC vs PAL based on vertical frequency
    is_ntsc = (core_refresh_hz > 55.0 && v_lines_per_field < 350.0);
    is_pal = (!is_ntsc && v_lines_per_field < 350.0);
}

// Compute vertical frequency from mode and parameters
float compute_v_freq(
    float v_freq_mode, float h_freq_hz, float v_lines_per_field,
    float custom_v_freq)
{
    if (v_freq_mode < 0.5) {
        return h_freq_hz / v_lines_per_field;
    } else if (v_freq_mode < 1.5) {
        return NTSC_V_FREQ;
    } else if (v_freq_mode < 2.5) {
        return PAL_V_FREQ;
    } else if (v_freq_mode < 3.5) {
        return h_freq_hz / custom_v_freq;
    } else {
        return custom_v_freq;
    }
}

// Compute horizontal pixel count and pixel timing
void compute_h_timing(
    float pixel_clock_hz, float h_freq_hz, float h_blank_fuzz,
    float original_width,
    out float total_pixels, out float pixel_time)
{
    float total_cycles = pixel_clock_hz / h_freq_hz;
    float fuzz_frac = h_blank_fuzz / 100.0;
    float clock_factor = round(total_cycles * fuzz_frac / original_width);
    total_pixels = total_cycles / clock_factor;
    pixel_time = 1.0 / (h_freq_hz * total_pixels);
}

// Compute output scaling factors for both horizontal and vertical dimensions
void compute_scale_factors(
    float frame_width,
    float output_width, float output_height,
    float total_pixels, float v_lines_per_field,
    out float h_scale)
{
    float h_scale1 = floor(frame_width / total_pixels);

    float h_scale2 = floor(output_width / (total_pixels * h_scale1));

    h_scale = max(h_scale1 * h_scale2, 1.0);
}

// Compute field phase with intelligent odd-field timing adjustment
float compute_field_phase(
    float field, float h_freq_hz, float v_lines_per_field,
    float v_freq, float sc_freq_hz, bool is_ntsc, 
    bool is_interlaced, float pixel_time, float original_width,
    float shorten_odd_field_time)
{
    float field_time = 1.0 / v_freq;
    float phase = field_time * field * 2.0 * PI * sc_freq_hz;

    // Apply odd-field timing adjustment based on standard and scan type
    float odd_field_adjust = 0.0;
    if (shorten_odd_field_time > 0.5) {
        float odd_time_adjust = original_width / 256.0 * pixel_time;

        if (is_ntsc) {
            // NTSC: Apply shortening only for progressive scan
            if (!is_interlaced) {
                odd_field_adjust = -odd_time_adjust;
            }
        } else {
            // PAL: Different behavior based on scan type
            if (is_interlaced) {
                // Interlaced PAL: lengthen odd field
                odd_field_adjust = odd_time_adjust;
            }
        }
    }

    phase += ceil(field / 2.0) * odd_field_adjust * 2.0 * PI * sc_freq_hz;
    return mod(phase, 2.0 * PI) - PI;
}

// ============================================================================
// Specialized timebase structs for different shader purposes
// ============================================================================

// Frame geometry only (for frame.slang, beam-mask.slang)
// Contains: h_pixels, v_lines_per_field, v_lines_per_frame, is_interlaced, field
struct FrameGeometry {
    float h_pixels;
    float v_lines_per_field;
    float v_lines_per_frame;
    float is_interlaced;
    float field;
};

// Carrier phase and modulation (for composite/S-Video modulators and demodulators)
// Contains: h_freq_hz, sc_freq_hz, pixel_time_px, field_phase, field
struct CarrierPhaseConfig {
    float h_freq_hz;
    float sc_freq_hz;
    float pixel_time_px;
    float field_phase;
    float field;
};

// Filter design (for bandlimit and IQ processing)
// Contains: pixel_time_px, pixel_time, field
struct FilterDesignConfig {
    float pixel_time_px;
    float pixel_time;
    float field;
};

// ============================================================================
// Extraction helpers for specialized timebase structs
// ============================================================================

// Extract carrier phase configuration from full timebase
CarrierPhaseConfig extract_carrier_phase(TimebaseConfig tb) {
    return CarrierPhaseConfig(
        tb.h_freq_hz,
        tb.sc_freq_hz,
        tb.pixel_time_px,
        tb.field_phase,
        tb.field);
}

// Extract filter design configuration from full timebase
FilterDesignConfig extract_filter_design(TimebaseConfig tb) {
    return FilterDesignConfig(
        tb.pixel_time_px,
        tb.pixel_time,
        tb.field);
}

// ============================================================================
// Lightweight frame geometry computation (for frame.slang, beam-mask.slang)
FrameGeometry compute_frame_geometry(
    uint frame_count,
    vec2 original_size,
    float core_refresh_hz,
    float sc_freq_mode,
    float sc_freq_custom_mhz,
    float pixel_clock_mhz,
    float pixel_clock_mode,
    float h_freq_mode,
    float h_freq_custom_khz,
    float v_freq_mode,
    float custom_v_freq,
    float h_blank_fuzz)
{
    FrameGeometry geom;
    geom.field = float(frame_count % 12u);

    // Frequency derivation
    int standard;
    float sc_freq_hz;
    compute_subcarrier_freq(sc_freq_mode, sc_freq_custom_mhz, core_refresh_hz,
                            sc_freq_hz, standard);

    float pixel_clock_hz = compute_pixel_clock(pixel_clock_mode, pixel_clock_mhz, sc_freq_hz);

    float h_freq_hz;
    compute_h_freq(h_freq_mode, standard, h_freq_custom_khz, pixel_clock_hz,
                   core_refresh_hz, h_freq_hz);

    // Vertical line derivation
    geom.v_lines_per_field = compute_v_lines_per_field(v_freq_mode, h_freq_hz,
                                                       core_refresh_hz, custom_v_freq);

    // Interlacing detection
    bool is_interlaced, is_ntsc, is_pal;
    detect_scan_mode(original_size.y, geom.v_lines_per_field, core_refresh_hz,
                     is_interlaced, is_ntsc, is_pal);
    geom.is_interlaced = is_interlaced ? 1.0 : 0.0;

    // Calculate frame dimensions
    geom.v_lines_per_frame = geom.v_lines_per_field * 2.0 + 2.0;
    
    if (is_interlaced) {
        geom.v_lines_per_field += 0.5;
    }

    // Calculate horizontal pixels
    float total_cycles = pixel_clock_hz / h_freq_hz;
    float fuzz_frac = h_blank_fuzz / 100.0;
    float clock_factor = round(total_cycles * fuzz_frac / original_size.x);
    geom.h_pixels = total_cycles / clock_factor;

    return geom;
}

// ============================================================================
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
    float frame_width,
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

    // === Frequency derivation ===
    int standard;
    compute_subcarrier_freq(
        sc_freq_mode, sc_freq_custom_mhz, core_refresh_hz,
        config.sc_freq_hz, standard);

    float pixel_clock_hz = compute_pixel_clock(
        pixel_clock_mode, pixel_clock_mhz,
        config.sc_freq_hz);

    compute_h_freq(
        h_freq_mode, standard, h_freq_custom_khz, pixel_clock_hz,
        core_refresh_hz, config.h_freq_hz);

    // === Vertical line and scan mode derivation ===
    config.v_lines_per_field = compute_v_lines_per_field(
        v_freq_mode, config.h_freq_hz,
        core_refresh_hz, custom_v_freq);

    bool is_interlaced, is_ntsc, is_pal;
    detect_scan_mode(
        original_size.y, config.v_lines_per_field, core_refresh_hz,
        is_interlaced, is_ntsc, is_pal);
    config.is_interlaced = is_interlaced ? 1.0 : 0.0;

    // Calculate lines per frame
    config.v_lines_per_frame = config.v_lines_per_field * 2.0 + 2.0;

    // For interlaced content, add one extra line to account for field differences
    if (is_interlaced) {
        config.v_lines_per_field += 0.5;
    }

    // === Timing derivation ===
    float v_freq = compute_v_freq(
        v_freq_mode, config.h_freq_hz,
        config.v_lines_per_field, custom_v_freq);

    float total_pixels;
    compute_h_timing(
        pixel_clock_hz, config.h_freq_hz, h_blank_fuzz,
        original_size.x, total_pixels, config.pixel_time);

    // === Field phase computation ===
    config.field_phase = compute_field_phase(
        config.field, config.h_freq_hz,
        config.v_lines_per_field, v_freq,
        config.sc_freq_hz, is_ntsc, is_interlaced,
        config.pixel_time, original_size.x,
        shorten_odd_field_time);

    // === Scale factor derivation ===
    float h_scale;
    compute_scale_factors(
        frame_width, output_size.x, output_size.y,
        total_pixels, config.v_lines_per_field, h_scale);

    // Per-output-pixel time (cycles-per-pixel scaling)
    config.pixel_time_px = config.pixel_time / h_scale;

    // Total horizontal pixels (active + blanking)
    config.h_pixels = total_pixels;

    return config;
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
//   where f_c is in normalized frequency: f_c = cutoff_freq_hz * pixel_time_px
float sigma_tb(TimebaseConfig tb, float cutoff_freq_mhz, float cutoff_atten_db)
{
    // Convert cutoff to normalized frequency
    float f_c = cutoff_freq_mhz * 1.0e6 * tb.pixel_time_px;

    // Guard: require positive frequency scale and attenuation
    if (f_c <= 0.0 || cutoff_atten_db <= 0.0)
        return 0.0;

    // Simplified stable form avoids pow/log on tiny values
    const float LN10 = 2.3025850929940459; // ln(10) high-precision constant
    float factor = (cutoff_atten_db * LN10) * 0.1; // (A/10)·ln(10) = -2·ln(a)

    // σ in texels
    float sigma = sqrt(factor) / (2.0 * PI * f_c);
    return sigma;
}