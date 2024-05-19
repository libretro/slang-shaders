#version 450

/*
    Virtual Screen v1.0 by fishku
    Copyright (C) 2024
    Public domain license (CC0)

    Changelog:
    v1.0: Initial release.
*/

#include "parameters.inc"
#include "shared.inc"

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float VIRT_SCREEN_F;
    float R;
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

void main() {
#if 0
    // Debug

#else
    // Generate ray
    const vec2 aspect =
        param.OutputSize.xy / max(param.OutputSize.x, param.OutputSize.y);
    const vec2 uv = (vTexCoord - 0.5) * 2.0 * aspect;
    const vec3 ray_o = vec3(0.0, 0.0, 5.0);
    const vec3 ray_d = vec3(uv, -param.VIRT_SCREEN_F);

    // Intersect sphere
    const float r = param.R;
    vec3 oc = ray_o;
    float a = dot(ray_d, ray_d);
    float half_b = dot(oc, ray_d);
    float c = dot(oc, oc) - r * r;
    float disc = half_b * half_b - a * c;
    
    if (disc < 0.0) {
        FragColor = vec4(vec3(0.0), 1.0);
    }
    
    float disc_sq = sqrt(disc);
    float root1 = (-half_b - disc_sq) / a;
    // float root2 = (-half_b + disc_sq) / a;
    
    const vec3 intersection_p = ray_o + root1 * ray_d;

    const vec3 normal = normalize(intersection_p);

    FragColor = vec4(normal, 1.0);
#endif
}
