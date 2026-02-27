#version 450

#define SONY_MEGATRON_VERSION_2

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_max_nits;
   float hcrt_paper_white_nits;
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
} global;

#include "include/parameters_v2_config.h"

#define HCRT_HDR                            global.HDRMode
#define HCRT_MAX_NITS                       params.hcrt_max_nits
#define HCRT_PAPER_WHITE_NITS               params.hcrt_paper_white_nits
#define HCRT_OUTPUT_COLOUR_SPACE            params.hcrt_colour_space

#define HCRT_R709_GAMMA_OUT                 params.hcrt_r709_gamma_out
#define HCRT_SRGB_GAMMA_OUT                 params.hcrt_srgb_gamma_out
#define HCRT_P3_GAMMA_OUT                   params.hcrt_p3_gamma_out
#define HCRT_ADOBE_GAMMA_OUT                params.hcrt_adobe_gamma_out
#define HCRT_R709_GAMMA_CUTOFF              params.hcrt_r709_gamma_cutoff
#define HCRT_SRGB_GAMMA_CUTOFF              params.hcrt_srgb_gamma_cutoff

#include "include/hdr_pass_v2.h"
