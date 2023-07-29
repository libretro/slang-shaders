#version 450

/*
    Average fill v1.5 by fishku
    Copyright (C) 2023
    Public domain license (CC0)

    This shader preset allows cropping the image on any side, and filling the
    cropped area with the average color of an adjustable area next to it.
    This is useful for certain games that do not render a full image to maintain
    the overall aspect ratio and to avoid burn-in.

    The preset also allows you to extend the original content to a larger
    screen. It's recommended to set the video scaling options as follows:
    - Turn integer scaling OFF
    - Set aspect ratio to FULL
    The shader will then take over and handle the proper scaling and aspect
    ratio of the input.

    In case the image is cropped on multiple sides, different blend modes for
    the corner are available. Simply change the parameter for the "corner blend
    mode".
    The available corner blend modes are:
    0 = Draw horizontal bars on top
    1 = Draw vertical bars on top
    2 = Blend bars by weighted averaging
    3 = Smooth angle-based blending

    Changelog:
    v1.5: Optimize. Update to new Pixel AA version.
    v1.4: Add anti-aliased interpolation for non-integer scaling.
    v1.3: Fix scaling bugs.
    v1.2: Fix scaling bugs.
    v1.1: Add extension modes from blur fill; Add average gamma adjustment.
    v1.0: Initial release.
*/

// clang-format off
#include "parameters.slang"
#include "../../../interpolation/shaders/pixel_aa/shared.slang"
// clang-format on

layout(push_constant) uniform Push {
    vec4 InputSize;
    vec4 FinalViewportSize;
    float OS_CROP_TOP;
    float OS_CROP_BOTTOM;
    float OS_CROP_LEFT;
    float OS_CROP_RIGHT;
    float CENTER_CROP;
    float SAMPLE_SIZE;
    float EXTEND_H;
    float EXTEND_V;
    float CORNER_BLEND_MODE;
    float FORCE_ASPECT_RATIO;
    float ASPECT_H;
    float ASPECT_V;
    float FORCE_INTEGER_SCALING;
    float FILL_GAMMA;
    // From pixel AA
    float PIX_AA_SHARP;
    float PIX_AA_SUBPX;
    float PIX_AA_SUBPX_BGR;
}
param;

#include "../blur_fill/scaling.slang"

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 tx_coord;
layout(location = 2) out vec2 tx_per_px;
layout(location = 3) out vec2 tx_to_uv;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    const vec2 scale_o2i = scale_o2i();
    tx_coord = (vTexCoord - 0.49999) * scale_o2i + get_input_center();
    tx_per_px = scale_o2i * param.FinalViewportSize.zw;
    tx_to_uv = param.InputSize.zw;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 tx_coord;
layout(location = 2) in vec2 tx_per_px;
layout(location = 3) in vec2 tx_to_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Input;
layout(set = 0, binding = 3) uniform sampler2D Top;
layout(set = 0, binding = 4) uniform sampler2D Bottom;
layout(set = 0, binding = 5) uniform sampler2D Left;
layout(set = 0, binding = 6) uniform sampler2D Right;

#define PI 3.1415926538

// For mipmap sampling, use a big offset to get the average of a PoT input.
#define BIG_NUMBER 9000.1

vec3 blend_corner(vec3 a,      // The first color to blend
                  vec3 b,      // The second color to blend
                  float wa,    // The weight of the first color
                  float wb,    // The weight of the second color
                  vec2 coord,  // The coordinate to evaluate the blend for
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
            const vec2 delta = (coord - corner_coord) / gap_size;
            // Use absolutes to always operate in 1st quadrant.
            // This makes the angle work out to be correct in all cases when
            // carefully choosing argument ordering.
            const float angle = atan(abs(delta.y), abs(delta.x)) / (PI * 0.5);
            // Smoothstep makes the transition perceptually smoother.
            return mix(a, b, smoothstep(0.0, 1.0, angle));
    }
}

