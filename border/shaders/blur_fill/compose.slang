#version 450

/*
    Blur fill v1.0 by fishku
    Copyright (C) 2023
    Public domain license (CC0)

    This shader preset allows cropping the image on any side, and filling the
    cropped area with a blurred version of the input image borders.
    This is useful for certain games that do not render a full image to maintain
    the overall aspect ratio and to avoid burn-in.

    The preset also allows you to extend the original content to a larger
    screen. It's recommended to set the video scaling options as follows:
    - Turn integer scaling OFF
    - Set aspect ratio to FULL
    The shader will then take over and handle the proper scaling and aspect
    ratio of the input.

    The preset comes in three variants which differ only in the strength of the
    blur.
    Since the blur strength in the dual filter blur depends on the input
    resolution, and because there is currently no mechanism to set resolution
    based on user parameters, the three variants provide different sampling
    resolutions which affect the strength of the blur.
    Additionally to the resolution, a blur radius parameter controls the
    strength of the blur.

    Changelog:
    v1.1: Fix bug with glcore driver.
    v1.0: Initial release.
*/

#include "../../../blurs/shaders/dual_filter/parameters.slang"
#include "parameters.slang"

layout(push_constant) uniform Push {
    vec4 InputSize;
    vec4 TiledSize;
    vec4 FinalViewportSize;
    float OS_CROP_TOP;
    float OS_CROP_BOTTOM;
    float OS_CROP_LEFT;
    float OS_CROP_RIGHT;
    float CENTER_CROP;
    float SAMPLE_SIZE;
    float FORCE_ASPECT_RATIO;
    float ASPECT_H;
    float ASPECT_V;
    float FORCE_INTEGER_SCALING;
    float FILL_GAMMA;
    // From dual filter blur
    float BLUR_RADIUS;
}
param;

#include "scaling.slang"

float DigitBin(const int x) {
    return x == 0   ? 480599.0
           : x == 1 ? 139810.0
           : x == 2 ? 476951.0
           : x == 3 ? 476999.0
           : x == 4 ? 350020.0
           : x == 5 ? 464711.0
           : x == 6 ? 464727.0
           : x == 7 ? 476228.0
           : x == 8 ? 481111.0
           : x == 9 ? 481095.0
                    : 0.0;
}

float PrintValue(vec2 vStringCoords, float fValue, float fMaxDigits,
                 float fDecimalPlaces) {
    vStringCoords.y = 1.0 - vStringCoords.y;
    if ((vStringCoords.y < 0.0) || (vStringCoords.y >= 1.0)) return 0.0;

    bool bNeg = (fValue < 0.0);
    fValue = abs(fValue);

    float fLog10Value = log2(abs(fValue)) / log2(10.0);
    float fBiggestIndex = max(floor(fLog10Value), 0.0);
    float fDigitIndex = fMaxDigits - floor(vStringCoords.x);
    float fCharBin = 0.0;
    if (fDigitIndex > (-fDecimalPlaces - 1.01)) {
        if (fDigitIndex > fBiggestIndex) {
            if ((bNeg) && (fDigitIndex < (fBiggestIndex + 1.5)))
                fCharBin = 1792.0;
        } else {
            if (fDigitIndex == -1.0) {
                if (fDecimalPlaces > 0.0) fCharBin = 2.0;
            } else {
                float fReducedRangeValue = fValue;
                if (fDigitIndex < 0.0) {
                    fReducedRangeValue = fract(fValue);
                    fDigitIndex += 1.0;
                }
                float fDigitValue =
                    (abs(fReducedRangeValue / (pow(10.0, fDigitIndex))));
                fCharBin = DigitBin(int(floor(mod(fDigitValue, 10.0))));
            }
        }
    }
    return floor(
        mod((fCharBin / pow(2.0, floor(fract(vStringCoords.x) * 4.0) +
                                     (floor(vStringCoords.y * 5.0) * 4.0))),
            2.0));
}

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Input;
layout(set = 0, binding = 3) uniform sampler2D Tiled;
layout(set = 0, binding = 4) uniform sampler2D Blurred;

void main() {
    const vec2 pixel_coord = o2i(vTexCoord) * param.InputSize.xy;

    const vec4 input_extrema = vec4(param.OS_CROP_LEFT, param.OS_CROP_TOP,
                                    param.InputSize.x - param.OS_CROP_RIGHT,
                                    param.InputSize.y - param.OS_CROP_BOTTOM);
    if (any(lessThan(pixel_coord, input_extrema.xy)) ||
        any(greaterThanEqual(pixel_coord, input_extrema.zw))) {
        if (param.BLUR_RADIUS > 0.0) {
            // Sample blur.
            FragColor = vec4(
                pow(texture(Blurred, vTexCoord).rgb, vec3(param.FILL_GAMMA)),
                1.0);
        } else {
            // Sample tiled pattern.
            // Do a sharp (nearest neighbor) resampling.
            FragColor =
                vec4(pow(texture(Tiled,
                                 (floor(vTexCoord * param.TiledSize.xy) + 0.5) *
                                     param.TiledSize.zw)
                             .rgb,
                         vec3(param.FILL_GAMMA)),
                     1.0);
        }
    } else {
        // Sample original.
        // Do a sharp (nearest neighbor) resampling.
        FragColor = vec4(
            texture(Input, (floor(pixel_coord) + 0.5) * param.InputSize.zw).rgb,
            1.0);
    }

    float digits_to_print = 2.0;
    float dec_pl_to_print = 3.0;
    vec2 pix_coord = vTexCoord * param.FinalViewportSize.xy;
    vec2 vFontSize = vec2(8.0, 15.0);

    const int print_x_coord = 70;
    const int print_x_coord_2 = 150;

    float print_value;

    // eff input res
    print_value =
        PrintValue((pix_coord - vec2(print_x_coord, 10)) / vFontSize,
                   eff_input_res().x, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
    print_value =
        PrintValue((pix_coord - vec2(print_x_coord, 30)) / vFontSize,
                   eff_input_res().y, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
    print_value =
        PrintValue((pix_coord - vec2(print_x_coord_2, 10)) / vFontSize,
                   param.FinalViewportSize.x, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
    print_value =
        PrintValue((pix_coord - vec2(print_x_coord_2, 30)) / vFontSize,
                   param.FinalViewportSize.y, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);

    // eff aspect
    print_value = PrintValue((pix_coord - vec2(print_x_coord, 70)) / vFontSize,
                             eff_aspect().x, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
    print_value = PrintValue((pix_coord - vec2(print_x_coord, 90)) / vFontSize,
                             eff_aspect().y, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);

    // scale x and scale y
    print_value =
        PrintValue((pix_coord - vec2(print_x_coord, 130)) / vFontSize,
                   wideness_vs_tallness().x, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
    print_value =
        PrintValue((pix_coord - vec2(print_x_coord, 150)) / vFontSize,
                   wideness_vs_tallness().y, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
    print_value =
        PrintValue((pix_coord - vec2(print_x_coord_2, 130)) / vFontSize,
                   debug_scale().x, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
    print_value =
        PrintValue((pix_coord - vec2(print_x_coord_2, 150)) / vFontSize,
                   debug_scale().y, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);

    // scale_o2i
    print_value = PrintValue((pix_coord - vec2(print_x_coord, 190)) / vFontSize,
                             scale_o2i().x, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
    print_value = PrintValue((pix_coord - vec2(print_x_coord, 210)) / vFontSize,
                             scale_o2i().y, digits_to_print, dec_pl_to_print);
    FragColor.rgb = mix(FragColor.rgb, vec3(0.0, 1.0, 0.0), print_value);
}
