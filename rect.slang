#version 450

#pragma parameter BLUR "Blur" 10.0 0.0 1000.0 10.0

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
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
    float dist_to_center = abs(x - center);
    float range = end - start;

    if (blur < 1.0e-5 || dist_to_center <= 0.5 * (range - blur)) {
        return clamp((x - start), 0.0, range);
    }

    float x_n = max(0.5 * (max(range, blur) + blur) - dist_to_center, 0.0) / blur;
    float poly = x_n * x_n * x_n * (1.0 - x_n * 0.5) * min(range, blur);
    return (x <= center) ? poly : range - poly;
}

void main() {
    vec2 px_coord = vTexCoord * param.OutputSize.xy;
    vec4 rect = vec4(251.24, 233.32, 457.85, 641.02);

    float res_x = rect_cdf(rect.x, rect.z, param.BLUR, px_coord.x + 0.5) -
                  rect_cdf(rect.x, rect.z, param.BLUR, px_coord.x - 0.5);
    float res_y = rect_cdf(rect.y, rect.w, param.BLUR, px_coord.y + 0.5) -
                  rect_cdf(rect.y, rect.w, param.BLUR, px_coord.y - 0.5);
    float pos = res_x * res_y;

    rect = vec4(rect.x, rect.y + 250.0, rect.z - 150.0, rect.w);
    res_x = rect_cdf(rect.x, rect.z, param.BLUR, px_coord.x + 0.5) -
            rect_cdf(rect.x, rect.z, param.BLUR, px_coord.x - 0.5);
    res_y = rect_cdf(rect.y, rect.w, param.BLUR, px_coord.y + 0.5) -
            rect_cdf(rect.y, rect.w, param.BLUR, px_coord.y - 0.5);
    float neg = res_x * res_y;

    FragColor = vec4(vec3(pos - neg), 1.0);
}