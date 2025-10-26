#version 450

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.1                          //
//                                                                       //
// Copyright (C) 2013 Harlequin : unknown92835@gmail.com                 //
// Copyright (C) 2024-2025 Matt Akins                                    //
//                                                                       //
// 2/6/24 - Modified to support color output by mattakins                //
// 9/30/25 - v1.0 by mattakins                                           //
//   • Fullscreen mode scales dot matrix effect to any screen size       //
//   • Swap between display modes (full / max integer / scale factor)    //
//   • Built-in palette presets while maintaining image pallete support  //
//   • Drop shadow ON / OFF toggle                                       //
//   • Simple vs perceptual pixel brightness calculation modes           //
//   • Performance optimizations (vertex pre-calc, early-exit)           //
//   • Parameter reorganization for ease of use                          //
//   • Fixed issue with artifacts sometimes appearing in border          //
// 10/25/25 - v1.1 by mattakins                                          //
//   • Fixed fullscreen mode right and bottom border bug                 //
//   • Improved brightness compensation for fullscreen pixel parameters  //
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
 // gb-pass0 - Core dot matrix generation & response time simulation    //
/////////////////////////////////////////////////////////////////////////

#pragma parameter GAMEBOY_SHADER "=== GAME BOY DOT MATRIX SHADER v1.1 ===" 0.0 0.0 1.0 1.0
#pragma parameter NOTE1 " *  TIPS: Turn OFF Integer Scale in Settings > Video > Scaling" 0.0 0.0 1.0 1.0
#pragma parameter NOTE2 " *  GBC: Turn OFF Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0
#pragma parameter NOTE3 " *  GBA: Turn ON Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0

#include "gb-params.inc"

  /////////////////////////////////////////////////////////////////////////
 // Shared functions for numerical grey balance compensation            //
 // Uses 4×4 grid (16-point) coverage sampling with empirical base values //
/////////////////////////////////////////////////////////////////////////

// 1D line segment intersection
float intersect_line_segment(float pixel_start, float pixel_end,
                             float dot_start, float dot_end) {
    float overlap_start = max(pixel_start, dot_start);
    float overlap_end = min(pixel_end, dot_end);
    return max(overlap_end - overlap_start, 0.0);
}

// 2D rectangle intersection
float intersect_rect_area(vec4 px_square, vec4 rect) {
    const vec2 bl = max(px_square.xy, rect.xy);
    const vec2 tr = min(px_square.zw, rect.zw);
    const vec2 coverage = max(tr - bl, vec2(0.0));
    return coverage.x * coverage.y;
}

// Calculate coverage for a single sample point in normalized coordinate space
float calculate_coverage_at_point(vec2 tx_coord_f, float pixel_size,
                                   float pixel_softness, float sharpening_amount,
                                   float pixel_shape, float sharp_mode) {
    // Normalized coordinate space where tx_to_px = 1.0
    vec2 pixel_center = (tx_coord_f - 0.5);
    vec4 pixel_rect = vec4(pixel_center - 0.5, pixel_center + 0.5);
    vec2 dot_size_in_px = vec2(pixel_size);
    vec4 dot_rect = vec4(-dot_size_in_px * 0.5, dot_size_in_px * 0.5);

    // RECTANGULAR METHOD: 1D separable coverage
    float x_coverage = intersect_line_segment(pixel_rect.x, pixel_rect.z,
                                              dot_rect.x, dot_rect.z);
    float y_coverage = intersect_line_segment(pixel_rect.y, pixel_rect.w,
                                              dot_rect.y, dot_rect.w);
    float rect_linear = x_coverage * y_coverage;

    // Apply sharpening
    float rect_sharpened;
    if (sharp_mode < 0.5) {
        // Power mode
        float sharp_factor = 1.0 / max(pixel_softness, 0.001);
        rect_sharpened = pow(x_coverage, sharp_factor) *
                        pow(y_coverage, sharp_factor);
    } else {
        // Sigmoid mode
        float sigmoid_strength = 10.0 / max(pixel_softness, 0.001);
        float x_sharp = 1.0 / (1.0 + exp(-sigmoid_strength * (x_coverage - 0.5)));
        float y_sharp = 1.0 / (1.0 + exp(-sigmoid_strength * (y_coverage - 0.5)));
        rect_sharpened = x_sharp * y_sharp;
    }
    float rect_coverage = mix(rect_linear, rect_sharpened, sharpening_amount);

    // CIRCULAR METHOD: 2D area coverage
    float circ_linear = intersect_rect_area(pixel_rect, dot_rect);

    // Apply sharpening
    float circ_sharpened;
    if (sharp_mode < 0.5) {
        circ_sharpened = pow(circ_linear, 1.0 / max(pixel_softness, 0.001));
    } else {
        float sigmoid_strength = 10.0 / max(pixel_softness, 0.001);
        circ_sharpened = 1.0 / (1.0 + exp(-sigmoid_strength * (circ_linear - 0.5)));
    }
    float circ_coverage = mix(circ_linear, circ_sharpened, sharpening_amount);

    // Blend between circular and rectangular based on pixel_shape parameter
    return mix(circ_coverage, rect_coverage, pixel_shape);
}

