#version 450

/*
	Lanczos2 in 5-taps (Fast) - adapted by Hyllian - 2024

	Adapted from these bicubic sources:

	See http://vec3.ca/bicubic-filtering-in-fewer-taps/ for more details
	Bicubic Sources: https://www.shadertoy.com/view/styXDh
	http://www.profhua.com/Sub/Article/BicubicFiltering/BicubicFiltering.html

	ATENTION: This code only work using LINEAR filter sampling set on Retroarch!

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float AR_STRENGTH;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter AR_STRENGTH "Anti-Ringing Strength" 1.0 0.0 1.0 0.05
#define AR_STRENGTH params.AR_STRENGTH

#define pi    3.1415926535897932384626433832795
#define FIX(c) (max(abs(c), 1e-5))

vec2 sinc(vec2 x) { return sin(pi*x)/(pi*x); }
vec4 sinc(vec4 x) { return sin(pi*x)/(pi*x); }

vec2 lanczos2(vec2 x) { x=FIX(x); return sinc(x) * sinc(x * 0.5); }
vec4 lanczos2(vec4 x) { x=FIX(x); return sinc(x) * sinc(x * 0.5); }


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;



void main()
{
    // We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
    // down the sample location to get the exact center of our "starting" texel. The starting texel will be at
    // location [1, 1] in the grid, where [0, 0] is the top left corner.
    vec2 iTc = vTexCoord * params.SourceSize.xy;

    vec2 tc = floor(iTc - vec2(0.5)) + vec2(0.5);

    // Compute the fractional offset from our starting texel to our original sample location, which we'll
    // feed into the function to get our filter weights.
    vec2 f  = iTc - tc;

    vec2 w0  = lanczos2(f + vec2(1.));
    vec4 w12 = lanczos2(vec4(f, vec2(1.) - f));

    vec2 w[3];
    vec2 Sample[3];

    mat3x2 v;

    w[0] = w0;
    w[1] = w12.xy + w12.zw;
    w[2] = vec2(1.) - w[0] - w[1];

    Sample[0] = (tc       - vec2(1.)) * params.SourceSize.zw;
    Sample[1] = (tc + w12.zw / w[1] ) * params.SourceSize.zw;
    Sample[2] = (tc       + vec2(2.)) * params.SourceSize.zw;


    vec3 CT = texture(Source, vec2(Sample[1].x, Sample[0].y)).rgb;    
    vec3 CL = texture(Source, vec2(Sample[0].x, Sample[1].y)).rgb;    
    vec3 CC = texture(Source, vec2(Sample[1].x, Sample[1].y)).rgb;    
    vec3 CR = texture(Source, vec2(Sample[2].x, Sample[1].y)).rgb;    
    vec3 CB = texture(Source, vec2(Sample[1].x, Sample[2].y)).rgb;

    vec4 SW4 = vec4(w[1].x, w[0].x, w[1].x, w[2].x) * vec4(w[0].y, w[1].y, w[1].y, w[1].y);

    float SW = w[1].x * w[2].y;

    vec3 color = mat4x3(CT, CL, CC, CR) * SW4 + CB * SW;

    color = color/(dot(SW4, vec4(1.)) + SW);

    // Anti-ringing
    vec3 aux = color;
    vec3 min_sample = min(min(min(CC,CT), CL), min(CR, CB));
    vec3 max_sample = max(max(max(CC,CT), CL), max(CR, CB));
    color = clamp(color, min_sample, max_sample);
    color = mix(aux, color, AR_STRENGTH*step(0.0, (CL-CC)*(CC-CR)+(CB-CC)*(CC-CT)));

    FragColor = vec4(color, 1.0);
}
