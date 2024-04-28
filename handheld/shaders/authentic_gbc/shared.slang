// See the main shader file for copyright and other information.

// As determined by counting pixels on a photo.
const vec2 subpx_ratio = vec2(0.296, 0.910);
const vec2 notch_ratio = vec2(0.115, 0.166);

float rect_coverage(vec4 px_rect, vec4 rect) {
    const vec2 bl = max(rect.xy, px_rect.xy);
    const vec2 tr = min(rect.zw, px_rect.zw);
    const vec2 coverage = max(tr - bl, 0.0);
    return coverage.x * coverage.y;
}

float subpx_coverage(vec4 px_rect, vec2 subpx_orig, vec2 subpx_size,
                     vec2 notch_size) {
    return rect_coverage(px_rect, vec4(subpx_orig, subpx_orig + subpx_size)) -
           rect_coverage(
               px_rect,
               vec4(subpx_orig.x, subpx_orig.y + subpx_size.y - notch_size.y,
                    subpx_orig.x + notch_size.x, subpx_orig.y + subpx_size.y));
}

vec3 pixel_color(vec4 px_rect, vec2 px_size, vec2 px_orig, float subpx_orig_y,
                 vec2 subpx_size, vec2 notch_size) {
    return vec3(
        subpx_coverage(
            px_rect,
            px_orig + vec2(px_size.x / 6.0 - subpx_size.x * 0.5, subpx_orig_y),
            subpx_size, notch_size),
        subpx_coverage(
            px_rect,
            px_orig + vec2(px_size.x / 2.0 - subpx_size.x * 0.5, subpx_orig_y),
            subpx_size, notch_size),
        subpx_coverage(
            px_rect,
            px_orig +
                vec2(5.0 * px_size.x / 6.0 - subpx_size.x * 0.5, subpx_orig_y),
            subpx_size, notch_size));
}