// Sample coverage across 4×4 grid and return average brightness
float sample_average_coverage(float pixel_size, float pixel_softness,
                               float sharpening_amount, float pixel_shape,
                               float sharp_mode) {
    float total = 0.0;
    // Sample at 16 sub-pixel positions representing different pixel-to-dot alignments
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            vec2 sample_pos = vec2(-0.375 + float(x) * 0.25,
                                  -0.375 + float(y) * 0.25);
            total += calculate_coverage_at_point(sample_pos, pixel_size,
                                                pixel_softness, sharpening_amount,
                                                pixel_shape, sharp_mode);
        }
    }
    return total / 16.0;
}

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	vec4 OriginalHistorySize1;
	float color_toggle;
	float pixel_size;
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
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

  /////////////////////////////////////////////////////////////////////////
 // Vertex shader                                                       //
/////////////////////////////////////////////////////////////////////////

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 original_coord;
layout(location = 2) out vec2 dot_size;
layout(location = 3) out vec2 one_texel;
layout(location = 4) out vec2 tx_coord;
layout(location = 5) out vec2 tx_to_px;
layout(location = 6) out vec2 dot_size_in_px;
layout(location = 7) out vec2 screen_bounds;
// OPTIMIZATION: Frame-constant values calculated once in vertex shader
layout(location = 8) out float video_scale_factor;
layout(location = 9) out vec2 scale_bounds;
layout(location = 10) out float aa_compensation_factor;  // Grey balance compensation (numerical)

  /////////////////////////////////////////////////////////////////////////
 // Vertex definitions                                                  //
/////////////////////////////////////////////////////////////////////////

