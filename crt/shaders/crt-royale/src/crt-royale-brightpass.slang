#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	vec4 MASKED_SCANLINESSize;
	vec4 BLOOM_APPROXSize;
} registers;

#include "params.inc"

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA


/////////////////////////////  SETTINGS MANAGEMENT  ////////////////////////////

#include "../user-settings.h"
#include "derived-settings-and-constants.h"
#include "bind-shader-params.h"


//////////////////////////////////  INCLUDES  //////////////////////////////////

#include "../../../../include/gamma-management.h"
#include "../../../../include/blur-functions.h"
#include "phosphor-mask-resizing.h"
#include "scanline-functions.h"
#include "bloom-functions.h"


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 video_uv;
layout(location = 1) out vec2 scanline_tex_uv;
layout(location = 2) out float bloom_sigma_runtime;
layout(location = 3) out vec2 blur3x3_tex_uv;

void main()
{
   gl_Position = params.MVP * Position;
   const vec2 tex_uv = TexCoord;
    //  Our various input textures use different coords:
    video_uv = tex_uv;
    scanline_tex_uv = video_uv * registers.MASKED_SCANLINESSize.xy *
        registers.MASKED_SCANLINESSize.zw;
    blur3x3_tex_uv = video_uv * registers.BLOOM_APPROXSize.xy * registers.BLOOM_APPROXSize.zw;

    //  Calculate a runtime bloom_sigma in case it's needed:
    const float mask_tile_size_x = get_resized_mask_tile_size(
        registers.OutputSize.xy, registers.OutputSize.xy * mask_resize_viewport_scale, false).x;
    bloom_sigma_runtime = get_min_sigma_to_blur_triad(
        mask_tile_size_x / mask_triads_per_tile, bloom_diff_thresh);
}

#pragma stage fragment
layout(location = 0) in vec2 video_uv;
layout(location = 1) in vec2 scanline_tex_uv;
layout(location = 2) in float bloom_sigma_runtime;
layout(location = 3) in vec2 blur3x3_tex_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D MASKED_SCANLINES;
layout(set = 0, binding = 4) uniform sampler2D BLOOM_APPROX;

void main()
{
	//  Sample the masked scanlines:
    const vec3 intensity_dim =
        tex2D_linearize(MASKED_SCANLINES, scanline_tex_uv).rgb;
    //  Get the full intensity, including auto-undimming, and mask compensation:
    const float auto_dim_factor = levels_autodim_temp;
    const float undim_factor = 1.0/auto_dim_factor;
    const float mask_amplify = get_mask_amplify();
    const vec3 intensity = intensity_dim * undim_factor * mask_amplify *
        levels_contrast;
		
	//  Sample BLOOM_APPROX to estimate what a straight blur of masked scanlines
    //  would look like, so we can estimate how much energy we'll receive from
    //  blooming neighbors:
    const vec3 phosphor_blur_approx = levels_contrast * tex2D_linearize(
        BLOOM_APPROX, blur3x3_tex_uv).rgb;
		
	//  Compute the blur weight for the center texel and the maximum energy we
    //  expect to receive from neighbors:
    const float bloom_sigma = get_final_bloom_sigma(bloom_sigma_runtime);
    const float center_weight = get_center_weight(bloom_sigma);
    const vec3 max_area_contribution_approx =
        max(vec3(0.0), phosphor_blur_approx - center_weight * intensity);
		
	//  Assume neighbors will blur 100% of their intensity (blur_ratio = 1.0),
    //  because it actually gets better results (on top of being very simple),
    //  but adjust all intensities for the user's desired underestimate factor:
    const vec3 area_contrib_underestimate =
        bloom_underestimate_levels * max_area_contribution_approx;
    const vec3 intensity_underestimate =
        bloom_underestimate_levels * intensity;
		
	//  Calculate the blur_ratio, the ratio of intensity we want to blur:
    #ifdef BRIGHTPASS_AREA_BASED
        //  This area-based version changes blur_ratio more smoothly and blurs
        //  more, clipping less but offering less phosphor differentiation:
        const vec3 phosphor_blur_underestimate = bloom_underestimate_levels *
            phosphor_blur_approx;
        const vec3 soft_intensity = max(intensity_underestimate,
            phosphor_blur_underestimate * mask_amplify);
        const vec3 blur_ratio_temp =
            ((vec3(1.0) - area_contrib_underestimate) /
            soft_intensity - vec3(1.0)) / (center_weight - 1.0);
    #else
        const vec3 blur_ratio_temp =
            ((vec3(1.0) - area_contrib_underestimate) /
            intensity_underestimate - vec3(1.0)) / (center_weight - 1.0);
    #endif
	
	const vec3 blur_ratio = clamp(blur_ratio_temp, 0.0, 1.0);
    //  Calculate the brightpass based on the auto-dimmed, unamplified, masked
    //  scanlines, encode if necessary, and return!
    const vec3 brightpass = intensity_dim *
        mix(blur_ratio, vec3(1.0), bloom_excess);
		
   FragColor = encode_output(vec4(brightpass, 1.0));
}