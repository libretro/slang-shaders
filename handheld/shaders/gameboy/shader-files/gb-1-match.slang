#version 450

#pragma name GameBoyMatchCorrection
#pragma format R32G32B32A32_SFLOAT

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.5                          //
//                                                                       //
// Copyright (C) 2013 Harlequin : unknown92835@gmail.com                 //
// Copyright (C) 2024-2026 Matt Akins                                    //
//                                                                       //
// This program is free software: you can redistribute it and/or modify  //
// it under the terms of the GNU General Public License as published by  //
// the Free Software Foundation, either version 3 of the License, or     //
// (at your option) any later version.                                   //
//                                                                       //
// This program is distributed in the hope that it will be useful,       //
// but WITHOUT ANY WARRANTY; without even the implied warranty of        //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         //
// GNU General Public License for more details.                          //
//                                                                       //
// You should have received a copy of the GNU General Public License     //
// along with this program.  If not, see <http://www.gnu.org/licenses/>. //
//                                                                       //
/////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////
 // Per-cell brightness correction                                      //
/////////////////////////////////////////////////////////////////////////

#include "gb-params.inc"
#include "gb-shared.inc"

// Bounded opacity curves for brightness matching across output scales.
struct AlphaCurve { vec4 a; vec4 b; vec4 c; vec4 d; vec4 x0; vec4 x1; vec4 x2; vec4 x3; };
float alpha_curve_value(AlphaCurve c, int i) {
    if (i < 4) return c.a[i];
    if (i < 8) return c.b[i - 4];
    if (i < 12) return c.c[i - 8];
    return c.d[i - 12];
}
float alpha_curve_strength(AlphaCurve c, int i) {
    if (i < 4) return c.x0[i];
    if (i < 8) return c.x1[i - 4];
    if (i < 12) return c.x2[i - 8];
    return c.x3[i - 12];
}
float alpha_curve_mean(AlphaCurve c, float strength) {
    int right_index = 1;
    if (!(strength <= c.x0.y)) {
        // Find the first matching knot; repeated knots keep their original tie order.
        int lower = 2;
        int upper = 16;
        for (int step = 0; step < 4; step++) {
            if (lower >= upper) break;
            int middle = (lower + upper) / 2;
            if (strength <= alpha_curve_strength(c, middle)) upper = middle;
            else lower = middle + 1;
        }
        right_index = lower;
    }
    if (right_index >= 16) return c.d.w;
    float right = alpha_curve_strength(c, right_index);
    float left = alpha_curve_strength(c, right_index - 1);
    return mix(alpha_curve_value(c, right_index - 1), alpha_curve_value(c, right_index),
        clamp((strength - left) / max(right - left, 0.000001), 0.0, 1.0));
}
vec4 alpha_unorm(vec4 v) { return roundEven(clamp(v, 0.0, 1.0) * 255.0) / 255.0; }
float alpha_unorm(float v) { return roundEven(clamp(v, 0.0, 1.0) * 255.0) / 255.0; }

float integer_clipped_alpha_mean(float strength, float scale, float mode, float blend) {
    float peak = alpha_unorm(strength);
    float gaps = 2.0 * (scale - 1.0) * alpha_unorm(2.0 * blend * peak);
    if (mode < 0.5)
        return ((scale - 1.0) * (scale - 1.0) * peak + gaps) / (scale * scale);
    float inner = max(scale - 3.0, 0.0);
    return (inner * inner * peak + 4.0 * inner * alpha_unorm(peak * (1.0 - blend)) +
        4.0 * alpha_unorm(peak * (1.0 - 2.0 * blend)) + gaps) / (scale * scale);
}

