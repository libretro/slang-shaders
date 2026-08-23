#version 450

/*
  pixel-weave-sync Shader
  Author: crashGG
  License: MIT

  [ Design Goal ]
  Built for upscale retro gaming on modern hi-res displays (2K/4K+).
  Works best at 8x scaling or higher.
  This is not a traditional scanline filter.
  No fake CRT screen bending, no heavy black lines.

  [ Visual Effect ]
  Uses halftone space blending logic. 
  Adds a subtle, breathing physical surface texture to flat color areas.
  Creates a linen-like canvas or fine-woven fabric texture.

  [ Technical Features ]
  - Y-axis weave sync: No integer scaling required. Aligns perfectly with pixel and half-pixel boundaries to draw textures at pixel joints.
  - X-axis grain: Alternates per single physical pixel to emulate micro-fabric noise.
  - Smart edge shielding: 5-Tap neighbor pixel check to kill overexposure and harsh artifacts at macro boundaries.
  - Halftone-style dynamic falloff: Mimics physical halftone dots and matches human luma/chroma perception models. Fades out details at extreme highlights and deep shadows.

  [ Inspiration ]
  Inspired by vintage halftone printing.
  Uses a micro high-frequency grid to enrich macro color depth and image detail.
*/

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float compY;
    float compX;
    float densY;
} params;

#pragma parameter compY "Weave Intensity (Vertical)" 0.12 0.0 0.40 0.01
#pragma parameter compX "Weave Intensity (Horizontal)" 0.04 0.0 0.10 0.01
#pragma parameter densY "Weave Density (Vertical)" 2.0 1.0 2.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

#define pi 3.14159265358979323846

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
	// Local variable mappings
	float compY = params.compY;
	float compX = params.compX;
	float scaleFactor = params.OriginalSize.y * params.OutputSize.w * params.densY;
	vec2 pixel_step = params.OutputSize.zw;	// Screen step size in physical pixels (1.0 / OutputSize.xy)

	// 5-Tap neighbor texture fetch
	vec3 texel = texture(Source, vTexCoord).rgb;
	vec3 tex_U = texture(Source, vTexCoord + vec2( 0.0, -pixel_step.y )).rgb;
	vec3 tex_D = texture(Source, vTexCoord + vec2( 0.0,  pixel_step.y )).rgb;
	vec3 tex_L = texture(Source, vTexCoord + vec2( -pixel_step.x, 0.0 )).rgb;
	vec3 tex_R = texture(Source, vTexCoord + vec2(  pixel_step.x, 0.0 )).rgb;

	// Y-axis cosine wave generator [-1.0, 1.0]
	// Inverted to align the weave pattern perfectly with the original pixel grid.
	// Driven by physical screen coordinate gl_FragCoord.
	// Explicit fract() prevents FP32 range clipping artifacts at high resolutions: cos(2π⋅fract(A))≡cos(2πA)
	float phaseY = fract(gl_FragCoord.y * scaleFactor);
	float waveY  = -cos(2.0 * pi * phaseY); 

	// X-axis binary square wave generator {-1.0, +1.0}
	float phaseX = fract(gl_FragCoord.x * 0.5);
	float waveX = step(0.5, phaseX) * 2.0 - 1.0;

	// X-axis edge luma delta (signed to track bright vs dark cycles)
	vec3 diffU = (texel - tex_U) * sign(waveY);
	vec3 diffD = (texel - tex_D) * sign(waveY);
	vec3 diffL = (texel - tex_L) * sign(waveX);
	vec3 diffR = (texel - tex_R) * sign(waveX);

	// Boundary determination
	// In dark cycles, center R/G/B cannot be darker than neighbors(based on threshold).
	// In bright cycles, center R/G/B cannot be brighter than neighbors(based on threshold).
	// R/G/B		diffU , diffD , diffL , diffR < threshold
	vec3 simUD = step(max(diffU, diffD), vec3(compY*0.381966));
	vec3 simLR = step(max(diffL, diffR), vec3(compX*0.381966));

	// remap [ -0.77, -0.91 ] -> [ 0.0, 0.618 ]
	// remap [  0.77,  0.91 ] -> [ 0.0, 0.618 ]
	float slide_factor = clamp(abs(waveY) * 7.142857 - 5.5, 0.0, 1.0) * 0.618034;

	vec3 weaveFadeY = mix(vec3(slide_factor), vec3(1.0), simUD);

	vec3 modY = compY * waveY * weaveFadeY;
	vec3 modX = compX * waveX * simLR;

	// Halftone shadow
	vec3 shadowSQ = 2.0 * texel * (1.0 - texel);

	vec3 brightness_delta = (modX + modY) * shadowSQ;

	// Polynomial approximation based on 1st-order Taylor expansion
	vec3 finalColor = texel + texel * brightness_delta;

	FragColor = vec4(finalColor, 1.0);
}
