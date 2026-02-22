#version 450

/* 
Part of the crt-sony-megatron shader group. Does the exact same thing as RetroArch does internally to inverse tonemap from a SDR image to HDR.

This is used to do this mapping BEFORE screen effects are applied.

Originally part of the crt\crt-sony-pvm-4k-hdr.slangp but can be used for any shader
*/

#define SONY_MEGATRON_VERSION_2

#pragma format R16G16B16A16_SFLOAT

#include "include\inverse_tonemap.h"

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float PaperWhiteNits;
   float MaxNits;
   float DisplayGamma;
} params;

#pragma parameter PaperWhiteNits    "Paper White Luminance" 200.0    0.0 10000.0 10.0
#pragma parameter MaxNits           "Peak Luminance"        1000.0   0.0 10000.0 10.0
#pragma parameter DisplayGamma      "Display Gamma"         2.2      0.0 5.0     0.1

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
   vec4 source = texture(Source, vTexCoord);

   vec3 sdr = pow(abs(source.rgb), vec3(params.DisplayGamma));       /* Display Gamma - needs to be determined by calibration screen */

   if(global.HDRMode >= 1u)
   {
      FragColor = vec4(InverseTonemap(sdr, params.MaxNits, params.PaperWhiteNits), source.a); 
   }
   else
   {
      FragColor = vec4 (sdr, source.a); 
   }
}

