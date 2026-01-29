#version 450

// Filename: digital-chroma-subsample.slang
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
// Digital YCbCr Chroma Subsampling stage
// ------------------------------------
// Input: Full-resolution YCbCr video
// Output: YCbCr with optionally subsampled chroma (4:4:4, 4:2:2, or 4:2:0)
//
// Performs chroma subsampling by sampling luma from source RGB
// and applying nearest-neighbor chroma sampling.

#include "common.inc"
#include "color.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/digital-component.inc"
#include "menus/parameters/digital-chroma-subsample.inc"

#pragma name DigitalChromaSubsample
#pragma format A2B10G10R10_UNORM_PACK32

#pragma parameter CHROMA_SUBSAMPLE_BYPASS "Bypass chroma subsampling" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameSize;
    uint FrameCount;
    float OriginalFPS;

    float CHROMA_SUBSAMPLE_BYPASS;
    float YCBCR_MODEL;
    float CHROMA_SUBSAMPLE;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float V_FREQ_MODE;
    float V_FREQ;
    float H_BLANK_FUZZ;
} config;

#define CHROMA_SUBSAMPLE_BYPASS config.CHROMA_SUBSAMPLE_BYPASS
#define YCBCR_MODEL config.YCBCR_MODEL
#define CHROMA_SUBSAMPLE config.CHROMA_SUBSAMPLE

#define SC_FREQ_MODE config.SC_FREQ_MODE
#define SC_FREQ config.SC_FREQ
#define PIXEL_CLOCK_MODE config.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK config.PIXEL_CLOCK
#define H_FREQ_MODE config.H_FREQ_MODE
#define H_FREQ config.H_FREQ
#define V_FREQ_MODE config.V_FREQ_MODE
#define V_FREQ config.V_FREQ
#define H_BLANK_FUZZ config.H_BLANK_FUZZ

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float pixels_per_line;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Compute pixels_per_line from timing parameters
    FrameGeometry geom = compute_frame_geometry(
        config.FrameCount,
        config.OriginalSize.xy,
        config.OriginalFPS,
        SC_FREQ_MODE, SC_FREQ,
        PIXEL_CLOCK, PIXEL_CLOCK_MODE,
        H_FREQ_MODE, H_FREQ,
        V_FREQ_MODE, V_FREQ,
        H_BLANK_FUZZ);

    float h_scale;
    float vpixelscale;
    compute_scale_factors(
        config.FrameSize.x, config.FrameSize.y,
        config.OutputSize.x, config.OutputSize.y,
        geom.h_pixels, geom.v_lines_per_field,
        h_scale, vpixelscale);

    pixels_per_line = vpixelscale;
}

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float pixels_per_line;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Bypass check
    if (CHROMA_SUBSAMPLE_BYPASS > 0.5) {
        FragColor = texture(Source, vTexCoord);
        return;
    }

    // Determine subsampling mode
    float mode = CHROMA_SUBSAMPLE;
    
    // Auto mode: choose based on color model
    if (mode < 0.5) {
        if (YCBCR_MODEL < 0.5) {
            mode = 2.0; // 4:2:2 for SMPTE/EBU
        } else {
            mode = 3.0; // 4:2:0 for Rec. 709
        }
    }

    // Sample full-resolution YCbCr
    vec3 yc_full = texture(Source, vTexCoord).rgb;
    float y = yc_full.r; // Y component passes through unchanged
    
    // If mode 4:4:4, no chroma subsampling needed
    if (mode < 1.5) {
        FragColor = vec4(yc_full, 1.0);
        return;
    }

    // For 4:2:2 or 4:2:0: subsample chroma (G, B components)
    vec2 output_pixel = vTexCoord * config.OutputSize.xy;
    
    // Sample from neighboring pixels for blending
    vec2 chroma_pixel_0 = output_pixel;
    vec2 chroma_pixel_1 = output_pixel + vec2(1.0, 0.0);
    
    // For 4:2:0, also include vertical neighbors
    if (mode > 2.5) {
        vec2 chroma_pixel_2 = output_pixel + vec2(0.0, 1.0 * pixels_per_line);
        vec2 chroma_pixel_3 = output_pixel + vec2(1.0, 1.0 * pixels_per_line);
    }
    
    // Average chroma samples from neighboring pixels
    vec2 chroma = vec2(0.0);
    int sample_count = 0;
    
    for (int dx = 0; dx < 2; dx++) {
        vec2 chroma_pixel = output_pixel + vec2(float(dx), 0.0);
        
        int y_end = (mode > 2.5) ? 2 : 1;
        for (int dy = 0; dy < y_end; dy++) {
            vec2 sample_pos = chroma_pixel + vec2(0.0, float(dy) * pixels_per_line);
            vec2 sample_coord = sample_pos * config.OutputSize.zw;
            chroma += texture(Source, sample_coord).gb;
            sample_count++;
        }
    }
    
    chroma /= float(sample_count);
    
    FragColor = vec4(y, chroma.x, chroma.y, 1.0);
}
