// Filename: color-sdr.slang
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
// Color converter base functions, to be used with #include

#include "common.inc"
#include "color.inc"
#include "tools/zebra.inc"

#include "menus/parameters/output-tonemap.inc"
#include "menus/parameters/user-common.inc"
#include "menus/parameters/colorimetry.inc"
#include "menus/parameters/output-color.inc"

#pragma parameter COLOR_CONVERSION_BYPASS "Bypass color correction" 0.0 0.0 1.0 1.0
#pragma parameter DEBUG_COLOR_DELTA "Show color correction deltas" 0.0 0.0 1.0 1.0
#pragma parameter COLOR_DEBUG_OUT_OF_RANGE "Debug out-of-range colors" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OutputSize;
    uint FrameCount;
    float USER_PICTURE;
    float USER_BRIGHTNESS;
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
    float COLOR_CONVERSION_BYPASS;
    float COLORIMETRY_PRESET;
    float TONEMAP_TYPE;
    float DEBUG_COLOR_DELTA;
    float COLOR_DEBUG_OUT_OF_RANGE;
} config;

#define USER_PICTURE config.USER_PICTURE
#define USER_BRIGHTNESS config.USER_BRIGHTNESS
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

#define TONEMAP_TYPE config.TONEMAP_TYPE
#define COLOR_CONVERSION_BYPASS config.COLOR_CONVERSION_BYPASS
#define DEBUG_COLOR_DELTA config.DEBUG_COLOR_DELTA
#define COLOR_DEBUG_OUT_OF_RANGE config.COLOR_DEBUG_OUT_OF_RANGE

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

// -- Color space conversion functions -- //

// -- Perceptual color transform functions -- //
// Linear methods are in color.inc

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

// -- Tone mapping functions -- //

// Reinhard tone mapping operator (basic version)
vec3 reinhard_basic(vec3 color)
{
    return color / (1.0 + color);
}

// Reinhard tone mapping operator (extended version)
vec3 reinhard_extended(vec3 color, float y, float w)
{
    float y_adj = y * (1.0 + y / (w * w)) / (1.0 + y);

    return color * y_adj / y;
}

