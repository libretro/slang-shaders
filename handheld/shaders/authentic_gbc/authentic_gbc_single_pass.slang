#version 450

// See the main shader file for copyright and other information.

#include "parameters.inc"
#include "shared.inc"

layout(push_constant) uniform Push {
    vec4 OriginalSize;
    vec4 OutputSize;
    uint Rotation;
    float AUTH_GBC_BRIG;
    float AUTH_GBC_BLUR;
    float AUTH_GBC_SUBPX;
    float AUTH_GBC_SUBPX_ORIENTATION;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec4 lcd_subpx_rect1;
layout(location = 1) out vec4 lcd_subpx_rect2;
layout(location = 2) out vec2 subpx_offset_in_px;
layout(location = 3) out vec2 tx_coord;
layout(location = 4) out vec2 tx_to_px;
layout(location = 5) out vec2 tx_orig_offs;
layout(location = 6) out float eff_blur_in_px;

void main() {
    gl_Position = global.MVP * Position;

    calculate_lcd_params(param.OriginalSize.xy, param.OutputSize.xy, param.Rotation,
                         param.AUTH_GBC_SUBPX, uint(param.AUTH_GBC_SUBPX_ORIENTATION),
                         param.AUTH_GBC_BRIG, TexCoord, lcd_subpx_rect1, lcd_subpx_rect2,
                         subpx_offset_in_px, tx_coord, tx_to_px, tx_orig_offs);

    // Blur strength is isotropic, so use the dimension that is most limiting.
    eff_blur_in_px = param.AUTH_GBC_BLUR * min(tx_to_px.x, tx_to_px.y) * 0.5;
}

#pragma stage fragment
layout(location = 0) in vec4 lcd_subpx_rect1;
layout(location = 1) in vec4 lcd_subpx_rect2;
layout(location = 2) in vec2 subpx_offset_in_px;
layout(location = 3) in vec2 tx_coord;
layout(location = 4) in vec2 tx_to_px;
layout(location = 5) in vec2 tx_orig_offs;
layout(location = 6) in float eff_blur_in_px;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "../../../misc/shaders/coverage/coverage.inc"

float subpx_coverage(vec4 px_square, vec2 subpx_orig) {
    // To render the "notch" present in the original subpixels, compose two rectangles.
    return intersect_blurred_rect_area(px_square, subpx_orig.xyxy + lcd_subpx_rect1,
                                       eff_blur_in_px) +
           intersect_blurred_rect_area(px_square, subpx_orig.xyxy + lcd_subpx_rect2,
                                       eff_blur_in_px);
}

vec3 pixel_color(vec2 tx_orig) {
    return vec3(subpx_coverage(vec4(-subpx_offset_in_px - 0.5, -subpx_offset_in_px + 0.5),
                               tx_orig + vec2(tx_orig_offs.x - tx_to_px.x / 3.0, tx_orig_offs.y)),
                subpx_coverage(vec4(vec2(-0.5), vec2(0.5)), tx_orig + tx_orig_offs),
                subpx_coverage(vec4(subpx_offset_in_px - 0.5, subpx_offset_in_px + 0.5),
                               tx_orig + vec2(tx_orig_offs.x + tx_to_px.x / 3.0, tx_orig_offs.y)));
}

void main() {
    // Figure out four nearest texels in source texture and sample them.
    vec2 tx_coord_i;
    const vec2 tx_coord_f = modf(tx_coord, tx_coord_i);
    const vec2 tx_coord_off = step(vec2(0.5), tx_coord_f) * 2.0 - 1.0;
    const vec2 tx_coord_offs[] = {vec2(0.0), vec2(tx_coord_off.x, 0.0), vec2(0.0, tx_coord_off.y),
                                  tx_coord_off};

    vec3 samples[] = {
        texture(Source, (tx_coord_i + tx_coord_offs[0] + 0.5) * param.OriginalSize.zw).rgb,
        texture(Source, (tx_coord_i + tx_coord_offs[1] + 0.5) * param.OriginalSize.zw).rgb,
        texture(Source, (tx_coord_i + tx_coord_offs[2] + 0.5) * param.OriginalSize.zw).rgb,
        texture(Source, (tx_coord_i + tx_coord_offs[3] + 0.5) * param.OriginalSize.zw).rgb};
    
    // Single pass version: Apply linearization.
    samples[0] = pow(samples[0], vec3(2.2));
    samples[1] = pow(samples[1], vec3(2.2));
    samples[2] = pow(samples[2], vec3(2.2));
    samples[3] = pow(samples[3], vec3(2.2));

    // The four nearest texels define a set of vector graphics which are rasterized.
    // The coordinate origin is shifted to px_coord = tx_coord * tx_to_px.
    const vec3 res = pixel_color((tx_coord_offs[0] - tx_coord_f) * tx_to_px) * samples[0] +
                     pixel_color((tx_coord_offs[1] - tx_coord_f) * tx_to_px) * samples[1] +
                     pixel_color((tx_coord_offs[2] - tx_coord_f) * tx_to_px) * samples[2] +
                     pixel_color((tx_coord_offs[3] - tx_coord_f) * tx_to_px) * samples[3];

    FragColor = vec4(pow(res, vec3(1.0 / 2.2)), 1.0);
}
