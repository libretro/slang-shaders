/* Filename: color.h

   Copyright (C) 2023, 2025 W. M. Martinez

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

struct Colorimetry {
    vec2 red_xy; // Red primary (x, y)
    vec2 green_xy; // Green primary (x, y)
    vec2 blue_xy; // Blue primary (x, y)
    vec2 white_xy; // White point (x, y)
};

mat3 XYZ_TO_sRGB = mat3(
     3.2406255, -0.9689307,  0.0557101,
    -1.5372080,  1.8758561, -0.2040211,
    -0.4986286,  0.0415175,  1.0569959);

mat3 XYZ_TO_BT2020 = mat3(
     1.716650, -0.66668,   0.01764,
    -0.355671,  1.616481, -0.042771,
    -0.253366,  0.015769,  0.942103);

mat3 XYZ_TO_AdobeRGB = mat3(
     2.04159, -0.96924,  0.01344,
    -0.56501,  1.87597, -0.11836,
    -0.34473,  0.04156,  1.01517);

mat3 XYZ_TO_DCIP3 = mat3(
     2.493497, -0.829489,  0.035846,
    -0.931384,  1.762664, -0.076172,
    -0.402711,  0.023625,  0.956885);

// Precision is low to match with the low precision of equipment at
// the time
mat3 XYZ_TO_NTSC = mat3(
     1.910, -0.985,  0.058,
    -0.532,  2.000, -0.118,
    -0.288,  0.028,  0.897);

mat3 XYZ_TO_NTSC_J = mat3(
     3.3770, -1.1343,  0.0601,
    -1.4609,  1.9974, -0.1787,
    -0.5366,  0.05933, 0.7938);

mat3 XYZ_TO_EBU = mat3(
     3.0634, -0.9692,  0.0679,
    -1.3934,  1.8760, -0.2288,
    -0.4758,  0.0416,  1.0691);

mat3 XYZ_TO_SMPTE_C = mat3(
     3.5060, -1.069,   0.0563,
    -1.7398,  1.9778, -0.1970,
    -0.5441,  0.0351,  1.0499);

mat3 sRGB_TO_XYZ = mat3(
    0.4124, 0.2126, 0.0193,
    0.3576, 0.7152, 0.1192,
    0.1805, 0.0722, 0.9505);

mat3 NTSC_TO_XYZ = mat3(
    0.607, 0.299, 0.000,
    0.173, 0.586, 0.066,
    0.200, 0.115, 1.117);

mat3 NTSC_J_TO_XYZ = mat3(
    0.3965, 0.2246, 0.0205,
    0.3119, 0.6740, 0.1281,
    0.2447, 0.1014, 1.2640);

mat3 EBU_TO_XYZ = mat3(
    0.4306, 0.2220, 0.0202,
    0.3411, 0.7066, 0.1292,
    0.1785, 0.0714, 0.9393);

mat3 SMPTE_C_TO_XYZ = mat3(
    0.3935, 0.2124, 0.0187,
    0.3653, 0.7011, 0.1119,
    0.1912, 0.0866, 0.9584);

mat3 RGB_TO_YIQ = mat3(
    0.299,  0.5959,  0.2115,
    0.587, -0.2746, -0.5227,
    0.114, -0.3213,  0.3112);

mat3 YIQ_TO_RGB = mat3(
    1.0,     1.0,      1.0,
    0.956,  -0.272,   -1.106,
    0.621,  -0.647,    1.703);

mat3 RGB_TO_YPbPr = mat3(
    0.299, -0.168736,  0.5,
    0.587, -0.331264, -0.418688,
    0.114,  0.5,      -0.081312);

mat3 YPbPr_TO_RGB = mat3(
    1.0,    1.0,      1.0,
    0.0,   -0.344136, 1.772,
    1.402, -0.714136, 0.0);

#define RGB_TO_YUV RGB_TO_YPbPr
#define YUV_TO_RGB YPbPr_TO_RGB

mat3 RGB_TO_YCbCr = mat3(
    0.2126, -0.1146,  0.5,
    0.7152, -0.3854, -0.4542,
    0.0722,  0.5,    -0.0458);

mat3 YCbCr_TO_RGB = mat3(
    1.0,    1.0,      1.0,
    0.0,   -0.1873,   1.8556,
    1.5748, -0.4681,   0.0);
    

mat3 colorspace_rgb(const float colorspace)
{
    if (colorspace == 1.0)
        return XYZ_TO_sRGB;
    else if (colorspace == 2.0)
        return XYZ_TO_BT2020;
    else if (colorspace == 3.0)
        return XYZ_TO_DCIP3;
    else
        return XYZ_TO_AdobeRGB;
}

vec3 xyY_to_XYZ(const vec3 xyY)
{
    float x = xyY.x;
    float y = xyY.y;
    float Y = xyY.z;
    float z = 1.0 - x - y;

    return vec3(Y * x / y, Y, Y * z / y);
}

vec3 XYZ_to_CIE_LUV(vec3 XYZ) {
    const float Yn = 1.0;
    const float Un = (4.0 * 0.95047) / (0.95047 + 15.0 * Yn + 3.0 * 1.08883);
    const float Vn = (9.0 * Yn) / (0.95047 + 15.0 * Yn + 3.0 * 1.08883);

    float Y = XYZ.y / Yn;
    float L = (Y > 0.008856) ? (116.0 * pow(Y, 1.0 / 3.0) - 16.0) : (903.3 * Y);

    float denom = XYZ.x + 15.0 * XYZ.y + 3.0 * XYZ.z;
    float u = (denom > 0.0) ? (4.0 * XYZ.x) / denom : 0.0;
    float v = (denom > 0.0) ? (9.0 * XYZ.y) / denom : 0.0;

    float U = 13.0 * L * (u - Un);
    float V = 13.0 * L * (v - Vn);

    return vec3(L, U, V);
}

vec3 CIE_LUV_to_XYZ(vec3 LUV) {
    const float Yn = 1.0;
    const float Un = (4.0 * 0.95047) / (0.95047 + 15.0 * Yn + 3.0 * 1.08883);
    const float Vn = (9.0 * Yn) / (0.95047 + 15.0 * Yn + 3.0 * 1.08883);

    float L = LUV.x;
    float U = LUV.y;
    float V = LUV.z;

    float u = Un + U / (13.0 * L);
    float v = Vn + V / (13.0 * L);

    float Y = (L > 8.0) ? pow((L + 16.0) / 116.0, 3.0) : (L / 903.3);
    float X = Y * 9.0 * u / (4.0 * v);
    float Z = Y * (12.0 - 3.0 * u - 20.0 * v) / (4.0 * v);

    return vec3(X, Y, Z);
}

mat3 ParkerCCorrection = mat3(
     1.2903, -0.0036, 0.0317,
    -0.2703,  0.9515, 0.1980,
    -0.0199,  0.0521, 1.1663);

mat3 Parker9300Correction = mat3(
     1.5468, -0.0187, 0.0095,
    -0.1977,  0.8960, 0.2231,
    -0.3491,  0.1226, 1.2135);

mat3 get_RGB_to_XYZ(const vec3 red_XYZ, const vec3 green_XYZ, const vec3 blue_XYZ, const vec3 white_XYZ)
{
    mat3 primary_XYZ = mat3(red_XYZ, green_XYZ, blue_XYZ);
    vec3 S = inverse(primary_XYZ) * white_XYZ;
    mat3 RGB_to_XYZ = mat3(
        red_XYZ * S.x,
        green_XYZ * S.y,
        blue_XYZ * S.z
    );

    return RGB_to_XYZ;
}

// Linear variant of the Bradford chromatic adaptation transform
mat3 bradford_linear(vec3 wref_XYZ, vec3 wout_XYZ)
{
    const mat3 M = mat3(
         0.8951, -0.7502,  0.0389,
         0.2664,  1.7135, -0.0685,
        -0.1614,  0.0367,  1.0296);
    const mat3 M_inv = mat3(
        0.9869929, 0.4323053, -0.0085287,
        -0.1470543, 0.5183603, 0.0400428,
        0.1599627, 0.0492912, 0.9684867);

    vec3 wref_RGB = M * wref_XYZ;
    vec3 wout_RGB = M * wout_XYZ;
    mat3 M_adt = mat3(
        wout_RGB.r / wref_RGB.r, 0.0, 0.0,
        0.0, wout_RGB.g / wref_RGB.g, 0.0,
        0.0, 0.0, wout_RGB.b / wref_RGB.b);
    return M_inv * M_adt * M;
}

// Chromatic adaptation transform from Zhai et al. 2018
mat3 zhai2018_cat16(vec3 ref_XYZ, vec3 tgt_XYZ, float d)
{
    // CAT16 matrix
    const mat3 cat16_M = mat3(
        0.401288, -0.250268, -0.002079,
        0.650173, 1.204414, 0.048952,
        -0.051461, 0.045854, 0.953127);

    // Inverse CAT16 matrix
    const mat3 cat16_M_inv = mat3(
        1.8620678, 0.387526, -0.015841,
        -1.0112546, 0.621447, -0.034123,
        0.1491868, -0.008974, 1.049964);

    vec3 src_cone = cat16_M * ref_XYZ;
    vec3 tgt_cone = cat16_M * tgt_XYZ;

    mat3 D = mat3(
        d * tgt_cone.x / src_cone.x + 1.0 - d, 0.0, 0.0,
        0.0, d * tgt_cone.y / src_cone.y + 1.0 - d, 0.0,
        0.0, 0.0, d * tgt_cone.z / src_cone.z + 1.0 - d);

    return cat16_M_inv * D * cat16_M;
}

// Convert RGB to selected luma-chroma space.
// For YDbDr: RGB -> YUV -> scale (U,V) to (Db,Dr).
vec3 rgb_to_luma_chroma(vec3 rgb, float model)
{
    if (model < 0.5) { // YPbPr
        return RGB_TO_YPbPr * rgb;
    } else if (model < 1.5) { // YDbDr via YUV scale
        // Db = (1.333 / 0.436) * U ; Dr = (-1.333 / 0.615) * V
        const float K_DB_FROM_U = 1.333 / 0.436;  // ≈ 3.056880734
        const float K_DR_FROM_V = -1.333 / 0.615; // ≈ -2.168292683

        vec3 yuv = RGB_TO_YUV * rgb;

        return vec3(yuv.r, K_DB_FROM_U * yuv.g, K_DR_FROM_V * yuv.b);
    } else { // YCbCr
        return RGB_TO_YCbCr * rgb;
    }
}

// Helper: decode from selected luma-chroma model to RGB
vec3 decode_luma_chroma_to_rgb(vec3 yc, float model) {
    if (model < 0.5) {
        return YPbPr_TO_RGB * yc;
    } else if (model < 1.5) {
        // YDbDr -> YUV -> RGB
        const float U_FROM_DB = 0.436 / 1.333;
        const float V_FROM_DR = -0.615 / 1.333;
        vec3 yuv = vec3(yc.r, yc.g * U_FROM_DB, yc.b * V_FROM_DR);
        return YUV_TO_RGB * yuv;
    } else {
        return YCbCr_TO_RGB * yc;
    }
}