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
    float CORNER_BLEND_MODE;
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

#define PI 3.1415926538

// For mipmap sampling, use a big offset to get the average of a PoT input.
#define BIG_NUMBER 9000.1

vec3 blend_corner(vec3 a,            // The first color to blend
                  vec3 b,            // The second color to blend
                  float wa,          // The weight of the first color
                  float wb,          // The weight of the second color
                  vec2 pixel_coord,  // The coordinate to evaluate the blend for
                  vec2 corner_coord,  // The coordinate of the corner of the
                                      // content after cropping
                  vec2 gap_size  // The component-wise distance from the corner
                                 // of the content to the corner of the viewport
) {
    switch (int(param.CORNER_BLEND_MODE)) {
        case 0:
            // Horizontal bars on top
            return b;
        case 1:
            // Vertical bars on top
            return a;
        case 2:
            // Weighted average of averages
            return mix(a, b, wa / (wa + wb));
        case 3:
        default:
            // Angle blend
            const vec2 delta = (pixel_coord - corner_coord) / gap_size;
            // Use absolutes to always operate in 1st quadrant.
            // This makes the angle work out to be correct in all cases when
            // carefully choosing argument ordering.
            const float angle = atan(abs(delta.y), abs(delta.x)) / (PI * 0.5);
            // Smoothstep makes the transition even smoother.
            return mix(a, b, smoothstep(0.0, 1.0, angle));
    }
}

void main() {
    const vec2 pixel_coord = vTexCoord * param.InputSize.xy;
    if (pixel_coord.x < param.OS_CROP_LEFT) {
        const vec3 left = textureLod(Left, vec2(0.5), BIG_NUMBER).rgb;
        if (pixel_coord.y < param.OS_CROP_TOP) {
            // Top left corner
            const vec3 top = textureLod(Top, vec2(0.5), BIG_NUMBER).rgb;
            FragColor =
                vec4(blend_corner(left, top,
                                  param.InputSize.y - param.OS_CROP_TOP -
                                      param.OS_CROP_BOTTOM,
                                  param.InputSize.x - param.OS_CROP_LEFT -
                                      param.OS_CROP_RIGHT,
                                  pixel_coord,
                                  vec2(param.OS_CROP_LEFT, param.OS_CROP_TOP),
                                  vec2(param.OS_CROP_LEFT, param.OS_CROP_TOP)),
                     1.0);
        } else if (pixel_coord.y < param.InputSize.y - param.OS_CROP_BOTTOM) {
            // Left bar
            FragColor = vec4(left, 1.0);
        } else {
            // Bottom left corner
            const vec3 bottom = textureLod(Bottom, vec2(0.5), BIG_NUMBER).rgb;
            FragColor = vec4(
                blend_corner(left, bottom,
                             param.InputSize.y - param.OS_CROP_TOP -
                                 param.OS_CROP_BOTTOM,
                             param.InputSize.x - param.OS_CROP_LEFT -
                                 param.OS_CROP_RIGHT,
                             pixel_coord,
                             vec2(param.OS_CROP_LEFT,
                                  param.InputSize.y - param.OS_CROP_BOTTOM),
                             vec2(param.OS_CROP_LEFT, param.OS_CROP_BOTTOM)),
                1.0);
        }
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
        const vec3 right = textureLod(Right, vec2(0.5), BIG_NUMBER).rgb;
        if (pixel_coord.y < param.OS_CROP_TOP) {
            // Top right corner
            const vec3 top = textureLod(Top, vec2(0.5), BIG_NUMBER).rgb;
            FragColor =
                vec4(blend_corner(right, top,
                                  param.InputSize.y - param.OS_CROP_TOP -
                                      param.OS_CROP_BOTTOM,
                                  param.InputSize.x - param.OS_CROP_LEFT -
                                      param.OS_CROP_RIGHT,
                                  pixel_coord,
                                  vec2(param.InputSize.x - param.OS_CROP_RIGHT,
                                       param.OS_CROP_TOP),
                                  vec2(param.OS_CROP_RIGHT, param.OS_CROP_TOP)),
                     1.0);
        } else if (pixel_coord.y < param.InputSize.y - param.OS_CROP_BOTTOM) {
            // Right bar
            FragColor = vec4(right, 1.0);
        } else {
            // Bottom right corner
            const vec3 bottom = textureLod(Bottom, vec2(0.5), BIG_NUMBER).rgb;
            FragColor = vec4(
                blend_corner(right, bottom,
                             param.InputSize.y - param.OS_CROP_TOP -
                                 param.OS_CROP_BOTTOM,
                             param.InputSize.x - param.OS_CROP_LEFT -
                                 param.OS_CROP_RIGHT,
                             pixel_coord,
                             vec2(param.InputSize.x - param.OS_CROP_RIGHT,
                                  param.InputSize.y - param.OS_CROP_BOTTOM),
                             vec2(param.OS_CROP_RIGHT, param.OS_CROP_BOTTOM)),
                1.0);
        }
    }
}
