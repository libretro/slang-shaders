#version 450

/*
    Offset shader by Jezze
*/

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
    uint FrameTimeDelta;
    float GLOBAL_MASTER;
    float SCREEN_RESOLUTION_SCALE;
    float SCREEN_ORIENTATION;
    float SCREEN_SCALE;
    float SCREEN_FREQUENCY;
} global;

layout(push_constant) uniform Push
{
    float COLOR_OVERFLOW;
    float COLOR_BRIGHTNESS;
    float COLOR_BRIGHTNESS_FLICKER;
    float SCANLINES_STRENGTH;
    float SCANLINES_OFFSET;
} param;

#include "parameters.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 1) out int ScreenOrientation;
layout(location = 2) out float ScreenMultiple;
layout(location = 0) out vec2 TexCoord;

// used in common/screen-helper.h
#define BASE_SIZE PARAM_SCREEN_RESOLUTION_SCALE > 2.5 ? 480.0 : 240.0;
#define ALLOW_AUTO_SCALE PARAM_SCREEN_RESOLUTION_SCALE > 1.5
#define ALLOW_AUTO_UP_SCALE PARAM_SCREEN_RESOLUTION_SCALE > 2.5

#include "common/screen-helper.h"

void main()
{
    gl_Position = global.MVP * Position;

    ScreenOrientation = get_orientation(global.OutputSize.xy, int(PARAM_SCREEN_ORIENTATION));
    ScreenMultiple = get_screen_multiple(global.OriginalSize.xy, ScreenOrientation, -PARAM_SCREEN_SCALE);

    TexCoord = Coord;
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) flat in int ScreenOrientation;
layout(location = 2) in float ScreenMultiple;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define INPUT_SCREEN_ORIENTATION ScreenOrientation
#define INPUT_SCREEN_MULTIPLE ScreenMultiple

#include "common/colorspace-srgb.h"
#include "common/color-helper.h"
#include "common/frame-helper.h"
#include "common/math-helper.h"

#define INPUT(color) decode_gamma(color)
#define OUTPUT(color, brightness) encode_gamma(apply_brightness(color, brightness))

vec2 vec2o(float x, float y)
{
    return INPUT_SCREEN_ORIENTATION == 0
        ? vec2(x, y)
        : vec2(y, x);
}

float get_luminance(vec3 color, float brightness)
{
    color = apply_color_overflow(color, PARAM_COLOR_OVERFLOW);
    color = apply_brightness(color, brightness);
    color = min(vec3(1.0), color);

    return get_luminance(color);
}

vec3 get_color(sampler2D source, vec2 tex_coord)
{
    vec2 texel_size = global.SourceSize.zw * INPUT_SCREEN_MULTIPLE * vec2o(0.0, 1.0);

    // offset scaled by multiple
    float scanlines_offset = PARAM_SCANLINES_OFFSET;
    if (scanlines_offset < 0.0)
    {
        // jitter offset each 3rd frame with 30/60Hz
        float scanlines_mod = mod(GetUniformFrameCount(PARAM_SCREEN_FREQUENCY), 3);

        // full offset
        scanlines_offset =
            // 3rd frame upwards
            scanlines_mod > 1.0 ? 1.0 :
            // 2nd frame downwards
            scanlines_mod > 0.0 ? -1.0 :
            // 1st frame no offset
            0.0;

        // get color with full offset
        vec3 color = INPUT(texture(source, tex_coord + scanlines_offset * texel_size).rgb);

        // get luminance brightness corrected
        float luma = get_luminance(color, PARAM_COLOR_BRIGHTNESS);

        // scale offset by color luma to avoid too much offset in dark areas
        scanlines_offset *= luma * abs(PARAM_SCANLINES_OFFSET);
    }

    // fade out for lower scanlines strength
    scanlines_offset *= normalized_sigmoid(PARAM_SCANLINES_STRENGTH, -0.5);

    // return color with scaled offset
    return INPUT(texture(source, tex_coord + scanlines_offset * texel_size).rgb);
}

float get_brightness_offset(vec3 color)
{
    // get luminance brightness corrected
    float luma = get_luminance(color, PARAM_COLOR_BRIGHTNESS);

    // jitter offset each 3rd frame with 30/60Hz
    float brightness_mod = mod(GetUniformFrameCount(PARAM_SCREEN_FREQUENCY), 3);

    // full offset
    float brightness_offset =
        // 3rd frame lighten
        brightness_mod > 1.0 ? luma :
        // 2nd frame darken
        brightness_mod > 0.0 ? -luma :
        // 1st frame no offset
        0.0;

    // less flicker for lower values
    brightness_offset *= normalized_sigmoid(PARAM_COLOR_BRIGHTNESS_FLICKER * 0.5, 0.5);

    return brightness_offset;
}

void main()
{
    // return if effect is disabled
    if (PARAM_COLOR_BRIGHTNESS_FLICKER == 0.0
        && PARAM_SCANLINES_OFFSET == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 color = get_color(Source, TexCoord);
    float brightness_offset = get_brightness_offset(color);

    FragColor = vec4(OUTPUT(color, brightness_offset), 1.0);
}
