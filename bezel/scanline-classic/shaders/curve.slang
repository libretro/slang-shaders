#version 450

// Filename: curve.slang
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
// CRT Curvature with Anisotropic Filtering
// ------------------------------------------------
// Input: Linear RGB signal
// Output: Linear RGB signal

#include "common.inc"
#include "geometry.inc"
#include "filter.h"
#include "modulation.inc"
#include "tools/zebra.inc"

#include "menus/parameters/user-common.inc"
#include "menus/parameters/factory-geometry.inc"
#include "menus/parameters/output-curve.inc"

#pragma name Curve
#pragma format R16G16B16A16_SFLOAT

#pragma parameter CURVE_BYPASS "Bypass Curvature" 0 0 1.0 1.0
#pragma parameter CURVE_FILTER "Curvature filter (0=off, 1=on)" 1.0 0.0 1.0 1.0
#pragma parameter DEBUG_BARREL_SURROUND "Debug: Show surround outside barrel" 0.0 0.0 1.0 1.0
#pragma parameter CURVE_DEBUG_OUT_OF_RANGE "Curve: Show out-of-range colors" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    // IO
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;

    // Control
    float CURVE_BYPASS;
    float CURVE_FILTER;
    float SCREEN_FOCUS;
    float ZOOM;
    float DEBUG_BARREL_SURROUND;

    // Factory geometry (angles in degrees)
    float ASPECT;
    float SCREEN_ANGLE_H;
    float SCREEN_ANGLE_V;

    float CURVE_DEBUG_OUT_OF_RANGE;
} config;

// Macro bindings for consistency with code style
#define CURVE_BYPASS config.CURVE_BYPASS
#define CURVE_FILTER config.CURVE_FILTER
#define SCREEN_FOCUS config.SCREEN_FOCUS
#define ZOOM config.ZOOM
#define DEBUG_BARREL_SURROUND config.DEBUG_BARREL_SURROUND

#define ASPECT config.ASPECT
#define SCREEN_ANGLE_H config.SCREEN_ANGLE_H
#define SCREEN_ANGLE_V config.SCREEN_ANGLE_V

#define CURVE_DEBUG_OUT_OF_RANGE config.CURVE_DEBUG_OUT_OF_RANGE

// MVP / matrix UBO (matches project convention)
layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

// ---- Helpers ----

// Parameterized barrel distortion using anisotropic angles (radians)
vec2 barrel_theta(vec2 uv, const float theta_h, const float theta_v)
{
    if (theta_h < EPS && theta_v < EPS) return uv;

    // Use small value (0.001) instead of 0 to preserve cross-axis coupling
    // This matches scanline-advanced.slang's approach for cylindrical curvature
    float safe_theta_h = max(theta_h, 0.001);
    float safe_theta_v = max(theta_v, 0.001);

    vec2 t = uv * vec2(safe_theta_h, safe_theta_v);
    float x = t.x;
    float y = t.y;

    // barrel formula: dx = tan(x)/cos(y), dy = tan(y)/cos(x)
    float dx = tan(x) / cos(y);
    float dy = tan(y) / cos(x);

    vec2 out_uv = vec2(dx / safe_theta_h, dy / safe_theta_v);
    return out_uv;
}

