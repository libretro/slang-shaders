#version 450

layout(push_constant) uniform Push
{
    float mixfactor;
} param;

#pragma parameter feed_nonono       "FEEDBACK:"               0.0  0.0 1.0 1.0
#pragma parameter mixfactor         "    Motionblur Fadeout"  0.75 0.0 1.0 0.01

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord   = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D PassFeedback0;

void main()
{
    vec3 current = texture(Source,        vTexCoord).rgb;
    vec3 fdback  = texture(PassFeedback0, vTexCoord).rgb;
    
    FragColor = vec4(mix(current, fdback, param.mixfactor), 1.0);
}
