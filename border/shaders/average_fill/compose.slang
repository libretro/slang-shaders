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
layout(set = 0, binding = 3) uniform sampler2D Top;
layout(set = 0, binding = 4) uniform sampler2D Bottom;
layout(set = 0, binding = 5) uniform sampler2D Left;
layout(set = 0, binding = 6) uniform sampler2D Right;

// For mipmap sampling, sample with a big offset to get the average of a PoT
// input.
#define BIG_NUMBER 9000.1

void main() {
    const vec2 pixel_coord = vTexCoord * param.InputSize.xy;
    if (pixel_coord.x < param.OS_CROP_LEFT) {
        // Left bar
        FragColor = vec4(textureLod(Left, vec2(0.5), BIG_NUMBER).rgb, 1.0);
        // TODO: Handle top and bottom bar + blending here!
    } else if (pixel_coord.x < param.InputSize.x - param.OS_CROP_RIGHT) {
        if (pixel_coord.y < param.OS_CROP_TOP) {
            // Top bar
            FragColor = vec4(textureLod(Top, vec2(0.5), BIG_NUMBER).rgb, 1.0);
        } else if (pixel_coord.y < param.InputSize.y - param.OS_CROP_BOTTOM) {
            // Uncropped
            // Do a sharp (nearest neighbor) resampling.
            FragColor = vec4(
                texture(Input, (floor(vTexCoord * param.InputSize.xy) + 0.5) *
                                   param.InputSize.zw)
                    .rgb,
                1.0);
        } else {
            // Bottom bar
            FragColor =
                vec4(textureLod(Bottom, vec2(0.5), BIG_NUMBER).rgb, 1.0);
        }
    } else {
        // Right bar
        FragColor = vec4(textureLod(Right, vec2(0.5), BIG_NUMBER).rgb, 1.0);
        // TODO: Handle top and bottom bar here!
    }
}
