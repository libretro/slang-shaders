#version 450

/*
	Bicubic B-Spline 4-taps (Fast) - ported by Hyllian - 2020

	The following code is licensed under the MIT license: https://gist.github.com/TheRealMJP/bc503b0b87b643d3505d41eab8b332ae

	Samples a texture with B-Spline filtering, using only 4 texture fetches instead of 16.
	See http://vec3.ca/bicubic-filtering-in-fewer-taps/ for more details

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
   vTexCoord = TexCoord;
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
    vec2 samplePos = vTexCoord * params.SourceSize.xy;
    vec2 tc = floor(samplePos - 0.5) + 0.5;

    // Compute the fractional offset from our starting texel to our original sample location, which we'll
    // feed into the B-Spline function to get our filter weights.
    vec2 f = samplePos - tc;
    vec2 f2 = f * f;
    vec2 f3 = f2 * f;

    // Compute the B-Spline weights using the fractional offset that we calculated earlier.
    // These equations are pre-expanded based on our knowledge of where the texels will be located,
    // which lets us avoid having to evaluate a piece-wise function.
    vec2 w0 = f2 - 0.5 * (f3 + f);
    vec2 w1 = 1.5 * f3 - 2.5 * f2 + 1.0;
    vec2 w2 = -1.5 * f3 + 2. * f2 + 0.5 * f;
 //   vec2 w3 = 0.5 * (f3 - f2);
    vec2 w3 = 1.0 - w0 - w1 - w2; // The sum of weights must be one.

    // Work out weighting factors and sampling offsets that will let us use bilinear filtering to
    // simultaneously evaluate the 2 samples each from the 4x4 grid.
    vec2 s0 = w0 + w1;
    vec2 s1 = w2 + w3;
    vec2 f0 = w1 / s0;
    vec2 f1 = w3 / s1;

    // Compute the final UV coordinates we'll use for sampling the texture
    vec2 t0 = tc - 1. + f0;
    vec2 t1 = tc + 1. + f1;

    t0 *= params.SourceSize.zw;
    t1 *= params.SourceSize.zw;

    vec4 c0 = texture(Source, vec2(t0.x, t0.y));
    vec4 c1 = texture(Source, vec2(t1.x, t0.y));
    vec4 c2 = texture(Source, vec2(t0.x, t1.y));
    vec4 c3 = texture(Source, vec2(t1.x, t1.y));

    FragColor = (c0 * s0.x + c1 * s1.x) * s0.y + (c2 * s0.x + c3 * s1.x) * s1.y;
}