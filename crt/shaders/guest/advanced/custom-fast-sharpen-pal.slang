#version 450

/*
   Fast Sharpen Shader (Custom) - PAL
   
   Copyright (C) 2005 - 2025 guest(r)

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
	float CSHARPEN, CCONTR, CDETAILS, NDEBLUR, DEDGE, DESHARP;
} params;

#pragma parameter CSHARPEN  "FSharpen - Sharpen strength"         0.00 0.0 5.00 0.10 
#pragma parameter CCONTR    "FSharpen - Sharpen(+Deb) Contrast"   0.05 0.0 0.25 0.01 
#pragma parameter CDETAILS  "FSharpen - Details sharpened"        1.00 0.0 1.00 0.05 
#pragma parameter NDEBLUR   "FSharpen - Deblur Strength"          1.00 1.0 8.00 0.25
#pragma parameter DEDGE     "FSharpen - Deblur Edge Falloff"      0.90 0.7 1.00 0.01
#pragma parameter DESHARP   "FSharpen - Deblur Extra Sharpen"     0.00 0.0 4.00 0.20
#pragma parameter ntsc-row6 "------------------------------------------------" 0.0 0.0 0.0 1.0


#define CSHARPEN params.CSHARPEN
#define CCONTR params.CCONTR
#define CDETAILS params.CDETAILS
#define DEBLUR params.NDEBLUR
#define DSMART params.DSMART

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
layout(set = 0, binding = 3) uniform sampler2D PrePass0;

const mat3 yuv_rgb =

mat3 (1.00000,   0.00000,   1.13983,
      1.00000,  -0.39465,  -0.58060,
      1.00000,   2.03211,   0.00000);

vec3 yuv2rgb(vec3 yuv)
{
	return yuv * yuv_rgb;
}

const mat3 rgb_yuv = mat3(
     0.29900,   0.58700,   0.11400,
    -0.14713,  -0.28886,   0.43600,
     0.61500,  -0.51499,  -0.10001);

vec3 rgb2yuv(vec3 rgb)
{
	return rgb * rgb_yuv;
}

float get_luma(vec3 c)
{
	return dot(c, vec3(0.299, 0.587, 0.114));
}


void main()
{
	vec2 g01 = vec2(-1.0/640.0, 0.0);
	vec2 g21 = vec2( 1.0/640.0, 0.0); 

	vec3 c01 = texture(Source, vTexCoord + g01).rgb;
	vec3 c21 = texture(Source, vTexCoord + g21).rgb;
	vec3 c11 = texture(Source, vTexCoord      ).rgb;
	
	vec3 b11 = 0.5*(c01+c21); 
	
	float contrast = max(max(c11.r,c11.g),c11.b);
	contrast = mix(2.0*CCONTR, CCONTR, contrast);
	
	vec3 mn = min(min(c01,c21),c11); vec3 mn1 = min(mn,c11*(1.0-contrast));
	vec3 mx = max(max(c01,c21),c11); vec3 mx1 = max(mx,c11*(1.0+contrast));
	
	vec3 dif = pow(mx1-mn1+0.00001, vec3(0.75,0.75,0.75));
	vec3 sharpen = mix(vec3(CSHARPEN*CDETAILS), vec3(CSHARPEN), dif);
	
	vec3 res = clamp(mix(c11,b11,-sharpen), mn1,mx1);
	
if (DEBLUR > 1.125) 
{
	vec2 tex0 = (floor(params.OriginalSize.xy*vTexCoord)+0.5)*params.OriginalSize.zw;
	
	float l01 = get_luma(texture(PrePass0, vTexCoord + 2.0*g01).rgb);
	float l21 = get_luma(texture(PrePass0, vTexCoord + 2.0*g21).rgb);
	float l11 = get_luma(texture(PrePass0, tex0).rgb);
	float dth = texture(Source, vTexCoord).a;

	float DEB = DEBLUR;
	
	float v11 = min(min(l01,l21), l11);
	      l11 = max(max(l01,l21), l11);

	float lmin = min(min(get_luma(c01),get_luma(c21)),get_luma(c11));
	float lmax = max(max(get_luma(c01),get_luma(c21)),get_luma(c11));
	
	float ln1 = min(mix(v11, lmin, lmin), lmin);
	float lx1 = max(mix(lmax, l11, lmax), lmax);
	float r11 = get_luma(res);

	float dif1 = max(r11-ln1, 0.0) + 0.00001; dif1 = pow(dif1, DEB);
	float dif2 = max(lx1-r11, 0.0) + 0.00001; dif2 = pow(dif2, DEB);
	
	float ratio = dif1/(dif1+dif2);
	float lsharpen = mix(ln1, lx1, ratio);

	lsharpen = min(lsharpen, max(params.DEDGE*lsharpen, r11));
	
	res = rgb2yuv(res);
	v11 = res.x;
	res.x = lsharpen;
	res.x = clamp((1.0+params.DESHARP)*res.x - params.DESHARP*v11, ln1*(1.0-contrast),lx1*(1.0+contrast));	
	res = max(yuv2rgb(res),0.0);
}
	
	FragColor = vec4(res,1.0);
}
