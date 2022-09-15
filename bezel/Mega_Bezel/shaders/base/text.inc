/*
    Mega Bezel - Creates a graphic treatment for the game play area to give a retro feel
    Copyright (C) 2019-2021 HyperspaceMadness - HyperspaceMadness@outlook.com

    Incorporates much great feedback from the libretro forum, and thanks 
    to Hunterk who helped me get started

    See more at the libretro forum
    https://forums.libretro.com/t/hsm-mega-bezel-reflection-shader-feedback-and-updates

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// Import so all the mega bezel parameters are the first in the parameter list

#include "text-resolution.inc"

#pragma alias TextPass

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.00001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D TextPassFeedback;
#define PassFeedback TextPassFeedback

layout(set = 0, binding = 8) uniform sampler2D InfoCachePass;
layout(set = 0, binding = 9) uniform sampler2D InfoCachePassFeedback;

#define eps 1e-3

vec2 GetScreenSize(vec2 screen_scale)
{
	vec2 screen_size = global.FinalViewportSize.xy * screen_scale;
	// Round this so we get proper integers
	screen_size = vec2(ceil(screen_size.x), ceil(screen_size.y));
	return screen_size;
}

vec2 GetIntegerScaleMult(vec2 screen_size, vec2 cropped_size)
{
	float epsilon = 0.002;
	vec2 integer_scale = screen_size / cropped_size;
	integer_scale = vec2(fract(integer_scale.x + 0.001) < epsilon ? round(integer_scale.x) : integer_scale.x,
						 fract(integer_scale.y + 0.001) < epsilon ? round(integer_scale.y) : integer_scale.y);
	return integer_scale;
}

vec4 AddText(vec2 in_coord, vec4 in_color)
{
   in_coord.x = HSM_FLIP_VIEWPORT_HORIZONTAL * HSM_FLIP_CORE_HORIZONTAL * (in_coord.x - 0.5) + 0.5;
   in_coord.y = HSM_FLIP_VIEWPORT_VERTICAL * HSM_FLIP_CORE_VERTICAL * (in_coord.y - 0.5) + 0.5;

   vec2 screen_size = GetScreenSize(SCREEN_SCALE);
   vec2 int_scale_mult = GetIntegerScaleMult(screen_size, CROPPED_ROTATED_SIZE);
   vec2 canvas_size = global.DerezedPassSize.xy;

   vec4 out_color = in_color;
   out_color = mix(out_color, vec4(0, 0, 0, 1), GetTextMask(in_coord + 2 * vec2(1/global.OutputSize.x, 0), global.FinalViewportSize.xy, screen_size, ROTATED_DEREZED_SIZE, ROTATED_CORE_PREPPED_SIZE, CROPPED_ROTATED_SIZE, CROPPED_ROTATED_SIZE_WITH_RES_MULT, int_scale_mult, canvas_size));
   out_color = mix(out_color, vec4(0, 0, 0, 1), GetTextMask(in_coord - 2 * vec2(1/global.OutputSize.x, 0), global.FinalViewportSize.xy, screen_size, ROTATED_DEREZED_SIZE, ROTATED_CORE_PREPPED_SIZE, CROPPED_ROTATED_SIZE, CROPPED_ROTATED_SIZE_WITH_RES_MULT, int_scale_mult, canvas_size));
   out_color = mix(out_color, vec4(0, 0, 0, 1), GetTextMask(in_coord + 1 * vec2(0, 1/global.OutputSize.y), global.FinalViewportSize.xy, screen_size, ROTATED_DEREZED_SIZE, ROTATED_CORE_PREPPED_SIZE, CROPPED_ROTATED_SIZE, CROPPED_ROTATED_SIZE_WITH_RES_MULT, int_scale_mult, canvas_size));
   out_color = mix(out_color, vec4(0, 0, 0, 1), GetTextMask(in_coord - 1 * vec2(0, 1/global.OutputSize.y), global.FinalViewportSize.xy, screen_size, ROTATED_DEREZED_SIZE, ROTATED_CORE_PREPPED_SIZE, CROPPED_ROTATED_SIZE, CROPPED_ROTATED_SIZE_WITH_RES_MULT, int_scale_mult, canvas_size));
   out_color = mix(out_color, vec4(1, 1, 0, 1), GetTextMask(in_coord,                                      global.FinalViewportSize.xy, screen_size, ROTATED_DEREZED_SIZE, ROTATED_CORE_PREPPED_SIZE, CROPPED_ROTATED_SIZE, CROPPED_ROTATED_SIZE_WITH_RES_MULT, int_scale_mult, canvas_size));
   return clamp(out_color, 0, 1);
}

void main()
{
	vec2 UNFLIPPED_VIEWPORT_COORD = vTexCoord;
   vec2 VIEWPORT_COORD = vTexCoord;
	HSM_UpdateGlobalScreenValuesFromCache(InfoCachePass, InfoCachePassFeedback, vTexCoord);

   FragColor = vec4(0);

   vec4 feedback_color_test = texture(PassFeedback, vec2(0,0));
   if (feedback_color_test.a < 0 && !HSM_CheckCacheInfoChanged())
   {
      FragColor = texture(PassFeedback, UNFLIPPED_VIEWPORT_COORD);
      return;
   }

   // Flip the coordinate vertically if desired
   VIEWPORT_COORD.y = HSM_FLIP_VIEWPORT_VERTICAL * HSM_FLIP_CORE_VERTICAL * (VIEWPORT_COORD.y - 0.5) + 0.5;
   VIEWPORT_COORD.x = HSM_FLIP_VIEWPORT_HORIZONTAL * HSM_FLIP_CORE_HORIZONTAL * (VIEWPORT_COORD.x - 0.5) + 0.5;

   //////// Draw text to show resolutions //////////
   FragColor = AddText(VIEWPORT_COORD - vec2(MAX_NEGATIVE_CROP, -MAX_NEGATIVE_CROP), FragColor);

	if (UNFLIPPED_VIEWPORT_COORD.x < (2 / global.OutputSize.x) && UNFLIPPED_VIEWPORT_COORD.y < (2 / global.OutputSize.y))
		FragColor = vec4(0.01, 0.01, 0.01, -1);
}