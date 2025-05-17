#version 450

/*
	Lanczos2 in 3-taps (Fast) - adapted by Hyllian - 2025

	See http://vec3.ca/bicubic-filtering-in-fewer-taps/ for more details
	Source: https://www.shadertoy.com/view/styXDh
	http://www.profhua.com/Sub/Article/BicubicFiltering/BicubicFiltering.html

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

#define pi    3.1415926535897932384626433832795
#define FIX(c) (max(abs(c), 1e-5))

vec3 sinc(vec3 x) { return sin(pi*x)/(pi*x); }

vec3 lanczos2(vec3 x) { x=FIX(x); return sinc(x) * sinc(x * 0.5); }

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
    float iTc = vTexCoord.y * params.SourceSize.y;
    float tc  = floor(iTc - 0.5) + 0.5;
    float fp  = iTc - tc;

    vec3 wgt = lanczos2(vec3(1 + fp, fp, 1 - fp));

    wgt.y += wgt.z;

    vec3 Sample = vec3(tc - 1, tc + wgt.z / wgt.y, tc + 2) * params.SourceSize.w;

    wgt.z = 1 - wgt.x - wgt.y;

    vec3 C0 = texture(Source, vec2(vTexCoord.x, Sample.x)).rgb;    
    vec3 C1 = texture(Source, vec2(vTexCoord.x, Sample.y)).rgb;    
    vec3 C2 = texture(Source, vec2(vTexCoord.x, Sample.z)).rgb;

    vec3 color = mat3(C0, C1, C2) * wgt;

    // Anti-ringing
    vec3 aux = color;
    vec3 min_sample = min(min(C0,C1), C2);
    vec3 max_sample = max(max(C0,C1), C2);
    color = clamp(color, min_sample, max_sample);
    color = mix(aux, color, step(0.0, (C0-C1)*(C1-C2)));

    FragColor = vec4(color, 1.0);
}