void main()
{
    // Pre-calculate frame-constant values once in vertex shader
    if (registers.integer_mode > 0.5) {
        // Integer scaling mode calculations moved to vertex shader
        if (registers.integer_mode > 1.5) {
            video_scale_factor = registers.video_scale;
        } else {
            video_scale_factor = floor(registers.OutputSize.y * registers.SourceSize.w);
        }
        vec2 scaled_video_out = (registers.SourceSize.xy * vec2(video_scale_factor));
        scale_bounds = scaled_video_out / registers.OutputSize.xy;

        // Standard setup for integer mode
        gl_Position = global.MVP * Position;
        vTexCoord = TexCoord * 1.0001;
        original_coord = TexCoord;
        dot_size = registers.SourceSize.zw;
        one_texel = 1.0 / (registers.SourceSize.xy * video_scale_factor);
        screen_bounds = scale_bounds;

        // Set unused outputs for non-integer mode
        tx_coord = vec2(0.0);
        tx_to_px = vec2(0.0);
        dot_size_in_px = vec2(0.0);
    } else {
        // Non-integer scaling mode (smooth anti-aliased)
        video_scale_factor = 1.0; // Not used in non-integer mode
        scale_bounds = vec2(1.0); // Full screen

        gl_Position = global.MVP * Position;
        vTexCoord = TexCoord;
        original_coord = TexCoord;

        // Calculate scaling parameters for geometric dot rendering
        tx_coord = TexCoord * registers.SourceSize.xy;
        tx_to_px = registers.OutputSize.xy / registers.SourceSize.xy;

        // Game Boy dot size in output pixels
        dot_size_in_px = tx_to_px * registers.pixel_size;

        // Set unused outputs for integer mode
        dot_size = vec2(0.0);
        one_texel = vec2(0.0);
        screen_bounds = vec2(1.0);
    }

    // Calculate grey balance compensation using numerical coverage sampling (only needed for fullscreen mode)
    if (registers.integer_mode < 0.5) {
        // Reference params match empirical tuning baseline:
        // pixel_size=0.80, pixel_softness=0.80, pixel_shape=1.0, sharpening_amount=1.0
        float ref_brightness = sample_average_coverage(0.80, 0.80, 1.0, 1.0,
                                                       registers.sharp_mode);
        float cur_brightness = sample_average_coverage(registers.pixel_size,
                                                       registers.pixel_softness,
                                                       registers.sharpening_amount,
                                                       registers.pixel_shape,
                                                       registers.sharp_mode);

        // Base compensation values empirically tuned at reference params
        float base_comp = (registers.sharp_mode < 0.5)
            ? 2.8  // Power mode: circular and rectangular are mathematically identical
            : mix(2.5, 1.60, registers.pixel_shape);  // Sigmoid mode differs by shape

        // Apply empirical corrections for perceptual brightness effects not captured by numerical sampling
        float brightness_ratio = ref_brightness / max(cur_brightness, 0.001);
        float size_comp = (registers.pixel_size > 0.80)
            ? pow(registers.pixel_size / 0.80, 0.62)  // Larger pixels appear brighter (perceptual effect)
            : 1.0;
        float softness_comp = (registers.pixel_softness > 1.0)
            ? pow(registers.pixel_softness, 0.444)  // Higher softness increases perceived brightness
            : 1.0;
        float sharpening_comp = (registers.sharp_mode < 0.5)
            ? mix(0.857, 1.0, registers.sharpening_amount)  // Power: linear coverage is brighter
            : mix(1.5, 1.0, registers.sharpening_amount);   // Sigmoid: linear coverage is darker
        float shape_comp = (registers.sharp_mode >= 0.5 && registers.pixel_shape > 1.0)
            ? 1.0 + (registers.pixel_shape - 1.0) * 0.667  // Rectangular shapes increase coverage ratio
            : 1.0;

        // Combine all factors
        aa_compensation_factor = base_comp * brightness_ratio * size_comp *
                                softness_comp * sharpening_comp * shape_comp;
    } else {
        aa_compensation_factor = 1.0;  // No compensation in integer mode
    }

}

  /////////////////////////////////////////////////////////////////////////
 // Fragment shader                                                     //
