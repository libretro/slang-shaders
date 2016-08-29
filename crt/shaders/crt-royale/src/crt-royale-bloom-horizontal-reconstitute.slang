#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	vec4 ORIG_LINEARIZEDSize;
	vec4 HALATION_BLURSize;
	vec4 MASKED_SCANLINESSize;
	vec4 BRIGHTPASSSize;
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
#include "bloom-functions.h"
#include "phosphor-mask-resizing.h"
#include "scanline-functions.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 video_uv;
layout(location = 1) out vec2 scanline_tex_uv;
layout(location = 2) out vec2 halation_tex_uv;
layout(location = 3) out vec2 brightpass_tex_uv;
layout(location = 4) out vec2 bloom_tex_uv;
layout(location = 5) out vec2 bloom_dxdy;
layout(location = 6) out float bloom_sigma_runtime;

void main()
{
   gl_Position = params.MVP * Position;
   video_uv = TexCoord;
   
    //  Our various input textures use different coords:
    scanline_tex_uv = video_uv * registers.MASKED_SCANLINESSize.xy *
        registers.MASKED_SCANLINESSize.zw;
    halation_tex_uv = video_uv * registers.HALATION_BLURSize.xy *
        registers.HALATION_BLURSize.zw;
    brightpass_tex_uv = video_uv * registers.BRIGHTPASSSize.xy *
        registers.BRIGHTPASSSize.zw;
    bloom_tex_uv = TexCoord;

    //  We're horizontally blurring the bloom input (vertically blurred
    //  brightpass).  Get the uv distance between output pixels / input texels
    //  in the horizontal direction (this pass must NOT resize):
    bloom_dxdy = vec2(registers.SourceSize.z, 0.0);

    //  Calculate a runtime bloom_sigma in case it's needed:
    const float mask_tile_size_x = get_resized_mask_tile_size(
        registers.OutputSize.xy, registers.OutputSize.xy * mask_resize_viewport_scale, false).x;
    bloom_sigma_runtime = get_min_sigma_to_blur_triad(
        mask_tile_size_x / mask_triads_per_tile, bloom_diff_thresh);
}

#pragma stage fragment
layout(location = 0) in vec2 video_uv;
layout(location = 1) in vec2 scanline_tex_uv;
layout(location = 2) in vec2 halation_tex_uv;
layout(location = 3) in vec2 brightpass_tex_uv;
layout(location = 4) in vec2 bloom_tex_uv;
layout(location = 5) in vec2 bloom_dxdy;
layout(location = 6) in float bloom_sigma_runtime;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D MASKED_SCANLINES;
layout(set = 0, binding = 4) uniform sampler2D HALATION_BLUR;
layout(set = 0, binding = 5) uniform sampler2D BRIGHTPASS;

void main()
{
//  Blur the vertically blurred brightpass horizontally by 9/17/25/43x:
    const float bloom_sigma = get_final_bloom_sigma(bloom_sigma_runtime);
    const vec3 blurred_brightpass = tex2DblurNfast(Source,
        bloom_tex_uv, bloom_dxdy, bloom_sigma);

//  Sample the masked scanlines.  Alpha contains the auto-dim factor:
    const vec3 intensity_dim =
        tex2D_linearize(MASKED_SCANLINES, scanline_tex_uv).rgb;
    const float auto_dim_factor = levels_autodim_temp;
    const float undim_factor = 1.0/auto_dim_factor;
	
	//  Calculate the mask dimpass, add it to the blurred brightpass, and
    //  undim (from scanline auto-dim) and amplify (from mask dim) the result:
    const float mask_amplify = get_mask_amplify();
    const vec3 brightpass = tex2D_linearize(BRIGHTPASS,
        brightpass_tex_uv).rgb;
    const vec3 dimpass = intensity_dim - brightpass;
    const vec3 phosphor_bloom = (dimpass + blurred_brightpass) *
        mask_amplify * undim_factor * levels_contrast;
		
	//  Sample the halation texture, and let some light bleed into refractive
    //  diffusion.  Conceptually this occurs before the phosphor bloom, but
    //  adding it in earlier passes causes black crush in the diffusion colors.
    const vec3 diffusion_color = levels_contrast * tex2D_linearize(
        HALATION_BLUR, halation_tex_uv).rgb;
    const vec3 final_bloom = mix(phosphor_bloom,
        diffusion_color, diffusion_weight);
		
	//  Encode and output the bloomed image:
   FragColor = encode_output(vec4(final_bloom, 1.0));
}