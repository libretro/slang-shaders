#version 450

#include "parameters.slang"

layout(push_constant) uniform Push {
    vec4 InputSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OS_CROP_TOP;
    float OS_CROP_BOTTOM;
    float OS_CROP_LEFT;
    float OS_CROP_RIGHT;
    float CENTER_CROP;
    float SAMPLE_SIZE;
    float BLUR_EXTEND_H;
    float BLUR_EXTEND_V;
    float FORCE_ASPECT_RATIO;
    float ASPECT_H;
    float ASPECT_V;
    float FORCE_INTEGER_SCALING;
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

vec4 sample_cropped(sampler2D tex, vec2 coord) {
    const vec2 pixel_coord = coord * param.InputSize.xy;
    if (pixel_coord.x < param.OS_CROP_LEFT ||
        pixel_coord.x >= param.InputSize.x - param.OS_CROP_RIGHT ||
        pixel_coord.y < param.OS_CROP_TOP ||
        pixel_coord.y >= param.InputSize.y - param.OS_CROP_BOTTOM) {
        return vec4(1, 0, 0, 1);
    }
    return texture(tex, coord);
}

void main() { FragColor = sample_cropped(Input, o2i(vTexCoord)); }
