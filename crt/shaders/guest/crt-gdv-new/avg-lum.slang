#version 450

/*
   Average Luminance Shader, Smart Edge Interpolation Coefficients Calculation
   
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
	float sth;
} params;

#pragma parameter lsmooth "Raster Bloom Effect Smoothing" 0.75 0.50 0.99 0.01

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


// Reference: http://www.compuphase.com/cmetric.htm
// Reference: ScaleFX, author Sp00kyFox

float dist(vec3 A, vec3 B)
{
	float r = 0.5 * (A.r + B.r);
	vec3 d = A - B;
	vec3 c = vec3(2. + r, 4., 3. - r);

	return sqrt(dot(c*d, d)) / 3.;
} 

void main()
{
	float m = max(log2(SourceSize.x), log2(SourceSize.y));
	m = max(m - 1.0, 1.0);

	vec2 dx = vec2(1.0/SourceSize.x, 0.0); 
	vec2 dy = vec2(0.0, 1.0/SourceSize.y);
	vec2 y2 = 2.0*dy;
	vec2 x2 = 2.0*dx;
	
	float ltotal = 0.0;
	
	ltotal+= max(0.0, length(textureLod(OriginalHistory0, vec2(0.25, 0.25), m).rgb));
	ltotal+= max(0.0, length(textureLod(OriginalHistory0, vec2(0.25, 0.75), m).rgb));
	ltotal+= max(0.0, length(textureLod(OriginalHistory0, vec2(0.75, 0.25), m).rgb));
	ltotal+= max(0.0, length(textureLod(OriginalHistory0, vec2(0.75, 0.75), m).rgb));
	
	ltotal*=0.25;
	
	ltotal = pow(0.577350269 * ltotal, 0.6);
	
	float lhistory = texture(AvgLumPassFeedback, vec2(0.1,0.1)).a;

	ltotal = mix(ltotal, lhistory, lsmooth);	

	vec3 l1 = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy           ).rgb;	   
	vec3 r1 = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy +dx       ).rgb;
	vec3 l2 = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy -dx       ).rgb;
	vec3 r2 = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy +x2       ).rgb;

	float c1 = dist(l2,l1);
	float c2 = dist(l1,r1);
	float c3 = dist(r2,r1);
	
	FragColor = vec4(c1,c2,c3,ltotal);
}