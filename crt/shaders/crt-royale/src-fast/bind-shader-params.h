#ifndef BIND_SHADER_PARAMS_H
#define BIND_SHADER_PARAMS_H

/*
    crt-royale-fast: a fast crt-royale adapted from original sources by Hyllian (2024).

    Aims to deliver a fast shader with crt-royale visual style by sacrificing some
    of its complex features.
*/

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA



/////////////////////////////  SETTINGS MANAGEMENT  ////////////////////////////

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	float crt_gamma;
	float lcd_gamma;
	float levels_contrast;
	float bloom_underestimate_levels;
	float bloom_excess;
	float beam_min_sigma;
	float beam_max_sigma;
	float beam_spot_power;
	float beam_min_shape;
	float beam_max_shape;
	float beam_shape_power;
	float beam_horiz_filter;
	float beam_horiz_sigma;
	float beam_horiz_linear_rgb_weight;
	float mask_type;
	float mask_triad_size_desired;
	float geom_aspect_ratio_x;
	float geom_aspect_ratio_y;
	float interlace_bff;
	float interlace_1080i;
	float interlace_detect_toggle;
} global;


#pragma parameter crt_gamma "Simulated CRT Gamma" 2.5 1.0 5.0 0.025
#define crt_gamma global.crt_gamma
#pragma parameter lcd_gamma "Your Display Gamma" 2.2 1.0 5.0 0.025
#define lcd_gamma global.lcd_gamma
#pragma parameter levels_contrast "Contrast" 1.0 0.0 4.0 0.015625
#define levels_contrast global.levels_contrast
#pragma parameter bloom_underestimate_levels "Bloom - Underestimate Levels" 0.8 0.0 5.0 0.01
#define bloom_underestimate_levels global.bloom_underestimate_levels
#pragma parameter bloom_excess "Bloom - Excess" 0.0 0.0 1.0 0.005
#pragma parameter beam_min_sigma "Beam - Min Sigma" 0.02 0.005 1.0 0.005
#define beam_min_sigma global.beam_min_sigma
#pragma parameter beam_max_sigma "Beam - Max Sigma" 0.3 0.005 1.0 0.005
#define beam_max_sigma global.beam_max_sigma
#pragma parameter beam_spot_power "Beam - Spot Power" 0.33 0.01 16.0 0.01
#define beam_spot_power global.beam_spot_power
#pragma parameter beam_min_shape "Beam - Min Shape" 2.0 2.0 32.0 0.1
#define beam_min_shape global.beam_min_shape
#pragma parameter beam_max_shape "Beam - Max Shape" 4.0 2.0 32.0 0.1
#define beam_max_shape global.beam_max_shape
#pragma parameter beam_shape_power "Beam - Shape Power" 0.25 0.01 16.0 0.01
#define beam_shape_power global.beam_shape_power
#pragma parameter beam_horiz_filter "Beam - Horiz Filter" 0.0 0.0 2.0 1.0
#define beam_horiz_filter global.beam_horiz_filter
#pragma parameter beam_horiz_sigma "Beam - Horiz Sigma" 0.35 0.0 0.67 0.005
#define beam_horiz_sigma global.beam_horiz_sigma
#pragma parameter beam_horiz_linear_rgb_weight "Beam - Horiz Linear RGB Weight" 1.0 0.0 1.0 0.01
#pragma parameter mask_type "Mask - Type" 0.0 0.0 2.0 1.0
#define mask_type global.mask_type
#pragma parameter mask_triad_size_desired "Mask - Triad Size Desired" 3.0 1.0 18.0 0.125
#pragma parameter interlace_detect_toggle "Interlacing - Toggle" 1.0 0.0 1.0 1.0
bool interlace_detect = bool(global.interlace_detect_toggle);
#pragma parameter interlace_bff "Interlacing - Bottom Field First" 0.0 0.0 1.0 1.0
//#define interlace_bff global.interlace_bff
#pragma parameter interlace_1080i "Interlace - Detect 1080i" 0.0 0.0 1.0 1.0
#define interlace_1080i global.interlace_1080i

//  LEVELS MANAGEMENT:
float levels_autodim_temp = 0.5;              //  range (0, 1]

bool  beam_generalized_gaussian = true;
float beam_antialias_level      = 1.0;        //  range [0, 2]
float beam_spot_shape_function  = 0.0;
float beam_spot_power_static    = 1.0/3.0;    //  range (0, 16]
float beam_min_shape_static     = 2.0;        //  range [2, 32]
float beam_max_shape_static     = 4.0;        //  range [2, 32]

//  PHOSPHOR MASK:
float mask_sinc_lobes = 3.0;                  //  range [2, 4]
float mask_min_allowed_triad_size = 2.0;

//  PASS SCALES AND RELATED CONSTANTS:
vec2  mask_resize_viewport_scale = vec2(0.0625, 0.0625);

//  PHOSPHOR MASK TEXTURE CONSTANTS:
vec2  mask_texture_small_size = vec2(64.0, 64.0);
float mask_triads_per_tile    = 8.0;
float mask_grille_avg_color   = 53.0/255.0;
float mask_slot_avg_color     = 46.0/255.0;
float mask_shadow_avg_color   = 50.0/255.0;

#define FIX_ZERO(c) (max(abs(c), 0.0000152587890625))   //  2^-16

float bloom_approx_filter      = 0.0;
vec2  mask_resize_src_lut_size = mask_texture_small_size;
float max_aa_base_pixel_border = 0.0;
float max_aniso_pixel_border = max_aa_base_pixel_border + 0.5;
float max_tiled_pixel_border = max_aniso_pixel_border;
float max_mask_texel_border = ceil(max_tiled_pixel_border);
float max_mask_tile_border = max_mask_texel_border/
        (mask_min_allowed_triad_size * mask_triads_per_tile);
float mask_resize_num_tiles = 1.0 + 2.0 * max_mask_tile_border;
float mask_start_texels = max_mask_texel_border;
float mask_resize_num_triads = mask_resize_num_tiles * mask_triads_per_tile;
vec2  min_allowed_viewport_triads = vec2(mask_resize_num_triads) / mask_resize_viewport_scale;

//  Calculate {sigma, shape}_range outside of scanline_contrib so it's only
//  done once per pixel (not 6 times) with runtime params.  Don't reuse the
//  vertex shader calculations, so static versions can be constant-folded.
float sigma_range = max(beam_max_sigma, beam_min_sigma) - beam_min_sigma;
float shape_range = max(beam_max_shape, beam_min_shape) - beam_min_shape;

////////////////////////  COMMON MATHEMATICAL CONSTANTS  ///////////////////////

float pi = 3.141592653589;
float under_half = 0.4995;

//  Provide accessors settings which still need "cooking:"
float get_mask_amplify()
{
    float mask_grille_amplify = 1.0/mask_grille_avg_color;
    float mask_slot_amplify   = 1.0/mask_slot_avg_color;
    float mask_shadow_amplify = 1.0/mask_shadow_avg_color;

    return mask_type < 0.5 ? mask_grille_amplify :
        mask_type < 1.5 ? mask_slot_amplify :
        mask_shadow_amplify;
}

#endif  //  BIND_SHADER_PARAMS_H