void main() {
    if (tx_coord.x < param.OS_CROP_LEFT) {
        if (param.EXTEND_H < 0.5) {
            FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
        const vec3 left = textureLod(Left, vec2(0.5), BIG_NUMBER).rgb;
        if (tx_coord.y < param.OS_CROP_TOP) {
            if (param.EXTEND_V < 0.5) {
                FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }
            // Top left corner
            const vec3 top = textureLod(Top, vec2(0.5), BIG_NUMBER).rgb;
            const vec2 content_corner =
                i2o(vec2(param.OS_CROP_LEFT, param.OS_CROP_TOP));
            const vec2 viewport_corner = vec2(0.0, 0.0);
            FragColor =
                vec4(blend_corner(left, top,
                                  param.InputSize.y - param.OS_CROP_TOP -
                                      param.OS_CROP_BOTTOM,
                                  param.InputSize.x - param.OS_CROP_LEFT -
                                      param.OS_CROP_RIGHT,
                                  vTexCoord, content_corner,
                                  viewport_corner - content_corner),
                     1.0);
            FragColor.rgb = pow(FragColor.rgb, vec3(param.FILL_GAMMA));
        } else if (tx_coord.y < param.InputSize.y - param.OS_CROP_BOTTOM) {
            // Left bar
            FragColor = vec4(pow(left, vec3(param.FILL_GAMMA)), 1.0);
        } else {
            if (param.EXTEND_V < 0.5) {
                FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }
            // Bottom left corner
            const vec3 bottom = textureLod(Bottom, vec2(0.5), BIG_NUMBER).rgb;
            const vec2 content_corner = i2o(vec2(
                param.OS_CROP_LEFT, param.InputSize.y - param.OS_CROP_BOTTOM));
            const vec2 viewport_corner = vec2(0.0, 1.0);
            FragColor =
                vec4(blend_corner(left, bottom,
                                  param.InputSize.y - param.OS_CROP_TOP -
                                      param.OS_CROP_BOTTOM,
                                  param.InputSize.x - param.OS_CROP_LEFT -
                                      param.OS_CROP_RIGHT,
                                  vTexCoord, content_corner,
                                  viewport_corner - content_corner),
                     1.0);
            FragColor.rgb = pow(FragColor.rgb, vec3(param.FILL_GAMMA));
        }
    } else if (tx_coord.x < param.InputSize.x - param.OS_CROP_RIGHT) {
        if (tx_coord.y < param.OS_CROP_TOP) {
            if (param.EXTEND_V < 0.5) {
                FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }
            // Top bar
            FragColor = vec4(textureLod(Top, vec2(0.5), BIG_NUMBER).rgb, 1.0);
            FragColor.rgb = pow(FragColor.rgb, vec3(param.FILL_GAMMA));
        } else if (tx_coord.y < param.InputSize.y - param.OS_CROP_BOTTOM) {
            // Uncropped
            if (param.FORCE_INTEGER_SCALING > 0.5) {
                // Do a perfectly sharp (nearest neighbor) sampling.
                FragColor = vec4(
                    texture(Input, (floor(tx_coord) + 0.5) * param.InputSize.zw)
                        .rgb,
                    1.0);
            } else {
                // Do a sharp anti-aliased interpolation.
                // Do not correct for gamma additionally because the input is
                // already in linear color space.
                FragColor = pixel_aa(
                    Input, tx_per_px, tx_to_uv, tx_coord, param.PIX_AA_SHARP,
                    /* gamma_correct = */ false, param.PIX_AA_SUBPX > 0.5,
                    param.PIX_AA_SUBPX_BGR > 0.5);
            }
        } else {
            if (param.EXTEND_V < 0.5) {
                FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }
            // Bottom bar
            FragColor =
                vec4(textureLod(Bottom, vec2(0.5), BIG_NUMBER).rgb, 1.0);
            FragColor.rgb = pow(FragColor.rgb, vec3(param.FILL_GAMMA));
        }
    } else {
        if (param.EXTEND_H < 0.5) {
            FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
        const vec3 right = textureLod(Right, vec2(0.5), BIG_NUMBER).rgb;
        if (tx_coord.y < param.OS_CROP_TOP) {
            if (param.EXTEND_V < 0.5) {
                FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }
            // Top right corner
            const vec3 top = textureLod(Top, vec2(0.5), BIG_NUMBER).rgb;
            const vec2 content_corner = i2o(vec2(
                param.InputSize.x - param.OS_CROP_RIGHT, param.OS_CROP_TOP));
            const vec2 viewport_corner = vec2(1.0, 0.0);
            FragColor =
                vec4(blend_corner(right, top,
                                  param.InputSize.y - param.OS_CROP_TOP -
                                      param.OS_CROP_BOTTOM,
                                  param.InputSize.x - param.OS_CROP_LEFT -
                                      param.OS_CROP_RIGHT,
                                  vTexCoord, content_corner,
                                  viewport_corner - content_corner),
                     1.0);
            FragColor.rgb = pow(FragColor.rgb, vec3(param.FILL_GAMMA));
        } else if (tx_coord.y < param.InputSize.y - param.OS_CROP_BOTTOM) {
            // Right bar
            FragColor = vec4(pow(right, vec3(param.FILL_GAMMA)), 1.0);
        } else {
            if (param.EXTEND_V < 0.5) {
                FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }
            // Bottom right corner
            const vec3 bottom = textureLod(Bottom, vec2(0.5), BIG_NUMBER).rgb;
            const vec2 content_corner =
                i2o(vec2(param.InputSize.x - param.OS_CROP_RIGHT,
                         param.InputSize.y - param.OS_CROP_BOTTOM));
            const vec2 viewport_corner = vec2(1.0, 1.0);
            FragColor =
                vec4(blend_corner(right, bottom,
                                  param.InputSize.y - param.OS_CROP_TOP -
                                      param.OS_CROP_BOTTOM,
                                  param.InputSize.x - param.OS_CROP_LEFT -
                                      param.OS_CROP_RIGHT,
                                  vTexCoord, content_corner,
                                  viewport_corner - content_corner),
                     1.0);
            FragColor.rgb = pow(FragColor.rgb, vec3(param.FILL_GAMMA));
        }
    }
}
