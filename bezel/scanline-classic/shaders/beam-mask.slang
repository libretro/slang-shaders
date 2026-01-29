#version 450

// Filename: beam-mask.slang
//
// Copyright (C) 2025 W. M. Martinez
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
// CRT beam simulation with mask
// ------------------------------------------------
// Input: Linear RGB signal
// Output: Linear RGB signal

#include "common.inc"
#include "filter.h"
#include "geometry.inc"
#include "modulation.inc"
#include "tools/zebra.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/mask.inc"
#include "menus/parameters/factory-geometry.inc"
#include "menus/parameters/service-geometry.inc"
#include "menus/parameters/user-uncommon.inc"

#pragma name CRTMask
#pragma format R16G16B16A16_SFLOAT

#pragma parameter GEOMETRY_BYPASS "Bypass beam geometry" 0.0 0.0 1.0 1.0
#pragma parameter FILTER_BYPASS "Bypass beam filter" 0.0 0.0 1.0 1.0
#pragma parameter MASK_BYPASS "Bypass CRT mask" 0.0 0.0 1.0 1.0
#pragma parameter MASK_FRAME_DEBUG "Mask frame debug (0=Off, 1=On)" 0.0 0.0 1.0 1.0
#pragma parameter BEAM_DEBUG_OUT_OF_RANGE "Beam-mask: Show out-of-range colors" 0.0 0.0 1.0 1.0

#pragma parameter DAR_SCALE "Display Aspect Ratio Scale" 1.0 0.1 5.0 0.01

layout(push_constant) uniform Push
{
    vec4 SourceSize;     // xy = input size in pixels
    vec4 OriginalSize;   // xy = input size in pixels
    vec4 OutputSize;     // xy = output size in pixels
    vec4 FrameSize;
    uint FrameCount;
    float OriginalFPS;
    float OriginalAspect;
    float MASK_BYPASS;
    float MASK_TYPE;
    float MASK_INTENSITY;
    float TVL;
    float BEAM_FOCUS;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float H_BLANK_FUZZ;
    float MASK_DIFFUSION;
} config;

#define MASK_BYPASS config.MASK_BYPASS
#define MASK_TYPE config.MASK_TYPE
#define MASK_INTENSITY config.MASK_INTENSITY
#define TVL config.TVL
#define BEAM_FOCUS config.BEAM_FOCUS
#define SC_FREQ_MODE config.SC_FREQ_MODE
#define SC_FREQ config.SC_FREQ
#define PIXEL_CLOCK_MODE config.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK config.PIXEL_CLOCK
#define H_FREQ_MODE config.H_FREQ_MODE
#define H_FREQ config.H_FREQ
#define H_BLANK_FUZZ config.H_BLANK_FUZZ
#define MASK_DIFFUSION config.MASK_DIFFUSION

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    float ASPECT;
    float MASK_FRAME_DEBUG;

    // ---- Geometry/user viewport controls ----
    float USER_H_SIZE;            // % (50 = 1.0)
    float USER_V_SIZE;            // % (50 = 1.0)

    float TRAPEZOIDAL_CORRECTION; // %
    float CORNER_CORRECTION;      // %
    float MAGNETIC_CORRECTION;    // % (0..100)
    float SHORTEN_ODD_FIELD_TIME;
    float USER_H_POS;            // % (50 = center)
    float USER_V_POS;            // % (50 = center)
    float USER_UNDERSCAN_TOGGLE; // toggle
    // Factory/service geometry controls needed here
    float DEFLECTION_ANGLE; // degrees
    float UNDERSCAN;        // %
    float S_CORRECTION_H;   // %
    float S_CORRECTION_V;   // %
    float GEOMETRY_BYPASS;
    float FILTER_BYPASS;
    float BEAM_DEBUG_OUT_OF_RANGE;

    float V_FREQ_MODE;
    float V_FREQ;

    float DAR_SCALE;
} global;

#define ASPECT global.ASPECT
#define MASK_FRAME_DEBUG global.MASK_FRAME_DEBUG

// Geometry macro bindings
#define USER_H_SIZE global.USER_H_SIZE
#define USER_V_SIZE global.USER_V_SIZE

