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
   float ColourSpace;
   float ExpandGamut;
} params;

#pragma parameter PaperWhiteNits    "Paper White Luminance"                                     200.0    0.0   10000.0  10.0
#pragma parameter ColourSpace       "Colour Space: r709 | sRGB | DCI-P3 | NTSC | PAL | Adobe"   1.0      0.0   5.0      1.0
#pragma parameter ExpandGamut       "Colour Boost"                                              1.0      0.0   1.0      1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
   float EnableHDR;
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
   
   if(global.EnableHDR >= 1.0f)
   {
      FragColor = vec4(Hdr10(hdr_linear.rgb, params.PaperWhiteNits, params.ColourSpace, params.ExpandGamut), hdr_linear.a); 
   }
   else
   {
      FragColor = hdr_linear; 
   }
}

