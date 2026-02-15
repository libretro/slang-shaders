#version 450

// Filename: framev.slang
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
// Vertical framing and zero-stuffing
// ----------------------------------
// Maps input texture to full frame height, scales by integer multiples,
// and applies zero-stuffing (renders each scanline once with blanking
// gaps between). Horizontal framing is expected to be applied earlier.
//
// Assumes linear color space

#include "common.inc"
#include "modulation.inc"

#include "menus/parameters/scanraster.inc"
#include "menus/parameters/sys-timing.inc"

#pragma name FrameV
#pragma format R16G16B16A16_SFLOAT

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

#define DOUBLE_REFRESH config.DOUBLE_REFRESH
#define SCANLINE_BLANK_WEIGHT config.SCANLINE_BLANK_WEIGHT

// Subframe support
#define CURRENT_SUBFRAME config.CurrentSubFrame
#define TOTAL_SUBFRAMES config.TotalSubFrames
#define HAS_SUBFRAMES (TOTAL_SUBFRAMES > 1u)

// Calculate effective double refresh state considering subframes
bool get_effective_double_refresh(float v_scale, float is_interlaced)
{
    return (DOUBLE_REFRESH > 0.5);
}

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float v_scale;
layout(location = 2) out float full_pad_top;
layout(location = 3) out float active_top_scaled;
layout(location = 4) out float full_height_int;
layout(location = 5) out float is_interlaced;
layout(location = 6) out float field;
layout(location = 7) out float effective_double_refresh;
layout(location = 8) out float subframe_field_offset;
layout(location = 9) out float num_blanks;
layout(location = 10) out float is_odd_blanks;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    // Compute only the frame geometry we need
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

    // Full video height (with blanking) at actual pixel clock rate
    float full_height = (geom.is_interlaced < 0.5) ? geom.v_lines_per_field : geom.v_lines_per_frame;

    full_height_int = floor(full_height);
    is_interlaced = geom.is_interlaced;
    field = geom.field;

    // Calculate integer vertical scale factor
    v_scale = max(floor(config.OutputSize.y / full_height), 1.0);

    // Determine effective double refresh state
    effective_double_refresh = get_effective_double_refresh(v_scale, is_interlaced) ? 1.0 : 0.0;

    // Calculate subframe field offset for interlaced content with subframes
    // When subframes are available, interlace parity switches per subframe rather than per frame
    subframe_field_offset = 0.0;
    if (is_interlaced > 0.5 && HAS_SUBFRAMES && effective_double_refresh > 0.5) {
        // Each subframe gets its own field parity
        subframe_field_offset = float(CURRENT_SUBFRAME);
    }

    // Precompute blanking parameters to avoid repeated calculations in fragment shader
    float effective_scale = (is_interlaced > 0.5)
        ? (effective_double_refresh > 0.5 ? v_scale : v_scale * 2.0)
        : v_scale;
    num_blanks = effective_scale - 1.0;
    is_odd_blanks = mod(num_blanks, 2.0) > 0.5 ? 1.0 : 0.0;

    // Scaled full video height
    float scaled_full_height = full_height_int * v_scale;

    // Center the scaled full video within output (vertical only)
    full_pad_top = floor((config.OutputSize.y - scaled_full_height) * 0.5);

    // Calculate scaled active region position (vertical only)
    active_top_scaled = full_pad_top + floor((scaled_full_height - config.SourceSize.y * v_scale) * 0.5);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float v_scale;
