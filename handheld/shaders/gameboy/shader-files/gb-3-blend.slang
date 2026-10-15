#version 450

#pragma name GameBoyDotMatrixAlphaBlend

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.5                          //
//                                                                       //
// Copyright (C) 2013 Harlequin : unknown92835@gmail.com                 //
// Copyright (C) 2024-2026 Matt Akins                                    //
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
 // Adjacent pixel alpha blending & brightness correction               //
/////////////////////////////////////////////////////////////////////////

#include "gb-params.inc"
#include "gb-shared.inc"

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	float blending_mode;
	float adjacent_texel_alpha_blending;
	float integer_mode;
	float video_scale;
    float color_toggle;
    float palette;
    float response_time;
    float brightness_mode;
    float grey_balance;
    float baseline_alpha;
    float alpha_reference_scale;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 GameBoyDotSize;
    vec4 GameBoyMatchCorrectionSize;
    float pixel_size;
    float fullscreen_match_pixel_size;
    float pixel_softness;
    float sharpening_amount;
    float pixel_shape;
    float sharp_mode;
    float auto_soften;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 2) out vec2 blur_coords_up;
layout(location = 3) out vec2 blur_coords_down;
layout(location = 4) out vec2 blur_coords_right;
layout(location = 5) out vec2 blur_coords_left;
layout(location = 6) flat out vec2 blur_coords_lower_bound;
layout(location = 7) flat out vec2 blur_coords_upper_bound;
layout(location = 14) flat out vec4 opacity_context;
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = biased_texcoord(TexCoord, registers.OutputSize.xy);
    vec2 texel = global.GameBoyDotSize.zw;
    blur_coords_down = vTexCoord + vec2(0.0, texel.y);
    blur_coords_up = vTexCoord + vec2(0.0, -texel.y);
    blur_coords_right = vTexCoord + vec2(texel.x, 0.0);
    blur_coords_left = vTexCoord + vec2(-texel.x, 0.0);
    blur_coords_lower_bound = texel * 0.5;
    blur_coords_upper_bound = texel * (global.GameBoyDotSize.xy - vec2(0.5));
    float scale = registers.integer_mode > 1.5 ? registers.video_scale
        : floor(global.GameBoyDotSize.y * registers.OriginalSize.w);
    opacity_context = vec4(1.0, scale, 0.0, 0.0);
}
#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 2) in vec2 blur_coords_up;
layout(location = 3) in vec2 blur_coords_down;
layout(location = 4) in vec2 blur_coords_right;
layout(location = 5) in vec2 blur_coords_left;
layout(location = 6) flat in vec2 blur_coords_lower_bound;
layout(location = 7) flat in vec2 blur_coords_upper_bound;
layout(location = 14) flat in vec4 opacity_context;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D GameBoyDot;
layout(set = 0, binding = 3) uniform sampler2D GameBoyMatchCorrection;
float blending_modifier(float color){
	float blend_bool = (color == 0.0) ? 1 : 0;
	return clamp(blend_bool + registers.blending_mode, 0.0, 1.0);
}

void main()
{
    // Blend neighboring alpha values to soften harsh transitions.
    // Blend Gaps affects zero-alpha gaps; Blend All affects every pixel.

    // Sample the input texture
    vec4 out_color = texture(GameBoyDot, vTexCoord).rgba;

    float blend_amount = min(registers.adjacent_texel_alpha_blending,
                             max_adjacent_alpha_blend);
    float apply_blend = blending_modifier(out_color.a);
    if (blend_amount != 0.0 && apply_blend != 0.0) {
        // Clamp the blur coords to the input texture size so it doesn't attempt to sample off the texture (it'll retrieve float4(0.0) and darken the edges otherwise)
        vec2 blur_coords_up_clamped    = clamp(blur_coords_up, blur_coords_lower_bound, blur_coords_upper_bound);
        vec2 blur_coords_down_clamped  = clamp(blur_coords_down, blur_coords_lower_bound, blur_coords_upper_bound);
        vec2 blur_coords_right_clamped = clamp(blur_coords_right, blur_coords_lower_bound, blur_coords_upper_bound);
        vec2 blur_coords_left_clamped  = clamp(blur_coords_left, blur_coords_lower_bound, blur_coords_upper_bound);

        // Sample adjacent texels based on the coordinates above
        vec4 adjacent_texel_1 = textureLod(GameBoyDot, blur_coords_up_clamped, 0.0).rgba;
        vec4 adjacent_texel_2 = textureLod(GameBoyDot, blur_coords_down_clamped, 0.0).rgba;
        vec4 adjacent_texel_3 = textureLod(GameBoyDot, blur_coords_right_clamped, 0.0).rgba;
        vec4 adjacent_texel_4 = textureLod(GameBoyDot, blur_coords_left_clamped, 0.0).rgba;

        // Sum the alpha differences between neighboring texels, apply modifiers, then subtract the result from the current fragment alpha value
        out_color.a -=
        (
            (out_color.a - adjacent_texel_1.a) +
            (out_color.a - adjacent_texel_2.a) +
            (out_color.a - adjacent_texel_3.a) +
            (out_color.a - adjacent_texel_4.a)
        ) * blend_amount * apply_blend;

    }

    float scale = opacity_context.y;
    vec2 bounds = registers.integer_mode > 0.5
        ? registers.OriginalSize.xy * scale * global.GameBoyDotSize.zw : vec2(1.0);
    vec2 core_coord = (vTexCoord - 0.5) / bounds + 0.5;
    bool inside = all(greaterThanEqual(core_coord, vec2(0.0))) && all(lessThan(core_coord, vec2(1.0)));
    if (inside) {
        vec2 cell_center = (floor(core_coord * registers.OriginalSize.xy) + 0.5) * global.GameBoyMatchCorrectionSize.zw;
        vec4 cell_data = texture(GameBoyMatchCorrection, cell_center);
        float correction = cell_data.r;
        if (correction > 0.0)
            out_color.a += correction * (1.0 - out_color.a);
        else if (correction < 0.0)
            out_color.a *= correction == -2.0 ? 0.0 : -correction;
        if (registers.color_toggle == 0.0)
            out_color.rgb = cell_data.gba;
    } else if (registers.color_toggle == 0.0) {
        out_color.rgb = vec3(0.0);
    }
    FragColor = out_color;
}
