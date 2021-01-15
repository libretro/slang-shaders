#version 450

/*
   Average Luminance Shader
   
   Copyright (C) 2018-2020 guest(r) - guest.r@gmail.com

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
   
   Thanks to HunterK for the mipmap hint. :D  
*/

layout(push_constant) uniform Push
{
	uint FrameCount;
	vec4 SourceSize;
	float lsmooth;
} params;

#pragma parameter lsmooth "Raster Bloom Effect Smoothing" 0.90 0.50 0.99 0.01

#define lsmooth params.lsmooth

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize
#define InputSize SourceSize
#define TEX0 vTexCoord

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
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D OriginalHistory0; 
layout(set = 0, binding = 3) uniform sampler2D AvgLumPassFeedback;

#define PassPrev2Texture WhitePointPass

void main()
{
	if (vTexCoord.x > 0.2 || vTexCoord.y > 0.2) discard;
	
	float m = max(log2(SourceSize.x), log2(SourceSize.y));
	m = max(m - 1.0, 1.0);
	
	float ltotal = 0.0;
	
	ltotal+= max(0.0, length(textureLod(OriginalHistory0, vec2(0.25, 0.25), m).rgb));
	ltotal+= max(0.0, length(textureLod(OriginalHistory0, vec2(0.25, 0.75), m).rgb));
	ltotal+= max(0.0, length(textureLod(OriginalHistory0, vec2(0.75, 0.25), m).rgb));
	ltotal+= max(0.0, length(textureLod(OriginalHistory0, vec2(0.75, 0.75), m).rgb));
	
	ltotal*=0.25;
	
	ltotal = pow(0.577350269 * ltotal, 0.6);
	
	float lhistory = texture(AvgLumPassFeedback, vec2(0.1,0.1)).a;

	ltotal = mix(ltotal, lhistory, lsmooth);	
	
	FragColor = vec4(ltotal);
}