// Bicubic texture sampling (4x4 Mitchell-Netravali)
// Rewritten to match scanline-advanced.slang's approach
vec3 sample_bicubic(sampler2D source, vec2 uv, vec2 stepxy, float B, float C)
{
    vec2 texSize = vec2(textureSize(source, 0));

    // Calculate fractional position within pixel grid
    vec2 pos = uv + stepxy / 2.0;
    vec2 f = fract(pos / stepxy);

    // Calculate bicubic filter coefficients
    vec4 xtaps = bicubic4(1.0 - f.x, B, C);
    vec4 ytaps = bicubic4(1.0 - f.y, B, C);

    // Normalize taps to ensure they sum to 1.0 (preserve brightness)
    xtaps /= xtaps.r + xtaps.g + xtaps.b + xtaps.a;
    ytaps /= ytaps.r + ytaps.g + ytaps.b + ytaps.a;

    // Calculate starting position for 4x4 kernel (centered on pixel)
    vec2 xystart = (-1.5 - f) * stepxy + pos;

    // Precompute 4 horizontal sample positions
    vec4 xpos = vec4(xystart.x,
                     xystart.x + stepxy.x,
                     xystart.x + stepxy.x * 2.0,
                     xystart.x + stepxy.x * 3.0);

    // Apply 4x4 bicubic filter
    vec3 col = vec3(0.0);

    // Row 0 (topmost)
    float y0 = xystart.y;
    col += (texture(source, vec2(xpos.r, y0)).rgb * xtaps.r +
            texture(source, vec2(xpos.g, y0)).rgb * xtaps.g +
            texture(source, vec2(xpos.b, y0)).rgb * xtaps.b +
            texture(source, vec2(xpos.a, y0)).rgb * xtaps.a) * ytaps.r;

    // Row 1
    float y1 = xystart.y + stepxy.y;
    col += (texture(source, vec2(xpos.r, y1)).rgb * xtaps.r +
            texture(source, vec2(xpos.g, y1)).rgb * xtaps.g +
            texture(source, vec2(xpos.b, y1)).rgb * xtaps.b +
            texture(source, vec2(xpos.a, y1)).rgb * xtaps.a) * ytaps.g;

    // Row 2
    float y2 = xystart.y + stepxy.y * 2.0;
    col += (texture(source, vec2(xpos.r, y2)).rgb * xtaps.r +
            texture(source, vec2(xpos.g, y2)).rgb * xtaps.g +
            texture(source, vec2(xpos.b, y2)).rgb * xtaps.b +
            texture(source, vec2(xpos.a, y2)).rgb * xtaps.a) * ytaps.b;

    // Row 3 (bottommost)
    float y3 = xystart.y + stepxy.y * 3.0;
    col += (texture(source, vec2(xpos.r, y3)).rgb * xtaps.r +
            texture(source, vec2(xpos.g, y3)).rgb * xtaps.g +
            texture(source, vec2(xpos.b, y3)).rgb * xtaps.b +
            texture(source, vec2(xpos.a, y3)).rgb * xtaps.a) * ytaps.a;

    return col;
}

// ---- Vertex Shader ----

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

// ---- Fragment Shader ----

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;

void main()
{
    // Simple bypass
    if (CURVE_BYPASS > 0.5) {
        vec4 src = texture(Source, vTexCoord);
        FragColor = vec4(src.rgb, src.a);
        return;
    }

    // Selected target aspect ratio for framing
    float maskAR = (ASPECT < 0.5)   ? (4.0 / 3.0)
                   : (ASPECT < 1.5) ? (16.0 / 9.0)
                   : (ASPECT < 2.5) ? (5.0 / 4.0)
                                    : (16.0 / 10.0);

    // Convert output coordinate to normalized [-1,1]
    vec2 uv = vTexCoord * 2.0 - 1.0;

    // To square space for isotropic distortions
    vec2 sq = vec2(uv.x * maskAR, uv.y);

    // Physical CRT geometry pipeline
    float theta_h = radians(SCREEN_ANGLE_H / 2.0);
    float theta_v = radians(SCREEN_ANGLE_V / 2.0);

    // Barrel from screen curvature
    sq = barrel_theta(sq, theta_h, theta_v);

    // Back to texture space
    vec2 uv2 = vec2(sq.x / maskAR, sq.y);
    vec2 tex = uv2 * 0.5 + 0.5;

    // --- ZOOM implementation ---
    float zoom = clamp(ZOOM, 50.0, 200.0) / 100.0; // 1.0 = 100%
    tex = (tex - 0.5) / zoom + 0.5;
    // ---------------------------

    // --- Debug: Show surround outside barrel ---
    if (DEBUG_BARREL_SURROUND > 0.5 && (tex.x < 0.0 || tex.x > 1.0 || tex.y < 0.0 || tex.y > 1.0)) {
        FragColor = vec4(0.0, 0.0, 0.5, 1.0); // Blue
        return;
    }
    // ------------------------------------------

    // Compute bicubic filter coefficients from focus parameter
    float focus = clamp(SCREEN_FOCUS * 0.01, 0.0, 1.0);
    float C = -1.0 / 3.0 * focus * focus + 5.0 / 6.0 * focus;
    float B = 1.0 - 2.0 * C;

    // Bicubic/Lanczos3/Nearest resample from input texture
    vec3 color;
    float alpha;
    if (CURVE_FILTER < 0.5) {
        vec4 src = texture(Source, tex);
        color = src.rgb;
        alpha = src.a;
    } else {
        color = sample_bicubic(Source, tex, 1.0 / config.SourceSize.xy, B, C);
        alpha = texture(Source, tex).a;
    }

    if (CURVE_DEBUG_OUT_OF_RANGE > 0.5) {
        color = zebra(color, 0.0, 1.0, vTexCoord, config.OutputSize.xy, config.FrameCount, 1.0);
    }

    FragColor = vec4(max(color, 0.0), alpha);
}
