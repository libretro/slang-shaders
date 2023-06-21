#version 450

// See compose.slang for copyright and other information.

#include "parameters.slang"

layout(push_constant) uniform Push {
    vec4 InputSize;
    vec4 FinalViewportSize;
    float OS_CROP_TOP;
    float OS_CROP_BOTTOM;
    float OS_CROP_LEFT;
    float OS_CROP_RIGHT;
    float CENTER_CROP;
    float SAMPLE_SIZE;
    float BLUR_EXTEND_H;
    float BLUR_EXTEND_V;
    float MIRROR_BLUR;
    float FORCE_ASPECT_RATIO;
    float ASPECT_H;
    float ASPECT_V;
    float FORCE_INTEGER_SCALING;
}
param;

#include "scaling.slang"

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Input;

float min_of_vec4(vec4 i) { return min(min(i.x, i.y), min(i.z, i.w)); }

int argmin(vec4 i) {
    const vec4 m = vec4(min_of_vec4(i));
    const vec4 ma = step(i, m) * vec4(0.0, -1.0, -2.0, -3.0);
    return -int(min_of_vec4(ma));
}

// Returns a coordinate in [0, w) when repeating that interval (and optionally
// mirroring).
float mirrored_repeat(float w, float x) {
    const float phase = mod(x, w);
    if (param.MIRROR_BLUR < 0.5) {
        return phase;
    }
    const int period = int(x / w);
    return period % 2 == 1 != x > 0.0 ? phase : w - phase;
}

float extend_left(vec2 coord, vec4 input_extrema) {
    return input_extrema.x +
           mirrored_repeat(param.SAMPLE_SIZE, coord.x - input_extrema.x);
}

float extend_right(vec2 coord, vec4 input_extrema) {
    return input_extrema.z -
           mirrored_repeat(param.SAMPLE_SIZE, input_extrema.z - coord.x);
}

float extend_top(vec2 coord, vec4 input_extrema) {
    return input_extrema.y +
           mirrored_repeat(param.SAMPLE_SIZE, coord.y - input_extrema.y);
}

float extend_bottom(vec2 coord, vec4 input_extrema) {
    return input_extrema.w -
           mirrored_repeat(param.SAMPLE_SIZE, input_extrema.w - coord.y);
}

// This function samples in a very specific way which is the foundation for
// blurring later.
// - If the sample coordinate is outside of the cropped input, Either black is
// returned if blur extension is turned off, or a repeated pattern from the
// sampling frame band is returned.
// - If the coordinate is inside the cropped input and within the frame band
// given by SAMPLE_SIZE, the original texture sample is returned.
// - If the coordinate is further inside than the frame band, a mirrored
// repeating sample is returned. The side of the frame that is sampled is given
// by the one that is closest to the sampled point.
vec3 sample_mirrored_frame(sampler2D tex, vec2 coord, vec4 input_extrema) {
    if (coord.x < input_extrema.x) {
        if (param.BLUR_EXTEND_H < 0.5) {
            return vec3(0.0);
        }
        if (coord.y < input_extrema.y) {
            // Top left corner extension
            if (param.BLUR_EXTEND_V < 0.5) {
                return vec3(0.0);
            }
            return texture(tex, vec2(extend_left(coord, input_extrema),
                                     extend_top(coord, input_extrema)) *
                                    param.InputSize.zw)
                .rgb;
        } else if (coord.y < input_extrema.w) {
            // Left extension
            return texture(tex,
                           vec2(extend_left(coord, input_extrema), coord.y) *
                               param.InputSize.zw)
                .rgb;
        } else {
            // Bottom left corner extension
            if (param.BLUR_EXTEND_V < 0.5) {
                return vec3(0.0);
            }
            return texture(tex, vec2(extend_left(coord, input_extrema),
                                     extend_bottom(coord, input_extrema)) *
                                    param.InputSize.zw)
                .rgb;
        }
    } else if (coord.x < input_extrema.z) {
        if (coord.y < input_extrema.y) {
            if (param.BLUR_EXTEND_V < 0.5) {
                return vec3(0.0);
            }
            // Top extension
            return texture(tex,
                           vec2(coord.x, extend_top(coord, input_extrema)) *
                               param.InputSize.zw)
                .rgb;
        } else if (coord.y < input_extrema.w) {
            const vec4 inner_extrema =
                input_extrema + vec4(param.SAMPLE_SIZE, param.SAMPLE_SIZE,
                                     -param.SAMPLE_SIZE, -param.SAMPLE_SIZE);
            if (any(lessThan(coord, inner_extrema.xy)) ||
                any(greaterThanEqual(coord, inner_extrema.zw))) {
                // In frame band
                return texture(tex, coord * param.InputSize.zw).rgb;
            }
            // Innermost -- mirrored repeat sampling from nearest side
            const vec4 distances =
                vec4(coord.x - inner_extrema.x, inner_extrema.z - coord.x,
                     coord.y - inner_extrema.y, inner_extrema.w - coord.y);
            switch (argmin(distances)) {
                case 0:
                    // left
                    return texture(tex, vec2(extend_left(coord, input_extrema),
                                             coord.y) *
                                            param.InputSize.zw)
                        .rgb;
                case 1:
                    // right
                    return texture(tex, vec2(extend_right(coord, input_extrema),
                                             coord.y) *
                                            param.InputSize.zw)
                        .rgb;
                case 2:
                    // top
                    return texture(tex, vec2(coord.x,
                                             extend_top(coord, input_extrema)) *
                                            param.InputSize.zw)
                        .rgb;
                case 3:
                default:
                    // bottom
                    return texture(tex,
                                   vec2(coord.x,
                                        extend_bottom(coord, input_extrema)) *
                                       param.InputSize.zw)
                        .rgb;
            }
        } else {
            if (param.BLUR_EXTEND_V < 0.5) {
                return vec3(0.0);
            }
            // Bottom extension
            return texture(tex,
                           vec2(coord.x, extend_bottom(coord, input_extrema)) *
                               param.InputSize.zw)
                .rgb;
        }
    } else {
        if (param.BLUR_EXTEND_H < 0.5) {
            return vec3(0.0);
        }
        if (coord.y < input_extrema.y) {
            // Top right corner extension
            if (param.BLUR_EXTEND_V < 0.5) {
                return vec3(0.0);
            }
            return texture(tex, vec2(extend_right(coord, input_extrema),
                                     extend_top(coord, input_extrema)) *
                                    param.InputSize.zw)
                .rgb;
        } else if (coord.y < input_extrema.w) {
            // Right extension
            return texture(tex,
                           vec2(extend_right(coord, input_extrema), coord.y) *
                               param.InputSize.zw)
                .rgb;
        } else {
            // Bottom right corner extension
            if (param.BLUR_EXTEND_V < 0.5) {
                return vec3(0.0);
            }
            return texture(tex, vec2(extend_right(coord, input_extrema),
                                     extend_bottom(coord, input_extrema)) *
                                    param.InputSize.zw)
                .rgb;
        }
    }
}

void main() {
    const vec2 pixel_coord = o2i(vTexCoord);
    FragColor = vec4(
        sample_mirrored_frame(Input, pixel_coord,
                              vec4(param.OS_CROP_LEFT, param.OS_CROP_TOP,
                                   param.InputSize.x - param.OS_CROP_RIGHT,
                                   param.InputSize.y - param.OS_CROP_BOTTOM)),
        1.0);
}
