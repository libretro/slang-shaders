#version 450

#include "dual_filter_parameters.slang"

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float BLUR_STRENGTH;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
}
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
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    const vec2 halfpixel = 0.5 * param.SourceSize.zw * param.BLUR_STRENGTH;
    vec3 sum = texture(Source, vTexCoord).rgb * 4.0;
    sum += texture(Source, vTexCoord - halfpixel).rgb;
    sum += texture(Source, vTexCoord + halfpixel).rgb;
    sum += texture(Source, vTexCoord + vec2(halfpixel.x, -halfpixel.y)).rgb;
    sum += texture(Source, vTexCoord - vec2(halfpixel.x, -halfpixel.y)).rgb;
    FragColor = vec4(sum * 0.125, 1.0);
}
