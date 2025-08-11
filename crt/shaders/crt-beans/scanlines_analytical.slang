#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float MaxSpotSize;
    float MinSpotSize;
    float OddFieldFirst;
    float OverscanHorizontal;
    float OverscanVertical;
    float MaskType;
    float SubpixelMaskPattern;
    float SubpixelPattern;
    float DynamicMaskTriads;
} params;

#pragma format R16G16B16A16_SFLOAT

#include "parameters_common.inc"
#include "parameters_analytical.inc"
#include "mask.inc"
#include "line_handling.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) flat out float delta;
layout(location = 2) out vec2 viewportCoord;

void main() {
    gl_Position = MVP * Position;

    // Handle overscan.
    vTexCoord = (1.0 - vec2(params.OverscanHorizontal, params.OverscanVertical)) * (TexCoord - 0.5) + 0.5;

    // Distance units are *scanlines heights*. delta is the distance between
    // samples on the x-axis, and has to be adjusted by the aspect ratio.
    // Overscan changes the aspect ratio and needs to be taken into account.
    delta = params.OutputSize.x * params.OutputSize.w *
            params.SourceSize.y * params.SourceSize.z *
            (1 - params.OverscanVertical) / (1 - params.OverscanHorizontal);

    // Adjust delta if we're interlacing.
    if (params.OddFieldFirst <= 2.0 && params.SourceSize.y > 300.0) {
        // bob or weave
        delta = 0.5 * delta;
    } else if (params.OddFieldFirst == 3.0 && params.SourceSize.y < 350) {
        // VGA line doubling
        delta = 2.0 * delta;
    }

    // The viewport coordinates (*not* processed for overscan).
    // We need this for the mask.
    viewportCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) flat in float delta;
layout(location = 2) in vec2 viewportCoord;
layout(location = 0) out vec4 FragColor;
layout(binding = 1) uniform sampler2D Source;
layout(binding = 2) uniform sampler2D Linearized;

#define PI 3.1415926535897932384626433832795

// Represents the convolution of the spot function over 1 texel. We can sum
// several calls of this function to solve the scanline convolution in a
// piecewise manner.
//
// The integral of:
//
//     MaxSpotSize * s *
//       (1 / w) * (2 * clamp(|y| / w, 0, 1)^3 - 3 * clamp(|y| / w, 0, 1)^2 + 1) *
//       (1 / w) * (1/2 + 1/2 * cos(pi * clamp((x - t) / w, -1, 1)))
//
// with respect to t over the interval [x0, x1], where:
//
//   * s is the sample value for this texel
//   * w is the radius of the spot for this texel (equivalently, the
//     full width at half maximum)
//   * x0 and x1 are the horizontal bounds of the texel along the scanline
//   * x is the current horizontal position along the scanline
//   * y is the current vertical position relative to the center of the scanline
//
// All units are in scanline widths (the vertical distance from the center of
// one scanline to the center of the next is 1).
//
// Note that a common factor of MaxSpotSize / (2 * pi) has been factored out of
// this function and should be multiplied back in externally.
vec3 spot_integral(vec3 sample_value, vec3 w_rcp, float x, float x0, float x1, float y) {
    vec3 edge0 = clamp(w_rcp * (x - x0), -1.0, 1.0);
    vec3 edge1 = clamp(w_rcp * (x - x1), -1.0, 1.0);
    vec3 y_ = clamp(abs(y) * w_rcp, 0.0, 1.0);
    return sample_value * w_rcp * ((y_ * y_) * (2.0 * y_ - 3.0) + 1.0) *
        (PI * edge0 + sin(PI * edge0) - PI * edge1 - sin(PI * edge1));
}

// sign(x) * 0.5 requires ~5 instructions because it needs to account for edge
// cases (0.0 and -0.0, etc) and multiply. This is 2 instructions.
vec3 fast_sign(vec3 val) {
    return vec3(val.r < 0.0 ? -0.5 : 0.5, val.g < 0.0 ? -0.5 : 0.5, val.b < 0.0 ? -0.5 : 0.5);
}

