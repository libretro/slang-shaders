// Authentic GBC – Coverage Functions
// Adapted from authentic_gbc/authentic_gbc_fast.slang by fishku.

// Coverage adapted from authentic_gbc_fast.slang for reusable grid stages.
// Keep the standalone LCD shader and its native colour-conversion pass intact.

#pragma stage vertex
#include "../../../authentic_gbc/shared.inc"
// Grid geometry and sampling coordinates shared by the separate stages.
layout(location = 12) out vec4 lcd_subpx_rect1;
layout(location = 13) out vec4 lcd_subpx_rect2;
layout(location = 14) out vec4 lcd_geometry;
layout(location = 15) out vec3 lcd_coord;
layout(location = 11) out vec2 lcd_scale;

void prepareLCD() {
    vec2 subpx_offset, tx_coord, tx_to_px, tx_orig_offs;
    calculate_lcd_params(global.OriginalSize.xy, global.FinalViewportSize.xy, global.Rotation,
                         global.AUTH_GBC_SUBPX, uint(global.AUTH_GBC_SUBPX_ORIENTATION),
                         global.AUTH_GBC_BRIG, TexCoord, lcd_subpx_rect1, lcd_subpx_rect2,
                         subpx_offset, tx_coord, tx_to_px, tx_orig_offs);
    float eff_blur = 0.7 * global.AUTH_GBC_BLUR * min(tx_to_px.x, tx_to_px.y) * 0.5;
    float half_px = 0.5 * clamp(1.0 + eff_blur, 1.0, min(tx_to_px.x, tx_to_px.y));
    lcd_scale = tx_to_px;
    lcd_geometry = vec4(subpx_offset, tx_orig_offs);
    lcd_coord = vec3(tx_coord, half_px);
}

#pragma stage fragment
layout(location = 12) in vec4 lcd_subpx_rect1;
layout(location = 13) in vec4 lcd_subpx_rect2;
layout(location = 14) in vec4 lcd_geometry;
layout(location = 15) in vec3 lcd_coord;
layout(location = 11) in vec2 lcd_scale;

vec3 lcd_coverage;
vec3 lcd_line_color;

vec3 overlap(vec3 lo, vec3 hi, vec3 origin, float start, float end) {
    return max(min(hi, origin + end) - max(lo, origin + start), vec3(0.0));
}

void horizontal_coverage(float origin, vec2 tx_to_px, out vec3 first, out vec3 second) {
    vec3 offset = vec3(-lcd_geometry.x, 0.0, lcd_geometry.x);
    vec3 subpixel = vec3(origin) + vec3(lcd_geometry.z - tx_to_px.x / 3.0,
                                       lcd_geometry.z,
                                       lcd_geometry.z + tx_to_px.x / 3.0);
    first = overlap(offset - lcd_coord.z, offset + lcd_coord.z, subpixel,
                    lcd_subpx_rect1.x, lcd_subpx_rect1.z);
    second = overlap(offset - lcd_coord.z, offset + lcd_coord.z, subpixel,
                     lcd_subpx_rect2.x, lcd_subpx_rect2.z);
}

void vertical_coverage(float origin, out vec3 first, out vec3 second) {
    float subpixel = origin + lcd_geometry.w;
    if (lcd_geometry.y == 0.0) {
        first = vec3(max(min(lcd_coord.z, subpixel + lcd_subpx_rect1.w) -
                         max(-lcd_coord.z, subpixel + lcd_subpx_rect1.y), 0.0));
        second = vec3(max(min(lcd_coord.z, subpixel + lcd_subpx_rect2.w) -
                          max(-lcd_coord.z, subpixel + lcd_subpx_rect2.y), 0.0));
    } else {
        vec3 offset = vec3(-lcd_geometry.y, 0.0, lcd_geometry.y);
        first = overlap(offset - lcd_coord.z, offset + lcd_coord.z, vec3(subpixel),
                        lcd_subpx_rect1.y, lcd_subpx_rect1.w);
        second = overlap(offset - lcd_coord.z, offset + lcd_coord.z, vec3(subpixel),
                         lcd_subpx_rect2.y, lcd_subpx_rect2.w);
    }
}

