#version 450

/* Filename: phosphor-chroma.slang

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

#include "common.h"
#include "color.h"

#pragma name PhosphorChroma
#pragma format R16G16B16A16_SFLOAT

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    float CHROMA_A_X;
    float CHROMA_A_Y;
    float CHROMA_B_X;
    float CHROMA_B_Y;
    float CHROMA_C_X;
    float CHROMA_C_Y;
    float CHROMA_A_WEIGHT;
    float CHROMA_B_WEIGHT;
    float CHROMA_C_WEIGHT;
    float SCALE_W;
    float COLOR_SPACE;
    float PHOSPHOR_CHROMA_BYPASS;
} config;

#pragma parameter PHOSPHOR_CHROMA_HEADER " ==== Phosphor Chroma Parameters ==== " 0.0 0.0 0.0 0.0

#pragma parameter PHOSPHOR_CHROMA_BYPASS "Phosphor chroma bypass" 0.0 0.0 1.0 1.0
#define PHOSPHOR_CHROMA_BYPASS config.PHOSPHOR_CHROMA_BYPASS

#pragma parameter CHROMA_A_X "Chromaticity A x" 0.630 0.0 1.0 0.001
#define CHROMA_A_X config.CHROMA_A_X
#pragma parameter CHROMA_A_Y "Chromaticity A y" 0.340 0.0 1.0 0.001
#define CHROMA_A_Y config.CHROMA_A_Y

#pragma parameter CHROMA_B_X "Chromaticity B x" 0.310 0.0 1.0 0.001
#define CHROMA_B_X config.CHROMA_B_X
#pragma parameter CHROMA_B_Y "Chromaticity B y" 0.595 0.0 1.0 0.001
#define CHROMA_B_Y config.CHROMA_B_Y

#pragma parameter CHROMA_C_X "Chromaticity C x" 0.155 0.0 1.0 0.001
#define CHROMA_C_X config.CHROMA_C_X
#pragma parameter CHROMA_C_Y "Chromaticity C y" 0.070 0.0 1.0 0.001
#define CHROMA_C_Y config.CHROMA_C_Y

#pragma parameter CHROMA_A_WEIGHT "Chromaticity A luminance weight" 0.2124 0.0 1.0 0.01
#define CHROMA_A_WEIGHT config.CHROMA_A_WEIGHT
#pragma parameter CHROMA_B_WEIGHT "Chromaticity B luminance weight" 0.7011 0.0 1.0 0.01
#define CHROMA_B_WEIGHT config.CHROMA_B_WEIGHT
#pragma parameter CHROMA_C_WEIGHT "Chromaticity C luminance weight" 0.0866 0.0 1.0 0.01
#define CHROMA_C_WEIGHT config.CHROMA_C_WEIGHT

#pragma parameter SCALE_W "Scale white point" 0.0 0.0 1.0 1.0
#define SCALE_W config.SCALE_W
#pragma parameter COLOR_SPACE "Output color space" 1.0 1.0 4.0 1.0
#define COLOR_SPACE config.COLOR_SPACE

vec3 Yrgb_to_RGB(mat3 toRGB, vec3 W, vec3 Yrgb)
{
    mat3 xyYrgb = mat3(CHROMA_A_X, CHROMA_A_Y, Yrgb.r,
                       CHROMA_B_X, CHROMA_B_Y, Yrgb.g,
                       CHROMA_C_X, CHROMA_C_Y, Yrgb.b);
    mat3 XYZrgb = mat3(xyY_to_XYZ(xyYrgb[0]),
                       xyY_to_XYZ(xyYrgb[1]),
                       xyY_to_XYZ(xyYrgb[2]));
    mat3 RGBrgb = mat3(toRGB * XYZrgb[0],
                       toRGB * XYZrgb[1],
                       toRGB * XYZrgb[2]);
    return vec3(dot(W, vec3(RGBrgb[0].r, RGBrgb[1].r, RGBrgb[2].r)),
                dot(W, vec3(RGBrgb[0].g, RGBrgb[1].g, RGBrgb[2].g)),
                dot(W, vec3(RGBrgb[0].b, RGBrgb[1].b, RGBrgb[2].b)));
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;

void main()
{
    vec3 Yrgb = texture(Source, vTexCoord).rgb;
    
    // Early exit for full bypass
    if (PHOSPHOR_CHROMA_BYPASS >= 1.0) {
        FragColor = vec4(clamp(Yrgb, 0.0, 1.0), 1.0);
        return;
    }
    
    mat3 toRGB = colorspace_rgb(COLOR_SPACE);
    vec3 W = vec3(
		CHROMA_A_WEIGHT,
		CHROMA_B_WEIGHT,
		CHROMA_C_WEIGHT);
    vec3 RGB = Yrgb_to_RGB(toRGB, W, Yrgb);
    
    if (SCALE_W > 0.0) {
        vec3 white = Yrgb_to_RGB(toRGB, W, WHITE);
        float G = 1.0 / max(max(white.r, white.g), white.b);
        RGB *= G;
    }
    
    RGB = clamp(RGB, 0.0, 1.0);
    FragColor = vec4(RGB, 1.0);
}
