#version 450

#define SONY_MEGATRON_VERSION_2

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
   float hcrt_colour_space;
   float hcrt_lcd_resolution;
   float hcrt_lcd_subpixel;
   float hcrt_colour_system;
   float hcrt_phosphor_set;
   float hcrt_white_temperature_D65;
   float hcrt_white_temperature_D93;
   float hcrt_brightness;
   float hcrt_contrast;
   float hcrt_saturation;
   float hcrt_gamma_in;
   float hcrt_gamma_cutoff;
   float hcrt_colour_boost_factor;
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
#define HCRT_OUTPUT_COLOUR_SPACE            params.hcrt_colour_space
#define HCRT_CRT_COLOUR_SYSTEM              params.hcrt_colour_system
#define HCRT_CRT_PHOSPHOR_SET               params.hcrt_phosphor_set
#define HCRT_WHITE_TEMPERATURE_D65          params.hcrt_white_temperature_D65
#define HCRT_WHITE_TEMPERATURE_D93          params.hcrt_white_temperature_D93
#define HCRT_BRIGHTNESS                     params.hcrt_brightness
#define HCRT_CONTRAST                       params.hcrt_contrast
#define HCRT_SATURATION                     params.hcrt_saturation
#define HCRT_GAMMA_IN                       params.hcrt_gamma_in
#define HCRT_GAMMA_CUTOFF                   params.hcrt_gamma_cutoff
#define HCRT_COLOUR_BOOST_FACTOR            params.hcrt_colour_boost_factor

#include "include/sdr_pass_v2.h"
