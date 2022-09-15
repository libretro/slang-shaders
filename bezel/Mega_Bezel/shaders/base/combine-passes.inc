/*
    Mega Bezel - Creates a graphic treatment for the game play area to give a retro feel
    Copyright (C) 2019-2022 HyperspaceMadness - HyperspaceMadness@outlook.com

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
    along with this program.  If not, see [http://www.gnu.org/licenses/].
*/

/////////////// IMPORTS ///////////////
#include "common/globals-and-image-layers-params.inc"
#include "common/common-functions-bezel.inc"


vec2 UNFLIPPED_VIEWPORT_COORD = vec2(0.5);
vec2 FLIPPED_VIEWPORT_COORD = vec2(0.5);

//////////////////////////////////////////////////////////////////////////////////////////////////
#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 6) out vec2 vTexCoord;
layout(location = 8) out vec3 BEZEL_FRAME_ORIGINAL_COLOR_RGB;

//////////////////////////////////////////////////////////////////////////////////////////////////
void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord;

	// Not sure why we need linearize this but it seems to have a smoother range this way
	BEZEL_FRAME_ORIGINAL_COLOR_RGB = HSM_Linearize(vec4(HSM_HSVtoRGB(vec3(HSM_BZL_COLOR_HUE, HSM_BZL_COLOR_SATURATION, HSM_BZL_COLOR_VALUE)), 1), DEFAULT_SRGB_GAMMA).rgb;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
#pragma stage fragment

layout(location = 6) in vec2 vTexCoord;

layout(location = 0) out vec4 FragColor;

// Pass Framebuffer Textures
layout(set = 0, binding = 1) uniform sampler2D InfoCachePass;
layout(set = 0, binding = 2) uniform sampler2D InfoCachePassFeedback;

layout(set = 0, binding = 3) uniform sampler2D BR_LayersUnderCRTPass;

#ifdef IS_NO_REFLECT_PRESET
layout(set = 0, binding = 4) uniform sampler2D MBZ_PostCRTPass;
#define MiddlePass MBZ_PostCRTPass
#else
layout(set = 0, binding = 4) uniform sampler2D BR_CRTAndReflectionPass;
#define MiddlePass BR_CRTAndReflectionPass
#endif

layout(set = 0, binding = 5) uniform sampler2D BR_LayersOverCRTPass;

layout(set = 0, binding = 6) uniform sampler2D CombinePassFeedback;
#define PassFeedback CombinePassFeedback

