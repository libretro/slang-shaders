#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float TAPSH;
   float GLOW_FALLOFF_H;
} params;

// Higher value, more centered glow.
// Lower values might need more taps.
// Adapted from crt-easymode-halation by Easymode.

#pragma parameter TAPSH "H. Glow Radius" 4.0 1.0 10.0 1.0 
#define TAPSH params.TAPSH
#pragma parameter GLOW_FALLOFF_H "Horizontal Glow Grade" 0.35 0.00 1.5 0.02 
#define GLOW_FALLOFF_H params.GLOW_FALLOFF_H

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.00001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D RotPass;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize

#define kernel(x) exp(-GLOW_FALLOFF_H * (x) * (x))

void main()
{
	float ratio = COMPAT_TEXTURE(RotPass, vec2(0.5,0.1)).a;
	if (vTexCoord.y > ratio) discard;
	
	vec3 col = vec3(0.0); vec3 tmp;
	float dx = SourceSize.z;

	float k_total = 0.;
	for (float i = -TAPSH; i <= TAPSH; i++)
		{
		float k = kernel(i);
		k_total += k;
		tmp = COMPAT_TEXTURE(Source, vTexCoord + vec2(float(i) * dx, 0.0)).rgb;
		col += k * tmp;
		}
   FragColor = vec4(col / k_total, ratio);
}