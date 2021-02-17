#version 450

/*
   CRT - Guest - Dr. Venom - Deconvergence pass
   
   Copyright (C) 2021 guest(r) - guest.r@gmail.com
   
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

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	uint FrameCount;
    float deconr;
    float decons;
	float cswitch;
} params;

#pragma parameter bogus_hdeconvergence "[ HORIZONTAL DECONVERGENCE ]: " 0.0 0.0 1.0 1.0
#pragma parameter deconr "          Hor. Deconvergence Color/Range" 0.0 -12.0 12.0 0.5
#define deconr        params.deconr     // Horizontal deconvergence colors range
#pragma parameter decons "          Horizontal Deconvergence Strength" 0.5 0.0 1.0 0.05
#define decons        params.decons     // Horizontal deconvergence colors strength
#pragma parameter cswitch "          Switch Deconvergence Colors" 1.0 -1.0 1.0 2.0
#define cswitch       params.cswitch    // Switch colors left/right

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
layout(set = 0, binding = 3) uniform sampler2D AvgLumPass;

#define COMPAT_TEXTURE(c,d) texture(c,d)

vec3 plant (vec3 tar, float r)
{
	float t = max(max(tar.r,tar.g),tar.b) + 0.00001;
	return tar * r / t;
}

void main()
{
	
	vec3 color = COMPAT_TEXTURE(Source, vTexCoord).rgb;
	vec3 result = color;
	
	if (abs(deconr) > 0.5)
	{
		float step = cswitch/1920.0;
		
		vec2 dx = vec2(step, 0.0);
		
		float shift =  step * abs(deconr);
		vec4 coords = vec4(shift, -shift, 0.0, -0.5*shift);

		vec2 rc = coords.rb;
		vec2 gc = coords.gb;
		vec2 bc = coords.rb;
		
		if (deconr < -0.05) { rc = coords.rb; gc = coords.ab; bc = coords.gb; }
		
		float TATE = round(COMPAT_TEXTURE(Source, vec2(0.5)).a);

		if (TATE > 0.5)
		{ 
			rc = -rc.yx; gc = -gc.yx, bc = -bc.yx; dx = -dx.yx;
		}

		float r1 = COMPAT_TEXTURE(Source, vTexCoord +     rc).r;
		float g1 = COMPAT_TEXTURE(Source, vTexCoord +     gc).g;
		float b1 = COMPAT_TEXTURE(Source, vTexCoord +     bc).b;

		float r2 = COMPAT_TEXTURE(Source, vTexCoord + rc -dx).r;
		float g2 = COMPAT_TEXTURE(Source, vTexCoord + gc -dx).g;
		float b2 = COMPAT_TEXTURE(Source, vTexCoord + bc -dx).b;

		float r3 = COMPAT_TEXTURE(Source, vTexCoord + rc +dx).r;
		float g3 = COMPAT_TEXTURE(Source, vTexCoord + gc +dx).g;
		float b3 = COMPAT_TEXTURE(Source, vTexCoord + bc +dx).b;

		vec3 result1 = vec3(r1,g1,b1);
		vec3 result2 = vec3(r2,g2,b2);
		vec3 result3 = vec3(r3,g3,b3);
		
		result1 = mix(color, result1, decons);
		result2 = mix(color, result2, decons);
		result3 = mix(color, result3, decons);
		result = (result1+result2+result3)/3.0;
		result = plant(result, 0.5*(max(max(color.r,color.g),color.b)+max(max(result.r,result.g),result.b)));
	}
	
	FragColor = vec4(result, 1.0);
}