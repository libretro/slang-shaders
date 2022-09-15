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

#include "../base/common/common-functions-bezel.inc"

#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;
layout(location = 7) out vec2 UNFLIPPED_VIEWPORT_COORD;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord * 1.00001;

	UNFLIPPED_VIEWPORT_COORD = vTexCoord;
}

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 7) in vec2 UNFLIPPED_VIEWPORT_COORD;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D Source;

layout(set = 0, binding = 2) uniform sampler2D InfoCachePass;
layout(set = 0, binding = 3) uniform sampler2D InfoCachePassFeedback;

layout(set = 0, binding = 4) uniform sampler2D TubeDiffuseImage;
layout(set = 0, binding = 5) uniform sampler2D TubeShadowImage;
layout(set = 0, binding = 6) uniform sampler2D TubeColoredGelImage;
layout(set = 0, binding = 7) uniform sampler2D TubeStaticReflectionImage;

layout(set = 0, binding = 8) uniform sampler2D BackgroundImage;
layout(set = 0, binding = 9) uniform sampler2D BackgroundVertImage;

layout(set = 0, binding = 10) uniform sampler2D NightLightingImage;
layout(set = 0, binding = 11) uniform sampler2D NightLighting2Image;
layout(set = 0, binding = 12) uniform sampler2D IntroPass;

layout(set = 0, binding = 13) uniform sampler2D MBZ_PostCRTPassFeedback;
#define PassFeedback MBZ_PostCRTPassFeedback

// Torridgristle - ScanlineSimple pass - Public domain
vec4 HSM_ApplyScanlineMask(vec4 in_color, vec2 screen_scale, vec2 in_coord, vec2 in_curved_coord, float in_scanline_opacity)
{
	//   Stuff to try implementing
    //   Try mame hlsl darkening
    //   Check Lottes tone mapping

	in_coord = mix(in_coord, in_curved_coord, HSM_FAKE_SCANLINE_CURVATURE);

    /* Scanlines */
	float scanline_roll_offset = float(mod(global.FrameCount, 1280)) / 1280 * HSM_FAKE_SCANLINE_ROLL; 

    // float scans = clamp( 0.35+0.18*sin(6.0*time-curved_uv.y*resolution.y*1.5), 0.0, 1.0);
    // float s = pow(scans,0.9);
    // col = col * vec3(s);

	float scan_axis_pos = USE_VERTICAL_SCANLINES * in_coord.x + (1 - USE_VERTICAL_SCANLINES) * in_coord.y;
	scan_axis_pos += scanline_roll_offset;

	vec2 screen_size = global.OutputSize.xy * screen_scale;
	float scan_axis_screen_scale_res = USE_VERTICAL_SCANLINES * screen_size.x + (1 - USE_VERTICAL_SCANLINES) * screen_size.y;
	
	float simulated_scanline_res = HSM_FAKE_SCANLINE_RES_MODE > 0.5 ? HSM_FAKE_SCANLINE_RES : CROPPED_ROTATED_SIZE.y;

	float scanline_size = scan_axis_screen_scale_res / simulated_scanline_res;

	if (HSM_FAKE_SCANLINE_INT_SCALE == 1)
		scanline_size = ceil(scanline_size);

	float scan = mod(scan_axis_pos * scan_axis_screen_scale_res, scanline_size) / scanline_size;

	// Alternate, modulating the scanline width depending on brightness
	//float scanline_mask = HHLP_EasePowerOut(1 - abs(scan - 0.5) * 2, 0.5 + 2 * smoothstep(0.4, 0.9, (in_color.r + in_color.g +  in_color.b) / 3));
	float color_brightness_modulation = HHLP_EasePowerOut(smoothstep(0.4, 0.99, (in_color.r + in_color.g +  in_color.b) / 3), 2);

	float scanline_mask = 1 - abs(scan - 0.5) * 2;
	scanline_mask = pow(1 - scanline_mask, 1);

	float final_scanline_mask = clamp(1 * scanline_mask, 0, 1);

	color_brightness_modulation = HHLP_EasePowerOut(smoothstep(0.4, HSM_FAKE_SCANLINE_BRIGHTNESS_CUTOFF + 1.5, (in_color.r + in_color.g +  in_color.b) / 3), 2);
	final_scanline_mask = clamp(mix(1, mix(final_scanline_mask, 1, color_brightness_modulation), in_scanline_opacity), 0, 1);

	vec4 masked_color = in_color;
	masked_color *= 1 + 0.5 * in_scanline_opacity;
	masked_color = clamp(final_scanline_mask * masked_color, 0, 1);
	masked_color.w = in_color.w;

	return clamp(masked_color, 0, 1);
}

