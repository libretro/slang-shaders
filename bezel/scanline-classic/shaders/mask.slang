#version 450

// Filename: mask.slang
//
// Copyright (C) 2026 W. M. Martinez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// CRT mask simulation
// ------------------------------------------------
// Input: Linear YrYgYb signal
// Output: Linear YrYgYb signal

#include "common.inc"
#include "color.inc"
#include "tools/zebra.inc"

#include "menus/parameters/mask.inc"
#include "menus/parameters/colorimetry.inc"
#include "menus/parameters/factory-geometry.inc"

#pragma name CRTMask
#pragma format R16G16B16A16_SFLOAT

#pragma parameter MASK_BYPASS "Bypass CRT mask" 0.0 0.0 1.0 1.0
#pragma parameter MASK_DEBUG_OUT_OF_RANGE "Beam-mask: Show out-of-range colors" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OutputSize;     // xy = output size in pixels
    uint FrameCount;
    float ASPECT;
    float MASK_BYPASS;
    float MASK_TYPE;
    float MASK_INTENSITY;
    float TVL;
    float MASK_DIFFUSION;
    float MASK_DEBUG_OUT_OF_RANGE;
} config;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

#define ASPECT config.ASPECT
#define MASK_BYPASS config.MASK_BYPASS
#define MASK_TYPE config.MASK_TYPE
#define MASK_INTENSITY config.MASK_INTENSITY
#define TVL config.TVL
#define MASK_DIFFUSION config.MASK_DIFFUSION
#define MASK_DEBUG_OUT_OF_RANGE config.MASK_DEBUG_OUT_OF_RANGE

// Cyclic distance on a ring of length `period`
// Returns shortest wrapped distance between x and center.
float cyclicDist(float x, float center, float period)
{
    float d = abs(x - center);
    return min(d, period - d);
}

// ---- Mask computation with numerical integration for anti-aliasing ----
// Numerically integrate Gaussian stripe contributions across pixel extent
// Uses multiple sample points to average the Gaussian values within the pixel
vec3 integrate_aperture_grille_numerical(float x_min, float x_max, float sigma_x, int samples)
{
    vec3 sum = vec3(0.0);
    float step = (x_max - x_min) / float(samples);

    for (int i = 0; i < samples; ++i) {
        float x = x_min + (float(i) + 0.5) * step;

        // Evaluate Gaussian at each RGB stripe center (0, 2, 4 in 6-unit cycle)
        float dr = cyclicDist(mod(x - 0.5, 6.0), 0.0, 6.0);
        float dg = cyclicDist(mod(x - 0.5, 6.0), 2.0, 6.0);
        float db = cyclicDist(mod(x - 0.5, 6.0), 4.0, 6.0);

        sum.r += exp(-0.5 * dr*dr / (sigma_x*sigma_x));
        sum.g += exp(-0.5 * dg*dg / (sigma_x*sigma_x));
        sum.b += exp(-0.5 * db*db / (sigma_x*sigma_x));
    }

    return sum / float(samples);
}

