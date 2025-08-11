#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    float GlowSigma;
} params;

// #pragma format R8G8B8A8_SRGB
#pragma format R16G16B16A16_SFLOAT

#include "parameters_common.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(binding = 1) uniform sampler2D Source;

/* This is a fast gaussian blur, relying on three tricks:
 *
 * - Bilinear filtering to reduce the number of texture samples.
 *   See: https://www.rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
 * - Updating the gaussian weights incrementally rather than recomputing using
 *   the exponential function each time.
 *   See: https://developer.nvidia.com/gpugems/gpugems3/part-vi-gpu-computing/chapter-40-incremental-computation-gaussian
 * - Relying on the output texture being the same size as the input texture
 *   and the symmetry of the gaussian distribution, to sample from the middle
 *   out which saves some ALU.
 */
void main() {
    float sigma = params.GlowSigma * params.SourceSize.y;
    // Guarantee an even number of taps on each side of center, at least sigma * 3.
    int side_taps = 2 * int(ceil(sigma * 1.5));

    vec2 pos = vTexCoord.xy * params.SourceSize.xy;
    float weight_sum = 0.0;
    vec3 value = vec3(0.0);

    // Center tap
    weight_sum += 1.0;
    value += texelFetch(Source, ivec2(floor(pos.x), floor(pos.y)), 0).rgb;

    // Taps from middle out
    float g0 = exp(-1.0 / (2.0 * sigma * sigma));
    float g2 = g0 * g0;
    float g1 = g0 * g2;
    for (int distance_x = 1; distance_x <= side_taps; distance_x += 2) {
        float weight0 = g0;
        g0 *= g1;
        g1 *= g2;
        float weight1 = g0;
        g0 *= g1;
        g1 *= g2;

        float scale = weight0 + weight1;
        weight_sum = 2.0 * scale + weight_sum;

        float delta = (distance_x + weight1 / scale) * params.SourceSize.z;

        value += textureLod(Source, vec2(vTexCoord.x - delta, vTexCoord.y), 0.0).rgb * scale;
        value += textureLod(Source, vec2(vTexCoord.x + delta, vTexCoord.y), 0.0).rgb * scale;
    }

    FragColor.rgb = value / weight_sum;
}