float matching_coverage_at_point(vec2 tx_coord_f, float pixel_size,
                                  float pixel_softness, float sharpening_amount,
                                  float pixel_shape, float sharp_mode) {
    vec2 pixel_center = tx_coord_f - 0.5;
    vec4 pixel_rect = vec4(pixel_center - 0.5, pixel_center + 0.5);
    vec2 dot_size_in_px = vec2(pixel_size);
    vec4 dot_rect = vec4(-dot_size_in_px * 0.5, dot_size_in_px * 0.5);

    float x_coverage = intersect_line_segment(pixel_rect.x, pixel_rect.z,
                                              dot_rect.x, dot_rect.z);
    float y_coverage = intersect_line_segment(pixel_rect.y, pixel_rect.w,
                                              dot_rect.y, dot_rect.w);
    float rect_linear = x_coverage * y_coverage;

    if (pixel_shape == 0.0) {
        float circle_linear = intersect_rect_area(pixel_rect, dot_rect);
        float circle_sharpened;
        if (sharp_mode < 0.5)
            circle_sharpened = pow(circle_linear, 1.0 / max(pixel_softness, 0.001));
        else {
            float sigmoid_strength = 10.0 / max(pixel_softness, 0.001);
            circle_sharpened = 1.0 / (1.0 + exp(-sigmoid_strength * (circle_linear - 0.5)));
        }
        return mix(circle_linear, circle_sharpened, sharpening_amount);
    }

    float rect_sharpened;
    if (sharp_mode < 0.5) {
        float sharp_factor = 1.0 / max(pixel_softness, 0.001);
        rect_sharpened = pow(x_coverage, sharp_factor) *
                         pow(y_coverage, sharp_factor);
    } else {
        float sigmoid_strength = 10.0 / max(pixel_softness, 0.001);
        float x_sharp = 1.0 / (1.0 + exp(-sigmoid_strength * (x_coverage - 0.5)));
        float y_sharp = 1.0 / (1.0 + exp(-sigmoid_strength * (y_coverage - 0.5)));
        rect_sharpened = x_sharp * y_sharp;
    }
    float rect_coverage = mix(rect_linear, rect_sharpened, sharpening_amount);
    if (pixel_shape == 1.0) return rect_coverage;

    float circ_linear = intersect_rect_area(pixel_rect, dot_rect);
    float circ_sharpened;
    if (sharp_mode < 0.5) {
        circ_sharpened = pow(circ_linear, 1.0 / max(pixel_softness, 0.001));
    } else {
        float sigmoid_strength = 10.0 / max(pixel_softness, 0.001);
        circ_sharpened = 1.0 / (1.0 + exp(-sigmoid_strength * (circ_linear - 0.5)));
    }
    float circ_coverage = mix(circ_linear, circ_sharpened, sharpening_amount);

    return mix(circ_coverage, rect_coverage, pixel_shape);
}