// 2D numerical integration for slot mask (18-unit horizontal, 3-unit vertical cycle)
vec3 integrate_slot_mask_numerical(
    float x_min, float x_max, float y_min, float y_max,
    float sigma_x, float sigma_v,
    int samples_x, int samples_y)
{
    // Vertical weights at sample points (slot mask has 3-unit vertical cycle)
    vec3 v_weights = vec3(0.0);
    float step_y = (y_max - y_min) / float(samples_y);

    for (int j = 0; j < samples_y; ++j) {
        float y = y_min + (float(j) + 0.5) * step_y;
        float vc = mod(y - 0.5, 3.0);

        float w0 = exp(-0.5 * pow(cyclicDist(vc, 0.0, 3.0), 2.0) / (sigma_v * sigma_v));
        float w1 = exp(-0.5 * pow(cyclicDist(vc, 1.0, 3.0), 2.0) / (sigma_v * sigma_v));
        float w2 = exp(-0.5 * pow(cyclicDist(vc, 2.0, 3.0), 2.0) / (sigma_v * sigma_v));

        v_weights += vec3(w0, w1, w2);
    }
    v_weights /= float(samples_y);

    // Horizontal integration for each vertical row pattern (18-unit cycle)
    float step_x = (x_max - x_min) / float(samples_x);
    vec3 row0 = vec3(0.0), row1 = vec3(0.0), row2 = vec3(0.0);

    for (int i = 0; i < samples_x; ++i) {
        float x = x_min + (float(i) + 0.5) * step_x;
        float cycle = mod(x - 0.5, 18.0);

        // Row 0: RGB at 6, 8, 10 and 12, 14, 16
        vec2 dR0 = vec2(cyclicDist(cycle, 6.0, 18.0), cyclicDist(cycle, 12.0, 18.0));
        vec2 dG0 = vec2(cyclicDist(cycle, 8.0, 18.0), cyclicDist(cycle, 14.0, 18.0));
        vec2 dB0 = vec2(cyclicDist(cycle, 10.0, 18.0), cyclicDist(cycle, 16.0, 18.0));

        row0 += vec3(
            exp(-0.5 * dR0.x * dR0.x / (sigma_x * sigma_x)) + exp(-0.5 * dR0.y * dR0.y / (sigma_x * sigma_x)),
            exp(-0.5 * dG0.x * dG0.x / (sigma_x * sigma_x)) + exp(-0.5 * dG0.y * dG0.y / (sigma_x * sigma_x)),
            exp(-0.5 * dB0.x * dB0.x / (sigma_x * sigma_x)) + exp(-0.5 * dB0.y * dB0.y / (sigma_x * sigma_x))
        );

        // Row 1: RGB at 0, 2, 4 and 12, 14, 16
        vec2 dR1 = vec2(cyclicDist(cycle, 0.0, 18.0), cyclicDist(cycle, 12.0, 18.0));
        vec2 dG1 = vec2(cyclicDist(cycle, 2.0, 18.0), cyclicDist(cycle, 14.0, 18.0));
        vec2 dB1 = vec2(cyclicDist(cycle, 4.0, 18.0), cyclicDist(cycle, 16.0, 18.0));

        row1 += vec3(
            exp(-0.5 * dR1.x * dR1.x / (sigma_x * sigma_x)) + exp(-0.5 * dR1.y * dR1.y / (sigma_x * sigma_x)),
            exp(-0.5 * dG1.x * dG1.x / (sigma_x * sigma_x)) + exp(-0.5 * dG1.y * dG1.y / (sigma_x * sigma_x)),
            exp(-0.5 * dB1.x * dB1.x / (sigma_x * sigma_x)) + exp(-0.5 * dB1.y * dB1.y / (sigma_x * sigma_x))
        );

        // Row 2: RGB at 0, 2, 4 and 6, 8, 10
        vec2 dR2 = vec2(cyclicDist(cycle, 0.0, 18.0), cyclicDist(cycle, 6.0, 18.0));
        vec2 dG2 = vec2(cyclicDist(cycle, 2.0, 18.0), cyclicDist(cycle, 8.0, 18.0));
        vec2 dB2 = vec2(cyclicDist(cycle, 4.0, 18.0), cyclicDist(cycle, 10.0, 18.0));

        row2 += vec3(
            exp(-0.5 * dR2.x * dR2.x / (sigma_x * sigma_x)) + exp(-0.5 * dR2.y * dR2.y / (sigma_x * sigma_x)),
            exp(-0.5 * dG2.x * dG2.x / (sigma_x * sigma_x)) + exp(-0.5 * dG2.y * dG2.y / (sigma_x * sigma_x)),
            exp(-0.5 * dB2.x * dB2.x / (sigma_x * sigma_x)) + exp(-0.5 * dB2.y * dB2.y / (sigma_x * sigma_x))
        );
    }

    row0 /= float(samples_x);
    row1 /= float(samples_x);
    row2 /= float(samples_x);

    // Combine: weighted average of rows
    return v_weights.x * row0 + v_weights.y * row1 + v_weights.z * row2;
}

