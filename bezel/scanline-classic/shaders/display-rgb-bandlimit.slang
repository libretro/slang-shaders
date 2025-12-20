#version 450

/* Filename: display-rgb-bandlimit.slang

   Copyright (C) 2025 W. M. Martinez

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

#include "common.inc"
#include "color.inc"
#include "bandlimit.inc"
#include "modulation.inc"

#include "menus/parameters/user-uncommon.inc"
#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/display-rgb.inc"

#pragma name DisplayRGBBandlimit
#pragma format R16G16B16A16_SFLOAT

#pragma parameter DISPLAY_RGB_AMP_BYPASS "Bypass display RGB amplifier" 0.0 0.0 1.0 1.0
#pragma parameter DISPLAY_RGB_FILTER_BYPASS "Bypass display RGB filter" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OriginalFPS;
    float V_FREQ_MODE;
    float V_FREQ;
    float SHORTEN_ODD_FIELD_TIME;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float H_BLANK_FUZZ;
    float DISPLAY_RGB_FILTER_BYPASS;
    float DISPLAY_RGB_AMP_BYPASS;
    float DISPLAY_BANDLIMIT_R;
    float DISPLAY_BANDLIMIT_G;
    float DISPLAY_BANDLIMIT_B;
    float DISPLAY_CUTOFF_ATTEN_R;
    float DISPLAY_CUTOFF_ATTEN_G;
    float DISPLAY_CUTOFF_ATTEN_B;
    float USER_BLUE_ONLY;
} config;

#define DISPLAY_RGB_FILTER_BYPASS config.DISPLAY_RGB_FILTER_BYPASS
#define DISPLAY_RGB_AMP_BYPASS config.DISPLAY_RGB_AMP_BYPASS

#define V_FREQ_MODE config.V_FREQ_MODE
#define V_FREQ config.V_FREQ
#define SHORTEN_ODD_FIELD_TIME config.SHORTEN_ODD_FIELD_TIME
#define SC_FREQ_MODE config.SC_FREQ_MODE
#define SC_FREQ config.SC_FREQ
#define PIXEL_CLOCK_MODE config.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK config.PIXEL_CLOCK
#define H_FREQ_MODE config.H_FREQ_MODE
#define H_FREQ config.H_FREQ
#define H_BLANK_FUZZ config.H_BLANK_FUZZ

#define DISPLAY_BANDLIMIT_R config.DISPLAY_BANDLIMIT_R
#define DISPLAY_BANDLIMIT_G config.DISPLAY_BANDLIMIT_G
#define DISPLAY_BANDLIMIT_B config.DISPLAY_BANDLIMIT_B

#define DISPLAY_CUTOFF_ATTEN_R config.DISPLAY_CUTOFF_ATTEN_R
#define DISPLAY_CUTOFF_ATTEN_G config.DISPLAY_CUTOFF_ATTEN_G
#define DISPLAY_CUTOFF_ATTEN_B config.DISPLAY_CUTOFF_ATTEN_B



#define USER_BLUE_ONLY config.USER_BLUE_ONLY

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    float DISPLAY_GAIN_R;
    float DISPLAY_GAIN_G;
    float DISPLAY_GAIN_B;
    float DISPLAY_BIAS_R;
    float DISPLAY_BIAS_G;
    float DISPLAY_BIAS_B;
} global;

#define DISPLAY_GAIN_R global.DISPLAY_GAIN_R
#define DISPLAY_GAIN_G global.DISPLAY_GAIN_G
#define DISPLAY_GAIN_B global.DISPLAY_GAIN_B

#define DISPLAY_BIAS_R global.DISPLAY_BIAS_R
#define DISPLAY_BIAS_G global.DISPLAY_BIAS_G
#define DISPLAY_BIAS_B global.DISPLAY_BIAS_B

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec3 sigma;
layout(location = 2) out vec3 gain;
layout(location = 3) out vec3 bias;
layout(location = 4) out TimebaseConfig tb;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    tb = compute_timebase(
        config.FrameCount,
        vTexCoord,
        config.OriginalSize.xy,
        config.OutputSize.xy,
        config.OriginalFPS,
        SC_FREQ_MODE,
        SC_FREQ,
        PIXEL_CLOCK,
        PIXEL_CLOCK_MODE,
        H_FREQ_MODE,
        H_FREQ,
        V_FREQ_MODE,
        V_FREQ,
        H_BLANK_FUZZ,
        SHORTEN_ODD_FIELD_TIME);

    sigma.x = sigma_tb(tb, DISPLAY_BANDLIMIT_R, DISPLAY_CUTOFF_ATTEN_R);
    sigma.y = sigma_tb(tb, DISPLAY_BANDLIMIT_G, DISPLAY_CUTOFF_ATTEN_G);
    sigma.z = sigma_tb(tb, DISPLAY_BANDLIMIT_B, DISPLAY_CUTOFF_ATTEN_B);

    // Amplifier
    gain = vec3(
        pow(10.0, DISPLAY_GAIN_R / 20.0),
        pow(10.0, DISPLAY_GAIN_G / 20.0),
        pow(10.0, DISPLAY_GAIN_B / 20.0));
    bias = vec3(
        DISPLAY_BIAS_R * 10e-3,
        DISPLAY_BIAS_G * 10e-3,
        DISPLAY_BIAS_B * 10e-3);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec3 sigma;
layout(location = 2) in vec3 gain;
layout(location = 3) in vec3 bias;
layout(location = 4) in TimebaseConfig tb;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec3 color;

    if (DISPLAY_RGB_FILTER_BYPASS < 0.5) {
        color = bandlimit_convolve_gaussian_x(vTexCoord, config.OutputSize, Source, sigma);
    } else {
        color = texture(Source, vTexCoord).rgb;
    }

    // RGB amplifier
    if (DISPLAY_RGB_AMP_BYPASS < 0.5) {
        color = gain * (color + bias);
    }

    // Apply blue-only filter
    color.r *= 1.0 - USER_BLUE_ONLY;
    color.g *= 1.0 - USER_BLUE_ONLY;

    FragColor = vec4(color, 1.0);
}
