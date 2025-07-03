#version 450

/*
   G-sharp resampler 2.0 horizontal - dynamic range (upscaler, downsampler)
   
   Copyright (C) 2024 guest(r)

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
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float GSHARP0;
	float GMAXSHARP;
	float GPAR;
	float GBOOST;
} params;

#pragma parameter gsharp_nonono       "G-SHARP2 DOWNSAMPLE:"                           0.0  0.0 1.0 1.0

#pragma parameter GSHARP0 "    Filter Range" 1.0 0.75 8.0 0.05
#define GSHARP0 params.GSHARP0

#pragma parameter GBOOST "    Filter Boost (same range, speedup)" 1.70 1.0 2.5 0.05
#define GBOOST params.GBOOST
float GBOOST1 = 1.0/GBOOST;

#pragma parameter GMAXSHARP "    Filter Sharpness" 0.10 0.0 0.25 0.01
float GMAXSHARP = 0.5*GBOOST*GBOOST*params.GMAXSHARP;

#pragma parameter GPAR "    Anti-Ringing" 0.50 0.0 1.0 0.10
#define GPAR params.GPAR

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
   vTexCoord = TexCoord * 1.00001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize

float smothstep(float x)
{
	return exp(-1.75*x*x);
}

float getw(float x)
{
	float z = x*GBOOST1;
	float y = smothstep(z);
	return max(y*y*y - GMAXSHARP, mix(-GMAXSHARP, 0.0, x-1.0));
}

void main()
{
	vec2 pos = vTexCoord * SourceSize.xy-0.5;
	float f =  -fract(pos.x);
	vec2 tex = floor(pos)*SourceSize.zw + 0.5*SourceSize.zw;
	vec3 color = 0.0.xxx;
	vec2 dx  = vec2(SourceSize.z, 0.0);
	
	float w, fp;
	float wsum = 0.0;
	vec3 pixel;
	vec3 cmax = 0.0.xxx;
	vec3 cmin = 1.0.xxx;
	float FPRi = 1.0/GSHARP0;
	float FPR2 = 2.0*GSHARP0;
	float FPR3 = FPR2*FPR2;
	float LOOPSIZE = ceil(FPR2);	
	float x = -LOOPSIZE+1.0;
	
	do
	{
		fp = min(abs(x+f),FPR2);
		pixel  = COMPAT_TEXTURE(Source, tex + x*dx).rgb;		
		fp = fp*FPRi;
		w = getw(fp);				
		if (w > 0.0) { cmin = min(cmin, pixel); cmax = max(cmax, pixel); }
		color = color + w * pixel;
		wsum   = wsum + w;
		
		x = x + 1.0;
		
	} while (x <= LOOPSIZE);

	color = color / wsum;

	color = mix(clamp(color, 0.0, 1.0), clamp(color, cmin, cmax), GPAR);
	
	FragColor = vec4(color, 1.0);
}