// 2D numerical integration for shadow mask (6-unit horizontal, 4-unit vertical cycle)
vec3 integrate_shadow_mask_numerical(
    float x_min, float x_max, float y_min, float y_max,
    float sigma_x, float sigma_y,
    int samples_x, int samples_y)
{
    // Shadow mask: 6-unit horizontal, 4-unit vertical cycle
    // Two rows: row 0 at y=0 (RGB at x=0,2,4), row 2 at y=2 (BRG at x=1,3,5)

    // Vertical weights
    vec2 v_weights = vec2(0.0);
    float step_y = (y_max - y_min) / float(samples_y);

    for (int j = 0; j < samples_y; ++j) {
        float y = y_min + (float(j) + 0.5) * step_y;
        float vc = mod(y - 1.0, 4.0);

        float w0 = exp(-0.5 * pow(cyclicDist(vc, 0.0, 4.0), 2.0) / (sigma_y * sigma_y));
        float w2 = exp(-0.5 * pow(cyclicDist(vc, 2.0, 4.0), 2.0) / (sigma_y * sigma_y));

        v_weights += vec2(w0, w2);
    }
    v_weights /= float(samples_y);

    // Horizontal integration
    float step_x = (x_max - x_min) / float(samples_x);
    vec3 row0 = vec3(0.0), row2 = vec3(0.0);

    for (int i = 0; i < samples_x; ++i) {
        float x = x_min + (float(i) + 0.5) * step_x;
        float cycle = mod(x - 0.5, 6.0);

        // Row 0: R=0, G=2, B=4
        float dR0 = cyclicDist(cycle, 0.0, 6.0);
        float dG0 = cyclicDist(cycle, 2.0, 6.0);
        float dB0 = cyclicDist(cycle, 4.0, 6.0);

        row0 += vec3(
            exp(-0.5 * dR0*dR0 / (sigma_x*sigma_x)),
            exp(-0.5 * dG0*dG0 / (sigma_x*sigma_x)),
            exp(-0.5 * dB0*dB0 / (sigma_x*sigma_x))
        );

        // Row 2: B=1, R=3, G=5
        float dB2 = cyclicDist(cycle, 1.0, 6.0);
        float dR2 = cyclicDist(cycle, 3.0, 6.0);
        float dG2 = cyclicDist(cycle, 5.0, 6.0);

        row2 += vec3(
            exp(-0.5 * dR2*dR2 / (sigma_x*sigma_x)),
            exp(-0.5 * dG2*dG2 / (sigma_x*sigma_x)),
            exp(-0.5 * dB2*dB2 / (sigma_x*sigma_x))
        );
    }

    row0 /= float(samples_x);
    row2 /= float(samples_x);

    return v_weights.x * row0 + v_weights.y * row2;
}

// Compute peak mask value for normalization
// Returns the maximum per-channel value the mask can produce at given diffusion
float compute_peak_mask_value(vec2 sigma, float mask_type)
{
    if (mask_type < 0.5) {
        // Aperture grille: peak at phosphor center with contributions from adjacent phosphors
        // At red phosphor (cycle=0): R(0) + G(±2) + B(±2)
        // Due to 6-unit period, distances are: 0, 2, 2 (wrapped)
        float sigma_sq = sigma.x * sigma.x;
        float peak = 1.0 + 2.0 * exp(-0.5 * 4.0 / sigma_sq);  // 1 + 2*exp(-2/σ²)
        return peak;
    } else if (mask_type < 1.5) {
        // Slot mask: peak at phosphor position in active row
        // Horizontal: 2 same-color phosphors per row (e.g., R at 6 and 12 in row 0)
        float sigma_sq = sigma.x * sigma.x;
        float h_peak = 1.0 + exp(-0.5 * 36.0 / sigma_sq);  // Distance between pairs: 6 units
        
        // Vertical: peak at row center
        float sigma_v = sigma.y * 0.5;
        float v_peak = 1.0;
        
        // Account for brightness ratio normalization
        float brightness_ratio = sqrt(1.0 + (sigma.y * sigma.y));
        return (h_peak * v_peak) / brightness_ratio;
    } else {
        // Shadow mask: peak at phosphor center
        // Horizontal: single phosphor per color per row (6-unit cycle)
        float h_peak = 1.0;
        
        // Vertical: peak at row center (4-unit cycle, 2 active rows)
        float v_peak = 1.0;
        
        // Account for brightness ratio normalization
        float brightness_ratio = sqrt(1.0 + (sigma.y * sigma.y));
        return (h_peak * v_peak) / brightness_ratio;
    }
}

