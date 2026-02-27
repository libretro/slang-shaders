#version 450

/* 
Part of the crt-sony-megatron shader group. Does the exact same thing as RetroArch does internally to map into HDR10 space.

This is used to do this mapping BEFORE screen effects are applied.

Originally part of the crt\crt-sony-pvm-4k-hdr.slangp but can be used for any shader
*/

#define SONY_MEGATRON_VERSION_2

#pragma format A2B10G10R10_UNORM_PACK32

#include "include\hdr10.h"

layout(push_constant) uniform Push
{
   float PaperWhiteNits;
   float ExpandGamut;
} params;

#pragma parameter PaperWhiteNits    "Paper White Luminance"                                     200.0    0.0   10000.0  10.0
#pragma parameter ExpandGamut       "Colour Boost: Accurate | Expanded | Wide | Super"          0.0      0.0   3.0      1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
   uint HDRMode;
} global;

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

void main()
{
   vec4 hdr_linear = texture(Source, vTexCoord);

   if(global.HDRMode >= 1u)
   {
      /* Gamut conversion — matches RetroArch menu "Colour Boost" setting:
       * 0=Accurate (709->2020), 1=Expanded, 2=Wide (P3->2020), 3=Super (2020 passthrough) */
      uint gamut = uint(params.ExpandGamut);
      vec3 rec2020;
      if(gamut == 0u)
         rec2020 = hdr_linear.rgb * k709_to_2020;
      else if(gamut == 1u)
         rec2020 = hdr_linear.rgb * kExpanded709_to_2020;
      else if(gamut == 2u)
         rec2020 = hdr_linear.rgb * kP3_to_2020;
      else
         rec2020 = hdr_linear.rgb;
      rec2020 = max(rec2020, vec3(0.0));

      vec3 pq = LinearToST2084(rec2020 * (params.PaperWhiteNits / kMaxNitsFor2084));
      FragColor = vec4(pq, hdr_linear.a);
   }
   else
   {
      FragColor = hdr_linear;
   }
}