void build_alpha_curve(vec2 scale, vec2 output_size, vec2 source_size,
    float size, float softness, float sharpening, float shape, float sharp,
    float mode, float amount, float used_range, float target_coverage,
    out AlphaCurve curve, out float peak, out float coverage) {
    curve = AlphaCurve(vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0));
    peak = 0.0;
    coverage = 0.0;
    float blend = min(amount, max_adjacent_alpha_blend);
    ivec2 output_pixels = max(ivec2(round(output_size)), ivec2(1));
    ivec2 source_pixels = max(ivec2(round(source_size)), ivec2(1));
    ivec2 phases = ivec2(output_pixels.x / greatest_common_divisor(output_pixels.x, source_pixels.x),
                        output_pixels.y / greatest_common_divisor(output_pixels.y, source_pixels.y));
    ivec2 count = min(phases, ivec2(32));
    vec2 denominator = vec2(phases.x <= 32 ? scale.x : 32.0,
                            phases.y <= 32 ? scale.y : 32.0);
    // Put curve knots at actual saturation thresholds instead of a fixed grid.
    float knots[16];
    for (int i = 0; i < 16; i++) knots[i] = 1e12;
    knots[0] = 0.0;
    float last_threshold = 0.0;
    for (int y = 0; y < 32; y++) {
        if (y >= count.y) break;
        for (int x = 0; x < 32; x++) {
            if (x >= count.x) break;
            vec2 phase = fract((vec2(x, y) + 0.5) / denominator);
            float mask = matching_coverage_at_point(phase, size, softness, sharpening, shape, sharp);
            peak = max(peak, mask);
            coverage += mask;
            if (mask <= 0.0) continue;
            float threshold = 1.0 / mask;
            last_threshold = max(last_threshold, threshold);
            if (threshold >= knots[14]) continue;
            int lower = 1;
            int upper = 14;
            for (int step = 0; step < 4; step++) {
                if (lower >= upper) break;
                int middle = (lower + upper) / 2;
                if (threshold <= knots[middle]) upper = middle;
                else lower = middle + 1;
            }
            bool duplicate = abs(knots[lower] - threshold) < 0.00001;
            if (lower > 1)
                duplicate = duplicate || abs(knots[lower - 1] - threshold) < 0.00001;
            if (duplicate) continue;
            for (int j = 14; j > lower; j--) knots[j] = knots[j - 1];
            knots[lower] = threshold;
        }
    }
    for (int i = 1; i < 16; i++) knots[i] = min(knots[i], last_threshold);
    // Uneven fractional scales can fill all fourteen thresholds below the
    // opacities in use; dark cells would then interpolate across the gap to
    // the final threshold and be underestimated.
    float used_domain_coverage = coverage / float(count.x * count.y);
    if (any(lessThan(scale, vec2(1.0))))
        used_domain_coverage = sample_scale_average_coverage(scale, output_size, source_size,
            size, softness, sharpening, shape, sharp);
    float used_top = min(used_range * alpha_normalization_factor(target_coverage, used_domain_coverage),
        last_threshold);
    if (used_top > knots[14] && knots[14] < last_threshold) {
        float first_threshold = knots[1];
        for (int i = 1; i < 15; i++)
            knots[i] = first_threshold * pow(used_top / first_threshold, float(i - 1) / 13.0);
        knots[15] = last_threshold;
    }
    curve.x0 = vec4(knots[0], knots[1], knots[2], knots[3]);
    curve.x1 = vec4(knots[4], knots[5], knots[6], knots[7]);
    curve.x2 = vec4(knots[8], knots[9], knots[10], knots[11]);
    curve.x3 = vec4(knots[12], knots[13], knots[14], knots[15]);
    for (int y = 0; y < 32; y++) {
        if (y >= count.y) break;
        for (int x = 0; x < 32; x++) {
            if (x >= count.x) break;
            vec2 phase = fract((vec2(x, y) + 0.5) / denominator);
            float center = matching_coverage_at_point(phase, size, softness, sharpening, shape, sharp);
            peak = max(peak, center);
            vec4 neighbors = vec4(0.0);
            if (blend != 0.0) {
                neighbors.x = matching_coverage_at_point(fract(phase + vec2(1.0 / scale.x, 0.0)), size, softness, sharpening, shape, sharp);
                neighbors.y = matching_coverage_at_point(fract(phase - vec2(1.0 / scale.x, 0.0)), size, softness, sharpening, shape, sharp);
                neighbors.z = matching_coverage_at_point(fract(phase + vec2(0.0, 1.0 / scale.y)), size, softness, sharpening, shape, sharp);
                neighbors.w = matching_coverage_at_point(fract(phase - vec2(0.0, 1.0 / scale.y)), size, softness, sharpening, shape, sharp);
            }
            for (int group = 0; group < 4; group++) {
                vec4 strengths = vec4(knots[group * 4], knots[group * 4 + 1],
                    knots[group * 4 + 2], knots[group * 4 + 3]);
                vec4 alpha = alpha_unorm(center * strengths);
                vec4 adjacent = alpha_unorm(neighbors.x * strengths) + alpha_unorm(neighbors.y * strengths) +
                    alpha_unorm(neighbors.z * strengths) + alpha_unorm(neighbors.w * strengths);
                vec4 apply = mode > 0.5 ? vec4(1.0) : vec4(equal(alpha, vec4(0.0)));
                vec4 result = alpha_unorm(alpha - (4.0 * alpha - adjacent) * blend * apply);
                if (group == 0) curve.a += result;
                else if (group == 1) curve.b += result;
                else if (group == 2) curve.c += result;
                else curve.d += result;
            }
        }
    }
    float divisor = float(count.x * count.y);
    curve.a /= divisor; curve.b /= divisor; curve.c /= divisor; curve.d /= divisor;
    coverage /= divisor;
    // The coverage sampler uses a safe scale when rendering below native size.
    if (any(lessThan(scale, vec2(1.0))))
        coverage = sample_scale_average_coverage(scale, output_size, source_size,
            size, softness, sharpening, shape, sharp);
}

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	float blending_mode;
	float adjacent_texel_alpha_blending;
	float integer_mode;
	float video_scale;
    float color_toggle;
    float palette;
    float response_time;
    float brightness_mode;
    float grey_balance;
    float baseline_alpha;
    float alpha_reference_scale;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 FinalViewportSize;
    float pixel_size;
    float fullscreen_match_pixel_size;
    float pixel_softness;
    float sharpening_amount;
    float pixel_shape;
    float sharp_mode;
    float auto_soften;
    float fullscreen_matching;
} global;

  /////////////////////////////////////////////////////////////////////////
 // Vertex shader                                                       //
