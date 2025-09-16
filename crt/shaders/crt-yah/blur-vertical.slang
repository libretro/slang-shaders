#version 450

/*
    Based on Vertical Blur shader by Hunter K.
    Modified by Jezze
*/

#pragma name BlurVPass

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
    float HALATION_INTENSITY;
    float HALATION_DIFFUSION;
} param;

#include "parameters.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out float Diffusion;
layout(location = 2) out float Tabs;
layout(location = 3) out float Multiple;

#include "common/screen-helper.h"

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    // invert parameter, avoid 0
    Diffusion = sqrt(PARAM_HALATION_DIFFUSION);
    Diffusion = max(1.0 / 16.0, 1.0 - Diffusion);

    // 4 to 16 tabs
    Tabs = PARAM_HALATION_DIFFUSION * PARAM_HALATION_DIFFUSION * 16.0;
    Tabs = max(4.0, round(Tabs));

    Multiple = get_multiple(global.SourceSize.xy);
    Multiple = max(1.0, round(Multiple));

    // normalize multiple based on ratio change with horizontal as reference
    Multiple = Multiple
        // from texture source
        * get_ratio(global.SourceSize.xy, 0)
        // to screen target
        / get_ratio(global.FinalViewportSize.xy, 0);
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in float Diffusion;
layout(location = 2) in float Tabs;
layout(location = 3) in float Multiple;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "common/colorspace-srgb.h"

// required by blur.h
#define INPUT(color) decode_gamma(color)
#define OUTPUT(color) encode_gamma(color)
#define OFFSET(tex_coord, offset) vec2(tex_coord.x, tex_coord.y + (offset * global.SourceSize.w))

#include "blur.h"

void main()
{
    if (PARAM_HALATION_INTENSITY == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    // scale diffusion
    float diffusion = Diffusion / (Multiple * Multiple);

    // scale tabs
    float tabs = Tabs * Multiple * 2.0;
    
    vec3 color = get_blur_color(Source, TexCoord, diffusion, tabs);

    FragColor = vec4(color, 1.0);
}
