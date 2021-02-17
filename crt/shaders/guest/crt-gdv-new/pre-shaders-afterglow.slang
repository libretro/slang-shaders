#version 450

/*
   CRT GDV Afterglow, color altering
   
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
   float CP, CS;
   float WP;
   float wp_saturation;
   float AS, sat;
} params;

#pragma parameter AS "          Afterglow Strength" 0.07 0.0 0.50 0.01
#define AS params.AS

#pragma parameter sat "          Afterglow saturation" 0.10 0.0 1.0 0.01
#define sat params.sat

#pragma parameter bogus_color "[ COLOR TWEAKS ]:" 0.0 0.0 1.0 1.0

#pragma parameter TNTC "          LUT Number/Colors (1.0-4.0)" 0.0 0.0 4.0 1.0
#define TNTC params.TNTC

#pragma parameter LS "          LUT Size" 32.0 32.0 64.0 32.0
#define LS params.LS

#pragma parameter LUTLOW "          Fix LUT Dark - Range" 5.0 0.0 50.0 1.0
#define LUTLOW params.LUTLOW

#pragma parameter LUTBR "          Fix LUT Brightness" 1.0 0.0 1.0 0.10
#define LUTBR params.LUTBR

#pragma parameter CP "          CRT Color Profile" 0.0 -1.0 5.0 1.0 
#pragma parameter CS "          Color Space: sRGB, DCI, Adobe, Rec.2020" 0.0 0.0 3.0 1.0 

#define CP params.CP
#define CS params.CS
 
#pragma parameter WP "          Color Temperature %" 0.0 -100.0 100.0 5.0 
#pragma parameter wp_saturation "          Saturation Adjustment" 1.0 0.0 2.0 0.05 

#define WP params.WP
#define wp_saturation params.wp_saturation

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
layout(set = 0, binding = 2) uniform sampler2D StockPass;
layout(set = 0, binding = 3) uniform sampler2D AfterglowPass;
layout(set = 0, binding = 4) uniform sampler2D SamplerLUT1;
layout(set = 0, binding = 5) uniform sampler2D SamplerLUT2;
layout(set = 0, binding = 6) uniform sampler2D SamplerLUT3;
layout(set = 0, binding = 7) uniform sampler2D SamplerLUT4;

#define COMPAT_TEXTURE(c,d) texture(c,d)


// Color profile matrices

const mat3 Profile0 = 
mat3(
 0.412391,  0.212639,  0.019331,
 0.357584,  0.715169,  0.119195,
 0.180481,  0.072192,  0.950532
);

const mat3 Profile1 = 
mat3(
 0.430554,  0.222004,  0.020182,
 0.341550,  0.706655,  0.129553,
 0.178352,  0.071341,  0.939322
);

const mat3 Profile2 = 
mat3(
 0.396686,  0.210299,  0.006131,
 0.372504,  0.713766,  0.115356,
 0.181266,  0.075936,  0.967571
);

const mat3 Profile3 = 
mat3(
 0.393521,  0.212376,  0.018739,
 0.365258,  0.701060,  0.111934,
 0.191677,  0.086564,  0.958385
);

const mat3 Profile4 = 
mat3(
 0.392258,  0.209410,  0.016061,
 0.351135,  0.725680,  0.093636,
 0.166603,  0.064910,  0.850324
);

const mat3 Profile5 = 
mat3(
 0.377923,  0.195679,  0.010514,
 0.317366,  0.722319,  0.097826,
 0.207738,  0.082002,  1.076960
);

const mat3 ToSRGB = 
mat3(
 3.240970, -0.969244,  0.055630,
-1.537383,  1.875968, -0.203977,
-0.498611,  0.041555,  1.056972
);

const mat3 ToDCI = 
mat3(
 2.725394,  -0.795168,   0.041242,
-1.018003,   1.689732,  -0.087639,
-0.440163,   0.022647,   1.100929
);

const mat3 ToAdobe = 
mat3(
 2.041588, -0.969244,  0.013444,
-0.565007,  1.875968, -0.11836,
-0.344731,  0.041555,  1.015175
);

const mat3 ToREC = 
mat3(
 1.716651, -0.666684,  0.017640,
-0.355671,  1.616481, -0.042771,
-0.253366,  0.015769,  0.942103
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


void main()
{
   vec4 imgColor = COMPAT_TEXTURE(StockPass, vTexCoord.xy);
   vec4 aftglow = COMPAT_TEXTURE(AfterglowPass, vTexCoord.xy);
   
   float w = 1.0-aftglow.w;

   float l = length(aftglow.rgb);
   aftglow.rgb = AS*w*normalize(pow(aftglow.rgb + 0.01, vec3(sat)))*l;
   
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

      if (imgColor.r == 0.0) res.r = 0.0;
      if (imgColor.g == 0.0) res.g = 0.0;
      if (imgColor.b == 0.0) res.b = 0.0;

      res.rgb = fix_lut (res.rgb, imgColor.rgb);
	  
      color = mix(imgColor.rgb, res.rgb, min(TNTC,1.0));
   }

	vec3 c = clamp(color, 0.0, 1.0);
	
	float p;
	mat3 m_out;
	
	if (CS == 0.0) { p = 2.4; m_out =  ToSRGB; } else
	if (CS == 1.0) { p = 2.6; m_out =  ToDCI;  } else
	if (CS == 2.0) { p = 2.2; m_out =  ToAdobe;} else
	if (CS == 3.0) { p = 2.4; m_out =  ToREC;  }
	
	color = pow(c, vec3(p));
	
	mat3 m_in = Profile0;

	if (CP == 0.0) { m_in = Profile0; } else	
	if (CP == 1.0) { m_in = Profile1; } else
	if (CP == 2.0) { m_in = Profile2; } else
	if (CP == 3.0) { m_in = Profile3; } else
	if (CP == 4.0) { m_in = Profile4; } else
	if (CP == 5.0) { m_in = Profile5; }
	
	color = m_in*color;
	color = m_out*color;

	color = clamp(color, 0.0, 1.0);

	color = pow(color, vec3(1.0/p));	
	
	if (CP == -1.0) color = c;
	
	vec3 scolor1 = normalize(pow(color + 0.000000001, vec3(wp_saturation)))*length(color);
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 scolor2 = mix(vec3(luma), color, wp_saturation);
	color = (wp_saturation > 1.0) ? scolor1 : scolor2;
   
	p = 2.2;
	
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
	
	color = color + aftglow.rgb;
	
	FragColor = vec4(color, 1.0); 
} 