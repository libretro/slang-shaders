#version 450

// Filename: crt-linear.slang
//
// Copyright (C) 2023 W. M. Martinez
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
// CRT Linear
// -----------
// Input: Normalized RGB signal [0.0, 1.0]
// Output: Linear RGB luminance (YrYgYb) signal [0.0, 10 000.0]
//
// Linearizes CRT display output using BT.1886 transfer function
// with user-configurable brightness and picture controls.

#include "common.inc"
#include "color.inc"

#include "menus/parameters/user-common.inc"
#include "menus/parameters/colorimetry.inc"

#pragma name CRTLinear
#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OriginalFPS;

    // User settings
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
    float COLORIMETRY_PRESET;
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

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float bt1886_a;
layout(location = 2) out float bt1886_b;
layout(location = 3) out vec3 luma_weights;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Precompute BT.1886 parameters for linearization
    const float gamma = 2.4;

    float black_level = 2.0 * USER_BRIGHTNESS / 100.0 - 1.0;
    float white_level = 2.0 * USER_PICTURE / 100.0 + black_level;
    bt1886_a = pow(white_level - black_level, gamma);
    bt1886_b = black_level / (white_level - black_level);

    mat3 RGB_to_XYZ;

    if (COLORIMETRY_PRESET < 0.5) {
        vec3 ref_XYZ = xyY_to_XYZ(vec3(W_X, W_Y, 1.0));
        vec3 red_XYZ = xyY_to_XYZ(vec3(R_X, R_Y, 1.0));
        vec3 green_XYZ = xyY_to_XYZ(vec3(G_X, G_Y, 1.0));
        vec3 blue_XYZ = xyY_to_XYZ(vec3(B_X, B_Y, 1.0));

        RGB_to_XYZ = get_RGB_to_XYZ(red_XYZ, green_XYZ, blue_XYZ, ref_XYZ);
    } else if (COLORIMETRY_PRESET < 1.5) {
        RGB_to_XYZ = SMPTE_C_TO_XYZ;
    } else if (COLORIMETRY_PRESET < 2.5) {
        RGB_to_XYZ = NTSC_J_TO_XYZ;
    } else if (COLORIMETRY_PRESET < 3.5) {
        RGB_to_XYZ = EBU_TO_XYZ;
    } else {
        RGB_to_XYZ = sRGB_TO_XYZ;
    }

    luma_weights = vec3(RGB_to_XYZ[0][1], RGB_to_XYZ[1][1], RGB_to_XYZ[2][1]);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float bt1886_a;
layout(location = 2) in float bt1886_b;
layout(location = 3) in vec3 luma_weights;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    const float TARGET_NITS = 100.0;
    
    // Linearize input using BT.1886 transfer function
    vec3 color = bt1886_linear(texture(Source, vTexCoord).rgb, bt1886_a, bt1886_b);

    // Multiply each component by the luminance weight to get absolute luminance
    color *= TARGET_NITS * luma_weights;

    FragColor = vec4(color, 1.0);
}
