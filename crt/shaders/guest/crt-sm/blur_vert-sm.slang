#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float TAPSV;
   float GLOW_FALLOFF_V;
} params;

// Higher value, more centered glow.
// Lower values might need more taps.
// Adapted from crt-easymode-halation by Easymode.

// Parameter lines go here:
#pragma parameter TAPSV "V. Glow Radius" 4.0 1.0 10.0 1.0 
#define TAPSV params.TAPSV
#pragma parameter GLOW_FALLOFF_V "Vertical Glow Grade" 0.35 0.00 1.5 0.02 
#define GLOW_FALLOFF_V params.GLOW_FALLOFF_V

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

#define kernel(x) exp(-GLOW_FALLOFF_V * (x) * (x))

void main()
{
	float ratio = COMPAT_TEXTURE(RotPass, vec2(0.5,0.1)).a;
	if (vTexCoord.y > ratio) discard;	
	
	vec3 col = vec3(0.0);
	float dy = SourceSize.w;

	float k_total = 0.;
	for (float i = -TAPSV; i <= TAPSV; i++)
		{
		float k = kernel(i);
		k_total += k;
		col += k * COMPAT_TEXTURE(Source, vTexCoord + vec2(0.0, float(i) * dy)).rgb;
		}
   FragColor = vec4(col / k_total, ratio);
}