// Filename: color-base.slang
//
// Copyright (C) 2025-2026 W. M. Martinez
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
// Color converter base functions, to be used with #include

#include "common.inc"
#include "color.inc"
#include "tools/zebra.inc"

#include "menus/parameters/output-tonemap.inc"
#include "menus/parameters/colorimetry.inc"
#include "menus/parameters/output-color.inc"
#include "menus/parameters/user-common.inc"

#pragma parameter COLOR_CONVERSION_BYPASS "Bypass color correction" 0.0 0.0 1.0 1.0
#pragma parameter DEBUG_COLOR_DELTA "Show color correction deltas" 0.0 0.0 1.0 1.0
#pragma parameter COLOR_DEBUG_OUT_OF_RANGE "Debug out-of-range colors" 0.0 0.0 1.0 1.0
#pragma parameter DEBUG_CARD "Show debug card" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float R_X;
    float R_Y;
    float G_X;
    float G_Y;
    float B_X;
    float B_Y;
    float W_X;
    float W_Y;
    float CHROMATIC_ADAPTATION;
    float ADAPTATION_LEVEL;
#ifdef SDR
    float GAMUT_COMPRESSION;
#endif
#ifdef WCG
    float GAMUT_SELECT;
#endif
    float COLOR_CONVERSION_BYPASS;
    float COLORIMETRY_PRESET;
    float TONEMAP_TYPE;
    float MAKEUP_GAIN;
    float DEBUG_COLOR_DELTA;
    float COLOR_DEBUG_OUT_OF_RANGE;
    float DEBUG_CARD;
    float USER_PICTURE;
    float USER_BRIGHTNESS;
} config;

#define COLORIMETRY_PRESET config.COLORIMETRY_PRESET
#define R_X config.R_X
#define R_Y config.R_Y
#define G_X config.G_X
#define G_Y config.G_Y
#define B_X config.B_X
#define B_Y config.B_Y
#define W_X config.W_X
#define W_Y config.W_Y
#define CHROMATIC_ADAPTATION config.CHROMATIC_ADAPTATION
#define ADAPTATION_LEVEL config.ADAPTATION_LEVEL

#ifdef SDR
#define GAMUT_COMPRESSION config.GAMUT_COMPRESSION
#endif

#ifdef WCG
#define GAMUT_SELECT config.GAMUT_SELECT
#endif

#define TONEMAP_TYPE config.TONEMAP_TYPE
#define MAKEUP_GAIN config.MAKEUP_GAIN

#define COLOR_CONVERSION_BYPASS config.COLOR_CONVERSION_BYPASS
#define DEBUG_COLOR_DELTA config.DEBUG_COLOR_DELTA
#define COLOR_DEBUG_OUT_OF_RANGE config.COLOR_DEBUG_OUT_OF_RANGE
#define DEBUG_CARD config.DEBUG_CARD

#define USER_PICTURE config.USER_PICTURE
#define USER_BRIGHTNESS config.USER_BRIGHTNESS

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

// -- Color space conversion functions -- //

// -- Perceptual color transform functions -- //
// Linear methods are in color.inc

// Pre-computed Bradford parameters (constant across all pixels)
struct BradfordParams {
    vec3 wref_RGB;   // M * wref_XYZ (reference white in cone response space)
    vec2 rg_scale;   // wout_RGB.rg / wref_RGB.rg (R and G adaptation scale)
    float b_out;     // wout_RGB.b (target blue cone response)
    float p;         // power exponent for blue channel (1/12)
};

// Fast Bradford using pre-computed parameters
vec3 bradford_fast(vec3 color_XYZ, const BradfordParams params)
{
    const mat3 M = mat3(
         0.8951, -0.7502,  0.0389,
         0.2664,  1.7135, -0.0685,
        -0.1614,  0.0367,  1.0296);
    const mat3 M_inv = mat3(
         0.9869929,  0.4323053, -0.0085287,
        -0.1470543,  0.5183603,  0.0400428,
         0.1599627,  0.0492912,  0.9684867);

    vec3 color_RGB = M * color_XYZ;
    vec2 adapted_RG = params.rg_scale * color_RGB.rg;
    float adapted_B = params.b_out * pow(color_RGB.b / params.wref_RGB.b, params.p);
    return M_inv * vec3(adapted_RG, adapted_B);
}