// ACES tone mapping operator (estimate)
vec3 aces_tone_map(vec3 color)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;

    color *= 0.8;
    vec3 mapped = (color * (a * color + b)) / (color * (c * color + d) + e);
    return clamp(mapped, 0.0, 1.0);
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
#ifdef WIDE_COLOR
layout(location = 1) out mat3 RGB_to_XYZ;
layout(location = 4) out mat3 XYZ_to_RGB;
layout(location = 7) out Colorimetry colorimetry;
#endif
#ifdef SDR
layout(location = 1) out vec2 luv_scale;
layout(location = 2) out mat3 RGB_to_XYZ;
layout(location = 5) out mat3 XYZ_to_RGB;
layout(location = 8) out Colorimetry colorimetry;
#endif

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    vec3 ref_XYZ;
    vec3 white_XYZ;
    vec3 red_XYZ;
    vec3 green_XYZ;
    vec3 blue_XYZ;

    // Set up colorimetry
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

        RGB_to_XYZ = get_RGB_to_XYZ(red_XYZ, green_XYZ, blue_XYZ, ref_XYZ);
        XYZ_to_RGB = inverse(RGB_to_XYZ);
    } else if (COLORIMETRY_PRESET < 1.5) {
        // Rec. 601
        colorimetry = Colorimetry(
            vec2(0.630, 0.340),
            vec2(0.310, 0.595),
            vec2(0.155, 0.070),
            vec2(0.3127, 0.3290));
        RGB_to_XYZ = SMPTE_C_TO_XYZ;
        XYZ_to_RGB = XYZ_TO_SMPTE_C;
    } else if (COLORIMETRY_PRESET < 2.5) {
        // Japanese phosphors, D93
        colorimetry = Colorimetry(
            vec2(0.618, 0.350),
            vec2(0.280, 0.605),
            vec2(0.152, 0.063),
            vec2(0.2832, 0.2971));
        RGB_to_XYZ = NTSC_J_TO_XYZ;
        XYZ_to_RGB = XYZ_TO_NTSC_J;
    } else if (COLORIMETRY_PRESET < 3.5) {
        // EBU Tech 3213
        colorimetry = Colorimetry(
            vec2(0.640, 0.330),
            vec2(0.290, 0.600),
            vec2(0.150, 0.060),
            vec2(0.3127, 0.3290));
        RGB_to_XYZ = EBU_TO_XYZ;
        XYZ_to_RGB = XYZ_TO_EBU;
    } else {
        // Rec. 709
        colorimetry = Colorimetry(
            vec2(0.640, 0.330),
            vec2(0.300, 0.600),
            vec2(0.150, 0.060),
            vec2(0.3127, 0.3290));
        RGB_to_XYZ = sRGB_TO_XYZ;
        XYZ_to_RGB = XYZ_TO_sRGB;
    }

    ref_XYZ = RGB_to_XYZ * WHITE;
    const vec3 D65_XYZ = vec3(0.95047, 1.0, 1.08883);

    if (CHROMATIC_ADAPTATION < 0.5) {
        // No adaptation, so pass through RGB_to_XYZ
        white_XYZ = RGB_to_XYZ * WHITE;
        red_XYZ = RGB_to_XYZ * RED;
        green_XYZ = RGB_to_XYZ * GREEN;
        blue_XYZ = RGB_to_XYZ * INDIGO;
    } else if (CHROMATIC_ADAPTATION < 1.5) {
        // Linear Bradford adaptation
        RGB_to_XYZ = bradford_linear(ref_XYZ, D65_XYZ) * RGB_to_XYZ;
        white_XYZ = RGB_to_XYZ * WHITE;
        red_XYZ = RGB_to_XYZ * RED;
        green_XYZ = RGB_to_XYZ * GREEN;
        blue_XYZ = RGB_to_XYZ * INDIGO;
    } else if (CHROMATIC_ADAPTATION < 2.5) {
        // Zhai et al. 2018 CAT16 adaptation
        RGB_to_XYZ = zhai2018_cat16(ref_XYZ, D65_XYZ, ADAPTATION_LEVEL) * RGB_to_XYZ;
        white_XYZ = RGB_to_XYZ * WHITE;
        red_XYZ = RGB_to_XYZ * RED;
        green_XYZ = RGB_to_XYZ * GREEN;
        blue_XYZ = RGB_to_XYZ * INDIGO;
    } else {
        // Bradford adaptation; needs more complex handling
        white_XYZ = RGB_to_XYZ * WHITE;
        red_XYZ = RGB_to_XYZ * RED;
        green_XYZ = RGB_to_XYZ * GREEN;
        blue_XYZ = RGB_to_XYZ * INDIGO;
        white_XYZ = bradford(white_XYZ, ref_XYZ);
        red_XYZ = bradford(red_XYZ, ref_XYZ);
        green_XYZ = bradford(green_XYZ, ref_XYZ);
        blue_XYZ = bradford(blue_XYZ, ref_XYZ);
    }

#ifdef SDR
    // Precompute Luv scale factors for advanced gamut compression
    luv_scale = vec2(0.0);
    
    if (GAMUT_COMPRESSION > 2.5) {
        vec3 white_out = XYZ_TO_COLOR_SPACE * white_XYZ;
        vec3 red_out = XYZ_TO_COLOR_SPACE * red_XYZ;
        vec3 green_out = XYZ_TO_COLOR_SPACE * green_XYZ;
        vec3 blue_out = XYZ_TO_COLOR_SPACE * blue_XYZ;

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
    }
#endif
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
#ifdef WIDE_COLOR
layout(location = 1) in mat3 RGB_to_XYZ;
layout(location = 4) in mat3 XYZ_to_RGB;
layout(location = 7) in Colorimetry colorimetry;
#endif
#ifdef SDR
layout(location = 1) in vec2 luv_scale;
layout(location = 2) in mat3 RGB_to_XYZ;
layout(location = 5) in mat3 XYZ_to_RGB;
layout(location = 8) in Colorimetry colorimetry;
#endif
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;