// Compute mask with analytical anti-aliasing when pixels_per_unit < threshold
vec3 compute_mask(vec2 screen_uv, float units_x_total, float units_y_total, vec2 pixels_per_unit)
{
    vec2 sigma = vec2(MASK_DIFFUSION);

    // Scale sigma for Shadow Mask
    if (MASK_TYPE >= 1.5) {
        sigma *= 0.625;
    }

    // Continuous unit coordinates for smooth Gaussian weighting
    float x_units = screen_uv.x * units_x_total;
    float y_units = screen_uv.y * units_y_total;

    // Three-case resolution handling:
    // Case 1: pixels_per_unit >= 1.0 -> Point sampling (sufficient resolution)
    // Case 2: Nyquist <= pixels_per_unit < 1.0 -> Numerical integration (anti-aliasing)
    // Case 3: pixels_per_unit < Nyquist -> Passthrough (pattern unresolvable)
    // Nyquist criterion: need at least 2 samples per period
    const float INTEGRATION_THRESHOLD = 1.0;
    
    // Compute Nyquist thresholds based on mask type and period
    float passthrough_threshold_x, passthrough_threshold_y;
    
    if (MASK_TYPE < 0.5) {
        // Aperture grille: 6-unit horizontal period, no vertical pattern
        passthrough_threshold_x = 2.0 / 6.0;   // 1/3
        passthrough_threshold_y = 0.0;         // No vertical component
    } else if (MASK_TYPE < 1.5) {
        // Slot mask: 18-unit horizontal, 3-unit vertical periods
        passthrough_threshold_x = 2.0 / 18.0;  // 1/9
        passthrough_threshold_y = 2.0 / 3.0;   // 2/3
    } else {
        // Shadow mask: 6-unit horizontal, 4-unit vertical periods
        passthrough_threshold_x = 2.0 / 6.0;   // 1/3
        passthrough_threshold_y = 2.0 / 4.0;   // 1/2
    }

    bool use_integration_x = (pixels_per_unit.x >= passthrough_threshold_x &&
                              pixels_per_unit.x < INTEGRATION_THRESHOLD);
    bool use_integration_y = (pixels_per_unit.y >= passthrough_threshold_y &&
                              pixels_per_unit.y < INTEGRATION_THRESHOLD);
    bool passthrough_x = pixels_per_unit.x < passthrough_threshold_x;
    bool passthrough_y = pixels_per_unit.y < passthrough_threshold_y;

    // Pixel extent in unit space
    float pixel_width_units = 1.0 / max(pixels_per_unit.x, EPS);
    float pixel_height_units = 1.0 / max(pixels_per_unit.y, EPS);

    // Pixel bounds in unit space (centered on current position)
    float x_min = x_units - pixel_width_units * 0.5;
    float x_max = x_units + pixel_width_units * 0.5;
    float y_min = y_units - pixel_height_units * 0.5;
    float y_max = y_units + pixel_height_units * 0.5;

    vec3 mask_color;

    if (MASK_TYPE < 0.5) {
        // Aperture grille (6-unit horizontal cycle, R G B at 0, 2, 4)

        if (passthrough_x) {
            // Case 3: Resolution too low, disable mask
            mask_color = vec3(1.0);
        } else if (use_integration_x) {
            // Case 2: Numerical integration with adaptive sample count
            // Use more samples when pixel spans more units
            int samples = int(clamp(pixel_width_units * 6.0, 6.0, 24.0));
            mask_color = integrate_aperture_grille_numerical(x_min, x_max, sigma.x, samples);
        } else {
            // Case 1: Point sampling (original method)
            float cycle = mod(x_units - 0.5, 6.0);
            float dr = cyclicDist(cycle, 0.0, 6.0);
            float dg = cyclicDist(cycle, 2.0, 6.0);
            float db = cyclicDist(cycle, 4.0, 6.0);

            float gauss_rx = exp(-0.5 * dr*dr / (sigma.x*sigma.x));
            float gauss_gx = exp(-0.5 * dg*dg / (sigma.x*sigma.x));
            float gauss_bx = exp(-0.5 * db*db / (sigma.x*sigma.x));

            mask_color = vec3(gauss_rx, gauss_gx, gauss_bx);
        }
    } else if (MASK_TYPE < 1.5) {
        // Slot mask: 18-unit horizontal, 3-unit vertical cycle
        // For now, only point sampling supported (integration TODO)
        if (passthrough_x && passthrough_y) {
            mask_color = vec3(1.0);
        } else if (use_integration_x || use_integration_y) {
            // 2D numerical integration with adaptive sample counts
            int samples_x = int(clamp(pixel_width_units * 6.0, 6.0, 24.0));
            int samples_y = int(clamp(pixel_height_units * 4.0, 4.0, 16.0));
            float sigma_v = sigma.y * 0.5;
            mask_color = integrate_slot_mask_numerical(x_min, x_max, y_min, y_max, sigma.x, sigma_v, samples_x, samples_y);
            float brightness_ratio = sqrt(1.0 + (sigma.y * sigma.y));
            mask_color /= brightness_ratio;
        } else {
            // Original point sampling code
            float cycle = mod(x_units - 0.5, 18.0);
            float vcycle = mod(y_units - 0.5, 3.0);
            float sigma_v = sigma.y * 0.5;
            float w0 = exp(-0.5 * pow(cyclicDist(vcycle, 0.0, 3.0), 2.0) / (sigma_v * sigma_v));
            float w1 = exp(-0.5 * pow(cyclicDist(vcycle, 1.0, 3.0), 2.0) / (sigma_v * sigma_v));
            float w2 = exp(-0.5 * pow(cyclicDist(vcycle, 2.0, 3.0), 2.0) / (sigma_v * sigma_v));

            vec2 dR0 = vec2(cyclicDist(cycle, 6.0, 18.0), cyclicDist(cycle, 12.0, 18.0));
            vec2 dG0 = vec2(cyclicDist(cycle, 8.0, 18.0), cyclicDist(cycle, 14.0, 18.0));
            vec2 dB0 = vec2(cyclicDist(cycle, 10.0, 18.0), cyclicDist(cycle, 16.0, 18.0));
            vec3 rgb0 = vec3(
                exp(-0.5 * dR0.x * dR0.x / (sigma.x * sigma.x)) + exp(-0.5 * dR0.y * dR0.y / (sigma.x * sigma.x)),
                exp(-0.5 * dG0.x * dG0.x / (sigma.x * sigma.x)) + exp(-0.5 * dG0.y * dG0.y / (sigma.x * sigma.x)),
                exp(-0.5 * dB0.x * dB0.x / (sigma.x * sigma.x)) + exp(-0.5 * dB0.y * dB0.y / (sigma.x * sigma.x)));

            vec2 dR1 = vec2(cyclicDist(cycle, 0.0, 18.0), cyclicDist(cycle, 12.0, 18.0));
            vec2 dG1 = vec2(cyclicDist(cycle, 2.0, 18.0), cyclicDist(cycle, 14.0, 18.0));
            vec2 dB1 = vec2(cyclicDist(cycle, 4.0, 18.0), cyclicDist(cycle, 16.0, 18.0));
            vec3 rgb1 = vec3(
                exp(-0.5 * dR1.x * dR1.x / (sigma.x * sigma.x)) + exp(-0.5 * dR1.y * dR1.y / (sigma.x * sigma.x)),
                exp(-0.5 * dG1.x * dG1.x / (sigma.x * sigma.x)) + exp(-0.5 * dG1.y * dG1.y / (sigma.x * sigma.x)),
                exp(-0.5 * dB1.x * dB1.x / (sigma.x * sigma.x)) + exp(-0.5 * dB1.y * dB1.y / (sigma.x * sigma.x)));

            vec2 dR2 = vec2(cyclicDist(cycle, 0.0, 18.0), cyclicDist(cycle, 6.0, 18.0));
            vec2 dG2 = vec2(cyclicDist(cycle, 2.0, 18.0), cyclicDist(cycle, 8.0, 18.0));
            vec2 dB2 = vec2(cyclicDist(cycle, 4.0, 18.0), cyclicDist(cycle, 10.0, 18.0));
            vec3 rgb2 = vec3(
                exp(-0.5 * dR2.x * dR2.x / (sigma.x * sigma.x)) + exp(-0.5 * dR2.y * dR2.y / (sigma.x * sigma.x)),
                exp(-0.5 * dG2.x * dG2.x / (sigma.x * sigma.x)) + exp(-0.5 * dG2.y * dG2.y / (sigma.x * sigma.x)),
                exp(-0.5 * dB2.x * dB2.x / (sigma.x * sigma.x)) + exp(-0.5 * dB2.y * dB2.y / (sigma.x * sigma.x)));

            mask_color = w0 * rgb0 + w1 * rgb1 + w2 * rgb2;
            float brightness_ratio = sqrt(1.0 + (sigma.y * sigma.y));
            mask_color /= brightness_ratio;
        }
    } else {
        // Shadow mask: 6-unit horizontal, 4-unit vertical cycle
        if (passthrough_x && passthrough_y) {
            mask_color = vec3(1.0);
        } else if (use_integration_x || use_integration_y) {
            // 2D numerical integration with adaptive sample counts
            int samples_x = int(clamp(pixel_width_units * 6.0, 6.0, 24.0));
            int samples_y = int(clamp(pixel_height_units * 4.0, 4.0, 16.0));
            mask_color = integrate_shadow_mask_numerical(x_min, x_max, y_min, y_max, sigma.x, sigma.y, samples_x, samples_y);
            float brightness_ratio = sqrt(1.0 + (sigma.y * sigma.y));
            mask_color /= brightness_ratio;
        } else {
            // Point sampling
            float cycle = mod(x_units - 0.5, 6.0);
            float vcycle = mod(y_units - 1.0, 4.0);
            float sigma_v = sigma.y;
            float w0 = exp(-0.5 * pow(cyclicDist(vcycle, 0.0, 4.0), 2.0) / (sigma_v * sigma_v));
            float w2 = exp(-0.5 * pow(cyclicDist(vcycle, 2.0, 4.0), 2.0) / (sigma_v * sigma_v));

            float dR0 = cyclicDist(cycle, 0.0, 6.0);
            float dG0 = cyclicDist(cycle, 2.0, 6.0);
            float dB0 = cyclicDist(cycle, 4.0, 6.0);
            vec3 rgb0 = vec3(
                exp(-0.5 * dR0*dR0 / (sigma.x*sigma.x)),
                exp(-0.5 * dG0*dG0 / (sigma.x*sigma.x)),
                exp(-0.5 * dB0*dB0 / (sigma.x*sigma.x))
            );

            float dB2 = cyclicDist(cycle, 1.0, 6.0);
            float dR2 = cyclicDist(cycle, 3.0, 6.0);
            float dG2 = cyclicDist(cycle, 5.0, 6.0);
            vec3 rgb2 = vec3(
                exp(-0.5 * dR2*dR2 / (sigma.x*sigma.x)),
                exp(-0.5 * dG2*dG2 / (sigma.x*sigma.x)),
                exp(-0.5 * dB2*dB2 / (sigma.x*sigma.x))
            );

            mask_color = w0 * rgb0 + w2 * rgb2;
            float brightness_ratio = sqrt(1.0 + (sigma.y * sigma.y));
            mask_color /= brightness_ratio;
        }
    }

    // Normalize by peak to ensure max(mask_color) <= 1.0
    // This prevents output from exceeding input range while preserving pattern
    float peak = compute_peak_mask_value(sigma, MASK_TYPE);
    mask_color /= peak;

    return mask_color;
}

