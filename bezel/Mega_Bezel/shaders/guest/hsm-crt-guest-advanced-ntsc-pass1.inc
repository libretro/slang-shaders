/*
   CRT - Guest - NTSC - Pass1
   
   Copyright (C) 2018-2022 guest(r) - guest.r@gmail.com

   Incorporates many good ideas and suggestions from Dr. Venom.
   I would also like give thanks to many Libretro forums members for continuous feedback, suggestions and caring about the shader.
   
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
	float SIGMA_HOR;
	float HSHARPNESS;
	float S_SHARP;
	float HARNG;
	float HSHARP; 
	float prescalex;
	float prescaley;
	float spike;
	float internal_res;
} params;

#pragma parameter bogus_filtering "[ FILTERING OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter HSHARPNESS "          Horizontal Filter Range -- HSHARPNESS" 1.5 1.0 8.0 0.125
#define HSHARPNESS params.HSHARPNESS

#pragma parameter SIGMA_HOR "          Horizontal Blur Sigma -- SIGMA_HOR" 0.90 0.1 7.0 0.05
#define SIGMA_HOR params.SIGMA_HOR

#pragma parameter S_SHARP "          Substractive Sharpness -- S_SHARP" 0.9 0.0 2.0 0.10
#define S_SHARP params.S_SHARP

#pragma parameter HSHARP "          Sharpness Definition -- HSHARP" 1.2 0.0 2.0 0.10
#define HSHARP params.HSHARP

#pragma parameter HARNG "          Substractive Sharpness Ringing -- HARNG" 0.4 0.0 4.0 0.10
#define HARNG params.HARNG 

#pragma parameter spike "          Scanline Spike Removal -- spike" 1.0 0.0 2.0 0.10
#define spike params.spike

#pragma parameter prescalex "          Prescale-X Factor (for xBR...pre-shader) -- prescalex" 1.0 1.0 4.0 1.0  // Joint parameter with main pass, values must match
#define prescalex        params.prescalex     // prescale-x factor 

#define COMPAT_TEXTURE(c,d) texture(c,d)

#define TEX0 vTexCoord

#define OutputSize params.OutputSize
#define gl_FragCoord (vTexCoord * OutputSize.xy)

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
layout(set = 0, binding = 2) uniform sampler2D LinearizePass;
layout(set = 0, binding = 3) uniform sampler2D InfoCachePass;
layout(set = 0, binding = 4) uniform sampler2D InfoCachePassFeedback;

float invsqrsigma = 1.0/(2.0*SIGMA_HOR*SIGMA_HOR);

float gaussian(float x)
{
	return exp(-x*x*invsqrsigma);
}

void main()
{	
		// HSM Added
	vec2 viewportCoordTransformed = HSM_GetViewportCoordWithZoomAndPan(vTexCoord);
	HSM_UpdateGlobalScreenValuesFromCache(InfoCachePass, InfoCachePassFeedback, vTexCoord);

// If it's the potato preset render the whole frame
#ifndef IS_POTATO_PRESET
#ifndef IS_NO_REFLECT_PRESET
	// Have to get the scale of the coordinates so we can figure out the size of the onscreen rectangle of the area 
	HSM_GetBezelCoords(TUBE_DIFFUSE_COORD, 
						TUBE_DIFFUSE_SCALE, 
						TUBE_SCALE, 
						SCREEN_ASPECT, 
						false,
						BEZEL_OUTSIDE_SCALE,
						BEZEL_OUTSIDE_COORD, 
						BEZEL_OUTSIDE_CURVED_COORD, 
						FRAME_OUTSIDE_CURVED_COORD);
#endif
#endif

	/* HSM Removed
	vec4 SourceSize = params.OriginalSize * vec4(2.0*prescalex, 1.0, 0.5/prescalex, 1.0);
	*/
	// HSM Added
	vec4 SourceSize = vec4(CROPPED_ROTATED_SIZE_WITH_RES_MULT, 1 / CROPPED_ROTATED_SIZE_WITH_RES_MULT) * vec4(2.0*prescalex, 1.0, 0.5/prescalex, 1.0);

	float f = fract(SourceSize.x * vTexCoord.x);
	f = 0.5 - f;
	vec2 tex = floor(SourceSize.xy * vTexCoord)*SourceSize.zw + 0.5*SourceSize.zw;
	vec3 color = 0.0.xxx;
	float scolor = 0.0;
	vec2 dx  = vec2(SourceSize.z, 0.0);

	float w = 0.0;
	float swsum = 0.0;
	float wsum = 0.0;
	vec3 pixel;

	float hsharpness = HSHARPNESS;
	vec3 cmax = 0.0.xxx;
	vec3 cmin = 1.0.xxx;
	float sharp = gaussian(hsharpness) * S_SHARP;
	float maxsharp = 0.20;
	float FPR = hsharpness;
	float fpx = 0.0;
	float sp = 0.0;
	float sw = 0.0;

	float ts = 0.025;
	vec3 luma = vec3(0.2126, 0.7152, 0.0722); 

	float LOOPSIZE = ceil(2.0*FPR);
	float CLAMPSIZE = round(2.0*LOOPSIZE/3.0);
	
	float n = -LOOPSIZE;
	
	do
	{
		pixel  = COMPAT_TEXTURE(LinearizePass, tex + n*dx).rgb;
		sp = max(max(pixel.r,pixel.g),pixel.b);
		
		w = gaussian(n+f) - sharp;
		fpx = abs(n+f-sign(n)*FPR)/FPR;
		if (abs(n) <= CLAMPSIZE) { cmax = max(cmax, pixel); cmin = min(cmin, pixel); }
		if (w < 0.0) w = clamp(w, mix(-maxsharp, 0.0, pow(fpx, HSHARP)), 0.0);
	
		color = color + w * pixel;
		wsum  = wsum + w;

		sw = max(w, 0.0) * (dot(pixel,luma) + ts); 
		scolor = scolor + sw * sp;
		swsum = swsum + sw;
		
		n = n + 1.0;
			
	} while (n <= LOOPSIZE);

	color = color / wsum;
	scolor = scolor / swsum;
	
	color = clamp(mix(clamp(color, cmin, cmax), color, HARNG), 0.0, 1.0); 
	
	scolor = clamp(mix(max(max(color.r, color.g),color.b), scolor, spike), 0.0, 1.0);
	
	FragColor = vec4(color, scolor);
} 