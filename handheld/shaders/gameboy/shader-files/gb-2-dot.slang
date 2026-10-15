#version 450

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.5                          //
//                                                                       //
// Copyright (C) 2013 Harlequin : unknown92835@gmail.com                 //
// Copyright (C) 2024-2026 Matt Akins			                         //
//                                                                       //
// 10/30/26 - v1.5                                                       //
//   • Seven passes; color, latency and matching run at native size      //
//   • Brightness matching computed once per cell, not per pixel         //
//   • Smooth shadow movement between pixels                             //
//   • Grid shadow no longer leaves a gap at edges                       //
//   • Faster shadow sampling with a single filtered read                //
//   • Restores v1.3 performance with v1.4 improvements                  //
//                                                                       //
// 10/5/26 - v1.4				                                         //
//   • Improved visual consistency across different output resolutions.  //
//   • Consistent pixel alpha between fullscreen and integer mode.       //
//   • Better edge light banding fix.								     //
//                                                                       //
// 9/13/26 - v1.3                                                        //
//   • Fixed sizing and pass references when stacking presets            //
//                                                                       //
// 6/2/26 - v1.2				                                         //
//   • Added motion-based shadows               					     //
//   • Fixed edge light banding											 //
//                                                                       //
// 10/25/25 - v1.1                                        				 //
//   • Fixed fullscreen mode right and bottom border bug                 //
//   • Improved brightness compensation for fullscreen pixel parameters  //
//                                                                       //
// 9/30/25 - v1.0                                         				 //
//   • Fullscreen mode scales dot matrix effect to any screen size       //
//   • Swap between display modes (full / max integer / scale factor)    //
//   • Built-in palette presets while maintaining image palette support  //
//   • Drop shadow ON / OFF toggle                                       //
//   • Simple vs perceptual pixel brightness calculation modes           //
//   • Performance optimizations (vertex pre-calc, early-exit)           //
//   • Parameter reorganization for ease of use                          //
//   • Fixed issue with artifacts sometimes appearing in border          //
//                                                                       //
// 2/6/24 - Modified to support color output                			 //
//                                                                       //
// This program is free software: you can redistribute it and/or modify  //
// it under the terms of the GNU General Public License as published by  //
// the Free Software Foundation, either version 3 of the License, or     //
// (at your option) any later version.                                   //
//                                                                       //
// This program is distributed in the hope that it will be useful,       //
// but WITHOUT ANY WARRANTY; without even the implied warranty of        //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         //
// GNU General Public License for more details.                          //
//                                                                       //
// You should have received a copy of the GNU General Public License     //
// along with this program.  If not, see <http://www.gnu.org/licenses/>. //
//                                                                       //
/////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////
 // Core dot matrix generation                                          //
/////////////////////////////////////////////////////////////////////////

#include "gb-params.inc"
#include "gb-shared.inc"

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	float color_toggle;
	float pixel_size;
	float fullscreen_match_pixel_size;
	float pixel_softness;
	float sharpening_amount;
	float integer_mode;
	float video_scale;
	float baseline_alpha;
	float grey_balance;
	float response_time;
	float brightness_mode;
	float sharp_mode;
	float pixel_shape;
	float palette;
	float auto_soften;
	float alpha_reference_scale;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   float blending_mode;
   float adjacent_texel_alpha_blending;
} global;

  /////////////////////////////////////////////////////////////////////////
 // Vertex shader                                                       //
/////////////////////////////////////////////////////////////////////////

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 4) out vec2 tx_coord;
layout(location = 5) flat out vec2 tx_to_px;
layout(location = 6) flat out vec2 dot_size_in_px;
// OPTIMIZATION: Frame-constant values calculated once in vertex shader
layout(location = 8) flat out float video_scale_factor;
layout(location = 9) flat out vec2 scale_bounds;
layout(location = 10) flat out float aa_compensation_factor;  // Pixel alpha normalization factor
layout(location = 11) flat out float effective_softness;      // Adaptive softness (moiré reduction)

  /////////////////////////////////////////////////////////////////////////
 // Vertex definitions                                                  //
/////////////////////////////////////////////////////////////////////////

