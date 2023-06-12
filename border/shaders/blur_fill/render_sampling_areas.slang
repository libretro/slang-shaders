#version 450

#include "parameters.slang"

layout(push_constant) uniform Push {
    vec4 InputSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OS_CROP_TOP;
    float OS_CROP_BOTTOM;
    float OS_CROP_LEFT;
    float OS_CROP_RIGHT;
    float SAMPLE_SIZE;
}
param;

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

float min(vec4 i) { return min(min(i.x, i.y), min(i.z, i.w)); }

int argmin(vec4 i) {
    const vec4 m = vec4(min(i));
    const vec4 ma = step(i, m) * vec4(0.0, -1.0, -2.0, -3.0);
    return -int(min(ma));
}

// Returns a coordinate in [0, w) when repeating that interval and mirroring,
// and sampling at x.
float mirrored_repeat(float w, float x) {
    const int period = int(x / w);
    const float phase = mod(x, w);
    return period % 2 == 0 == x < 0.0 ? phase : w - phase;
}

// This function samples in a very specific way which is the foundation for
// blurring later.
// - If the sample coordinate is outside of the cropped input, black is
// returned.
// - If the coordinate is inside the cropped input and within the frame band
// given by SAMPLE_SIZE, the original texture sample is returned.
// - If the coordinate is further inside than the frame band, a mirrored
// repeating sample is returned. The side of the frame that is sampled is given
// by the one that is closest to the sampled point.
vec3 sample_mirrored_frame(sampler2D tex, vec2 coord, vec4 input_extrema) {
    if (any(lessThan(coord, input_extrema.xy)) ||
        any(greaterThanEqual(coord, input_extrema.zw))) {
        // Outside
        return vec3(0.0);
    }
    const vec4 inner_extrema =
        input_extrema + vec4(param.SAMPLE_SIZE, param.SAMPLE_SIZE,
                             -param.SAMPLE_SIZE, -param.SAMPLE_SIZE);
    if (any(lessThan(coord, inner_extrema.xy)) ||
        any(greaterThanEqual(coord, inner_extrema.zw))) {
        // In frame band
        return texture(tex, coord * param.InputSize.zw).rgb;
    }
    // Innermost -- mirrored repeat sampling
    const vec4 distances =
        vec4(coord.x - inner_extrema.x, inner_extrema.z - coord.x,
             coord.y - inner_extrema.y, inner_extrema.w - coord.y);
    switch (argmin(distances)) {
        case 0:
            // left
            return texture(tex, vec2(input_extrema.x +
                                         mirrored_repeat(param.SAMPLE_SIZE,
                                                         distances.x),
                                     coord.y) *
                                    param.InputSize.zw)
                .rgb;
        case 1:
            // right
            return texture(tex, vec2(input_extrema.z -
                                         mirrored_repeat(param.SAMPLE_SIZE,
                                                         distances.y),
                                     coord.y) *
                                    param.InputSize.zw)
                .rgb;
        case 2:
            // top
            return texture(tex,
                           vec2(coord.x, input_extrema.y +
                                             mirrored_repeat(param.SAMPLE_SIZE,
                                                             distances.z)) *
                               param.InputSize.zw)
                .rgb;
        case 3:
        default:
            // bottom
            return texture(tex,
                           vec2(coord.x, input_extrema.w -
                                             mirrored_repeat(param.SAMPLE_SIZE,
                                                             distances.w)) *
                               param.InputSize.zw)
                .rgb;
    }
}

void main() {
    const vec2 pixel_coord = vTexCoord * param.InputSize.xy;
    FragColor = vec4(
        sample_mirrored_frame(Input, pixel_coord,
                              vec4(param.OS_CROP_LEFT, param.OS_CROP_TOP,
                                   param.InputSize.x - param.OS_CROP_RIGHT,
                                   param.InputSize.y - param.OS_CROP_BOTTOM)),
        1.0);
}
