#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    float MaxSpotSize;
    float MinSpotSize;
    float OverscanHorizontal;
    float OverscanVertical;
    float OddFieldFirst;
} params;

#pragma format R16G16B16A16_SFLOAT

#include "parameters_fast.inc"
#include "parameters_fast.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) flat out float delta;

void main() {
    gl_Position = MVP * Position;
    vTexCoord = TexCoord;

    // TODO Handle horizontal overscan?

    // Distance units are *scanlines heights*. delta is the distance between
    // samples on the x-axis, and has to be adjusted by the aspect ratio.
    // Overscan changes the aspect ratio and needs to be taken into account.
    delta = params.FinalViewportSize.x * params.FinalViewportSize.w *
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
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) flat in float delta;
layout(location = 0) out vec4 FragColor;
layout(binding = 1) uniform sampler2D Source;

#define PI 3.1415926535897932384626433832795

// TODO proper doc
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
vec3 spot_integral(vec3 sample_value, float x, float x0, float x1) {
    vec3 w_rcp =  1.0 / (params.MinSpotSize * params.MaxSpotSize - sqrt(sample_value) * (params.MinSpotSize * params.MaxSpotSize - params.MaxSpotSize));
    vec3 u0 = clamp(w_rcp * (x - x0), -1.0, 1.0);
    vec3 u1 = clamp(w_rcp * (x - x1), -1.0, 1.0);
    return sample_value * (PI * u0 + sin(PI * u0) - PI * u1 - sin(PI * u1));
}

// sign() requires ~4 instructions because it needs to account for edge cases
// (0.0 and -0.0, etc). This is 2 instructions.
// vec3 fast_sign(vec3 val) {
//     return vec3(val.r < 0.0 ? -1.0 : 1.0, val.g < 0.0 ? -1.0 : 1.0, val.b < 0.0 ? -1.0 : 1.0);
// }

// vec3 spot_integral2(vec3 sample_value, vec3 w_rcp, float x, float x0, float x1) {
//     vec3 edge0 = clamp(w_rcp * (x - x0), -1.0, 1.0);
//     vec3 edge1 = clamp(w_rcp * (x - x1), -1.0, 1.0);
//     return sample_value * (((edge0 * edge0) * (fast_sign(edge0) * (edge0 * edge0) - edge0) + edge0) -
//             ((edge1 * edge1) * (fast_sign(edge1) * (edge1 * edge1) - edge1) + edge1));
// }

void main() {
    vec3 value = vec3(0.0);
    float start_x = params.SourceSize.z * (floor(vTexCoord.x * params.SourceSize.x - (params.MaxSpotSize / delta)) + 0.5);
    float stop_x = params.SourceSize.z * (floor(vTexCoord.x * params.SourceSize.x + (params.MaxSpotSize / delta)) + 1.0);
    float x = vTexCoord.x * params.SourceSize.x * delta;
    for (float sample_x = start_x; sample_x < stop_x; sample_x += params.SourceSize.z) {
        vec3 sample_value = textureLod(Source, vec2(sample_x, vTexCoord.y), 0.0).rgb;
        float x0 = delta * (params.SourceSize.x * sample_x - 0.5);
        float x1 = x0 + delta;
        value += spot_integral(sample_value, x, x0, x1);
    }
    // We pulled these common factors out of the integral. Multiply them now.
    value = value / (2.0 * PI); // For spot 1 only

    FragColor.rgb = value;
}
