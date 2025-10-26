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
 // gb-pass4 - Final compositing with background & shadows              //
/////////////////////////////////////////////////////////////////////////

#include "gb-params.inc"

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	vec4 PassOutputSize1;
	float contrast;
	float screen_light;
	float pixel_opacity;
	float bg_smoothing;
	float shadow_opacity;
	float shadow_offset_x;
	float shadow_offset_y;
	float screen_offset_x;
	float screen_offset_y;
	float shadow_enable;
	float palette;
	float shadow_scale;
	float integer_mode;
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
layout(location = 1) out vec2 texel;
layout(location = 2) out float resolution_scale;
layout(location = 3) out float shadow_scale_factor;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord * 1.0001;

    // Calculate resolution scale for shadow compensation
    // Reference resolution: 640×480 (shadow offsets tuned for this resolution)
    float scale_x = registers.OutputSize.x / 640.0;
    float scale_y = registers.OutputSize.y / 480.0;
    resolution_scale = sqrt(scale_x * scale_y);

    // Pre-calculate shadow scale factor based on toggle
    shadow_scale_factor = (registers.shadow_scale > 0.5) ? resolution_scale : 1.0;

    texel = registers.SourceSize.zw;
}

  /////////////////////////////////////////////////////////////////////////
 // Fragment definitions                                                //
/////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 texel;
layout(location = 2) in float resolution_scale;
layout(location = 3) in float shadow_scale_factor;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;
layout(set = 0, binding = 2) uniform sampler2D PassOutput1;
layout(set = 0, binding = 3) uniform sampler2D BACKGROUND;
layout(set = 0, binding = 4) uniform sampler2D COLOR_PALETTE;

// Background palette color selection
vec4 get_bg_color() {
    if (registers.palette < 0.5) {
        return texture(COLOR_PALETTE, vec2(0.25, 0.5)); // 0: Original texture
    } else if (registers.palette < 1.5) {
        return vec4(0.651, 0.675, 0.518, 1.0); // 1: #A6AC84
    } else if (registers.palette < 2.5) {
        return vec4(0.737, 0.737, 0.737, 1.0); // 2: #BCBCBC
    } else if (registers.palette < 3.5) {
        return vec4(1.0, 1.0, 1.0, 1.0); // 3: #FFFFFF
    } else if (registers.palette < 4.5) {
        return vec4(0.627, 0.667, 0.024, 1.0); // 4: #A0AA06
    } else if (registers.palette < 5.5) {
        return vec4(0.027, 0.729, 0.369, 1.0); // 5: #07BA5E
    } else {
        return vec4(0.027, 0.729, 0.608, 1.0); // 6: #07BA9B
    }
}

#define bg_color get_bg_color() 

// Sample the background color from the palette
#define shadow_alpha (registers.contrast * registers.shadow_opacity * registers.shadow_enable)

// Offset for the shadow (with resolution compensation if enabled)
#define shadow_offset vec2(registers.shadow_offset_x * texel.x * shadow_scale_factor, registers.shadow_offset_y * texel.y * shadow_scale_factor)    

// Offset for the entire screen
// Only apply -1 offset in integer scaling modes (not fullscreen)
#define screen_offset vec2( \
    (registers.integer_mode > 0.5 ? (registers.screen_offset_x - 1.0) : registers.screen_offset_x) * texel.x, \
    (registers.integer_mode > 0.5 ? (registers.screen_offset_y - 1.0) : registers.screen_offset_y) * texel.y \
)

  /////////////////////////////////////////////////////////////////////////
 // Fragment shader                                                     //
/////////////////////////////////////////////////////////////////////////

void main()
{
    vec2 tex = floor(registers.PassOutputSize1.xy * vTexCoord);
    tex = (tex + 0.5) * registers.PassOutputSize1.zw;

    // Cache background color to avoid multiple function calls
    vec4 bg_color_cached = get_bg_color();

    // Sample all the relevant textures
    vec4 foreground = texture(PassOutput1, tex - screen_offset);
    vec4 background = texture(BACKGROUND, vTexCoord);
    vec4 shadows    = texture(Source, vTexCoord - (shadow_offset + screen_offset));

    // Foreground and background are blended with the background color
    foreground *= bg_color_cached;
    
    float bg_test = 0.0;
    if ( foreground.a > 0.0 )
        bg_test = 1.0; 

    background -= (background - 0.5) * registers.bg_smoothing * bg_test;

    // Allows for highlights,
    // background = bg_color when the background color is 0.5 gray
    background.rgb = clamp(
        vec3(
            bg_color_cached.r + mix(-1.0, 1.0, background.r),
            bg_color_cached.g + mix(-1.0, 1.0, background.g),
            bg_color_cached.b + mix(-1.0, 1.0, background.b)
        ),
        0.0, 1.0
    );

    // Shadows are alpha blended with the background
    vec4 out_color = (shadows * shadows.a * shadow_alpha) + (background * (1 - shadows.a * shadow_alpha));  

    // Foreground is alpha blended with the shadowed background
    out_color = (foreground * foreground.a * registers.contrast) + (out_color * (registers.screen_light - foreground.a * registers.contrast * registers.pixel_opacity));
    
    FragColor = out_color;
}