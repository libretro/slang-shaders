#version 450
#pragma parameter u_gamma "Gamma" 1.0 0.5 3.0 0.05

layout(push_constant) uniform Push
{
float u_gamma;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} global;

#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
#define OutputSize global.OutputSize
#define FrameCount global.FrameCount
#define u_gamma params.u_gamma

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
	vec3 res = texture(Source, vTexCoord).rgb;
   FragColor.rgb = pow(res,vec3(u_gamma));
}
