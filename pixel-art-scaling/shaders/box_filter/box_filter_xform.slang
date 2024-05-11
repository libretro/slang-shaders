#version 450

/*
    Box Filter AA v1.0 by fishku
    Copyright (C) 2024
    Public domain license (CC0)

    Branching-free anti-aliasing using pixel coverage.

    Changelog:
    v1.0: Initial release.
*/

// clang-format off
#include "../../../misc/shaders/input_transform/parameters.inc"

#include "../../../misc/shaders/coverage/coverage.inc"
#include "../../../misc/shaders/input_transform/input_transform.inc"
// clang-format on

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint Rotation;
    // From input transform library, scaling section
    float FORCE_ASPECT_RATIO;
    float ASPECT_H;
    float ASPECT_V;
    float FORCE_INTEGER_SCALING_H;
    float FORCE_INTEGER_SCALING_V;
    float OVERSCALE;
    // From input transform library, cropping section
    float OS_CROP_TOP;
    float OS_CROP_BOTTOM;
    float OS_CROP_LEFT;
    float OS_CROP_RIGHT;
    // From input transform library, moving section
    float SHIFT_H;
    float SHIFT_V;
    float CENTER_AFTER_CROPPING;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec4 px_rect;
layout(location = 1) out vec2 tx_coord;
layout(location = 2) out vec2 scale_o2i;
layout(location = 3) out vec2 input_center;

void main() {
    gl_Position = global.MVP * Position;

    px_rect = vec4(TexCoord * param.OutputSize.xy - 0.5,
                   TexCoord * param.OutputSize.xy + 0.5);
    const vec4 crop = vec4(param.OS_CROP_TOP, param.OS_CROP_LEFT,
                           param.OS_CROP_BOTTOM, param.OS_CROP_RIGHT);
    scale_o2i = get_scale_o2i(
        param.SourceSize.xy, param.OutputSize.xy, crop, param.Rotation,
        param.CENTER_AFTER_CROPPING, param.FORCE_ASPECT_RATIO,
        vec2(param.ASPECT_H, param.ASPECT_V),
        vec2(param.FORCE_INTEGER_SCALING_H, param.FORCE_INTEGER_SCALING_V),
        param.OVERSCALE,
        /* output_size_is_final_viewport_size = */ false);
    const vec2 shift = vec2(param.SHIFT_H, param.SHIFT_V);
    input_center =
        get_input_center(param.SourceSize.xy, crop, shift, param.Rotation,
                         param.CENTER_AFTER_CROPPING);
    tx_coord = o2i(TexCoord, scale_o2i, input_center);
}

#pragma stage fragment
layout(location = 0) in vec4 px_rect;
layout(location = 1) in vec2 tx_coord;
layout(location = 2) in vec2 scale_o2i;
layout(location = 3) in vec2 input_center;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float DigitBin(const int x) {
    return x == 0   ? 480599.0
           : x == 1 ? 139810.0
           : x == 2 ? 476951.0
           : x == 3 ? 476999.0
           : x == 4 ? 350020.0
           : x == 5 ? 464711.0
           : x == 6 ? 464727.0
           : x == 7 ? 476228.0
           : x == 8 ? 481111.0
           : x == 9 ? 481095.0
                    : 0.0;
}

float PrintValue(vec2 vStringCoords, float fValue, float fMaxDigits,
                 float fDecimalPlaces) {
    if ((vStringCoords.y < 0.0) || (vStringCoords.y >= 1.0)) return 0.0;

    bool bNeg = (fValue < 0.0);
    fValue = abs(fValue);

    float fLog10Value = log2(abs(fValue)) / log2(10.0);
    float fBiggestIndex = max(floor(fLog10Value), 0.0);
    float fDigitIndex = fMaxDigits - floor(vStringCoords.x);
    float fCharBin = 0.0;
    if (fDigitIndex > (-fDecimalPlaces - 1.01)) {
        if (fDigitIndex > fBiggestIndex) {
            if ((bNeg) && (fDigitIndex < (fBiggestIndex + 1.5)))
                fCharBin = 1792.0;
        } else {
            if (fDigitIndex == -1.0) {
                if (fDecimalPlaces > 0.0) fCharBin = 2.0;
            } else {
                float fReducedRangeValue = fValue;
                if (fDigitIndex < 0.0) {
                    fReducedRangeValue = fract(fValue);
                    fDigitIndex += 1.0;
                }
                float fDigitValue =
                    (abs(fReducedRangeValue / (pow(10.0, fDigitIndex))));
                fCharBin = DigitBin(int(floor(mod(fDigitValue, 10.0))));
            }
        }
    }
    return floor(
        mod((fCharBin / pow(2.0, floor(fract(vStringCoords.x) * 4.0) +
                                     (floor(vStringCoords.y * 5.0) * 4.0))),
            2.0));
}

