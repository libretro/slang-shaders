#version 450

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_hdr;
   float hcrt_max_nits;
   float hcrt_paper_white_nits;
   float hcrt_expand_gamut;
   float hcrt_colour_accurate;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} global;

#include "include/parameters.h"

#define HCRT_HDR                            params.hcrt_hdr
#define HCRT_MAX_NITS                       params.hcrt_max_nits
#define HCRT_PAPER_WHITE_NITS               params.hcrt_paper_white_nits
#define HCRT_EXPAND_GAMUT                   params.hcrt_expand_gamut
#define HCRT_COLOUR_ACCURATE                params.hcrt_colour_accurate

#include "include/hdr_pass_v1.h"
