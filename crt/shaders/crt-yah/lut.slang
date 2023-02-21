#version 450

/*
    Based on LUT shader by Hunter K.
    Modified by Jezze
*/

#pragma name LutPass

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
} global;

layout (push_constant) uniform Push
{
    float GLOBAL_MASTER;
    float COLOR_PROFILE;
} param;

#include "parameters.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D SamplerLutNtsc;
layout(set = 0, binding = 4) uniform sampler2D SamplerLutTrinitron;

vec3 apply_lut(vec3 color, sampler2D lut_sampler)
{
    float lut_size = textureSize(lut_sampler, 0).y;

    float red = (color.r * (lut_size - 1.0) + 0.5) / (lut_size * lut_size);
    float green = (color.g * (lut_size - 1.0) + 0.5) / lut_size;
    float blue = (floor(color.b * (lut_size - 1.0)) / lut_size) + red;

    return texture(lut_sampler, vec2(blue, green)).rgb;
}

// no gamma correction
#define INPUT(color) color
#define OUTPUT(color) color

void main()
{
    if (PARAM_COLOR_PROFILE == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 color = INPUT(texture(Source, TexCoord).rgb);

    vec3 ntsc_color = apply_lut(color, SamplerLutNtsc);
    vec3 trinitron_color = apply_lut(color, SamplerLutTrinitron);

    color = PARAM_COLOR_PROFILE < 0.0
        ? mix(color, ntsc_color, -PARAM_COLOR_PROFILE)
        : mix(color, trinitron_color, PARAM_COLOR_PROFILE);

    FragColor = vec4(OUTPUT(color), 1.0);
}
