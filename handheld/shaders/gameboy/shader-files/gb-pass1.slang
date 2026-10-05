#version 450

#pragma name GameBoyDotMatrixAlphaBlend

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.4                          //
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
 // gb-pass1 - Alpha blending for adjacent pixels                       //
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
    for (int i = 1; i < 16; i++) {
        float right = alpha_curve_strength(c, i);
        if (strength <= right) {
            float left = alpha_curve_strength(c, i - 1);
            return mix(alpha_curve_value(c, i - 1), alpha_curve_value(c, i),
                clamp((strength - left) / max(right - left, 0.000001), 0.0, 1.0));
        }
    }
    return c.d.w;
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

void build_alpha_curve(vec2 scale, vec2 output_size, vec2 source_size,
    float size, float softness, float sharpening, float shape, float sharp,
    float mode, float amount, out AlphaCurve curve, out float peak) {
    curve = AlphaCurve(vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0));
    peak = 0.0;
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
            float mask = calculate_coverage_at_point(phase, size, softness, sharpening, shape, sharp);
            peak = max(peak, mask);
            if (mask <= 0.0) continue;
            float threshold = 1.0 / mask;
            last_threshold = max(last_threshold, threshold);
            bool duplicate = false;
            for (int i = 1; i < 15; i++)
                duplicate = duplicate || abs(knots[i] - threshold) < 0.00001;
            if (duplicate) continue;
            for (int i = 1; i < 15; i++) {
                if (threshold < knots[i]) {
                    for (int j = 14; j > i; j--) knots[j] = knots[j - 1];
                    knots[i] = threshold;
                    break;
                }
            }
        }
    }
    for (int i = 1; i < 16; i++) knots[i] = min(knots[i], last_threshold);
    curve.x0 = vec4(knots[0], knots[1], knots[2], knots[3]);
    curve.x1 = vec4(knots[4], knots[5], knots[6], knots[7]);
    curve.x2 = vec4(knots[8], knots[9], knots[10], knots[11]);
    curve.x3 = vec4(knots[12], knots[13], knots[14], knots[15]);
    for (int y = 0; y < 32; y++) {
        if (y >= count.y) break;
        for (int x = 0; x < 32; x++) {
            if (x >= count.x) break;
            vec2 phase = fract((vec2(x, y) + 0.5) / denominator);
            float center = calculate_coverage_at_point(phase, size, softness, sharpening, shape, sharp);
            peak = max(peak, center);
            vec4 neighbors;
            neighbors.x = calculate_coverage_at_point(fract(phase + vec2(1.0 / scale.x, 0.0)), size, softness, sharpening, shape, sharp);
            neighbors.y = calculate_coverage_at_point(fract(phase - vec2(1.0 / scale.x, 0.0)), size, softness, sharpening, shape, sharp);
            neighbors.z = calculate_coverage_at_point(fract(phase + vec2(0.0, 1.0 / scale.y)), size, softness, sharpening, shape, sharp);
            neighbors.w = calculate_coverage_at_point(fract(phase - vec2(0.0, 1.0 / scale.y)), size, softness, sharpening, shape, sharp);
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
}

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
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
    float pixel_size;
    float fullscreen_match_pixel_size;
    float pixel_softness;
    float sharpening_amount;
    float pixel_shape;
    float sharp_mode;
    float auto_soften;
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
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord * 1.0001;

    texel = registers.SourceSize.zw;
    blur_coords_down  = vTexCoord + vec2(0.0, texel.y);
    blur_coords_up    = vTexCoord + vec2(0.0, -texel.y);
    blur_coords_right = vTexCoord + vec2(texel.x,  0.0);
    blur_coords_left  = vTexCoord + vec2(-texel.x, 0.0);
    blur_coords_lower_bound = texel * 0.5;
    blur_coords_upper_bound = texel * (registers.SourceSize.xy - vec2(0.5));
    opacity_curve0 = opacity_curve1 = opacity_curve2 = opacity_curve3 = vec4(0.0);
    reference_opacity0 = reference_opacity1 = vec4(0.0);
    opacity_context = vec4(0.0);
    packed_vTexCoord.zw = vec2(0.0);
    packed_texel.zw = vec2(0.0);
    packed_blur_coords_up.zw = vec2(0.0);
    packed_blur_coords_down.zw = vec2(0.0);
    packed_blur_coords_right.zw = vec2(0.0);
    packed_blur_coords_left.zw = vec2(0.0);
    packed_blur_coords_lower_bound.zw = vec2(0.0);
    packed_blur_coords_upper_bound.zw = vec2(0.0);
    if (registers.integer_mode < 0.5) {
        vec2 scale = registers.SourceSize.xy * registers.OriginalSize.zw;
        float size = get_effective_pixel_size(scale, global.pixel_size, global.fullscreen_match_pixel_size);
        float softness = get_effective_pixel_softness(scale, global.pixel_softness, global.auto_soften);
        float range = 3.0 / registers.grey_balance + registers.baseline_alpha;
        AlphaCurve current; float peak;
        build_alpha_curve(scale, registers.SourceSize.xy, registers.OriginalSize.xy,
            size, softness, global.sharpening_amount, global.pixel_shape, global.sharp_mode,
            registers.blending_mode, registers.adjacent_texel_alpha_blending, current, peak);
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
        float current_coverage = sample_scale_average_coverage(scale, registers.SourceSize.xy,
            registers.OriginalSize.xy, size, softness, global.sharpening_amount, global.pixel_shape, global.sharp_mode);
        float current_reference = integer_post_blend_coverage(registers.alpha_reference_scale,
            registers.blending_mode, registers.adjacent_texel_alpha_blending);
        opacity_context = vec4(alpha_normalization_factor(current_reference, current_coverage), current_reference, peak, range);
        vec2 reference = vec2(registers.alpha_reference_scale);
        float reference_size = get_effective_pixel_size(reference, global.pixel_size, global.fullscreen_match_pixel_size);
        float reference_softness = get_effective_pixel_softness(reference, global.pixel_softness, global.auto_soften);
        AlphaCurve reference_curve;
        build_alpha_curve(reference, registers.OriginalSize.xy * reference, registers.OriginalSize.xy,
            reference_size, reference_softness, global.sharpening_amount, global.pixel_shape, global.sharp_mode,
            registers.blending_mode, registers.adjacent_texel_alpha_blending, reference_curve, peak);
        float coverage = sample_scale_average_coverage(reference, registers.OriginalSize.xy * reference,
            registers.OriginalSize.xy, reference_size, reference_softness, global.sharpening_amount,
            global.pixel_shape, global.sharp_mode);
        float hard_reference = integer_post_blend_coverage(registers.alpha_reference_scale,
            registers.blending_mode, registers.adjacent_texel_alpha_blending);
        float normalization = alpha_normalization_factor(hard_reference, coverage);
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
layout(set = 0, binding = 4) uniform sampler2D OriginalHistory1;
layout(set = 0, binding = 5) uniform sampler2D OriginalHistory2;
layout(set = 0, binding = 6) uniform sampler2D OriginalHistory3;
layout(set = 0, binding = 7) uniform sampler2D OriginalHistory4;
layout(set = 0, binding = 8) uniform sampler2D OriginalHistory5;
layout(set = 0, binding = 9) uniform sampler2D OriginalHistory6;
layout(set = 0, binding = 10) uniform sampler2D OriginalHistory7;

float base_opacity(vec4 source, vec2 core_coord) {
    float range = 3.0 / registers.grey_balance + registers.baseline_alpha;
    if (registers.color_toggle == 0.0) {
        vec2 bytes = round(source.rg * 255.0);
        return (bytes.x * 256.0 + bytes.y) / 65535.0 * range;
    }
    vec3 rgb = abs(1.0 - source.rgb);
    if (registers.response_time > 0.0) {
        rgb += (abs(1.0 - texture(OriginalHistory1, core_coord).rgb) - rgb) * registers.response_time;
        rgb += (abs(1.0 - texture(OriginalHistory2, core_coord).rgb) - rgb) * pow(registers.response_time, 2.0);
        rgb += (abs(1.0 - texture(OriginalHistory3, core_coord).rgb) - rgb) * pow(registers.response_time, 3.0);
        rgb += (abs(1.0 - texture(OriginalHistory4, core_coord).rgb) - rgb) * pow(registers.response_time, 4.0);
        rgb += (abs(1.0 - texture(OriginalHistory5, core_coord).rgb) - rgb) * pow(registers.response_time, 5.0);
        rgb += (abs(1.0 - texture(OriginalHistory6, core_coord).rgb) - rgb) * pow(registers.response_time, 6.0);
        rgb += (abs(1.0 - texture(OriginalHistory7, core_coord).rgb) - rgb) * pow(registers.response_time, 7.0);
    }
    float brightness = registers.brightness_mode < 0.5 ? rgb.r + rgb.g + rgb.b
        : 3.0 * dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    return brightness / registers.grey_balance + registers.baseline_alpha;
}

  /////////////////////////////////////////////////////////////////////////
 // Fragment definitions                                                //
/////////////////////////////////////////////////////////////////////////

float blending_modifier(float color){
	float blend_bool = (color == 0.0) ? 1 : 0;
	return clamp(blend_bool + registers.blending_mode, 0.0, 1.0);
}

void main()
{
    // Blend neighboring alpha values to soften harsh transitions.
    // Blend Gaps affects zero-alpha gaps; Blend All affects every pixel.

    // Sample the input texture
    vec4 out_color = texture(Source, vTexCoord).rgba;

    // Clamp the blur coords to the input texture size so it doesn't attempt to sample off the texture (it'll retrieve float4(0.0) and darken the edges otherwise)
    vec2 blur_coords_up_clamped    = clamp(blur_coords_up, blur_coords_lower_bound, blur_coords_upper_bound);
    vec2 blur_coords_down_clamped  = clamp(blur_coords_down, blur_coords_lower_bound, blur_coords_upper_bound);
    vec2 blur_coords_right_clamped = clamp(blur_coords_right, blur_coords_lower_bound, blur_coords_upper_bound);
    vec2 blur_coords_left_clamped  = clamp(blur_coords_left, blur_coords_lower_bound, blur_coords_upper_bound);

    // Sample adjacent texels based on the coordinates above
    vec4 adjacent_texel_1 = texture(Source, blur_coords_up_clamped).rgba;
    vec4 adjacent_texel_2 = texture(Source, blur_coords_down_clamped).rgba;
    vec4 adjacent_texel_3 = texture(Source, blur_coords_right_clamped).rgba;
    vec4 adjacent_texel_4 = texture(Source, blur_coords_left_clamped).rgba;
    float blend_amount = min(registers.adjacent_texel_alpha_blending,
                             max_adjacent_alpha_blend);

    // Sum the alpha differences between neighboring texels, apply modifiers, then subtract the result from the current fragment alpha value
    out_color.a -=
    (
        (out_color.a - adjacent_texel_1.a) +
        (out_color.a - adjacent_texel_2.a) +
        (out_color.a - adjacent_texel_3.a) +
        (out_color.a - adjacent_texel_4.a)
    ) * blend_amount * blending_modifier(out_color.a);

    float scale = registers.integer_mode > 1.5 ? registers.video_scale
        : floor(registers.SourceSize.y * registers.OriginalSize.w);
    vec2 bounds = registers.integer_mode > 0.5
        ? registers.OriginalSize.xy * scale * registers.SourceSize.zw : vec2(1.0);
    vec2 core_coord = (vTexCoord - 0.5) / bounds + 0.5;
    bool inside = all(greaterThanEqual(core_coord, vec2(0.0))) && all(lessThan(core_coord, vec2(1.0)));
    if (inside) {
        vec2 cell_center = (floor(core_coord * registers.OriginalSize.xy) + 0.5) * registers.OriginalSize.zw;
        vec2 center_coord = (cell_center - 0.5) * bounds + 0.5;
        float base = base_opacity(texture(Source, center_coord), cell_center);
        float current_mean; float reference_mean;
        bool at_reference;
        if (registers.integer_mode > 0.5) {
            float reference_coverage = integer_post_blend_coverage(registers.alpha_reference_scale,
                registers.blending_mode, blend_amount);
            float current_coverage = integer_post_blend_coverage(scale, registers.blending_mode, blend_amount);
            float normalization = alpha_normalization_factor(reference_coverage, current_coverage);
            current_mean = integer_clipped_alpha_mean(base * normalization, scale, registers.blending_mode, blend_amount);
            reference_mean = integer_clipped_alpha_mean(base, registers.alpha_reference_scale, registers.blending_mode, blend_amount);
            at_reference = abs(scale - registers.alpha_reference_scale) < 0.0001 || scale < 3.0;
        } else {
            vec2 current_scale = registers.SourceSize.xy * registers.OriginalSize.zw;
            float normalization = opacity_context.x;
            float range = opacity_context.w;
            AlphaCurve curve = AlphaCurve(opacity_curve0, opacity_curve1, opacity_curve2, opacity_curve3,
                vec4(packed_vTexCoord.zw, packed_texel.zw),
                vec4(packed_blur_coords_up.zw, packed_blur_coords_down.zw),
                vec4(packed_blur_coords_right.zw, packed_blur_coords_left.zw),
                vec4(packed_blur_coords_lower_bound.zw, packed_blur_coords_upper_bound.zw));
            float strength = base * normalization;
            current_mean = alpha_curve_mean(curve, strength);
            float phase = clamp(base / range * 7.0, 0.0, 7.0);
            int left = min(int(floor(phase)), 6); int right = left + 1;
            float low = left < 4 ? reference_opacity0[left] : reference_opacity1[left - 4];
            float high = right < 4 ? reference_opacity0[right] : reference_opacity1[right - 4];
            reference_mean = mix(low, high, phase - float(left));
            at_reference = all(lessThan(abs(current_scale - vec2(registers.alpha_reference_scale)), vec2(0.0001)));
        }
        if (!at_reference && abs(reference_mean - current_mean) > 0.5 / 255.0) {
            if (reference_mean > current_mean) {
                float lift = clamp((reference_mean - current_mean) / max(1.0 - current_mean, 0.000001), 0.0, 1.0);
                out_color.a += lift * (1.0 - out_color.a);
            } else {
                out_color.a *= clamp(reference_mean / max(current_mean, 0.000001), 0.0, 1.0);
            }
        }
        if (registers.color_toggle == 0.0)
            out_color.rgb = gameboy_foreground_color(registers.palette, COLOR_PALETTE);
    } else if (registers.color_toggle == 0.0) {
        out_color.rgb = vec3(0.0);
    }
    FragColor = out_color;
}