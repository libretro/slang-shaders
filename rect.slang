#version 450

#pragma parameter BLUR "Blur" 10.0 0.0 20.0 0.1

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float BLUR;
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
layout(set = 0, binding = 2) uniform sampler2D Source;

float rect_cdf(float start, float end, float blur, float x) {
    float center = 0.5 * (start + end);
    float range = end - start;
    float dist_to_center = abs(x - center);

    float linear = clamp((x - start), 0.0, range);

    float x_n = max(0.5 * (max(range, blur) + blur) - dist_to_center, 0.0) / (blur + 1.0e-6);
    // Quartic polynomial fit to function:
    // x / 2 + exp(-x ^ 2 / 2) / sqrt(2 * pi) + x / 2 * erf(x / sqrt(2));
    // Subject to y(0) = 0, y'(0) = 0, y(1) = 1/2, y'(1) = 1
    const vec3 c = vec3(-0.3635, 0.727, 0.1365);
    float poly = fma(fma(c.x, x_n, c.y), x_n, c.z) * x_n * x_n * min(range, blur);
    float transition = mix(poly, range - poly, step(center, x));

    // If blur < eps or distance to center is less than width of linear section, use linear section.
    float part = step(1.0e-6, blur) * step(0.5 * (range - blur), dist_to_center);
    return mix(linear, transition, part);
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

void main() {
    vec2 px_coord = vTexCoord * param.OutputSize.xy;
    vec4 rect = vec4(251.24, 233.32, 457.85, 641.02);

    // float blur = sin(param.FrameCount / 90.0) * 20.0;
    float blur = param.BLUR;
    blur = blur * blur;

    float res_x, res_y;

    // First rect complete
    // float res_x = rect_cdf(rect.x, rect.z, blur, px_coord.x + 0.5) -
    //               rect_cdf(rect.x, rect.z, blur, px_coord.x - 0.5);
    // float res_y = rect_cdf(rect.y, rect.w, blur, px_coord.y + 0.5) -
    //               rect_cdf(rect.y, rect.w, blur, px_coord.y - 0.5);
    // float pos = res_x * res_y;
    float pos = intersect_blurred_rect_area(vec4(px_coord - 0.5, px_coord + 0.5), rect, blur);

    // Subtract rect
    rect = vec4(rect.x, rect.y + 250.0, rect.z - 150.0, rect.w);
    res_x = rect_cdf(rect.x, rect.z, blur, px_coord.x + 0.5) -
            rect_cdf(rect.x, rect.z, blur, px_coord.x - 0.5);
    res_y = rect_cdf(rect.y, rect.w, blur, px_coord.y + 0.5) -
            rect_cdf(rect.y, rect.w, blur, px_coord.y - 0.5);
    float neg = res_x * res_y;

    // Second rect additive
    rect = vec4(251.24 + 1000.0, 233.32, 457.85 + 1000.0, 233.32 + 250.0);
    res_x = rect_cdf(rect.x, rect.z, blur, px_coord.x + 0.5) -
            rect_cdf(rect.x, rect.z, blur, px_coord.x - 0.5);
    res_y = rect_cdf(rect.y, rect.w, blur, px_coord.y + 0.5) -
            rect_cdf(rect.y, rect.w, blur, px_coord.y - 0.5);
    float pos2 = res_x * res_y;

    // Second rect 2nd part
    rect = vec4(rect.z - 150.0, rect.w, rect.z, 641.02);
    res_x = rect_cdf(rect.x, rect.z, blur, px_coord.x + 0.5) -
            rect_cdf(rect.x, rect.z, blur, px_coord.x - 0.5);
    res_y = rect_cdf(rect.y, rect.w, blur, px_coord.y + 0.5) -
            rect_cdf(rect.y, rect.w, blur, px_coord.y - 0.5);
    float pos3 = res_x * res_y;

    FragColor = vec4(0.8 * vec3(pos - neg + pos2 + pos3), 1.0);
}