void main()
{
    // Pre-calculate frame-constant values once in vertex shader
    float effective_pixel_size = registers.pixel_size;
    if (registers.integer_mode > 0.5) {
        // Integer scaling mode calculations moved to vertex shader
        if (registers.integer_mode > 1.5) {
            video_scale_factor = registers.video_scale;
        } else {
            video_scale_factor = floor(registers.OutputSize.y * registers.OriginalSize.w);
        }
        vec2 scaled_video_out = (registers.OriginalSize.xy * vec2(video_scale_factor));
        scale_bounds = scaled_video_out / registers.OutputSize.xy;

        // Standard setup for integer mode
        gl_Position = global.MVP * Position;
        vTexCoord = biased_texcoord(TexCoord, registers.OutputSize.xy);

        // Set unused outputs for non-integer mode
        tx_coord = vec2(0.0);
        tx_to_px = vec2(0.0);
        dot_size_in_px = vec2(0.0);
    } else {
        // Non-integer scaling mode (smooth anti-aliased)
        video_scale_factor = 1.0; // Not used in non-integer mode
        scale_bounds = vec2(1.0); // Full screen

        gl_Position = global.MVP * Position;
        vec2 fullscreen_tex_coord = TexCoord;
        vTexCoord = fullscreen_tex_coord;

        // Calculate scaling parameters for geometric dot rendering
        tx_coord = fullscreen_tex_coord * registers.OriginalSize.xy;
        tx_to_px = registers.OutputSize.xy / registers.OriginalSize.xy;

        effective_pixel_size = get_effective_pixel_size(
            tx_to_px,
            registers.pixel_size,
            registers.fullscreen_match_pixel_size
        );

        // Game Boy dot size in output pixels
        dot_size_in_px = tx_to_px * effective_pixel_size;

        // Set unused outputs for integer mode
    }

    // Compute scale-aware softness for uneven fullscreen scales
    effective_softness = registers.pixel_softness;
    if (registers.integer_mode < 0.5)
        effective_softness = get_effective_pixel_softness(
            tx_to_px,
            registers.pixel_softness,
            registers.auto_soften
        );

    aa_compensation_factor = 1.0;

    // Match fullscreen AA coverage to the selected pixel alpha intensity.
    if (registers.integer_mode < 0.5) {
        float reference_coverage = integer_post_blend_coverage(
            registers.alpha_reference_scale,
            global.blending_mode,
            global.adjacent_texel_alpha_blending
        );
        float current_coverage = sample_scale_average_coverage(
            tx_to_px,
            registers.OutputSize.xy,
            registers.OriginalSize.xy,
            effective_pixel_size,
            effective_softness,
            registers.sharpening_amount,
            registers.pixel_shape,
            registers.sharp_mode
        );
        aa_compensation_factor = alpha_normalization_factor(
            reference_coverage,
            current_coverage
        );
    } else if (registers.integer_mode > 0.5) {
        float reference_scale = registers.alpha_reference_scale;
        float reference_coverage = integer_post_blend_coverage(
            reference_scale,
            global.blending_mode,
            global.adjacent_texel_alpha_blending
        );
        float current_coverage = integer_post_blend_coverage(
            video_scale_factor,
            global.blending_mode,
            global.adjacent_texel_alpha_blending
        );
        aa_compensation_factor = alpha_normalization_factor(
            reference_coverage,
            current_coverage
        );
    }

}

  /////////////////////////////////////////////////////////////////////////
 // Fragment shader                                                     //
/////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 4) in vec2 tx_coord;
layout(location = 5) flat in vec2 tx_to_px;
layout(location = 6) flat in vec2 dot_size_in_px;
layout(location = 8) flat in float video_scale_factor;
layout(location = 9) flat in vec2 scale_bounds;
layout(location = 10) flat in float aa_compensation_factor;
layout(location = 11) flat in float effective_softness;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D GameBoyOpacity;

  /////////////////////////////////////////////////////////////////////////
 // Fragment definitions                                                //
/////////////////////////////////////////////////////////////////////////

