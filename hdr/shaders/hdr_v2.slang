#version 450

/* 
Part of the crt-sony-megatron shader group. Does the exact same thing as RetroArch does internally to map into HDR10 space.

This is used to do this mapping BEFORE screen effects are applied.

Originally part of the crt\crt-sony-pvm-4k-hdr.slangp but can be used for any shader
*/

#define SONY_MEGATRON_VERSION_2

#pragma format A2B10G10R10_UNORM_PACK32

layout(push_constant) uniform Push
{
   float ColourSpace;
   float DisplayGamma;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
	float EnableHDR;
    float MaxNits;
    float PaperWhiteNits;
    float ExpandGamut;
} global;

#pragma parameter DisplayGamma      "Display Gamma"                                             2.2      0.0   5.0   0.1
#pragma parameter ColourSpace       "Colour Space: r709 | sRGB | DCI-P3 | NTSC | PAL | Adobe"   1.0      0.0   5.0   1.0

#include "include\hdr10.h"
#include "include\inverse_tonemap.h"

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
   vec4 source = texture(Source, vTexCoord);

   vec3 sdr = pow(abs(source.rgb), vec3(params.DisplayGamma));       /* Display Gamma - needs to be determined by calibration screen */

   if(global.EnableHDR >= 1.0f)
   {
      vec4 hdr_linear = vec4(InverseTonemap(sdr, global.MaxNits, global.PaperWhiteNits), source.a); 
      
      FragColor = vec4(Hdr10(hdr_linear.rgb, global.PaperWhiteNits, params.ColourSpace, global.ExpandGamut), hdr_linear.a); 
   }
   else
   {
      FragColor = vec4 (sdr, source.a); 
   }
}
