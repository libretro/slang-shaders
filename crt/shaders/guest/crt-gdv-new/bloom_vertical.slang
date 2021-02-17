#version 450

/*
   Gaussian blur - vertical pass, dynamic range, resizable
   
   Copyright (C) 2020 guest(r) - guest.r@gmail.com

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

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SIZEVB;
	float SIGMA_VB;
} params;


#pragma parameter SIZEVB "          V. Bloom/Halation Radius" 3.0 1.0 30.0 1.0 
#define SIZEVB params.SIZEVB

#pragma parameter SIGMA_VB "          Vertical Bloom/Halation Sigma" 0.70 0.5 15.0 0.10
#define SIGMA_VB params.SIGMA_VB

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

float invsqrsigma = 1.0/(2.0*SIGMA_VB*SIGMA_VB);

float gaussian(float x)
{
	return exp(-x*x*invsqrsigma);
}

void main()
{
	vec4 SourceSize1 = params.SourceSize;
	SourceSize1.yw = params.OriginalSize.yw;
	
	float f = fract(SourceSize1.y * vTexCoord.y);
	f = 0.5 - f;
	vec2 tex = floor(SourceSize1.xy * vTexCoord)*SourceSize1.zw + 0.5*SourceSize1.zw;
	vec3 color = vec3(0.0);
	vec2 dy  = vec2(0.0, SourceSize1.w);

	float w;
	float wsum = 0.0;
	vec3 pixel;
	float n = -SIZEVB;

	do
	{
		pixel  = COMPAT_TEXTURE(Source, tex + n*dy).rgb;
		w      = gaussian(n+f);
		color  = color + w * pixel;
		wsum   = wsum + w;
		n = n + 1.0;
		
	} while (n <= SIZEVB);

	color = color / wsum;
	
	FragColor = vec4(color, 1.0);
}