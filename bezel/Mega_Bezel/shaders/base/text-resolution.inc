/*
    Text code is from the Shadertoy "96-bit 8x12" Font by Flyguy

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include "text-lib.inc"

float DrawResolutions(vec2 uv, vec2 viewport_size, vec2 screen_size, vec2 derezed_size, vec2 negative_crop_added_size, vec2 cropped_original_size, vec2 sampling_res, vec2 int_mult)
{
    float col = 0.0;
    
    float current_line_index = 0;
    float margin = STRHEIGHT(1);

    //Resolution Text
    printPos = vec2(margin, 0);
    
    TEXT_MODE = NORMAL;

    // Line 14 Viewport Resolution ----------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);
    
    TEXT_MODE = NORMAL;  

    col += GetChar(ch_V, uv);
    col += GetChar(ch_i, uv);
    col += GetChar(ch_e, uv);
    col += GetChar(ch_w, uv);
    col += GetChar(ch_p, uv);
    col += GetChar(ch_o, uv);
    col += GetChar(ch_r, uv);
    col += GetChar(ch_t, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);

    col += GetChar(ch_spc, uv);
    col += print_integer(viewport_size.x,0, uv); 
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_x, uv);
    col += GetChar(ch_spc, uv);
    col += print_integer(viewport_size.y,0, uv); 


    // Line 13 Screen Resolution ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);

    col += GetChar(ch_S, uv);
    col += GetChar(ch_c, uv);
    col += GetChar(ch_r, uv);
    col += GetChar(ch_e, uv);
    col += GetChar(ch_e, uv);
    col += GetChar(ch_n, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);

    col += GetChar(ch_spc, uv);
    col += print_integer(screen_size.x,0, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_x, uv);
    col += GetChar(ch_spc, uv);
    col += print_integer(screen_size.y,0, uv);


    // Line 12 Final Aspect Ratio ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);
    
    col += GetChar(ch_F, uv);
    col += GetChar(ch_i, uv);
    col += GetChar(ch_n, uv);
    col += GetChar(ch_a, uv);
    col += GetChar(ch_l, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_A, uv);
    col += GetChar(ch_s, uv);
    col += GetChar(ch_p, uv);
    col += GetChar(ch_e, uv);
    col += GetChar(ch_c, uv);
    col += GetChar(ch_t, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    
    col += GetChar(ch_spc, uv);
    col += print_number(screen_size.x/screen_size.y > 1 ? screen_size.x/screen_size.y : screen_size.y/screen_size.x, uv, 2);


    // Line 11 Non-Int Scale Percent ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);
    
    col += GetChar(ch_N, uv);
    col += GetChar(ch_o, uv);
    col += GetChar(ch_n, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_I, uv);
    col += GetChar(ch_n, uv);
    col += GetChar(ch_t, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_S, uv);
    col += GetChar(ch_c, uv);
    col += GetChar(ch_l, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_pct, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    
    col += GetChar(ch_spc, uv);
    col += print_number(screen_size.y / viewport_size.y * 100, uv, 3);


    // Line 10 Int Scale Vertical ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);
    
    col += GetChar(ch_I, uv);
    col += GetChar(ch_n, uv);
    col += GetChar(ch_t, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_S, uv);
    col += GetChar(ch_c, uv);
    col += GetChar(ch_l, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_V, uv);
    col += GetChar(ch_e, uv);
    col += GetChar(ch_r, uv);
    col += GetChar(ch_t, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    
    col += GetChar(ch_spc, uv);
    if (fract(int_mult.y) < 0.01 || fract(int_mult.y) > 0.99)
        col += print_number(int_mult.y, uv, 0);
    else
        col += print_number(int_mult.y, uv, 3);


    // Line 09 Int Scale Horizontal ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);
    
    col += GetChar(ch_I, uv);
    col += GetChar(ch_n, uv);
    col += GetChar(ch_t, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_S, uv);
    col += GetChar(ch_c, uv);
    col += GetChar(ch_l, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_H, uv);
    col += GetChar(ch_o, uv);
    col += GetChar(ch_r, uv);
    col += GetChar(ch_z, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    
    col += GetChar(ch_spc, uv);
    if (fract(int_mult.x) < 0.01 || fract(int_mult.x) > 0.99)
        col += print_number(int_mult.x, uv, 0);
    else
        col += print_number(int_mult.x, uv, 3);


    // Line 08 Sampling Resolution ----------------------------------------------------------
    if (cropped_original_size.x != sampling_res.x || cropped_original_size.y != sampling_res.y)
    {
        printPos.x = margin;
        printPos.y += STRHEIGHT(1);
        
        col += GetChar(ch_S, uv);
        col += GetChar(ch_a, uv);
        col += GetChar(ch_m, uv);
        col += GetChar(ch_p, uv);
        col += GetChar(ch_l, uv);
        col += GetChar(ch_i, uv);
        col += GetChar(ch_n, uv);
        col += GetChar(ch_g, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_R, uv);
        col += GetChar(ch_e, uv);
        col += GetChar(ch_s, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);

        col += GetChar(ch_spc, uv);
        col += print_integer(sampling_res.x,0, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_x, uv);
        col += GetChar(ch_spc, uv);
        col += print_integer(sampling_res.y,0, uv);
    }


    // Line 07 CROPPED Resolution ----------------------------------------------------------
    if (cropped_original_size.x != ROTATED_CORE_PREPPED_SIZE.x || cropped_original_size.y != ROTATED_CORE_PREPPED_SIZE.y)
    {
        printPos.x = margin;
        printPos.y += STRHEIGHT(1);
        
        col += GetChar(ch_C, uv);
        col += GetChar(ch_r, uv);
        col += GetChar(ch_o, uv);
        col += GetChar(ch_p, uv);
        col += GetChar(ch_p, uv);
        col += GetChar(ch_e, uv);
        col += GetChar(ch_d, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);

        col += GetChar(ch_spc, uv);
        col += print_integer(cropped_original_size.x,0, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_x, uv);
        col += GetChar(ch_spc, uv);
        col += print_integer(cropped_original_size.y,0, uv);
    }


    // Line 06 Negative Crop Resolution ----------------------------------------------------------
    if (derezed_size.x != ROTATED_CORE_PREPPED_SIZE.x || derezed_size.y != ROTATED_CORE_PREPPED_SIZE.y)
    {
        printPos.x = margin;
        printPos.y += STRHEIGHT(1);
        
        col += GetChar(ch_N, uv);
        col += GetChar(ch_e, uv);
        col += GetChar(ch_g, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_C, uv);
        col += GetChar(ch_r, uv);
        col += GetChar(ch_o, uv);
        col += GetChar(ch_p, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_A, uv);
        col += GetChar(ch_d, uv);
        col += GetChar(ch_d, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);

        col += GetChar(ch_spc, uv);
        col += print_integer(ROTATED_CORE_PREPPED_SIZE.x,0, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_x, uv);
        col += GetChar(ch_spc, uv);
        col += print_integer(ROTATED_CORE_PREPPED_SIZE.y,0, uv);
    }


    // Line 05 DEREZ Resolution ----------------------------------------------------------
    if (derezed_size.x != ROTATED_CORE_ORIGINAL_SIZE.x || derezed_size.y != ROTATED_CORE_ORIGINAL_SIZE.y)
    {
        printPos.x = margin;
        printPos.y += STRHEIGHT(1);
        
        col += GetChar(ch_D, uv);
        col += GetChar(ch_e, uv);
        col += GetChar(ch_r, uv);
        col += GetChar(ch_e, uv);
        col += GetChar(ch_z, uv);
        col += GetChar(ch_e, uv);
        col += GetChar(ch_d, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);
        col += GetChar(ch_dsh, uv);

        col += GetChar(ch_spc, uv);
        col += print_integer(derezed_size.x,0, uv);
        col += GetChar(ch_spc, uv);
        col += GetChar(ch_x, uv);
        col += GetChar(ch_spc, uv);
        col += print_integer(derezed_size.y,0, uv);
    }


    // Line 04 CORE Resolution ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);
    
    col += GetChar(ch_C, uv);
    col += GetChar(ch_o, uv);
    col += GetChar(ch_r, uv);
    col += GetChar(ch_e, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_dsh, uv);

    col += GetChar(ch_spc, uv);
    col += print_integer(ROTATED_CORE_ORIGINAL_SIZE.x,0, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_x, uv);
    col += GetChar(ch_spc, uv);
    col += print_integer(ROTATED_CORE_ORIGINAL_SIZE.y,0, uv);


    // Line 03 Preset Type ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(2);
    
#ifdef IS_ADV_PRESET
    col += GetChar(ch_A, uv);
    col += GetChar(ch_D, uv);
    col += GetChar(ch_V, uv);
    col += GetChar(ch_A, uv);
    col += GetChar(ch_N, uv);
    col += GetChar(ch_C, uv);
    col += GetChar(ch_E, uv);
    col += GetChar(ch_D, uv);
#endif

#ifdef IS_STD_PRESET
    col += GetChar(ch_S, uv);
    col += GetChar(ch_T, uv);
    col += GetChar(ch_A, uv);
    col += GetChar(ch_N, uv);
    col += GetChar(ch_D, uv);
    col += GetChar(ch_A, uv);
    col += GetChar(ch_R, uv);
    col += GetChar(ch_D, uv);
#endif

#ifdef IS_GLASS_PRESET
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_G, uv);
    col += GetChar(ch_L, uv);
    col += GetChar(ch_A, uv);
    col += GetChar(ch_S, uv);
    col += GetChar(ch_S, uv);
#endif

#ifdef IS_NO_REFLECT_PRESET
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_N, uv);
    col += GetChar(ch_O, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_R, uv);
    col += GetChar(ch_E, uv);
    col += GetChar(ch_F, uv);
    col += GetChar(ch_L, uv);
    col += GetChar(ch_E, uv);
    col += GetChar(ch_C, uv);
    col += GetChar(ch_T, uv);
#endif

#ifdef IS_POTATO_PRESET
    col += GetChar(ch_P, uv);
    col += GetChar(ch_0, uv);
    col += GetChar(ch_T, uv);
    col += GetChar(ch_A, uv);
    col += GetChar(ch_T, uv);
    col += GetChar(ch_O, uv);
#endif


    // Line 02 Version ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);

    col += GetChar(ch_1, uv);
    col += GetChar(ch_per, uv);
    col += GetChar(ch_2, uv);
    col += GetChar(ch_per, uv);
    col += GetChar(ch_0, uv);
    col += GetChar(ch_spc, uv);

    // Date
    col += GetChar(ch_2, uv);
    col += GetChar(ch_0, uv);
    col += GetChar(ch_2, uv);
    col += GetChar(ch_2, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_0, uv);
    col += GetChar(ch_9, uv);
    col += GetChar(ch_dsh, uv);
    col += GetChar(ch_1, uv);
    col += GetChar(ch_1, uv);


    // Line 01 Title ----------------------------------------------------------
    printPos.x = margin;
    printPos.y += STRHEIGHT(1);

    col += GetChar(ch_M, uv);
    col += GetChar(ch_E, uv);
    col += GetChar(ch_G, uv);
    col += GetChar(ch_A, uv);
    col += GetChar(ch_spc, uv);
    col += GetChar(ch_B, uv);
    col += GetChar(ch_E, uv);
    col += GetChar(ch_Z, uv);
    col += GetChar(ch_E, uv);
    col += GetChar(ch_L, uv);
    col += GetChar(ch_spc, uv);


    TEXT_MODE = NORMAL;  

    return col;
}

// Returns a 
float GetTextMask(vec2 in_coord, vec2 viewport_size, vec2 screen_size, vec2 derezed_size, vec2 negative_crop_added_size, vec2 cropped_original_size, vec2 sampling_res, vec2 int_mult, vec2 canvas_size)
{
    in_coord = (in_coord - 0.5) * vec2(1, -1) + 0.5;
    float downscale = 1;
    if (canvas_size.y > 600) downscale = 2;
    if (canvas_size.y > 1000) downscale = 3;

	textCanvasResolution = global.OutputSize.xy / downscale;
    vec2 uv = global.OutputSize.xy * in_coord;
	vec2 downscaled_uv = floor(global.OutputSize.xy * in_coord / downscale);
    
	float pixel = DrawResolutions(downscaled_uv, viewport_size, screen_size, derezed_size, negative_crop_added_size, cropped_original_size, sampling_res, int_mult);
    
    vec3 col = vec3(1);
    pixel *= (1 - distance(mod(uv, vec2(1.0)), vec2(0.65))) * 1.2;
    col *= mix(vec3(0), vec3(1, 1, 1), pixel);

	return col.r;
}