#version 450

/*
    Blur fill v1.0 by fishku
    Copyright (C) 2023
    Public domain license (CC0)

    Changelog:
    v1.0: Initial release.
*/

#include "parameters.slang"
#include "scaling.slang"

layout(push_constant) uniform Push {
    vec4 InputSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OS_CROP_TOP;
    float OS_CROP_BOTTOM;
    float OS_CROP_LEFT;
    float OS_CROP_RIGHT;
    float SAMPLE_SIZE;
}
param;

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
layout(set = 0, binding = 3) uniform sampler2D Blurred;

void main() {
    const vec2 pixel_coord = vTexCoord * param.InputSize.xy;

    const vec4 input_extrema = vec4(param.OS_CROP_LEFT, param.OS_CROP_TOP,
                                    param.InputSize.x - param.OS_CROP_RIGHT,
                                    param.InputSize.y - param.OS_CROP_BOTTOM);
    if (any(lessThan(pixel_coord, input_extrema.xy)) ||
        any(greaterThanEqual(pixel_coord, input_extrema.zw))) {
        // Sample blur.
        FragColor = vec4(texture(Blurred, blurred_to_vp(vTexCoord)).rgb, 1.0);
    } else {
        // Sample original.
        // Do a sharp (nearest neighbor) resampling.
        FragColor =
            vec4(texture(Input, (floor(vTexCoord * param.InputSize.xy) + 0.5) *
                                    param.InputSize.zw)
                     .rgb,
                 1.0);
    }
}
