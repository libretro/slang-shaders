#version 450

/*
    Based on Horizontal Blur shader by Hunter K.
    Modified by Jezze
*/

#pragma name BlurHPass

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
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in float Diffusion;
layout(location = 2) in float Tabs;
layout(location = 3) in float Multiple;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "common/colorspace-srgb.h"

#define INPUT(color) decode_gamma(color)
#define OUTPUT(color) encode_gamma(color)

float offset(float i)
{
    // return alternating offset
    return mod(i, 2.0) > 0.0
        ? ceil(i / 2.0)
        : -ceil(i / 2.0);
}

void main()
{
    if (PARAM_HALATION_INTENSITY == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 color = vec3(0.0);
    float sum = 0.0;

    // scale diffusion
    float diffusion = Diffusion / (Multiple * Multiple);

    // scale tabs, but limit to 64
    const float max_tabs = 64.0;
    float tabs = Tabs * Multiple * 2.0;
    float tab_size = tabs > max_tabs
        ? tabs / max_tabs
        : 1.0;
    int i = 0;
    do
    {
        float o = offset(i) * tab_size;

        vec2 texCoord = TexCoord;
        texCoord.x += o * global.SourceSize.z;

        float k = exp(-diffusion * o * o);
        color += k * INPUT(texture(Source, texCoord).rgb);
        sum += k;

        i++;
    }
    while (i <= tabs && i <= max_tabs); // break after limit

    FragColor = vec4(OUTPUT(color / sum), 1.0);
}
