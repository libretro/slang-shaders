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
layout(location = 6) out float half_px_size;

void main() {
    gl_Position = global.MVP * Position;

    calculate_lcd_params(param.OriginalSize.xy, param.OutputSize.xy, param.Rotation,
                         param.AUTH_GBC_SUBPX, uint(param.AUTH_GBC_SUBPX_ORIENTATION),
                         param.AUTH_GBC_BRIG, TexCoord, lcd_subpx_rect1, lcd_subpx_rect2,
                         subpx_offset_in_px, tx_coord, tx_to_px, tx_orig_offs);

    // In the "fast" version of the shader, instead of rendering a rectangle convolved with a
    // Gaussian, we simply increase the pixel size and normalize. In effect, this achieves a box
    // filter, approximating the Gaussian low-pass filter.
    // We fudge the blur radius by a conversion factor, since the Gaussian kernel would appear
    // sharper for the same radius because it concentrates more mass near the center.
    // This requires an extra normalization step of the resulting color.
    float eff_blur_in_px = 0.7 * param.AUTH_GBC_BLUR * min(tx_to_px.x, tx_to_px.y) * 0.5;
    half_px_size = 0.5 * clamp(1.0 + eff_blur_in_px, 1.0, min(tx_to_px.x, tx_to_px.y));
}

#pragma stage fragment
layout(location = 0) in vec4 lcd_subpx_rect1;
layout(location = 1) in vec4 lcd_subpx_rect2;
layout(location = 2) in vec2 subpx_offset_in_px;
layout(location = 3) in vec2 tx_coord;
layout(location = 4) in vec2 tx_to_px;
layout(location = 5) in vec2 tx_orig_offs;
layout(location = 6) in float half_px_size;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Rectangle coverage separates into horizontal and vertical overlap. Reuse each
// axis for both neighboring rows/columns instead of intersecting 24 rectangles.
vec3 overlap(vec3 lo, vec3 hi, vec3 origin, float start, float end) {
    return max(min(hi, origin + end) - max(lo, origin + start), vec3(0.0));
}

void horizontal_coverage(float origin, out vec3 first, out vec3 second) {
    vec3 offset = vec3(-subpx_offset_in_px.x, 0.0, subpx_offset_in_px.x);
    vec3 subpixel = vec3(origin) + vec3(tx_orig_offs.x - tx_to_px.x / 3.0,
                                       tx_orig_offs.x,
                                       tx_orig_offs.x + tx_to_px.x / 3.0);
    first = overlap(offset - half_px_size, offset + half_px_size, subpixel,
                    lcd_subpx_rect1.x, lcd_subpx_rect1.z);
    second = overlap(offset - half_px_size, offset + half_px_size, subpixel,
                     lcd_subpx_rect2.x, lcd_subpx_rect2.z);
}

void vertical_coverage(float origin, out vec3 first, out vec3 second) {
    float subpixel = origin + tx_orig_offs.y;
    if (subpx_offset_in_px.y == 0.0) {
        // With horizontal or disabled display subpixels, all channels share Y.
        first = vec3(max(min(half_px_size, subpixel + lcd_subpx_rect1.w) -
                         max(-half_px_size, subpixel + lcd_subpx_rect1.y), 0.0));
        second = vec3(max(min(half_px_size, subpixel + lcd_subpx_rect2.w) -
                          max(-half_px_size, subpixel + lcd_subpx_rect2.y), 0.0));
    } else {
        vec3 offset = vec3(-subpx_offset_in_px.y, 0.0, subpx_offset_in_px.y);
        first = overlap(offset - half_px_size, offset + half_px_size, vec3(subpixel),
                        lcd_subpx_rect1.y, lcd_subpx_rect1.w);
        second = overlap(offset - half_px_size, offset + half_px_size, vec3(subpixel),
                         lcd_subpx_rect2.y, lcd_subpx_rect2.w);
    }
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

    vec3 x0_first, x0_second, x1_first, x1_second;
    vec3 y0_first, y0_second, y1_first, y1_second;
    horizontal_coverage(-tx_coord_f.x * tx_to_px.x, x0_first, x0_second);
    horizontal_coverage((tx_coord_off.x - tx_coord_f.x) * tx_to_px.x, x1_first, x1_second);
    vertical_coverage(-tx_coord_f.y * tx_to_px.y, y0_first, y0_second);
    vertical_coverage((tx_coord_off.y - tx_coord_f.y) * tx_to_px.y, y1_first, y1_second);

    const vec3 res = ((x0_first * y0_first + x0_second * y0_second) * samples[0] +
                      (x1_first * y0_first + x1_second * y0_second) * samples[1] +
                      (x0_first * y1_first + x0_second * y1_second) * samples[2] +
                      (x1_first * y1_first + x1_second * y1_second) * samples[3]) /
                     (4.0 * half_px_size * half_px_size);

    FragColor = vec4(sqrt(res), 1.0);
}