#define GEOMETRY_BYPASS global.GEOMETRY_BYPASS
#define FILTER_BYPASS global.FILTER_BYPASS

#define TRAPEZOIDAL_CORRECTION global.TRAPEZOIDAL_CORRECTION
#define CORNER_CORRECTION global.CORNER_CORRECTION
#define MAGNETIC_CORRECTION global.MAGNETIC_CORRECTION
#define SHORTEN_ODD_FIELD_TIME global.SHORTEN_ODD_FIELD_TIME
#define USER_H_POS global.USER_H_POS
#define USER_V_POS global.USER_V_POS
#define USER_UNDERSCAN_TOGGLE global.USER_UNDERSCAN_TOGGLE

#define DEFLECTION_ANGLE global.DEFLECTION_ANGLE
#define UNDERSCAN global.UNDERSCAN
#define S_CORRECTION_H global.S_CORRECTION_H
#define S_CORRECTION_V global.S_CORRECTION_V

#define BEAM_DEBUG_OUT_OF_RANGE global.BEAM_DEBUG_OUT_OF_RANGE

#define V_FREQ_MODE global.V_FREQ_MODE
#define V_FREQ global.V_FREQ

#define DAR_SCALE global.DAR_SCALE

// Bicubic texture sampling (4x4 Mitchell-Netravali)
// Matches implementation style from crt-geometry.slang
vec3 sample_bicubic(sampler2D source, vec2 uv, vec2 stepxy, float B, float C)
{
    vec2 pos = uv + stepxy / 2.0;
    vec2 f = fract(pos / stepxy);

    vec4 xtaps = bicubic4(1.0 - f.x, B, C);
    vec4 ytaps = bicubic4(1.0 - f.y, B, C);
    xtaps /= (xtaps.r + xtaps.g + xtaps.b + xtaps.a);
    ytaps /= (ytaps.r + ytaps.g + ytaps.b + ytaps.a);

    vec2 xystart = (-1.5 - f) * stepxy + pos;

    vec4 xpos = vec4(xystart.x,
             xystart.x + stepxy.x,
             xystart.x + stepxy.x * 2.0,
             xystart.x + stepxy.x * 3.0);

    vec3 col = vec3(0.0);

    float y0 = xystart.y;
    col += (texture(source, vec2(xpos.r, y0)).rgb * xtaps.r +
        texture(source, vec2(xpos.g, y0)).rgb * xtaps.g +
        texture(source, vec2(xpos.b, y0)).rgb * xtaps.b +
        texture(source, vec2(xpos.a, y0)).rgb * xtaps.a) * ytaps.r;

    float y1 = xystart.y + stepxy.y;
    col += (texture(source, vec2(xpos.r, y1)).rgb * xtaps.r +
        texture(source, vec2(xpos.g, y1)).rgb * xtaps.g +
        texture(source, vec2(xpos.b, y1)).rgb * xtaps.b +
        texture(source, vec2(xpos.a, y1)).rgb * xtaps.a) * ytaps.g;

    float y2 = xystart.y + stepxy.y * 2.0;
    col += (texture(source, vec2(xpos.r, y2)).rgb * xtaps.r +
        texture(source, vec2(xpos.g, y2)).rgb * xtaps.g +
        texture(source, vec2(xpos.b, y2)).rgb * xtaps.b +
        texture(source, vec2(xpos.a, y2)).rgb * xtaps.a) * ytaps.b;

    float y3 = xystart.y + stepxy.y * 3.0;
    col += (texture(source, vec2(xpos.r, y3)).rgb * xtaps.r +
        texture(source, vec2(xpos.g, y3)).rgb * xtaps.g +
        texture(source, vec2(xpos.b, y3)).rgb * xtaps.b +
        texture(source, vec2(xpos.a, y3)).rgb * xtaps.a) * ytaps.a;

    return col;
}

// ---- Local geometry helpers (subset; barrel handled later stage) ----
// Parameterized pincushion (electrostatic/linear) using anisotropic angles (radians)
vec2 pincushion_theta(vec2 uv, const float theta_h, const float theta_v)
{
    if (theta_h < EPS && theta_v < EPS) return uv;
    float safe_theta_h = max(theta_h, 0.001);
    float safe_theta_v = max(theta_v, 0.001);
    vec2 t = uv * vec2(safe_theta_h, safe_theta_v);
    float x = t.x;
    float y = t.y;
    float dx = atan(x * cos(y));
    float dy = atan(y * cos(x));
    vec2 out_uv = vec2(dx / safe_theta_h, dy / safe_theta_v);
    return out_uv;
}

