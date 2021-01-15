#version 450

/*
   Phosphor Afterglow Shader
   
   Copyright (C) 2018 guest(r) - guest.r@gmail.com

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
   float AS, PR, PG, PB, sat;
} params;

#pragma parameter AS "Afterglow Strength" 0.07 0.0 1.0 0.01
#pragma parameter PR "Persistence Red (more is less)" 0.05 0.0 1.0 0.01
#pragma parameter PG "Persistence Green"  0.05 0.0 1.0 0.01
#pragma parameter PB "Persistence Blue"  0.05 0.0 1.0 0.01
#pragma parameter sat "Afterglow saturation" 0.10 0.0 1.0 0.01

#define AS params.AS
#define PR params.PR
#define PG params.PG
#define PB params.PB
#define sat params.sat

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
layout(set = 0, binding = 3) uniform sampler2D OriginalHistory1;
layout(set = 0, binding = 4) uniform sampler2D OriginalHistory2;
layout(set = 0, binding = 5) uniform sampler2D OriginalHistory3;
layout(set = 0, binding = 6) uniform sampler2D OriginalHistory4;
layout(set = 0, binding = 7) uniform sampler2D OriginalHistory5;
layout(set = 0, binding = 8) uniform sampler2D OriginalHistory6;

#define Prev1Texture OriginalHistory1
#define Prev2Texture OriginalHistory2
#define Prev3Texture OriginalHistory3
#define Prev4Texture OriginalHistory4
#define Prev5Texture OriginalHistory5
#define Prev6Texture OriginalHistory6

#define TEX0 vTexCoord

#define eps 1e-3

vec3 afterglow(float number)
{
	return vec3(AS)*exp2(-vec3(PR, PG, PB)*vec3(number*number));
}

void main()
{
	vec3 color = COMPAT_TEXTURE(Source, TEX0.xy).rgb;
	vec3 color1 = COMPAT_TEXTURE(Prev1Texture, TEX0.xy).rgb * afterglow(1.0);
	vec3 color2 = COMPAT_TEXTURE(Prev2Texture, TEX0.xy).rgb * afterglow(2.0);
	vec3 color3 = COMPAT_TEXTURE(Prev3Texture, TEX0.xy).rgb * afterglow(3.0);
	vec3 color4 = COMPAT_TEXTURE(Prev4Texture, TEX0.xy).rgb * afterglow(4.0);
	vec3 color5 = COMPAT_TEXTURE(Prev5Texture, TEX0.xy).rgb * afterglow(5.0);
	vec3 color6 = COMPAT_TEXTURE(Prev6Texture, TEX0.xy).rgb * afterglow(6.0);

	vec3 glow = color1 + color2 + color3 + color4 + color5 + color6;
	
	float l = length(glow);
	glow = normalize(pow(glow + vec3(eps), vec3(sat)))*l;		
	
	float w = 1.0;
	if ((color.r + color.g + color.b) > 7.0/255.0) w = 0.0;
	
	FragColor = vec4(color + w*glow,1.0);
}