#version 450

/*
    Virtual Screen v1.0 by fishku
    Copyright (C) 2024
    Public domain license (CC0)

    This example demoes the following:
    - How to generate rays for tracing against the screen surface in the vertex
      shader.
    - How to trace the rays in the fragment shader.
    - How to achieve high-quality sampling with the found UV.

    Changelog:
    v1.0: Initial release.
*/

// Uncommented means sharp pixel art, better for stand-alone usage.
// Commented out means no coordinate distortion, better for appending.
#define SHARP_PIXEL_SAMPLING

// Uncommented blends mip-map levels, if available, giving better AA.
#define TRILINEAR_SAMPLING

#include "parameters.inc"
#include "shared.inc"

layout(push_constant) uniform Push {
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    float VIRT_SCREEN_ASPECT_H;
    float VIRT_SCREEN_ASPECT_V;
    float VIRT_SCREEN_SHAPE;
    float VIRT_SCREEN_CURVATURE;
    float VIRT_SCREEN_ZOOM;
    float VIRT_SCREEN_TILT_ANGLE;
    float VIRT_SCREEN_F;
    float VIRT_SCREEN_ROUNDED_CORNER;
    float VIRT_SCREEN_LOD_BIAS;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec3 prim_ray_o;
layout(location = 1) out vec3 prim_ray_d;
layout(location = 2) out vec3 plane_n;
layout(location = 3) out vec3 plane_u;
layout(location = 4) out vec3 plane_v;

void main() {
    gl_Position = global.MVP * Position;

    // Define curved object: sphere or cylinder.
    // Simplification: Assume origin of curved object (sphere / cylinder) is at
    // the origin.
    const float r = param.VIRT_SCREEN_CURVATURE > 1.0e-3
                        ? 1.0 / param.VIRT_SCREEN_CURVATURE
                        : 1.0;
    const float sin_tilt = sin(param.VIRT_SCREEN_TILT_ANGLE);
    const float cos_tilt = cos(param.VIRT_SCREEN_TILT_ANGLE);
    // Simplification: Assume cylinder axis == plane_v.

    // Define plane
    plane_n = vec3(0.0, -r * sin_tilt, -r * cos_tilt);
    plane_u = vec3(1.0, 0.0, 0.0);
    plane_v = vec3(0.0, cos_tilt, -sin_tilt);

    // Misc. pre-computation.
    const vec2 input_aspect = get_input_aspect(
        vec2(param.VIRT_SCREEN_ASPECT_H, param.VIRT_SCREEN_ASPECT_V),
        param.OriginalSize.xy);
    const vec2 output_aspect =
        param.OutputSize.xy / max(param.OutputSize.x, param.OutputSize.y);

    // Simplification: Assume plane_o = plane_n
    generate_camera_ray(TexCoord, input_aspect, output_aspect, r, plane_n,
                        plane_u, plane_v, param.VIRT_SCREEN_F,
                        param.VIRT_SCREEN_SHAPE, param.VIRT_SCREEN_ZOOM,
                        prim_ray_o, prim_ray_d);
}

#pragma stage fragment
layout(location = 0) in vec3 prim_ray_o;
layout(location = 1) in vec3 prim_ray_d;
layout(location = 2) in vec3 plane_n;
layout(location = 3) in vec3 plane_u;
layout(location = 4) in vec3 plane_v;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    vec3 sec_ray_o = prim_ray_o;
    vec3 sec_ray_d = prim_ray_d;

    if (param.VIRT_SCREEN_CURVATURE > 1.0e-3) {
        // Intersect sphere / cylinder.
        // Simplification: Assume VIRT_SCREEN_SHAPE = 0 for sphere, = 1 for
        // cylinder. This allows multiplication instead of branching.
        // Simplification: Assume cylinder axis == plane_v.
        const vec3 alpha = prim_ray_d - param.VIRT_SCREEN_SHAPE *
                                            dot(prim_ray_d, plane_v) * plane_v;
        const vec3 beta = prim_ray_o - param.VIRT_SCREEN_SHAPE *
                                           dot(prim_ray_o, plane_v) * plane_v;
        const float half_b = dot(alpha, beta);
        const float r = 1.0 / param.VIRT_SCREEN_CURVATURE;
        const float c = dot(beta, beta) - r * r;
        // Simplification: a = dot(alpha, alpha).
        const float discriminant = half_b * half_b - dot(alpha, alpha) * c;
        if (discriminant < 0.0) {
            FragColor = vec4(vec3(0.0), 1.0);
            return;
        }

        // We only need the smaller root of the two solutions for the ray-object
        // intersection. The smaller root can be found as c / q, according to:
        // https://www.av8n.com/physics/quadratic-formula.htm
        // Simplification: Assume the solution is positive.
        // Simplification: Assume half_b < 0.
        const vec3 p_screen =
            prim_ray_o + c / (sqrt(discriminant) - half_b) * prim_ray_d;

        sec_ray_o = p_screen;
        // Simplification: Assume VIRT_SCREEN_SHAPE = 0 for sphere, = 1 for
        // cylinder. This allows multiplication instead of branching.
        sec_ray_d = p_screen -
                    param.VIRT_SCREEN_SHAPE * dot(p_screen, plane_v) * plane_v;
    }

    // Intersect plane.
    // Simplification:
    // t = dot(plane_o - sec_ray_o, plane_n) / dot(plane_n, sec_ray_d).
    // Simplification: Assume t > 0.
    // Simplification: Assume denominator is not close to zero.
    // Simplification: p_plane = sec_ray_o + dot(plane_o - sec_ray_o, plane_n) /
    //  dot(plane_n, sec_ray_d) * sec_ray_d;
    // Simplification: Assume plane_o = plane_n
    const vec3 op = sec_ray_o +
                    dot(plane_n - sec_ray_o, plane_n) /
                        dot(plane_n, sec_ray_d) * sec_ray_d -
                    plane_n;
    // Convert plane intersection to input UV.
    const vec2 input_aspect = get_input_aspect(
        vec2(param.VIRT_SCREEN_ASPECT_H, param.VIRT_SCREEN_ASPECT_V),
        param.OriginalSize.xy);
    vec2 uv = vec2(dot(op, plane_u / input_aspect.x),
                   dot(op, plane_v / input_aspect.y)) +
              0.5;

    // Compute rounded corner darkening.
    const vec2 q =
        input_aspect * (abs(uv - 0.5) - 0.5) + param.VIRT_SCREEN_ROUNDED_CORNER;
    const float rounded_rect_dist = min(max(q.x, q.y), 0.0) +
                                    length(max(q, 0.0)) -
                                    param.VIRT_SCREEN_ROUNDED_CORNER;
    const float corner_darkening = smoothstep(
        -max(param.OutputSize.z, param.OutputSize.w), 0.0, -rounded_rect_dist);

    // Sampling.
#if defined(SHARP_PIXEL_SAMPLING) || defined(TRILINEAR_SAMPLING)
    const vec2 d_uv_dx = dFdx(uv) * param.SourceSize.xy;
    const vec2 d_uv_dy = dFdy(uv) * param.SourceSize.xy;
#endif

#ifdef SHARP_PIXEL_SAMPLING
    // Do a sharp "pixel art" sampling, following:
    // https://www.youtube.com/watch?v=d6tp43wZqps
    const vec2 box_size = clamp(abs(d_uv_dx) + abs(d_uv_dy), 1.0e-6, 1.0);
    const vec2 tx = uv * param.SourceSize.xy - 0.5 * box_size;
    const vec2 tx_offset = smoothstep(1 - box_size, vec2(1.0), fract(tx));
    uv = (floor(tx) + 0.5 + tx_offset) * param.SourceSize.zw;
#endif

#ifdef TRILINEAR_SAMPLING
    // Anisotropic trilinear filtering.
    // Implement in software because current implementation is broken. See:
    // https://github.com/libretro/RetroArch/issues/16567
    const float lambda_base =
        max(0.0,
            0.5 * log2(max(dot(d_uv_dx, d_uv_dx), dot(d_uv_dy, d_uv_dy)))) +
        param.VIRT_SCREEN_LOD_BIAS;
    float lambda_i;
    const float lambda_f = modf(lambda_base, lambda_i);
    FragColor = vec4(mix(textureLod(Source, uv, lambda_i).rgb,
                         textureLod(Source, uv, lambda_i + 1.0).rgb, lambda_f),
                     1.0);
#else
    FragColor =
        vec4(textureLod(Source, uv, param.VIRT_SCREEN_LOD_BIAS).rgb, 1.0);
#endif

    // Apply rounded corner darkening.
    FragColor.rgb *= corner_darkening;
}