// Standard Bradford transform
//
// color_XYZ: Input color in XYZ space
// wref_XYZ: Reference white point in XYZ space
//
// Inputs should be normalized by Y before calling this function. 
vec3 bradford(vec3 color_XYZ, vec3 wref_XYZ)
{
    // Target white point is always D65
    const vec3 D65_XYZ = vec3(0.95047, 1.0, 1.08883);
    const mat3 M = mat3(
         0.8951, -0.7502,  0.0389,
         0.2664,  1.7135, -0.0685,
        -0.1614,  0.0367,  1.0296);
    const mat3 M_inv = mat3(
         0.9869929,  0.4323053, -0.0085287,
        -0.1470543,  0.5183603,  0.0400428,
         0.1599627,  0.0492912,  0.9684867);

    vec3 color_RGB = M * color_XYZ;
    vec3 wref_RGB = M * wref_XYZ;
    vec3 wout_RGB = M * D65_XYZ;
    vec2 adapted_RG = wout_RGB.rg * (color_RGB.rg / wref_RGB.rg);
    float p = pow(wref_RGB.b / wout_RGB.b, 0.0834);  // 1/12
    float adapted_B = wout_RGB.b * pow(color_RGB.b / wref_RGB.b, p);
    vec3 result = M_inv * vec3(adapted_RG, adapted_B);
    return result;
}

// -- Gamut compression functions -- //

// Simple luminance scaling to fit color space
vec3 reduce_luminance(const vec3 color)
{
    float maxC = max(max(color.r, color.g), color.b);
    if (maxC > 1.0) {
        // Scale all channels so the maximum is 1.0
        return color / maxC;
    }
    return color;
}

const float THRESHOLD = 1.0 / 255.0;

// --- Advanced gamut compression in CIE Luv space -- //
//
// Reduces luminance and chroma as needed to fit into output gamut.
// Since most displays have luminance headroom in dim environments,
// this method prioritizes preserving chrominance over luminance when
// a channel is greater than 1.0.  Conversely, when a channel is less
// than 0.0, luminance is preserved while chroma is reduced because
// humans are less sensitive to chroma loss in dark colors while being
// more sensitive to changes in luminance.

// Scale luminance in CIE Luv space
float scale_luminance_cieluv(vec3 color, vec3 luv, mat3 toRGB)
{
    // Reduce luminance if any channel > 1
    if (any(greaterThan(color, vec3(1.0)))) {
        float minScale = 0.0;
        float maxScale = 1.0;
        float scale = 1.0;
        for (int i = 0; i < 9; ++i) {
            float testL = luv.x * scale;
            vec3 testRGB = toRGB * CIE_LUV_to_XYZ(vec3(testL, luv.y, luv.z));
            if (all(lessThanEqual(testRGB, vec3(1.0)))) {
                minScale = scale;
            } else {
                maxScale = scale;
            }
            scale = 0.5 * (minScale + maxScale);
            if (maxScale - minScale < THRESHOLD)
                break;
        }
        return minScale;
    }
    return 1.0;
}

// Scale chroma in CIE Luv space
float scale_chroma_cieluv(vec3 color, vec3 luv, mat3 toRGB)
{
    // Reduce chroma if any channel < 0
    if (any(lessThan(color, vec3(0.0)))) {
        float minScale = 0.0;
        float maxScale = 1.0;
        float scale = 1.0;
        for (int i = 0; i < 9; ++i) {
            vec3 testLuv = vec3(luv.x, luv.y * scale, luv.z * scale);
            vec3 testRGB = toRGB * CIE_LUV_to_XYZ(testLuv);
            if (all(greaterThanEqual(testRGB, vec3(0.0)))) {
                minScale = scale;
            } else {
                maxScale = scale;
            }
            scale = 0.5 * (minScale + maxScale);
            if (maxScale - minScale < THRESHOLD)
                break;
        }
        return minScale;
    }
    return 1.0;
}

float scale_luminance_ipt(vec3 color, vec3 ipt, mat3 toRGB)
{
    if (any(greaterThan(color, vec3(1.0)))) {
        float minScale = 0.0;
        float maxScale = 1.0;
        float scale = 1.0;
        for (int i = 0; i < 9; ++i) {
            float testI = ipt.x * scale;
            vec3 testRGB = toRGB * IPT_to_XYZ(vec3(testI, ipt.y, ipt.z));
            if (all(lessThanEqual(testRGB, vec3(1.0)))) {
                minScale = scale;
            } else {
                maxScale = scale;
            }
            scale = 0.5 * (minScale + maxScale);
            if (maxScale - minScale < THRESHOLD)
                break;
        }
        return minScale;
    }
    return 1.0;
}

