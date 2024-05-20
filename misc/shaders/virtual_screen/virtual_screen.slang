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
    // vec3 res =
    //     textureGrad(Source, vTexCoord,
    //                 vec2(log2(1.0 - vTexCoord.x) / 32.0, 0.0),
    //                 dFdy(vTexCoord))
    //         .rgb;

    // float lod = vTexCoord.x * 8.0;
    // vec3 res_1 = textureLod(Source, vTexCoord, floor(lod)).rgb;
    // vec3 res_2 = textureLod(Source, vTexCoord, floor(lod) + 1.0).rgb;
    // FragColor = vec4(mix(res_1, res_2, fract(lod)), 1.0);
    // return;

    // Generate ray
    vec2 aspect =
        param.OutputSize.xy / max(param.OutputSize.x, param.OutputSize.y);
    vec2 uv = (vTexCoord - 0.5) * aspect;
    // TODO find distance automatically
    vec3 ray_o = vec3(0.0, 0.0, 5.0);
    vec3 ray_d = vec3(uv, -param.VIRT_SCREEN_F);

    // Intersect sphere
    const vec3 sphere_o = vec3(0.0);
    const float r = param.R;
    vec3 oc = ray_o - sphere_o;
    float a = dot(ray_d, ray_d);
    float half_b = dot(oc, ray_d);
    float c = dot(oc, oc) - r * r;
    float disc = half_b * half_b - a * c;

    if (disc < 0.0) {
        FragColor = vec4(vec3(0.0), 1.0);
        return;
    }

    float disc_sq = sqrt(disc);
    // TODO: Sign of half_b is always negative?
    const float q = -(half_b + sign(half_b) * disc_sq);
    // We only need the smaller root of the two solutions for the sphere-ray
    // intersection. The smaller root can be found as follows, according to:
    // https://www.av8n.com/physics/quadratic-formula.htm
    // This assumes that the solution is positive.
    float root = c / q;
    const vec3 p_sphere = ray_o + root * ray_d;
    const vec3 normal = normalize(p_sphere);

    // Intersect plane
    ray_o = sphere_o;
    ray_d = p_sphere - sphere_o;
    // TODO this will be rotated
    const vec3 plane_o = vec3(0.0, 0.0, -r);
    const vec3 plane_n = plane_o - sphere_o;
    float denom = dot(plane_n, ray_d);
    // We assume that denom is not close to zero.
    const vec3 d = plane_o - ray_o;
    const float t = dot(d, plane_n) / denom;
    // We assume that t >= 0.
    const vec3 p_plane = ray_o + t * ray_d;

    // Convert plane intersection to input UV
    aspect = param.SourceSize.xy / max(param.SourceSize.x, param.SourceSize.y);
    // Invert p_plane to flip image the right way up.
    uv = -p_plane.xy / aspect + 0.5;

    // Do a sharp "pixel art" sampling following:
    // https://www.youtube.com/watch?v=d6tp43wZqps
    // You may probably want to do a different kind of sampling when chaining
    // this shader with other effects.

    // Naive approach
    // vec2 px_per_tx = param.OutputSize.xy * param.SourceSize.zw;
    // vec2 tx = uv * param.SourceSize.xy;
    // vec2 tx_offset = clamp(fract(tx) * px_per_tx, 0, 0.5) -
    //                  clamp((1 - fract(tx)) * px_per_tx, 0, 0.5);
    // uv = (floor(tx) + 0.5 + tx_offset) * param.SourceSize.zw;

    // // First d_uv_dx & d_uv_dy version
    // vec2 box_size = (abs(dFdx(uv)) + abs(dFdy(uv))) * param.SourceSize.xy;
    // // vec2 px_per_tx = param.OutputSize.xy * param.SourceSize.zw;
    // vec2 tx = uv * param.SourceSize.xy;
    // vec2 tx_offset = clamp(fract(tx) / box_size, 0, 0.5) -
    //                  clamp((1 - fract(tx)) / box_size, 0, 0.5);
    // uv = (floor(tx) + 0.5 + tx_offset) * param.SourceSize.zw;

    // // Use fwidth instead of d_uv_dx & d_uv_dy
    // vec2 box_size = fwidth(uv) * param.SourceSize.xy;
    // // vec2 px_per_tx = param.OutputSize.xy * param.SourceSize.zw;
    // vec2 tx = uv * param.SourceSize.xy;
    // vec2 tx_offset = clamp(fract(tx) / box_size, 0, 0.5) -
    //                  clamp((1 - fract(tx)) / box_size, 0, 0.5);
    // uv = (floor(tx) + 0.5 + tx_offset) * param.SourceSize.zw;

    // // Simplify code
    // vec2 box_size = fwidth(uv) * param.SourceSize.xy;
    // vec2 tx = uv * param.SourceSize.xy - 0.5 * box_size;
    // vec2 tx_offset = clamp((fract(tx) - (1 - box_size)) / box_size,
    // 0.0, 1.0); uv = (floor(tx) + 0.5 + tx_offset) * param.SourceSize.zw;

    // // Clamp box size
    // vec2 box_size = clamp(fwidth(uv) * param.SourceSize.xy, 1.0e-6, 1.0);
    // vec2 tx = uv * param.SourceSize.xy - 0.5 * box_size;
    // vec2 tx_offset = clamp((fract(tx) - (1 - box_size)) / box_size,
    // 0.0, 1.0); uv = (floor(tx) + 0.5 + tx_offset) * param.SourceSize.zw;

    // // Use bilinear sampling. Ignore gamma correctness.
    // const vec3 rgb = texture(Source, uv).rgb;

    // // Better texture sampling
    // const vec2 d_uv_dx = dFdx(uv);
    // const vec2 d_uv_dy = dFdy(uv);
    // vec2 box_size = clamp((abs(d_uv_dx) + abs(d_uv_dy)) *
    // param.SourceSize.xy, 1.0e-6, 1.0); vec2 tx = uv * param.SourceSize.xy -
    // 0.5 * box_size; vec2 tx_offset = clamp((fract(tx) - (1 - box_size)) /
    // box_size, 0.0, 1.0); uv = (floor(tx) + 0.5 + tx_offset) *
    // param.SourceSize.zw; const vec3 rgb = textureGrad(Source, uv, d_uv_dx,
    // d_uv_dy).rgb;

    // Smoothstep weighting
    const vec2 d_uv_dx = dFdx(uv);
    const vec2 d_uv_dy = dFdy(uv);
    vec2 box_size =
        clamp((abs(d_uv_dx) + abs(d_uv_dy)) * param.SourceSize.xy, 1.0e-6, 1.0);
    vec2 tx = uv * param.SourceSize.xy - 0.5 * box_size;
    vec2 tx_offset = smoothstep(1 - box_size, vec2(1), fract(tx));
    uv = (floor(tx) + 0.5 + tx_offset) * param.SourceSize.zw;
    const vec3 rgb = textureGrad(Source, uv, d_uv_dx, d_uv_dy).rgb;

    FragColor = vec4(rgb, 1.0);
}
