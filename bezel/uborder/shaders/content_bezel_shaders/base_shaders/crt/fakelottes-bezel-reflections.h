
// Simple scanlines with curvature and mask effects lifted from crt-lottes
// by hunterk

////////////////////////////////////////////////////////////////////
////////////////////////////  SETTINGS  ////////////////////////////
/////  comment these lines to disable effects and gain speed  //////
////////////////////////////////////////////////////////////////////

#define MASK // fancy, expensive phosphor mask effect
#define CURVATURE // applies barrel distortion to the screen
#define SCANLINES  // applies horizontal scanline effect
//#define ROTATE_SCANLINES // for TATE games; also disables the mask effects, which look bad with it
#define EXTRA_MASKS // disable these if you need extra registers freed up

////////////////////////////////////////////////////////////////////
//////////////////////////  END SETTINGS  //////////////////////////
////////////////////////////////////////////////////////////////////

// prevent stupid behavior
#if defined ROTATE_SCANLINES && !defined SCANLINES
	#define SCANLINES
#endif

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float shadowMask;
	float SCANLINE_SINE_COMP_B;
	float warpX;
	float warpY;
	float maskDark;
	float maskLight;
	float monitor_gamma;
	float crt_gamma;
	float SCANLINE_SINE_COMP_A;
	float SCANLINE_BASE_BRIGHTNESS;
} params;



#define USE_BEZEL_REFLECTIONS_COMMON

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;

#include "../../include/uborder_bezel_reflections_global_declarations.inc"


} global;

#include "../../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     params.OutputSize
#define ub_OriginalSize   params.OriginalSize
#define ub_Rotation       global.Rotation

#include "../../include/uborder_bezel_reflections_common.inc"

#pragma parameter fake_nonono       "FAKELOTTES:"                           0.0  0.0 1.0 1.0
#pragma parameter shadowMask "shadowMask" 1.0 0.0 4.0 1.0
#pragma parameter SCANLINE_SINE_COMP_B "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter warpX "warpX" 0.031 0.0 0.125 0.01
#pragma parameter warpY "warpY" 0.041 0.0 0.125 0.01
#pragma parameter maskDark "maskDark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "maskLight" 1.5 0.0 2.0 0.1
#pragma parameter crt_gamma "CRT Gamma" 2.5 1.0 4.0 0.05
#pragma parameter monitor_gamma "Monitor Gamma" 2.2 1.0 4.0 0.05
#pragma parameter SCANLINE_SINE_COMP_A "Scanline Sine Comp A" 0.0 0.0 0.10 0.01
#pragma parameter SCANLINE_BASE_BRIGHTNESS "Scanline Base Brightness" 0.95 0.0 1.0 0.01

vec2  mask_size  = ub_OutputSize.xy* fr_scale * (1.0 - 0.5*global.h_curvature);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 uv;
layout(location = 2) out vec2 border_uv;
layout(location = 3) out vec2 bezel_uv;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord * vec2(1.000001);

    vec2 diff = vTexCoord.xy - middle;
    uv        = 2.0*(middle + diff / fr_scale - fr_center) - 1.0;
    bezel_uv  = uv - 2.0*bz_center;

    border_uv = (global.border_allow_rot < 0.5) ? get_unrotated_coords(TexCoord.xy, ub_Rotation) : TexCoord.xy;

    border_uv.y = mix(border_uv.y, 1.0-border_uv.y, border_mirror_y);

    border_uv = middle + (border_uv.xy - middle - border_pos) / (global.border_scale*all_zoom);

    border_uv = border_uv.xy * vec2(1.000001);

#ifdef KEEP_BORDER_ASPECT_RATIO
    border_uv -= 0.5.xx;
#endif
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec2 border_uv;
layout(location = 3) in vec2 bezel_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;
layout(set = 0, binding = 4) uniform sampler2D LAYER2;
#ifdef USE_AMBIENT_LIGHT
layout(set = 0, binding = 5) uniform sampler2D ambi_temporal_pass;
#endif

vec4 scanline(vec2 coord, vec4 frame)
{
#if defined SCANLINES
	vec2 omega = vec2(3.1415 * params.OutputSize.x, 2.0 * 3.1415 * params.SourceSize.y);
	vec2 sine_comp = vec2(params.SCANLINE_SINE_COMP_A, params.SCANLINE_SINE_COMP_B);
	vec3 res = frame.xyz;
	#ifdef ROTATE_SCANLINES
		sine_comp = sine_comp.yx;
		omega = omega.yx;
	#endif
	vec3 scanline = res * (params.SCANLINE_BASE_BRIGHTNESS + dot(sine_comp * sin(coord * omega), vec2(1.0, 1.0)));

	return vec4(scanline.x, scanline.y, scanline.z, 1.0);
#else
	return frame;
#endif
}

