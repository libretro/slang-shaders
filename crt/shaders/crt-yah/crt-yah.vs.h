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

#include "common/math-helper.h"
#include "common/screen-helper.h"

vec2 get_mask_profile()
{
    float pixel_size = global.SourceSize.x < global.SourceSize.y 
        ? global.FinalViewportSize.x / global.SourceSize.x
        : global.FinalViewportSize.y / global.SourceSize.y;

    float subpixel_count = PARAM_MASK_TYPE == 3
        // shadow-mask
        ? 3.0
        // aperture-grille, slot-mask
        : 4.0;

    // auto
    float subpixel_size = pixel_size / subpixel_count * INPUT_SCREEN_MULTIPLE;
    // manual correction
    subpixel_size += PARAM_MASK_SIZE;
    // limit
    subpixel_size = floor(max(1.0, subpixel_size));
    
    float subpixel_smoothness =
        // aperture-grille for size > 2
        PARAM_MASK_TYPE == 1 ? clamp((subpixel_size - 2.0) * 0.75, 0.0, 1.0) :
        // slot-mask for size > 2
        PARAM_MASK_TYPE == 2 ? clamp((subpixel_size - 2.0) * 0.75, 0.0, 1.0) :
        // shadow-mask for size > 2
        PARAM_MASK_TYPE == 3 ? clamp((subpixel_size - 2.0) * 0.25, 0.0, 1.0) : 0.0;

    return vec2(subpixel_size, subpixel_smoothness);
}

float get_brightness_compensation()
{
    float brightness_compensation = 0.0;

    float scanlines_strength = normalized_sigmoid(PARAM_SCANLINES_STRENGTH, 0.5);

    // scanlines compensation
    brightness_compensation +=
        scanlines_strength
        * mix(
            // smarp shape
            0.375,
            // smooth shape
            0.875,
            PARAM_BEAM_SHAPE);

    float mask_intensity = normalized_sigmoid(PARAM_MASK_INTENSITY * PARAM_MASK_INTENSITY, 0.5);
    float mask_blend = 1.0 - (1.0 - PARAM_MASK_BLEND) * (1.0 - PARAM_MASK_BLEND);

    float mask_size = INPUT_MASK_PROFILE.x;

    // mask sub-pixel
    float subpixel_offset =
        // white, black
        PARAM_MASK_SUBPIXEL == 1 ? mix(-1.2, -0.3, mask_blend) :
        // green, magenta
        PARAM_MASK_SUBPIXEL == 2 ? mix(-1.2, -0.3, mask_blend) :
        // green, magenta, black
        PARAM_MASK_SUBPIXEL == 3 ? 0.0 :
        // red, green, blue
        PARAM_MASK_SUBPIXEL == 4 ? 0.0 :
        // red, green, blue, black
        PARAM_MASK_SUBPIXEL == 5 ? mix(1.2, 0.3, mask_blend) : 0.0;

    // mask type
    float type_offset =
        // aperture-grille
        PARAM_MASK_TYPE == 1 ? 0.0 :
        // slot-mask
        PARAM_MASK_TYPE == 2 ? mix(1.0, 0.25, mask_blend) :
        // shadow-mask
        PARAM_MASK_TYPE == 3 ? 0.0 : 0.0;

    // mask size
    float size_offset = 
        // aperture-grille for size > 2
        PARAM_MASK_TYPE == 1 && mask_size > 2.0 ? mix(1.2, 0.3, mask_blend) :
        // slot-mask for size > 2
        PARAM_MASK_TYPE == 2 && mask_size > 2.0 ? mix(1.6, 0.4, mask_blend) :
        // shadow-mask for size > 2
        PARAM_MASK_TYPE == 3 && mask_size > 2.0 ? mix(2.0, 0.5, mask_blend) : 0.0;

    // mask compensation
    brightness_compensation -= 0.25 * mask_intensity;
    brightness_compensation += 2.25 * (1.0 - mask_blend) * mask_intensity;
    brightness_compensation += subpixel_offset * mask_intensity;
    brightness_compensation += type_offset * mask_intensity;
    brightness_compensation += size_offset * mask_intensity;

    return brightness_compensation;
}

