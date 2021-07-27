#version 450

/*
   CRT - Guest - Dr. Venom - Pass1
   
   Copyright (C) 2018-2019 guest(r) - guest.r@gmail.com

   Incorporates many good ideas and suggestions from Dr. Venom.
   
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
   float h_sharp;
   float s_sharp;
   float h_smart;
} params;

#pragma parameter h_sharp "Horizontal sharpness" 5.00 1.5 20.0 0.25
#define h_sharp params.h_sharp
#pragma parameter s_sharp "Substractive sharpness" 0.05 0.0 0.20 0.01
#define s_sharp params.s_sharp
#pragma parameter h_smart "Smart Horizontal Smoothing" 0.0 0.0 1.0 0.1
#define h_smart params.h_smart
#define SourceSize params.SourceSize

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
layout(set = 0, binding = 3) uniform sampler2D SmoothPass;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define PassPrev2Texture SmoothPass

void main()
{
	vec2 ps = SourceSize.zw;
	vec2 OGL2Pos = vTexCoord * SourceSize.xy;
	vec2 fp = fract(OGL2Pos);
	vec2 dx = vec2(ps.x,0.0);
	vec2 dy = vec2(0.0, ps.y);
	vec2 pC4 = floor(OGL2Pos) * ps + 0.5*ps;  
   
	// Reading the texels
	vec2 x2 = 2.0*dx;
	vec2 y2 = 2.0*dy;
   
	bool sharp = (s_sharp > 0.0);

	float hsharp_tl, hsharp_tr, hsharp_tc; float s_sharpl = s_sharp; float s_sharpr = s_sharp; float s_sharpc = s_sharp;
	
	if (h_smart == 0.0)
	{
		hsharp_tl = h_sharp; hsharp_tr = h_sharp; hsharp_tc = h_sharp;
	}
	else
	{	
		// reading differences for smoothing
		vec2 diffs = COMPAT_TEXTURE(PassPrev2Texture, pC4).xy;
		
		float ls = mix (4.25, 2.25, h_smart);
		hsharp_tl = mix(h_sharp, ls, diffs.x);
		hsharp_tr = mix(h_sharp, ls, diffs.y);

		s_sharpl = mix(s_sharp, 0.0, diffs.x);
		s_sharpr = mix(s_sharp, 0.0, diffs.y);
		
		hsharp_tc = hsharp_tl;
		if (fp.x == 0.5) { hsharp_tc = 0.5*(hsharp_tl + hsharp_tr); s_sharpc = 0.5*(s_sharpl + s_sharpr); }
		if (fp.x >  0.5) { hsharp_tc = hsharp_tr; }
	}
	
	float wl2 = 1.5 + fp.x; wl2*=wl2; float twl2 = exp2(-hsharp_tl*wl2); twl2 = max(twl2 - s_sharpl, -twl2);
	float wl1 = 0.5 + fp.x; wl1*=wl1; float twl1 = exp2(-hsharp_tl*wl1); twl1 = max(twl1 - s_sharpl, -0.4*s_sharpl);
	float wct = 0.5 - fp.x; wct*=wct; float twct = exp2(-hsharp_tc*wct); twct = max(twct - s_sharpc,  s_sharpc);
	float wr1 = 1.5 - fp.x; wr1*=wr1; float twr1 = exp2(-hsharp_tr*wr1); twr1 = max(twr1 - s_sharpr, -0.4*s_sharpr);
	float wr2 = 2.5 - fp.x; wr2*=wr2; float twr2 = exp2(-hsharp_tr*wr2); twr2 = max(twr2 - s_sharpr, -twr2);

	float wtt = 1.0/(twl2+twl1+twct+twr1+twr2);
	
	vec3 l2 = COMPAT_TEXTURE(Source, pC4 -x2).xyz;
	vec3 l1 = COMPAT_TEXTURE(Source, pC4 -dx).xyz;
	vec3 ct = COMPAT_TEXTURE(Source, pC4    ).xyz;
	vec3 r1 = COMPAT_TEXTURE(Source, pC4 +dx).xyz;
	vec3 r2 = COMPAT_TEXTURE(Source, pC4 +x2).xyz;
	
	vec3 color = (l2*twl2 + l1*twl1 + ct*twct + r1*twr1 + r2*twr2)*wtt;
	if (sharp) color = clamp(color, 0.8*min(min(l1,r1),ct), 1.2*max(max(l1,r1),ct)); 
   
	FragColor = vec4(color, 1.0);
}