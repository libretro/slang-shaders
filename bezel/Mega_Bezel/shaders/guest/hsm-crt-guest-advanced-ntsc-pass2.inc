/*
   CRT - Guest - Advanced - NTSC
   
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
	float IOS, OS, BLOOM, brightboost, brightboost1, gsl, scanline1, scanline2, beam_min, beam_max, beam_size,
	h_sharp, s_sharp, warpX, warpY, glow, shadowMask, masksize, vertmask, ring;
} params;

// layout(std140, set = 0, binding = 0) uniform UBO
// {
// 	mat4 MVP;
// 	vec4 SourceSize;
// 	vec4 OriginalSize;
// 	vec4 OutputSize;
// 	uint FrameCount;
// 	float bloom;
// 	float halation;
// 	float scans;
// 	float gamma_c;
// 	float gamma_out;
// 	float overscanX;
// 	float overscanY;
// 	float intres;
// 	float prescalex;
// 	float c_shape;
// 	float blendMode; 
// 	float scangamma;
// 	float rolling_scan;
// 	float sborder;
// 	float scan_falloff;
// 	float bloom_dist;
// } global;


#pragma parameter bogus_brightness "[ BRIGHTNESS SETTINGS ]:" 0.0 0.0 1.0 1.0

#pragma parameter glow "          Glow Strength -- glow" 0.08 -2.0 2.0 0.01
#define glow         global.glow     // Glow Strength

#pragma parameter bloom "          Bloom Strength -- bloom" 0.0 -2.0 2.0 0.05
#define bloom         global.bloom     // bloom effect

#pragma parameter mask_bloom "          Mask Bloom -- mask_bloom" 0.0 0.0 2.0 0.05
#define mask_bloom         global.mask_bloom     // bloom effect

#pragma parameter bloom_dist "          Bloom Distribution -- bloom_dist" 0.0 0.0 3.0 0.05
#define bloom_dist         global.bloom_dist     // bloom effect distribution

#pragma parameter halation "          Halation Strength -- halation" 0.0 -2.0 2.0 0.025
#define halation         global.halation     // halation effect

#pragma parameter gamma_c "          Gamma Correct -- gamma_c" 1.0 0.50 2.0 0.025
#define gamma_c   global.gamma_c     // adjust brightness

#pragma parameter brightboost "          Bright Boost Dark Pixels -- brightboost" 1.40 0.25 10.0 0.05
#define brightboost  global.brightboost     // adjust brightness

#pragma parameter brightboost1 "          Bright Boost Bright Pixels -- brightboost1" 1.10 0.25 3.00 0.025
#define brightboost1  global.brightboost1     // adjust brightness

#pragma parameter bogus_scanline "[ SCANLINE OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter gsl "          Scanline Type -- gsl" 0.0 -1.0 2.0 1.0
#define gsl          global.gsl      // Alternate scanlines

#pragma parameter scanline1 "          Scanline Beam Shape Center -- scanline1" 6.0 -20.0 20.0 0.5
#define scanline1    global.scanline1      // scanline param, vertical sharpness

#pragma parameter scanline2 "          Scanline Beam Shape Edges -- scanline2" 8.0 0.0 70.0 1.0
#define scanline2    global.scanline2      // scanline param, vertical sharpness

#pragma parameter beam_min "          Scanline Shape Dark Pixels -- beam_min" 1.30 0.25 10.0 0.05
#define beam_min     global.beam_min     // dark area beam min - narrow

#pragma parameter beam_max "          Scanline Shape Bright Pixels -- beam_max" 1.00 0.4 3.5 0.025
#define beam_max     global.beam_max     // bright area beam max - wide

#pragma parameter beam_size "          Increased Bright Scanline Beam -- beam_size" 0.60 0.0 1.0 0.05
#define beam_size    global.beam_size     // increased max. beam size

#pragma parameter vertmask "          Scanline Color Deconvergence -- vertmask" 0.0 -1.0 1.0 0.1
#define vertmask     global.vertmask     // Scanline deconvergence colors

#pragma parameter scans "          Scanline Saturation / Mask Falloff -- scans" 0.40 0.0 3.5 0.05
#define scans        global.scans     // scanline saturation

#pragma parameter scan_falloff "          Scanline Falloff -- scan_falloff" 1.0 0.20 2.0 0.05
#define scan_falloff        global.scan_falloff     // scanline falloff

#pragma parameter scangamma "          Scanline Gamma -- scangamma" 2.40 0.5 10.0 0.05
#define scangamma global.scangamma

#pragma parameter rolling_scan "          Rolling Scanlines -- rolling_scan" 0.0 -1.0 1.0 0.01
#define rolling_scan        global.rolling_scan     // rolling scanlines

#pragma parameter no_scanlines "          No-Scanline Mode (Guest Advanced Only)" 0.0 0.0 1.0 1.0
#define no_scanlines global.no_scanlines

// #pragma parameter bogus_screen "[ SCREEN OPTIONS ]: " 0.0 0.0 1.0 1.0

// #pragma parameter intres "          Internal Resolution Y: 0.5...y-dowsample" 0.0 0.0 6.0 0.5 // Joint parameter with linearize pass, values must match

// #pragma parameter IOS "          Integer Scaling: Odd:Y, Even:'X'+Y" 0.0 0.0 4.0 1.0
// #define IOS          params.IOS     // Smart Integer Scaling

// #pragma parameter OS "          R. Bloom Overscan Mode" 1.0 0.0 2.0 1.0
// #define OS           params.OS     // Do overscan

// #pragma parameter BLOOM "          Raster bloom %" 0.0 0.0 20.0 1.0
// #define BLOOM        params.BLOOM     // Bloom overscan percentage

// #pragma parameter warpX "          CurvatureX (default 0.03)" 0.0 0.0 0.25 0.01
// #define warpX        params.warpX     // Curvature X

// #pragma parameter warpY "          CurvatureY (default 0.04)" 0.0 0.0 0.25 0.01
// #define warpY        params.warpY     // Curvature Y

// #pragma parameter c_shape "          Curvature Shape" 0.25 0.05 0.60 0.05
// #define c_shape        global.c_shape     // curvature shape

// #pragma parameter overscanX "          Overscan X original pixels" 0.0 -200.0 200.0 1.0
// #define overscanX        global.overscanX     // OverscanX pixels

// #pragma parameter overscanY "          Overscan Y original pixels" 0.0 -200.0 200.0 1.0
// #define overscanY        global.overscanY     // OverscanY pixels

/// HSM Removed
// #define COMPAT_TEXTURE(c,d) texture(c,d)

// HSM Added
#define COMPAT_TEXTURE(c,d) HSM_GetCroppedTexSample(c,d)
// End Addition

#define TEX0 vTexCoord

#define OutputSize global.OutputSize
#define gl_FragCoord (vTexCoord * OutputSize.xy)

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
layout(set = 0, binding = 2) uniform sampler2D LinearizePass;
layout(set = 0, binding = 3) uniform sampler2D AvgLumPass;
layout(set = 0, binding = 4) uniform sampler2D Pass1;
layout(set = 0, binding = 6) uniform sampler2D InfoCachePass;

#define eps 1e-8

float st(float x)
{
	return exp2(-10.0*x*x);
} 

float st1(float x)
{
	return exp2(-7.0*x*x);
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

/* HSM Removed
vec2 Warp(vec2 pos)
{
	pos  = pos*2.0-1.0;    
	pos  = mix(pos, vec2(pos.x*inversesqrt(1.0-c_shape*pos.y*pos.y), pos.y*inversesqrt(1.0-c_shape*pos.x*pos.x)), vec2(warpX, warpY)/c_shape);
	return pos*0.5 + 0.5;
}

vec2 Overscan(vec2 pos, float dx, float dy){
	pos=pos*2.0-1.0;    
	pos*=vec2(dx,dy);
	return pos*0.5+0.5;
} 
*/

