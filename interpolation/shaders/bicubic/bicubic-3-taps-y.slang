#version 450

/*
	Bicubic 3-taps (Fast) - ported by Hyllian - 2025

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
	float B, C;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


#pragma parameter B "Bicubic Coeff B" 0.33 0.0 1.0 0.01
#pragma parameter C "Bicubic Coeff C" 0.33 0.0 1.0 0.01

#define B params.B
#define C params.C

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

    float tc = floor(iTc - 0.5) + 0.5;

    float fp = iTc - tc;

    vec3 f  = vec3(1. + fp, fp, 2. - fp);
    vec3 f2 = f * f;
    vec3 f3 = f2 * f;

    float w0 = (      (-B-6.*C)*f3.x     +(6.*B+30.*C)*f2.x+(-12.*B-48.*C)*f.x+(8.*B+24.*C))/6.0;
    float w1 = ((12.-9.*B-6.*C)*f3.y+(-18.+12.*B+6.*C)*f2.y+(6.-2.*B))/6.0;
    float w3 = (      (-B-6.*C)*f3.z     +(6.*B+30.*C)*f2.z+(-12.*B-48.*C)*f.z+(8.*B+24.*C))/6.0;
    float w2 = 1. - w0 - w1 - w3;

    vec3 Weight;
    vec3 Sample;

    Weight = vec3(w0, w1 + w2, w3);

    Sample = vec3(tc - 1., tc + w2 / Weight.y, tc + 2.) * params.SourceSize.w;

    vec3 C0 = texture(Source, vec2(vTexCoord.x, Sample.x)).rgb;    
    vec3 C1 = texture(Source, vec2(vTexCoord.x, Sample.y)).rgb;    
    vec3 C2 = texture(Source, vec2(vTexCoord.x, Sample.z)).rgb;

    vec3 color = mat3(C0, C1, C2) * Weight;

    FragColor = vec4(color, 1.0);
}
