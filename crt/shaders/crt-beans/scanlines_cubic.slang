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
#include "parameters_sampled.inc"
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
    delta = params.SourceSize.y > 300.0 ? 0.5 * delta : delta;

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
layout(binding = 2) uniform sampler2D Filtered;

vec3 spot(vec3 sample_value, vec3 width_rcp, float distance_x, float distance_y) {
    vec3 x = clamp(abs(distance_x) * width_rcp, 0.0, 1.0);
    vec3 y = clamp(abs(distance_y) * width_rcp, 0.0, 1.0);
    return sample_value * width_rcp * width_rcp * ((x * x) * (2.0 * x - 3.0) + 1.0) * ((y * y) * (2.0 * y - 3.0) + 1.0);
}

vec3 scanlines(lines_t lines, float u) {
    vec3 value = vec3(0.0);
    float start_x = params.SourceSize.z * (round(u * params.SourceSize.x - (params.MaxSpotSize / delta)) + 0.5);
    float stop_x = params.SourceSize.z * round(u * params.SourceSize.x + (params.MaxSpotSize / delta));
    float distance_x = delta * params.SourceSize.x * (start_x - u);
    for (float sample_x = start_x; sample_x < stop_x; sample_x += params.SourceSize.z) {
        vec3 upper_sample = textureLod(Filtered, vec2(sample_x, lines.upper_sample_y), 0.0).rgb;
        vec3 upper_width_rcp = textureLod(Source, vec2(sample_x, lines.upper_sample_y), 0.0).rgb;
        vec3 lower_sample = textureLod(Filtered, vec2(sample_x, lines.lower_sample_y), 0.0).rgb;
        vec3 lower_width_rcp = textureLod(Source, vec2(sample_x, lines.lower_sample_y), 0.0).rgb;
        value += spot(upper_sample, upper_width_rcp, distance_x, lines.upper_distance_y);
        value += spot(lower_sample, lower_width_rcp, distance_x, lines.lower_distance_y);
        distance_x += delta;
    }
    return delta * params.MaxSpotSize * value;
}

void main() {
    vec3 value = vec3(0.0);
    if (params.SourceSize.y <= 300.0) {
        // no interlacing
        lines_t lines = get_closest_lines(vTexCoord.y, params.SourceSize);
        value = scanlines(lines, vTexCoord.x);
    } else if (params.OddFieldFirst == 2.0) {
        // weave
        // Simulate even and odd fields, then average them together
        lines_t lines_even = get_even_lines(vTexCoord.y, params.SourceSize);
        value = scanlines(lines_even, vTexCoord.x);
        lines_t lines_odd = get_odd_lines(vTexCoord.y, params.SourceSize);
        value = 0.5 * (value + scanlines(lines_odd, vTexCoord.x));
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
