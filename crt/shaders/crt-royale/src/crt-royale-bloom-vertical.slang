#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
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

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 tex_uv;
layout(location = 1) out vec2 bloom_dxdy;
layout(location = 2) out float bloom_sigma_runtime;

void main()
{
   gl_Position = params.MVP * Position;
   tex_uv = TexCoord;
   
    //  Get the uv sample distance between output pixels.  Calculate dxdy like
    //  blurs/vertex-shader-blur-fast-vertical.h.
    const vec2 dxdy_scale = registers.SourceSize.xy * registers.OutputSize.zw;
    const vec2 dxdy = dxdy_scale * registers.SourceSize.zw;
    //  This blur is vertical-only, so zero out the vertical offset:
    bloom_dxdy = vec2(0.0, dxdy.y);

    //  Calculate a runtime bloom_sigma in case it's needed:
    const float mask_tile_size_x = get_resized_mask_tile_size(
        registers.OutputSize.xy, registers.OutputSize.xy * mask_resize_viewport_scale, false).x;
    bloom_sigma_runtime = get_min_sigma_to_blur_triad(
        mask_tile_size_x / mask_triads_per_tile, bloom_diff_thresh);
}

#pragma stage fragment
layout(location = 0) in vec2 tex_uv;
layout(location = 1) in vec2 bloom_dxdy;
layout(location = 2) in float bloom_sigma_runtime;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    //  Blur the brightpass horizontally with a 9/17/25/43x blur:
    const float bloom_sigma = get_final_bloom_sigma(bloom_sigma_runtime);
    const vec3 color = tex2DblurNfast(Source, tex_uv,
        bloom_dxdy, bloom_sigma);
    //  Encode and output the blurred image:
   FragColor = encode_output(vec4(color, 1.0));
}