vec3 gc(vec3 c)
{
	float mc = max(max(c.r,c.g),c.b);
	float mg = pow(mc, 1.0/gamma_c);
	return c * mg/(mc + eps);  
}


void main()
{
		// HSM Added
	vec2 viewportCoordTransformed = HSM_GetViewportCoordWithZoomAndPan(vTexCoord);
	HSM_UpdateGlobalScreenValuesFromCache(InfoCachePass, vTexCoord);

	vec2 cache_bounds_coord = SCREEN_COORD;

// If it's the potato preset render the whole frame
#ifndef IS_POTATO_PRESET
#ifndef IS_NO_REFLECT_PRESET
	vec2 bezel_outside_flat_coord;
	vec2 frame_outside_flat_coord;
	HSM_GetSimpleBezelCoords(TUBE_DIFFUSE_COORD, 
							TUBE_DIFFUSE_SCALE, 
							TUBE_SCALE, 
							SCREEN_ASPECT,
							bezel_outside_flat_coord, 
							frame_outside_flat_coord);
	cache_bounds_coord = (frame_outside_flat_coord - 0.5) * 0.9 + 0.5;
#endif
#endif

	if (HHLP_IsOutsideCoordSpace(cache_bounds_coord))
	{
			FragColor = vec4(0);
			return;
	}

	/* HSM Removed
	vec4 SourceSize = params.OriginalSize * vec4(2.0*prescalex, 1.0, 0.5/prescalex, 1.0);

	float f = fract(SourceSize.x * vTexCoord.x);
	f = 0.5 - f;
	vec2 tex = floor(SourceSize.xy * vTexCoord)*SourceSize.zw + 0.5*SourceSize.zw;
	*/

	// HSM Added
	float prescalex = float(CROPPED_ROTATED_SIZE_WITH_RES_MULT.x / CROPPED_ROTATED_SIZE.x); 
	vec4 SourceSize = vec4(CROPPED_ROTATED_SIZE_WITH_RES_MULT, 1 / CROPPED_ROTATED_SIZE_WITH_RES_MULT);

	SourceSize*= vec4(2.0, 1.0, 0.5, 1.0);
	
	float lum = COMPAT_TEXTURE(AvgLumPass, vec2(0.5,0.5)).a;
	
	float gamma_in = 1.0/COMPAT_TEXTURE(LinearizePass, vec2(0.25,0.25)).a;
	float intera = COMPAT_TEXTURE(LinearizePass, vec2(0.75,0.25)).a;
	bool interb  = (intera < 0.5);
	
   	/* HSM Removed
	float SourceY = SourceSize.y;
	float sy = 1.0;
	if (global.intres == 1.0) sy = SourceY/224.0;
	if (global.intres > 0.25 && global.intres != 1.0) sy = global.intres;
	SourceSize*=vec4(1.0, 1.0/sy, 1.0, sy);
	
	// Calculating texel coordinates
   
	vec2 texcoord = TEX0.xy;
	*/
	// HSM Added
	// vec2 texcoord = HSM_GetCurvedCoord(SCREEN_COORD, HSM_CRT_CURVATURE_SCALE, SCREEN_ASPECT);
	// texcoord = HSM_GetMirrorWrappedCoord(texcoord);
	// End Addition

	/* HSM Removed
	if (IOS > 0.0 && !interb){
		vec2 ofactor = OutputSize.xy/global.OriginalSize.xy;
		vec2 intfactor = (IOS < 2.5) ? floor(ofactor) : ceil(ofactor);
		vec2 diff = ofactor/intfactor;
		float scan = diff.y;
		texcoord = Overscan(texcoord, scan, scan);
		if (IOS == 1.0 || IOS == 3.0) texcoord = vec2(TEX0.x, texcoord.y);
	}
   
	float factor  = 1.00 + (1.0-0.5*OS)*BLOOM/100.0 - lum*BLOOM/100.0;
	texcoord  = Overscan(texcoord, factor, factor);

	texcoord = Overscan(texcoord, (global.OriginalSize.x - overscanX)/global.OriginalSize.x, (global.OriginalSize.y - overscanY)/global.OriginalSize.y);

	vec2 pos  = Warp(texcoord);
	vec2 pos0 = Warp(TEX0.xy);
 	*/

	// HSM Added
	vec2 screen_curved_coord = HSM_GetCurvedCoord(SCREEN_COORD, HSM_CRT_CURVATURE_SCALE, SCREEN_ASPECT);
	vec2 pos = HSM_GetMirrorWrappedCoord(screen_curved_coord);


	vec2 coffset = vec2(0.5, 0.5);
	
	vec2 ps = SourceSize.zw;
	vec2 OGL2Pos = pos * SourceSize.xy - coffset;
	vec2 fp = fract(OGL2Pos);
	
	vec2 dx = vec2(ps.x,0.0);
	vec2 dy = vec2(0.0, ps.y);
   
	// Reading the texels

	float  f = fp.y;
	
	vec2 pC4 = floor(OGL2Pos) * ps + 0.5*ps;
	pC4.x = pos.x;	
	if (interb)  pC4.y = pos.y;

	/* HSM Removed
	if (global.intres == 0.5 && prescalex < 1.5) pC4.y = floor(pC4.y * global.OriginalSize.y)*global.OriginalSize.w + 0.5*global.OriginalSize.w;
	*/

	// TODO need to add VGA Doubling mode
	// float hsm_intres = HSM_CORE_RES_SAMPLING_MULT_OPPOSITE_DIR;

	// if (hsm_intres > 1 && (USE_VERTICAL_SCANLINES < 0.5) && prescalex < 1.5) pC4.y = floor(pC4.y * ROTATED_DEREZED_SIZE.y) * (1 / ROTATED_DEREZED_SIZE.y) + 0.5 * (1 / ROTATED_DEREZED_SIZE.y);

	vec3 color1 = COMPAT_TEXTURE(Pass1, pC4      ).rgb;
	vec3 scolor1 = 	COMPAT_TEXTURE(Pass1, pC4      ).aaa;

	if(!interb) color1 = pow(color1, vec3(scangamma/gamma_in));

	pC4+=dy;

	/* HSM Removed
	if (global.intres == 0.5 && prescalex < 1.5) pC4.y = floor((pos.y + 0.33*dy.y) * global.OriginalSize.y)*global.OriginalSize.w + 0.5*global.OriginalSize.w;
	*/

	// if (hsm_intres > 1 && (USE_VERTICAL_SCANLINES < 0.5) && prescalex < 1.5) pC4.y = floor((pos.y + 0.33*dy.y) * ROTATED_DEREZED_SIZE.y) * (1 / ROTATED_DEREZED_SIZE.y) + 0.5 * (1 / ROTATED_DEREZED_SIZE.y);
	
	vec3 color2 = COMPAT_TEXTURE(Pass1, pC4      ).rgb;
	vec3 scolor2 = 	COMPAT_TEXTURE(Pass1, pC4      ).aaa;

	if(!interb) color2 = pow(color2, vec3(scangamma/gamma_in)); 

	vec3 ctmp = color1; float w3 = 1.0; vec3 color = color1;
	vec3 one = vec3(1.0);

if (!interb)
{	
	// calculating scanlines

	float shape1 = mix(scanline1, scanline2, f);
	float shape2 = mix(scanline1, scanline2, 1.0-f);	
	
	float wt1 = st(f);
	float wt2 = st(1.0-f);

	vec3 color00 = color1*wt1 + color2*wt2;
	vec3 scolor0 = scolor1*wt1 + scolor2*wt2;
	
	ctmp = color00/(wt1+wt2);
	vec3 sctmp = scolor0/(wt1+wt2);
	
	float wf1, wf2;
	
	vec3 cref1 = mix(sctmp, scolor1, beam_size); float creff1 = pow(max(max(cref1.r,cref1.g),cref1.b), scan_falloff);
	vec3 cref2 = mix(sctmp, scolor2, beam_size); float creff2 = pow(max(max(cref2.r,cref2.g),cref2.b), scan_falloff);

	float f1 = f; 
	float f2 = 1.0-f;

	float scanpix = SourceSize.x/OutputSize.x;

	f1 = fract(f1 + rolling_scan*float(global.FrameCount)*scanpix);
	f2 = 1.0 - f1;
	
	if (gsl <  0.5) { wf1 = sw0(f1,creff1,shape1); wf2 = sw0(f2,creff2,shape2);} else
	if (gsl == 1.0) { wf1 = sw1(f1,creff1,shape1); wf2 = sw1(f2,creff2,shape2);} else
	                { wf1 = sw2(f1,creff1,shape1); wf2 = sw2(f2,creff2,shape2);}
	
	if ((wf1 + wf2) > 1.0) { float wtmp = 1.0/(wf1+wf2); wf1*=wtmp; wf2*=wtmp; }
	
	// Scanline saturation application
	
	vec3 w1 = vec3(wf1); vec3 w2 = vec3(wf2);
	w3 = wf1+wf2;
	
	float mc1 = max(max(color1.r,color1.g),color1.b) + eps;
	float mc2 = max(max(color2.r,color2.g),color2.b) + eps;
	
	cref1 = color1 / mc1;
	cref2 = color2 / mc2;

	w1 = pow(w1, mix(2.0*scans.xxx + 1.0, 1.0.xxx, cref1))*mix(1.0.xxx + 0.075*scans, 1.0.xxx, cref1);
	w2 = pow(w2, mix(2.0*scans.xxx + 1.0, 1.0.xxx, cref2))*mix(1.0.xxx + 0.075*scans, 1.0.xxx, cref2);
	
	// Scanline Deconvergence
	
	vec3 cd1 = one; vec3 cd2 = one;
	
if (abs(vertmask) > 0.025)
{
	float vm = sqrt(abs(vertmask));
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
}
	
	/* HSM Removed
	color = (gc(color1)*w1*cd1 + gc(color2)*w2*cd2)/mix(1.0.xxx, w1+w2, no_scanlines);
	*/

	// HSM Added
	float scan_res = (1 - USE_VERTICAL_SCANLINES) * CROPPED_ROTATED_SIZE_WITH_RES_MULT.y + 
						USE_VERTICAL_SCANLINES *  CROPPED_ROTATED_SIZE_WITH_RES_MULT.x;
	float hsm_no_scanlines = HSM_INTERLACE_MODE < 0 && HSM_INTERLACE_TRIGGER_RES <= scan_res ? 1 : no_scanlines;
	
	color = (gc(color1)*w1*cd1 + gc(color2)*w2*cd2)/mix(1.0.xxx, w1+w2, hsm_no_scanlines);

	if (abs(rolling_scan) > 0.005) 
	{ 
		wt1 = st1(f);
		wt2 = st1(1.0-f);
		color00 = (color1*wt1 + color2*wt2)/(wt1+wt2);
		color = gc(color00) * mix(w1+w2, w3.xxx, max(wf1,wf2));	
	}
	
	color = min(color, 1.0);
}
	
	if (interb) 
	{
		color = gc(color1);
	}

	float colmx = max(max(ctmp.r,ctmp.g),ctmp.b);

	if(!interb) color = pow( color, vec3(gamma_in/scangamma) );

	FragColor = vec4(color, colmx);

	if (HSM_GetUseFakeScanlines())
	{
		vec2 tube_curved_coord = HSM_GetTubeCurvedCoord(TUBE_DIFFUSE_COORD, 1, TUBE_DIFFUSE_SCALE, TUBE_SCALE, TUBE_DIFFUSE_ASPECT, 1);
		FragColor = HSM_ApplyScanlineMask(FragColor, SCREEN_SCALE, SCREEN_COORD, screen_curved_coord, tube_curved_coord, HSM_FAKE_SCANLINE_OPACITY);
	}
}