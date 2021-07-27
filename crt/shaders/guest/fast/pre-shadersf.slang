#version 450

/*
   CRT Advanced color altering
   
   Copyright (C) 2019-2021 guest(r) and Dr. Venom
   
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
   float TNTC;
   float LS;
   float LUTLOW, LUTBR;   
   float WP;
   float wp_saturation;
   float BP;
   float vigstr;
   float vigdef;
   float sega_fix;
   float pre_bb;   
} params;

#pragma parameter bogus_color "[ COLOR TWEAKS ]:" 0.0 0.0 1.0 1.0

#pragma parameter TNTC "          LUT Colors: Trin. | invTrin. | Nec Mult. | NTSC" 0.0 0.0 4.0 1.0
#define TNTC params.TNTC

#pragma parameter LS "          LUT Size" 32.0 32.0 64.0 32.0
#define LS params.LS

#define LUTLOW 5.0  // "Fix LUT Dark - Range" from 0.0 to 50.0 - RGB singletons

#define LUTBR 1.0   // "Fix LUT Brightness" from 0.0 to 1.0
 
#pragma parameter WP "          Color Temperature %" 0.0 -100.0 100.0 5.0 
#pragma parameter wp_saturation "          Saturation Adjustment" 1.0 0.0 2.0 0.05 
#pragma parameter pre_bb "          Brightness Adjustment" 1.0 0.0 2.0 0.01

#pragma parameter sega_fix "          Sega Brightness Fix" 0.0 0.0 1.0 1.0

#pragma parameter BP "          Raise Black Level" 0.0 0.0 25.0 1.0

#pragma parameter vigstr "          Vignette Strength" 0.0 0.0 2.0 0.025

#pragma parameter vigdef "          Vignette Definition" 7.0 0.4 15.0 0.2


#define WP params.WP
#define wp_saturation params.wp_saturation
#define BP params.BP


layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

#define gl_FragCoord (vTexCoord * params.OutputSize.xy)

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.00001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D SamplerLUT1;
layout(set = 0, binding = 4) uniform sampler2D SamplerLUT2;
layout(set = 0, binding = 5) uniform sampler2D SamplerLUT3;
layout(set = 0, binding = 6) uniform sampler2D SamplerLUT4;
layout(set = 0, binding = 7) uniform sampler2D OriginalHistory0;
layout(set = 0, binding = 8) uniform sampler2D OriginalHistory1;

#define COMPAT_TEXTURE(c,d) texture(c,d)


// Color profile matrices

const mat3 ToSRGB = 
mat3(
 3.240970, -0.969244,  0.055630,
-1.537383,  1.875968, -0.203977,
-0.498611,  0.041555,  1.056972
);


// Color temperature matrices

const mat3 D65_to_D55 = mat3 (
           0.4850339153,  0.2500956126,  0.0227359648,
           0.3488957224,  0.6977914447,  0.1162985741,
           0.1302823568,  0.0521129427,  0.6861537456);


const mat3 D65_to_D93 = mat3 (
           0.3683017655,  0.1899055978,  0.0172641453,
           0.3555467892,  0.7110935785,  0.1185155964,
           0.2475020592,  0.0990008237,  1.3035108450);


vec3 fix_lut(vec3 lutcolor, vec3 ref)
{
	float r = length(ref);
	float l = length(lutcolor);
	float m = max(max(ref.r,ref.g),ref.b);
	ref = normalize(lutcolor + 0.0000001) * mix(r, l, pow(m,1.25));
	return mix(lutcolor, ref, LUTBR);
}

vec2 ctransform (vec2 inputc)
{
	return vec2( inputc.x * sqrt(1.0 - 0.5*inputc.y*inputc.y), inputc.y * sqrt(1.0 - 0.5*inputc.x*inputc.x));
}

float vignette (vec2 coords)
{
	vec2 ccoords = ctransform(2.0*(coords-0.5));
	ccoords = ccoords * ccoords;
	float vstr = sqrt(ccoords.x+ccoords.y);
	vstr = pow(vstr, params.vigdef);
	return max(mix(1.0, 1.0-vstr, params.vigstr), 0.0);
}


void main()
{
   vec4 imgColor = COMPAT_TEXTURE(Source, vTexCoord.xy);
   
   float w = float ((imgColor.r + imgColor.g + imgColor.b) < 1.5/255.0);

   float bp = w * BP/255.0;

   imgColor.rgb = imgColor.rgb * params.pre_bb;
   
   if (params.sega_fix > 0.5) imgColor.rgb = imgColor.rgb * (255.0 / 239.0);
   
   imgColor.rgb = min(imgColor.rgb, 1.0);
   
   vec3 color = imgColor.rgb;
   
   if (int(TNTC) == 0)
   {
      color.rgb = imgColor.rgb;
   }
   else
   {
	  float lutlow = LUTLOW/255.0; float invLS = 1.0/LS;
	  vec3 lut_ref = imgColor.rgb + lutlow*(1.0 - pow(imgColor.rgb, 0.333.xxx));
	  float lutb = lut_ref.b * (1.0-0.5*invLS);	  
	  lut_ref.rg    = lut_ref.rg * (1.0-invLS) + 0.5*invLS; 
	  float tile1 = ceil (lutb * (LS-1.0));
	  float tile0 = max(tile1 - 1.0, 0.0);
	  float f = fract(lutb * (LS-1.0)); if (f == 0.0) f = 1.0;
	  vec2 coord0 = vec2(tile0 + lut_ref.r, lut_ref.g)*vec2(invLS, 1.0);
	  vec2 coord1 = vec2(tile1 + lut_ref.r, lut_ref.g)*vec2(invLS, 1.0);
	  vec4 color1, color2, res;
	  
      if (int(TNTC) == 1)
      {
         color1 = COMPAT_TEXTURE(SamplerLUT1, coord0);
         color2 = COMPAT_TEXTURE(SamplerLUT1, coord1);
         res = mix(color1, color2, f);
      }
      else if (int(TNTC) == 2)
      {
         color1 = COMPAT_TEXTURE(SamplerLUT2, coord0);
         color2 = COMPAT_TEXTURE(SamplerLUT2, coord1);
         res = mix(color1, color2, f);
      }	
      else if (int(TNTC) == 3)
      {
         color1 = COMPAT_TEXTURE(SamplerLUT3, coord0);
         color2 = COMPAT_TEXTURE(SamplerLUT3, coord1);
         res = mix(color1, color2, f);
      }	
      else if (int(TNTC) == 4)
      {
         color1 = COMPAT_TEXTURE(SamplerLUT4, coord0);
         color2 = COMPAT_TEXTURE(SamplerLUT4, coord1);
         res = mix(color1, color2, f);
      }	

      res.rgb = fix_lut (res.rgb, imgColor.rgb);
	  
      color = mix(imgColor.rgb, res.rgb, min(TNTC,1.0));
   }

	vec3 c = clamp(color, 0.0, 1.0);
	
	vec3 scolor1 = normalize(pow(color + 0.000000001, vec3(wp_saturation)))*length(color);
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 scolor2 = mix(vec3(luma), color, wp_saturation);
	color = (wp_saturation > 1.0) ? scolor1 : scolor2;
   
	float p = 2.2;
	
	color = pow(color, vec3(p)); 
 
	color = clamp(color, 0.0, 1.0); 
	
	vec3 warmer = D65_to_D55*color;
	warmer = ToSRGB*warmer;
	
	vec3 cooler = D65_to_D93*color;
	cooler = ToSRGB*cooler;
	
	float m = abs(WP)/100.0;
	
	vec3 comp = (WP < 0.0) ? cooler : warmer;
	
	color = mix(color, comp, m);
	color = pow(max(color, 0.0), vec3(1.0/p));
	
	color = color + bp;

	vec2 dx = vec2(params.SourceSize.z, 0.0);
	vec2 x2 = 2.5 *dx;
	vec2 xx = dx + dx;
	vec2 x3 = x2 + dx;
	vec2 pC4 = vTexCoord;

	vec3 ol3 = COMPAT_TEXTURE(OriginalHistory1, pC4 -x2).rgb;
	vec3 ol2 = COMPAT_TEXTURE(OriginalHistory1, pC4 -dx).rgb;
	vec3 ol1 = COMPAT_TEXTURE(OriginalHistory1, pC4    ).rgb;
	vec3 or1 = COMPAT_TEXTURE(OriginalHistory1, pC4 +dx).rgb;
	vec3 or2 = COMPAT_TEXTURE(OriginalHistory1, pC4 +xx).rgb;

	vec3 cl3 = COMPAT_TEXTURE(OriginalHistory0, pC4 -x2).rgb;	
	vec3 cl2 = COMPAT_TEXTURE(OriginalHistory0, pC4 -dx).rgb;
	vec3 cl1 = COMPAT_TEXTURE(OriginalHistory0, pC4    ).rgb;
	vec3 cr1 = COMPAT_TEXTURE(OriginalHistory0, pC4 +dx).rgb;
	vec3 cr2 = COMPAT_TEXTURE(OriginalHistory0, pC4 +xx).rgb;
	
	vec3 res = abs(ol3-cl3) + abs(ol2-cl2) + abs(ol1-cl1) + abs(or1-cr1) + abs(or2-cr2);
	float res1 = 1.0;
	if ((res.r+res.g+res.b) == 0.0) res1 = 0.0;
	FragColor = vec4(color * vignette(vTexCoord.xy), res1); 
} 