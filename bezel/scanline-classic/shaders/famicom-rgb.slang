#version 450

// Filename: famicom-rgb.slang
//
// Copyright (C) 2026 W. M. Martinez
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
// Decodes packed Famicom palette indices to RGB using 2C03 palette data.

#pragma name FamicomRGB
#pragma format R8G8B8A8_UNORM

#include "common.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameHSize;
    float OriginalFPS;
    uint FrameCount;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float V_FREQ_MODE;
    float V_FREQ;
    float H_BLANK_FUZZ;
    float SHORTEN_ODD_FIELD_TIME;
} config;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float h_scale;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    TimebaseConfig tb = compute_timebase(
        config.FrameCount,
        TexCoord,
        config.OriginalSize.xy,
        config.OutputSize.xy,
        config.FrameHSize.x,
        config.OriginalFPS,
        config.SC_FREQ_MODE,
        config.SC_FREQ,
        config.PIXEL_CLOCK,
        config.PIXEL_CLOCK_MODE,
        config.H_FREQ_MODE,
        config.H_FREQ,
        config.V_FREQ_MODE,
        config.V_FREQ,
        config.H_BLANK_FUZZ,
        config.SHORTEN_ODD_FIELD_TIME);

    compute_scale_factors(
        config.FrameHSize.x,
        config.OutputSize.x,
        config.OutputSize.y,
        tb.h_pixels,
        tb.v_lines_per_field,
        h_scale);
}

#pragma stage fragment

const ivec3 PALETTE_2C03[64] = ivec3[](
    ivec3(109, 109, 109), ivec3(0, 36, 146), ivec3(0, 0, 219), ivec3(109, 73, 219),
    ivec3(146, 0, 109), ivec3(182, 0, 109), ivec3(182, 36, 0), ivec3(146, 73, 0),
    ivec3(109, 73, 0), ivec3(36, 73, 0), ivec3(0, 109, 36), ivec3(0, 146, 0),
    ivec3(0, 73, 73), ivec3(0, 0, 0), ivec3(0, 0, 0), ivec3(0, 0, 0),

    ivec3(182, 182, 182), ivec3(0, 109, 219), ivec3(0, 73, 255), ivec3(146, 0, 255),
    ivec3(182, 0, 255), ivec3(255, 0, 146), ivec3(255, 0, 0), ivec3(219, 109, 0),
    ivec3(146, 109, 0), ivec3(36, 146, 0), ivec3(0, 146, 0), ivec3(0, 182, 109),
    ivec3(0, 146, 146), ivec3(0, 0, 0), ivec3(0, 0, 0), ivec3(0, 0, 0),

    ivec3(255, 255, 255), ivec3(109, 182, 255), ivec3(146, 146, 255), ivec3(219, 109, 255),
    ivec3(255, 0, 255), ivec3(255, 109, 255), ivec3(255, 146, 0), ivec3(255, 182, 0),
    ivec3(219, 219, 0), ivec3(109, 219, 0), ivec3(0, 255, 0), ivec3(73, 255, 219),
    ivec3(0, 255, 255), ivec3(0, 0, 0), ivec3(0, 0, 0), ivec3(0, 0, 0),

    ivec3(255, 255, 255), ivec3(182, 219, 255), ivec3(219, 182, 255), ivec3(255, 182, 255),
    ivec3(255, 146, 255), ivec3(255, 182, 182), ivec3(255, 219, 146), ivec3(255, 255, 73),
    ivec3(255, 255, 109), ivec3(182, 255, 73), ivec3(146, 255, 109), ivec3(73, 255, 219),
    ivec3(146, 219, 255), ivec3(0, 0, 0), ivec3(0, 0, 0), ivec3(0, 0, 0)
);

vec3 apply_emphasis_max(vec3 color, int emphasis)
{
    if ((emphasis & 0x1) != 0) {
        color.r = 1.0;
    }
    if ((emphasis & 0x2) != 0) {
        color.g = 1.0;
    }
    if ((emphasis & 0x4) != 0) {
        color.b = 1.0;
    }
    return color;
}

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float h_scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    float output_x = vTexCoord.x * config.OutputSize.x;
    float active_width = config.OriginalSize.x * h_scale;
    float active_left = (config.OutputSize.x - active_width) * 0.5;
    float active_right = active_left + active_width;
    if (output_x < active_left || output_x >= active_right) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3 packed = texture(Source, vTexCoord).rgb;
    int color = clamp(int(floor((packed.r * 15.0) + 0.5)), 0, 15);
    int level = clamp(int(floor((packed.g * 3.0) + 0.5)), 0, 3);
    int emphasis = clamp(int(floor((packed.b * 7.0) + 0.5)), 0, 7);

    int palette_index = level * 16 + color;
    vec3 rgb = vec3(PALETTE_2C03[palette_index]) / 255.0;
    rgb = apply_emphasis_max(rgb, emphasis);

    FragColor = vec4(rgb, 1.0);
}
