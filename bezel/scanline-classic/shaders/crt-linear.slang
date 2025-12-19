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
// Output: Linear RGB signal [0.0, 1.0]
//
// Linearizes CRT display output using BT.1886 transfer function
// with user-configurable brightness and picture controls.

#include "common.inc"

#include "menus/parameters/user-common.inc"

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
} config;

#define USER_PICTURE config.USER_PICTURE
#define USER_BRIGHTNESS config.USER_BRIGHTNESS

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float bt1886_a;
layout(location = 2) out float bt1886_b;

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
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float bt1886_a;
layout(location = 2) in float bt1886_b;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Linearize input using BT.1886 transfer function
    vec3 color = bt1886_linear(texture(Source, vTexCoord).rgb, bt1886_a, bt1886_b);
    FragColor = vec4(color, 1.0);
}
