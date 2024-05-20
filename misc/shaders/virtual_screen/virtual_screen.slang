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
    float VIRT_SCREEN_CURVATURE;
    float VIRT_SCREEN_ZOOM;
    float VIRT_SCREEN_TILT_ANGLE;
    float VIRT_SCREEN_F;
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
    // Misc. pre-computation
    const vec2 input_aspect =
        param.SourceSize.xy / max(param.SourceSize.x, param.SourceSize.y);
    // const vec2 input_aspect = vec2(1.0, 0.75);
    const vec2 output_aspect =
        param.OutputSize.xy / max(param.OutputSize.x, param.OutputSize.y);

    // Define sphere
    const vec3 sphere_o = vec3(0.0);
    const float r = 1.0 / param.VIRT_SCREEN_CURVATURE;

    // Define plane
    const float sin_tilt = sin(param.VIRT_SCREEN_TILT_ANGLE);
    const float cos_tilt = cos(param.VIRT_SCREEN_TILT_ANGLE);
    const vec3 plane_o = vec3(0.0, -r * sin_tilt, r * cos_tilt);
    const vec3 plane_u = vec3(1.0, 0.0, 0.0);
    const vec3 plane_v = vec3(0.0, cos_tilt, sin_tilt);
    const vec3 plane_n = plane_o - sphere_o;

    // Generate camera ray
    // TODO find distance automatically
    vec3 ray_o = vec3(0.0, plane_o.y, 5.0);
    vec3 ray_d = vec3((vTexCoord - 0.5) * output_aspect, -param.VIRT_SCREEN_F);

    // Intersect sphere
    const vec3 oc = ray_o - sphere_o;
    const float a = dot(ray_d, ray_d);
    const float half_b = dot(oc, ray_d);
    const float c = dot(oc, oc) - r * r;
    const float disc = half_b * half_b - a * c;

    if (disc < 0.0) {
        FragColor = vec4(vec3(0.0), 1.0);
        return;
    }

    // We only need the smaller root of the two solutions for the sphere-ray
    // intersection. The smaller root can be found as follows, according to:
    // https://www.av8n.com/physics/quadratic-formula.htm
    // Simplification: Assume the solution is positive.
    // Simplification: Assume half_b < 0.
    const vec3 p_sphere = ray_o + c / (sqrt(disc) - half_b) * ray_d;

    // Intersect plane
    ray_o = sphere_o;
    ray_d = p_sphere - sphere_o;
    float denom = dot(plane_n, ray_d);
    // We assume that denom is not close to zero.
    const vec3 d = plane_o - ray_o;
    const float t = dot(d, plane_n) / denom;
    // We assume that t > 0.
    const vec3 p_plane = ray_o + t * ray_d;

    // Convert plane intersection to input UV
    const vec3 po = p_plane - plane_o;
    vec2 uv = vec2(dot(po, plane_u), dot(po, plane_v)) / input_aspect + 0.5;

    // Do a sharp "pixel art" sampling, following:
    // https://www.youtube.com/watch?v=d6tp43wZqps
    // You may probably want to do a different kind of sampling when chaining
    // this shader with other effects.
    const vec2 d_uv_dx = dFdx(uv) * param.SourceSize.xy;
    const vec2 d_uv_dy = dFdy(uv) * param.SourceSize.xy;
    const vec2 box_size = clamp(abs(d_uv_dx) + abs(d_uv_dy), 1.0e-6, 1.0);
    const vec2 tx = uv * param.SourceSize.xy - 0.5 * box_size;
    const vec2 tx_offset = smoothstep(1 - box_size, vec2(1.0), fract(tx));
    uv = (floor(tx) + 0.5 + tx_offset) * param.SourceSize.zw;

    // Implement proper anisotropic texture filtering in software because
    // current implementation is broken. See:
    // https://github.com/libretro/RetroArch/issues/16567
    const float lambda_base =
        max(0.0, 0.5 * log2(max(dot(d_uv_dx, d_uv_dx), dot(d_uv_dy, d_uv_dy))));
    float lambda_i;
    const float lambda_f = modf(lambda_base, lambda_i);
    const vec3 rgb = mix(textureLod(Source, uv, lambda_i).rgb,
                         textureLod(Source, uv, lambda_i + 1.0).rgb, lambda_f);

    FragColor = vec4(rgb, 1.0);
}
