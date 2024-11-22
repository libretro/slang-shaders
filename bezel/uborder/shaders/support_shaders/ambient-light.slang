#version 450

/*  ambient-light shader

    Based on ambient-glow.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float AG_effect;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter AG_NONONO        "AMBIENT-LIGHT:"         1.0 0.0 1.0 1.0
#pragma parameter AG_effect        "    Glow Brightness"    1.0 0.1 3.0 0.1

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec4 background;
    vec4 color = texture(Source, vTexCoord, 10.0) * 1.25 + 0.125; // use mipmapping to get an average of the entire screen

    background = clamp(color * color * params.AG_effect, 0.0, 1.0);

    FragColor = background;
}
