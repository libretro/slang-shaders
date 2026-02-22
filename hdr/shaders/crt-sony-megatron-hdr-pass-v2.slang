#version 450

/* 
A shader that tries to emulate a sony PVM type aperture grille screen but with full brightness.

The novel thing about this shader is that it relies on the HDR shaders to brighten up the image so that when 
we apply this shader which emulates the apperture grille the resulting screen isn't left too dark.  

I think you need at least a DisplayHDR 600 monitor but to get close to CRT levels of brightness I think DisplayHDR 1000.

Please Enable HDR in RetroArch 1.10+

NOTE: when this shader is envoked the Contrast, Peak Luminance and Paper White Luminance in the HDR menu do nothing instead set those values through the shader parameters 

For this shader set Paper White Luminance to above 700 and Peak Luminance to the peak luminance of your monitor.  

Also try to use a integer scaling - its just better - overscaling is fine.

This shader doesn't do any geometry warping or bouncing of light around inside the screen etc - I think these effects just add unwanted noise, I know people disagree. Please feel free to make you own and add them

Dont use this shader directly - use the hdr\crt-make-model-hdr.slangp where make and model are the make and model of the CRT you want.

THIS SHADER DOES NOT SUPPORT WRGB OLED (Due to the sub pixel layout of WRGB - RGB QD-OLED or LCD (and variants thereof screens are fine)
*/

#define SONY_MEGATRON_VERSION_2

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_hdr;
   float hcrt_max_nits;
   float hcrt_paper_white_nits;
   float hcrt_expand_gamut;
   float hcrt_colour_space;
	
   float hcrt_r709_gamma_out;
   float hcrt_srgb_gamma_out;
   float hcrt_p3_gamma_out;
   float hcrt_adobe_gamma_out;
   float hcrt_r709_gamma_cutoff;
   float hcrt_srgb_gamma_cutoff;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;	
	uint HDRMode;
	float PaperWhiteNits;
	float MaxNits;
} global;

#include "include/parameters_v2.h"

#define HCRT_HDR                            global.HDRMode
#define HCRT_MAX_NITS                       global.MaxNits
#define HCRT_PAPER_WHITE_NITS               global.PaperWhiteNits
#define HCRT_OUTPUT_COLOUR_SPACE            params.hcrt_colour_space

#define HCRT_R709_GAMMA_OUT                 params.hcrt_r709_gamma_out
#define HCRT_SRGB_GAMMA_OUT                 params.hcrt_srgb_gamma_out
#define HCRT_P3_GAMMA_OUT                   params.hcrt_p3_gamma_out
#define HCRT_ADOBE_GAMMA_OUT                params.hcrt_adobe_gamma_out
#define HCRT_R709_GAMMA_CUTOFF              params.hcrt_r709_gamma_cutoff
#define HCRT_SRGB_GAMMA_CUTOFF              params.hcrt_srgb_gamma_cutoff

#include "include/hdr_pass_v2.h"
