#version 450

// Filename: frameh.slang
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
// Horizontal framing
// -------------------
// Maps input texture (active content) to full frame width,
// scales by integer multiples, and applies horizontal padding.
//
// This pass does not perform vertical framing or zero-stuffing.

#include "common.inc"
#include "modulation.inc"

#include "menus/parameters/scanraster.inc"
#include "menus/parameters/sys-timing.inc"

#pragma name FrameH
#pragma format R8G8B8A8_UNORM

#pragma parameter FRAME_VIZ_ACTIVE "Show active content" 1.0 0.0 1.0 1.0
#pragma parameter FRAME_VIZ_BLANKING "Show frame blanking (yellow)" 0.0 0.0 1.0 1.0
#pragma parameter FRAME_VIZ_PADDING "Show padding (magenta)" 0.0 0.0 1.0 1.0

// Push constants
layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float OriginalFPS;
    uint CurrentSubFrame;
    uint TotalSubFrames;
    float FRAME_VIZ_ACTIVE;
    float FRAME_VIZ_BLANKING;
    float FRAME_VIZ_PADDING;
    float V_FREQ_MODE;
    float V_FREQ;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float H_BLANK_FUZZ;
    float DOUBLE_REFRESH;
    float SCANLINE_BLANK_WEIGHT;
} config;

#define FRAME_VIZ_ACTIVE config.FRAME_VIZ_ACTIVE
#define FRAME_VIZ_BLANKING config.FRAME_VIZ_BLANKING
#define FRAME_VIZ_PADDING config.FRAME_VIZ_PADDING
#define V_FREQ_MODE config.V_FREQ_MODE
#define V_FREQ config.V_FREQ
#define SC_FREQ_MODE config.SC_FREQ_MODE
#define SC_FREQ config.SC_FREQ
#define PIXEL_CLOCK_MODE config.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK config.PIXEL_CLOCK
#define H_FREQ_MODE config.H_FREQ_MODE
#define H_FREQ config.H_FREQ
#define H_BLANK_FUZZ config.H_BLANK_FUZZ

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float h_scale;
layout(location = 2) out float full_pad_left;
layout(location = 3) out float active_left_scaled;
layout(location = 4) out float full_width_int;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Compute only the horizontal frame geometry we need
    FrameGeometry geom = compute_frame_geometry(
        config.FrameCount,
        config.SourceSize.xy,
        config.OriginalFPS,
        SC_FREQ_MODE,
        SC_FREQ,
        PIXEL_CLOCK,
        PIXEL_CLOCK_MODE,
        H_FREQ_MODE,
        H_FREQ,
        V_FREQ_MODE,
        V_FREQ,
        H_BLANK_FUZZ);

    // Full video width (with blanking) at actual pixel clock rate
    float full_width = geom.h_pixels;

    full_width_int = floor(full_width);

    // Calculate integer horizontal scale factor
    h_scale = max(floor(config.OutputSize.x / full_width), 1.0);

    // Scaled full video width
    float scaled_full_width = full_width_int * h_scale;

    // Center the scaled full video within output (horizontal only)
    full_pad_left = floor((config.OutputSize.x - scaled_full_width) * 0.5);

    // Calculate scaled active region position (horizontal only)
    active_left_scaled = full_pad_left + floor((scaled_full_width - config.SourceSize.x * h_scale) * 0.5);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float h_scale;
layout(location = 2) in float full_pad_left;
layout(location = 3) in float active_left_scaled;
layout(location = 4) in float full_width_int;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

vec3 sample_active_content(float output_x, float output_y)
{
    float scaled_active_x = output_x - active_left_scaled;
    float original_x = floor(scaled_active_x / h_scale);
    float original_y = floor(output_y);

    vec2 texel = (vec2(original_x, original_y) + 0.5) / config.SourceSize.xy;
    return crt_linear(texture(Source, texel).rgb);
}

void main()
{
    float output_x = floor(vTexCoord.x * config.OutputSize.x);
    float output_y = floor(vTexCoord.y * config.OutputSize.y);

    // Calculate scaled full video width
    float scaled_full_width = full_width_int * h_scale;

    // Horizontal boundaries of frame area in output space
    float frame_left = full_pad_left;
    float frame_right = full_pad_left + scaled_full_width;

    // Horizontal boundaries of active region in output space
    float active_right = active_left_scaled + config.SourceSize.x * h_scale;

    bool in_source_y = (output_y >= 0.0 && output_y < config.SourceSize.y);
    bool in_frame_x = (output_x >= frame_left && output_x < frame_right);
    bool in_active_x = (output_x >= active_left_scaled && output_x < active_right);

    bool in_frame = in_frame_x && in_source_y;
    bool in_active = in_active_x && in_source_y;

    vec3 color;

    if (in_active && FRAME_VIZ_ACTIVE > 0.5) {
        color = sample_active_content(output_x, output_y);
    } else if (in_frame && !in_active && FRAME_VIZ_BLANKING > 0.5) {
        color = vec3(1.0, 1.0, 0.0) * 0.5;
    } else if (!in_frame && FRAME_VIZ_PADDING > 0.5) {
        color = vec3(1.0, 0.0, 1.0) * 0.5;
    } else {
        color = vec3(0.0);
    }

    FragColor = vec4(crt_gamma(color), 1.0);
}
