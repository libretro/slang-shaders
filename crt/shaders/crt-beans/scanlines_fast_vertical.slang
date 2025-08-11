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
    float OutputGamma;
} params;

#include "parameters_fast.inc"
#include "mask.inc"
#include "line_handling.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 viewportCoord;

void main() {
    gl_Position = MVP * Position;

    // Handle overscan.
    vTexCoord = (1.0 - vec2(params.OverscanHorizontal, params.OverscanVertical)) * (TexCoord - 0.5) + 0.5;

    // The viewport coordinates (*not* processed for overscan).
    // We need this for the mask.
    viewportCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 viewportCoord;
layout(location = 0) out vec4 FragColor;
layout(binding = 1) uniform sampler2D Source;

vec3 linear_to_srgb(vec3 rgb) {
    // Floating point inaccuracies could result in negative values, so we'll
    // clamp here to avoid NaNs.
    rgb = clamp(rgb, 0.0, 1.0);
    bvec3 cutoff = lessThan(rgb, vec3(0.0031308));
    vec3 higher = vec3(1.055) * pow(rgb, vec3(1.0 / 2.4)) - vec3(0.055);
    vec3 lower = rgb * vec3(12.92);

    return mix(higher, lower, cutoff);
}

vec3 linear_to_gamma(vec3 rgb) {
    // Floating point inaccuracies could result in negative values, so we'll
    // clamp here to avoid NaNs.
    rgb = clamp(rgb, 0.0, 1.0);
    return pow(rgb, vec3(1.0 / 2.2));
}

vec3 scanlines(lines_t lines, float u) {
    vec3 upper_sample = textureLod(Source, vec2(u, lines.upper_sample_y), 0.0).rgb;
    vec3 upper_width_rcp = 1.0 / (params.MinSpotSize * params.MaxSpotSize - sqrt(upper_sample) * (params.MinSpotSize * params.MaxSpotSize - params.MaxSpotSize));
    vec3 upper_y = clamp(abs(lines.upper_distance_y) * upper_width_rcp, 0.0, 1.0);
    vec3 upper_value = upper_sample * upper_width_rcp * ((upper_y * upper_y) * (2.0 * upper_y - 3.0) + 1.0);

    vec3 lower_sample = textureLod(Source, vec2(u, lines.lower_sample_y), 0.0).rgb;
    vec3 lower_width_rcp = 1.0 / (params.MinSpotSize * params.MaxSpotSize - sqrt(lower_sample) * (params.MinSpotSize * params.MaxSpotSize - params.MaxSpotSize));
    vec3 lower_y = clamp(abs(lines.lower_distance_y) * lower_width_rcp, 0.0, 1.0);
    vec3 lower_value = lower_sample * lower_width_rcp * ((lower_y * lower_y) * (2.0 * lower_y - 3.0) + 1.0);

    return params.MaxSpotSize * (upper_value + lower_value);
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
        vec4 mask = subpixel_aperture_grille(vTexCoord, params.OutputSize, params.SubpixelPattern, params.SubpixelMaskPattern);
        value = blend_mask(mask.rgb, value, mask.a);
    } else if (params.MaskType == 2.0) {
        vec4 mask = dynamic_aperture_grille(vTexCoord, params.OutputSize, params.DynamicMaskTriads);
        value = blend_mask(mask.rgb, value, mask.a);
    } // Otherwise, no mask

    if (params.OutputGamma < 0.5) {
        value = linear_to_srgb(value);
    } else {
        value = linear_to_gamma(value);
    }

    FragColor.rgb = value;
}
