#version 450

/*
   Raster Bloom AKA CRT Brething
   
   code copied from crt-guest-advanced, Copyright (C) 2018-2025 guest(r)
   
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
	float RB_OS, RB_BLOOM;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} global;

#pragma parameter RB_OS "          R. Bloom Overscan Mode" 1.0 0.0 2.0 1.0
#define RB_OS           params.RB_OS     // Do overscan

#pragma parameter RB_BLOOM "          Raster bloom %" 0.0 0.0 20.0 1.0
#define RB_BLOOM        params.RB_BLOOM     // Bloom overscan percentage

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define TEX0 vTexCoord

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.00001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D RBAvgLumPass;
layout(set = 0, binding = 3) uniform sampler2D PerRBAvgLumPass;

vec2 Overscan(vec2 pos, float dx, float dy){
	pos=pos*2.0-1.0;    
	pos*=vec2(dx,dy);
	return pos*0.5+0.5;
} 

void main()
{
	float lum = COMPAT_TEXTURE(RBAvgLumPass, vec2(0.5,0.5)).a;
	
	float factor  = 1.00 + (1.0-0.5*RB_OS)*RB_BLOOM/100.0 - lum*RB_BLOOM/100.0;
	vec2 texcoord = TEX0.xy;
	texcoord  = Overscan(texcoord, factor, factor);

	FragColor = vec4(texture(PerRBAvgLumPass, texcoord).rgb, 1.0);
}