#ifdef CURVATURE
// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*params.warpX, 1.0 + (pos.x*pos.x)*params.warpY);
    
    return pos*0.5 + 0.5;
}
#endif

#if defined MASK && !defined ROTATE_SCANLINES
	// Shadow mask.
	vec4 Mask(vec2 pos)
	{
		vec3 mask = vec3(params.maskDark, params.maskDark, params.maskDark);
	  
		// Very compressed TV style shadow mask.
		if (params.shadowMask == 1.0) 
		{
			float line = params.maskLight;
			float odd = 0.0;
			
			if (fract(pos.x*0.166666666) < 0.5) odd = 1.0;
			if (fract((pos.y + odd) * 0.5) < 0.5) line = params.maskDark;  
			
			pos.x = fract(pos.x*0.333333333);

			if      (pos.x < 0.333) mask.r = params.maskLight;
			else if (pos.x < 0.666) mask.g = params.maskLight;
			else                    mask.b = params.maskLight;
			mask*=line;  
		} 

		// Aperture-grille.
		else if (params.shadowMask == 2.0) 
		{
			pos.x = fract(pos.x*0.333333333);

			if      (pos.x < 0.333) mask.r = params.maskLight;
			else if (pos.x < 0.666) mask.g = params.maskLight;
			else                    mask.b = params.maskLight;
		} 
	#ifdef EXTRA_MASKS
		// These can cause moire with curvature and scanlines
		// so they're an easy target for freeing up registers
		
		// Stretched VGA style shadow mask (same as prior shaders).
		else if (params.shadowMask == 3.0) 
		{
			pos.x += pos.y*3.0;
			pos.x  = fract(pos.x*0.166666666);

			if      (pos.x < 0.333) mask.r = params.maskLight;
			else if (pos.x < 0.666) mask.g = params.maskLight;
			else                    mask.b = params.maskLight;
		}

		// VGA style shadow mask.
		else if (params.shadowMask == 4.0) 
		{
			pos.xy  = floor(pos.xy*vec2(1.0, 0.5));
			pos.x  += pos.y*3.0;
			pos.x   = fract(pos.x*0.166666666);

			if      (pos.x < 0.333) mask.r = params.maskLight;
			else if (pos.x < 0.666) mask.g = params.maskLight;
			else                    mask.b = params.maskLight;
		}
	#endif
		
		else mask = vec3(1.,1.,1.);

		return vec4(mask, 1.0);
	}
#endif

vec3 get_content(vec2 vTex, vec2 uv)
{
#ifdef CURVATURE
//	vec2 pos = Warp(vTexCoord.xy);
	vec2 pos = Warp(vTex.xy);
#else
//	vec2 pos = vTexCoord.xy;
	vec2 pos = vTex.xy;
#endif

#if defined MASK && !defined ROTATE_SCANLINES
	// mask effects look bad unless applied in linear gamma space
	vec4 in_gamma = vec4(params.crt_gamma, params.crt_gamma, params.crt_gamma, 1.0);
	vec4 out_gamma = vec4(1.0 / params.monitor_gamma, 1.0 / params.monitor_gamma, 1.0 / params.monitor_gamma, 1.0);
	vec4 res = pow(texture(Source, pos), in_gamma);
#else
	vec4 res = texture(Source, pos);
#endif

#if defined MASK && !defined ROTATE_SCANLINES
	// apply the mask; looks bad with vert scanlines so make them mutually exclusive
//	res *= Mask(vTexCoord * params.OutputSize.xy * 1.0001);
	res *= Mask(mix(vTex, uv, global.h_curvature) * mask_size);
#endif

#if defined MASK && !defined ROTATE_SCANLINES
	// re-apply the gamma curve for the mask path
//    FragColor = pow(scanline(pos-vec2(0.0,0.25*params.SourceSize.w), res), out_gamma);
    return pow(scanline(pos-vec2(0.0,0.25*params.SourceSize.w), res), out_gamma).rgb;
#else
//	FragColor = scanline(pos, res);
	return scanline(pos, res).rgb;
#endif
}


#define ReflexSrc Source

// Yeah, an unorthodox 'include' usage.
#include "../../include/uborder_bezel_reflections_main.inc"
