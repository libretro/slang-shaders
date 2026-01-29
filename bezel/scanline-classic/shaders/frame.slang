#version 450

// Filename: frame.slang
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
// Frame scaling and zero-stuffing
// --------------------------------
// Maps input texture (active content) to full video frame dimensions,
// scales by integer multiples, and applies zero-stuffing (renders each
// scanline once with blanking gaps between).
//
// Includes visualization modes to see full frame and padding regions.

#include "common.inc"
#include "modulation.inc"

#include "menus/parameters/scanraster.inc"
#include "menus/parameters/sys-timing.inc"

#pragma name Frame
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

#define DOUBLE_REFRESH config.DOUBLE_REFRESH
#define SCANLINE_BLANK_WEIGHT config.SCANLINE_BLANK_WEIGHT

// Subframe support
#define CURRENT_SUBFRAME config.CurrentSubFrame
#define TOTAL_SUBFRAMES config.TotalSubFrames
#define HAS_SUBFRAMES (TOTAL_SUBFRAMES > 1u)

// Calculate effective double refresh state considering subframes
bool get_effective_double_refresh(float v_scale, float is_interlaced) {
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
layout(location = 1) out float h_scale;
layout(location = 2) out float v_scale;
layout(location = 3) out float full_pad_left;
layout(location = 4) out float full_pad_top;
layout(location = 5) out float active_left_scaled;
layout(location = 6) out float active_top_scaled;
layout(location = 7) out float full_width_int;
layout(location = 8) out float full_height_int;
layout(location = 9) out float is_interlaced;
layout(location = 10) out float field;
layout(location = 11) out float effective_double_refresh;
layout(location = 12) out float subframe_field_offset;
layout(location = 13) out float num_blanks;
layout(location = 14) out float is_odd_blanks;

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

    // Full video dimensions (with blanking) at actual pixel clock rate
    float full_width = geom.h_pixels;
    float full_height = (geom.is_interlaced < 0.5) ? geom.v_lines_per_field : geom.v_lines_per_frame;
    
    full_width_int = floor(full_width);
    full_height_int = floor(full_height);
    is_interlaced = geom.is_interlaced;
    field = geom.field;
    
    // Calculate integer scale factors for each dimension
    h_scale = max(floor(config.OutputSize.x / full_width), 1.0);
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
    
    // Scaled full video dimensions
    float scaled_full_width = full_width_int * h_scale;
    float scaled_full_height = full_height_int * v_scale;
    
    // Center the scaled full video within output
    full_pad_left = floor((config.OutputSize.x - scaled_full_width) * 0.5);
    full_pad_top = floor((config.OutputSize.y - scaled_full_height) * 0.5);
    
    // Calculate scaled active region position
    active_left_scaled = full_pad_left + floor((scaled_full_width - config.SourceSize.x * h_scale) * 0.5);
    active_top_scaled = full_pad_top + floor((scaled_full_height - config.SourceSize.y * v_scale) * 0.5);

    // Align to pixel grid boundaries to prevent misalignment with zero-stuffing
    // Ensures all scaled pixels fall on clean multiples of scale factors
    active_left_scaled = floor(active_left_scaled / h_scale) * h_scale;
    active_top_scaled = floor(active_top_scaled / v_scale) * v_scale;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float h_scale;
layout(location = 2) in float v_scale;
layout(location = 3) in float full_pad_left;
layout(location = 4) in float full_pad_top;
layout(location = 5) in float active_left_scaled;
layout(location = 6) in float active_top_scaled;
layout(location = 7) in float full_width_int;
layout(location = 8) in float full_height_int;
layout(location = 9) in float is_interlaced;
layout(location = 10) in float field;
layout(location = 11) in float effective_double_refresh;
layout(location = 12) in float subframe_field_offset;
layout(location = 13) in float num_blanks;
layout(location = 14) in float is_odd_blanks;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Sample active content with zero-stuffing applied
vec3 sample_active_content(float output_x, float output_y) {
    float scaled_active_x = output_x - active_left_scaled;
    float scaled_active_y = output_y - active_top_scaled;
    
    float original_x = floor(scaled_active_x / h_scale);
    float original_y = floor(scaled_active_y / v_scale);
    float v_scanline_offset = mod(scaled_active_y, v_scale);

    if (v_scanline_offset > v_scale / 2.0)
        original_y += 1.0;
    vec3 base = crt_linear(texture(Source, (vec2(original_x, original_y) + 0.5) / config.SourceSize.xy).rgb);
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

void main()
{
    float output_x = floor(vTexCoord.x * config.OutputSize.x);
    float output_y = floor(vTexCoord.y * config.OutputSize.y);
    
    // Calculate scaled full video dimensions
    float scaled_full_width = full_width_int * h_scale;
    float scaled_full_height = full_height_int * v_scale;
    
    // Boundaries of frame area in output space
    float frame_left = full_pad_left;
    float frame_right = full_pad_left + scaled_full_width;
    float frame_top = full_pad_top;
    float frame_bottom = full_pad_top + scaled_full_height;
    
    // Boundaries of active region in output space
    float active_right = active_left_scaled + config.SourceSize.x * h_scale;
    float active_bottom = active_top_scaled + config.SourceSize.y * v_scale;
    
    bool in_frame = (output_x >= frame_left && output_x < frame_right &&
                     output_y >= frame_top && output_y < frame_bottom);
    bool in_active = (output_x >= active_left_scaled && output_x < active_right &&
                      output_y >= active_top_scaled && output_y < active_bottom);
    
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