/////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 original_coord;
layout(location = 2) in vec2 dot_size;
layout(location = 3) in vec2 one_texel;
layout(location = 4) in vec2 tx_coord;
layout(location = 5) in vec2 tx_to_px;
layout(location = 6) in vec2 dot_size_in_px;
layout(location = 7) in vec2 screen_bounds;
layout(location = 8) in float video_scale_factor;
layout(location = 9) in vec2 scale_bounds;
layout(location = 10) in float aa_compensation_factor;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D OriginalHistory1;
layout(set = 0, binding = 4) uniform sampler2D OriginalHistory2;
layout(set = 0, binding = 5) uniform sampler2D OriginalHistory3;
layout(set = 0, binding = 6) uniform sampler2D OriginalHistory4;
layout(set = 0, binding = 7) uniform sampler2D OriginalHistory5;
layout(set = 0, binding = 8) uniform sampler2D OriginalHistory6;
layout(set = 0, binding = 9) uniform sampler2D OriginalHistory7;
layout(set = 0, binding = 10) uniform sampler2D COLOR_PALETTE;

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

    // Sample texture and frame history with final coordinates
    vec3 foreground_source = texture(Source, final_tex_coord).rgb;

    // Sample frame history for response time calculation (uses full 7-frame history)
    vec3 curr_rgb = abs(1.0 - texture(Source, final_tex_coord).rgb);
    vec3 prev0_rgb = abs(1.0 - texture(OriginalHistory1, final_tex_coord).rgb);
    vec3 prev1_rgb = abs(1.0 - texture(OriginalHistory2, final_tex_coord).rgb);
    vec3 prev2_rgb = abs(1.0 - texture(OriginalHistory3, final_tex_coord).rgb);
    vec3 prev3_rgb = abs(1.0 - texture(OriginalHistory4, final_tex_coord).rgb);
    vec3 prev4_rgb = abs(1.0 - texture(OriginalHistory5, final_tex_coord).rgb);
    vec3 prev5_rgb = abs(1.0 - texture(OriginalHistory6, final_tex_coord).rgb);
    vec3 prev6_rgb = abs(1.0 - texture(OriginalHistory7, final_tex_coord).rgb);

    float is_on_dot = 0.0;

    if (registers.integer_mode > 0.5) {
        // Integer mode dot detection
        if ( mod(final_tex_coord.x, dot_size.x) > one_texel.x && mod(final_tex_coord.y, dot_size.y) > one_texel.y )
            is_on_dot = 1.0;
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
            float sharp_factor = 1.0 / max(registers.pixel_softness, 0.001);
            rect_sharpened = pow(x_coverage, sharp_factor) * pow(y_coverage, sharp_factor);
        } else {
            // Mode 1: Sigmoid
            // Base steepness of 10.0 provides moderate sharpness, scaled by pixel_softness
            float sigmoid_strength = 10.0 / max(registers.pixel_softness, 0.001);
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
            circ_sharpened = pow(circ_linear, 1.0 / max(registers.pixel_softness, 0.001));
        } else {
            float sigmoid_strength = 10.0 / max(registers.pixel_softness, 0.001);
            circ_sharpened = 1.0 / (1.0 + exp(-sigmoid_strength * (circ_linear - 0.5)));
        }

        // Blend between linear and sharpened coverage
        float circ_coverage = mix(circ_linear, circ_sharpened, registers.sharpening_amount);

        // Blend between circular and rectangular based on pixel_shape parameter
        is_on_dot = mix(circ_coverage, rect_coverage, registers.pixel_shape);
    }

    // Sample color from the current and previous frames, apply response time modifier
    // Response time effect implemented through an exponential dropoff algorithm
    vec3 input_rgb = curr_rgb;
    input_rgb += (prev0_rgb - input_rgb) * registers.response_time;
    input_rgb += (prev1_rgb - input_rgb) * pow(registers.response_time, 2.0);
    input_rgb += (prev2_rgb - input_rgb) * pow(registers.response_time, 3.0);
    input_rgb += (prev3_rgb - input_rgb) * pow(registers.response_time, 4.0);
    input_rgb += (prev4_rgb - input_rgb) * pow(registers.response_time, 5.0);
    input_rgb += (prev5_rgb - input_rgb) * pow(registers.response_time, 6.0);
    input_rgb += (prev6_rgb - input_rgb) * pow(registers.response_time, 7.0);

    // Brightness calculation based on mode
    float brightness;
    if (registers.brightness_mode < 0.5) {
        brightness = (input_rgb.r + input_rgb.g + input_rgb.b);
    } else {
        brightness = (0.2126 * input_rgb.r) + (0.7152 * input_rgb.g) + (0.0722 * input_rgb.b);
    }

    // Apply numerical grey balance compensation (calculated in vertex shader)
    float grey_balance_adjusted = registers.grey_balance / aa_compensation_factor;

    // Compensate for brightness range difference between modes
    // Perceptual mode outputs 0-1, simple mode outputs 0-3
    if (registers.brightness_mode >= 0.5) {
        grey_balance_adjusted = grey_balance_adjusted / 3.0;
    }

    float rgb_to_alpha = brightness / grey_balance_adjusted + registers.baseline_alpha;

    // Foreground palette color selection
    vec3 foreground_color;
    if (registers.palette < 0.5) {
        foreground_color = texture(COLOR_PALETTE, vec2(0.75, 0.5)).rgb; // 0: Original texture
    } else if (registers.palette < 1.5) {
        foreground_color = vec3(0.067, 0.098, 0.133); // 1: #111922
    } else if (registers.palette < 2.5) {
        foreground_color = vec3(0.125, 0.125, 0.125); // 2: #202020
    } else if (registers.palette < 3.5) {
        foreground_color = vec3(0.0, 0.0, 0.0); // 3: #000000
    } else if (registers.palette < 4.5) {
        foreground_color = vec3(0.114, 0.416, 0.420); // 4: #1D6A6B
    } else if (registers.palette < 5.5) {
        foreground_color = vec3(0.0, 0.325, 0.200); // 5: #005333
    } else {
        foreground_color = vec3(0.0, 0.325, 0.314); // 6: #005350
    }

    vec4 out_color;
    if (registers.color_toggle == 0.0)
        out_color = vec4(foreground_color, rgb_to_alpha);
    else
        out_color = vec4(foreground_source, rgb_to_alpha);

    // Apply dot matrix mask - zeros out gaps in integer mode, applies antialiasing gradient in fullscreen mode
    out_color.a *= is_on_dot;

    FragColor = out_color;
}