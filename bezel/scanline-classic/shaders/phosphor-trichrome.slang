#version 450

// Filename: phosphor-trichrome.slang
//
// Copyright (C) 2023, 2025 W. M. Martinez
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
// Trichrome phosphor simulation
// ------------------------------------------------
// Input: Linear RGB signal
// Output: Linear RGB signal

#include "common.inc"

#include "menus/parameters/phosphor.inc"

#pragma name Phosphor3
#pragma format R16G16B16A16_SFLOAT

#pragma parameter PHOSPHOR_BYPASS "Phosphor trichrome bypass" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    float OriginalFPS;
    float PHOSPHOR_BYPASS;
    float PHOSPHOR_MANTISSA_R;
    float PHOSPHOR_MANTISSA_G;
    float PHOSPHOR_MANTISSA_B;
    float PHOSPHOR_EXPONENT_R;
    float PHOSPHOR_EXPONENT_G;
    float PHOSPHOR_EXPONENT_B;
    float PHOSPHOR_HOLD_R;
    float PHOSPHOR_HOLD_G;
    float PHOSPHOR_HOLD_B;
} config;

#define PHOSPHOR_BYPASS config.PHOSPHOR_BYPASS

#define PHOSPHOR_MANTISSA_R config.PHOSPHOR_MANTISSA_R
#define PHOSPHOR_MANTISSA_G config.PHOSPHOR_MANTISSA_G
#define PHOSPHOR_MANTISSA_B config.PHOSPHOR_MANTISSA_B

#define PHOSPHOR_EXPONENT_R config.PHOSPHOR_EXPONENT_R
#define PHOSPHOR_EXPONENT_G config.PHOSPHOR_EXPONENT_G
#define PHOSPHOR_EXPONENT_B config.PHOSPHOR_EXPONENT_B

#define PHOSPHOR_HOLD_R config.PHOSPHOR_HOLD_R
#define PHOSPHOR_HOLD_G config.PHOSPHOR_HOLD_G
#define PHOSPHOR_HOLD_B config.PHOSPHOR_HOLD_B

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

vec3 phosphor_inv_pow3(vec3 col, vec3 gamma, vec3 n)
{
    // Handle dark/off pixels early to avoid pow() on ~0
    vec3 mask = step(vec3(EPS), col);
    vec3 safe = max(col, vec3(EPS));
    // Compute decay: y_{k+1} = (y_k^{-1/n} + gamma)^{-n}
    vec3 y = pow(pow(safe, -1.0 / n) + gamma, -n);
    return mask * min(y, col - EPS);  // Prevent positive feedback
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
layout(set = 0, binding = 2) uniform sampler2D Phosphor3Feedback;

void main()
{
    vec2 Tex = vTexCoord;

    vec3 color = texture(Source, Tex).rgb;

    // Early exit for full bypass
    if (PHOSPHOR_BYPASS >= 1.0) {
        FragColor = vec4(color, 1.0);
        return;
    }

    vec3 n = vec3(1.0 / PHOSPHOR_HOLD_R,
                  1.0 / PHOSPHOR_HOLD_G,
                  1.0 / PHOSPHOR_HOLD_B);

    vec3 tau = vec3(
        PHOSPHOR_MANTISSA_R * pow(10.0, PHOSPHOR_EXPONENT_R),
        PHOSPHOR_MANTISSA_G * pow(10.0, PHOSPHOR_EXPONENT_G),
        PHOSPHOR_MANTISSA_B * pow(10.0, PHOSPHOR_EXPONENT_B));

    vec3 gamma_c = (pow(vec3(10.0), 1.0 / n) - 1.0) / tau;

    vec3 gamma_frame = gamma_c / config.OriginalFPS;

    // Point-sample normalization so that the average of the first two point samples is 0.5.
    // A_point = 1 / (1 + (1 + r)^(-n)), with r = gamma_frame and per-channel n.
    //vec3 A_point = 1.0 / (vec3(1.0) + pow(vec3(1.0) + gamma_frame, -n));

    // Scale current input by A_point; feedback carries the tail.
    //color *= A_point;

    vec3 color1 = texture(Phosphor3Feedback, Tex).rgb;
    color1 = phosphor_inv_pow3(color1, gamma_frame, n);
    color = max(color, color1);  // More stable 'saturation' method

    FragColor = vec4(color, 1.0);
}