/////////////////////////////////////////////////////////////////////////

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec4 packed_vTexCoord;
#define vTexCoord packed_vTexCoord.xy
layout(location = 1) out vec4 packed_texel;
#define texel packed_texel.xy
layout(location = 2) out vec4 packed_blur_coords_up;
#define blur_coords_up packed_blur_coords_up.xy
layout(location = 3) out vec4 packed_blur_coords_down;
#define blur_coords_down packed_blur_coords_down.xy
layout(location = 4) out vec4 packed_blur_coords_right;
#define blur_coords_right packed_blur_coords_right.xy
layout(location = 5) out vec4 packed_blur_coords_left;
#define blur_coords_left packed_blur_coords_left.xy
layout(location = 6) out vec4 packed_blur_coords_lower_bound;
#define blur_coords_lower_bound packed_blur_coords_lower_bound.xy
layout(location = 7) out vec4 packed_blur_coords_upper_bound;
#define blur_coords_upper_bound packed_blur_coords_upper_bound.xy
layout(location = 8) out vec4 opacity_curve0;
layout(location = 9) out vec4 opacity_curve1;
layout(location = 10) out vec4 opacity_curve2;
layout(location = 11) out vec4 opacity_curve3;
layout(location = 12) out vec4 reference_opacity0;
layout(location = 13) out vec4 reference_opacity1;
layout(location = 14) out vec4 opacity_context;