void main()
{
    vec3 Yrgb = texture(Source, vTexCoord).rgb;

    float black_level = max(2.0 * USER_BRIGHTNESS / 100.0 - 1.0, 0.0);
    float white_level = 2.0 * USER_PICTURE / 100.0 + black_level;
    
    // Early exit for full bypass
    if (COLOR_CONVERSION_BYPASS >= 1.0) {
        // Inverse power law
        FragColor = vec4(crt_gamma(clamp(Yrgb, 0.0, 1.0)), 1.0);
        return;
    }

    // Tone mapping
    if (TONEMAP_TYPE < 0.5) {
        // No tone mapping
    } else if (TONEMAP_TYPE < 1.5) {
        Yrgb = reinhard_basic(Yrgb);
    } else if (TONEMAP_TYPE < 2.5) {
        // Luminance
        float y = dot(Yrgb, vec3(RGB_to_XYZ[0][1], RGB_to_XYZ[1][1], RGB_to_XYZ[2][1]));

        Yrgb = reinhard_extended(Yrgb, y, white_level);
    } else {
        Yrgb = aces_tone_map(Yrgb);
    }

    // Clamp to native gamut RGB space
    Yrgb = clamp(Yrgb, 0.0, 1.0);

    mat3 toRGB = XYZ_TO_COLOR_SPACE;
    vec3 RGB;

    if (CHROMATIC_ADAPTATION < 2.5) {
        // Linear, convert directly from conversion matrix
        vec3 XYZ = RGB_to_XYZ * Yrgb;
#ifdef SDR
        // Take advantage of intermediate for advanced compression
        if (GAMUT_COMPRESSION < 1.5) {
            // Handle later
        } else if (GAMUT_COMPRESSION < 2.5) {
            vec3 Luv = XYZ_to_CIE_LUV(XYZ);

            RGB = toRGB * XYZ;
            Luv.x *= scale_luminance_cieluv(RGB, Luv, toRGB);
            Luv.yz *= scale_chroma_cieluv(RGB, Luv, toRGB);

            XYZ = CIE_LUV_to_XYZ(Luv);
        } else if (GAMUT_COMPRESSION < 3.5) {
            vec3 Luv = XYZ_to_CIE_LUV(XYZ);

            Luv.x *= luv_scale.x;
            Luv.yz *= luv_scale.y;
            XYZ = CIE_LUV_to_XYZ(Luv);
        }
#endif
        RGB = toRGB * XYZ;
    } else {
        // Bradford adaptation requires special handling
        vec3 ref_XYZ = RGB_to_XYZ * WHITE;
        vec3 Yrgb_XYZ = RGB_to_XYZ * Yrgb;
        vec3 adapted_XYZ = bradford(Yrgb_XYZ, ref_XYZ);
        RGB = toRGB * adapted_XYZ;

#ifdef SDR
        if (GAMUT_COMPRESSION < 1.5) {
            // Handle later
        } else if (GAMUT_COMPRESSION < 2.5) {
            vec3 Luv = XYZ_to_CIE_LUV(adapted_XYZ);

            Luv.x *= scale_luminance_cieluv(RGB, Luv, toRGB);
            Luv.yz *= scale_chroma_cieluv(RGB, Luv, toRGB);

            RGB = toRGB * CIE_LUV_to_XYZ(Luv);
        } else if (GAMUT_COMPRESSION < 3.5) {
            vec3 Luv = XYZ_to_CIE_LUV(adapted_XYZ);

            Luv.x *= luv_scale.x;
            Luv.yz *= luv_scale.y;
            RGB = toRGB * CIE_LUV_to_XYZ(Luv);
        }
#endif
    }

    if (DEBUG_COLOR_DELTA > 0.5) {
        vec3 delta = abs(RGB - Yrgb);

        // Inverse power law
        FragColor = vec4(crt_gamma(clamp(delta, 0.0, 1.0)), 1.0);
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
    color = clamp(color, 0.0, 1.0);
    
    // Inverse power law
    FragColor = vec4(crt_gamma(color), 1.0);
}
