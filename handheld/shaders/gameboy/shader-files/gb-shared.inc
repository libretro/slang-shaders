// GAME BOY DOT MATRIX SHADER v1.4 - Shared Helpers

  /////////////////////////////////////////////////////////////////////////
 // Fullscreen pixel sizing and adaptive softness                      //
/////////////////////////////////////////////////////////////////////////

// Match fullscreen dots to the one-output-pixel gaps used by integer modes.
float get_effective_pixel_size(vec2 tx_to_px, float pixel_size,
                               float auto_size) {
    float fullscreen_scale = max(min(tx_to_px.x, tx_to_px.y), 1.0);
    float auto_pixel_size = clamp(
        1.0 - 1.0 / fullscreen_scale, 0.2, 1.10
    );
    return mix(pixel_size, auto_pixel_size, step(0.5, min(auto_size, 1.0)));
}

float hard_dot_mask(vec2 cell_index, vec2 cell_frac, vec2 scale) {
    vec2 gap = 1.0 / max(scale, vec2(1.0));
    vec2 edge_cell = 1.0 - step(vec2(0.5), cell_index);
    gap = mix(gap, vec2(0.0), edge_cell);
    return (cell_frac.x > gap.x && cell_frac.y > gap.y) ? 1.0 : 0.0;
}

// Add softness as either output axis moves away from an integer scale.
float get_effective_pixel_softness(vec2 tx_to_px, float pixel_softness,
                                   float auto_soften) {
    float effective_softness = pixel_softness;
    if (auto_soften > 0.5) {
        vec2 fract_scale = fract(tx_to_px);
        float fract_factor = max(
            0.5 - abs(fract_scale.x - 0.5),
            0.5 - abs(fract_scale.y - 0.5)
        );
        effective_softness += fract_factor * 4.0;
    }
    return effective_softness;
}

  /////////////////////////////////////////////////////////////////////////
 // Geometric coverage primitives                                      //
/////////////////////////////////////////////////////////////////////////

// Return the overlap length between two one-dimensional line segments.
float intersect_line_segment(float pixel_start, float pixel_end,
                             float dot_start, float dot_end) {
    float overlap_start = max(pixel_start, dot_start);
    float overlap_end = min(pixel_end, dot_end);
    return max(overlap_end - overlap_start, 0.0);
}

// Return the overlap area between two axis-aligned rectangles.
float intersect_rect_area(vec4 px_square, vec4 rect) {
    const vec2 bl = max(px_square.xy, rect.xy);
    const vec2 tr = min(px_square.zw, rect.zw);
    const vec2 coverage = max(tr - bl, vec2(0.0));
    return coverage.x * coverage.y;
}

  /////////////////////////////////////////////////////////////////////////
 // Antialiased dot coverage                                            //
/////////////////////////////////////////////////////////////////////////