// Parameterized pincushion non-linear (magnetic) using anisotropic angles (radians)
// Blends between safe linear-style function near origin and non-linear function away from it
vec2 pincushion_nl_theta(vec2 uv, const float theta_h, const float theta_v)
{
    if (theta_h < EPS && theta_v < EPS)
        return uv;
    float safe_theta_h = max(theta_h, 0.001);
    float safe_theta_v = max(theta_v, 0.001);
    
    vec2 t = uv * vec2(safe_theta_h, safe_theta_v);
    float x = t.x;
    float y = t.y;
    
    // Smoothly blend from safe linear function near origin to non-linear function away from it
    // This avoids discontinuity at y≈0 and x≈0
    float blend_x = smoothstep(0.05, 0.3, abs(x));
    float blend_y = smoothstep(0.05, 0.3, abs(y));
    
    // Safe linear-style approximation near origin (avoids asin domain issues)
    float dx_safe = atan(x * cos(y));
    float dy_safe = atan(y * cos(x));
    
    // Original non-linear (magnetic) function away from origin
    float dx_nl = atan(asin(clamp(x, -1.0, 1.0)) * cos(asin(clamp(y, -1.0, 1.0))));
    float dy_nl = atan(asin(clamp(y, -1.0, 1.0)) * cos(asin(clamp(x, -1.0, 1.0))));
    
    // Blend smoothly
    float dx = mix(dx_safe, dx_nl, blend_x);
    float dy = mix(dy_safe, dy_nl, blend_y);
    
    vec2 out_uv = vec2(dx / safe_theta_h, dy / safe_theta_v);
    return out_uv;
}

// Cyclic distance on a ring of length `period`
// Returns shortest wrapped distance between x and center.
float cyclicDist(float x, float center, float period)
{
    float d = abs(x - center);
    return min(d, period - d);
}

