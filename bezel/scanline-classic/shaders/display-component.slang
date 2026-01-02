#version 450

/* Filename: display-component.slang

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

#pragma name DisplayComponent
#pragma format R16G16B16A16_SFLOAT


layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameSize;
    uint FrameCount;
    // Timing parameters for timebase computation
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
    float DISPLAY_COMPONENT_BYPASS;
    float YC_MODEL; // 0=YIQ, 1=YPbPr, 2=YUV, 3=YDbDr, 4=YCbCr
    float DISPLAY_COMPONENT_FILTER_BYPASS;
    float DISPLAY_BANDWIDTH_Y;
    float DISPLAY_BANDWIDTH_U;
    float DISPLAY_BANDWIDTH_V;
    float DISPLAY_CUTOFF_ATTEN_Y;
    float DISPLAY_CUTOFF_ATTEN_U;
    float DISPLAY_CUTOFF_ATTEN_V;
} config;


#pragma parameter DISPLAY_COMPONENT_HEADER " ==== Display Component Parameters ==== " 0.0 0.0 0.0 0.0
#pragma parameter DISPLAY_COMPONENT_BYPASS "Display component bypass" 0.0 0.0 1.0 1.0
#define DISPLAY_COMPONENT_BYPASS config.DISPLAY_COMPONENT_BYPASS
#pragma parameter V_FREQ_MODE "Vertical frequency mode (0=Auto, 1=NTSC, 2=PAL, 3=PAL-M, 4=Custom)" 1.0 0.0 4.0 1.0
#define V_FREQ_MODE config.V_FREQ_MODE
#pragma parameter V_FREQ "Custom vertical frequency (Hz)" 59.94 1.0 240.0 0.01
#define V_FREQ config.V_FREQ
#pragma parameter SHORTEN_ODD_FIELD_TIME "Shorten odd field time (0=Off, 1=On)" 0.0 0.0 1.0 1.0
#define SHORTEN_ODD_FIELD_TIME config.SHORTEN_ODD_FIELD_TIME
#pragma parameter SC_FREQ_MODE "Subcarrier frequency mode (0=Auto, 1=NTSC, 2=PAL, 3=Custom)" 1.0 0.0 3.0 1.0
#define SC_FREQ_MODE config.SC_FREQ_MODE
#pragma parameter SC_FREQ "Custom Subcarrier Frequency (MHz)" 3.579545 0.0 10.0 0.000001
#define SC_FREQ config.SC_FREQ
#pragma parameter PIXEL_CLOCK_MODE "Pixel clock mode (0=Auto, 1=NTSC, 2=PAL, 3=Divisor, 4=Custom)" 1.0 0.0 4.0 1.0
#define PIXEL_CLOCK_MODE config.PIXEL_CLOCK_MODE
#pragma parameter PIXEL_CLOCK "Pixel clock (MHz)" 21.477272 0.1 100.0 0.000001
#define PIXEL_CLOCK config.PIXEL_CLOCK
#pragma parameter H_FREQ_MODE "Horizontal frequency mode (0=Auto, 1=NTSC, 2=PAL, 3=Divisor, 4=Custom)" 0.0 0.0 4.0 1.0
#define H_FREQ_MODE config.H_FREQ_MODE
#pragma parameter H_FREQ "Custom horizontal frequency (kHz)" 15.734 1.0 100.0 0.001
#define H_FREQ config.H_FREQ
#pragma parameter H_BLANK_FUZZ "Horizontal blanking fuzz (cycles)" 0.0 0.0 20.0 0.1
#define H_BLANK_FUZZ config.H_BLANK_FUZZ
#pragma parameter YC_MODEL "YC color model (0=YIQ,1=YPbPr,2=YUV,3=YDbDr,4=YCbCr)" 1.0 0.0 4.0 1.0
#define YC_MODEL config.YC_MODEL
#pragma parameter DISPLAY_COMPONENT_FILTER_BYPASS "Display component filter bypass" 0.0 0.0 1.0 1.0
#define DISPLAY_COMPONENT_FILTER_BYPASS config.DISPLAY_COMPONENT_FILTER_BYPASS
#pragma parameter DISPLAY_BANDWIDTH_Y "Display Luma (Y) bandwidth (MHz)" 5.4 0.0 75.0 0.01
#pragma parameter DISPLAY_BANDWIDTH_U "Display Chroma (U) bandwidth (MHz)" 2.7 0.0 15.0 0.01
#pragma parameter DISPLAY_BANDWIDTH_V "Display Chroma (V) bandwidth (MHz)" 2.7 0.0 15.0 0.01
#pragma parameter DISPLAY_CUTOFF_ATTEN_Y "Display Y cutoff attenuation (dB)" 12.5 0.0 30.0 1.0
#pragma parameter DISPLAY_CUTOFF_ATTEN_U "Display U cutoff attenuation (dB)" 12.5 0.0 30.0 1.0
#pragma parameter DISPLAY_CUTOFF_ATTEN_V "Display V cutoff attenuation (dB)" 12.5 0.0 30.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec3 sigma;
layout(location = 2) out TimebaseConfig tb;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Precompute per-component sigmas (in texels) from MHz/dB specs.
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

    sigma.x = sigma_tb(tb, config.DISPLAY_BANDWIDTH_Y, config.DISPLAY_CUTOFF_ATTEN_Y);
    sigma.y = sigma_tb(tb, config.DISPLAY_BANDWIDTH_U, config.DISPLAY_CUTOFF_ATTEN_U);
    sigma.z = sigma_tb(tb, config.DISPLAY_BANDWIDTH_V, config.DISPLAY_CUTOFF_ATTEN_V);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in vec3 sigma;
layout(location = 2) in TimebaseConfig tb;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Helper: decode from selected luma-chroma model to RGB
vec3 decode_luma_chroma_to_rgb(vec3 yc, float model) {
    if (model < 0.5) {
        return YIQ_TO_RGB * yc;
    } else if (model < 1.5) {
        return YPbPr_TO_RGB * yc;
    } else if (model < 2.5) {
        return YUV_TO_RGB * yc;
    } else if (model < 3.5) {
        // YDbDr -> YUV -> RGB
        const float U_FROM_DB = 0.436 / 1.333;
        const float V_FROM_DR = -0.615 / 1.333;
        vec3 yuv = vec3(yc.r, yc.g * U_FROM_DB, yc.b * V_FROM_DR);
        return YUV_TO_RGB * yuv;
    } else {
        return YCbCr_TO_RGB * yc;
    }
}

void main()
{
    if (DISPLAY_COMPONENT_BYPASS > 0.5) {
        FragColor = texture(Source, vTexCoord);
        return;
    }

    // Filter bypass: decode center sample without Gaussian lobes
    if (DISPLAY_COMPONENT_FILTER_BYPASS > 0.5) {
        vec3 yc = texture(Source, vTexCoord).rgb;
        vec3 rgb = decode_luma_chroma_to_rgb(yc, YC_MODEL);
        FragColor = vec4(rgb, 1.0);
        return;
    }

    const float FILTER_THRESHOLD = 1.0 / 255.0;

    // Horizontal coordinate handling using nearest pixel-center addressing
    vec2 UV  = vTexCoord * config.OutputSize.xy;
    float baseIndex = floor(UV.x + 0.5);   // nearest pixel index
    float baseCenter = baseIndex + 0.5;    // pixel center position
    float Ax = UV.x - baseCenter;          // offset from center in [-0.5, 0.5]
    vec2 Tex = vec2(
        baseCenter * config.OutputSize.z,
        (floor(UV.y) + 0.5) * config.OutputSize.w);
    vec2 dx  = vec2(config.OutputSize.z, 0.0);

    // Accumulators and weights for Y, U/Db, V/Dr
    vec3 accum = vec3(0.0);
    vec3 wsum  = vec3(0.0);

    // Center sample
    vec3 yc_c = texture(Source, Tex).rgb;
    float wy = gaussian(Ax, sigma.x);
    float wu = gaussian(Ax, sigma.y);
    float wv = gaussian(Ax, sigma.z);
    accum += vec3(wy * yc_c.x, wu * yc_c.y, wv * yc_c.z);
    wsum  += vec3(wy, wu, wv);

    // Symmetric lobes
    for (int n = 1; n <= 32; ++n) {
        float nf = float(n);
        // Symmetric distances: right = n - Ax, left = n + Ax
        float wy_r = gaussian(nf - Ax, sigma.x);
        float wy_l = gaussian(nf + Ax, sigma.x);
        float wu_r = gaussian(nf - Ax, sigma.y);
        float wu_l = gaussian(nf + Ax, sigma.y);
        float wv_r = gaussian(nf - Ax, sigma.z);
        float wv_l = gaussian(nf + Ax, sigma.z);
        if (wy_r < FILTER_THRESHOLD && wy_l < FILTER_THRESHOLD &&
            wu_r < FILTER_THRESHOLD && wu_l < FILTER_THRESHOLD &&
            wv_r < FILTER_THRESHOLD && wv_l < FILTER_THRESHOLD)
            break;
        vec3 yc_r = texture(Source, Tex + nf * dx).rgb;
        vec3 yc_l = texture(Source, Tex - nf * dx).rgb;
        accum.x += wy_r * yc_r.x + wy_l * yc_l.x;
        accum.y += wu_r * yc_r.y + wu_l * yc_l.y;
        accum.z += wv_r * yc_r.z + wv_l * yc_l.z;
        wsum.x  += wy_r + wy_l;
        wsum.y  += wu_r + wu_l;
        wsum.z  += wv_r + wv_l;
    }

    // Normalize
    vec3 outyc = accum / max(wsum, vec3(EPS));
    vec3 pixel = decode_luma_chroma_to_rgb(outyc, YC_MODEL);
    FragColor = vec4(pixel, 1.0);
}