#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	uint FrameCount;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
    float interlace_bff;
} params;

#pragma parameter interlace_bff "interlace_bff" 0.0 0.0 1.0 1.0

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

//  PASS SETTINGS:
//  gamma-management.h needs to know what kind of pipeline we're using and
//  what pass this is in that pipeline.  This will become obsolete if/when we
//  can #define things like this in the preset file.
#define FIRST_PASS
#define SIMULATE_CRT_ON_LCD

//////////////////////////////////  INCLUDES  //////////////////////////////////

#include "../user-settings.h"
#include "bind-shader-params.h"
#include "../../../../include/gamma-management.h"
#include "scanline-functions.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 tex_uv;
layout(location = 1) out vec2 uv_step;

void main()
{
	gl_Position = params.MVP * Position;
	tex_uv = TexCoord;
   
	//  Save the uv distance between texels:
	uv_step = vec2(1.0) * registers.SourceSize.zw;
}

#pragma stage fragment
layout(location = 0) in vec2 tex_uv;
layout(location = 1) in vec2 uv_step;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
	//  Detect interlacing: 1.0 = true, 0.0 = false.
	const vec2 video_size = registers.SourceSize.xy;
	bool interlaced = is_interlaced(video_size.y);
	
//  Linearize the input based on CRT gamma and bob interlaced fields.
//  Bobbing ensures we can immediately blur without getting artifacts.
//  Note: TFF/BFF won't matter for sources that double-weave or similar.
if(interlace_detect)
    {
        //  Sample the current line and an average of the previous/next line;
        //  tex2D_linearize will decode CRT gamma.  Don't bother branching:
//        const vec2 tex_uv = tex_uv;
        const vec2 v_step = vec2(0.0, uv_step.y);
        const vec3 curr_line = tex2D_linearize(
            Source, tex_uv).rgb;
        const vec3 last_line = tex2D_linearize(
            Source, tex_uv - v_step).rgb;
        const vec3 next_line = tex2D_linearize(
            Source, tex_uv + v_step).rgb;
        const vec3 interpolated_line = 0.5 * (last_line + next_line);
        //  If we're interlacing, determine which field curr_line is in:
		float interlace_check = 0.0;
		if (interlaced == true) interlace_check = 1.0;
        const float modulus = interlace_check + 1.0;
        const float field_offset =
            mod(registers.FrameCount + float(params.interlace_bff), modulus);
        const float curr_line_texel = tex_uv.y * registers.SourceSize.y;
        //  Use under_half to fix a rounding bug around exact texel locations.
        const float line_num_last = floor(curr_line_texel - under_half);
        const float wrong_field = mod(line_num_last + field_offset, modulus);
        //  Select the correct color, and output the result:
        const vec3 color = mix(curr_line, interpolated_line, wrong_field);
        FragColor = encode_output(vec4(color, 1.0));
    }
    else
    {
        FragColor = encode_output(tex2D_linearize(Source, tex_uv));
    }
}