vec4 HSM_GetPostCrtPreppedColor(vec4 in_color_with_gamma, vec2 VIEWPORT_COORD, vec2 screen_curved_coord, in sampler2D source_pass, bool source_is_linear, in sampler2D TubeDiffuseImage, in sampler2D TubeColoredGelImage, in sampler2D TubeStaticReflectionImage, in sampler2D BackgroundImage, in sampler2D BackgroundVertImage, in sampler2D NightLightingImage, in sampler2D NightLighting2Image)
{
	if (HSM_MONOCHROME_MODE > 0.5 && HSM_GetUseOnCurrentScreenIndex(HSM_MONOCHROME_DUALSCREEN_VIS_MODE))
		in_color_with_gamma = HSM_ApplyMonochrome(in_color_with_gamma);

	vec4 out_color = HSM_Linearize(in_color_with_gamma, DEFAULT_SRGB_GAMMA);
	out_color *= HSM_POST_CRT_BRIGHTNESS;

	vec2 mirrored_screen_coord = HSM_GetMirrorWrappedCoord(screen_curved_coord);

	// TODO we see artifacts of the reflection at the edge of the screen when there is extra tube thickness and the reflection is scaled
	float screen_mask = HSM_GetCornerMask((screen_curved_coord - 0.5) * 0.999 + 0.5, SCREEN_ASPECT, HSM_GLOBAL_CORNER_RADIUS * HSM_SCREEN_CORNER_RADIUS_SCALE, 0.9);
						
	vec2 tube_curved_coord = HSM_GetTubeCurvedCoord(TUBE_DIFFUSE_COORD, 1, TUBE_DIFFUSE_SCALE, TUBE_SCALE, TUBE_DIFFUSE_ASPECT, 1);
	vec2 mirrored_tube_coord = HSM_GetMirrorWrappedCoord(tube_curved_coord);
	
	float vignette_factor = HSM_GetScreenVignetteFactor(mirrored_tube_coord);
	if (HSM_GetUseScreenVignette())
	{
		float vignette_factor_outside_screen = HSM_SCREEN_VIGNETTE_IN_REFLECTION * vignette_factor + (1 - HSM_SCREEN_VIGNETTE_IN_REFLECTION) * 1;
		vignette_factor = screen_mask * vignette_factor + (1 - screen_mask) * vignette_factor_outside_screen;

		out_color *= vignette_factor;
	}

	if (HSM_AB_COMPARE_SHOW_MODE == 1 && HSM_GetIsInABCompareArea(VIEWPORT_COORD))
	{
		vec2 ab_screen_coord = HSM_CRT_CURVATURE_SCALE * screen_curved_coord + (1 - HSM_CRT_CURVATURE_SCALE) * SCREEN_COORD;
		ab_screen_coord = HSM_GetMirrorWrappedCoord(ab_screen_coord);

		vec4 source_color = HSM_GetCroppedTexSample(source_pass, ab_screen_coord);
		if (!source_is_linear)
			source_color = HSM_Linearize(source_color, GAMMA_INPUT);
		source_color = HSM_Delinearize(source_color, HSM_GAMMA_OUT_CRT);
		source_color = HSM_Linearize(source_color, DEFAULT_SRGB_GAMMA);

		out_color = source_color;
	}

	float scan_axis_res = USE_VERTICAL_SCANLINES * CROPPED_ROTATED_SIZE_WITH_RES_MULT.x + (1 - USE_VERTICAL_SCANLINES) * CROPPED_ROTATED_SIZE_WITH_RES_MULT.y;

	if (HSM_FAKE_SCANLINE_OPACITY > 0.001 && (HSM_FAKE_SCANLINE_MODE == 1 || (HSM_FAKE_SCANLINE_MODE == 2 && scan_axis_res > HSM_INTERLACE_TRIGGER_RES)))
	{
		vec4 scanline_masked_color = HSM_ApplyScanlineMask(out_color, SCREEN_SCALE, SCREEN_COORD, screen_curved_coord, HSM_FAKE_SCANLINE_OPACITY);
		
		// Darken the outside image a bit
		out_color = mix(out_color, out_color * 0.9, HSM_FAKE_SCANLINE_OPACITY);

		// Show scanlines only in the tube area
		float tube_highlight_mask = HSM_GetCornerMask((tube_curved_coord - 0.5) * 0.995 + 0.5 , TUBE_DIFFUSE_ASPECT, HSM_BZL_INNER_CORNER_RADIUS_SCALE * HSM_GLOBAL_CORNER_RADIUS, 0.05);
		out_color = mix(out_color, scanline_masked_color, tube_highlight_mask);
	}
	
	float bezel_corner_radius = HSM_BZL_INNER_CORNER_RADIUS_SCALE * HSM_GLOBAL_CORNER_RADIUS;
	if(HSM_BZL_USE_INDEPENDENT_CURVATURE > 0)
		bezel_corner_radius = HSM_BZL_INNER_CORNER_RADIUS_SCALE * DEFAULT_SCREEN_CORNER_RADIUS;

	float tube_mask =  HSM_GetCornerMask(tube_curved_coord, TUBE_DIFFUSE_ASPECT, bezel_corner_radius, 0.99);
	float screen_to_tube_mask_invert = 1 - (tube_mask - screen_mask);

	float black_edge_corner_radius = HSM_TUBE_BLACK_EDGE_CORNER_RADIUS_SCALE * HSM_GLOBAL_CORNER_RADIUS;
	vec2 tube_diffuse_curved_coord = HSM_GetTubeCurvedCoord(TUBE_DIFFUSE_COORD, HSM_TUBE_BLACK_EDGE_CURVATURE_SCALE, TUBE_DIFFUSE_SCALE, TUBE_SCALE, TUBE_DIFFUSE_ASPECT, 0);
	float tube_diffuse_mask =  HSM_GetCornerMask(tube_diffuse_curved_coord, TUBE_DIFFUSE_ASPECT, black_edge_corner_radius, 0.99);

	// float black_edge_mask_invert = 1 - (tube_mask - tube_diffuse_mask);
	float black_edge_mask_invert = 1 - (tube_mask - tube_diffuse_mask);

	out_color *= screen_to_tube_mask_invert;

	// AMBIENT LIGHTING IMAGES
	vec4 ambient_lighting_image = vec4(1);
	vec4 ambient2_lighting_image = vec4(1);
	HSM_Fill_Ambient_Images(VIEWPORT_COORD, 
							VIEWPORT_UNSCALED_COORD, 
							TUBE_DIFFUSE_COORD_MIXED_POS, 
							TUBE_DIFFUSE_SCALE_1ST_SCREEN, 
							HSM_AMBIENT_LIGHTING_SWAP_IMAGE_MODE, 
							NightLightingImage, 
							NightLighting2Image, 
							ambient_lighting_image, 
							ambient2_lighting_image);

	vec3 tube_shadow = vec3(1);
	if (HSM_TUBE_SHADOW_IMAGE_ON > 0.5 && (HSM_GetUseTubeDiffuseImage() || HSM_GetUseTubeColoredGelImage() || HSM_GetUseTubeStaticReflection()))
	{
		vec2 shadow_coord = tube_diffuse_curved_coord;
		shadow_coord = HSM_GetMirrorWrappedCoord(shadow_coord);

		// TODO Shadow Coordinate isn't right with 3D Curvature

		shadow_coord.x = (shadow_coord.x - HSM_TUBE_SHADOW_IMAGE_POS_X - 0.5) / HSM_TUBE_SHADOW_IMAGE_SCALE_X + 0.5;
		shadow_coord.y = (shadow_coord.y + HSM_TUBE_SHADOW_IMAGE_POS_Y) / HSM_TUBE_SHADOW_IMAGE_SCALE_Y;

		vec2 curvature_values = HSM_TUBE_SHADOW_CURVATURE_SCALE * HSM_GetCurvatureValues(TUBE_DIFFUSE_ASPECT);
		shadow_coord = HSM_Get2DCurvedCoord(shadow_coord, curvature_values);

		shadow_coord.x = HSM_FLIP_VIEWPORT_HORIZONTAL * (shadow_coord.x - 0.5) + 0.5;
		shadow_coord.y = HSM_FLIP_VIEWPORT_VERTICAL * (shadow_coord.y - 0.5) + 0.5;
		

		vec4 tube_shadow_sample = HSM_GetMipmappedTexSample(TubeShadowImage, shadow_coord, TUBE_SCALE * vec2(HSM_TUBE_SHADOW_IMAGE_SCALE_X, HSM_TUBE_SHADOW_IMAGE_SCALE_Y), 0);
		tube_shadow_sample = HSM_GLOBAL_GRAPHICS_BRIGHTNESS * HSM_GetPreMultipliedColorLinear(tube_shadow_sample, SOURCE_MATTE_PREMULTIPLIED, DEFAULT_SRGB_GAMMA);

		tube_shadow = (1 - HSM_TUBE_SHADOW_IMAGE_OPACITY) + HSM_TUBE_SHADOW_IMAGE_OPACITY * tube_shadow_sample.rgb;
	}

	// If the crt blend mode is multiply then use the diffuse image
	float tube_diffuse_mode = HSM_CRT_BLEND_MODE == 2 ? 1 : HSM_TUBE_DIFFUSE_MODE;
	vec4 tube_diffuse = vec4(0, 0, 0, 1);
	float adjusted_tube_diffuse_amount = HSM_TUBE_DIFFUSE_MODE == 0 ? 0 : HSM_TUBE_DIFFUSE_IMAGE_AMOUNT;

	if (tube_diffuse_mode == 2)
	{
		// Do something if the tube is supposed to be transparent here
	}
	if (tube_diffuse_mode == 1)
	{
		// TubeDiffuseImage
		if (adjusted_tube_diffuse_amount > 0 || HSM_CRT_BLEND_MODE == 2)
		{
			vec2 diffuse_coord = tube_diffuse_curved_coord;

			diffuse_coord = HSM_GetMirrorWrappedCoord(diffuse_coord);
			diffuse_coord.x = HSM_FLIP_VIEWPORT_HORIZONTAL * (diffuse_coord.x - 0.5) + 0.5;
			diffuse_coord.y = HSM_FLIP_VIEWPORT_VERTICAL * (diffuse_coord.y - 0.5) + 0.5;

			diffuse_coord = (diffuse_coord - 0.5) / (HSM_TUBE_DIFFUSE_IMAGE_SCALE * vec2(HSM_TUBE_DIFFUSE_IMAGE_SCALE_X, 1)) + 0.5;

			tube_diffuse = HSM_GetMipmappedTexSample(TubeDiffuseImage, diffuse_coord, TUBE_SCALE * HSM_TUBE_DIFFUSE_IMAGE_SCALE, 0);
			tube_diffuse.rgb = HSM_GLOBAL_GRAPHICS_BRIGHTNESS * HSM_GetPreMultipliedColorLinear(vec4(tube_diffuse.rgb, 1), SOURCE_MATTE_PREMULTIPLIED, DEFAULT_SRGB_GAMMA).rgb;
			tube_diffuse.rgb = HSM_ApplyHSVAdjustment(tube_diffuse.rgb, HSM_TUBE_DIFFUSE_IMAGE_HUE, HSM_TUBE_DIFFUSE_IMAGE_SATURATION, HSM_TUBE_DIFFUSE_IMAGE_BRIGHTNESS, HSM_TUBE_DIFFUSE_IMAGE_COLORIZE_ON, HSM_TUBE_DIFFUSE_IMAGE_GAMMA);
			tube_diffuse.rgb *= HSM_TUBE_DIFFUSE_IMAGE_AMOUNT;

			tube_diffuse.rgb *= tube_shadow;
		}

		// If CRT Blend Mode is Multiply (2) then the tube must be fully opaque
		tube_diffuse *= HSM_GetTubeDiffuseOpacity();
		tube_diffuse.rgb = HSM_ApplyAmbientImage(tube_diffuse.rgb, ambient_lighting_image.rgb, HSM_TUBE_DIFFUSE_IMAGE_AMBIENT_LIGHTING);
		tube_diffuse.rgb = HSM_ApplyAmbientImage(tube_diffuse.rgb, ambient2_lighting_image.rgb, HSM_TUBE_DIFFUSE_IMAGE_AMBIENT2_LIGHTING);

		// TODO see what to do when its transparent
	}
	out_color.a = in_color_with_gamma.a;

	// Don't apply the CRT images
	if (HSM_CRT_BLEND_MODE == 0)
		out_color = tube_diffuse;

	// Apply the CRT image additively to the tube diffuse color
	if (HSM_CRT_BLEND_MODE == 1)
		out_color = HSM_BlendModeLayerMix(tube_diffuse, out_color, BLEND_MODE_ADD, HSM_CRT_BLEND_AMOUNT);

	// Apply the CRT image with multiply blending
	if (HSM_CRT_BLEND_MODE == 2)
	{	
		out_color = clamp(out_color, 0, 1);
		out_color = HSM_BlendModeLayerMix(tube_diffuse, out_color, BLEND_MODE_MULTIPLY, HSM_CRT_BLEND_AMOUNT);
	}

	// Add a Colored Gel image on top of the screen, this is what colors games like space invaders or battlezone
	if (HSM_GetUseTubeColoredGelImage())
	{
		vec2 gel_coord = HSM_GetMirrorWrappedCoord(tube_diffuse_curved_coord);
		gel_coord.x = HSM_TUBE_COLORED_GEL_IMAGE_FLIP_HORIZONTAL * (gel_coord.x - 0.5) + 0.5;
		gel_coord.y = HSM_TUBE_COLORED_GEL_IMAGE_FLIP_VERTICAL * (gel_coord.y - 0.5) + 0.5;
		gel_coord = (gel_coord - 0.5) / HSM_TUBE_COLORED_GEL_IMAGE_SCALE + 0.5;
		vec4 gel_image = HSM_GetMipmappedTexSample(TubeColoredGelImage, gel_coord, TUBE_SCALE, 0);

		gel_image = HSM_GLOBAL_GRAPHICS_BRIGHTNESS * HSM_Linearize(gel_image, DEFAULT_SRGB_GAMMA);

		if (HSM_TUBE_COLORED_GEL_IMAGE_MULTIPLY_AMOUNT > 0)
			out_color = mix(out_color, out_color * gel_image, HSM_TUBE_COLORED_GEL_IMAGE_MULTIPLY_AMOUNT);

		if (HSM_TUBE_COLORED_GEL_IMAGE_ADDITIVE_AMOUNT > 0)
			out_color = mix(out_color, out_color + gel_image, HSM_TUBE_COLORED_GEL_IMAGE_ADDITIVE_AMOUNT);

		if (HSM_TUBE_COLORED_GEL_IMAGE_NORMAL_AMOUNT > 0)
		{
			gel_image.a = clamp( gel_image.a - HSM_TUBE_COLORED_GEL_IMAGE_TRANSPARENCY_THRESHOLD, 0, 1 ) / (1 - HSM_TUBE_COLORED_GEL_IMAGE_TRANSPARENCY_THRESHOLD);
			gel_image.rgb *= HSM_TUBE_COLORED_GEL_IMAGE_NORMAL_BRIGHTNESS;
			gel_image.rgb *= tube_shadow;

			if (HSM_TUBE_COLORED_GEL_IMAGE_FAKE_SCANLINE_AMOUNT > 0.001)
				gel_image.rgb = HSM_ApplyScanlineMask(gel_image, SCREEN_SCALE, SCREEN_COORD, screen_curved_coord, HSM_TUBE_COLORED_GEL_IMAGE_FAKE_SCANLINE_AMOUNT).rgb;

			gel_image.rgb = HSM_ApplyAmbientImage(gel_image.rgb, ambient_lighting_image.rgb, HSM_TUBE_COLORED_GEL_IMAGE_AMBIENT_LIGHTING);
			gel_image.rgb = HSM_ApplyAmbientImage(gel_image.rgb, ambient2_lighting_image.rgb, HSM_TUBE_COLORED_GEL_IMAGE_AMBIENT2_LIGHTING);

			gel_image = HSM_BlendModeLayerMix(gel_image, vec4(vec3(vignette_factor), 1), BLEND_MODE_MULTIPLY, HSM_TUBE_COLORED_GEL_IMAGE_NORMAL_VIGNETTE);

			if ( HSM_SHOW_CRT_ON_TOP_OF_COLORED_GEL == 0 )
				out_color = HSM_BlendModeLayerMix(out_color, gel_image, BLEND_MODE_NORMAL, HSM_TUBE_COLORED_GEL_IMAGE_NORMAL_AMOUNT);
			
			if ( HSM_SHOW_CRT_ON_TOP_OF_COLORED_GEL == 1 )
			{
				gel_image.rgb *= tube_shadow;
				vec4 normal_blended = HSM_BlendModeLayerMix(vec4(0, 0, 0, 1), gel_image, BLEND_MODE_NORMAL, HSM_TUBE_COLORED_GEL_IMAGE_NORMAL_AMOUNT);
				out_color = normal_blended + out_color;
			}
		}
	} 

	#ifndef IS_NO_REFLECT_PRESET

	out_color *= black_edge_mask_invert;

	#else

	out_color *= tube_diffuse_mask;

	#endif

	if (HSM_GetUseTubeStaticReflection())
	{
		vec3 tube_highlight_image = HSM_GetTubeHighlight(tube_curved_coord, false, TubeStaticReflectionImage).rgb;
		tube_highlight_image = HSM_ApplyAmbientImage(tube_highlight_image.rgb, ambient_lighting_image.rgb, HSM_TUBE_STATIC_AMBIENT_LIGHTING);
		tube_highlight_image = HSM_ApplyAmbientImage(tube_highlight_image.rgb, ambient2_lighting_image.rgb, HSM_TUBE_STATIC_AMBIENT2_LIGHTING);

		tube_highlight_image.rgb *= HSM_TUBE_STATIC_SHADOW_OPACITY * tube_shadow + (1 - HSM_TUBE_STATIC_SHADOW_OPACITY);

		tube_highlight_image = clamp(HSM_TUBE_STATIC_BLACK_LEVEL * (tube_highlight_image - 1) + 1, 0, 1);

		tube_highlight_image *= 1 - HSM_TUBE_STATIC_OPACITY_DIFFUSE_MULTIPLY + HSM_TUBE_STATIC_OPACITY_DIFFUSE_MULTIPLY * adjusted_tube_diffuse_amount;

		out_color.rgb += tube_highlight_image * HSM_TUBE_STATIC_REFLECTION_IMAGE_OPACITY;
	}

	// #ifndef IS_NO_REFLECT_PRESET
	// Apply the final Gamma
	out_color = HSM_Delinearize(out_color, DEFAULT_SRGB_GAMMA);
	// #endif
	
	return out_color;
}


