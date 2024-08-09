#version 450

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

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	vec4 VERTICAL_SCANLINESSize;
	vec4 MASK_RESIZESize;
} params;

#define VERTICAL_SCANLINEStexture VERTICAL_SCANLINES
#define VERTICAL_SCANLINEStexture_size params.VERTICAL_SCANLINESSize.xy
#define VERTICAL_SCANLINESvideo_size params.VERTICAL_SCANLINESSize.xy
#define MASK_RESIZEtexture MASK_RESIZE
#define MASK_RESIZEtexture_size params.MASK_RESIZESize.xy
#define MASK_RESIZEvideo_size params.MASK_RESIZESize.xy

float bloom_approx_scale_x = params.OutputSize.x / params.SourceSize.y;
float max_viewport_size_x = 1080.0*1024.0*(4.0/3.0);

/////////////////////////////  SETTINGS MANAGEMENT  ////////////////////////////

#include "bind-shader-params.h"

///////////////////////////////  VERTEX INCLUDES  ///////////////////////////////

#include "scanline-functions.h"
#include "phosphor-mask-resizing.h"

///////////////////////////////////  HELPERS  //////////////////////////////////

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 video_uv;
layout(location = 1) out vec2 scanline_texture_size_inv;
layout(location = 2) out vec4 mask_tile_start_uv_and_size;
layout(location = 3) out vec2 mask_tiles_per_screen;

void main()
{
   gl_Position = global.MVP * Position;
    video_uv = TexCoord;

    scanline_texture_size_inv = vec2(1.0, 1.0)/VERTICAL_SCANLINEStexture_size;

    //  Get a consistent name for the final mask texture size.  Sample mode 0
    //  uses the manually resized mask, but ignore it if we never resized.
    vec2 mask_resize_texture_size = MASK_RESIZEtexture_size;
    vec2 mask_resize_video_size = MASK_RESIZEvideo_size;

    //  Compute mask tile dimensions, starting points, etc.:
    mask_tile_start_uv_and_size = get_mask_sampling_parameters(mask_resize_texture_size, mask_resize_video_size, params.OutputSize.xy, mask_tiles_per_screen);
}

#pragma stage fragment
layout(location = 0) in vec2 video_uv;
layout(location = 1) in vec2 scanline_texture_size_inv;
layout(location = 2) in vec4 mask_tile_start_uv_and_size;
layout(location = 3) in vec2 mask_tiles_per_screen;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D VERTICAL_SCANLINES;
layout(set = 0, binding = 4) uniform sampler2D MASK_RESIZE;

//////////////////////////////  FRAGMENT INCLUDES  //////////////////////////////

void main()
{
    //  This pass: Sample (misconverged?) scanlines to the final horizontal
    //  resolution, apply halation (bouncing electrons), and apply the phosphor
    //  mask.  Fake a bloom if requested.  Unless we fake a bloom, the output
    //  will be dim from the scanline auto-dim, mask dimming, and low gamma.

    //  Horizontally sample the current row (a vertically interpolated scanline)
    //  and account for horizontal convergence offsets, given in units of texels.
    vec3 scanline_color_dim = sample_rgb_scanline_horizontal(VERTICAL_SCANLINEStexture, video_uv, VERTICAL_SCANLINEStexture_size, scanline_texture_size_inv);

    //  Sample the phosphor mask:
    vec2 tile_uv_wrap = video_uv * mask_tiles_per_screen;

    vec2 mask_tex_uv = convert_phosphor_tile_uv_wrap_to_tex_uv(tile_uv_wrap, mask_tile_start_uv_and_size);

    vec3 phosphor_mask_sample;

    //  Sample the resized mask, and avoid tiling artifacts:
    phosphor_mask_sample = texture(MASK_RESIZEtexture, mask_tex_uv).rgb;

    //  Apply the phosphor mask:
    vec3 phosphor_emission_dim = scanline_color_dim * phosphor_mask_sample;

    FragColor = vec4(phosphor_emission_dim, 1.0);
}
