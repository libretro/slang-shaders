#version 450

/*
   CRT - Guest - Advanced - Deconvergence pass + noise
   
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
	float TATE;
	float decons;
	float addnoised;
	float noiseresd;
	float shadowMask;
	float masksize;
	float deconrr;
	float deconrg;
	float deconrb;
	float deconrry;
	float deconrgy;
	float deconrby;	
	float deconsmooth;
	float dctypex;
	float dctypey;	
} params;

#pragma parameter TATE "          TATE Mode" 0.0 0.0 1.0 1.0
#define TATE         params.TATE     // Screen orientation

#pragma parameter bogus_deconvergence11 "[ HORIZONTAL/VERTICAL DECONVERGENCE ]: " 0.0 0.0 1.0 1.0

#pragma parameter dctypex "          Deconvergence type X : 0.0 - static, other - dynamic" 0.0 0.0 1.0 0.05

#pragma parameter dctypey "          Deconvergence type Y : 0.0 - static, other - dynamic" 0.0 0.0 1.0 0.05

#pragma parameter deconrr "          Horizontal Deconvergence Red Range" 0.0 -12.0 12.0 0.25

#pragma parameter deconrg "          Horizontal Deconvergence Green Range" 0.0 -12.0 12.0 0.25

#pragma parameter deconrb "          Horizontal Deconvergence Blue Range" 0.0 -12.0 12.0 0.25

#pragma parameter deconrry "          Vertical Deconvergence Red Range" 0.0 -12.0 12.0 0.25

#pragma parameter deconrgy "          Vertical Deconvergence Green Range" 0.0 -12.0 12.0 0.25

#pragma parameter deconrby "          Vertical Deconvergence Blue Range" 0.0 -12.0 12.0 0.25
 
#pragma parameter decons "          Deconvergence Strength (and Type)" 0.5 -4.0 4.0 0.10
#define decons        params.decons     // Horizontal deconvergence colors strength

#pragma parameter deconsmooth "          Deconvergence Smoothing" 0.0 0.0 1.0 0.10

#pragma parameter addnoised "          Add Noise" 0.0 -1.0 1.0 0.02
#define addnoised       params.addnoised   // add noise

#pragma parameter noiseresd "          Noise Resolution" 2.0 0.0 10.0 1.0
#define noiseresd       params.noiseresd   // add noise


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

#define COMPAT_TEXTURE(c,d) texture(c,d)


// noise function:
// Dedicated to the public domain.
// If you want a real license, you may consider this MIT/BSD/CC0/WTFPL-licensed (take your pick).
// Adapted from ChuckNorris - shadertoy: https://www.shadertoy.com/view/XtK3Dz

vec3 noise(vec3 v){
    if (addnoised < 0.0) v.z = -addnoised; else v.z = v.z/6000.0;
	// ensure reasonable range
    v = fract(v) + fract(v*1e4) + fract(v*1e-4);
    // seed
    v += vec3(0.12345, 0.6789, 0.314159);
    // more iterations => more random
    v = fract(v*dot(v, v)*123.456);
    v = fract(v*dot(v, v)*123.456);
	v = fract(v*dot(v, v)*123.456);	
    return v;
}

void main()
{
	
	vec3 color = COMPAT_TEXTURE(Source, vTexCoord).rgb;
	vec3 result = color;
	
	if ((abs(params.deconrr) + abs(params.deconrg) + abs(params.deconrb) + abs(params.deconrry) + abs(params.deconrgy) + abs(params.deconrby)) > 0.20)
	{	
		float step = 1.0;
		float dstep = step;
		step*= (TATE < 0.5) ? (params.OutputSize.z) : (params.OutputSize.w);
		float stepy = (TATE < 0.5) ? (params.OutputSize.w) : (params.OutputSize.z);
		float stepx = (TATE < 0.5) ? (params.OutputSize.z) : (params.OutputSize.w);
		
		vec2 sx = mix(vec2(stepx, 0.0), vec2(0.0, stepx), TATE);
		
		float ds = decons;
				
		vec2 dx = (TATE < 0.5) ? vec2(step, 0.0) :  vec2(0.0, step);
		vec2 dy = (TATE > 0.5) ? vec2(stepy, 0.0) :  vec2(0.0, stepy);		
		
		float posx = 2.0*vTexCoord.x - 1.0;
		float posy = 2.0*vTexCoord.y - 1.0;
		
		if (params.dctypex > 0.025)
		{
			posx = sign(posx)*pow(abs(posx), 1.05-params.dctypex);
			dx = posx * dx;
		}

		if (params.dctypey > 0.025)
		{

			posy = sign(posy)*pow(abs(posy), 1.05-params.dctypey);
			dy = posy * dy;
		}

		if (params.dctypex > 0.025 || params.dctypey > 0.025) ds *= sqrt(posx*posx*sign(params.dctypex) + posy*posy*sign(params.dctypey));

		vec2 rc = params.deconrr * dx + params.deconrry*dy;
		vec2 gc = params.deconrg * dx + params.deconrgy*dy;
		vec2 bc = params.deconrb * dx + params.deconrby*dy;		

		dx = (dx+dy) * params.deconsmooth;
		
		float r1 = COMPAT_TEXTURE(Source, vTexCoord + rc    ).r;
		float g1 = COMPAT_TEXTURE(Source, vTexCoord + gc    ).g;
		float b1 = COMPAT_TEXTURE(Source, vTexCoord + bc    ).b;

		float r2 = COMPAT_TEXTURE(Source, vTexCoord + rc -dx).r;
		float g2 = COMPAT_TEXTURE(Source, vTexCoord + gc -dx).g;
		float b2 = COMPAT_TEXTURE(Source, vTexCoord + bc -dx).b;

		float r3 = COMPAT_TEXTURE(Source, vTexCoord + rc +dx).r;
		float g3 = COMPAT_TEXTURE(Source, vTexCoord + gc +dx).g;
		float b3 = COMPAT_TEXTURE(Source, vTexCoord + bc +dx).b;

		vec3 result1 = vec3(r1,g1,b1);
		vec3 result2 = vec3(r2,g2,b2);
		vec3 result3 = vec3(r3,g3,b3);
		result = (result1+result2+result3)/3.0;
		
		vec3 dcolor = max(max(COMPAT_TEXTURE(Source, vTexCoord + sx).rgb, COMPAT_TEXTURE(Source, vTexCoord - sx).rgb), color);
		
		float mc = max(max(dcolor.r, dcolor.g), dcolor.b);
		if (decons < 0.0) mc = 0.9;
	
		result = clamp(mix(color, sqrt(mix(result*result, color*result, sqrt(mc))), abs(ds)), min(result,color), max(result, color));
	}
	
	float rc = 0.6*sqrt(max(max(result.r, result.g), result.b))+0.4;
	
	if (abs(addnoised) > 0.01) result = mix(result, noise(vec3(floor(params.OutputSize.xy * vTexCoord / noiseresd), float(params.FrameCount))), 0.25*abs(addnoised) * rc);
	
	float corner = COMPAT_TEXTURE(Source, vTexCoord).a;	
	
	FragColor = vec4(result*corner, 1.0);
}