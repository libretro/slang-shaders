#version 450

#define ADAMANT

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_hdr;
   float hcrt_new;
   float hcrt_max_nits;
   float hcrt_paper_white_nits;
   float hcrt_content_gamut;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;	
	float EnableHDR;
	float PaperWhiteNits;
	float MaxNits;
} global;

#include "include/parameters.h"

#define HCRT_HDR                            params.hcrt_hdr
#define HCRT_MAX_NITS                       params.hcrt_max_nits
#define HCRT_PAPER_WHITE_NITS               params.hcrt_paper_white_nits
#define HCRT_CONTENT_GAMUT                   params.hcrt_content_gamut

#define COMPAT_TEXTURE(c, d) texture(c, d)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * vec2(1.00001);  // To resolve rounding issues when sampling
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "include/inverse_tonemap.h"
#include "include/hdr10.h"

void main()
{
   vec3 hdr_colour = COMPAT_TEXTURE(Source, vTexCoord).rgb;

   if(HCRT_HDR >= 1.0f)
   {
      hdr_colour = InverseTonemap(hdr_colour, HCRT_MAX_NITS, HCRT_PAPER_WHITE_NITS);
   }

   FragColor = vec4(hdr_colour, 1.0);
}