// Map from framebuffer UV to input texture coordinates, applying
// display framing, physical distortions, and electronic service geometry.
// Inputs:
//  - vTexCoord: source framebuffer UV in [0,1]
//  - dar: selected display aspect ratio (e.g., 4/3, 16/9)
// Outputs:
//  - input_tex: UV to sample the source texture
void apply_geometry_pipeline(
    vec2 uv,
    float dar,
    out vec2 input_tex)
{
    // Start in full-video square space
    vec2 uv_screen = uv * 2.0 - 1.0;  // [-1,1] in texture space
    vec2 sq = vec2(uv_screen.x, uv_screen.y / dar);

    // --- Physical distortions (pincushion and magnetic) ---
    float theta_defl = radians(DEFLECTION_ANGLE / 4.0);
    if (DEFLECTION_ANGLE > 4.0) {
        if (DEFLECTION_ANGLE <= 60.0) {
            sq = pincushion_theta(sq, theta_defl, theta_defl);
        } else {
            sq = pincushion_nl_theta(sq, theta_defl, theta_defl);
        }
    }
    float mag_corr = MAGNETIC_CORRECTION * 0.01;
    if (mag_corr > 0.0) {
        sq = magnetic_correction(sq, mag_corr, 2.0 * theta_defl);
    }

    // --- Electronic positioning/sizing and service corrections (all in square space) ---
    float sx = USER_H_SIZE / 50.0;
    float sy = USER_V_SIZE / 50.0;
    float ox = (USER_H_POS - 50.0) / 50.0;
    float oy = (USER_V_POS - 50.0) / 50.0;
    float underscan_scale = (USER_UNDERSCAN_TOGGLE > 0.5) ? (1.0 - (UNDERSCAN * 0.01)) : 1.0;
    // Offset/scale in display-geometry units (dar for X)
    sq = (sq - vec2(ox * dar, oy)) / (vec2(sx, sy) * underscan_scale);

    // Electronic service corrections (trapezoid, corner, S-corrections)
    float trap = TRAPEZOIDAL_CORRECTION * 0.01;
    float corner = CORNER_CORRECTION * 0.01;
    float s_h = S_CORRECTION_H * 0.01;
    float s_v = S_CORRECTION_V * 0.01;
    if (abs(trap) > 0.0001 || abs(corner) > 0.0001 || abs(s_h) > 0.0001 || abs(s_v) > 0.0001) {
        sq = geometric_correction(sq, trap, corner, s_h, s_v);
    }

    // Convert back from display-geometry space to full-video square space, then to normalized
    vec2 uv_full = vec2(sq.x, sq.y * dar);
    input_tex = uv_full * 0.5 + 0.5; // full video area [0,1]
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
    // Case 1: pixels_per_unit >= 1.0 → Point sampling (sufficient resolution)
    // Case 2: 1/3 <= pixels_per_unit < 1.0 → Numerical integration (anti-aliasing)
    // Case 3: pixels_per_unit < 1/3 → Passthrough (pattern nearly unresolvable)
    const float INTEGRATION_THRESHOLD = 1.0;
    const float PASSTHROUGH_THRESHOLD = 1.0 / 3.0;

    bool use_integration_x = (pixels_per_unit.x >= PASSTHROUGH_THRESHOLD &&
                              pixels_per_unit.x < INTEGRATION_THRESHOLD);
    bool use_integration_y = (pixels_per_unit.y >= PASSTHROUGH_THRESHOLD &&
                              pixels_per_unit.y < INTEGRATION_THRESHOLD);
    bool passthrough_x = pixels_per_unit.x < PASSTHROUGH_THRESHOLD;
    bool passthrough_y = pixels_per_unit.y < PASSTHROUGH_THRESHOLD;

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

    return mask_color;
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float maskAR;
layout(location = 2) out FrameGeometry geom;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Selected target aspect ratio for framing
    maskAR = (ASPECT < 0.5) ? (4.0 / 3.0)
        : (ASPECT < 1.5) ? (16.0 / 9.0)
        : (ASPECT < 2.5) ? (5.0 / 4.0)
        : (16.0 / 10.0);

    geom = compute_frame_geometry(
        config.FrameCount,
        config.OriginalSize.xy,
        config.OriginalFPS,
        SC_FREQ_MODE,
        SC_FREQ,
        PIXEL_CLOCK,
        PIXEL_CLOCK_MODE,
        H_FREQ_MODE,
        H_FREQ,
        V_FREQ_MODE,
        V_FREQ,
        H_BLANK_FUZZ);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float maskAR;
layout(location = 2) in FrameGeometry geom;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;

void main()
{
    // Horizontal timing from frame geometry
    float total_h_pixels = geom.h_pixels;
    float total_v_lines = geom.is_interlaced < 0.5 ? geom.v_lines_per_field : geom.v_lines_per_frame;

    // Aspect ratios for full video
    float original_dar = config.OriginalAspect;
    float original_sar = config.OriginalSize.x / config.OriginalSize.y;
    float original_par = original_dar / max(original_sar, EPS);

    float full_dar = original_par * total_h_pixels / max(total_v_lines, 1.0);
    float full_sar = total_h_pixels / max(total_v_lines, 1.0);
    float full_par = full_dar / max(full_sar, EPS);

    // When there's padding, adjust full aspect to account for it
    float h_scale1 = floor(config.FrameSize.x / total_h_pixels);
    float v_scale1 = floor(config.FrameSize.y / total_v_lines);

    float h_scale2 = floor(config.SourceSize.x / (total_h_pixels * h_scale1));
    float v_scale2 = floor(config.SourceSize.y / (total_v_lines * v_scale1));

    float h_scale = max(h_scale1 * h_scale2, 1.0);
    float v_scale = max(v_scale1 * v_scale2, 1.0);

    // Calculate the active (non-padded) dimensions in the input texture
    float active_width = floor(total_h_pixels) * h_scale;
    float active_height = floor(total_v_lines) * v_scale;

    float source_sar = config.SourceSize.x / config.SourceSize.y;
    float active_sar = active_width / max(active_height, 1.0);
    float source_dar = full_dar * source_sar / active_sar;
    source_dar *= DAR_SCALE;

    // Calculate active region bounds in texture UV space (centered)
    float active_left = (config.SourceSize.x - active_width) * 0.5 / config.SourceSize.x;
    float active_right = (config.SourceSize.x + active_width) * 0.5 / config.SourceSize.x;
    float active_top = (config.SourceSize.y - active_height) * 0.5 / config.SourceSize.y;
    float active_bottom = (config.SourceSize.y + active_height) * 0.5 / config.SourceSize.y;

    // Expand vTexCoord so active region UVs map to [0,1]
    float norm_x = (vTexCoord.x - active_left) / max(active_right - active_left, EPS);
    float norm_y = (vTexCoord.y - active_top) / max(active_bottom - active_top, EPS);
    vec2 active_uv = vec2(norm_x, norm_y);

    // Fill to mask border (zoom): scale so the smaller axis fills the mask border
    vec2 uv_zoom = 2.0 * active_uv - 1.0;
    float content_aspect = source_dar;
    float target_aspect = maskAR;
    vec2 scale = vec2(1.0);

    if (content_aspect > target_aspect) {
        // Content is wider: scale x up (crop sides)
        scale.x = content_aspect / target_aspect;
        // Uncomment to crop out padding fully
        scale *= config.SourceSize.y / active_height;
    } else {
        // Content is taller: scale y up (crop top/bottom)
        scale.y = target_aspect / content_aspect;
        // Uncomment to crop out padding fully
        scale *= config.SourceSize.x / active_width;
    }
    uv_zoom /= scale;
    active_uv = 0.5 * (uv_zoom + 1.0);

    // ---- Geometry pipeline ----
    vec2 geometry_uv;
    if (GEOMETRY_BYPASS > 0.5) {
        geometry_uv = active_uv;
    } else {
        apply_geometry_pipeline(
            active_uv,
            maskAR,
            geometry_uv);
    }

    // Remap from geometry UVs to input texture UVs
    vec2 input_uv = vec2(
        active_left + geometry_uv.x * (active_right - active_left),
        active_top + geometry_uv.y * (active_bottom - active_top)
    );

    // Bicubic resample from input texture using BEAM_FOCUS
    float focus = clamp(BEAM_FOCUS * 0.01, 0.0, 1.0);
    float C = -1.0 / 3.0 * focus * focus + 5.0 / 6.0 * focus;
    float B = 1.0 - 2.0 * C;

    vec3 color;
    if (FILTER_BYPASS < 0.5) {
        color = sample_bicubic(Source, input_uv, 1.0 / config.SourceSize.xy, B, C);
    } else {
        color = texture(Source, input_uv).rgb;
    }

    // If mask is bypassed, return color as-is
    if (MASK_BYPASS >= 1.0) {
        FragColor = vec4(color, 1.0);
        return;
    }

    // TVL-based unit scaling independent of output resolution
    // 1 TVL = 6 horizontal units (one RGB triad + gaps) in all modes
    // TVL here is defined for the selected frame aspect
    float tvl = max(TVL, 1.0);
    float units_x_total = tvl * 6.0;

    // Vertical units depend on mask type:
    // Aperture: no vertical structure (use minimal for consistency)
    // Slot: 3-unit vertical cycle (simplified slot with gating)
    // Shadow: 4 vertical units per TVL (4-row shadow mask cycle)
    float units_y_total;
    if (MASK_TYPE < 0.5) {
        units_y_total = tvl; // Aperture has no vertical pattern
    } else if (MASK_TYPE < 1.5) {
        units_y_total = tvl / maskAR * 2.5;
    } else {
        units_y_total = tvl / maskAR * 6.0;
    }

    float mask_intensity = MASK_INTENSITY * 0.01;

    // Gaussian stripe helper (sigma in pattern units)
    vec2 pixels_per_unit = config.OutputSize.xy / vec2(units_x_total, units_y_total);

    vec3 mask_color = compute_mask(vTexCoord, units_x_total, units_y_total, pixels_per_unit);
    vec3 masked_color = mix(color, color * mask_color, mask_intensity);

    if (BEAM_DEBUG_OUT_OF_RANGE >= 1.0) {
        masked_color = zebra(masked_color, 0.0, 1.0, vTexCoord, config.OutputSize.xy, config.FrameCount, 2.0);
    }

    FragColor = vec4(masked_color, 1.0);
}