/*
    Yah! - Yet Another Hyllian
    Based on CRT shader by Hyllian
    Modified by Jezze

    Copyright (C) 2011-2025 Hyllian - sergiogdb@gmail.com
    Copyright (C) 2023-2025 Jezze - jezze@gmx.net
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

#include "common/color-helper.h"
#include "common/frame-helper.h"
#include "common/interpolation-helper.h"
#include "common/math-helper.h"
#include "common/subpixel-color.h"

float get_brightness_compensation(float color_luma)
{
    float mask_blend = 1.0 - (1.0 - PARAM_MASK_BLEND) * (1.0 - PARAM_MASK_BLEND);
    
    return PARAM_COLOR_COMPENSATION > 0.0
        ? mix(
            INPUT_BRIGHTNESS_COMPENSATION,
            INPUT_BRIGHTNESS_COMPENSATION * (1.0 - color_luma),
            mask_blend)
        : 0.0;
}

vec3 INPUT(vec3 color)
{
    color = decode_gamma(color);
    color = apply_floor(color, PARAM_COLOR_FLOOR * PARAM_COLOR_BLACK_LIGHT);

    return color;
}

vec3 OUTPUT(vec3 color, float color_luma)
{
    color = apply_contrast(color, PARAM_COLOR_CONTRAST);
    color = apply_brightness(color, PARAM_COLOR_BRIGHTNESS + get_brightness_compensation(color_luma));
    color = apply_saturation(color, PARAM_COLOR_SATURATION);
    color = apply_temperature(color, PARAM_COLOR_TEMPERATUE);
    color = encode_gamma(color);

    return color;
}

// orientation-aware vec2 constructors
vec2 vec2o(vec2 v)
{
    return INPUT_SCREEN_ORIENTATION == 0.0
        ? v.xy
        : v.yx;
}

vec2 vec2o(float x, float y)
{
    return INPUT_SCREEN_ORIENTATION == 0.0
        ? vec2(x, y)
        : vec2(y, x);
}

vec2 vec2ox(vec2 v, float f)
{
    return INPUT_SCREEN_ORIENTATION == 0.0
        ? vec2(v.x, f)
        : vec2(f, v.y);
}

vec2 vec2oy(vec2 v, float f)
{
    return INPUT_SCREEN_ORIENTATION == 0.0
        ? vec2(f, v.y)
        : vec2(v.x, f);
}

vec2 apply_sharp_bilinear_filtering(vec2 tex_coord)
{
    return sharp_bilinear(tex_coord, global.SourceSize.xy, global.OutputSize.xy);
}

vec2 apply_cubic_lens_distortion(vec2 tex_coord)
{
    float amount = PARAM_CRT_CURVATURE_AMOUNT;

    // center coordinates
    tex_coord -= 0.5;

    // compute cubic distortion factor
    float c = tex_coord.x * tex_coord.x + tex_coord.y * tex_coord.y;
    float f = 1.0 + c * (amount * sqrt(c));

    // fit screen bounds
    f /= 1.0 + amount * 0.125;

    // apply cubic distortion factor
    tex_coord *= f;

    // un-center coordinates
    tex_coord += 0.5;

    return tex_coord;
}

float get_vignette_factor(vec2 tex_coord)
{
    float amount = PARAM_CRT_VIGNETTE_AMOUNT;

    // center coordinates
    tex_coord -= 0.5;

    // compute vignetting
    float vignette_radius = 1.0 - (amount * 0.25);
    float vignette_length = length(tex_coord);
    float vignette_blur = (amount * 0.125) + 0.375;
    float vignette = smoothstep(vignette_radius, vignette_radius - vignette_blur, vignette_length);

    return clamp(vignette, 0.0, 1.0);
}

float get_round_corner_factor(vec2 tex_coord)
{
    return smooth_round_box(
        tex_coord,
        global.OutputSize.xy,
        vec2(1.0),
        PARAM_CRT_CORNER_RAIDUS,
        PARAM_CRT_CORNER_SMOOTHNESS);
}

vec3 get_half_scanlines_factor(vec3 color, float position)
{
    float min_width = INPUT_BEAM_PROFILE.x;
    float max_width = INPUT_BEAM_PROFILE.y;
    float slope = INPUT_BEAM_PROFILE.z;
    float strength = INPUT_BEAM_PROFILE.w;

    // limit color burn
    vec3 width_limit = mix(
        // max. color value for all channel
        vec3(max_color(color)),
        // no limit
        color,
        PARAM_SCANLINES_COLOR_BURN);

    // apply min./max. width
    vec3 width = mix(
        vec3(min_width),
        vec3(max_width),
        width_limit);

    // apply strength and slope
    vec3 factor = position / (width + EPSILON);
    factor = exp(-10.0 * strength * pow(factor, vec3(slope)));

    return factor;
}

vec3 get_half_beam_color(sampler2D source, vec2 tex_coord, vec2 delta_x, vec2 delta_y, vec4 beam_filter)
{
    // get spline bases
    vec3 x = INPUT(texture(source, tex_coord -       delta_x - delta_y).rgb);
    vec3 y = INPUT(texture(source, tex_coord                 - delta_y).rgb);
    vec3 z = INPUT(texture(source, tex_coord +       delta_x - delta_y).rgb);
    vec3 w = INPUT(texture(source, tex_coord + 2.0 * delta_x - delta_y).rgb);

    // get color from spline
    vec3 color = mat4x3(x, y, z, w) * beam_filter;

    // map filter range [-1.0, 1.0] to anti-ringing factor [0.5, 0.0] 
    float anti_ringing_auto = 1.0 - smoothstep(1.5, 2.0, PARAM_BEAM_FILTER + 1.0);
    float anti_ringing_manual = PARAM_ANTI_RINGING;

    // apply anti-ringing
    vec3 color_step = step(0.0, abs(x - y) * abs(z - w));
    vec3 color_clamp = clamp(color, min(y, z), max(y, z));
    color = mix(
        color,
        color_clamp,
        color_step * anti_ringing_auto * anti_ringing_manual);

    return color;
}

vec3 get_raw_color(sampler2D source, vec2 tex_coord)
{
    return INPUT(texture(source, tex_coord).rgb);
}

vec2 get_scanlines_pixel_coordinate(vec2 tex_coord, vec2 tex_size)
{
    // texture to pixel coordinates
    vec2 pix_coord = tex_coord * tex_size;

    // apply half pixel offset (align to pixel corner)
    pix_coord += vec2(0.5, 0.5);

    return pix_coord;
}

vec2 get_scanlines_texel_coordinate(vec2 pix_coord, vec2 tex_size, vec2 multiple)
{
    vec2 tex_coord = floor(pix_coord);

    // when manual down-scaled
    if (INPUT_SCREEN_MULTIPLE > 1.0)
    {
        // apply half texel offset scaled by absolut amount of multiple
        tex_coord += vec2o(-0.5, 0.5) / multiple;
    }
    // when manual up-scaled
    else
    {
        // apply half texel offset
        tex_coord += vec2o(-0.5, 0.5);
    }

    // when automatic down-scaled
    if (INPUT_SCREEN_MULTIPLE_AUTO > 1.0)
    {
        // apply half texel x-offset (to sample between two pixel anlong scanlines)
        tex_coord += vec2o(-0.5, 0.0);
    }
    // when not automatic but manual down-scaled
    else if (INPUT_SCREEN_MULTIPLE > 1.0)
    {
        // apply half texel y-offset scaled by relative amount of multiple (to sample between two pixel between scanlines)
        tex_coord += vec2o(0.0, 0.5) / multiple * (INPUT_SCREEN_MULTIPLE - 1.0);
    }

    float scanlines_offset = PARAM_SCANLINES_OFFSET > 0.0
        // fixed offset
        ? PARAM_SCANLINES_OFFSET
        // jitter offset each 2nd frame with 60fps
        : mod(GetUniformFrameCount(60), 2) > 0.0
            ? 0.0
            : abs(PARAM_SCANLINES_OFFSET);

    // when automatic down-scaled
    if (INPUT_SCREEN_MULTIPLE_AUTO > 1.0)
    {
        float slope = 1.0 - 1.0 / INPUT_SCREEN_MULTIPLE;

        // apply manual half texel y-offset by exponential amout of multiple
        tex_coord += vec2o(0.0, 0.5) * normalized_sigmoid(scanlines_offset / 2.0, -slope) * 2.0;
    }
    // when not automatic down-scaled
    else
    {
        // apply manual half texel y-offset
        tex_coord += vec2o(0.0, 0.5) * scanlines_offset;
    }

    // pixel to texture coordinates
    tex_coord /= tex_size;

    return tex_coord;
}

vec3 get_scanlines_color(sampler2D source, vec2 tex_coord)
{
    vec2 multiple = vec2o(1.0, INPUT_SCREEN_MULTIPLE);

    // apply "fake" scale (only y-axis)
    vec2 tex_size = global.OriginalSize.xy / multiple;

    vec2 pix_coord = vec2(0.0);
    pix_coord = get_scanlines_pixel_coordinate(tex_coord, tex_size);
    tex_coord = get_scanlines_texel_coordinate(pix_coord, tex_size, multiple);

    vec2 tex_delta = vec2(1.0) / tex_size;
    vec2 tex_delta_x = vec2ox(tex_delta, 0.0);
    vec2 tex_delta_y = vec2oy(tex_delta, 0.0);

    vec2 pix_fract = vec2o(fract(pix_coord));

    // apply filtering
    vec4 beam_filter = vec4(
        pix_fract.x * pix_fract.x * pix_fract.x,
        pix_fract.x * pix_fract.x,
        pix_fract.x,
        1.0) * INPUT_BEAM_FILTER;

    vec3 color0 = get_half_beam_color(source, tex_coord, tex_delta_x, tex_delta_y, beam_filter);
    vec3 color1 = get_half_beam_color(source, tex_coord, tex_delta_x, vec2(0.0), beam_filter);

    // apply scanlines
    vec3 factor0 = get_half_scanlines_factor(color0, pix_fract.y);
    vec3 factor1 = get_half_scanlines_factor(color1, 1.0 - pix_fract.y);

    return color0 * factor0 + color1 * factor1;
}

vec3 blend_colors(vec3 raw_color, vec3 scanlines_color)
{
    if (PARAM_SCANLINES_STRENGTH == 0.0)
    {
        return raw_color;
    }

    // merged raw color with scanlines for strength < 0.125
    float merge_limit = min(1.0, PARAM_SCANLINES_STRENGTH * 8);

    return mix(
        raw_color,
        scanlines_color,
        merge_limit);
}

vec3 get_mask(vec2 tex_coord)
{
    vec2 pix_coord = vec2o(tex_coord * global.OutputSize.xy);

    // change subpixel type 1 to 2 and swap subpixel colors from 2-MG to 1-BY
    int subpixel_type = PARAM_MASK_SUBPIXEL < 2.0
        ? int(PARAM_MASK_SUBPIXEL + 1)
        : int(PARAM_MASK_SUBPIXEL);
    bool subpixel_color_swap = PARAM_MASK_SUBPIXEL < 2.0;

    float subpixel_mask = PARAM_MASK_TYPE;
    float subpixel_size = INPUT_MASK_PROFILE.x;
    float subpixel_smoothness = INPUT_MASK_PROFILE.y;

    vec3 mask = get_subpixel_color(
        pix_coord,
        int(subpixel_size),
        int(subpixel_mask),
        subpixel_type,
        subpixel_color_swap,
        1.0,
        subpixel_smoothness);

    return mask;
}

vec3 apply_mask(vec3 color, float color_luma, vec2 tex_coord)
{
    if (PARAM_MASK_TYPE == 0.0)
    {
        return color;
    }

    vec3 mask = get_mask(tex_coord);
    float mask_luma = get_luminance(mask);

    // apply color bleed to neighbor sub-pixel
    mask += mask_luma * PARAM_MASK_COLOR_BLEED;

    // apply half color luma for additive mask
    mask = mix(
        mask,
        mask + color_luma * 0.5,
        PARAM_MASK_BLEND);

    // increase mask brightnes based on half intensity
    vec3 mask_add = mask;
    mask_add += (1.0 - PARAM_MASK_INTENSITY) * 0.5;
    mask_add = clamp(mask_add, 0.0, 1.0);
    mask_add += PARAM_MASK_INTENSITY * 0.5;

    // blend multiplicative and additive mask
    mask = mix(
        mask,
        mask_add,
        PARAM_MASK_BLEND);

    // apply mask based on intensity
    color = mix(
        color,
        color * mask,
        PARAM_MASK_INTENSITY);

    return color;
}

vec3 apply_color_overflow(vec3 color)
{
    vec3 color_overflow = color * color * PARAM_COLOR_OVERFLOW;

    color.r += LumaR * LumaG * color_overflow.g;
    color.r += LumaR * LumaB * color_overflow.b;
    color.g += LumaG * LumaR * color_overflow.r;
    color.g += LumaG * LumaB * color_overflow.b;
    color.b += LumaB * LumaR * color_overflow.r;
    color.b += LumaB * LumaG * color_overflow.g;

    return color;
}

vec3 apply_halation(vec3 color, sampler2D halation_source, vec2 tex_coord)
{
    vec3 halation = INPUT(texture(halation_source, tex_coord).rgb);

    // add the difference between color and halation
    return color + (halation - color) * (PARAM_HALATION_INTENSITY * 0.25);
}

vec3 apply_noise(vec3 color, float color_luma, vec2 tex_coord)
{
    float subpixel_size = INPUT_MASK_PROFILE.x;

    vec2 pix_coord = vec2o(tex_coord.xy * global.OutputSize.xy);

    // scale noise based on mask's sub-pixel size
    pix_coord = floor(pix_coord / int(subpixel_size)) * int(subpixel_size);

    // repeat every 20 frames with 12fps
    float frame = mod(GetUniformFrameCount(12), 20);
    float noise = random(pix_coord * (frame + 1.0));

    float mul_noise = noise * 2.0;
    float add_noise = noise * (1.0 - color_luma) * (4.0 / 256.0 - PARAM_COLOR_FLOOR) * PARAM_COLOR_BLACK_LIGHT;

    return mix(
        color,
        color * mul_noise + add_noise,
        (1.0 - color_luma) * PARAM_CRT_NOISE_AMOUNT * 0.25);
}
