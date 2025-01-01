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
    float dist_to_center = abs(x - center);
    float range = end - start;

    if (blur < 1.0e-5 || dist_to_center <= 0.5 * (range - blur)) {
        return clamp((x - start), 0.0, range);
    }

    float x_n = max(0.5 * (max(range, blur) + blur) - dist_to_center, 0.0) / blur;
    
    // float poly = x_n * x_n * x_n * (1.0 - x_n * 0.5);
    
    float a = -0.3635;
    float b = 0.727;
    float c = 0.1365;
    float poly = a * x_n * x_n * x_n * x_n + b * x_n * x_n * x_n + c * x_n * x_n;

    poly *= min(range, blur);
    return (x <= center) ? poly : range - poly;
}

void main() {
    vec2 px_coord = vTexCoord * param.OutputSize.xy;
    vec4 rect = vec4(251.24, 233.32, 457.85, 641.02);

    // float blur = sin(param.FrameCount / 90.0) * 20.0;
    float blur = param.BLUR;
    blur = blur * blur;

    // First rect complete
    float res_x = rect_cdf(rect.x, rect.z, blur, px_coord.x + 0.5) -
                  rect_cdf(rect.x, rect.z, blur, px_coord.x - 0.5);
    float res_y = rect_cdf(rect.y, rect.w, blur, px_coord.y + 0.5) -
                  rect_cdf(rect.y, rect.w, blur, px_coord.y - 0.5);
    float pos = res_x * res_y;

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