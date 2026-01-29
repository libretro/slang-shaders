#version 450

// Filename: svideo-mod.slang
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
// S-Video modulation: RGB → Y/C (luma in R, chroma in G)
// --------------------------------------------------------
// Input: RGB voltage signal
// Output: Luma and chroma (R16G16_SFLOAT, R=luma, G=chroma)

#include "common.inc"
#include "color.inc"
#include "modulation.inc"
#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/sys-encode.inc"
#include "menus/parameters/sys-yc.inc"

#pragma name SysYC
#pragma format R16G16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameSize;
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
    float PAL;
    float YC_MODEL;
    float SYS_GAIN_Y;
    float SYS_GAIN_U;
    float SYS_GAIN_V;
    float SYS_BIAS_Y;
    float SYS_BIAS_U;
    float SYS_BIAS_V;
} config;

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
#define PAL config.PAL
#define YC_MODEL config.YC_MODEL
#define SYS_GAIN_Y config.SYS_GAIN_Y
#define SYS_GAIN_U config.SYS_GAIN_U
#define SYS_GAIN_V config.SYS_GAIN_V
#define SYS_BIAS_Y config.SYS_BIAS_Y
#define SYS_BIAS_U config.SYS_BIAS_U
#define SYS_BIAS_V config.SYS_BIAS_V

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    float ENCODER_SETUP;
} global;

#define ENCODER_SETUP global.ENCODER_SETUP

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec3 gain;
layout(location = 2) out vec3 bias;
layout(location = 3) out TimebaseConfig tb;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    tb = compute_timebase(
        config.FrameCount,
        vTexCoord,
        config.OriginalSize.xy,
        config.OutputSize.xy,
        config.FrameSize.xy,
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

    // Amplifier gains and biases
    gain = vec3(
        pow(10.0, SYS_GAIN_Y / 20.0),
        pow(10.0, SYS_GAIN_U / 20.0),
        pow(10.0, SYS_GAIN_V / 20.0));
    bias = vec3(
        SYS_BIAS_Y * 10e-3,
        SYS_BIAS_U * 10e-3,
        SYS_BIAS_V * 10e-3);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec3 gain;
layout(location = 2) in vec3 bias;
layout(location = 3) in TimebaseConfig tb;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec2 UV = vTexCoord * config.OutputSize.xy;
    float line = floor(UV.y) / tb.pixels_per_line;
    float baseIndex = floor(UV.x);
    float baseCenter = baseIndex + 0.5;
    vec2 Tex = vec2(
        baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);

    // Convert RGB to selected luma-chroma space
    vec3 rgb = texture(Source, Tex).rgb;
    vec3 yc = rgb_to_luma_chroma(rgb, YC_MODEL);
    
    // Apply gain and bias
    yc = gain * (yc + bias);
    
    // Modulate chroma onto subcarrier
    vec2 pal_phase = vec2(0.0, floor(mod(line, 2.0)) * PI * PAL);
    float t0 = line / tb.h_freq_hz + baseCenter * tb.pixel_time_px;
    float phase0 = compute_carrier_phase(t0, tb.sc_freq_hz, tb.field_phase);
    vec2 carrier0 = sincos_phase_raw(vec2(phase0) + pal_phase);
    float chroma0 = yc.g * carrier0.x + yc.b * carrier0.y;

    float y_gain = 1.0;
    float y_offset = 0.0;
    if (ENCODER_SETUP > 0.5) {
        y_gain = 0.925;
        y_offset = 0.075;
    }

    float luma = y_gain * (yc.r + y_offset);
    FragColor = vec4(luma, chroma0, 0.0, 1.0);
}
