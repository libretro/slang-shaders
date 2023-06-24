// See compose.slang for copyright and other information.

// Scaling from unit output to pixel input space.
vec2 scale_o2i() {
    // Pixels in input coord. space, after cropping.
    const vec2 eff_input_res =
        param.InputSize.xy -
        (param.CENTER_CROP > 0.5
             ? vec2(param.OS_CROP_LEFT + param.OS_CROP_RIGHT,
                    param.OS_CROP_TOP + param.OS_CROP_BOTTOM)
             : 2 * vec2(min(param.OS_CROP_LEFT, param.OS_CROP_RIGHT),
                        min(param.OS_CROP_TOP, param.OS_CROP_BOTTOM)));
    // Integer aspect ratio after cropping.
    // lambda_1 * input_pixels.x, lambda_2 * input_pixels.y,
    // possibly corrected for forced aspect ratio
    const vec2 eff_aspect =
        param.InputSize.yx *
        (param.FORCE_ASPECT_RATIO < 0.5
             ? param.FinalViewportSize.xy
             : (param.ASPECT_H < 0.5 || param.ASPECT_V < 0.5
                    ? param.InputSize.xy
                    : vec2(param.ASPECT_H, param.ASPECT_V)));
    float scale_x, scale_y;
    if (param.FinalViewportSize.x * eff_input_res.y * eff_aspect.y <
        param.FinalViewportSize.y * eff_input_res.x * eff_aspect.x) {
        // Scale will be limited by width. Calc x scale, then derive y scale
        // using aspect ratio.
        scale_x = param.FinalViewportSize.x / eff_input_res.x;
        if (param.FORCE_INTEGER_SCALING > 0.5) {
            scale_x = max(1.0, floor(scale_x));
        }
        scale_y = scale_x * eff_aspect.y / eff_aspect.x;
        if (param.FORCE_INTEGER_SCALING > 0.5) {
            scale_y = max(1.0, floor(scale_y));
        }
    } else {
        // Scale will be limited by height.
        scale_y = param.FinalViewportSize.y / eff_input_res.y;
        if (param.FORCE_INTEGER_SCALING > 0.5) {
            scale_y = max(1.0, floor(scale_y));
        }
        scale_x = scale_y * eff_aspect.x / eff_aspect.y;
        if (param.FORCE_INTEGER_SCALING > 0.5) {
            scale_x = max(1.0, floor(scale_x));
        }
    }
    return param.FinalViewportSize.xy / vec2(scale_x, scale_y);
}

// Get adjusted center in input pixel coordinate system.
// Round to whole pixels to avoid issues on low-res output resolutions, e.g.,
// when using a 10x by 1x horizontal superresolution.
vec2 get_input_center() {
    return floor(param.CENTER_CROP > 0.5
                     ? 0.5 * vec2(param.OS_CROP_LEFT + param.InputSize.x -
                                      param.OS_CROP_RIGHT,
                                  param.OS_CROP_TOP + param.InputSize.y -
                                      param.OS_CROP_BOTTOM)
                     : vec2(0.49999) * param.InputSize.xy);
}

// From unit output to pixel input space.
// coord_in_input_space = o2i(coord_in_output_space)
// This is used to sample from the input texture in the output pass.
vec2 o2i(vec2 x) { return (x - 0.49999) * scale_o2i() + get_input_center(); }

// From pixel input to unit output space.
vec2 i2o(vec2 x) { return (x - get_input_center()) / scale_o2i() + 0.49999; }
