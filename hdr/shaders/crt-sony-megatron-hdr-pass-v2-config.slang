#version 450

#define SONY_MEGATRON_VERSION_2

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_max_nits;
   float hcrt_paper_white_nits;
   float hcrt_expand_gamut;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float EnableHDR;
} global;

#include "include/parameters_v2_config.h"

#define HCRT_HDR                            global.EnableHDR
#define HCRT_MAX_NITS                       params.hcrt_max_nits
#define HCRT_PAPER_WHITE_NITS               params.hcrt_paper_white_nits
#define HCRT_EXPAND_GAMUT                   params.hcrt_expand_gamut

#include "include/hdr_pass_v2.h"
