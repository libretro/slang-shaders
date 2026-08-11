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
    float compYlevl;
    float compXlevl;
    float densY;
} params;

#pragma parameter compYlevl "Weave Intensity (Vertical)" 20.0 0.0 80.0 1.0
#pragma parameter compXlevl "Weave Intensity (Horizontal)" 4.0 0.0 20.0 1.0
#pragma parameter densY "Weave Density (Vertical)" 2.0 1.0 2.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

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
    float compY = params.compYlevl * 0.005;
    float compX = params.compXlevl * 0.005;
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

    // BT.601 luma weights
    vec3 luma_weight = vec3(0.299, 0.587, 0.114);
    float lumaC = dot(texel, luma_weight);
    float lumaU = dot(tex_U, luma_weight);
    float lumaD = dot(tex_D, luma_weight);
    float lumaL = dot(tex_L, luma_weight);
    float lumaR = dot(tex_R, luma_weight);

    // X-axis edge luma delta (signed to track bright vs dark cycles)
    float diffL = (lumaC - lumaL) * sign(waveX);
    float diffR = (lumaC - lumaR) * sign(waveX);
	// In dark cycles, center texel cannot be darker than neighbors based on compX threshold.
	// In bright cycles, center texel cannot be brighter than neighbors based on compX threshold.
	// Otherwise, drop the filter and roll back to raw texel.
	// diffL < compX && diffR < compX
    float modX  = compX * waveX * step(max(diffL, diffR), compX);

	// Y-axis hard edge detection (compY threshold)
	// Dark cycle only, no signs needed
    float isHardEdgeY = step(compY, max(lumaU, lumaD) - lumaC);

	// Remaps [ -0.77, -0.91 ] -> [ 0.0, 0.61804 ]
	float slide_factor = clamp(waveY * -7.142857 - 5.5, 0.0, 1.0) * 0.61804;

	float weaveFadeY = mix(1.0, slide_factor, isHardEdgeY);

    // Final Y-axis modulation factor
    float modY = compY * waveY * weaveFadeY;

    // Sum up X and Y axis modulation
    float total_fluctuation = modX + modY;

    // Halftone dynamic texture falloff: Tracks how far RGB deviates from mid-gray (0.5) to fade out details at extreme luma values.
    vec3 dist = abs(texel - 0.5) * 2.0; 
    
    // Final luma and color composition
    vec3 final_brightness = 1.0 + total_fluctuation * (1.0 - dist);
    vec3 woven_texel = texel * final_brightness;

    FragColor = vec4(woven_texel, 1.0);
}