void main()
{
    // Coordinate transformation simplified using pre-calculated values
    vec2 final_tex_coord = vTexCoord;

    if (registers.integer_mode > 0.5) {
        // Check if we're outside the scaled Game Boy area using pre-calculated bounds
        vec2 centered_coord = abs(vTexCoord - 0.5);
        if (centered_coord.x > (scale_bounds.x * 0.5) ||
            centered_coord.y > (scale_bounds.y * 0.5)) {
            FragColor = vec4(0.0, 0.0, 0.0, 0.0);
            return;
        }

        // OPTIMIZATION: Use pre-calculated scale_bounds instead of recalculating
        final_tex_coord = (vTexCoord - 0.5) / scale_bounds + 0.5;
    }

    // Read prepared color, dot opacity, and grayscale word.
    vec4 opacity_source = texture(GameBoyOpacity, final_tex_coord);
    float packed_color = opacity_source.r;
    vec3 foreground_source = vec3(floor(packed_color / 65536.0),
        mod(floor(packed_color / 256.0), 256.0), mod(packed_color, 256.0)) / 255.0;

    float is_on_dot = 0.0;

    if (registers.integer_mode > 0.5) {
        // Integer mode dot detection
        vec2 cell_index;
        vec2 cell_frac = modf(final_tex_coord * registers.OriginalSize.xy,
                              cell_index);
        is_on_dot = hard_dot_mask(
            cell_index,
            cell_frac,
            vec2(video_scale_factor)
        );
    } else {
        // Non-integer scaling mode - use geometric intersection for accuracy
        vec2 tx_coord_i;
        const vec2 tx_coord_f = modf(tx_coord, tx_coord_i);

        // Calculate pixel rectangle in output space
            vec2 pixel_center = (tx_coord_f - 0.5) * tx_to_px;
            vec4 pixel_rect = vec4(pixel_center - tx_to_px * 0.5, pixel_center + tx_to_px * 0.5);

            // Create Game Boy dot rectangle (dot_size_in_px calculated in vertex shader)
            vec4 dot_rect = vec4(-dot_size_in_px * 0.5, dot_size_in_px * 0.5);

            // RECTANGULAR METHOD: Calculate 1D line segment intersections
            float x_coverage = intersect_line_segment(pixel_rect.x, pixel_rect.z, dot_rect.x, dot_rect.z) / tx_to_px.x;
            float y_coverage = intersect_line_segment(pixel_rect.y, pixel_rect.w, dot_rect.y, dot_rect.w) / tx_to_px.y;

            // Linear coverage (no sharpening)
            float rect_linear = x_coverage * y_coverage;

            // Apply sharpening to X and Y separately (preserves rectangular shape)
            float rect_sharpened;
            if (registers.sharp_mode < 0.5) {
                // Mode 0: Power curve
                float sharp_factor = 1.0 / max(effective_softness, 0.001);
                rect_sharpened = pow(x_coverage, sharp_factor) * pow(y_coverage, sharp_factor);
            } else {
                // Mode 1: Sigmoid
                // Base steepness of 10.0 provides moderate sharpness, scaled by effective_softness
                float sigmoid_strength = 10.0 / max(effective_softness, 0.001);
                float x_sharp = 1.0 / (1.0 + exp(-sigmoid_strength * (x_coverage - 0.5)));
                float y_sharp = 1.0 / (1.0 + exp(-sigmoid_strength * (y_coverage - 0.5)));
                rect_sharpened = x_sharp * y_sharp;
            }

            // Blend between linear and sharpened coverage
            float rect_coverage = mix(rect_linear, rect_sharpened, registers.sharpening_amount);

            // CIRCULAR METHOD: 2D area intersection with sharpening applied after
            float circ_linear = intersect_rect_area(pixel_rect, dot_rect) / (tx_to_px.x * tx_to_px.y);

            // Apply sharpening to 2D coverage (creates circular gradients)
            float circ_sharpened;
            if (registers.sharp_mode < 0.5) {
                circ_sharpened = pow(circ_linear, 1.0 / max(effective_softness, 0.001));
            } else {
                float sigmoid_strength = 10.0 / max(effective_softness, 0.001);
                circ_sharpened = 1.0 / (1.0 + exp(-sigmoid_strength * (circ_linear - 0.5)));
            }

            // Blend between linear and sharpened coverage
            float circ_coverage = mix(circ_linear, circ_sharpened, registers.sharpening_amount);

            // Blend between circular and rectangular based on pixel_shape parameter
        is_on_dot = mix(circ_coverage, rect_coverage, registers.pixel_shape);
    }

    float base_alpha = opacity_source.g;
    if (registers.color_toggle == 0.0)
        base_alpha = opacity_source.r;
    float rgb_to_alpha = base_alpha;
    rgb_to_alpha *= aa_compensation_factor;

    vec4 out_color = vec4(foreground_source, rgb_to_alpha);

    // Apply dot matrix mask - zeros out gaps in integer mode, applies antialiasing gradient in fullscreen mode
    out_color.a *= is_on_dot;

    if (registers.color_toggle == 0.0) {
        // Carry unnormalized opacity through the existing 8-bit RGB channels.
        float word = opacity_source.g;
        out_color.rgb = vec3(floor(word / 256.0), mod(word, 256.0), 0.0) / 255.0;
    }
    FragColor = out_color;
}
