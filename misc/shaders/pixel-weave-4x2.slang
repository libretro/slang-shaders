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
  - X-axis grain texture: Generated in a 2 physical pixel cycle of {-1, +1} to emulate micro-fabric noise.
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
    float compYlevl;
    float compXlevl;
} params;

#pragma parameter compYlevl "Weave Intensity (Vertical)" 15.0 0.0 80.0 1.0
#pragma parameter compXlevl "Weave Intensity (Horizontal)" 4.0 0.0 20.0 1.0

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

    // Local variable mappings
    float compY = params.compYlevl * 0.005;
    float compX = params.compXlevl * 0.005;
    vec2 pixel_step = params.OutputSize.zw;	// Screen step size in physical pixels (1.0 / OutputSize.xy)

    // 5-Tap neighbor texture fetch
    vec3 texel = texture(Source, vTexCoord).rgb;
    vec3 tex_U = texture(Source, vTexCoord + vec2( 0.0, -pixel_step.y )).rgb;
    vec3 tex_D = texture(Source, vTexCoord + vec2( 0.0,  pixel_step.y )).rgb;
    vec3 tex_L = texture(Source, vTexCoord + vec2( -pixel_step.x, 0.0 )).rgb;
    vec3 tex_R = texture(Source, vTexCoord + vec2(  pixel_step.x, 0.0 )).rgb;

    // BT.601 luma weights
    vec3 luma_weight = vec3(0.299, 0.587, 0.114);
    float lumaC = dot(texel, luma_weight);
    float lumaU = dot(tex_U, luma_weight);
    float lumaD = dot(tex_D, luma_weight);
    float lumaL = dot(tex_L, luma_weight);
    float lumaR = dot(tex_R, luma_weight);

    // Wave generators
    // Driven by physical screen coordinate gl_FragCoord.
    // Y-axis +0.25 offset equals 1 physical pixel shift, creating a {-1, +1, +1, -1} cycle to force the first row to -1.
    // X-axis has a {-1.0, +1.0} cycle.
    vec2 phase = fract(gl_FragCoord.xy * vec2(0.5, 0.25) + vec2(0.0, 0.25));
    vec2 wave  = step(0.5, phase) * 2.0 - 1.0;

    // Edge luma delta (signed to track bright vs dark cycles)
    float diffU = (lumaC - lumaU) * sign(wave.y);
    float diffD = (lumaC - lumaD) * sign(wave.y);
    float diffL = (lumaC - lumaL) * sign(wave.x);
    float diffR = (lumaC - lumaR) * sign(wave.x);

    // Amplitude modulation
	// In dark cycles, center texel cannot be darker than neighbors based on compXY threshold.
	// In bright cycles, center texel cannot be brighter than neighbors based on compXY threshold.
	// Otherwise, drop the filter and roll back to raw texel.
    float modY  = compY * wave.y * float(diffU < compY && diffD < compY);
    float modX  = compX * wave.x * float(diffL < compX && diffR < compX);

    // Dynamic texture falloff: Tracks how far RGB deviates from mid-gray (0.5) to fade out details at extreme luma values.
    vec3 dist = abs(texel - 0.5) * 2.0;
    vec3 final_brightness = 1.0 + (modX + modY) * (1.0 - dist);

    // Final luma and color composition
    FragColor = vec4(texel * final_brightness, 1.0);
}
