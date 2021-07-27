#version 450

/*
   CRT - Guest - Advanced - Fastest - Pass2
   
   Copyright (C) 2018-2021 guest(r) - guest.r@gmail.com

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
	float brightboost, brightboost1, gsl, scanline1, scanline2, beam_min, beam_max, beam_size,
    glow, shadowMask, masksize, vertmask, slotmask, slotwidth, double_slot, mcut, maskDark, maskLight,
	maskstr, inters, bloom, halation, scans, slotms, mclip, gamma_c, gamma_out, DER, DEG, DEB, DES, IOS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float warpX;
	float warpY;
	float csize;
	float bsize;
	float c_shape;
	float slotmask1;
} global;

#pragma parameter bogus_screen "[ SCREEN OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter IOS "          Integer Scaling: Odd:Y, Even:'X'+Y" 0.0 0.0 4.0 1.0
#define IOS          params.IOS     // Smart Integer Scaling

#pragma parameter warpX "          CurvatureX (default 0.03)" 0.0 0.0 0.25 0.01
#define warpX        global.warpX     // Curvature X

#pragma parameter warpY "          CurvatureY (default 0.04)" 0.0 0.0 0.25 0.01
#define warpY        global.warpY     // Curvature Y

#pragma parameter c_shape "          Curvature Shape" 0.25 0.05 0.60 0.05
#define c_shape        global.c_shape     // curvature shape

#pragma parameter csize "          Corner size" 0.0 0.0 0.25 0.01
#define csize        global.csize     // corner size

#pragma parameter bsize "          Border smoothness" 400.0 100.0 700.0 10.0
#define bsize        global.bsize     // border smoothness 

#pragma parameter bogus_brightness "[ BRIGHTNESS SETTINGS ]:" 0.0 0.0 1.0 1.0

#pragma parameter glow "          Glow Strength" 0.08 0.0 2.0 0.01
#define glow         params.glow     // Glow Strength

#pragma parameter bloom "          Bloom Strength" 0.0 0.0 2.0 0.05
#define bloom         params.bloom     // bloom effect

#pragma parameter halation "          Halation Strength" 0.0 0.0 1.0 0.025
#define halation         params.halation     // halation effect

#pragma parameter gamma_c "          Gamma correct" 1.0 0.50 2.0 0.02
#define gamma_c   params.gamma_c     // adjust brightness

#pragma parameter brightboost "          Bright Boost Dark Pixels" 1.40 0.25 10.0 0.05
#define brightboost  params.brightboost     // adjust brightness

#pragma parameter brightboost1 "          Bright Boost Bright Pixels" 1.10 0.25 3.00 0.025
#define brightboost1  params.brightboost1     // adjust brightness

#pragma parameter bogus_scanline "[ SCANLINE OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter gsl "          Scanline Type" 0.0 -1.0 2.0 1.0
#define gsl          params.gsl      // Alternate scanlines

#pragma parameter scanline1 "          Scanline Beam Shape Center" 6.0 0.0 20.0 0.5
#define scanline1    params.scanline1      // scanline param, vertical sharpness

#pragma parameter scanline2 "          Scanline Beam Shape Edges" 8.0 3.0 40.0 1.0 
#define scanline2    params.scanline2      // scanline param, vertical sharpness

#pragma parameter beam_min "          Scanline Shape Dark Pixels" 1.30 0.25 3.5 0.05
#define beam_min     params.beam_min     // dark area beam min - narrow

#pragma parameter beam_max "          Scanline Shape Bright Pixels" 1.00 0.4 2.5 0.05
#define beam_max     params.beam_max     // bright area beam max - wide

#pragma parameter beam_size "          Increased Bright Scanline Beam" 0.60 0.0 1.0 0.05
#define beam_size    params.beam_size     // increased max. beam size

#pragma parameter vertmask "          Scanline Color Deconvergence" 0.0 -1.0 1.0 0.1
#define vertmask     params.vertmask     // Scanline deconvergence colors

#pragma parameter scans "          Scanline Saturation" 0.60 0.0 1.0 0.05
#define scans        params.scans     // scanline saturation

#pragma parameter bogus_masks "[ CRT MASK OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter shadowMask "          CRT Mask: 0:CGWG, 1-4:Lottes, 5-7:'Trinitron'" 0.0 -1.0 8.0 1.0
#define shadowMask   params.shadowMask     // Mask Style

#pragma parameter maskstr "          Mask Strength (0, 5-8)" 0.3 -0.5 1.0 0.05
#define maskstr         params.maskstr      // CGWG Mask Strength

#pragma parameter mcut "          Mask 5-7 Low Strength" 1.10 0.0 2.0 0.05
#define mcut         params.mcut      // Mask 5-7 dark color strength

#pragma parameter masksize "          CRT Mask Size (2.0 is nice in 4k)" 1.0 1.0 4.0 1.0
#define masksize     params.masksize     // Mask Size

#pragma parameter maskDark "          Lottes maskDark" 0.5 0.0 2.0 0.05
#define maskDark     params.maskDark     // Dark "Phosphor"

#pragma parameter maskLight "          Lottes maskLight" 1.5 0.0 2.0 0.05
#define maskLight    params.maskLight     // Light "Phosphor"

#pragma parameter slotmask "          Slot Mask Strength Bright Pixels" 0.0 0.0 1.0 0.05
#define slotmask     params.slotmask

#pragma parameter slotmask1 "          Slot Mask Strength Dark Pixels" 0.0 0.0 1.0 0.05
#define slotmask1     global.slotmask1

#pragma parameter slotwidth "          Slot Mask Width" 2.0 1.0 6.0 0.5
#define slotwidth    params.slotwidth     // Slot Mask Width

#pragma parameter double_slot "          Slot Mask Height: 2x1 or 4x1" 1.0 1.0 2.0 1.0
#define double_slot  params.double_slot     // Slot Mask Height

#pragma parameter slotms "          Slot Mask Size" 1.0 1.0 4.0 1.0
#define slotms  params.slotms     // Slot Mask Size

#pragma parameter mclip "          Keep Mask effect with clipping" 0.50 0.0 1.0 0.05
#define mclip  params.mclip     // Slot Mask Size

#pragma parameter bogus_deconvergence22 "[ HORIZONTAL DECONVERGENCE ]:" 0.0 0.0 1.0 1.0

#pragma parameter DER  "          Deconvergence Red offset" 0.0 -15.0 15.0 0.5

#pragma parameter DEG  "          Deconvergence Green offset" 0.0 -15.0 15.0 0.5

#pragma parameter DEB  "          Deconvergence Blue offset" 0.0 -15.0 15.0 0.5

#pragma parameter DES  "          Deconvergence Strength" 0.7 0.0 1.0 0.05

#pragma parameter gamma_out "Gamma out" 2.4 1.0 5.0 0.05
#define gamma_out    params.gamma_out     // output gamma

#pragma parameter inters "          Interlacing Effect Smoothness" 0.0 0.0 0.5 0.05 // Joint parameter with linearize pass, values must match
#define inters  params.inters     // interlacing effect smoothing

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define TEX0 vTexCoord

#define SourceSize global.SourceSize
#define OutputSize global.OutputSize
#define gl_FragCoord (vTexCoord * OutputSize.xy)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.000001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D LinearizePass;
layout(set = 0, binding = 4) uniform sampler2D PrePassDontChange;
layout(set = 0, binding = 5) uniform sampler2D Pass2Feedback;

#define eps 1e-10 

float st(float x)
{
	return exp2(-10.0*x*x);
} 
   
float sw0(float x, float color, float scanline)
{
	float tmp = mix(beam_min, beam_max, color);
	float ex = x*tmp;
	ex = (gsl > -0.5) ? ex*ex : mix(ex*ex, ex*ex*ex, 0.4);
	return exp2(-scanline*ex);
} 

float sw1(float x, float color, float scanline)
{	
	x = mix (x, beam_min*x, max(x-0.4*color,0.0));
	float tmp = mix(1.2*beam_min, beam_max, color);
	float ex = x*tmp;
	return exp2(-scanline*ex*ex);
}    

float sw2(float x, float color, float scanline)
{
	float tmp = mix((2.5-0.5*color)*beam_min, beam_max, color);
	tmp = mix(beam_max, tmp, pow(x, color+0.3));
	float ex = x*tmp;
	return exp2(-scanline*ex*ex);
}  

// Shadow mask (1-4 from PD CRT Lottes shader).

vec3 Mask(vec2 pos, float mx)
{
	pos = floor(pos/masksize);
	vec3 mask = vec3(maskDark, maskDark, maskDark);
	vec3 one = vec3(1.0);
	float dark_compensate  = mix(max( clamp( mix (mcut, maskstr, mx),0.0, 1.0) - 0.3, 0.0) + 1.0, 1.0, mx);
	float mc = 1.0 - max(maskstr, 0.0);	
	
	// No mask
	if (shadowMask == -1.0)
	{
		mask = vec3(1.0);
	}       
	
	// Phosphor.
	else if (shadowMask == 0.0)
	{
		pos.x = fract(pos.x*0.5);
		if (pos.x < 0.5) { mask.r = 1.0; mask.g = mc; mask.b = 1.0; }
		else { mask.r = mc; mask.g = 1.0; mask.b = mc; }
	}    
   
	// Very compressed TV style shadow mask.
	else if (shadowMask == 1.0)
	{
		float line = maskLight;
		float odd  = 0.0;

		if (fract(pos.x/6.0) < 0.5)
			odd = 1.0;
		if (fract((pos.y + odd)/2.0) < 0.5)
			line = maskDark;

		pos.x = fract(pos.x/3.0);
    
		if      (pos.x < 0.333) mask.r = maskLight;
		else if (pos.x < 0.666) mask.g = maskLight;
		else                    mask.b = maskLight;
		
		mask*=line;  
	} 

	// Aperture-grille.
	else if (shadowMask == 2.0)
	{
		pos.x = fract(pos.x/3.0);

		if      (pos.x < 0.333) mask.r = maskLight;
		else if (pos.x < 0.666) mask.g = maskLight;
		else                    mask.b = maskLight;
	} 

	// Stretched VGA style shadow mask (same as prior shaders).
	else if (shadowMask == 3.0)
	{
		pos.x += pos.y*3.0;
		pos.x  = fract(pos.x/6.0);

		if      (pos.x < 0.333) mask.r = maskLight;
		else if (pos.x < 0.666) mask.g = maskLight;
		else                    mask.b = maskLight;
	}

	// VGA style shadow mask.
	else if (shadowMask == 4.0)
	{
		pos.xy = floor(pos.xy*vec2(1.0, 0.5));
		pos.x += pos.y*3.0;
		pos.x  = fract(pos.x/6.0);

		if      (pos.x < 0.333) mask.r = maskLight;
		else if (pos.x < 0.666) mask.g = maskLight;
		else                    mask.b = maskLight;
	}
	
	// Trinitron mask 5
	else if (shadowMask == 5.0)
	{
		mask = vec3(0.0);		
		pos.x = fract(pos.x/2.0);
		if  (pos.x < 0.5)
		{	mask.r  = 1.0;
			mask.b  = 1.0;
		}
		else     mask.g = 1.0;
		mask = clamp(mix( mix(one, mask, mcut), mix(one, mask, maskstr), mx), 0.0, 1.0) * dark_compensate;
	}    

	// Trinitron mask 6
	else if (shadowMask == 6.0)
	{
		mask = vec3(0.0);
		pos.x = fract(pos.x/3.0);
		if      (pos.x < 0.333) mask.r = 1.0;
		else if (pos.x < 0.666) mask.g = 1.0;
		else                    mask.b = 1.0;
		mask = clamp(mix( mix(one, mask, mcut), mix(one, mask, maskstr), mx), 0.0, 1.0) * dark_compensate;
	}
	
	// BW Trinitron mask 7
	else if (shadowMask == 7.0)
	{
		float maskTmp = clamp(mix( mix(1.0, 0.0, mcut), mix(1.0, 0.0, maskstr), mx), 0.0, 1.0) * dark_compensate;
		mask = vec3(maskTmp);
		pos.x = fract(pos.x/2.0);
		if  (pos.x < 0.5) mask = vec3(1.0);
	}    

	// 4k mask
	else 
	{
		mask = vec3(mc);
		pos.x = fract(pos.x * 0.25);
		if      (pos.x < 0.2)  mask.r  = 1.0;
		else if (pos.x < 0.4)  mask.rg = 1.0.xx;
		else if (pos.x < 0.7)  mask.gb = 1.0.xx;	
		else                   mask.b  = 1.0;	
	}     
 
	return mask;
}  

float SlotMask(vec2 pos, float m)
{
	if (slotmask == 0.0) return 1.0;
	else
	{
	pos = floor(pos/slotms);
	float mlen = slotwidth*2.0;
	float px = fract(pos.x/mlen);
	float py = floor(fract(pos.y/(2.0*double_slot))*2.0*double_slot);
	float slot_dark = mix(1.0-slotmask1, 1.0-slotmask, m);
	float slot = 1.0;
	if (py == 0.0 && px <  0.5) slot = slot_dark; else
	if (py == double_slot && px >= 0.5) slot = slot_dark;		
	
	return slot;
	}
}


vec3 declip(vec3 c, float b)
{
	float m = max(max(c.r,c.g),c.b);
	if (m > b) c = c*b/m;
	return c;
}

vec3 gc(vec3 c)
{
	float mc = max(max(c.r,c.g),c.b);
	float mg = pow(mc, 1.0/gamma_c);
	return c * mg/(mc + eps);  
}

vec3 plant (vec3 tar, float r)
{
	float t = max(max(tar.r,tar.g),tar.b) + 0.00001;
	return tar * r / t;
}

vec2 Overscan(vec2 pos, float dx, float dy){
	pos=pos*2.0-1.0;    
	pos*=vec2(dx,dy);
	return pos*0.5+0.5;
}  

vec2 Warp(vec2 pos)
{
	pos  = pos*2.0-1.0;    
	pos  = mix(pos, vec2(pos.x*inversesqrt(1.0-c_shape*pos.y*pos.y), pos.y*inversesqrt(1.0-c_shape*pos.x*pos.x)), vec2(warpX, warpY)/c_shape);
	return pos*0.5 + 0.5;
}

// Borrowed from cgwg's crt-geom, under GPL

float corner(vec2 coord)
{
	coord = min(coord, vec2(1.0)-coord) * vec2(1.0, OutputSize.y/OutputSize.x);
	vec2 cdist = vec2(max(csize/3.0, max((1.0-smoothstep(100.0,600.0,bsize))*0.01,0.002)));
	coord = (cdist - min(coord,cdist));
	float dist = sqrt(dot(coord,coord));
	return clamp((cdist.x-dist)*bsize,0.0, 1.0);
}

vec3 calculate_bloom (vec2 pos, vec2 x, vec2 y)
{
	return  ( COMPAT_TEXTURE(LinearizePass, pos -x -y).rgb * 0.091849 +
	          COMPAT_TEXTURE(LinearizePass, pos    -y).rgb * 0.119368 +
	          COMPAT_TEXTURE(LinearizePass, pos +x -y).rgb * 0.091849 +
	          COMPAT_TEXTURE(LinearizePass, pos -x   ).rgb * 0.119368 +
	          COMPAT_TEXTURE(LinearizePass, pos      ).rgb * 0.155131 +
	          COMPAT_TEXTURE(LinearizePass, pos +x   ).rgb * 0.119368 +
	          COMPAT_TEXTURE(LinearizePass, pos -x +y).rgb * 0.091849 +
	          COMPAT_TEXTURE(LinearizePass, pos    +y).rgb * 0.119368 +
	          COMPAT_TEXTURE(LinearizePass, pos +x +y).rgb * 0.091849 );				   			   
}

void main()
{
	float intera = COMPAT_TEXTURE(LinearizePass, vec2(0.75,0.25)).a;
	bool interb  = (intera < 0.75);
	vec4 result = COMPAT_TEXTURE(Pass2Feedback, vTexCoord);

	vec2 texcoord = TEX0.xy;

	if (IOS > 0.0){
		vec2 ofactor = OutputSize.xy/SourceSize.xy;
		vec2 intfactor = (IOS < 2.5) ? floor(ofactor) : ceil(ofactor);
		vec2 diff = ofactor/intfactor;
		float scan = diff.y;
		texcoord = Overscan(texcoord, scan, scan);
		if (IOS == 1.0 || IOS == 3.0) texcoord = vec2(TEX0.x, texcoord.y);
	}
	
	vec2 yy = vec2(0.0, global.OriginalSize.w);
	vec2 xx = vec2(global.OriginalSize.z, 0.0);
	vec2 y2 = yy+yy;
	vec2 pos  = Warp(texcoord);	
	vec2 pc4 = pos;
	pc4 = floor(pc4 * global.OriginalSize.xy - vec2(0.0, 0.5)) * global.OriginalSize.zw + 0.5*global.OriginalSize.zw; 

	float same2 = COMPAT_TEXTURE(PrePassDontChange,pc4-yy).a;
	float same3 = COMPAT_TEXTURE(PrePassDontChange,pc4   ).a;
	float same4 = COMPAT_TEXTURE(PrePassDontChange,pc4+yy).a;
	float same5 = COMPAT_TEXTURE(PrePassDontChange,pc4+y2).a;
	
	float refresh1 = 30.0;
	float refresh2 = round(TEX0.y*29.0);
	
	bool frames = (floor(mod(float(global.FrameCount), refresh1)) == refresh2);
	bool not_same = (same2 + same3 + same4 + same5) > 0.25;

if ( not_same || frames || interb )

{

	float gamma_in = 1.0/COMPAT_TEXTURE(LinearizePass, vec2(0.25,0.25)).a;

	// Calculating texel coordinates

	vec2 cpos = (IOS > 2.5) ? TEX0 : texcoord;
	float corner0 = corner(Warp(cpos));

	float coffset = 0.5;
	
	vec2 ps = SourceSize.zw;
	float OGL2Pos = pos.y * SourceSize.y - coffset;
	float f = fract(OGL2Pos);
	
	vec2 dx = vec2(ps.x,0.0);
	vec2 dy = vec2(0.0, ps.y);
   
	// Reading the texels

	vec2 pC4;
	
	pC4.y = floor(OGL2Pos) * ps.y + 0.5*ps.y; 
	pC4.x = pos.x;
	
	if (interb)  pC4.y = pos.y - inters * SourceSize.w;
	
	vec3 color1 = COMPAT_TEXTURE(Source, pC4      ).rgb;
	vec3 dcolor1 = color1;
	dcolor1.r = COMPAT_TEXTURE(Source, pC4 + dx*params.DER).r;
	dcolor1.g = COMPAT_TEXTURE(Source, pC4 + dx*params.DEG).g;
	dcolor1.b = COMPAT_TEXTURE(Source, pC4 + dx*params.DEB).b;
	color1 = mix(color1, dcolor1, params.DES);
	
	vec3 scolor1 = 	COMPAT_TEXTURE(Source, pC4      ).aaa;
	
	if (interb) pC4.y = pos.y + inters * SourceSize.w; else
	pC4+=dy;
	
	vec3 color2 = COMPAT_TEXTURE(Source, pC4      ).rgb;
	vec3 dcolor2 = color2;
	dcolor2.r = COMPAT_TEXTURE(Source, pC4 + dx*params.DER).r;
	dcolor2.g = COMPAT_TEXTURE(Source, pC4 + dx*params.DEG).g;
	dcolor2.b = COMPAT_TEXTURE(Source, pC4 + dx*params.DEB).b;
	color2 = mix(color2, dcolor2, params.DES);

	vec3 scolor2 = 	COMPAT_TEXTURE(Source, pC4      ).aaa;
	
	// calculating scanlines

	vec3 ctmp; vec3 mcolor; float w3; vec3 color;
	vec3 one = vec3(1.0);

if (!interb)
{	
	float shape1 = mix(scanline1, scanline2, f);
	float shape2 = mix(scanline1, scanline2, 1.0-f);	
	
	float wt1 = st(f);
	float wt2 = st(1.0-f);

	vec3 color00 = color1*wt1 + color2*wt2;
	vec3 scolor0 = scolor1*wt1 + scolor2*wt2;
	
	ctmp = color00/(wt1+wt2);
	vec3 sctmp = max(scolor0/(wt1+wt2), ctmp);
	mcolor = sctmp;
	
	float wf1, wf2;
	
	vec3 cref1 = mix(sctmp, scolor1, beam_size); float creff1 = max(max(cref1.r,cref1.g),cref1.b);
	vec3 cref2 = mix(sctmp, scolor2, beam_size); float creff2 = max(max(cref2.r,cref2.g),cref2.b);

	float f1 = f; 
	float f2 = 1.0-f;
	
	if (gsl <  0.5) { wf1 = sw0(f1,creff1,shape1); wf2 = sw0(f2,creff2,shape2);} else
	if (gsl == 1.0) { wf1 = sw1(f1,creff1,shape1); wf2 = sw1(f2,creff2,shape2);} else
	                { wf1 = sw2(f1,creff1,shape1); wf2 = sw2(f2,creff2,shape2);}

	if ((wf1 + wf2) > 1.0) { float wtmp = 1.0/(wf1+wf2); wf1*=wtmp; wf2*=wtmp; }
	
	// Scanline saturation application
	
	vec3 w1 = vec3(wf1); vec3 w2 = vec3(wf2);
	w3 = wf1+wf2;
	
	cref1 = color1 / (max(max(color1.r,color1.g),color1.b) + 0.00001);
	cref2 = color2 / (max(max(color2.r,color2.g),color2.b) + 0.00001);	

	w1 = mix(w1*mix(one, cref1*cref1*cref1, scans), w1, wf1);
	w2 = mix(w2*mix(one, cref2*cref2*cref2, scans), w2, wf2);
	
	vec3 cd1 = one; vec3 cd2 = one; float vm = sqrt(abs(vertmask));
	
	float v_high1 = 1.0 + 0.3*vm;
	float v_high2 = 1.0 + 0.6*vm;	
	float v_low  = 1.0 - vm;
	
	float ds1 = min(max(1.0-w3*w3, 2.5*f1), 1.0);
	float ds2 = min(max(1.0-w3*w3, 2.5*f2), 1.0);
	
	if (vertmask < 0.0) 
	{
		cd1 = mix(one, vec3(v_high2, v_low, v_low), ds1);
		cd2 = mix(one, vec3(v_low, v_high1, v_high1), ds2);
	}
	else
	{
		cd1 = mix(one, vec3(v_high1, v_low, v_high1), ds1);
		cd2 = mix(one, vec3(v_low, v_high2, v_low), ds2);
	}
	
	color = gc(color1)*w1*cd1 + gc(color2)*w2*cd2;
	color = min(color, 1.0);
}
	
	if (interb) 
	{
		color = gc(0.5*(color1+color2));
		mcolor = clamp(mix(color1, scolor1, 1.25), 0.0, 1.0);
	}

	float mx = max(max(mcolor.r,mcolor.g),mcolor.b);
	mx = pow(mx, 1.20/gamma_in);
   
	// Apply Mask
	
	vec3 orig1 = color;
	vec3 cmask = one;
	
	float smask = SlotMask(gl_FragCoord.xy * 1.000001, mx);	
	cmask*= Mask(gl_FragCoord.xy * 1.000001, mx);
	
	color = color*cmask;
	color = min(color,1.0);
	color = color*smask;

	cmask = min(cmask*smask, 1.0);

	if (interb) ctmp = color;
	float colmx = pow( max( max(ctmp.r, ctmp.g), ctmp.b), 1.40/gamma_out);
	float bb = mix(brightboost, brightboost1, colmx);
	if (interb) bb = (abs(intera-0.5)<0.1) ? pow(0.80*bb, 0.65) : pow(bb, 0.60);
	color*=bb;

	vec3  Glow = calculate_bloom (pos, xx, 0.75*yy);
	float maxb = max(max(Glow.r, Glow.g),Glow.b);
	Glow = pow(Glow, 1.4.xxx);	
	vec3  Bloom = Glow;
	
	vec3 Bloom1 = min(Bloom*(orig1+color), max(0.5*(colmx + orig1 - color),0.0));
	color = color + bloom*Bloom1;

	color = min(color, mix(one, cmask, mclip));
	if (!interb) color = declip(color, pow(w3,0.60));

	if (halation > 0.025) {
		Bloom = mix(0.5*(Bloom + Bloom*Bloom), Bloom*Bloom, colmx);
		color = color + 0.75*(0.75+maxb)*Bloom*(0.4+sqrt(colmx))*mix(1.0,w3,0.5*colmx)*mix(one,cmask,0.35 + 0.4*maxb)*halation; }

	Glow = mix(Glow, 0.25*color, 0.7*colmx);
	color = color + 0.5*glow*Glow;
	
	color = pow(color, vec3(1.0/gamma_out));
	color = min(color, 1.0);
	
	result = vec4(color*corner0, corner0);
}
	FragColor = result;
} 