layout(location = 2) in float full_pad_top;
layout(location = 3) in float active_top_scaled;
layout(location = 4) in float full_height_int;
layout(location = 5) in float is_interlaced;
layout(location = 6) in float field;
layout(location = 7) in float effective_double_refresh;
layout(location = 8) in float subframe_field_offset;
layout(location = 9) in float num_blanks;
layout(location = 10) in float is_odd_blanks;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Sample active content with zero-stuffing applied
vec3 sample_active_content(float output_x, float output_y)
{
    float scaled_active_y = output_y - active_top_scaled;

    float original_x = floor(output_x);
    float original_y = floor(scaled_active_y / v_scale);
    float v_scanline_offset = mod(scaled_active_y, v_scale);

    if (v_scanline_offset > v_scale / 2.0)
        original_y += 1.0;

    vec3 base = texture(Source, (vec2(original_x, original_y) + 0.5) / config.SourceSize.xy).rgb;
    bool scaled_blank_line = v_scanline_offset >= 1.0;

    // Interlaced handling with parity-aware zero-stuffing
    if (is_interlaced > 0.5) {
        // Compute field parity with subframe offset
        float effective_field = field + subframe_field_offset;
        int field_parity = int(mod(effective_field, 2.0));
        int line_parity = int(mod(original_y, 2.0));
        bool parity_mismatch = line_parity != field_parity;

        if (effective_double_refresh > 0.5) {
            // Double refresh: both fields shown every frame (or subframe), only blank the scaled gaps
            if (!scaled_blank_line) return base;
        } else {
            // Single refresh: blank wrong field lines AND scaled gaps
            if (!parity_mismatch && !scaled_blank_line) return base;
        }

        // For interlaced: calculate effective blank position in output sequence
        // In single-refresh, parity mismatches treated as first blank (index 1)
        // In double-refresh, only scaled blanks are blanked
        float blank_index;
        if (effective_double_refresh > 0.5) {
            blank_index = floor(v_scanline_offset);
        } else {
            // Single refresh: parity mismatch is at blank index 1, scaled blanks follow
            blank_index = parity_mismatch && !scaled_blank_line ? 1.0 : floor(v_scanline_offset);
        }
        float blank_center = blank_index + 0.5;
        float blank_mix = SCANLINE_BLANK_WEIGHT / 100.0;
        if (num_blanks > 1.0) {
            // Define effective_scale before use in interlaced path
            float effective_scale = effective_double_refresh > 0.5 ? v_scale : v_scale * 2.0;
            float dist_current = blank_center - 0.5;
            float dist_next = (effective_scale + 0.5) - blank_center;
            float min_dist = min(dist_current, dist_next);
            float max_min_dist = effective_scale / 2.0;
            float weight_factor = min_dist / max_min_dist;

            // Compute sum of all triangular weight factors
            // Odd: sum_dists = (n+1)^2/4, Even: sum_dists = n(n+2)/4
            float sum_of_dists = is_odd_blanks > 0.5
                ? (num_blanks + 1.0) * (num_blanks + 1.0) / 4.0
                : num_blanks * (num_blanks + 2.0) / 4.0;
            float sum_weights = 2.0 * sum_of_dists / effective_scale;

            // Scale by num_blanks so more blanks = darker overall
            blank_mix *= weight_factor / sum_weights * num_blanks;
        }

        return mix(base, vec3(0.0), blank_mix);
    }

    // Progressive path with triangular distribution
    if (!scaled_blank_line)
        return base;

    float blank_mix = SCANLINE_BLANK_WEIGHT / 100.0;
    if (num_blanks > 1.0) {
        float blank_index = floor(v_scanline_offset);
        float blank_center = blank_index + 0.5;
        float dist_current = blank_center - 0.5;
        float dist_next = (v_scale + 0.5) - blank_center;
        float min_dist = min(dist_current, dist_next);
        float max_min_dist = v_scale / 2.0;
        float weight_factor = min_dist / max_min_dist;

        // Compute sum of all triangular weight factors
        // Odd: sum_dists = (n+1)^2/4, Even: sum_dists = n(n+2)/4
        float sum_of_dists = is_odd_blanks > 0.5
            ? (num_blanks + 1.0) * (num_blanks + 1.0) / 4.0
            : num_blanks * (num_blanks + 2.0) / 4.0;
        float sum_weights = 2.0 * sum_of_dists / v_scale;

        // Scale by num_blanks so more blanks = darker overall
        blank_mix *= weight_factor / sum_weights * num_blanks;
    }

    return mix(base, vec3(0.0), blank_mix);
}

// Average gain across the active region for the current frame.
float average_active_gain()
{
    float effective_scale = (is_interlaced > 0.5)
        ? (effective_double_refresh > 0.5 ? v_scale : v_scale * 2.0)
        : v_scale;
    float num_blanks_local = max(effective_scale - 1.0, 0.0);
    float base = SCANLINE_BLANK_WEIGHT / 100.0;
    float avg_blank_mix = (effective_scale > 0.0) ? base * (num_blanks_local / effective_scale) : 0.0;
    return clamp(1.0 - avg_blank_mix, 0.0, 1.0);
}

void main()
{
    float output_x = floor(vTexCoord.x * config.OutputSize.x);
    float output_y = floor(vTexCoord.y * config.OutputSize.y);

    // Calculate scaled full video height
    float scaled_full_height = full_height_int * v_scale;

    // Vertical boundaries of frame area in output space
    float frame_top = full_pad_top;
    float frame_bottom = full_pad_top + scaled_full_height;

    // Vertical boundaries of active region in output space
    float active_bottom = active_top_scaled + config.SourceSize.y * v_scale;

    bool in_source_x = (output_x >= 0.0 && output_x < config.SourceSize.x);
    bool in_frame_y = (output_y >= frame_top && output_y < frame_bottom);
    bool in_active_y = (output_y >= active_top_scaled && output_y < active_bottom);

    bool in_frame = in_source_x && in_frame_y;
    bool in_active = in_source_x && in_active_y;

    vec4 color_gain;

    if (in_active && FRAME_VIZ_ACTIVE > 0.5) {
        vec3 color = sample_active_content(output_x, output_y);
        color_gain = vec4(color, average_active_gain());
    } else if (in_frame && !in_active && FRAME_VIZ_BLANKING > 0.5) {
        color_gain = vec4(vec3(1.0, 1.0, 0.0) * 0.5, 0.0);
    } else if (!in_frame && FRAME_VIZ_PADDING > 0.5) {
        color_gain = vec4(vec3(1.0, 0.0, 1.0) * 0.5, 0.0);
    } else {
        color_gain = vec4(vec3(0.0), 0.0);
    }

    FragColor = color_gain;
}