//////////////////////////////////////////////////////////////////////////////////////////////////
void main()
{
	UNFLIPPED_VIEWPORT_COORD = vTexCoord;
	vec2 VIEWPORT_COORD = HSM_GetViewportCoordWithZoomAndPan(vTexCoord);
	HSM_UpdateGlobalScreenValuesFromCache(InfoCachePass, InfoCachePassFeedback, vTexCoord);


	// Have to get the scale of the coordinates so we can figure out the size of the onscreen rectangle of the area 
	HSM_GetBezelCoords(TUBE_DIFFUSE_COORD, 
						TUBE_DIFFUSE_COORD, 
						TUBE_SCALE, 
						TUBE_DIFFUSE_ASPECT,
						false, 
						BEZEL_OUTSIDE_SCALE,
						BEZEL_OUTSIDE_COORD, 
						BEZEL_OUTSIDE_CURVED_COORD, 
						FRAME_OUTSIDE_CURVED_COORD);

	if (BEZEL_OUTSIDE_COORD.x < -0.01 || BEZEL_OUTSIDE_COORD.x > 1.01 || BEZEL_OUTSIDE_COORD.y < -0.01 || BEZEL_OUTSIDE_COORD.y > 1.01)
	{
		vec4 feedback_color_test = texture(PassFeedback, vec2(0,0));
		if (HSM_CACHE_GRAPHICS_ON > 0.5 && feedback_color_test.a < 0 && !HSM_CheckCacheInfoChanged() && HSM_RENDER_SIMPLE_MODE < 0.5)
		{
			FragColor = texture(PassFeedback, UNFLIPPED_VIEWPORT_COORD);
			return;
		}
	}

	vec4 out_color = texture(BR_LayersUnderCRTPass, vTexCoord);
	out_color.rgb *= HSM_GLOBAL_GRAPHICS_BRIGHTNESS;

	vec4 crt_layer = texture(MiddlePass, vTexCoord);
	#ifdef IS_NO_REFLECT_PRESET
		crt_layer = HSM_Linearize(crt_layer, DEFAULT_SRGB_GAMMA);
	#endif

	if (HSM_RENDER_SIMPLE_MODE > 0.5)
		crt_layer.rgb = vec3(0);

	float bezel_corner_radius = HSM_BZL_INNER_CORNER_RADIUS_SCALE * HSM_GLOBAL_CORNER_RADIUS;
	if(HSM_BZL_USE_INDEPENDENT_CURVATURE > 0)
		bezel_corner_radius = HSM_BZL_INNER_CORNER_RADIUS_SCALE * DEFAULT_SCREEN_CORNER_RADIUS;
	vec2 tube_curved_coord = HSM_GetTubeCurvedCoord(TUBE_DIFFUSE_COORD, 1, TUBE_DIFFUSE_SCALE, TUBE_SCALE, TUBE_DIFFUSE_ASPECT, 1);

	if (HSM_RENDER_SIMPLE_MODE < 0.5)
		out_color.rgb += crt_layer.rgb;

	vec4 over_layer = texture(BR_LayersOverCRTPass, vTexCoord);
	over_layer.rgb *= HSM_GLOBAL_GRAPHICS_BRIGHTNESS;
	out_color = HSM_PreMultAlphaBlend(out_color, over_layer);

	FragColor = HSM_ApplyGamma(clamp(out_color, 0, 1), DEFAULT_SRGB_GAMMA);

	if (HSM_RENDER_SIMPLE_MODE > 0.5)
	{
		TUBE_DIFFUSE_CURVED_COORD = HSM_GetCurvedCoord(TUBE_DIFFUSE_COORD, HSM_TUBE_BLACK_EDGE_CURVATURE_SCALE, TUBE_DIFFUSE_ASPECT);
		TUBE_DIFFUSE_MASK = HSM_GetCornerMask(((TUBE_DIFFUSE_CURVED_COORD - 0.5) * 1.001) + 0.5, TUBE_DIFFUSE_ASPECT, HSM_GLOBAL_CORNER_RADIUS * HSM_TUBE_BLACK_EDGE_CORNER_RADIUS_SCALE, HSM_TUBE_BLACK_EDGE_SHARPNESS);

		TUBE_MASK =  HSM_GetCornerMask(tube_curved_coord, TUBE_DIFFUSE_ASPECT, bezel_corner_radius, 0.99);
		// float TUBE_MASK_TRIM = HSM_GetCornerMask((tube_curved_coord - 0.5) * 1.003 + 0.5, TUBE_DIFFUSE_ASPECT, bezel_corner_radius, 0.99);

		INSIDE_BEZEL_MASK = HSM_GetCornerMask(BEZEL_OUTSIDE_CURVED_COORD, TUBE_DIFFUSE_ASPECT, HSM_GLOBAL_CORNER_RADIUS * HSM_BZL_OUTER_CORNER_RADIUS_SCALE, 0.9);
		BEZEL_MASK = INSIDE_BEZEL_MASK * (1 - TUBE_MASK);

		OUTSIDE_BEZEL_MASK = 1 - INSIDE_BEZEL_MASK;
		OUTSIDE_FRAME_MASK = 1 - HSM_GetCornerMask(FRAME_OUTSIDE_CURVED_COORD, TUBE_DIFFUSE_ASPECT, HSM_FRM_OUTER_CORNER_RADIUS, 1);

		FRAME_MASK = OUTSIDE_BEZEL_MASK * (1 - OUTSIDE_FRAME_MASK);

		if ( HSM_RENDER_SIMPLE_MODE == RENDER_SIMPLE_MODE_BLACK_SCREEN )
			FragColor = HSM_PreMultAlphaBlend(FragColor, vec4(0, 0, 0, 1) * (TUBE_MASK));

		if ( HSM_RENDER_SIMPLE_MODE == RENDER_SIMPLE_MODE_BLACK_SCREEN_AND_BG )
			FragColor = HSM_PreMultAlphaBlend(FragColor, vec4(0, 0, 0, 1) * (TUBE_MASK + OUTSIDE_FRAME_MASK));

		if ( HSM_RENDER_SIMPLE_MODE == RENDER_SIMPLE_MODE_PINK_MASK )
		{
			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_SCREEN )
				FragColor = HSM_PreMultAlphaBlend(FragColor, vec4(1, 0, 1, 1) * (TUBE_DIFFUSE_MASK));

			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_TUBE )
				FragColor = HSM_PreMultAlphaBlend(FragColor, vec4(1, 0, 1, 1) * (TUBE_MASK));

			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_BEZEL_AND_FRAME )
				FragColor = HSM_PreMultAlphaBlend(FragColor, vec4(1, 0, 1, 1) * (TUBE_MASK + OUTSIDE_FRAME_MASK));

			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_BEZEL )
				FragColor = HSM_PreMultAlphaBlend(FragColor, vec4(1, 0, 1, 1) * (1 - BEZEL_MASK));

			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_FRAME )
				FragColor = HSM_PreMultAlphaBlend(FragColor, vec4(1, 0, 1, 1) * (1 - FRAME_MASK));
		}
		if ( HSM_RENDER_SIMPLE_MODE == RENDER_SIMPLE_MODE_BLACK_WHITE_MASK )
		{
			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_SCREEN )
				FragColor = vec4(1 - TUBE_DIFFUSE_MASK);

			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_TUBE )
				FragColor = vec4(1 - TUBE_MASK);

			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_BEZEL_AND_FRAME )
				FragColor = vec4(1 - TUBE_MASK) - OUTSIDE_FRAME_MASK;

			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_BEZEL )
				FragColor = vec4(BEZEL_MASK);

			if ( HSM_RENDER_SIMPLE_MASK_TYPE == RENDER_SIMPLE_MASK_TYPE_FRAME )
				FragColor = vec4(FRAME_MASK);
		}
	}
	if (UNFLIPPED_VIEWPORT_COORD.x < (2 / global.OutputSize.x) && UNFLIPPED_VIEWPORT_COORD.y < (2 / global.OutputSize.y))
		FragColor = vec4(0.01, 0.01, 0.01, -1);
		
	return;
}
































