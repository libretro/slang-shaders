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

#define LAST_PASS
#define SIMULATE_CRT_ON_LCD
#include "../user-settings.h"
#include "derived-settings-and-constants.h"
#include "bind-shader-params.h"

#ifndef DONT_DEFINE //RUNTIME_GEOMETRY_TILT
    //  Create a local-to-global rotation matrix for the CRT's coordinate frame
    //  and its global-to-local inverse.  See the vertex shader for details.
    //  It's faster to compute these statically if possible.
    const vec2 sin_tilt = sin(geom_tilt_angle_static);
    const vec2 cos_tilt = cos(geom_tilt_angle_static);
    const mat3x3 geom_local_to_global_static = mat3x3(
        cos_tilt.x, sin_tilt.y*sin_tilt.x, cos_tilt.y*sin_tilt.x,
        0.0, cos_tilt.y, -sin_tilt.y,
        -sin_tilt.x, sin_tilt.y*cos_tilt.x, cos_tilt.y*cos_tilt.x);
    const mat3x3 geom_global_to_local_static = mat3x3(
        cos_tilt.x, 0.0, -sin_tilt.x,
        sin_tilt.y*sin_tilt.x, cos_tilt.y, sin_tilt.y*cos_tilt.x,
        cos_tilt.y*sin_tilt.x, -sin_tilt.y, cos_tilt.y*cos_tilt.x);
#endif

//////////////////////////////////  INCLUDES  //////////////////////////////////

//#include "../../../../include/gamma-management.h"
#include "tex2Dantialias.h"
#include "geometry-functions.h"
#include "includes.h"

///////////////////////////////////  HELPERS  //////////////////////////////////

