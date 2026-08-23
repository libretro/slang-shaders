#version 450

/*
  pixel-weave-4x2 Shader
  Author: crashGG
  License: MIT

  [ Design Goal ]
  Built for upscale retro gaming on 1080p/2K/4K+ displays.
  A universal fallback variant of the pixel-weave-sync shader.
  Made for cases without high scaling factors.
  Works for arbitrary or non-integer scaling.
  This is not a traditional scanline filter.
  No fake CRT screen bending, no heavy black lines.

  [ Visual Effect ]
  Uses halftone space blending logic.
  Adds a subtle, breathing physical surface texture to flat color areas.
  Creates a linen-like canvas or fine-woven fabric texture.

  [ Technical Features ]
  - Y-axis weave texture: Generated in a 4 physical pixel cycle of {-1, +1, +1, -1}. Does not strictly align with raw pixel or half-pixel boundaries.
  - X-axis grain texture: Generated in a 2 physical pixel cycle of {-1, +1} to emulate micro-fabric noise(Optional the same period as Y-axis).
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
	float densX;
} params;

#pragma parameter compY "Weave Intensity (Vertical)" 0.12 0.0 0.40 0.01
#pragma parameter compX "Weave Intensity (Horizontal)" 0.04 0.0 0.10 0.01
#pragma parameter densX "Weave Density  (Horizontal)" 1.0 0.5 1.0 0.5

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

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
	float densX = params.densX * 0.5;

	vec2 pixel_step = params.OutputSize.zw;	// Screen step size in physical pixels (1.0 / OutputSize.xy)

	// 5-Tap neighbor texture fetch
	vec3 texel = texture(Source, vTexCoord).rgb;
	vec3 tex_U = texture(Source, vTexCoord + vec2( 0.0, -pixel_step.y )).rgb;
	vec3 tex_D = texture(Source, vTexCoord + vec2( 0.0,  pixel_step.y )).rgb;
	vec3 tex_L = texture(Source, vTexCoord + vec2( -pixel_step.x, 0.0 )).rgb;
	vec3 tex_R = texture(Source, vTexCoord + vec2(  pixel_step.x, 0.0 )).rgb;

	// Wave generators
	// Driven by physical screen coordinate gl_FragCoord.
	// +0.25 offset equals 1 physical pixel shift, creating a {-1, +1, +1, -1} cycle to force the first row to -1.
	vec2 phase = fract(gl_FragCoord.xy * vec2(densX, 0.25) + vec2(0.25, 0.25));
	vec2 wave  = step(0.5, phase) * 2.0 - 1.0;

	// neighbor RGB delta (signed to track bright and dark cycles)
	vec3 diffU = (texel - tex_U) * sign(wave.y);
	vec3 diffD = (texel - tex_D) * sign(wave.y);
	vec3 diffL = (texel - tex_L) * sign(wave.x);
	vec3 diffR = (texel - tex_R) * sign(wave.x);

	// Boundary determination
	// In dark cycles, center R/G/B cannot be darker than neighbors(based on threshold).
	// In bright cycles, center R/G/B cannot be brighter than neighbors(based on threshold).
	// Otherwise, drop the filter and roll back to raw R/G/B.
	// R/G/B		diffU , diffD , diffL , diffR < golden threshold
	vec3 simUD = step(max(diffU, diffD), vec3(compY*0.381966));
	vec3 simLR = step(max(diffL, diffR), vec3(compX*0.381966));

	vec3 modY  = compY * wave.y * simUD;
	vec3 modX  = compX * wave.x * simLR;

	// Halftone shadow
	vec3 shadowSQ = 2.0 * texel * (1.0 - texel);

	vec3 brightness_delta = (modX + modY) * shadowSQ;

	// Polynomial approximation based on 1st-order Taylor expansion
	vec3 finalColor = texel + texel * brightness_delta;

	FragColor = vec4(finalColor, 1.0);
}