// Calculate one output sample's coverage for the selected dot shape.
float calculate_coverage_at_point(vec2 tx_coord_f, float pixel_size,
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

  /////////////////////////////////////////////////////////////////////////
 // Fractional-scale phase sampling                                    //
/////////////////////////////////////////////////////////////////////////

// Support exact phase-cycle counts for rational source/output scales.
int greatest_common_divisor(int a, int b) {
    for (int i = 0; i < 32; i++) {
        if (b == 0) break;
        int remainder = a % b;
        a = b;
        b = remainder;
    }
    return max(a, 1);
}

// Average AA coverage across every unique output phase when practical.
float sample_scale_average_coverage(vec2 tx_to_px, vec2 output_size,
                                    vec2 source_size, float pixel_size,
                                    float pixel_softness, float sharpening_amount,
                                    float pixel_shape, float sharp_mode) {
    float total = 0.0;
    const int max_samples = 32;
    vec2 safe_scale = max(tx_to_px, vec2(1.0));
    ivec2 output_pixels = max(ivec2(round(output_size)), ivec2(1));
    ivec2 source_pixels = max(ivec2(round(source_size)), ivec2(1));
    ivec2 phase_count = ivec2(
        output_pixels.x / greatest_common_divisor(output_pixels.x, source_pixels.x),
        output_pixels.y / greatest_common_divisor(output_pixels.y, source_pixels.y)
    );
    bvec2 exact_phase_cycle = lessThanEqual(phase_count, ivec2(max_samples));
    ivec2 sample_count = ivec2(
        exact_phase_cycle.x ? phase_count.x : max_samples,
        exact_phase_cycle.y ? phase_count.y : max_samples
    );
    vec2 sample_denominator = vec2(
        exact_phase_cycle.x ? safe_scale.x : float(max_samples),
        exact_phase_cycle.y ? safe_scale.y : float(max_samples)
    );

    for (int y = 0; y < max_samples; y++) {
        if (y >= sample_count.y) break;
        for (int x = 0; x < max_samples; x++) {
            if (x >= sample_count.x) break;
            vec2 sample_pos = fract(
                (vec2(float(x), float(y)) + vec2(0.5)) /
                sample_denominator
            );
            total += calculate_coverage_at_point(sample_pos, pixel_size,
                                                 pixel_softness, sharpening_amount,
                                                 pixel_shape, sharp_mode);
        }
    }
    return total / float(sample_count.x * sample_count.y);
}

  /////////////////////////////////////////////////////////////////////////
 // Integer and post-blend coverage                                    //
/////////////////////////////////////////////////////////////////////////

// Integer dots use an (N-1) x (N-1) lit area inside each N x N cell.
float integer_dot_coverage(float scale) {
    float safe_scale = max(scale, 1.0);
    float lit_pixels = max(safe_scale - 1.0, 0.0);
    return (lit_pixels * lit_pixels) / (safe_scale * safe_scale);
}

float integer_rect_post_blend_coverage(vec2 scale, float blending_mode,
                                       float blend_amount) {
    vec2 safe_scale = max(scale, vec2(1.0));
    float safe_blend_amount = min(blend_amount, max_adjacent_alpha_blend);
    vec2 lit_pixels = max(safe_scale - vec2(1.0), vec2(0.0));
    float hard_coverage = (lit_pixels.x * lit_pixels.y) /
                          (safe_scale.x * safe_scale.y);
    float gap_blend_coverage =
        2.0 * safe_blend_amount * (lit_pixels.x + lit_pixels.y) /
        (safe_scale.x * safe_scale.y);
    float blend_gaps_only = 1.0 - step(0.5, blending_mode);
    return hard_coverage + gap_blend_coverage * blend_gaps_only;
}

// Include the alpha that Blend Gaps adds around the hard integer mask.
float integer_post_blend_coverage(float scale, float blending_mode,
                                  float blend_amount) {
    vec2 safe_scale = vec2(max(scale, 1.0));
    return integer_rect_post_blend_coverage(safe_scale, blending_mode,
                                            blend_amount);
}

// Match alpha coverage without allowing unstable amplification.
float alpha_normalization_factor(float reference_coverage,
                                 float current_coverage) {
    return clamp(reference_coverage / max(current_coverage, 0.001),
                 0.0, 4.0);
}

// Foreground palette shared by dot generation and opacity-data restoration.
vec3 gameboy_foreground_color(float palette, sampler2D color_palette) {
    if (palette < 0.5) {
        return texture(color_palette, vec2(0.75, 0.5)).rgb; // 0: Original texture
    } else if (palette < 1.5) {
        return vec3(0.067, 0.098, 0.133); // 1: #111922
    } else if (palette < 2.5) {
        return vec3(0.125, 0.125, 0.125); // 2: #202020
    } else if (palette < 3.5) {
        return vec3(0.0, 0.0, 0.0); // 3: #000000
    } else if (palette < 4.5) {
        return vec3(0.114, 0.416, 0.420); // 4: #1D6A6B
    } else if (palette < 5.5) {
        return vec3(0.0, 0.325, 0.200); // 5: #005333
    } else if (palette < 6.5) {
        return vec3(0.0, 0.325, 0.314); // 6: #005350
    } else {
        return vec3(29.0, 106.0, 107.0) / 255.0; // 7: #1D6A6B
    }
}