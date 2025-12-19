#version 450

// Filename: sys-rgb-amp.slang
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
// System-level amplifier
// ------------------------
// Input: Voltage
// Output: Voltage
//
// Can be used to alter channel level, e.g. to compensate an emulator's
// output being too dark or too bright

#include "common.inc"

#pragma name Amplifier
#pragma format R16G16B16A16_SFLOAT

#include "menus/parameters/sys-rgb.inc"

#pragma parameter SYS_RGB_AMP_BYPASS "Bypass RGB Amplifier" 0 0 1 1

layout(push_constant) uniform Push
{
    float SYS_RGB_AMP_BYPASS;
    float SYS_BIAS_R;
    float SYS_BIAS_G;
    float SYS_BIAS_B;
    float SYS_GAIN_R;
    float SYS_GAIN_G;
    float SYS_GAIN_B;
} config;

#define SYS_RGB_AMP_BYPASS config.SYS_RGB_AMP_BYPASS

#define SYS_BIAS_R config.SYS_BIAS_R
#define SYS_BIAS_G config.SYS_BIAS_G
#define SYS_BIAS_B config.SYS_BIAS_B

#define SYS_GAIN_R config.SYS_GAIN_R
#define SYS_GAIN_G config.SYS_GAIN_G
#define SYS_GAIN_B config.SYS_GAIN_B

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec3 gain;
layout(location = 2) out vec3 bias;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;

   gain = vec3(
       pow(10.0, SYS_GAIN_R / 20.0),
       pow(10.0, SYS_GAIN_G / 20.0),
       pow(10.0, SYS_GAIN_B / 20.0));

   bias = vec3(
       SYS_BIAS_R * 10e-3,
       SYS_BIAS_G * 10e-3,
       SYS_BIAS_B * 10e-3);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec3 gain;
layout(location = 2) in vec3 bias;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec3 color = texture(Source, vTexCoord).rgb;

    if (SYS_RGB_AMP_BYPASS >= 0.5) {
        FragColor = vec4(color, 1.0);
        return;
    }

    color = gain * (color + bias);
    FragColor = vec4(color, 1.0);
}