// Compute peak gain as the maximum Yr+Yg+Yb value after masking.
// This searches the mask pattern for the brightest pixel and returns
// the gain relative to a unit grayscale input (sum = 3.0).
float compute_peak_mask_gain(float units_x_total, float units_y_total, vec2 pixels_per_unit, float mask_intensity)
{
    // Compute Nyquist thresholds based on mask type
    float passthrough_threshold_x, passthrough_threshold_y;
    bool passthrough;
    
    if (MASK_TYPE < 0.5) {
        // Aperture grille: only horizontal pattern
        passthrough_threshold_x = 2.0 / 6.0;   // 1/3
        passthrough = (pixels_per_unit.x < passthrough_threshold_x);
    } else if (MASK_TYPE < 1.5) {
        // Slot mask: both horizontal and vertical patterns (require AND logic)
        passthrough_threshold_x = 2.0 / 18.0;  // 1/9
        passthrough_threshold_y = 2.0 / 3.0;   // 2/3
        passthrough = (pixels_per_unit.x < passthrough_threshold_x) && 
                      (pixels_per_unit.y < passthrough_threshold_y);
    } else {
        // Shadow mask: both horizontal and vertical patterns (require AND logic)
        passthrough_threshold_x = 2.0 / 6.0;   // 1/3
        passthrough_threshold_y = 2.0 / 4.0;   // 1/2
        passthrough = (pixels_per_unit.x < passthrough_threshold_x) && 
                      (pixels_per_unit.y < passthrough_threshold_y);
    }
    
    if (passthrough) {
        return 1.0;  // No mask attenuation at very low resolution
    }

    float period_x = 6.0;
    float period_y = 1.0;

    if (MASK_TYPE >= 0.5 && MASK_TYPE < 1.5) {
        period_x = 18.0;
        period_y = 3.0;
    } else if (MASK_TYPE >= 1.5) {
        period_x = 6.0;
        period_y = 4.0;
    }

    int samples_x = int(clamp(floor(pixels_per_unit.x * period_x + 0.5), 2.0, 77.0));
    int samples_y = int(clamp(floor(pixels_per_unit.y * period_y + 0.5), 2.0, 58.0));
    float max_sum = 0.0;

    for (int j = 0; j < samples_y; ++j) {
        float y_units = (float(j) + 0.5) * (period_y / float(samples_y));
        float v = y_units / max(units_y_total, EPS);

        for (int i = 0; i < samples_x; ++i) {
            float x_units = (float(i) + 0.5) * (period_x / float(samples_x));
            float u = x_units / max(units_x_total, EPS);
            vec3 mask_color = compute_mask(vec2(u, v), units_x_total, units_y_total, pixels_per_unit);
            float sum = mask_color.r + mask_color.g + mask_color.b;
            max_sum = max(max_sum, sum);
        }
    }

    // Apply mask intensity to the sum and convert to gain vs unit grayscale input (sum = 3.0).
    float blended_sum = mix(3.0, max_sum, mask_intensity);
    return blended_sum / 3.0;
}