// This is basically the same as the above function, but using the cubic
// function as the horizontal component. This avoids the sin() calls, which may
// be slow on some GPUs. However, it uses more instructions in total.
vec3 spot_integral2(vec3 sample_value, vec3 w_rcp, float x, float x0, float x1, float y) {
    vec3 edge0 = clamp(w_rcp * (x - x0), -1.0, 1.0);
    vec3 edge1 = clamp(w_rcp * (x - x1), -1.0, 1.0);
    vec3 y_ = clamp(abs(y) * w_rcp, 0.0, 1.0);
    return sample_value * w_rcp * ((y_ * y_) * (2.0 * y_ - 3.0) + 1.0) *
        (((edge0 * edge0) * (fast_sign(edge0) * (edge0 * edge0) - edge0) + edge0) -
            ((edge1 * edge1) * (fast_sign(edge1) * (edge1 * edge1) - edge1) + edge1));
}

vec3 scanlines(lines_t lines, float u) {
    vec3 value = vec3(0.0);
    // TODO check bounds
    float start_x = params.SourceSize.z * (floor(u * params.SourceSize.x - (params.MaxSpotSize / delta)) + 0.5);
    float stop_x = params.SourceSize.z * (floor(u * params.SourceSize.x + (params.MaxSpotSize / delta)) + 1.0);
    float x = u * params.SourceSize.x * delta;
    for (float sample_x = start_x; sample_x < stop_x; sample_x += params.SourceSize.z) {
        vec3 upper_sample = textureLod(Linearized, vec2(sample_x, lines.upper_sample_y), 0.0).rgb;
        vec3 upper_width_rcp = textureLod(Source, vec2(sample_x, lines.upper_sample_y), 0.0).rgb;
        vec3 lower_sample = textureLod(Linearized, vec2(sample_x, lines.lower_sample_y), 0.0).rgb;
        vec3 lower_width_rcp = textureLod(Source, vec2(sample_x, lines.lower_sample_y), 0.0).rgb;
        float x0 = delta * (params.SourceSize.x * sample_x - 0.5);
        float x1 = x0 + delta;
        value += spot_integral(upper_sample, upper_width_rcp, x, x0, x1, lines.upper_distance_y);
        value += spot_integral(lower_sample, lower_width_rcp, x, x0, x1, lines.lower_distance_y);
    }
    // We pulled these common factors out of the integral. Multiply them now.
    return params.MaxSpotSize / (2 * PI) * value; // For spot_integral
    // return params.MaxSpotSize * value; // For spot_integral2
}

void main() {
    vec3 value = vec3(0.0);
    if (params.OddFieldFirst == 3.0 && params.SourceSize.y < 350) {
        // VGA line doubling
        lines_t lines = get_doubled_lines(vTexCoord.y, params.SourceSize);
        value = scanlines(lines, vTexCoord.x);
    } else if (params.OddFieldFirst == 4.0 || params.OddFieldFirst == 3.0 || params.SourceSize.y <= 300.0) {
        // no interlacing
        lines_t lines = get_closest_lines(vTexCoord.y, params.SourceSize);
        value = scanlines(lines, vTexCoord.x);
    } else if (params.OddFieldFirst == 2.0) {
        // weave
        // Simulate even and odd fields, then average them together
        lines_t lines_even = get_even_lines(vTexCoord.y, params.SourceSize);
        lines_t lines_odd = get_odd_lines(vTexCoord.y, params.SourceSize);
        value = 0.5 * (scanlines(lines_even, vTexCoord.x) + scanlines(lines_odd, vTexCoord.x));
    } else if ((params.FrameCount + (params.OddFieldFirst == 1.0 ? 1u : 0u)) % 2u == 0u) {
        // bob (odd phase)
        lines_t lines = get_odd_lines(vTexCoord.y, params.SourceSize);
        value = scanlines(lines, vTexCoord.x);
    } else {
        // bob (even phase)
        lines_t lines = get_even_lines(vTexCoord.y, params.SourceSize);
        value = scanlines(lines, vTexCoord.x);
    }

    if (params.MaskType == 1.0) {
        vec4 mask = subpixel_aperture_grille(viewportCoord, params.OutputSize, params.SubpixelPattern, params.SubpixelMaskPattern);
        value = blend_mask(mask.rgb, value, mask.a);
    } else if (params.MaskType == 2.0) {
        vec4 mask = dynamic_aperture_grille(viewportCoord, params.OutputSize, params.DynamicMaskTriads);
        value = blend_mask(mask.rgb, value, mask.a);
    } // Otherwise, no mask

    FragColor.rgb = value;
}