#ifndef PT_GRID_AXIS_ONLY
void lcdWeights(out ivec2 cell, out ivec2 offset, out vec3 w0, out vec3 w1,
                out vec3 w2, out vec3 w3, out float area) {
    ivec2 pixel = ivec2(floor(lcd_coord.xy * lcd_scale));
    vec4 xMeta0 = texelFetch(PTGridX, ivec2(pixel.x, 0), 0);
    vec3 x0_first = xMeta0.rgb;
    vec4 xMeta1 = texelFetch(PTGridX, ivec2(pixel.x, 1), 0);
    vec3 x0_second = xMeta1.rgb;
    vec3 x1_first = texelFetch(PTGridX, ivec2(pixel.x, 2), 0).rgb;
    vec3 x1_second = texelFetch(PTGridX, ivec2(pixel.x, 3), 0).rgb;
    vec4 yMeta0 = texelFetch(PTGridY, ivec2(0, pixel.y), 0);
    vec3 y0_first = yMeta0.rgb;
    vec4 yMeta1 = texelFetch(PTGridY, ivec2(1, pixel.y), 0);
    vec3 y0_second = yMeta1.rgb;
    vec3 y1_first = texelFetch(PTGridY, ivec2(2, pixel.y), 0).rgb;
    vec3 y1_second = texelFetch(PTGridY, ivec2(3, pixel.y), 0).rgb;
    cell = ivec2(xMeta0.a, yMeta0.a);
    offset = ivec2(xMeta1.a, yMeta1.a);
    w0 = x0_first * y0_first + x0_second * y0_second;
    w1 = x1_first * y0_first + x1_second * y0_second;
    w2 = x0_first * y1_first + x0_second * y1_second;
    w3 = x1_first * y1_first + x1_second * y1_second;
    area = 4.0 * lcd_coord.z * lcd_coord.z;
}

#endif
#ifndef PT_GRID_OVERLAY_ONLY
vec3 nativeSample(ivec2 cell) {
    return texture(LCDInput, (vec2(cell) + vec2(0.5)) * global.OriginalSize.zw).rgb;
}

vec3 quantizeLCD(vec3 color) {
    // Preserve the removed R8G8B8A8_UNORM framebuffer's clipping and rounding.
    return color; // The separate framebuffer performs the quantization.
}

vec4 sampleLCD() {
    ivec2 cell, offset;
    vec3 w0, w1, w2, w3;
    float area;
    lcdWeights(cell, offset, w0, w1, w2, w3, area);
    vec3 samples[] = {nativeSample(cell), nativeSample(cell + ivec2(offset.x, 0)),
                      nativeSample(cell + ivec2(0, offset.y)), nativeSample(cell + offset)};
    vec3 res = (w0 * samples[0] + w1 * samples[1] + w2 * samples[2] + w3 * samples[3]) / area;

    bool above = global.PT_GRID > 0.5;
    if (!above && global.PT_GRID_STRENGTH == 1.0 &&
        global.PT_GRID_BRIGHTNESS == 0.0)
        return vec4(quantizeLCD(sqrt(res)), 1.0);

    vec3 coverage = clamp((w0 + w1 + w2 + w3) / area, 0.0, 1.0);
    vec3 native_color = mix(samples[0], res / max(coverage, vec3(0.000001)),
                           greaterThan(coverage, vec3(0.000001)));
    // In Accurate placement the final pass applies the grid, so pass the native colour through.
    if (above)
        return vec4(sqrt(max(native_color, vec3(0.0))), 1.0);
    float strength = global.PT_GRID_STRENGTH;
    lcd_coverage = mix(vec3(1.0), coverage, strength);
    vec3 line = vec3(global.PT_GRID_BRIGHTNESS);
    lcd_line_color = line * line;
    if (above)
        return vec4(quantizeLCD(sqrt(max(native_color, vec3(0.0)))), 1.0);
    vec3 colored = native_color * lcd_coverage + lcd_line_color * (vec3(1.0) - lcd_coverage);
    return vec4(quantizeLCD(sqrt(max(colored, vec3(0.0)))), 1.0);
}

#endif
