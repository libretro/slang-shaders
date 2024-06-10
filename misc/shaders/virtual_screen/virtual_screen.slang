#version 450

/*
    Virtual Screen v1.0 by fishku
    Copyright (C) 2024
    Public domain license (CC0)

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
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void update_frustum(bool shape, const vec3 curvature_o, const float curv,
                    const vec3 plane_o, const vec3 plane_u, const vec3 plane_v,
                    const vec2 input_aspect, const float f,
                    inout vec3 half_spaces[4], inout vec3 p_min,
                    inout vec3 p_max, vec2 uv) {
    uv -= 0.5;
    uv *= input_aspect;
    vec3 p = plane_o + uv.x * plane_u + uv.y * plane_v;
    if (curv > 1.0e-3) {
        if (shape) {
            // Sphere
            p = curvature_o + normalize(p - curvature_o) / curv;
        } else {
            // Cylinder
            // Assume that the cylinder axis is == plane_v.
            const vec3 oc = p - curvature_o;
            const vec3 p_on_ax = curvature_o + dot(oc, plane_v) * plane_v;
            p = p_on_ax + normalize(p - p_on_ax) / curv;
        }
    }
    half_spaces[0].z = min(half_spaces[0].z, dot(half_spaces[0].xy, p.xz));
    half_spaces[1].z = min(half_spaces[1].z, dot(half_spaces[1].xy, p.xz));
    half_spaces[2].z = min(half_spaces[2].z, dot(half_spaces[2].xy, p.yz));
    half_spaces[3].z = min(half_spaces[3].z, dot(half_spaces[3].xy, p.yz));
    p_min = min(p_min, p);
    p_max = max(p_max, p);
}

vec2 line_intersection(vec3 l1, vec3 l2) {
    // Assumes lines are not parallel.
    const float inv_det = 1.0 / (l1.x * l2.y - l2.x * l1.y);
    return vec2((l2.y * l1.z - l1.y * l2.z) * inv_det,
                (l1.x * l2.z - l2.x * l1.z) * inv_det);
}

void main() {
    // Misc. pre-computation
    const vec2 input_aspect =
        param.VIRT_SCREEN_ASPECT_H > 0.0 && param.VIRT_SCREEN_ASPECT_V > 0.0
            ? vec2(param.VIRT_SCREEN_ASPECT_H, param.VIRT_SCREEN_ASPECT_V) /
                  max(param.VIRT_SCREEN_ASPECT_H, param.VIRT_SCREEN_ASPECT_V)
            : param.OriginalSize.xy /
                  max(param.OriginalSize.x, param.OriginalSize.y);
    const vec2 output_aspect =
        param.OutputSize.xy / max(param.OutputSize.x, param.OutputSize.y);
    // Focal length
    const float f = param.VIRT_SCREEN_F;

    // Define curved object: sphere or cylinder
    const float sin_tilt = sin(param.VIRT_SCREEN_TILT_ANGLE);
    const float cos_tilt = cos(param.VIRT_SCREEN_TILT_ANGLE);
    const vec3 curvature_o = vec3(0.0, 0.0, 0.0);
    const float curv = param.VIRT_SCREEN_CURVATURE;
    const float r = 1.0 / curv;
    const vec3 cyl_ax = vec3(0.0, cos_tilt, -sin_tilt);

    // Define plane
    const vec3 plane_o = curv > 1.0e-3 ? vec3(0.0, -r * sin_tilt, -r * cos_tilt)
                                       : vec3(0.0, -sin_tilt, -cos_tilt);
    const vec3 plane_u = vec3(1.0, 0.0, 0.0);
    const vec3 plane_v = vec3(0.0, cos_tilt, -sin_tilt);
    const vec3 plane_n = plane_o - curvature_o;

    // Figure out optimal camera position from 9 points sampled across the
    // frame. We want to find the camera position that is as close as possible
    // to the points, maximizing the points in the frustum view.
    vec3 half_spaces[4] = {vec3(f, 0.5 * output_aspect.x, 1.0e16),
                           vec3(-f, 0.5 * output_aspect.x, 1.0e16),
                           vec3(f, 0.5 * output_aspect.y, 1.0e16),
                           vec3(-f, 0.5 * output_aspect.y, 1.0e16)};
    vec3 p_min = vec3(1.0e16);
    vec3 p_max = vec3(-1.0e16);
    const bool shape = param.VIRT_SCREEN_SHAPE < 0.5;
    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) {
            update_frustum(shape, curvature_o, curv, plane_o, plane_u, plane_v,
                           input_aspect, f, half_spaces, p_min, p_max,
                           vec2(i * 0.5, j * 0.5));
        }
    }
    const vec2 i_xz = line_intersection(half_spaces[0], half_spaces[1]);
    const vec2 i_yz = line_intersection(half_spaces[2], half_spaces[3]);
    const float ideal_cam_z = min(i_xz[1], i_yz[1]);

    // Generate camera ray
    vec3 ray_o, ray_d;
    if (param.VIRT_SCREEN_F < VIRT_SCREEN_F_MAX) {
        // Perspective camera
        ray_o =
            vec3(i_xz[0], i_yz[0],
                 p_min.z + (ideal_cam_z - p_min.z) / param.VIRT_SCREEN_ZOOM);
        ray_d = vec3((vTexCoord - 0.5) * output_aspect, f);
    } else {
        // Orthographic camera
        const vec3 p_extent = p_max - p_min;
        const vec2 p_center = 0.5 * (p_min.xy + p_max.xy);
        ray_o = vec3(p_center + (vTexCoord - 0.5) * output_aspect *
                                    max(p_extent.x / output_aspect.x,
                                        p_extent.y / output_aspect.y) /
                                    param.VIRT_SCREEN_ZOOM,
                     p_min.z - 1.0);
        ray_d = vec3(0.0, 0.0, 1.0);
    }

    if (curv > 1.0e-3) {
        // Intersect sphere / cylinder
        float a, half_b, c;
        const vec3 oc = ray_o - curvature_o;
        if (param.VIRT_SCREEN_SHAPE < 0.5) {
            // sphere
            a = dot(ray_d, ray_d);
            half_b = dot(oc, ray_d);
            c = dot(oc, oc) - r * r;
        } else {
            // cylinder
            const vec3 alpha = ray_d - dot(ray_d, cyl_ax) * cyl_ax;
            const vec3 beta = oc - dot(oc, cyl_ax) * cyl_ax;
            a = dot(alpha, alpha);
            half_b = dot(alpha, beta);
            c = dot(beta, beta) - r * r;
        }
        const float disc = half_b * half_b - a * c;
        if (disc < 0.0) {
            FragColor = vec4(vec3(0.0), 1.0);
            return;
        }

        // We only need the smaller root of the two solutions for the ray-object
        // intersection. The smaller root can be found as c / q, according to:
        // https://www.av8n.com/physics/quadratic-formula.htm
        // Simplification: Assume the solution is positive.
        // Simplification: Assume half_b < 0.
        const vec3 p_screen = ray_o + c / (sqrt(disc) - half_b) * ray_d;

        // const vec3 n_sphere = normalize(p_screen - curvature_o);
        // FragColor = vec4((n_sphere * 0.5 + 0.5).xy, 0.0, 1.0);
        // return;

        if (param.VIRT_SCREEN_SHAPE < 0.5) {
            // sphere
            ray_o = p_screen;
            ray_d = p_screen - curvature_o;
        } else {
            // cylinder
            ray_o = p_screen;
            const vec3 oc = p_screen - curvature_o;
            const vec3 p_on_ax = curvature_o + dot(oc, plane_v) * plane_v;
            ray_d = p_screen - p_on_ax;
        }
    }

    // Intersect plane
    float denom = dot(plane_n, ray_d);
    // We assume that denom is not close to zero.
    const vec3 d = plane_o - ray_o;
    const float t = dot(d, plane_n) / denom;
    // We assume that t > 0.
    const vec3 p_plane = ray_o + t * ray_d;

    // Convert plane intersection to input UV
    const vec3 op = p_plane - plane_o;
    vec2 uv = vec2(dot(op, plane_u / input_aspect.x),
                   dot(op, plane_v / input_aspect.y)) +
              0.5;

    // Compute rounded corner darkening
    const vec2 q =
        input_aspect * (abs(uv - 0.5) - 0.5) + param.VIRT_SCREEN_ROUNDED_CORNER;
    const float dist = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) -
                       param.VIRT_SCREEN_ROUNDED_CORNER;
    const float darkening =
        smoothstep(-max(param.OutputSize.z, param.OutputSize.w), 0.0, -dist);

#if defined(SHARP_PIXEL_SAMPLING) || defined(TRILINEAR_SAMPLING)
    const vec2 d_uv_dx = dFdx(uv) * param.SourceSize.xy;
    const vec2 d_uv_dy = dFdy(uv) * param.SourceSize.xy;
#endif

#ifdef SHARP_PIXEL_SAMPLING
    // Do a sharp "pixel art" sampling, following:
    // https://www.youtube.com/watch?v=d6tp43wZqps
    // You may probably want to do a different kind of sampling when chaining
    // this shader with other effects.
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

    // Apply rounded corner
    FragColor.rgb *= darkening;
}
