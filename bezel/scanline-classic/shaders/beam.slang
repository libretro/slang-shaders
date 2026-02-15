#version 450

// Filename: beam.slang
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
// CRT beam simulation (geometry + resample)
// ------------------------------------------------
// Input: Linear YrYgYb signal
// Output: Linear YrYgYb signal

#include "common.inc"
#include "filter.h"
#include "geometry.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/factory-geometry.inc"
#include "menus/parameters/service-geometry.inc"
#include "menus/parameters/user-common.inc"
#include "menus/parameters/user-uncommon.inc"

#pragma name CRTBeam
#pragma format R16G16B16A16_SFLOAT

#pragma parameter GEOMETRY_BYPASS "Bypass beam geometry" 0.0 0.0 1.0 1.0
#pragma parameter FILTER_BYPASS "Bypass beam filter" 0.0 0.0 1.0 1.0

#pragma parameter DAR_SCALE "Display Aspect Ratio Scale" 1.0 0.1 5.0 0.01

layout(push_constant) uniform Push
{
    vec4 SourceSize;     // xy = input size in pixels
    vec4 OriginalSize;   // xy = input size in pixels
    vec4 OutputSize;     // xy = output size in pixels
    vec4 FrameHSize;
    vec4 FrameVSize;
    uint FrameCount;
    float OriginalFPS;
    float OriginalAspect;
    float ASPECT;
    float GEOMETRY_BYPASS;
    float FILTER_BYPASS;
    float V_FREQ_MODE;
    float V_FREQ;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float DAR_SCALE;
    float BEAM_FOCUS;
} config;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float H_BLANK_FUZZ;

    // ---- Geometry/user viewport controls ----
    float USER_H_SIZE;            // % (50 = 1.0)
    float USER_V_SIZE;            // % (50 = 1.0)

    float TRAPEZOIDAL_CORRECTION; // %
    float CORNER_CORRECTION;      // %
    float MAGNETIC_CORRECTION;    // % (0..100)
    float USER_H_POS;            // % (50 = center)
    float USER_V_POS;            // % (50 = center)
    float USER_UNDERSCAN_TOGGLE; // toggle

    // Factory/service geometry controls needed here
    float DEFLECTION_ANGLE; // degrees
    float UNDERSCAN;        // %
    float S_CORRECTION_H;   // %
    float S_CORRECTION_V;   // %
} global;

#define ASPECT config.ASPECT
#define GEOMETRY_BYPASS config.GEOMETRY_BYPASS
#define FILTER_BYPASS config.FILTER_BYPASS
#define V_FREQ_MODE config.V_FREQ_MODE
#define V_FREQ config.V_FREQ
#define SC_FREQ_MODE config.SC_FREQ_MODE
#define SC_FREQ config.SC_FREQ
#define PIXEL_CLOCK_MODE global.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK global.PIXEL_CLOCK
#define H_FREQ_MODE global.H_FREQ_MODE
#define H_FREQ global.H_FREQ
#define H_BLANK_FUZZ global.H_BLANK_FUZZ
#define DAR_SCALE config.DAR_SCALE

// Geometry macro bindings
#define USER_H_SIZE global.USER_H_SIZE
#define USER_V_SIZE global.USER_V_SIZE
#define TRAPEZOIDAL_CORRECTION global.TRAPEZOIDAL_CORRECTION
#define CORNER_CORRECTION global.CORNER_CORRECTION
#define MAGNETIC_CORRECTION global.MAGNETIC_CORRECTION
#define USER_H_POS global.USER_H_POS
#define USER_V_POS global.USER_V_POS
#define USER_UNDERSCAN_TOGGLE global.USER_UNDERSCAN_TOGGLE
#define DEFLECTION_ANGLE global.DEFLECTION_ANGLE
#define UNDERSCAN global.UNDERSCAN
#define S_CORRECTION_H global.S_CORRECTION_H
#define S_CORRECTION_V global.S_CORRECTION_V
#define BEAM_FOCUS config.BEAM_FOCUS

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
    // This avoids discontinuity at y~=0 and x~=0
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
    float h_scale1 = floor(config.FrameHSize.x / total_h_pixels);
    float v_scale1 = floor(config.FrameVSize.y / total_v_lines);

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
    float alpha = texture(Source, input_uv).a;
    if (FILTER_BYPASS < 0.5) {
        color = sample_bicubic(Source, input_uv, 1.0 / config.SourceSize.xy, B, C);
    } else {
        color = texture(Source, input_uv).rgb;
    }

    FragColor = vec4(max(color, 0.0), alpha);
}
