#include "parameters.slang"

// Pixels in input coord. space
vec2 eff_input_res() {
    if (param.CENTER_CROP > 0.5) {
        return param.InputSize.xy -
               vec2(param.OS_CROP_LEFT + param.OS_CROP_RIGHT,
                    param.OS_CROP_TOP + param.OS_CROP_BOTTOM);
    }
    return param.InputSize.xy -
           2.0 * vec2(min(param.OS_CROP_LEFT, param.OS_CROP_RIGHT),
                      min(param.OS_CROP_TOP, param.OS_CROP_BOTTOM));
}

// Output to input scaling, in unit coordinate systems.
vec2 scale_o2i() {
    const vec2 eff_input_res = eff_input_res();
    const vec2 eff_aspect =
        vec2(eff_input_res.x, param.FORCE_ASPECT_RATIO > 0.5
                                  ? eff_input_res.y / param.InputSize.y *
                                        param.InputSize.x * param.ASPECT_V /
                                        param.ASPECT_H
                                  : eff_input_res.y);

    if (param.FinalViewportSize.x / eff_aspect.x <
        param.FinalViewportSize.y / eff_aspect.y) {
        // Scale will be limited by width. Calc x scale, then derive y scale
        // using aspect ratio.
        const float scale_x =
            param.FORCE_INTEGER_SCALING > 0.5
                ? floor(param.FinalViewportSize.x / eff_input_res.x)
                : param.FinalViewportSize.x / eff_input_res.x;
        const float scale_y = (scale_x * eff_input_res.x * eff_aspect.y) /
                              (eff_input_res.y * eff_aspect.x);
        return param.FinalViewportSize.xy * param.InputSize.zw /
               vec2(scale_x, scale_y);
    } else {
        // Scale will be limited by height.
        const float scale_y =
            param.FORCE_INTEGER_SCALING > 0.5
                ? floor(param.FinalViewportSize.y / eff_input_res.y)
                : param.FinalViewportSize.y / eff_input_res.y;
        const float scale_x = (scale_y * eff_input_res.y * eff_aspect.x) /
                              (eff_input_res.x * eff_aspect.y);
        return param.FinalViewportSize.xy * param.InputSize.zw /
               vec2(scale_x, scale_y);
    }
}

// In unit space (output to input)
// coord_in_input_space = o2i(coord_in_output_space)
// This is used to sample from the input texture in the output pass.
vec2 o2i(vec2 x) {
    const vec2 center_in =
        param.CENTER_CROP > 0.5
            ? 0.5 * param.InputSize.zw *
                  vec2(param.OS_CROP_LEFT + param.InputSize.x -
                           param.OS_CROP_RIGHT,
                       param.OS_CROP_TOP + param.InputSize.y -
                           param.OS_CROP_BOTTOM)
            : vec2(0.49999);
    return (x - 0.49999) * scale_o2i() + center_in;
}