vec3 addTextOverlays(vec2 fragCoord, vec2 origin, float valueToPrint,
                     vec3 color) {
    fragCoord = vec2(fragCoord.x, param.OutputSize.y - fragCoord.y);
    vec2 vFontSize = vec2(8.0, 15.0);

    float customDigit =
        PrintValue((fragCoord - origin) / vFontSize, valueToPrint, 3.0, 6.0);

    return mix(vec3(0.), color, customDigit);
}

void main() {
    // Figure out 4 nearest texels in source texture
    vec2 tx_coord_i;
    const vec2 tx_coord_f = modf(tx_coord, tx_coord_i);
    const vec2 tx_coord_off = step(vec2(0.5), tx_coord_f) * 2.0 - 1.0;
    vec2 tx_origins[] = {tx_coord_i, tx_coord_i + vec2(tx_coord_off.x, 0.0),
                         tx_coord_i + vec2(0.0, tx_coord_off.y),
                         tx_coord_i + tx_coord_off};

    // Sample.
    // Apply square for fast "gamma correction".
    vec3 samples[] = {
        texture(Source, (tx_origins[0] + 0.5) * param.SourceSize.zw).rgb,
        texture(Source, (tx_origins[1] + 0.5) * param.SourceSize.zw).rgb,
        texture(Source, (tx_origins[2] + 0.5) * param.SourceSize.zw).rgb,
        texture(Source, (tx_origins[3] + 0.5) * param.SourceSize.zw).rgb};
    samples[0] *= samples[0];
    samples[1] *= samples[1];
    samples[2] *= samples[2];
    samples[3] *= samples[3];

    // Apply shader.
    // Transform tx_origins into pixel output space. Equivalent to manual
    // unrolling of "i2o" function.
    const vec2 scale_i2o = 1.0 / scale_o2i;
    const vec2 px_per_tx = param.OutputSize.xy * scale_i2o;

    tx_origins[0] = fma(tx_origins[0], scale_i2o, -input_center * scale_i2o);
    tx_origins[0] =
        fma(tx_origins[0], param.OutputSize.xy, 0.49999 * param.OutputSize.xy);

    tx_origins[1] = fma(tx_origins[1], scale_i2o, -input_center * scale_i2o);
    tx_origins[1] =
        fma(tx_origins[1], param.OutputSize.xy, 0.49999 * param.OutputSize.xy);

    tx_origins[2] = fma(tx_origins[2], scale_i2o, -input_center * scale_i2o);
    tx_origins[2] =
        fma(tx_origins[2], param.OutputSize.xy, 0.49999 * param.OutputSize.xy);

    tx_origins[3] = fma(tx_origins[3], scale_i2o, -input_center * scale_i2o);
    tx_origins[3] =
        fma(tx_origins[3], param.OutputSize.xy, 0.49999 * param.OutputSize.xy);

    const vec3 res =
        samples[0] * rect_coverage(px_rect, vec4(tx_origins[0],
                                                 tx_origins[0] + px_per_tx)) +
        samples[1] * rect_coverage(px_rect, vec4(tx_origins[1],
                                                 tx_origins[1] + px_per_tx)) +
        samples[2] * rect_coverage(px_rect, vec4(tx_origins[2],
                                                 tx_origins[2] + px_per_tx)) +
        samples[3] * rect_coverage(px_rect, vec4(tx_origins[3],
                                                 tx_origins[3] + px_per_tx));

    // Apply sqrt for fast "gamma correction".
    FragColor = vec4(sqrt(res), 1.0);

    // px_per_tx
    FragColor.rgb += addTextOverlays(px_rect.xy, vec2(20.0, 20.0), px_per_tx.x,
                                     vec3(1.0, 0.0, 0.0));
    FragColor.rgb += addTextOverlays(px_rect.xy, vec2(100.0, 20.0), px_per_tx.y,
                                     vec3(1.0, 0.0, 0.0));

    // px_rect fract
    FragColor.rgb += addTextOverlays(px_rect.xy, vec2(20.0, 50.0),
                                     fract(px_rect.x), vec3(1.0, 0.0, 0.0));
    FragColor.rgb += addTextOverlays(px_rect.xy, vec2(100.0, 50.0),
                                     fract(px_rect.y), vec3(1.0, 0.0, 0.0));

    // tx_origins fract
    FragColor.rgb +=
        addTextOverlays(px_rect.xy, vec2(20.0, 100.0), fract(tx_origins[0].x),
                        vec3(1.0, 0.0, 0.0));
    FragColor.rgb +=
        addTextOverlays(px_rect.xy, vec2(100.0, 100.0), fract(tx_origins[0].y),
                        vec3(1.0, 0.0, 0.0));

    // input_center
    FragColor.rgb += addTextOverlays(px_rect.xy, vec2(20.0, 150.0),
                                     input_center.x, vec3(1.0, 0.0, 0.0));
    FragColor.rgb += addTextOverlays(px_rect.xy, vec2(150.0, 150.0),
                                     input_center.y, vec3(1.0, 0.0, 0.0));
}
