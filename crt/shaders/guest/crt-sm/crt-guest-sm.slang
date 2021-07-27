#version 450

/*
   CRT - Guest - SM (Scanline Mask) Shader
   
   Copyright (C) 2019-2020 guest(r) - guest.r@gmail.com

   Big thanks to Nesguy from the Libretro forums for the masks and other ideas.
   
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

/*   README - MASKS GUIDE

To obtain the best results with masks 0, 1, 3, 4: 
must leave “mask size” at 1 and the display must be set to its native resolution to result in evenly spaced “active” LCD subpixels.

Mask 0: Uses a magenta and green pattern for even spacing of the LCD subpixels.

Mask 1: Similar to Mask 0, but with "ZigZag"

Mask 2: Intended for displays that have RBG subpixels (as opposed to the more common RGB). 
Uses a yellow/blue pattern for even spacing of the LCD subpixels.

Mask 3: Common red/green/blue pattern.

Mask 4: This is useful for 4K displays, where masks 0 and 1 can look too fine. 
Uses a red/yellow/cyan/blue pattern to result in even spacing of the LCD subpixels.

Mask 5: Intended for displays that have the less common RBG subpixel pattern. 
This is useful for 4K displays, where masks 0 and 1 can look too fine. 
Uses a red/magenta/cyan/green pattern for even spacing of the LCD subpixels.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	// vec4 OriginalSize;
	vec4 OutputSize;

	uint FrameCount;
	float smart, brightboost1, brightboost2, stype, scanline1, scanline2, beam_min, beam_max, s_beam;
	float h_sharp, cubic, mask, maskmode, maskdark, maskbright, masksize, gamma_out;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 FinalViewportSize;	
	float bglow;
	float warpx;
	float warpy;
	float bloom;
	float halation;
	float autobrm;	
	float sclip;
} global;

#pragma parameter bglow "Base Glow" 0.0 0.0 1.0 0.01
#pragma parameter bloom "Bloom" 0.40 0.0 2.0 0.05
#pragma parameter halation "Halation" 0.0 0.0 2.0 0.05
#pragma parameter autobrm "Automatic Brightness (Mask)" 0.5 0.0 1.0 0.1
#pragma parameter smart "1:Smart 2:Crop 3:Overscan Y Integer Scaling" 0.0 0.0 3.0 1.0
#pragma parameter brightboost1 "Bright boost dark colors" 1.40 0.5 5.0 0.10
#pragma parameter brightboost2 "Bright boost bright colors" 1.15 0.5 3.0 0.05
#pragma parameter stype "Scanline Type" 1.0 0.0 3.0 1.0
#pragma parameter scanline1 "Scanline Shape Center" 5.0 2.0 20.0 0.5
#pragma parameter scanline2 "Scanline Shape Edges"  7.0 4.0 20.0 0.5
#pragma parameter beam_min "Scanline dark" 1.25 0.5 3.0 0.05
#pragma parameter beam_max "Scanline bright" 1.10 0.5 3.0 0.05
#pragma parameter sclip "Allow Scanline/Mask Clipping With Bloom" 0.50 0.0 1.0 0.05
#pragma parameter s_beam "Overgrown Bright Beam" 0.70 0.0 1.0 0.05
#pragma parameter h_sharp "Horizontal sharpness" 3.0 1.0 10.0 0.10
#pragma parameter cubic "Cubic Filtering" 1.0 0.0 1.0 0.10
#pragma parameter mask "CRT Mask (4&5 are 4k masks)" 0.0 0.0 5.0 1.0
#pragma parameter maskmode "CRT Mask Mode: Classic, Fine, Coarse" 0.0 0.0 2.0 1.0
#pragma parameter maskdark "CRT Mask Strength Dark Pixels" 1.0 0.0 1.5 0.05
#pragma parameter maskbright "CRT Mask Strength Bright Pixels" 0.25 -0.5 1.0 0.05
#pragma parameter masksize "CRT Mask Size" 1.0 1.0 2.0 1.0
#pragma parameter warpx "Curvature X" 0.0  0.0 0.25 0.01
#pragma parameter warpy "Curvature Y" 0.0  0.0 0.25 0.01
#pragma parameter gamma_out "Gamma Out" 2.50 1.0 3.5 0.05

#define bglow global.bglow
#define autobrm global.autobrm
#define smart params.smart
#define brightboost1 params.brightboost1
#define brightboost2 params.brightboost2
#define bloom global.bloom
#define halation global.halation
#define stype params.stype
#define scanline1 params.scanline1
#define scanline2 params.scanline2
#define beam_min params.beam_min
#define beam_max params.beam_max
#define sclip global.sclip
#define s_beam params.s_beam
#define h_sharp params.h_sharp
#define cubic params.cubic
#define mask params.mask
#define maskmode params.maskmode
#define maskdark params.maskdark
#define maskbright params.maskbright
#define masksize params.masksize
#define warpx global.warpx
#define warpy global.warpy
#define gamma_out params.gamma_out


#define TEX0 vTexCoord
#define COMPAT_TEXTURE(c,d) texture(c,d)
#define Texture Source
#define InputSize SourceSize
#define gl_FragCoord (vTexCoord * params.OutputSize.xy)

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
layout(set = 0, binding = 3) uniform sampler2D WpPass; 
layout(set = 0, binding = 4) uniform sampler2D RotPass; 
layout(set = 0, binding = 5) uniform sampler2D LinPass; 

float st(float x)
{
	return exp2(-10.0*x*x);
}   



vec3 sw0(float x, vec3 color, float scan)
{
	vec3 tmp = mix(vec3(beam_min),vec3(beam_max), color);
	vec3 ex = x*tmp;
	return exp2(-scan*ex*ex);
}


vec3 sw1(float x, vec3 color, float scan)
{
	float mx1 = max(max(color.r,color.g),color.b);	
	vec3 tmp = mix(vec3(2.50*beam_min),vec3(beam_max), color);
	tmp = mix(vec3(beam_max), tmp, pow(vec3(x), color + 0.30));
	vec3 ex = vec3(x)*tmp;
	vec3 res = exp2(-scan*ex*ex);
	float mx2 = max(max(res.r,res.g),res.b);
	float br = clamp(mix(0.30, 0.50, 2.0*(beam_min-1.0)),0.10, 0.60);
	return mix(vec3(mx2), res, 0.50)/(1.0 - br + br*mx1);
}


vec3 sw2(float x, vec3 color, float scan)
{	
	float mx1 = max(max(color.r,color.g),color.b);
	vec3 ex = mix(vec3(2.0*beam_min), vec3(beam_max), color);
	vec3 m = min(0.3 + 0.35*ex, 1.0);
	ex = x*ex; 
	vec3 xx = ex*ex;
	xx = mix(xx, ex*xx, m);
	vec3 res = exp2(-1.25*scan*xx);
	float mx2 = max(max(res.r,res.g),res.b);
	float br = clamp(mix(0.20, 0.50, 2.0*(beam_min-1.0)),0.10, 0.60);
	return mix(vec3(mx2), res, 0.50)/(1.0 - br + br*mx1);
}


float Overscan(float pos, float dy){
	pos=pos*2.0-1.0;    
	pos*=dy;
	return pos*0.5+0.5;
}


// Distortion of scanlines, and end of screen alpha (PD CRT Lottes Curvature)
vec2 Warp(vec2 pos)
{
	pos  = pos*2.0-1.0;    
	pos *= vec2(1.0 + (pos.y*pos.y)*warpx, 1.0 + (pos.x*pos.x)*warpy);
	return pos*0.5 + 0.5;
}  

vec3 declip(vec3 c, float b)
{
	float m = max(max(c.r,c.g),c.b);
	if (m > b) c = c*b/m;
	return c;
}

vec3 gc (vec3 c, float bd, float mb)
{
	float m = max(max(c.r,c.g),c.b)+0.00001;
	float b2 = mix(bd, 1.0, pow(m,0.50));
	return b2*c;
}

void main()
{
	vec2 tex = TEX0.xy * 1.00001;
	float sm_tate = COMPAT_TEXTURE(WpPass, vec2(0.5)).a;
	float ratio = COMPAT_TEXTURE(RotPass, vec2(0.5, 0.1)).a;
	
	vec4 SourceSize1 = params.SourceSize;
	float vertres = SourceSize1.y*ratio;
	
	tex.y *= ratio;
	if (sm_tate > 0.25) { tex.x = Overscan(tex.x, (1.0/3.0)*SourceSize1.y/SourceSize1.x); }

	float factor = params.OutputSize.y/vertres;	

	float gamma = COMPAT_TEXTURE(LinPass, vec2(0.5,0.1)).a;
	
	if (smart == 1.0 || smart == 2.0 || smart == 3.0)
	{
		float intfactor = round(factor); if (smart == 2.0) intfactor = floor(factor); if (smart == 3.0) intfactor = ceil(factor);
		float diff = factor/intfactor;
		tex.y = Overscan(tex.y/(ratio), diff)*ratio;
	}
	
	tex = Warp(tex/vec2(1.0,ratio))*vec2(1.0,ratio);	
	
	vec2 OGL2Pos = tex * SourceSize1.xy - vec2(0.5,0.5);
	vec2 fp = fract(OGL2Pos);
	float fpx = fp.x;
	float fp1 = 1.0-fpx;

	vec2 pC4 = (floor(OGL2Pos) + vec2(0.5)) * SourceSize1.zw;	
	
	// Reading the texels
	vec2 dx = vec2(SourceSize1.z,0.0);
	vec2 dy = vec2(0.0,SourceSize1.w);
	vec2 x2 = dx+dx;
	float zero = mix(0.0, exp2(-h_sharp), cubic);
	
	float wl2 = 1.0 + fp.x;	
	float wl1 =       fp.x;
	float wr1 = 1.0 - fp.x;
	float wr2 = 2.0 - fp.x;

	wl2*=wl2; wl2 = exp2(-h_sharp*wl2);
	wl1*=wl1; wl1 = exp2(-h_sharp*wl1);
	wr1*=wr1; wr1 = exp2(-h_sharp*wr1);
	wr2*=wr2; wr2 = exp2(-h_sharp*wr2);

	wl2 = max(wl2 - zero, mix(0.0,mix(-0.14, 0.0, 1.0-fp1*fp1),float(cubic > 0.05)));
	wl1 = max(wl1 - zero, 0.0);
	wr1 = max(wr1 - zero, 0.0);	
	wr2 = max(wr2 - zero, mix(0.0,mix(-0.14, 0.0, 1.0-fpx*fpx),float(cubic > 0.05)));

	float sl2 = max(wl2,0.0);
	float sl1 = wl1;
	float sr1 = wr1;
	float sr2 = max(wr2,0.0);	

	float wtt =  1.0/(wl2+wl1+wr1+wr2);
	float wts =  1.0/(sl2+sl1+sr1+sr2);

	vec3 l2 = COMPAT_TEXTURE(LinPass, pC4 - dx).rgb;
	vec3 l1 = COMPAT_TEXTURE(LinPass, pC4     ).rgb;
	vec3 r1 = COMPAT_TEXTURE(LinPass, pC4 + dx).rgb;
	vec3 r2 = COMPAT_TEXTURE(LinPass, pC4 + x2).rgb;
	
	vec3 color1 = (wl2*l2+wl1*l1+wr1*r1+wr2*r2)*wtt;
	
	vec3 colmin = min(min(l2,l1),min(r1,r2));
	vec3 colmax = max(max(l2,l1),max(r1,r2));
	
	if (cubic > 0.05) color1 = clamp(color1, colmin, colmax);
	
	l1*=l1; l1*=l1*l1; r1*=r1; r1*=r1*r1; l2*=l2; l2*=l2*l2; r2*=r2; r2*=r2*r2;
	vec3 scolor1 = (sl2*l2+sl1*l1+sr1*r1+sr2*r2)*wts;
	scolor1 = pow(scolor1, vec3(1.0/6.0)); vec3 mscolor1 = scolor1;
	
	scolor1 = mix(color1, scolor1, 1.0);
	
	pC4+=dy;
	l2 = COMPAT_TEXTURE(LinPass, pC4 - dx).rgb;
	l1 = COMPAT_TEXTURE(LinPass, pC4     ).rgb;
	r1 = COMPAT_TEXTURE(LinPass, pC4 + dx).rgb;
	r2 = COMPAT_TEXTURE(LinPass, pC4 + x2).rgb;
	
	vec3 color2 = (wl2*l2+wl1*l1+wr1*r1+wr2*r2)*wtt;
	
	colmin = min(min(l2,l1),min(r1,r2));
	colmax = max(max(l2,l1),max(r1,r2));
	
	if (cubic > 0.05) color2 = clamp(color2, colmin, colmax);
	
	l1*=l1; l1*=l1*l1; r1*=r1; r1*=r1*r1; l2*=l2; l2*=l2*l2; r2*=r2; r2*=r2*r2;
	vec3 scolor2 = (sl2*l2+sl1*l1+sr1*r1+sr2*r2)*wts;
	scolor2 = pow(scolor2, vec3(1.0/6.0)); vec3 mscolor2 = scolor2;
	
	scolor2 = mix(color2, scolor2, 1.0);
	
	float f1 = fp.y;
	float f2 = 1.0 - fp.y;
	float f3 = fract(tex.y * SourceSize1.y);
	
	vec3 color;
	float t1 = st(f1);
	float t2 = st(f2);
	float wt = 1.0/(t1+t2);
	
// calculating scanlines

	float scan1 = mix(scanline1, scanline2, f1);
	float scan2 = mix(scanline1, scanline2, f2);
	
	vec3 sctemp = (t1*scolor1 + t2*scolor2)*wt;
	vec3 msctemp = (t1*mscolor1 + t2*mscolor2)*wt;
	
	vec3 ref1 = mix(sctemp, scolor1.rgb, s_beam); ref1 = pow(ref1, mix(vec3(1.25), vec3(0.65), ref1));
	vec3 ref2 = mix(sctemp, scolor2.rgb, s_beam); ref2 = pow(ref2, mix(vec3(1.25), vec3(0.65), ref2));
	
	vec3 w1, w2 = vec3(0.0);

	if (stype < 0.5)
	{
		w1 = sw0(f1, ref1, scan1);
		w2 = sw0(f2, ref2, scan2);
	} 
	else
	if (stype < 1.5)
	{
		w1 = sw1(f1, ref1, scan1);
		w2 = sw1(f2, ref2, scan2);
	}	
	else
	if (stype < 2.5)
	{
		w1 = sw2(f1, ref1, scan1);
		w2 = sw2(f2, ref2, scan2);
	}
	else
	{
		w1 = vec3(f2);
		w2 = vec3(f1);
	}	
	
	
	vec3 ctemp = (t1*color1 + t2*color2)*wt; vec3 orig = ctemp;	float pixbr = max(max(orig.r,orig.g),orig.b); vec3 one = vec3(1.0);
	vec3 tmp1 = clamp(mix(orig, msctemp, 1.25),0.0,1.0);	
	ctemp = w1+w2;
	float w3 = max(max(ctemp.r,ctemp.g),ctemp.b);	
	
	tmp1 = pow(tmp1, vec3(0.65));
	float pixbr1 = max(max(tmp1.r,tmp1.g),tmp1.b);
	
	float maskd = mix(min(maskdark,1.0), 0.25*max(maskbright,0.0), pixbr1); if (mask == 3.0 || mask == 4.0) maskd*=1.33; maskd = mix(1.0, 1.0/(1.0-0.5*maskd), autobrm);
	maskd = mix(maskd, 1.0, pow(pixbr,0.85));	
	
	float brightboost_d = brightboost1;
	float brightboost_b = brightboost2;

	if (stype == 1.0) { brightboost_d = min(brightboost1, 1.40); maskd = 1.0; }
	
	color1 = gc(color1, brightboost_d, maskd);
	color2 = gc(color2, brightboost_d, maskd);
	
	color1 = min(color1, 1.0);
	color2 = min(color2, 1.0);	
	
	color = w1*color1.rgb + w2*color2.rgb;
	color = maskd*color;
	
	vec3 scan3 = vec3(0.0);

	float spos  = (gl_FragCoord.x);
	float spos2 = floor(1.000001*gl_FragCoord.x/masksize) + floor(1.000001*gl_FragCoord.y/masksize);
	
	spos  = floor((spos  * 1.000001)/masksize); float spos1 = 0.0;


	if (mask == 0.0 || mask == 1.0)
	{
		if (mask == 1.0) spos = spos2;
		spos1 = fract(spos*0.5);
		if      (spos1 < 0.5)  scan3.rb = one.rb;
		else                   scan3.g  = one.g;	
	}
	else
	if (mask == 2.0)
	{
		spos1 = fract(spos*0.5);
		if      (spos1 < 0.5)  scan3.rg = one.rg;
		else                   scan3.b  = one.b;
	}
	else
	if (mask == 3.0)
	{
		spos1 = fract(spos/3.0);
		if      (spos1 < 0.3333)  scan3.r = one.r;
		else if (spos1 < 0.6666)  scan3.g = one.g;
		else                      scan3.b = one.b;
	}
	else
	if (mask == 4.0)
	{
		spos1 = fract(spos*0.25);
		if      (spos1 < 0.25)  scan3.r = one.r;
		else if (spos1 < 0.50)  scan3.rg = one.rg;
		else if (spos1 < 0.75)  scan3.gb = one.gb;	
		else                    scan3.b  = one.b;	
	}
	else	
	{
		spos1 = fract(spos*0.25);
		if      (spos1 < 0.25)  scan3.r = one.r;
		else if (spos1 < 0.50)  scan3.rb = one.rb;
		else if (spos1 < 0.75)  scan3.gb = one.gb;
		else                    scan3.g =  one.g; 
	}
	
	vec3 mixmask = tmp1;
	if (maskmode == 1.0) mixmask = vec3(pixbr1); else
	if (maskmode == 2.0) mixmask = tmp1*w3;
	
	vec3 cmask = clamp(mix( mix(one, scan3, maskdark), mix(one, scan3, maskbright), mixmask), 0.0, 1.0);
	vec3 orig1 = color;
	color = color*cmask*brightboost_b;
	
	vec3 Bloom = COMPAT_TEXTURE(Source, tex).rgb;
	vec3 Bglow = COMPAT_TEXTURE(LinPass, tex).rgb;
	Bglow = clamp(Bloom - Bglow,0.0,1.0);
	vec3 hglow = 0.5*(Bloom + Bglow);
	float maxb = max(max(hglow.r,hglow.g),hglow.b); maxb*=maxb;

	vec3 Bloom1 = 2.0*Bloom*Bloom;
	Bloom1 = min(Bloom1, 0.75);
	float bmax = max(max(Bloom1.r,Bloom1.g),Bloom1.b);
	float pmax = 0.85;
	Bloom1 = min(Bloom1, pmax*bmax)/pmax;
	
	Bloom1 = mix(min( Bloom1, 0.5*(orig1+color)), Bloom1, 0.5*(orig1+color));
	Bloom1 = Bloom1*mix(w1+w2,one,1.0-color);
	
	Bloom1 = bloom*Bloom1*cmask;
	
	color = color + Bloom1;
	color = min(color,1.0);
	color = declip(color, pow(w3, 1.0-sclip));		

	float colmx = pixbr1;
	Bloom = mix(0.5*(Bloom + Bloom*Bloom), Bloom*Bloom, colmx);	
	color = color + 0.75*(0.75+maxb)*Bloom*(0.75+sqrt(colmx))*mix(1.0,w3,0.5*colmx)*mix(one,cmask,0.35 + 0.4*maxb)*halation; 

	color = color + bglow*Bglow;
	color = min(color, mix(cmask,one,sclip));
	
	float fgamma = 1.0/gamma_out;
	if (stype == 1.0) fgamma = gamma;
	vec3 color1g = pow(color, vec3(fgamma));
	
    FragColor = vec4(color1g, 1.0);
}