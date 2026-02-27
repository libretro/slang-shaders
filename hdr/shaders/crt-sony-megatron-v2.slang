#version 450

#define SONY_MEGATRON_VERSION_2

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_colour_space;




   float hcrt_lcd_resolution;
   float hcrt_lcd_subpixel;

   float hcrt_red_vertical_convergence;
   float hcrt_green_vertical_convergence;
   float hcrt_blue_vertical_convergence;
   float hcrt_red_horizontal_convergence;
   float hcrt_green_horizontal_convergence;
   float hcrt_blue_horizontal_convergence;
   
   float hcrt_bloom_strength;

   // Developer Settings
   float hcrt_crt_screen_type;
   float hcrt_crt_resolution;

   // Vertical Settings
   float hcrt_red_scanline_min;
   float hcrt_red_scanline_max;
   float hcrt_red_scanline_attack;
   float hcrt_green_scanline_min;
   float hcrt_green_scanline_max;
   float hcrt_green_scanline_attack;
   float hcrt_blue_scanline_min;
   float hcrt_blue_scanline_max;
   float hcrt_blue_scanline_attack;

   // Horizontal Settings
   float hcrt_red_beam_sharpness;
   float hcrt_red_beam_attack;
   float hcrt_green_beam_sharpness;
   float hcrt_green_beam_attack;
   float hcrt_blue_beam_sharpness;
   float hcrt_blue_beam_attack;

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

	float hcrt_r709_gamma_out;
	float hcrt_srgb_gamma_out;
	float hcrt_p3_gamma_out;
   float hcrt_adobe_gamma_out;
	float hcrt_r709_gamma_cutoff;
	float hcrt_srgb_gamma_cutoff;
	
	float hcrt_h_size;
	float hcrt_v_size;
	float hcrt_h_cent;
	float hcrt_v_cent;
} global;

#include "include/parameters_v2.h"

#define HCRT_HDR                             global.HDRMode
#define HCRT_OUTPUT_COLOUR_SPACE             params.hcrt_colour_space
#define HCRT_PAPER_WHITE_NITS                global.PaperWhiteNits
#define HCRT_MAX_NITS                        global.MaxNits
#define HCRT_R709_GAMMA_OUT                  global.hcrt_r709_gamma_out
#define HCRT_SRGB_GAMMA_OUT                  global.hcrt_srgb_gamma_out
#define HCRT_P3_GAMMA_OUT                    global.hcrt_p3_gamma_out
#define HCRT_ADOBE_GAMMA_OUT                 global.hcrt_adobe_gamma_out
#define HCRT_R709_GAMMA_CUTOFF               global.hcrt_r709_gamma_cutoff
#define HCRT_SRGB_GAMMA_CUTOFF               global.hcrt_srgb_gamma_cutoff
#define HCRT_BLOOM_STRENGTH                  params.hcrt_bloom_strength

#define HCRT_LCD_RESOLUTION                  params.hcrt_lcd_resolution 
#define HCRT_LCD_SUBPIXEL                    params.hcrt_lcd_subpixel
#define HCRT_RED_VERTICAL_CONVERGENCE        params.hcrt_red_vertical_convergence
#define HCRT_GREEN_VERTICAL_CONVERGENCE      params.hcrt_green_vertical_convergence
#define HCRT_BLUE_VERTICAL_CONVERGENCE       params.hcrt_blue_vertical_convergence
#define HCRT_RED_HORIZONTAL_CONVERGENCE      params.hcrt_red_horizontal_convergence
#define HCRT_GREEN_HORIZONTAL_CONVERGENCE    params.hcrt_green_horizontal_convergence
#define HCRT_BLUE_HORIZONTAL_CONVERGENCE     params.hcrt_blue_horizontal_convergence

#define HCRT_CRT_SCREEN_TYPE                 params.hcrt_crt_screen_type
#define HCRT_CRT_RESOLUTION                  params.hcrt_crt_resolution

#define HCRT_RED_SCANLINE_MIN                params.hcrt_red_scanline_min
#define HCRT_RED_SCANLINE_MAX                params.hcrt_red_scanline_max
#define HCRT_RED_SCANLINE_ATTACK             params.hcrt_red_scanline_attack
#define HCRT_GREEN_SCANLINE_MIN              params.hcrt_green_scanline_min
#define HCRT_GREEN_SCANLINE_MAX              params.hcrt_green_scanline_max
#define HCRT_GREEN_SCANLINE_ATTACK           params.hcrt_green_scanline_attack
#define HCRT_BLUE_SCANLINE_MIN               params.hcrt_blue_scanline_min
#define HCRT_BLUE_SCANLINE_MAX               params.hcrt_blue_scanline_max
#define HCRT_BLUE_SCANLINE_ATTACK            params.hcrt_blue_scanline_attack

#define HCRT_RED_BEAM_SHARPNESS              params.hcrt_red_beam_sharpness
#define HCRT_RED_BEAM_ATTACK                 params.hcrt_red_beam_attack
#define HCRT_GREEN_BEAM_SHARPNESS            params.hcrt_green_beam_sharpness
#define HCRT_GREEN_BEAM_ATTACK               params.hcrt_green_beam_attack
#define HCRT_BLUE_BEAM_SHARPNESS             params.hcrt_blue_beam_sharpness
#define HCRT_BLUE_BEAM_ATTACK                params.hcrt_blue_beam_attack

#define HCRT_H_SIZE                          global.hcrt_h_size
#define HCRT_V_SIZE                          global.hcrt_v_size
#define HCRT_H_CENT                          global.hcrt_h_cent
#define HCRT_V_CENT                          global.hcrt_v_cent

#include "include/sony_megatron_v2.h"
