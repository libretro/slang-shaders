#version 450

// Filename: dac.slang
//
// Copyright (C) 2026 W. M. Martinez
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
// Digital-to-Analog Converter (DAC) stage
// ----------------------------------------
// Input: YC (Y in R, modulated C in G)
// Output: YC with bias/gain applied (float format)
//
// Applies system-level bias and gain adjustments to luma and chroma
// channels, simulating DAC-level signal conditioning. Also applies
// encoder setup pedestal to luma if enabled.

#include "common.inc"
#include "digital.inc"

#include "menus/parameters/digital-component.inc"
#include "menus/parameters/sys-encode.inc"

#pragma name DAC
#pragma format R16G16B16A16_SFLOAT

#pragma parameter DAC_BYPASS "Bypass DAC stage" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float DAC_BYPASS;
    float WORKING_BITS;
    float DAC_BITS;
    float DITHER;
    float ENCODER_SETUP;
    float VIDEO_MODE;
    float SYS_BIAS_Y;
    float SYS_BIAS_U;
    float SYS_BIAS_V;
    float SYS_GAIN_Y;
    float SYS_GAIN_U;
    float SYS_GAIN_V;
} config;

#define DAC_BYPASS config.DAC_BYPASS
#define WORKING_BITS config.WORKING_BITS
#define DAC_BITS config.DAC_BITS
#define DITHER config.DITHER
#define ENCODER_SETUP config.ENCODER_SETUP
#define VIDEO_MODE config.VIDEO_MODE
#define SYS_BIAS_Y config.SYS_BIAS_Y
#define SYS_BIAS_U config.SYS_BIAS_U
#define SYS_BIAS_V config.SYS_BIAS_V
#define SYS_GAIN_Y config.SYS_GAIN_Y
#define SYS_GAIN_U config.SYS_GAIN_U
#define SYS_GAIN_V config.SYS_GAIN_V

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

    // Convert dB to linear gain: gain = 10^(dB/20)
    float gain_y = pow(10.0, SYS_GAIN_Y / 20.0);
    float gain_u = pow(10.0, SYS_GAIN_U / 20.0);
    float gain_v = pow(10.0, SYS_GAIN_V / 20.0);
    
    gain = vec3(gain_y, gain_u, gain_v);

    // Convert IRE to voltage: bias = IRE * 10e-3
    float bias_y = SYS_BIAS_Y * 10e-3;
    float bias_u = SYS_BIAS_U * 10e-3;
    float bias_v = SYS_BIAS_V * 10e-3;
    
    bias = vec3(bias_y, bias_u, bias_v);
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

    if (DAC_BYPASS > 0.5) {
        FragColor = vec4(color, 1.0);
        return;
    }

    int bits = int(DAC_BITS + 0.5);
    int working_bits = int(WORKING_BITS + 0.5);

    if (VIDEO_MODE > 1.5) {
        // Component mode: adjust Pb/Pr separately
        vec3 ycbcr = color;

        // Apply dithering before quantization
        if (DITHER > 0.5) {
            vec2 screen_coord = vTexCoord.xy * config.OutputSize.xy;
            ycbcr = apply_dither(ycbcr, working_bits, bits, screen_coord, config.FrameCount);
        }

        // Quantize to output bit depth
        if (bits < 7) {
            ycbcr = quantize_6bit(ycbcr);
        } else if (bits < 9) {
            ycbcr = quantize_8bit(ycbcr);
        } else {
            ycbcr = quantize_10bit(ycbcr);
        }

        // Restore full-range PbPr from limited range
        vec3 ypbpr = unlimit_ycbcr(ycbcr, bits);

        // Apply bias and gain
        ypbpr = gain * (ypbpr + bias);

        FragColor = vec4(ypbpr, 1.0);
        return;
    }

    float y = color.r;
    float c = color.g;

    // Apply dithering before quantization
    if (DITHER > 0.5) {
        vec2 screen_coord = vTexCoord.xy * config.OutputSize.xy;
        y = apply_dither(y, working_bits, bits, screen_coord, config.FrameCount);
        c = apply_dither(c, working_bits, bits, screen_coord + vec2(0.5, 0.5), config.FrameCount);
    }

    // Quantize to output bit depth
    if (bits == 6) {
        y = quantize_6bit(y);
        c = quantize_6bit(c);
    } else if (bits == 8) {
        y = quantize_8bit(y);
        c = quantize_8bit(c);
    } else if (bits == 10){
        y = quantize_10bit(y);
        c = quantize_10bit(c);
    } else {
        y = quantize(y, bits);
        c = quantize(c, bits);
    }

    const float INV_SQRT2 = 0.70710678;

    c = (c - 0.5) / INV_SQRT2;  // Remove offset and restore gain

    // Apply encoder setup to luma if enabled
    if (ENCODER_SETUP > 0.5) {
        y = 0.925 * (y + 0.075);
    }

    // Apply bias and gain
    y = gain.x * (y + bias.x);
    c = gain.y * (c + bias.y);

    if (VIDEO_MODE < 0.5) {
        // Composite mode: sum chroma into luma
        y += c;
        c = 0.0;
    }

    FragColor = vec4(y, c, 0.0, 1.0);
}