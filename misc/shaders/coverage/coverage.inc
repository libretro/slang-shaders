// Computes intersection area between pixels and geometric shapes for perfect (analytical)
// anti-aliasing.
// If the pixel square that is passed in has unit area, the result can be directly converted to a
// color.

float intersect_rect_area(vec4 px_square, vec4 rect) {
    const vec2 bl = max(px_square.xy, rect.xy);
    const vec2 tr = min(px_square.zw, rect.zw);
    const vec2 coverage = max(tr - bl, vec2(0.0));
    return coverage.x * coverage.y;
}

float intersect_blurred_rect_area(vec4 px_square, vec4 rect, float blur) {
    vec4 range = (rect.zw - rect.xy).xyxy;
    vec4 linear = clamp(px_square - rect.xyxy, vec4(0.0), range);

    // Early out: If blur is very small, return perfectly sharp rectangle intersection area.
    if (blur < 1.0e-6) {
        return (linear.z - linear.x) * (linear.w - linear.y);
    }

    vec4 center = (0.5 * (rect.xy + rect.zw)).xyxy;
    vec4 dist_to_center = abs(px_square - center);
    vec4 blur_vec = vec4(blur);

    vec4 x_n = max(0.5 * (max(range, blur_vec) + blur_vec) - dist_to_center, vec4(0.0)) / blur_vec;
    // Quartic polynomial fit to function:
    // x / 2 + exp(-x ^ 2 / 2) / sqrt(2 * pi) + x / 2 * erf(x / sqrt(2));
    // Subject to y(0) = 0, y'(0) = 0, y(1) = 1/2, y'(1) = 1
    const vec3 c = vec3(-0.3635, 0.727, 0.1365);
    vec4 poly = fma(fma(c.xxxx, x_n, c.yyyy), x_n, c.zzzz) * x_n * x_n * min(range, blur_vec);
    // Exploit point symmetry around center
    vec4 transition = mix(poly, range - poly, step(center, px_square));

    // Determine if we are in the linear or transitional part.
    vec4 res = mix(linear, transition, step(0.5 * (range - blur_vec), dist_to_center));
    return (res.z - res.x) * (res.w - res.y);
}
