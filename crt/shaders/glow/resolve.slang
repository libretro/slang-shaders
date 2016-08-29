#version 450

layout(push_constant) uniform Push
{
    float BLOOM_STRENGTH;
    float OUTPUT_GAMMA;
} param;

#pragma parameter BLOOM_STRENGTH "Glow Strength" 0.45 0.0 0.8 0.05
#pragma parameter OUTPUT_GAMMA "Monitor Gamma" 2.2 1.8 2.6 0.02

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
	vec4 CRTPassSize;
} global;

#pragma stage vertex
layout(location = 0) in  vec4  Position;
layout(location = 1) in  vec2  TexCoord;
layout(location = 0) out vec2  vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord   = TexCoord;
}

#pragma stage fragment
layout(location = 0) in  vec2  vTexCoord;
layout(location = 0) out vec4  FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;
layout(set = 0, binding = 2) uniform sampler2D CRTPass;

// For debugging
#define BLOOM_ONLY 0

#define CRT_PASS CRTPass

void main() 
{
#if BLOOM_ONLY
    vec3 source = BLOOM_STRENGTH * texture(Source, vTexCoord).rgb;
#else

    vec3 source = 1.15 * texture(CRT_PASS, vTexCoord).rgb;
    vec3 bloom  = texture(Source, vTexCoord).rgb;
    source     += param.BLOOM_STRENGTH * bloom;
#endif
    FragColor = vec4(pow(clamp(source, 0.0, 1.0), vec3(1.0 / param.OUTPUT_GAMMA)), 1.0);
}
