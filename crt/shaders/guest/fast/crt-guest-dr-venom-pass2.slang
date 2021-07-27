#version 450

/*
   CRT - Guest - Dr. Venom - Pass2
   
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
   float brightboost, IOS, gsl, scanline1, scanline2, beam_min, beam_max, s_power, beam_size, shadowMask,
      masksize, vertmask, slotmask, slotwidth, double_slot, mcut, maskDark, maskLight, CGWG, gamma_out;
} params;

#pragma parameter brightboost "Bright boost" 1.30 0.50 2.00 0.01
#define brightboost  params.brightboost     // adjust brightness
#pragma parameter IOS "Smart Y Integer Scaling" 0.0 0.0 1.0 1.0
#define IOS          params.IOS     // smart integer scaling
#pragma parameter gsl "Scanline Type" 1.0 0.0 2.0 1.0
#define gsl          params.gsl     // Alternate scanlines
#pragma parameter scanline1 "Scanline beam shape low" 8.0 1.0 15.0 1.0
#define scanline1    params.scanline1     // scanline param, vertical sharpness
#pragma parameter scanline2 "Scanline beam shape high" 8.0 5.0 23.0 1.0
#define scanline2   params.scanline2     // scanline param, vertical sharpness
#pragma parameter beam_min "Scanline dark" 1.25 0.5 2.0 0.05
#define beam_min     params.beam_min     // dark area beam min - narrow
#pragma parameter beam_max "Scanline bright" 1.05 0.5 2.0 0.05
#define beam_max     params.beam_max     // bright area beam max - wide
#pragma parameter s_power  "Scanline intensity" 1.0 0.5 2.5 0.05
#define s_power      params.s_power     // scanline intensity
#pragma parameter beam_size "Increased bright scanline beam" 0.65 0.0 1.0 0.05
#define beam_size    params.beam_size     // increased max. beam size
#pragma parameter shadowMask "CRT Mask: 0:CGWG, 1-4:Lottes, 5-6:'Trinitron'" 5.0 -1.0 6.0 1.0
#define shadowMask   params.shadowMask     // Mask Style
#pragma parameter masksize "CRT Mask Size (2.0 is nice in 4k)" 1.0 1.0 2.0 1.0
#define masksize     params.masksize     // Mask Size
#pragma parameter vertmask "PVM Like Colors" 0.05 0.0 0.25 0.01
#define vertmask     params.vertmask     // Vertical mask
#pragma parameter slotmask "Slot Mask Strength" 0.0 0.0 1.0 0.05
#define slotmask     params.slotmask     // Slot Mask ON/OFF
#pragma parameter slotwidth "Slot Mask Width" 2.0 2.0 6.0 0.5
#define slotwidth    params.slotwidth     // Slot Mask Width
#pragma parameter double_slot "Slot Mask Height: 2x1 or 4x1" 1.0 1.0 2.0 1.0
#define double_slot  params.double_slot     // Slot Mask Height
#pragma parameter mcut "Mask 5&6 cutoff" 0.2 0.0 0.5 0.05
#define mcut         params.mcut     // Mask 5&6 cutoff
#pragma parameter maskDark "Mask Dark" 0.5 0.0 2.0 0.05
#define maskDark     params.maskDark     // Dark "Phosphor"
#pragma parameter maskLight "Mask Light" 1.5 0.0 2.0 0.05
#define maskLight    params.maskLight     // Light "Phosphor"
#pragma parameter CGWG "CGWG Mask Str." 0.3 0.0 1.0 0.05
#define CGWG         params.CGWG     // CGWG Mask Strength
#pragma parameter gamma_out "Gamma out" 2.4 1.0 3.5 0.05
#define gamma_out    params.gamma_out     // output gamma

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
   vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
} global;

#define SourceSize global.SourceSize
#define OutputSize global.OutputSize
#define FrameCount global.FrameCount

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define gl_FragCoord (vTexCoord.xy * OutputSize.xy)
#define InputSize SourceSize

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

#define eps 1e-10

float st(float x, float scanline)
{
	return exp2(-scanline*x*x);
} 
   
vec3 sw0(vec3 x, vec3 color, float scanline)
{
	vec3 tmp = mix(vec3(beam_min),vec3(beam_max), color);
	vec3 ex = x*tmp;
	return exp2(-scanline*ex*ex);
} 

vec3 sw1(vec3 x, vec3 color, float scanline)
{	
	float mx = max(max(color.r, color.g),color.b);
	x = mix (x, beam_min*x, max(x-0.4*mx,0.0));
	vec3 tmp = mix(vec3(1.2*beam_min),vec3(beam_max), color);
	vec3 ex = x*tmp;
	float br = clamp(0.8*beam_min - 1.0, 0.2, 0.45);
	return exp2(-scanline*ex*ex)/(1.0-br+br*color);
}    

vec3 sw2(vec3 x, vec3 color, float scanline)
{
	vec3 tmp = mix(vec3(2.75*beam_min),vec3(beam_max), color);
	tmp = mix(vec3(beam_max), tmp, pow(x, vec3(max(max(color.r, color.g),color.b)+0.3)));
	vec3 ex = x*tmp;
	return exp2(-scanline*ex*ex)/(0.6 + 0.4*color);
}

// Shadow mask (1-4 from PD CRT Lottes shader).
vec3 Mask(vec2 pos, vec3 c)
{
	pos = floor(pos/masksize);
	vec3 mask = vec3(maskDark, maskDark, maskDark);

	
	// No mask
	if (shadowMask == -1.0)
	{
		mask = vec3(1.0);
	}       
	
	// Phosphor.
	else if (shadowMask == 0.0)
	{
		pos.x = fract(pos.x*0.5);
		float mc = 1.0 - CGWG;
		if (pos.x < 0.5) { mask.r = 1.1; mask.g = mc; mask.b = 1.1; }
		else { mask.r = mc; mask.g = 1.1; mask.b = mc; }
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
	
	// Alternate mask 5
	else if (shadowMask == 5.0)
	{
		float mx = max(max(c.r,c.g),c.b);
		vec3 maskTmp = vec3( min( 1.25*max(mx-mcut,0.0)/(1.0-mcut) ,maskDark + 0.2*(1.0-maskDark)*mx));
		float adj = 0.80*maskLight - 0.5*(0.80*maskLight - 1.0)*mx + 0.75*(1.0-mx);	
		mask = maskTmp;
		pos.x = fract(pos.x/2.0);
		if  (pos.x < 0.5)
		{	mask.r  = adj;
			mask.b  = adj;
		}
		else     mask.g = adj;
	}    

	// Alternate mask 6
	else if (shadowMask == 6.0)
	{
		float mx = max(max(c.r,c.g),c.b);
		vec3 maskTmp = vec3( min( 1.5*max(mx-mcut,0.0)/(1.0-mcut) ,maskDark + 0.225*(1.0-maskDark)*mx));
		float adj = 0.80*maskLight - 0.5*(0.80*maskLight - 1.0)*mx + 0.75*(1.0-mx);
		mask = maskTmp;
		pos.x = fract(pos.x/3.0);
		if      (pos.x < 0.333) mask.r = adj;
		else if (pos.x < 0.666) mask.g = adj;
		else                    mask.b = adj; 
	}      
	
	return mask;
} 

float SlotMask(vec2 pos, vec3 c)
{
	if (slotmask == 0.0) return 1.0;
	
	float mx = pow(max(max(c.r,c.g),c.b),1.33);
	float mlen = slotwidth*2.0;
	float px = fract(pos.x/mlen);
	float py = floor(fract(pos.y/(2.0*double_slot))*2.0*double_slot);
	float slot_dark = mix(1.0-slotmask, 1.0-0.80*slotmask, mx);
	float slot = 1.0 + 0.7*slotmask*(1.0-mx);
	if (py == 0.0 && px <  0.5) slot = slot_dark; else
	if (py == double_slot && px >= 0.5) slot = slot_dark;		
	
	return slot;
}   

float Overscan2(float pos, float dy){
	pos=pos*2.0-1.0;    
	pos*=dy;
	return pos*0.5+0.5;
}  

void main()
{
	vec2 texcoord = vTexCoord;
	
	if (IOS == 1.0){
		float ofactor = OutputSize.y/InputSize.y;
		float intfactor = round(ofactor);
		float diff = ofactor/intfactor;
		texcoord.y = Overscan2(texcoord.y*(SourceSize.y/InputSize.y), diff)*(InputSize.y/SourceSize.y);
	} 	

	vec2 ps = SourceSize.zw;
	vec2 OGL2Pos = texcoord * SourceSize.xy - vec2(0.0,0.5);
	vec2 fp = fract(OGL2Pos);
	vec2 dx = vec2(ps.x,0.0);
	vec2 dy = vec2(0.0, ps.y);

	vec2 pC4 = floor(OGL2Pos) * ps + 0.5*ps;  
	
	vec3 color1 = COMPAT_TEXTURE(Source, pC4    ).xyz;
	vec3 color2 = COMPAT_TEXTURE(Source, pC4 +dy).xyz;
   
	// calculating scanlines
   
	float f = fp.y;
	float shape1 = mix(scanline1, scanline2, f);
	float shape2 = mix(scanline1, scanline2, 1.0-f);	
	
	float wt1 = st(f, shape1);
	float wt2 = st(1.0-f, shape2);
	vec3 color0 = color1*wt1 + color2*wt2;
	vec3 ctmp = color0/(wt1+wt2);
	vec3 tmp = pow(ctmp, vec3(1.0/gamma_out));
	
	vec3 w1,w2 = vec3(0.0);
	
	vec3 cref1 = mix(ctmp, color1, beam_size);
	vec3 cref2 = mix(ctmp, color2, beam_size);
	
	vec3 shift = vec3(-vertmask, vertmask, -vertmask);
	
	vec3 f1 = clamp(vec3(f) + shift*0.5*(1.0+f), 0.0, 1.0); 
	vec3 f2 = clamp(vec3(1.0-f) - shift*0.5*(2.0-f), 0.0, 1.0);
	
	if (gsl == 0.0) { w1 = sw0(f1,cref1,shape1); w2 = sw0(f2,cref2,shape2);} else
	if (gsl == 1.0) { w1 = sw1(f1,cref1,shape1); w2 = sw1(f2,cref2,shape2);} else
	if (gsl == 2.0) { w1 = sw2(f1,cref1,shape1); w2 = sw2(f2,cref2,shape2);}
	
	vec3 color = color1*pow(w1, vec3(s_power)) + color2*pow(w2, vec3(s_power));
	
	color*=brightboost;
	color = min(color, 1.0); 
	
	// Apply Mask
	
	color *= Mask(gl_FragCoord.xy * 1.000001,tmp);
	
	color = min(color,1.0);
	
	color *= SlotMask(gl_FragCoord.xy * 1.000001,tmp);		
   
	color = pow(color, vec3(1.0/gamma_out));
	FragColor = vec4(color, 1.0);
}