void main()
{
	if (HSM_AB_COMPARE_FREEZE_CRT_TUBE == 1 && HSM_GetIsInABCompareArea(vTexCoord))
	{
		FragColor = texture(PassFeedback, vTexCoord);
		return;
	}

	VIEWPORT_UNSCALED_COORD = HSM_GetViewportCoordWithFlip(vTexCoord);

	vec2 viewportCoordTransformed = HSM_GetViewportCoordWithZoomAndPan(vTexCoord);
	HSM_UpdateGlobalScreenValuesFromCache(InfoCachePass, InfoCachePassFeedback, vTexCoord);

	// Have to get the scale of the coordinates so we can figure out the size of the onscreen rectangle of the area 
	HSM_GetBezelCoords(TUBE_DIFFUSE_COORD, 
						TUBE_DIFFUSE_SCALE, 
						TUBE_SCALE, 
						TUBE_DIFFUSE_ASPECT, 
						false,
						BEZEL_OUTSIDE_SCALE,
						BEZEL_OUTSIDE_COORD, 
						BEZEL_OUTSIDE_CURVED_COORD, 
						FRAME_OUTSIDE_CURVED_COORD);

	FRAME_OUTSIDE_CURVED_COORD = (FRAME_OUTSIDE_CURVED_COORD - 0.5) * 0.9 + 0.5;
	if (FRAME_OUTSIDE_CURVED_COORD.x < -0.01 || FRAME_OUTSIDE_CURVED_COORD.x > 1.01 || FRAME_OUTSIDE_CURVED_COORD.y < -0.01 || FRAME_OUTSIDE_CURVED_COORD.y > 1.01)
	{
		FragColor = vec4(0);
		return;
	}

	vec2 screen_curved_coord = HSM_GetCurvedCoord(SCREEN_COORD, 1, SCREEN_ASPECT);

	FragColor = texture(Source, UNFLIPPED_VIEWPORT_COORD);

	FragColor = HSM_GetPostCrtPreppedColor(FragColor, vTexCoord, screen_curved_coord, IntroPass, false, TubeDiffuseImage, TubeColoredGelImage, TubeStaticReflectionImage, BackgroundImage, BackgroundVertImage, NightLightingImage, NightLighting2Image);
}
