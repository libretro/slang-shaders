#version 450

/*
   Smart Smoothing Difference Shader
   
   Copyright (C) 2019 guest(r) - guest.r@gmail.com

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
   
*/

#pragma name SmoothPass

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float STH;
} params;

#pragma parameter STH "Smart Smoothing Threshold" 0.7 0.4 1.2 0.05
#define STH params.STH
#define SourceSize params.SourceSize
#define COMPAT_TEXTURE(c,d) texture(c,d)

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float df (vec3 A, vec3 B)
{
	float diff = length(A-B);
	float luma = clamp(length(0.5*min(A,B) + 0.25*(A+B) + 1e-8), 0.0001, 1.0);
	float diff1 = diff/luma;
	return 1.0 - clamp(7.0*(max(1.5*diff,diff1)-STH), 0.0, 1.0);
}

void main()
{
	vec2 dx  = vec2(SourceSize.z, 0.0);	
	vec2 dy  = vec2(0.0, SourceSize.w);	

	vec3 l1 = COMPAT_TEXTURE(Source, vTexCoord.xy -dx).xyz;
	vec3 ct = COMPAT_TEXTURE(Source, vTexCoord.xy    ).xyz;
	vec3 r1 = COMPAT_TEXTURE(Source, vTexCoord.xy +dx).xyz;
	
	float dl = df(ct, l1);
	float dr = df(ct, r1);
	
	float resx = dl; float resy = dr;
	
	FragColor = vec4(resx,resy,1.0,1.0);
}
