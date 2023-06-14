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
    v1.0: Initial release.
*/

#include "../../../blurs/shaders/dual_filter/parameters.slang"
#include "parameters.slang"

layout(push_constant) uniform Push {
    vec4 InputSize;
    vec4 TiledSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
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
    // From dual filter blur
    float BLUR_RADIUS;
}
param;

#include "scaling.slang"

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
            FragColor = vec4(texture(Blurred, vTexCoord).rgb, 1.0);
        } else {
            // Sample tiled pattern.
            // Do a sharp (nearest neighbor) resampling.
            FragColor = vec4(
                texture(Tiled, (floor(vTexCoord * param.TiledSize.xy) + 0.5) *
                                   param.TiledSize.zw)
                    .rgb,
                1.0);
        }
    } else {
        // Sample original.
        // Do a sharp (nearest neighbor) resampling.
        FragColor = vec4(
            texture(Input, (floor(pixel_coord) + 0.5) * param.InputSize.zw).rgb,
            1.0);
    }
}
