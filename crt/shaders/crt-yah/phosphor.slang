#version 450

/*
    Based on Phosphor shader by Westley M. Martinez
    Ported from MAME
    Modified by Jezze
*/

#pragma name PhosphorPass
#pragma format R16G16B16A16_SFLOAT

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
    uint FrameTimeDelta;
} global;

layout (push_constant) uniform Push
{
    float GLOBAL_MASTER;
    float PHOSPHOR_AMOUNT;
    float PHOSPHOR_DECAY;
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
layout(set = 0, binding = 3) uniform sampler2D PhosphorPassFeedback;

#define INPUT(color) decode_gamma(color)
#define OUTPUT(color) encode_gamma(color)

#include "common/colorspace-srgb.h"
#include "common/frame-helper.h"

void main()
{
    if (PARAM_PHOSPHOR_AMOUNT == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 current = INPUT(texture(Source, TexCoord).rgb);
    vec3 feedback = INPUT(texture(PhosphorPassFeedback, TexCoord).rgb);

    float r = feedback.r;
    float g = feedback.g;
    float b = feedback.b;

    float amount = 1.0 / (PARAM_PHOSPHOR_AMOUNT * 0.5);
    float decay = PARAM_PHOSPHOR_DECAY + 1.0;
    decay *= GetUniformFrameFactor();

    r = r > 0.0 ? pow(amount + pow(1.0 / r, 1.0 / decay), -decay) : r;
    g = g > 0.0 ? pow(amount + pow(1.0 / g, 1.0 / decay), -decay) : g;
    b = b > 0.0 ? pow(amount + pow(1.0 / b, 1.0 / decay), -decay) : b;

    r = max(current.r, r);
    g = max(current.g, g);
    b = max(current.b, b);

    FragColor = vec4(OUTPUT(vec3(r, g, b)), 1.0);
}
