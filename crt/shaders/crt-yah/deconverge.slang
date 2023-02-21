#version 450

/*
    Based on Deconverge shader by Jezze
    Ported from MAME
*/

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
} global;

layout (push_constant) uniform Push
{
    float GLOBAL_MASTER;
    float SCREEN_SCALE;
    float SCREEN_ORIENTATION;
    float DECONVERGE_LINEAR;
    float DECONVERGE_RADIAL;
} param;

#include "parameters.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 TexCoordR;
layout(location = 2) out vec2 TexCoordG;
layout(location = 3) out vec2 TexCoordB;

#include "common/screen-helper.h"

void main()
{
    gl_Position = global.MVP * Position;

    float screen_orientation = get_orientation(global.OutputSize.xy, PARAM_SCREEN_ORIENTATION);
    float screen_scale = get_multiple(global.OriginalSize.xy, screen_orientation, -PARAM_SCREEN_SCALE);

    // limit deconverge to range of [-1.0, 1.0]
    float linear_limit = PARAM_DECONVERGE_LINEAR > 0
        ? min(1.0, PARAM_DECONVERGE_LINEAR)
        : max(-1.0, PARAM_DECONVERGE_LINEAR);
    float radial_limit = PARAM_DECONVERGE_RADIAL > 0
        ? min(1.0, PARAM_DECONVERGE_RADIAL)
        : max(-1.0, PARAM_DECONVERGE_RADIAL);

    vec2 linear_offset = mix(
        vec2(linear_limit, 0.0),
        vec2(0.0, linear_limit),
        screen_orientation);
    vec2 radial_offset = vec2(radial_limit);

    float r = -1.0;
    float g = 0.0;
    float b = 1.0;

    vec2 TexelSize = global.SourceSize.zw * screen_scale;

    TexCoord = Coord;
    TexCoordR = Coord;
    TexCoordG = Coord;
    TexCoordB = Coord;

    // center coordinate
    TexCoordR -= 0.5;
    TexCoordG -= 0.5;
    TexCoordB -= 0.5;

    // radial converge
    TexCoordR *= 1.0 + radial_offset * r * TexelSize * 2.0;
    TexCoordG *= 1.0 + radial_offset * g * TexelSize * 2.0;
    TexCoordB *= 1.0 + radial_offset * b * TexelSize * 2.0;

    // uncenter coordinate
    TexCoordR += 0.5;
    TexCoordG += 0.5;
    TexCoordB += 0.5;

    // linear converge
    TexCoordR += linear_offset * r * TexelSize;
    TexCoordG += linear_offset * g * TexelSize;
    TexCoordB += linear_offset * b * TexelSize;
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in vec2 TexCoordR;
layout(location = 2) in vec2 TexCoordG;
layout(location = 3) in vec2 TexCoordB;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define INPUT(color) decode_gamma(color)
#define OUTPUT(color) encode_gamma(color)

#include "common/colorspace-srgb.h"

void main()
{
    if (PARAM_DECONVERGE_LINEAR == 0.0
        && PARAM_DECONVERGE_RADIAL == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 color = INPUT(texture(Source, TexCoord).rgb);

    vec3 deconverge_color = vec3(
        INPUT(texture(Source, TexCoordR).rgb).r,
        INPUT(texture(Source, TexCoordG).rgb).g,
        INPUT(texture(Source, TexCoordB).rgb).b);

    float limit = max(abs(PARAM_DECONVERGE_RADIAL), abs(PARAM_DECONVERGE_LINEAR));
    float merge = max(0.0, limit - 1.0);

    deconverge_color = mix(
        // merge color with deconverge color in range of [-1.0, 1.0]
        (color + deconverge_color) / 2.0,
        // reduce merge beyond range of [-1.0, 1.0]
        deconverge_color,
        merge);

    FragColor = vec4(OUTPUT(deconverge_color), 1.0);
}
