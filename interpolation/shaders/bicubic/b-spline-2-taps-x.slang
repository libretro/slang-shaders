#version 450

/*
	Bicubic B-Spline 4-taps (Fast) - ported by Hyllian - 2025

	The following code is licensed under the MIT license: https://gist.github.com/TheRealMJP/bc503b0b87b643d3505d41eab8b332ae

	Samples a texture with B-Spline filtering, using only 4 texture fetches instead of 16.
	See http://vec3.ca/bicubic-filtering-in-fewer-taps/ for more details
	Implementation: https://www.shadertoy.com/view/styXDh

	ATENTION: This code only work using LINEAR filter sampling set on Retroarch!

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

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
   vTexCoord = TexCoord + vec2(0.0001, 0.0);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


void main()
{
    float iTc = vTexCoord.x * params.SourceSize.x;
    float tc  = floor(iTc - 0.5) + 0.5;
    float fp  = iTc - tc;

    vec3 f  = vec3(1. + fp, fp, 2. - fp);
    vec3 f2 = f * f;
    vec3 f3 = f2 * f;

    float w0 = (  -f3.x + 6.*f2.x - 12.*f.x + 8.)/6.0;
    float w1 = (3.*f3.y - 6.*f2.y           + 4.)/6.0;
    float w2 = (  -f3.z + 6.*f2.z - 12.*f.z + 8.)/6.0;

    vec2 Weight = vec2(w0 + w1, 1 - w0 - w1);
    vec2 Sample = vec2(tc - 1. + w1/Weight.x, tc + 1. + w2/Weight.y) * params.SourceSize.z;

    vec3 C0 = texture(Source, vec2(Sample.x, vTexCoord.y)).rgb;    
    vec3 C1 = texture(Source, vec2(Sample.y, vTexCoord.y)).rgb;    

    vec3 color = mat2x3(C0, C1) * Weight;

    FragColor = vec4(color, 1.0);
}