void main()
{
    // One correction texel per input cell, at the native attachment size.
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    texel = global.FinalViewportSize.zw;
    blur_coords_down  = vTexCoord + vec2(0.0, texel.y);
    blur_coords_up    = vTexCoord + vec2(0.0, -texel.y);
    blur_coords_right = vTexCoord + vec2(texel.x,  0.0);
    blur_coords_left  = vTexCoord + vec2(-texel.x, 0.0);
    blur_coords_lower_bound = texel * 0.5;
    blur_coords_upper_bound = texel * (global.FinalViewportSize.xy - vec2(0.5));
    opacity_curve0 = opacity_curve1 = opacity_curve2 = opacity_curve3 = vec4(0.0);
    reference_opacity0 = reference_opacity1 = vec4(0.0);
    float integer_scale = registers.integer_mode > 1.5 ? registers.video_scale
        : floor(global.FinalViewportSize.y * registers.OriginalSize.w);
    bool matching_needed = registers.integer_mode > 0.5
        ? abs(integer_scale - registers.alpha_reference_scale) >= 0.0001 && integer_scale >= 3.0
        : !all(lessThan(abs(global.FinalViewportSize.xy * registers.OriginalSize.zw -
            vec2(registers.alpha_reference_scale)), vec2(0.0001)));
    matching_needed = matching_needed &&
        (registers.integer_mode > 0.5 || global.fullscreen_matching > 0.5);
    // Normalization, integer scale, correction needed, and opacity range are frame constants.
    opacity_context = vec4(1.0, integer_scale, matching_needed ? 1.0 : 0.0,
        3.0 / registers.grey_balance + registers.baseline_alpha);
    if (registers.integer_mode > 0.5 && matching_needed) {
        float blend = min(registers.adjacent_texel_alpha_blending, max_adjacent_alpha_blend);
        float reference_coverage = integer_post_blend_coverage(registers.alpha_reference_scale,
            registers.blending_mode, blend);
        float current_coverage = integer_post_blend_coverage(integer_scale, registers.blending_mode, blend);
        opacity_context.x = alpha_normalization_factor(reference_coverage, current_coverage);
    }
    packed_vTexCoord.zw = vec2(0.0);
    packed_texel.zw = vec2(0.0);
    packed_blur_coords_up.zw = vec2(0.0);
    packed_blur_coords_down.zw = vec2(0.0);
    packed_blur_coords_right.zw = vec2(0.0);
    packed_blur_coords_left.zw = vec2(0.0);
    packed_blur_coords_lower_bound.zw = vec2(0.0);
    packed_blur_coords_upper_bound.zw = vec2(0.0);
    // Build fractional-scale correction curves once per frame.
    if (registers.integer_mode < 0.5 && matching_needed) {
        vec2 scale = global.FinalViewportSize.xy * registers.OriginalSize.zw;
        float size = get_effective_pixel_size(scale, global.pixel_size, global.fullscreen_match_pixel_size);
        float softness = get_effective_pixel_softness(scale, global.pixel_softness, global.auto_soften);
        float range = 3.0 / registers.grey_balance + registers.baseline_alpha;
        vec2 reference = vec2(registers.alpha_reference_scale);
        float reference_size = get_effective_pixel_size(reference, global.pixel_size, global.fullscreen_match_pixel_size);
        float reference_softness = get_effective_pixel_softness(reference, global.pixel_softness, global.auto_soften);
        float hard_reference = integer_post_blend_coverage(registers.alpha_reference_scale,
            registers.blending_mode, registers.adjacent_texel_alpha_blending);
        AlphaCurve reference_curve; float coverage; float peak;
        build_alpha_curve(reference, registers.OriginalSize.xy * reference, registers.OriginalSize.xy,
            reference_size, reference_softness, global.sharpening_amount, global.pixel_shape, global.sharp_mode,
            registers.blending_mode, registers.adjacent_texel_alpha_blending, range, hard_reference,
            reference_curve, peak, coverage);
        float normalization = alpha_normalization_factor(hard_reference, coverage);
        AlphaCurve current; float current_coverage;
        build_alpha_curve(scale, global.FinalViewportSize.xy, registers.OriginalSize.xy,
            size, softness, global.sharpening_amount, global.pixel_shape, global.sharp_mode,
            registers.blending_mode, registers.adjacent_texel_alpha_blending,
            range, hard_reference, current, peak, current_coverage);
        opacity_curve0 = current.a; opacity_curve1 = current.b;
        opacity_curve2 = current.c; opacity_curve3 = current.d;
        packed_vTexCoord.zw = current.x0.xy;
        packed_texel.zw = current.x0.zw;
        packed_blur_coords_up.zw = current.x1.xy;
        packed_blur_coords_down.zw = current.x1.zw;
        packed_blur_coords_right.zw = current.x2.xy;
        packed_blur_coords_left.zw = current.x2.zw;
        packed_blur_coords_lower_bound.zw = current.x3.xy;
        packed_blur_coords_upper_bound.zw = current.x3.zw;
        float current_reference = integer_post_blend_coverage(registers.alpha_reference_scale,
            registers.blending_mode, registers.adjacent_texel_alpha_blending);
        opacity_context.x = alpha_normalization_factor(current_reference, current_coverage);
        for (int i = 0; i < 8; i++) {
            float value = alpha_curve_mean(reference_curve, range * float(i) / 7.0 * normalization);
            if (i < 4) reference_opacity0[i] = value;
            else reference_opacity1[i - 4] = value;
        }
    }
}

  /////////////////////////////////////////////////////////////////////////
 // Fragment shader                                                     //
/////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec4 packed_vTexCoord;
#define vTexCoord packed_vTexCoord.xy
layout(location = 1) in vec4 packed_texel;
#define texel packed_texel.xy
layout(location = 2) in vec4 packed_blur_coords_up;
#define blur_coords_up packed_blur_coords_up.xy
layout(location = 3) in vec4 packed_blur_coords_down;
#define blur_coords_down packed_blur_coords_down.xy
layout(location = 4) in vec4 packed_blur_coords_right;
#define blur_coords_right packed_blur_coords_right.xy
layout(location = 5) in vec4 packed_blur_coords_left;
#define blur_coords_left packed_blur_coords_left.xy
layout(location = 6) in vec4 packed_blur_coords_lower_bound;
#define blur_coords_lower_bound packed_blur_coords_lower_bound.xy
layout(location = 7) in vec4 packed_blur_coords_upper_bound;
#define blur_coords_upper_bound packed_blur_coords_upper_bound.xy
layout(location = 8) in vec4 opacity_curve0;
layout(location = 9) in vec4 opacity_curve1;
layout(location = 10) in vec4 opacity_curve2;
layout(location = 11) in vec4 opacity_curve3;
layout(location = 12) in vec4 reference_opacity0;
layout(location = 13) in vec4 reference_opacity1;
layout(location = 14) in vec4 opacity_context;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D COLOR_PALETTE;

