#version 450

// Filename: digital-component.slang
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
// Digital RGB to YC Component stage
// -------------------------------
// Input: Gamma-corrected RGB
// Output: YCbCr (rec. 601 or rec. 709) or other luma-chroma space
//
// Encodes RGB into a chosen luma-chroma color space, and optionally
// performs chroma subsampling.  The result is also interpolated based
// on the ratio of output size to source size (to the nearest integer
// scale).
//
// By default, 4:2:2 subsampling is used for rec. 601 and 4:2:0 for rec. 709.

#include "common.inc"
#include "color.inc"
#include "digital.inc"

#include "menus/parameters/digital-component.inc"

#pragma name DigitalComponent
#pragma format A2B10G10R10_UNORM_PACK32

#pragma parameter DIGITAL_COMPONENT_BYPASS "Bypass system component stage" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;

    float WORKING_BITS;
    float YCBCR_MODEL;
    float DIGITAL_COMPONENT_BYPASS;
} config;

#define DIGITAL_COMPONENT_BYPASS config.DIGITAL_COMPONENT_BYPASS

#define YCBCR_MODEL config.YCBCR_MODEL
#define WORKING_BITS config.WORKING_BITS

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

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
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Full stage bypass: pass through RGB
    if (DIGITAL_COMPONENT_BYPASS > 0.5) {
        FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
        return;
    }

    // Sample input and convert to luma-chroma space
    vec3 rgb = texture(Source, vTexCoord).rgb;
    float model = YCBCR_MODEL > 0.5 ? 0.0 : 2.0;
    vec3 ycbcr = rgb_to_luma_chroma(rgb, model);

    // Quantize to working bit depth
    int bits = int(WORKING_BITS + 0.5);

    // Limit to legal ranges
    ycbcr = limit_ycbcr(ycbcr, bits);

    // Quantize to working bit depth (6, 8, or 10 bits)
    if (bits == 6) {
        ycbcr = quantize_6bit(ycbcr);
    } else if (bits == 8) {
        ycbcr = quantize_8bit(ycbcr);
    } else if (bits == 10) {
        ycbcr = quantize_10bit(ycbcr);
    } else {
        ycbcr = quantize(ycbcr, bits);
    }
    
    FragColor = vec4(ycbcr, 1.0);
}