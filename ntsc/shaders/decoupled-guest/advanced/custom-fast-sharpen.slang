#version 450

/*
   Fast Sharpen Shader (Custom)
   
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
	float CSHARPEN, CCONTR, CDETAILS, NDEBLUR, DEDGE, DESHARP, DSMART;
} params;

#pragma parameter CSHARPEN  "FSharpen - Sharpen strength"         0.00 0.0 5.00 0.10 
#pragma parameter CCONTR    "FSharpen - Sharpen(+Deb) Contrast"   0.05 0.0 0.25 0.01 
#pragma parameter CDETAILS  "FSharpen - Details sharpened"        1.00 0.0 1.00 0.05 
#pragma parameter NDEBLUR   "FSharpen - Deblur Strength"          1.00 1.0 8.00 0.25
#pragma parameter DSMART    "FSharpen - Smart 'Dithering' Deblur" 0.00 0.0 1.00 1.00
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

const mat3 yiq2rgb_mat = mat3(
   1.0, 0.956, 0.6210,
   1.0, -0.2720, -0.6474,
   1.0, -1.1060, 1.7046);

vec3 yiq2rgb(vec3 yiq)
{
   return yiq * yiq2rgb_mat;
}

const mat3 yiq_mat = mat3(
      0.2989, 0.5870, 0.1140,
      0.5959, -0.2744, -0.3216,
      0.2115, -0.5229, 0.3114
);

vec3 rgb2yiq(vec3 col)
{
   return col * yiq_mat;
}

float get_luma(vec3 c)
{
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float resmult = round(params.OriginalSize.x / 300.0);

void main()
{
	vec2 g01 = vec2(-0.5*resmult*params.OriginalSize.z, 0.0);
	vec2 g21 = vec2( 0.5*resmult*params.OriginalSize.z, 0.0); 

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

	float DEB = max(mix(0.375*DEBLUR, DEBLUR, max(1.0-DSMART, dth)), 1.0);
	
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
	
	res = rgb2yiq(res);
	v11 = res.x;
	res.x = lsharpen;
	res.x = clamp((1.0+params.DESHARP)*res.x - params.DESHARP*v11, ln1*(1.0-contrast),lx1*(1.0+contrast));	
	res = max(yiq2rgb(res),0.0);
}
	
	FragColor = vec4(res,1.0);
}