float base_opacity(vec4 cell_data) {
    if (registers.color_toggle == 0.0)
        return cell_data.g / 65535.0 * opacity_context.w;
    return cell_data.b;
}

  /////////////////////////////////////////////////////////////////////////
 // Fragment definitions                                                //
/////////////////////////////////////////////////////////////////////////

void main() {
    // R stores a lossless coefficient: zero = identity, positive = lift,
    // negative = scale, and -2 = scale to zero. GBA stores palette RGB.
    vec4 result = vec4(0.0, registers.color_toggle == 0.0
        ? gameboy_foreground_color(registers.palette, COLOR_PALETTE) : vec3(0.0));
    vec2 cell_index = floor(vTexCoord * registers.OutputSize.xy);
    if (any(greaterThanEqual(cell_index, registers.OriginalSize.xy))) {
        FragColor = result;
        return;
    }
    if (opacity_context.z > 0.5) {
        float scale = opacity_context.y;
        vec2 cell_center = (cell_index + 0.5) * registers.OriginalSize.zw;
        vec2 matching_coord = cell_center;
        // Preserve the dot pass's nearest-pixel sample when shrinking the input.
        // History-based color correction already reads the native cell directly.
        if (registers.integer_mode < 0.5 &&
            any(lessThan(global.FinalViewportSize.xy, registers.OriginalSize.xy)) &&
            (registers.color_toggle == 0.0 || registers.response_time <= 0.0)) {
            matching_coord = (floor(cell_center * global.FinalViewportSize.xy) + 0.5)
                * global.FinalViewportSize.zw;
        }
        float base = base_opacity(texture(Source, matching_coord));
        float blend_amount = min(registers.adjacent_texel_alpha_blending, max_adjacent_alpha_blend);
        float current_mean; float reference_mean;
            if (registers.integer_mode > 0.5) {
                float normalization = opacity_context.x;
                current_mean = integer_clipped_alpha_mean(base * normalization, scale, registers.blending_mode, blend_amount);
                reference_mean = integer_clipped_alpha_mean(base, registers.alpha_reference_scale, registers.blending_mode, blend_amount);
            } else {
                float normalization = opacity_context.x;
                float range = opacity_context.w;
                AlphaCurve curve = AlphaCurve(opacity_curve0, opacity_curve1, opacity_curve2, opacity_curve3,
                    vec4(packed_vTexCoord.zw, packed_texel.zw),
                    vec4(packed_blur_coords_up.zw, packed_blur_coords_down.zw),
                    vec4(packed_blur_coords_right.zw, packed_blur_coords_left.zw),
                    vec4(packed_blur_coords_lower_bound.zw, packed_blur_coords_upper_bound.zw));
                float strength = base * normalization;
                current_mean = alpha_curve_mean(curve, strength);
                if (registers.grey_balance < 3.0 || range > 1.1001 || global.pixel_shape < 1.0) {
                    // Wider opacity ranges saturate most dots, and rounded dots differ from
                    // integer squares; the fullscreen dot model drifts from integer dots in
                    // both cases, so match the integer dots directly.
                    reference_mean = integer_clipped_alpha_mean(base, registers.alpha_reference_scale,
                        registers.blending_mode, blend_amount);
                } else {
                    float phase = clamp(base / range * 7.0, 0.0, 7.0);
                    int left = min(int(floor(phase)), 6); int right = left + 1;
                    float low = left < 4 ? reference_opacity0[left] : reference_opacity1[left - 4];
                    float high = right < 4 ? reference_opacity0[right] : reference_opacity1[right - 4];
                    reference_mean = mix(low, high, phase - float(left));
                }
            }
        if (abs(reference_mean - current_mean) > 0.5 / 255.0) {
            if (reference_mean > current_mean) {
                float lift = clamp((reference_mean - current_mean) / max(1.0 - current_mean, 0.000001), 0.0, 1.0);
                result.r = lift;
            } else {
                float factor = clamp(reference_mean / max(current_mean, 0.000001), 0.0, 1.0);
                result.r = factor == 0.0 ? -2.0 : -factor;
            }
        }
    }
    FragColor = result;
}