mat2x2 mul_scale(vec2 scale, mat2x2 matrix)
{
    //mat2x2 scale_matrix = mat2x2(scale.x, 0.0, 0.0, scale.y);
    //return (matrix * scale_matrix);
    return mat2x2(vec4(matrix[0].xy, matrix[1].xy) * scale.xxyy);
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 tex_uv;
layout(location = 1) out vec4 video_and_texture_size_inv;
layout(location = 2) out vec2 output_size_inv;
layout(location = 3) out vec3 eye_pos_local;
layout(location = 4) out vec4 geom_aspect_and_overscan;
#ifdef RUNTIME_GEOMETRY_TILT
layout(location = 5) out vec3 global_to_local_row0;
layout(location = 6) out vec3 global_to_local_row1;
layout(location = 7) out vec3 global_to_local_row2;
#endif

void main()
{
   gl_Position = params.MVP * Position;
   tex_uv = TexCoord;
   
   video_and_texture_size_inv = vec4(registers.SourceSize.zw, registers.SourceSize.zw);
    output_size_inv = registers.OutputSize.zw;

    //  Get aspect/overscan vectors from scalar parameters (likely uniforms):
    const float viewport_aspect_ratio = registers.OutputSize.x * registers.OutputSize.w;
    const vec2 geom_aspect = get_aspect_vector(viewport_aspect_ratio);
    const vec2 geom_overscan = get_geom_overscan_vector();
    geom_aspect_and_overscan = vec4(geom_aspect, geom_overscan);
	
	#ifdef DONT_DEFINE //RUNTIME_GEOMETRY_TILT
        //  Create a local-to-global rotation matrix for the CRT's coordinate
        //  frame and its global-to-local inverse.  Rotate around the x axis
        //  first (pitch) and then the y axis (yaw) with yucky Euler angles.
        //  Positive angles go clockwise around the right-vec and up-vec.
        //  Runtime shader parameters prevent us from computing these globally,
        //  but we can still combine the pitch/yaw matrices by hand to cut a
        //  few instructions.  Note that cg matrices fill row1 first, then row2,
        //  etc. (row-major order).
        const vec2 geom_tilt_angle = get_geom_tilt_angle_vector();
        const vec2 sin_tilt = sin(geom_tilt_angle);
        const vec2 cos_tilt = cos(geom_tilt_angle);
        //  Conceptual breakdown:
        //      const mat3x3 rot_x_matrix = mat3x3(
        //          1.0, 0.0, 0.0,
        //          0.0, cos_tilt.y, -sin_tilt.y,
        //          0.0, sin_tilt.y, cos_tilt.y);
        //      const mat3x3 rot_y_matrix = mat3x3(
        //          cos_tilt.x, 0.0, sin_tilt.x,
        //          0.0, 1.0, 0.0,
        //          -sin_tilt.x, 0.0, cos_tilt.x);
        //      const mat3x3 local_to_global =
        //          rot_x_matrix * rot_y_matrix;
        //      const mat3x3 global_to_local =
        //          transpose(local_to_global);
        mat3x3 local_to_global = mat3x3(
            cos_tilt.x, sin_tilt.y*sin_tilt.x, cos_tilt.y*sin_tilt.x,
            0.0, cos_tilt.y, -sin_tilt.y,
            -sin_tilt.x, sin_tilt.y*cos_tilt.x, cos_tilt.y*cos_tilt.x);
        //  This is a pure rotation, so transpose = inverse:
        mat3x3 global_to_local = transpose(local_to_global);
        //  Decompose the matrix into 3 vec3's for output:
        global_to_local_row0 = vec3(global_to_local[0].xyz);
        global_to_local_row1 = vec3(global_to_local[1].xyz);
        global_to_local_row2 = vec3(global_to_local[2].xyz);
    #else
        const mat3x3 global_to_local = geom_global_to_local_static;
        const mat3x3 local_to_global = geom_local_to_global_static;
    #endif
	
	//  Get an optimal eye position based on geom_view_dist, viewport_aspect,
    //  and CRT radius/rotation:
    #ifdef RUNTIME_GEOMETRY_MODE
        const float geom_mode = geom_mode_runtime;
    #else
        const float geom_mode = geom_mode_static;
    #endif
	
	const vec3 eye_pos_global = get_ideal_global_eye_pos(local_to_global, geom_aspect, geom_mode);
    eye_pos_local = eye_pos_global, global_to_local;
}

#pragma stage fragment
layout(location = 0) in vec2 tex_uv;
layout(location = 1) in vec4 video_and_texture_size_inv;
layout(location = 2) in vec2 output_size_inv;
layout(location = 3) in vec3 eye_pos_local;
layout(location = 4) in vec4 geom_aspect_and_overscan;
#ifdef RUNTIME_GEOMETRY_TILT
layout(location = 5) in vec3 global_to_local_row0;
layout(location = 6) in vec3 global_to_local_row1;
layout(location = 7) in vec3 global_to_local_row2;
#endif
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    //  Localize some parameters:
    const vec2 geom_aspect = geom_aspect_and_overscan.xy;
    const vec2 geom_overscan = geom_aspect_and_overscan.zw;
    const vec2 video_size_inv = video_and_texture_size_inv.xy;
    const vec2 texture_size_inv = video_and_texture_size_inv.zw;
	
	#ifdef RUNTIME_GEOMETRY_TILT
        const mat3x3 global_to_local = mat3x3(global_to_local_row0,
            global_to_local_row1, global_to_local_row2);
    #else
        const mat3x3 global_to_local = geom_global_to_local_static;
    #endif
    #ifdef RUNTIME_GEOMETRY_MODE
        const float geom_mode = geom_mode_runtime;
    #else
        const float geom_mode = geom_mode_static;
    #endif
	
	//  Get flat and curved texture coords for the current fragment point sample
    //  and a pixel_to_tangent_video_uv matrix for transforming pixel offsets:
    //  video_uv = relative position in video frame, mapped to [0.0, 1.0] range
    //  tex_uv = relative position in padded texture, mapped to [0.0, 1.0] range
    const vec2 flat_video_uv = tex_uv * (registers.SourceSize.xy * video_size_inv);
    mat2x2 pixel_to_video_uv;
    vec2 video_uv_no_geom_overscan;
    if(geom_mode > 0.5)
    {
        video_uv_no_geom_overscan =
            get_curved_video_uv_coords_and_tangent_matrix(flat_video_uv,
                eye_pos_local, output_size_inv, geom_aspect,
                geom_mode, global_to_local, pixel_to_video_uv);
    }
    else
    {
        video_uv_no_geom_overscan = flat_video_uv;
        pixel_to_video_uv = mat2x2(
            output_size_inv.x, 0.0, 0.0, output_size_inv.y);
    }
	
	//  Correct for overscan here (not in curvature code):
    const vec2 video_uv =
        (video_uv_no_geom_overscan - vec2(0.5))/geom_overscan + vec2(0.5);
    const vec2 tex_uv = video_uv * (registers.SourceSize.xy * texture_size_inv);
	
	//  Get a matrix transforming pixel vectors to tex_uv vectors:
    const mat2x2 pixel_to_tex_uv =
        mul_scale(registers.SourceSize.xy * texture_size_inv /
            geom_aspect_and_overscan.zw, pixel_to_video_uv);
			
	//  Sample!  Skip antialiasing if aa_level < 0.5 or both of these hold:
    //  1.) Geometry/curvature isn't used
    //  2.) Overscan == vec2(1.0)
    //  Skipping AA is sharper, but it's only faster with dynamic branches.
    const vec2 abs_aa_r_offset = abs(get_aa_subpixel_r_offset());
    bool need_subpixel_aa = true;
	if(abs_aa_r_offset.x + abs_aa_r_offset.y < 0.0) need_subpixel_aa = false;
    vec3 color;
    if(aa_level > 0.5 && (geom_mode > 0.5 || any(notEqual(geom_overscan , vec2(1.0)))))
    {
        //  Sample the input with antialiasing (due to sharp phosphors, etc.):
        color = tex2Daa(Source, tex_uv, pixel_to_tex_uv, registers.FrameCount);
    }
    else if(aa_level > 0.5 && need_subpixel_aa == true)
    {
        //  Sample at each subpixel location:
        color = tex2Daa_subpixel_weights_only(
            Source, tex_uv, pixel_to_tex_uv);
    }
    else
    {
        color = tex2D_linearize(Source, tex_uv).rgb;
    }
	
	//  Dim borders and output the final result:
    const float border_dim_factor = get_border_dim_factor(video_uv, geom_aspect);
    const vec3 final_color = color * border_dim_factor;

   FragColor = encode_output(vec4(final_color, 1.0));
}