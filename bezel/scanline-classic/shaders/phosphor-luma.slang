#version 450

/* Filename: phosphor-luma.slang

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

#pragma name PhosphorLuma
#pragma format R16G16B16A16_SFLOAT

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 PhosphorLumaFeedbackSize;
    float V_FREQ;
    float COLOR_MODE;
    float TO_GRAY_WEIGHT_R;
    float TO_GRAY_WEIGHT_G;
    float TO_GRAY_WEIGHT_B;
    float PHOSPHORESCENSE_A;
    float PHOSPHORESCENSE_B;
    float PHOSPHORESCENSE_C; 
    float PHOS_EXP_A;
    float PHOS_EXP_B;
    float PHOS_EXP_C;
    float PHOS_TRAP_A;
    float PHOS_TRAP_B;
    float PHOS_TRAP_C;
    float PHOSPHOR_LUMA_BYPASS;
} config;

#pragma parameter PHOSPHOR_HEADER " ==== Phosphor Luma Parameters ==== " 0.0 0.0 0.0 0.0

#pragma parameter PHOSPHOR_LUMA_BYPASS "Phosphor luma bypass" 0.0 0.0 1.0 1.0
#define PHOSPHOR_LUMA_BYPASS config.PHOSPHOR_LUMA_BYPASS

#pragma parameter V_FREQ "Vertical frequency (Hz)" 59.94 1.0 240.0 0.01
#define V_FREQ config.V_FREQ

#pragma parameter COLOR_MODE "Chromaticity mode" 3.0 1.0 3.0 1.0
#define COLOR_MODE config.COLOR_MODE

#pragma parameter TO_GRAY_WEIGHT_R "Red channel to gray weight" 0.2124 0.0 1.0 0.01
#define TO_GRAY_WEIGHT_R config.TO_GRAY_WEIGHT_R
#pragma parameter TO_GRAY_WEIGHT_G "Green channel to gray weight" 0.7011 0.0 1.0 0.01
#define TO_GRAY_WEIGHT_G config.TO_GRAY_WEIGHT_G
#pragma parameter TO_GRAY_WEIGHT_B "Blue channel to gray weight" 0.0866 0.0 1.0 0.01
#define TO_GRAY_WEIGHT_B config.TO_GRAY_WEIGHT_B

#pragma parameter PHOSPHORESCENSE_A "Phosphorescense decay A (1/s)" 9.0 0.0 100.0 1.0
#define PHOSPHORESCENSE_A config.PHOSPHORESCENSE_A
#pragma parameter PHOSPHORESCENSE_B "Phosphorescense decay B (1/s)" 9.0 0.0 100.0 1.0
#define PHOSPHORESCENSE_B config.PHOSPHORESCENSE_B
#pragma parameter PHOSPHORESCENSE_C "Phosphorescense decay C (1/s)" 9.0 0.0 100.0 1.0
#define PHOSPHORESCENSE_C config.PHOSPHORESCENSE_C

#pragma parameter PHOS_EXP_A "Decay rate A (EE)" 5.0 0.0 10.0 1.0
#define PHOS_EXP_A config.PHOS_EXP_A
#pragma parameter PHOS_EXP_B "Decay rate B (EE)" 5.0 0.0 10.0 1.0
#define PHOS_EXP_B config.PHOS_EXP_B
#pragma parameter PHOS_EXP_C "Decay rate C (EE)" 5.0 0.0 10.0 1.0
#define PHOS_EXP_C config.PHOS_EXP_C

#pragma parameter PHOS_TRAP_A "Decay escape A (order)" 1.25 0.5 2.0 0.01
#define PHOS_TRAP_A config.PHOS_TRAP_A
#pragma parameter PHOS_TRAP_B "Decay escape B (order)" 1.25 0.5 2.0 0.01
#define PHOS_TRAP_B config.PHOS_TRAP_B
#pragma parameter PHOS_TRAP_C "Decay escape C (order)" 1.25 0.5 2.0 0.01
#define PHOS_TRAP_C config.PHOS_TRAP_C

vec3 blend(vec3 col1, vec3 col2)
{
    return vec3(max(col1.r, col2.r), max(col1.g, col2.g), max(col1.b, col2.b));
}

vec3 phosphor_inv_pow3(vec3 col, vec3 gamma, vec3 n)
{
    vec3 mask = step(vec3(EPS), col);
    vec3 safe_col = max(col, vec3(EPS));
    vec3 y = pow(gamma / V_FREQ + pow(1.0 / safe_col, 1.0 / n), -n);
    
    return mask * min(y, col - EPS);
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
layout(set = 0, binding = 2) uniform sampler2D PhosphorLumaFeedback;

void main()
{
    vec2 uv = floor(config.PhosphorLumaFeedbackSize.xy * vTexCoord);
    uv = (uv + 0.5) * config.PhosphorLumaFeedbackSize.zw;
    
    vec3 rgb = crt_linear(texture(Source, uv).rgb);
    
    // Early exit for full bypass
    if (PHOSPHOR_LUMA_BYPASS >= 1.0) {
        FragColor = vec4(rgb, 1.0);
        return;
    }
    
    vec3 Yrgb;
    vec3 Wrgb = vec3(
        TO_GRAY_WEIGHT_R,
        TO_GRAY_WEIGHT_G,
        TO_GRAY_WEIGHT_B);
    
    if (COLOR_MODE < 2.0) {
        Yrgb = vec3(dot(Wrgb, rgb), 0.0, 0.0);
    } else if (COLOR_MODE < 3.0) {
        float gray = dot(Wrgb, rgb);
        Yrgb = vec3(gray, gray, 0.0);
    } else {
        Yrgb = rgb;
    }

    // Sample feedback
    vec3 Yrgb1 = texture(PhosphorLumaFeedback, uv).rgb;
    
    // Precompute gamma values
    float gamma_a = PHOSPHORESCENSE_A * pow(10.0, PHOS_EXP_A);
    float gamma_b = PHOSPHORESCENSE_B * pow(10.0, PHOS_EXP_B);
    float gamma_c = PHOSPHORESCENSE_C * pow(10.0, PHOS_EXP_C);

    Yrgb1 = phosphor_inv_pow3(Yrgb1,
        vec3(gamma_a, gamma_b, gamma_c),
        vec3(PHOS_TRAP_A, PHOS_TRAP_B, PHOS_TRAP_C));
    
    Yrgb = blend(Yrgb, Yrgb1);
    
    FragColor = vec4(Yrgb, 1.0);
}