// Mitchell-Netravali survay of bi-cubic filters
//   For upscaling, it is recommended to use values that satisfy the equation b + 2c = 1.
//
// Common values for:     b       c
//   Hermite              0       0
//   B-Spline             1       0
//   Mitchell-Netravali   1/3     1/3
//   Catmull-Rom          0       1/2
//   Sharp Bicubic        0       1
//   Box                 -1       0
//
//   [Bluring] b                       [Aliasing]
//
//         1.0 ■ (B-Spline)· · · · ·
//             │▪                  ·
//             │ ▪                 ·
//         2/3 │  ■ 1/6 ("quasi" B-Spline)
//             │   ▪               ·
//         0.5 ┤    ▪              ·
//             │     ▪             ·
//         1/3 │      ■ 1/3 (Mitchell-Netravali)
//             │       ▪           ·
//             │        ▪          ·
//  [Blocking] ■─▪─▪─▪─▪─■─────────┤ c [Ringing]
//            0.0       0.5       1.0
//            (Hermite) (Catmull-Rom)
//             ▪
//             ▪
//        -0.5 ▪
//             ▪
//             ▪
//             ▪
//             ▪
//        -1.0 ■ (Box)
//
// Read more:
//   https://en.wikipedia.org/wiki/Mitchell-Netravali_filters
//   https://guideencodemoe-mkdocs.readthedocs.io/encoding/resampling/#mitchell-netravali-bicubic
mat4x4 get_beam_filter()
{
    // change filter range from [-1, 1] to [-1, 3] for four distinct ranges of size 1.0
    float f = PARAM_BEAM_FILTER * 2 + 1;

    // Hermite (b = 0, c = 0)
    float b = 0.0;
    float c = 0.0;

    // original range [-1.0, -0.5]
    if (f <= 0.0)
    {
        // Box (b = -1, c = 0) to Hermite (b = 0, c = 0)
        b = f;
        c = 0;
    }
    // original range [-0.5, 0.0]
    else if (f <= 1.0)
    {
        // Hermite to Catmull-Rom (b = 0, c = 1/2)
        b = 0.0;
        c = f * 0.5;
    }
    // original range [0.0, 0.5]
    else if (f <= 2.0)
    {
        // Catmull-Rom to Mitchell-Netravali (b = 1/3, c = 1/3)
        b = (f - 1.0) / 3.0;
        c = 0.5 - (f - 1.0) / 6.0;
    }
    // original range [0.5, 1.0]
    else if (f <= 3.0)
    {
        // Mitchell-Netravali to "quasi" B-Spline (b = 2/3, c = 1/6)
        b = (1.0 / 3.0) + (f - 2.0) / 3.0;
        c = (1.0 / 3.0) - (f - 2.0) / 6.0;
    }

    return mat4x4(
                    (-b - 6.0 * c) / 6.0,          (3.0 * b + 12.0 * c) / 6.0, (-3.0 * b - 6.0 * c) / 6.0,              b  / 6.0,
        (12.0 - 9.0 * b - 6.0 * c) / 6.0, (-18.0 + 12.0 * b +  6.0 * c) / 6.0,                        0.0, (6.0 - 2.0 * b) / 6.0,
       -(12.0 - 9.0 * b - 6.0 * c) / 6.0, ( 18.0 - 15.0 * b - 12.0 * c) / 6.0,  (3.0 * b + 6.0 * c) / 6.0,              b  / 6.0,
                     (b + 6.0 * c) / 6.0,                           -c,                  0.0,                   0.0
    );
}

vec4 get_beam_profile()
{
    float beam_min_width = 1.0;
    float beam_max_width = 1.0;
    float beam_slope = 2.0;

    float param_beam_shape_inverted = 1.0 - PARAM_BEAM_SHAPE; 

    // increase beam slope
    beam_slope +=
        2.0
        // increase for sharp shape, no increase for smooth shape
        * (param_beam_shape_inverted * PARAM_SCANLINES_STRENGTH)
        // double increase for sharp shape
        * (param_beam_shape_inverted * PARAM_SCANLINES_STRENGTH + 1.0);

    // reduce min./max. width for sharp shape
    beam_min_width -= param_beam_shape_inverted * PARAM_SCANLINES_STRENGTH / 2.0;
    beam_max_width -= param_beam_shape_inverted * PARAM_SCANLINES_STRENGTH / 2.0;

    // reduce min. width
    beam_min_width /=
        1.0
        // for beam width < 1
        + min(1.0, 1.0 - PARAM_BEAM_WIDTH_MIN)
        // when strength in range [0.5, 1.0]
        * min(1.0, PARAM_SCANLINES_STRENGTH * 2.0)
        // half
        / 2.0;

    // increase max. width
    beam_max_width *=
        1.0
        // for beam width > 1
        + max(0.0, PARAM_BEAM_WIDTH_MAX - 1.0)
        // when strength in range [0.5, 1.0]
        * min(1.0, PARAM_SCANLINES_STRENGTH * 2.0)
        // half
        / 2.0;

    // change stenghth slope to level out at higher values
    float scanlines_strength = normalized_sigmoid(PARAM_SCANLINES_STRENGTH, 0.5);

    // change strength range to [0.25, 1.5]
    scanlines_strength *= 1.25;
    scanlines_strength += 0.25;

    return vec4(beam_min_width, beam_max_width, beam_slope, scanlines_strength);
}
