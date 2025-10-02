#version 450

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.0                          //
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

#pragma parameter GAMEBOY_SHADER "=== GAME BOY Dot Matrix Shader v1.0 ===" 0.0 0.0 1.0 1.0
#pragma parameter NOTE1 " *  TIPS: Turn OFF Integer Scale in Settings > Video > Scaling" 0.0 0.0 1.0 1.0
#pragma parameter NOTE2 " *  GBC: Turn OFF Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0
#pragma parameter NOTE3 " *  GBA: Turn ON Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0

#include "gb-params.inc"

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	vec4 OriginalHistorySize1;
	float color_toggle;
	float pixel_size;
	float sigmoid_blend;
	float pixel_aspect;
	float integer_mode;
	float video_scale;
	float baseline_alpha;
	float grey_balance;
	float response_time;
	float brightness_mode;
	float sharp_mode;
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
// OPTIMIZATION: Pre-calculated values moved from fragment shader
layout(location = 8) out float video_scale_factor;
layout(location = 9) out vec2 scale_bounds;

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

        // Calculate authentic_gbc-style scaling parameters
        tx_coord = TexCoord * registers.SourceSize.xy;
        tx_to_px = registers.OutputSize.xy / registers.SourceSize.xy;

        // Game Boy dot size in output pixels with adjustable aspect ratio
        float coverage = 0.8 + (registers.pixel_aspect * 0.15);
        dot_size_in_px = tx_to_px * coverage;

        // Set unused outputs for integer mode
        dot_size = vec2(0.0);
        one_texel = vec2(0.0);
        screen_bounds = vec2(1.0);
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

// Geometric intersection function (from authentic_gbc)
float intersect_rect_area(vec4 px_square, vec4 rect) {
    const vec2 bl = max(px_square.xy, rect.xy);
    const vec2 tr = min(px_square.zw, rect.zw);
    const vec2 coverage = max(tr - bl, vec2(0.0));
    return coverage.x * coverage.y;
}

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

    // Sample frame history for response time calculation (full 7-frame history restored)
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
        // Non-integer scaling mode (smooth anti-aliased)
        vec2 tx_coord_i;
        const vec2 tx_coord_f = modf(tx_coord, tx_coord_i);

        // Calculate pixel rectangle in output space
        vec2 pixel_center = (tx_coord_f - 0.5) * tx_to_px;
        vec4 pixel_rect = vec4(pixel_center - tx_to_px * 0.5, pixel_center + tx_to_px * 0.5);

        // Create Game Boy dot rectangle with adjustable squareness
        vec2 dot_size_adjusted = dot_size_in_px;

        if (registers.pixel_aspect > 0.0) {
            dot_size_adjusted = dot_size_in_px * (1.0 + registers.pixel_aspect * 0.2);
        }

        vec4 dot_rect = vec4(-dot_size_adjusted * 0.5, dot_size_adjusted * 0.5);

        // Calculate geometric coverage
        float dot_coverage = intersect_rect_area(pixel_rect, dot_rect) / (tx_to_px.x * tx_to_px.y);

        // Power curve vs Sigmoid sharpening
        if (registers.sharp_mode < 0.5) {
            // Mode 0: Power curve sharpening (exponential scaling)
            is_on_dot = pow(dot_coverage, 1.0 / max(registers.pixel_size, 0.001));

        } else {
            // Mode 1: Linear-to-sigmoid blend with independent controls
            // pixel_size controls the sigmoid curve steepness
            // sigmoid_blend controls the mix between linear (0) and sigmoid (1)
            float sigmoid_strength = registers.pixel_size * 10.0;
            float sigmoid = 1.0 / (1.0 + exp(-sigmoid_strength * (dot_coverage - 0.5)));
            float linear_coverage = dot_coverage;
            is_on_dot = mix(linear_coverage, sigmoid, clamp(registers.sigmoid_blend, 0.0, 1.0));
        }
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

    // Compensate for antialiasing intensity reduction in fullscreen mode
    // Mode 0 applies geometric antialiasing which reduces average intensity by ~3.0x
    // (calculated from average is_on_dot value across a dot with default sharpness settings)
    float grey_balance_adjusted = registers.grey_balance;
    if (registers.integer_mode < 0.5) {
        grey_balance_adjusted = grey_balance_adjusted / 3.0;
    }
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

    // Apply dot matrix mask - zeros out gaps, applies antialiasing gradient in Mode 0
    out_color.a *= is_on_dot;

    FragColor = out_color;
}