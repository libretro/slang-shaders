// See compose.slang for copyright and other information.

// Pixels in input coord. space, after cropping
ivec2 eff_input_res() {
    if (param.CENTER_CROP > 0.5) {
        return ivec2(param.InputSize.xy) -
               ivec2(param.OS_CROP_LEFT + param.OS_CROP_RIGHT,
                     param.OS_CROP_TOP + param.OS_CROP_BOTTOM);
    }
    return ivec2(param.InputSize.xy) -
           2 * ivec2(min(param.OS_CROP_LEFT, param.OS_CROP_RIGHT),
                     min(param.OS_CROP_TOP, param.OS_CROP_BOTTOM));
}

// integer aspect ratio after crop
// lambda_1 * input_pixels.x, lambda_2 * input_pixels.y,
// possibly corrected for forced aspect ratio
ivec2 eff_aspect() {
    const ivec2 eff_input_res = eff_input_res();
    if (param.FORCE_ASPECT_RATIO < 0.5) {
        return eff_input_res;
    }
    return ivec2(eff_input_res.x * param.InputSize.y * param.ASPECT_H,
                 eff_input_res.y * param.InputSize.x * param.ASPECT_V);
}

ivec2 wideness_vs_tallness() {
    const ivec2 eff_aspect = eff_aspect();
    return ivec2(param.FinalViewportSize.x * eff_aspect.y,
                 param.FinalViewportSize.y * eff_aspect.x);
}

vec2 debug_scale() {
    const ivec2 eff_input_res = eff_input_res();
    const ivec2 eff_aspect = eff_aspect();
    float scale_x, scale_y;
    if (param.FinalViewportSize.x * eff_aspect.y <
        param.FinalViewportSize.y * eff_aspect.x) {
        // Scale will be limited by width. Calc x scale, then derive y scale
        // using aspect ratio.
        scale_x = param.FinalViewportSize.x / eff_input_res.x;
        if (param.FORCE_ASPECT_RATIO < 0.5) {
            scale_y = scale_x;
        } else {
            scale_y = scale_x * param.ASPECT_V / param.ASPECT_H;
        }
    } else {
        // Scale will be limited by height.
        scale_y = param.FinalViewportSize.y / eff_input_res.y;
        if (param.FORCE_ASPECT_RATIO < 0.5) {
            scale_x = scale_y;
        } else {
            scale_x = scale_y * param.ASPECT_H / param.ASPECT_V;
        }
    }
    if (param.FORCE_INTEGER_SCALING > 0.5) {
        scale_x = max(1.0, floor(scale_x));
        scale_y = max(1.0, floor(scale_y));
    }
    return vec2(scale_x, scale_y);
}

// Output to input scaling, in unit coordinate systems.
vec2 scale_o2i() {
    const ivec2 eff_input_res = eff_input_res();
    const ivec2 eff_aspect = eff_aspect();
    float scale_x, scale_y;
    if (param.FinalViewportSize.x * eff_aspect.y <
        param.FinalViewportSize.y * eff_aspect.x) {
        // Scale will be limited by width. Calc x scale, then derive y scale
        // using aspect ratio.
        scale_x = param.FinalViewportSize.x / eff_input_res.x;
        if (param.FORCE_ASPECT_RATIO < 0.5) {
            scale_y = scale_x;
        } else {
            scale_y = scale_x * param.ASPECT_V / param.ASPECT_H;
        }
    } else {
        // Scale will be limited by height.
        scale_y = param.FinalViewportSize.y / eff_input_res.y;
        if (param.FORCE_ASPECT_RATIO < 0.5) {
            scale_x = scale_y;
        } else {
            scale_x = scale_y * param.ASPECT_H / param.ASPECT_V;
        }
    }
    if (param.FORCE_INTEGER_SCALING > 0.5) {
        scale_x = max(1.0, floor(scale_x));
        scale_y = max(1.0, floor(scale_y));
    }
    return param.FinalViewportSize.xy * param.InputSize.zw /
           vec2(scale_x, scale_y);
}

// Input to output scaling, in unit coordinate systems.
vec2 scale_i2o() { return 1.0 / scale_o2i(); }

// Get adjusted center in input unit coordinate system.
vec2 get_input_center() {
    return param.CENTER_CROP > 0.5
               ? 0.5 * param.InputSize.zw *
                     vec2(param.OS_CROP_LEFT + param.InputSize.x -
                              param.OS_CROP_RIGHT,
                          param.OS_CROP_TOP + param.InputSize.y -
                              param.OS_CROP_BOTTOM)
               : vec2(0.49999);
}

// In unit space (output to input).
// coord_in_input_space = o2i(coord_in_output_space)
// This is used to sample from the input texture in the output pass.
vec2 o2i(vec2 x) { return (x - 0.49999) * scale_o2i() + get_input_center(); }

// In unit coordinate systems.
vec2 i2o(vec2 x) { return (x - get_input_center()) * scale_i2o() + 0.49999; }