float scale_chroma_ipt(vec3 color, vec3 ipt, mat3 toRGB)
{
    if (any(lessThan(color, vec3(0.0)))) {
        float minScale = 0.0;
        float maxScale = 1.0;
        float scale = 1.0;
        for (int i = 0; i < 9; ++i) {
            vec3 testIpt = vec3(ipt.x, ipt.yz * scale);
            vec3 testRGB = toRGB * IPT_to_XYZ(testIpt);
            if (all(greaterThanEqual(testRGB, vec3(0.0)))) {
                minScale = scale;
            } else {
                maxScale = scale;
            }
            scale = 0.5 * (minScale + maxScale);
            if (maxScale - minScale < THRESHOLD)
                break;
        }
        return minScale;
    }
    return 1.0;
}

// -- Uncharted 2 tone mapping functions -- //
// Partial tone map (filmic curve)
float uncharted2_tonemap_partial(float x)
{
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

// Full Uncharted 2 tone mapping with exposure bias and white point normalization
float uncharted2_tonemap( float color, float exposure_bias)
{
    float curr = uncharted2_tonemap_partial(color * exposure_bias);
    float white_scale = 1.0 / uncharted2_tonemap_partial(11.2);
    return curr * white_scale;
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
#ifdef WIDE_COLOR
layout(location = 1) out float white_level;
layout(location = 2) out float max_luma_weight;
layout(location = 3) out vec3 ref_XYZ;
layout(location = 4) out mat3 cat_transform;
layout(location = 7) out BradfordParams bradford_params;
layout(location = 11) out Colorimetry colorimetry;
#endif
#ifdef SDR
layout(location = 1) out float white_level;
layout(location = 2) out float max_luma_weight;
layout(location = 3) out vec3 ref_XYZ;
layout(location = 4) out vec2 luv_scale;
layout(location = 5) out vec2 ipt_scale;
layout(location = 6) out mat3 cat_transform;
layout(location = 9) out BradfordParams bradford_params;
layout(location = 13) out Colorimetry colorimetry;
#endif

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Compute white_level from user controls (matches crt-linear.slang)
    float black_level = 2.0 * USER_BRIGHTNESS / 100.0 - 1.0;
    white_level = 2.0 * USER_PICTURE / 100.0 + black_level;

    vec3 ref_XYZ;
    vec3 white_XYZ;
    vec3 red_XYZ;
    vec3 green_XYZ;
    vec3 blue_XYZ;

    // Set up colorimetry
    mat3 RGB_to_XYZ_local;  // Local variable for vertex shader use only
    if (COLORIMETRY_PRESET < 0.5) {
        // Custom
        colorimetry = Colorimetry(
            vec2(R_X, R_Y),
            vec2(G_X, G_Y),
            vec2(B_X, B_Y),
            vec2(W_X, W_Y));
        ref_XYZ = xyY_to_XYZ(vec3(W_X, W_Y, 1.0));
        red_XYZ = xyY_to_XYZ(vec3(R_X, R_Y, 1.0));
        green_XYZ = xyY_to_XYZ(vec3(G_X, G_Y, 1.0));
        blue_XYZ = xyY_to_XYZ(vec3(B_X, B_Y, 1.0));

        RGB_to_XYZ_local = get_RGB_to_XYZ(red_XYZ, green_XYZ, blue_XYZ, ref_XYZ);
    } else if (COLORIMETRY_PRESET < 1.5) {
        // Rec. 601
        colorimetry = Colorimetry(
            vec2(0.630, 0.340),
            vec2(0.310, 0.595),
            vec2(0.155, 0.070),
            vec2(0.3127, 0.3290));
        RGB_to_XYZ_local = SMPTE_C_TO_XYZ;
    } else if (COLORIMETRY_PRESET < 2.5) {
        // Japanese phosphors, D93
        colorimetry = Colorimetry(
            vec2(0.618, 0.350),
            vec2(0.280, 0.605),
            vec2(0.152, 0.063),
            vec2(0.2832, 0.2971));
        RGB_to_XYZ_local = NTSC_J_TO_XYZ;
    } else if (COLORIMETRY_PRESET < 3.5) {
        // EBU Tech 3213
        colorimetry = Colorimetry(
            vec2(0.640, 0.330),
            vec2(0.290, 0.600),
            vec2(0.150, 0.060),
            vec2(0.3127, 0.3290));
        RGB_to_XYZ_local = EBU_TO_XYZ;
    } else {
        // Rec. 709
        colorimetry = Colorimetry(
            vec2(0.640, 0.330),
            vec2(0.300, 0.600),
            vec2(0.150, 0.060),
            vec2(0.3127, 0.3290));
        RGB_to_XYZ_local = sRGB_TO_XYZ;
    }

    ref_XYZ = RGB_to_XYZ_local * WHITE;
    const vec3 D65_XYZ = vec3(0.95047, 1.0, 1.08883);

    // Extract luminance weights from native phosphor RGB_to_XYZ
    vec3 luma_weights = vec3(RGB_to_XYZ_local[0][1], RGB_to_XYZ_local[1][1], RGB_to_XYZ_local[2][1]);
    max_luma_weight = max(max(luma_weights.r, luma_weights.g), luma_weights.b);

    // Compute chromatic adaptation transform (same for all pixels)
    if (CHROMATIC_ADAPTATION < 0.5) {
        cat_transform = mat3(1.0);
    } else if (CHROMATIC_ADAPTATION < 1.5) {
        cat_transform = bradford_linear(ref_XYZ, D65_XYZ);
    } else if (CHROMATIC_ADAPTATION < 2.5) {
        cat_transform = zhai2018_cat16(ref_XYZ, D65_XYZ, ADAPTATION_LEVEL);
    } else {
        // Nonlinear Bradford is per-color, will apply in fragment
        cat_transform = mat3(1.0);
    }

    // Pre-compute Bradford parameters for fast per-pixel computation
    if (CHROMATIC_ADAPTATION >= 2.5) {
        const mat3 M = mat3(
             0.8951, -0.7502,  0.0389,
             0.2664,  1.7135, -0.0685,
            -0.1614,  0.0367,  1.0296);
        
        vec3 wref_RGB = M * ref_XYZ;
        vec3 wout_RGB = M * D65_XYZ;
        
        bradford_params.wref_RGB = wref_RGB;
        bradford_params.rg_scale = wout_RGB.rg / wref_RGB.rg;
        bradford_params.b_out = wout_RGB.b;
        bradford_params.p = pow(wref_RGB.b / wout_RGB.b, 0.0834);
    }

#ifdef SDR
    // Precompute Luv scale factors for advanced gamut compression
    // Apply chromatic adaptation to primary XYZ values for output gamut testing
    luv_scale = vec2(0.0);
    ipt_scale = vec2(0.0);
    
    if (GAMUT_COMPRESSION > 1.5) {
        vec3 white_XYZ = RGB_to_XYZ_local * WHITE;
        vec3 red_XYZ = RGB_to_XYZ_local * RED;
        vec3 green_XYZ = RGB_to_XYZ_local * GREEN;
        vec3 blue_XYZ = RGB_to_XYZ_local * INDIGO;
        
        // Apply chromatic adaptation to XYZ values directly
        if (CHROMATIC_ADAPTATION < 2.5 && CHROMATIC_ADAPTATION >= 0.5) {
            // Use pre-computed cat_transform (Linear Bradford or CAT16)
            white_XYZ = cat_transform * white_XYZ;
            red_XYZ = cat_transform * red_XYZ;
            green_XYZ = cat_transform * green_XYZ;
            blue_XYZ = cat_transform * blue_XYZ;
        } else if (CHROMATIC_ADAPTATION >= 2.5) {
            // Nonlinear Bradford adaptation using pre-computed parameters
            white_XYZ = bradford_fast(white_XYZ, bradford_params);
            red_XYZ = bradford_fast(red_XYZ, bradford_params);
            green_XYZ = bradford_fast(green_XYZ, bradford_params);
            blue_XYZ = bradford_fast(blue_XYZ, bradford_params);
        }
        vec3 white_out = XYZ_TO_COLOR_SPACE * white_XYZ;
        vec3 red_out = XYZ_TO_COLOR_SPACE * red_XYZ;
        vec3 green_out = XYZ_TO_COLOR_SPACE * green_XYZ;
        vec3 blue_out = XYZ_TO_COLOR_SPACE * blue_XYZ;

        if (GAMUT_COMPRESSION < 2.5) {
            vec3 white_luv = XYZ_to_CIE_LUV(white_XYZ);
            vec3 red_luv = XYZ_to_CIE_LUV(red_XYZ);
            vec3 green_luv = XYZ_to_CIE_LUV(green_XYZ);
            vec3 blue_luv = XYZ_to_CIE_LUV(blue_XYZ);

            // Determine luminance pre-scale
            float y_scale = scale_luminance_cieluv(white_out, white_luv, XYZ_TO_COLOR_SPACE);

            red_luv.x *= y_scale;
            green_luv.x *= y_scale;
            blue_luv.x *= y_scale;

            // Determine chroma pre-scale
            float red_c_scale = scale_chroma_cieluv(red_out, red_luv, XYZ_TO_COLOR_SPACE);
            float green_c_scale = scale_chroma_cieluv(green_out, green_luv, XYZ_TO_COLOR_SPACE);
            float blue_c_scale = scale_chroma_cieluv(blue_out, blue_luv, XYZ_TO_COLOR_SPACE);
            float c_scale = min(min(red_c_scale, green_c_scale), blue_c_scale);

            luv_scale = vec2(y_scale, c_scale);
        } else {
            vec3 white_ipt = XYZ_to_IPT(white_XYZ);
            vec3 red_ipt = XYZ_to_IPT(red_XYZ);
            vec3 green_ipt = XYZ_to_IPT(green_XYZ);
            vec3 blue_ipt = XYZ_to_IPT(blue_XYZ);

            float y_scale = scale_luminance_ipt(white_out, white_ipt, XYZ_TO_COLOR_SPACE);

            red_ipt.x *= y_scale;
            green_ipt.x *= y_scale;
            blue_ipt.x *= y_scale;

            float red_c_scale = scale_chroma_ipt(red_out, red_ipt, XYZ_TO_COLOR_SPACE);
            float green_c_scale = scale_chroma_ipt(green_out, green_ipt, XYZ_TO_COLOR_SPACE);
            float blue_c_scale = scale_chroma_ipt(blue_out, blue_ipt, XYZ_TO_COLOR_SPACE);
            float c_scale = min(min(red_c_scale, green_c_scale), blue_c_scale);

            ipt_scale = vec2(y_scale, c_scale);
        }
    }
#endif
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
#ifdef WIDE_COLOR
layout(location = 1) in float white_level;
layout(location = 2) in float max_luma_weight;
layout(location = 3) in vec3 ref_XYZ;
layout(location = 4) in mat3 cat_transform;
layout(location = 7) in BradfordParams bradford_params;
layout(location = 11) in Colorimetry colorimetry;
#endif
#ifdef SDR
layout(location = 1) in float white_level;
layout(location = 2) in float max_luma_weight;
layout(location = 3) in vec3 ref_XYZ;
layout(location = 4) in vec2 luv_scale;
layout(location = 5) in vec2 ipt_scale;
layout(location = 6) in mat3 cat_transform;
layout(location = 9) in BradfordParams bradford_params;
layout(location = 13) in Colorimetry colorimetry;
#endif
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;

void unpack_gain_pair(float packed, out float avg_gain, out float peak_gain)
{
    float combined = floor(packed * 65535.0 + 0.5);
    float avg8 = floor(combined / 256.0);
    float peak8 = combined - avg8 * 256.0;
    avg_gain = avg8 / 255.0;
    peak_gain = peak8 / 255.0;
}

vec3 rgb_to_YrYgYb(vec3 rgb, Colorimetry colorimetry)
{
    vec3 red_XYZ = xyY_to_XYZ(vec3(colorimetry.red_xy.x, colorimetry.red_xy.y, 1.0));
    vec3 green_XYZ = xyY_to_XYZ(vec3(colorimetry.green_xy.x, colorimetry.green_xy.y, 1.0));
    vec3 blue_XYZ = xyY_to_XYZ(vec3(colorimetry.blue_xy.x, colorimetry.blue_xy.y, 1.0));
    vec3 white_XYZ = xyY_to_XYZ(vec3(colorimetry.white_xy.x, colorimetry.white_xy.y, 1.0));

    mat3 primary_XYZ = mat3(red_XYZ, green_XYZ, blue_XYZ);
    vec3 S = inverse(primary_XYZ) * white_XYZ;
    return rgb * S;
}

vec3 render_debug_card(vec2 uv, float safe_gain, float peak_gain, Colorimetry colorimetry, out float high_peak)
{
    float out_gray = 0.0;
    vec3 out_color = vec3(0.0);
    high_peak = 100.0;

    float row = floor(uv.y * 6.0);
    if (row < 1.0) {
        // 10-step gray ramp, linear
        float step_index = floor(uv.x * 10.0);
        out_gray = clamp(step_index / 9.0, 0.0, 1.0);
        out_color = vec3(out_gray);
    } else if (row < 2.0) {
        // 10-step gray ramp, Rec. 709 OETF (decoded to linear)
        float step_index = floor(uv.x * 10.0);
        float code = clamp(step_index / 9.0, 0.0, 1.0);
        out_gray = sdr_linear(code);
        out_color = vec3(out_gray);
    } else if (row < 3.0) {
        // safe_gain then peak_gain
        if (uv.x < 0.5) {
            out_gray = safe_gain;
        } else {
            out_gray = peak_gain;
        }
        out_color = vec3(out_gray);
    } else if (row < 4.0) {
        // 10-step HDR ramp, logarithmic, 100 nits to 10000 nits (1 to 100)
        float step_index = floor(uv.x * 10.0);
        float t = clamp(step_index / 9.0, 0.0, 1.0);
        out_gray = pow(100.0, t);
        out_color = vec3(out_gray);
    } else if (row < 5.0) {
        // SDR color bars at 0.75
        float bar = floor(uv.x * 7.0);
        if (bar < 1.0) {
            out_color = vec3(1.0);
        } else if (bar < 2.0) {
            out_color = vec3(1.0, 1.0, 0.0);
        } else if (bar < 3.0) {
            out_color = vec3(0.0, 1.0, 1.0);
        } else if (bar < 4.0) {
            out_color = vec3(0.0, 1.0, 0.0);
        } else if (bar < 5.0) {
            out_color = vec3(1.0, 0.0, 1.0);
        } else if (bar < 6.0) {
            out_color = vec3(1.0, 0.0, 0.0);
        } else {
            out_color = vec3(0.0, 0.0, 1.0);
        }
        out_color *= 0.75;
    } else if (row < 6.0) {
        // HDR color bars at 4.0 (linear)
        float bar = floor(uv.x * 7.0);
        if (bar < 1.0) {
            out_color = vec3(1.0);
        } else if (bar < 2.0) {
            out_color = vec3(1.0, 1.0, 0.0);
        } else if (bar < 3.0) {
            out_color = vec3(0.0, 1.0, 1.0);
        } else if (bar < 4.0) {
            out_color = vec3(0.0, 1.0, 0.0);
        } else if (bar < 5.0) {
            out_color = vec3(1.0, 0.0, 1.0);
        } else if (bar < 6.0) {
            out_color = vec3(1.0, 0.0, 0.0);
        } else {
            out_color = vec3(0.0, 0.0, 1.0);
        }
        out_color *= 4.0;
    }

    return rgb_to_YrYgYb(out_color, colorimetry);
}

void main()
{
    const float TARGET_NITS = 100.0;

    vec4 src = texture(Source, vTexCoord);
    vec3 YrYgYb = src.rgb;
    float avg_gain;
    float peak_gain;
    unpack_gain_pair(src.a, avg_gain, peak_gain);
    float safe_gain = max(avg_gain, EPS);

    float high_peak;

    // Debug output: ramps and gain swatches, rest black
    if (DEBUG_CARD > 0.5) {
        YrYgYb = render_debug_card(vTexCoord, safe_gain, peak_gain, colorimetry, high_peak);
    } else {
        // Source peak luminance: white_level × target nits
        float source_peak = max(white_level * TARGET_NITS * peak_gain, EPS);

        // Apply makeup gain before tone mapping to boost highlights
        if (MAKEUP_GAIN > 0.5) {
            // Makeup gain is inverse of the gain channel from scanning, mask effects, etc.
            YrYgYb /= safe_gain;
            source_peak /= safe_gain;
        }

        // Determine high peak for tone mapping based on source peak and target nits
        float low_peak = TARGET_NITS;
        
        high_peak = max(source_peak, TARGET_NITS) / low_peak;
        YrYgYb /= low_peak;
    }

#ifdef HDR
    // HDR: tone mapping handled via PQ
#else
    // Tone mapping
    if (TONEMAP_TYPE < 0.5) {
        // No tone mapping
    } else if (TONEMAP_TYPE < 1.5) {
        // Reinhard tone mapping
        float Y_in = YrYgYb.r + YrYgYb.g + YrYgYb.b;
        float Y_out = Y_in / (1.0 + Y_in);
        YrYgYb *= Y_out / max(Y_in, EPS);
    } else if (TONEMAP_TYPE < 2.5) {
        // Reinhard extended
        float Y_in = YrYgYb.r + YrYgYb.g + YrYgYb.b;
        float Y_out = (Y_in * (1.0 + Y_in / (high_peak * high_peak))) / (1.0 + Y_in);
        YrYgYb *= Y_out / max(Y_in, EPS);
    } else if (TONEMAP_TYPE < 3.5) {
        // Uncharted 2 tone mapping
        float exposure_bias = 2.0;
        float Y_in = YrYgYb.r + YrYgYb.g + YrYgYb.b;
        float Y_out = uncharted2_tonemap(Y_in, exposure_bias);
        YrYgYb *= Y_out / max(Y_in, EPS);
    } else {
        // ACES approximation
        float Y_in = YrYgYb.r + YrYgYb.g + YrYgYb.b;
        float Y_out = (Y_in * (2.51 * Y_in + 0.03)) / (Y_in * (2.43 * Y_in + 0.59) + 0.14);
        YrYgYb *= Y_out / max(Y_in, EPS);
    }

    YrYgYb = clamp(YrYgYb, 0.0, 1.0);
#endif

    // Convert YrYgYb to XYZ using native colorimetry
    vec3 XYZ = YrYgYb_to_XYZ(YrYgYb, colorimetry);
    
    // Apply chromatic adaptation to XYZ directly (not to encoding matrix)
    if (CHROMATIC_ADAPTATION > 0.5 && COLOR_CONVERSION_BYPASS < 0.5) {
        if (CHROMATIC_ADAPTATION < 2.5) {
            // Linear Bradford or CAT16 (computed in vertex shader)
            XYZ = cat_transform * XYZ;
        } else {
            // Nonlinear Bradford adaptation (per-color operation with pre-computed params)
            XYZ = bradford_fast(XYZ, bradford_params);
        }
    }

    mat3 toRGB = XYZ_TO_COLOR_SPACE;

    // Early exit for full bypass
    if (COLOR_CONVERSION_BYPASS > 0.5) {
        FragColor = vec4(toRGB * XYZ, 1.0);
        return;
    }

    vec3 RGB;

    // Convert adapted XYZ to output color space
#ifdef SDR
        // Take advantage of intermediate for advanced compression
        if (GAMUT_COMPRESSION < 1.5) {
            // Handle later
        } else if (GAMUT_COMPRESSION < 2.5) {
            vec3 Luv = XYZ_to_CIE_LUV(XYZ);

            Luv.x *= luv_scale.x;
            Luv.yz *= luv_scale.y;
            XYZ = CIE_LUV_to_XYZ(Luv);
        } else {
            vec3 Ipt = XYZ_to_IPT(XYZ);

            Ipt.x *= ipt_scale.x;
            Ipt.yz *= ipt_scale.y;
            XYZ = IPT_to_XYZ(Ipt);
        }
#endif
        RGB = toRGB * XYZ;

    if (DEBUG_COLOR_DELTA > 0.5) {
        vec3 RGB_baseline = toRGB * XYZ;
        vec3 delta = abs(RGB - RGB_baseline);

        FragColor = vec4(max(delta, 0.0), 1.0);
        return;
    }

#ifdef SDR
    // Gamut mapping
    if (GAMUT_COMPRESSION < 0.5) {
        // No gamut compression
    } else if (GAMUT_COMPRESSION < 1.5) {
        RGB = reduce_luminance(RGB);
    } else {
        // Advanced gamut compression
        // Already applied earlier
    }
#endif

    // Debug: Visualize out-of-range colors with sinusoid modulation
    if (COLOR_DEBUG_OUT_OF_RANGE > 0.5) {
        RGB = zebra(RGB, 0.0, 1.0, vTexCoord, config.OutputSize.xy, config.FrameCount, 2.0);
    }

    vec3 color = RGB;

    // Safety clamp
    color = max(color, vec3(0.0));

    // Output linear color; encoding happens in a later stage.
    FragColor = vec4(color, 1.0);
}