float pack_gain_pair(float avg_gain, float peak_gain)
{
    float avg8 = floor(clamp(avg_gain, 0.0, 1.0) * 255.0 + 0.5);
    float peak8 = floor(clamp(peak_gain, 0.0, 1.0) * 255.0 + 0.5);
    return (avg8 * 256.0 + peak8) / 65535.0;
}

float erf_approx(float x)
{
    float sign = x < 0.0 ? -1.0 : 1.0;
    x = abs(x);
    float t = 1.0 / (1.0 + 0.3275911 * x);
    float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t) * exp(-x * x);
    return sign * y;
}

float average_cyclic_gauss(float period, float sigma)
{
    float s = max(sigma, EPS);
    float half_period = 0.5 * period;
    float arg = half_period / (sqrt(2.0) * s);
    float integral = sqrt(0.5 * PI) * s * erf_approx(arg);
    return (2.0 / period) * integral;
}

vec3 average_mask_color(vec2 pixels_per_unit)
{
    vec2 sigma = vec2(MASK_DIFFUSION);
    if (MASK_TYPE >= 1.5) {
        sigma *= 0.625;
    }

    // Compute Nyquist thresholds based on mask type
    float passthrough_threshold_x, passthrough_threshold_y;
    bool passthrough;
    
    if (MASK_TYPE < 0.5) {
        // Aperture grille: only horizontal pattern
        passthrough_threshold_x = 2.0 / 6.0;   // 1/3
        passthrough = (pixels_per_unit.x < passthrough_threshold_x);
    } else if (MASK_TYPE < 1.5) {
        // Slot mask: both horizontal and vertical patterns (require AND logic)
        passthrough_threshold_x = 2.0 / 18.0;  // 1/9
        passthrough_threshold_y = 2.0 / 3.0;   // 2/3
        passthrough = (pixels_per_unit.x < passthrough_threshold_x) && 
                      (pixels_per_unit.y < passthrough_threshold_y);
    } else {
        // Shadow mask: both horizontal and vertical patterns (require AND logic)
        passthrough_threshold_x = 2.0 / 6.0;   // 1/3
        passthrough_threshold_y = 2.0 / 4.0;   // 1/2
        passthrough = (pixels_per_unit.x < passthrough_threshold_x) && 
                      (pixels_per_unit.y < passthrough_threshold_y);
    }

    const float INTEGRATION_THRESHOLD = 1.0;
    bool use_integration = (pixels_per_unit.x < INTEGRATION_THRESHOLD && pixels_per_unit.x >= passthrough_threshold_x) ||
                           (pixels_per_unit.y < INTEGRATION_THRESHOLD && pixels_per_unit.y >= passthrough_threshold_y);

    if (passthrough) {
        return vec3(1.0);  // Mask disabled at very low resolution
    }

    vec3 avg_mask_unnormalized;
    
    if (MASK_TYPE < 0.5) {
        float avg_x = average_cyclic_gauss(6.0, sigma.x);
        avg_mask_unnormalized = vec3(avg_x);  // Aperture has no vertical component
    } else {
        // Brightness ratio for normalization based on vertical diffusion
        float brightness_ratio = sqrt(1.0 + (sigma.y * sigma.y));

        if (MASK_TYPE < 1.5) {
            // Slot mask: horizontal 18-unit, vertical 3-unit
            float sigma_v = sigma.y * 0.5;
            float avg_w = average_cyclic_gauss(3.0, sigma_v);
            float avg_row = 2.0 * average_cyclic_gauss(18.0, sigma.x);
            float avg_mask = (avg_w * 3.0 * avg_row) / brightness_ratio;
            avg_mask_unnormalized = vec3(avg_mask);
        } else {
            // Shadow mask: horizontal 6-unit, vertical 4-unit
            float avg_w = average_cyclic_gauss(4.0, sigma.y);
            float avg_row = average_cyclic_gauss(6.0, sigma.x);
            float avg_mask = (avg_w * 2.0 * avg_row) / brightness_ratio;
            avg_mask_unnormalized = vec3(avg_mask);
        }
    }
    
    // Apply same peak normalization as compute_mask() for consistency
    float peak = compute_peak_mask_value(sigma, MASK_TYPE);
    return avg_mask_unnormalized / peak;
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float maskAR;
layout(location = 2) out float avg_mask_gain;
layout(location = 3) out float units_x_total;
layout(location = 4) out float units_y_total;
layout(location = 5) out float mask_intensity;
layout(location = 6) out vec2 pixels_per_unit;
layout(location = 7) out float peak_mask_gain;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Selected target aspect ratio for framing
    maskAR = (ASPECT < 0.5) ? (4.0 / 3.0)
        : (ASPECT < 1.5) ? (16.0 / 9.0)
        : (ASPECT < 2.5) ? (5.0 / 4.0)
        : (16.0 / 10.0);

    float tvl = max(TVL, 1.0);
    units_x_total = tvl * 6.0;
    if (MASK_TYPE < 0.5) {
        units_y_total = tvl;
    } else if (MASK_TYPE < 1.5) {
        units_y_total = tvl / maskAR * 2.5;
    } else {
        units_y_total = tvl / maskAR * 6.0;
    }

    mask_intensity = MASK_INTENSITY * 0.01;
    pixels_per_unit = config.OutputSize.xy / vec2(units_x_total, units_y_total);
    vec3 avg_mask = average_mask_color(pixels_per_unit);
    vec3 avg_mask_rgb = mix(vec3(1.0), avg_mask, mask_intensity);

    // Compute unitless average mask gain
    // YrYgYb signal: each channel is luminance contribution, so simple average
    const vec3 one_third = vec3(1.0 / 3.0);
    avg_mask_gain = dot(avg_mask_rgb, one_third);

    // Compute peak mask gain based on output sampling grid
    peak_mask_gain = compute_peak_mask_gain(units_x_total, units_y_total, pixels_per_unit, mask_intensity);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float maskAR;
layout(location = 2) in float avg_mask_gain;
layout(location = 3) in float units_x_total;
layout(location = 4) in float units_y_total;
layout(location = 5) in float mask_intensity;
layout(location = 6) in vec2 pixels_per_unit;
layout(location = 7) in float peak_mask_gain;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;

void main()
{
    vec4 color_gain = texture(Source, vTexCoord);
    vec3 color = color_gain.rgb;
    float incoming_gain = color_gain.a;

    // If mask is bypassed, pass through incoming gain unchanged (mask gain = 1.0)
    if (MASK_BYPASS >= 1.0) {
        float packed_gain = pack_gain_pair(incoming_gain, peak_mask_gain);
        FragColor = vec4(color, packed_gain);
        return;
    }

    // Use units and mask_intensity computed in vertex shader
    vec3 mask_color = compute_mask(vTexCoord, units_x_total, units_y_total, pixels_per_unit);
    vec3 masked_color = mix(color, color * mask_color, mask_intensity);

    if (MASK_DEBUG_OUT_OF_RANGE >= 1.0) {
        masked_color = zebra(masked_color, 0.0, 10000.0, vTexCoord, config.OutputSize.xy, config.FrameCount, 2.0);
    }

    // Combine incoming gain with average mask gain
    float combined_gain = incoming_gain * avg_mask_gain;
    float packed_gain = pack_gain_pair(combined_gain, peak_mask_gain);

    FragColor = vec4(masked_color, packed_gain);
}
