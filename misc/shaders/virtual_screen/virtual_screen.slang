#version 450

/*
    Virtual Screen v1.0 by fishku
    Copyright (C) 2024
    Public domain license (CC0)

    Changelog:
    v1.0: Initial release.
*/

// Uncommented means sharp pixel art, better for stand-alone usage.
// Commented out means bilinear filtering, better for appending.
// #define SHARP_PIXEL_SAMPLING

#include "parameters.inc"
#include "shared.inc"

layout(push_constant) uniform Push {
    vec4 OriginalSize;
    vec4 OutputSize;
    float VIRT_SCREEN_ASPECT_H;
    float VIRT_SCREEN_ASPECT_V;
    float VIRT_SCREEN_CURVATURE;
    float VIRT_SCREEN_ZOOM;
    float VIRT_SCREEN_TILT_ANGLE;
    float VIRT_SCREEN_F;
    float VIRT_SCREEN_ROUNDED_CORNER;
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

void update_frustum(const vec3 curvature_o, const float curv,
                    const vec3 plane_o, const vec3 plane_u, const vec3 plane_v,
                    const vec2 input_aspect, const float f,
                    inout vec3 half_spaces[4], inout float min_z, vec2 uv) {
    uv -= 0.5;
    uv *= input_aspect;
    vec3 p = plane_o + uv.x * plane_u + uv.y * plane_v;
    if (curv > 1.0e-3) {
        p = normalize(p - curvature_o) / curv;
    }
    half_spaces[0].z = min(half_spaces[0].z, dot(half_spaces[0].xy, p.xz));
    half_spaces[1].z = min(half_spaces[1].z, dot(half_spaces[1].xy, p.xz));
    half_spaces[2].z = min(half_spaces[2].z, dot(half_spaces[2].xy, p.yz));
    half_spaces[3].z = min(half_spaces[3].z, dot(half_spaces[3].xy, p.yz));
    min_z = min(min_z, p.z);
}

vec2 line_intersection(vec3 l1, vec3 l2) {
    // Assumes lines are not parallel.
    const float inv_det = 1.0 / (l1.x * l2.y - l2.x * l1.y);
    return vec2((l2.y * l1.z - l1.y * l2.z) * inv_det,
                (l1.x * l2.z - l2.x * l1.z) * inv_det);
}

void main() {
    // FragColor = vec4(vTexCoord, 0.0, 1.0);
    // return;

    // Misc. pre-computation
    const vec2 input_aspect =
        param.VIRT_SCREEN_ASPECT_H > 0.0 && param.VIRT_SCREEN_ASPECT_V > 0.0
            ? vec2(param.VIRT_SCREEN_ASPECT_H, param.VIRT_SCREEN_ASPECT_V) /
                  max(param.VIRT_SCREEN_ASPECT_H, param.VIRT_SCREEN_ASPECT_V)
            : param.OriginalSize.xy /
                  max(param.OriginalSize.x, param.OriginalSize.y);
    // const vec2 input_aspect = vec2(1.0, 0.75);
    const vec2 output_aspect =
        param.OutputSize.xy / max(param.OutputSize.x, param.OutputSize.y);
    // Focal length
    const float f = param.VIRT_SCREEN_F;

    // Define curved object, sphere or cylinder
    const vec3 curvature_o = vec3(0.0, 0.0, 0.0);
    const float curv = param.VIRT_SCREEN_CURVATURE;
    const float r = 1.0 / curv;

    // Define plane
    const float sin_tilt = sin(param.VIRT_SCREEN_TILT_ANGLE);
    const float cos_tilt = cos(param.VIRT_SCREEN_TILT_ANGLE);
    const vec3 plane_o = curv > 1.0e-3 ? vec3(0.0, -r * sin_tilt, -r * cos_tilt)
                                       : vec3(0.0, -sin_tilt, -cos_tilt);
    const vec3 plane_u = vec3(1.0, 0.0, 0.0);
    const vec3 plane_v = vec3(0.0, cos_tilt, -sin_tilt);
    const vec3 plane_n = plane_o - curvature_o;

    // Figure out optimal camera position from 8 points:
    // Upper left, upper middle, upper right, lower left, lower middle, lower
    // right, left middle, right middle.
    // We want to find the camera position that is as close as possible to the
    // points, maximizing the points in the frustum view.
    vec3 half_spaces[4] = {vec3(f, 0.5 * output_aspect.x, 1.0e16),
                           vec3(-f, 0.5 * output_aspect.x, 1.0e16),
                           vec3(-f, 0.5 * output_aspect.y, 1.0e16),
                           vec3(f, 0.5 * output_aspect.y, 1.0e16)};
    float min_z = 1.0e16;
    update_frustum(curvature_o, curv, plane_o, plane_u, plane_v, input_aspect,
                   f, half_spaces, min_z, vec2(0.0, 0.0));
    update_frustum(curvature_o, curv, plane_o, plane_u, plane_v, input_aspect,
                   f, half_spaces, min_z, vec2(0.5, 0.0));
    update_frustum(curvature_o, curv, plane_o, plane_u, plane_v, input_aspect,
                   f, half_spaces, min_z, vec2(1.0, 0.0));
    update_frustum(curvature_o, curv, plane_o, plane_u, plane_v, input_aspect,
                   f, half_spaces, min_z, vec2(0.0, 0.5));
    update_frustum(curvature_o, curv, plane_o, plane_u, plane_v, input_aspect,
                   f, half_spaces, min_z, vec2(1.0, 0.5));
    update_frustum(curvature_o, curv, plane_o, plane_u, plane_v, input_aspect,
                   f, half_spaces, min_z, vec2(0.0, 1.0));
    update_frustum(curvature_o, curv, plane_o, plane_u, plane_v, input_aspect,
                   f, half_spaces, min_z, vec2(0.5, 1.0));
    update_frustum(curvature_o, curv, plane_o, plane_u, plane_v, input_aspect,
                   f, half_spaces, min_z, vec2(1.0, 1.0));
    const vec2 i_xz = line_intersection(half_spaces[0], half_spaces[1]);
    const vec2 i_yz = line_intersection(half_spaces[2], half_spaces[3]);
    const float ideal_cam_z = min(i_xz[1], i_yz[1]);

    // Generate camera ray
    vec3 ray_o = vec3(i_xz[0], i_yz[0],
                      min_z + (ideal_cam_z - min_z) / param.VIRT_SCREEN_ZOOM);
    vec3 ray_d = vec3((vTexCoord - 0.5) * output_aspect, f);

    // FragColor = vec4(ray_d.xy, 0.0, 1.0);
    // return;

    if (curv > 1.0e-3) {
        // Intersect sphere
        const vec3 oc = ray_o - curvature_o;
        const float a = dot(ray_d, ray_d);
        const float half_b = dot(oc, ray_d);
        const float c = dot(oc, oc) - r * r;
        const float disc = half_b * half_b - a * c;

        if (disc < 0.0) {
            FragColor = vec4(vec3(0.0), 1.0);
            return;
        }

        // We only need the smaller root of the two solutions for the sphere-ray
        // intersection. The smaller root can be found as c / q, according to:
        // https://www.av8n.com/physics/quadratic-formula.htm
        // Simplification: Assume the solution is positive.
        // Simplification: Assume half_b < 0.
        const vec3 p_sphere = ray_o + c / (sqrt(disc) - half_b) * ray_d;

        // const vec3 n_sphere = normalize(p_sphere - curvature_o);
        // FragColor = vec4((n_sphere * 0.5 + 0.5).xy, 0.0, 1.0);
        // return;

        ray_o = curvature_o;
        ray_d = p_sphere - curvature_o;
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
        smoothstep(-(param.OutputSize.z + param.OutputSize.w), 0.0, -dist);

#ifdef SHARP_PIXEL_SAMPLING
    // Do a sharp "pixel art" sampling, following:
    // https://www.youtube.com/watch?v=d6tp43wZqps
    // You may probably want to do a different kind of sampling when chaining
    // this shader with other effects.
    const vec2 d_uv_dx = dFdx(uv) * param.OriginalSize.xy;
    const vec2 d_uv_dy = dFdy(uv) * param.OriginalSize.xy;
    const vec2 box_size = clamp(abs(d_uv_dx) + abs(d_uv_dy), 1.0e-6, 1.0);
    const vec2 tx = uv * param.OriginalSize.xy - 0.5 * box_size;
    const vec2 tx_offset = smoothstep(1 - box_size, vec2(1.0), fract(tx));
    uv = (floor(tx) + 0.5 + tx_offset) * param.OriginalSize.zw;

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
#else
    FragColor = texture(Source, uv);
#endif

    // Apply rounded corner
    FragColor.rgb *= darkening;
}
