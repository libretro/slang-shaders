#version 450

/*
Scanline Modern Lossless Dynamic Quantization Shader

This shader is not designed to simply simulate the scanline + cross grid effect of old CRT monitors. 
Instead, it aims to combine the advantages of sharp clarity on modern displays with retro games, 
enabling better pixel-level scaling.
The generation intensity of scanlines is dynamically quantized and adjusted based on the human eye's 
perceptual curve for chromatic brightness, rather than using rigid stripe overlay.

Core Features:
- Supports independent adjustment of vertical scanline and horizontal crossline intensity/density, 
  adapting to different resolutions (1080P/4K / high-magnification scaling);
- Default parameters are suitable for most pixel games scaled up on large modern 4K resolution screens, 
  with lossless brightness/color;
- Optimized scanline performance based on human eye brightness sensitivity curve: 
  scanlines are prominent in medium brightness areas and weakened in extreme brightness areas;
- Adjustable color channel quantization attenuation, suitable for games like GBA that have 
  hardware-encoded gamma bias (over-bright/grayed out) due to lack of backlighting. 
  It can perfectly restore vivid colors. 
  Practical testing shows better results than mainstream GBA color correction shaders on the market;

Human Eye Brightness-Chromatic Sensitivity Curve

Sensitivity
  ↑
  |    ↗  Peak Sensitivity (0.4-0.6)
  |   / \
  |  /   \
  | /     ↘ decrease at high brightness
  |/
  +----------------→ Brightness
  0  0.3   1.0
*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float sinCompX;
	float sinCompY;
	float densY;
	float densX;
	float colAtten;
} params;

#pragma parameter sinCompY "Scanline Intensity" 0.10 0.0 1.0 0.01
#pragma parameter sinCompX "Crossline Intensity" 0.02 0.0 0.10 0.01
#pragma parameter densY "Scanline Density" 2.0 1.0 6.0 1.0		// Scanline density: 1 for 1080P, 2 for 4K displays, 3 for denser lines
#pragma parameter densX "Crossline Density" 1.0 0.5 1.0 0.5		// Density of lines crossing scanlines: 1 for maximum density, 0.5 for half density
#pragma parameter colAtten "Colorimetric attenuation" 0.0 0.0 2.0 0.05	// RGB chromatic quantization attenuation: 0 = no attenuation - 2.0 = maximum attenuation.

#define sinCompX params.sinCompX
#define sinCompY params.sinCompY
#define densY params.densY
#define densX params.densX
#define colAtten params.colAtten

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#define pi 3.141592654

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 omega;

void main()
{
   gl_Position = global.MVP * Position; // Vertex coordinate transformation (standard MVP matrix)
   vTexCoord = TexCoord*1.0001; // Slightly scale up texture coordinates to avoid black edges at borders
   // Calculate angular frequency: controls the period (density) of the sine wave
   // 1.999 Slightly deviate from integer multiple angular frequency of 2.0 to avoid rigid stripes 
   // caused by strict alignment between scanlines and pixel grid
   // Important distinction: Use OutputSize.x for X-axis to make horizontal grids "fill the output screen" 
   // generating uniformly distributed horizontal grids covering the final display image, rather than following the original source material
   omega = vec2(pi * params.OutputSize.x * densX, 1.999 * pi * params.SourceSize.y * densY);	
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 omega;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
   vec2 sine_comp = vec2(sinCompX, sinCompY);
   vec3 res = texture(Source, vTexCoord).xyz;

   // Step 1: Calculate periodic offset of texture coordinates (provides periodic input for sine wave, vec2 type, corresponding to horizontal/vertical directions)
   // vTexCoord: Texture coordinates [0,1], omega: Angular frequency (determines scanline density)
   // Result: Periodic values for horizontal/vertical directions respectively, used to generate uniformly distributed sine waves
   vec2 tex_omega_product = vTexCoord * omega;

   // Step 2: Calculate sine wave fluctuations for horizontal/vertical directions (core, generates periodic brightness changes, vec2 type)
   // sin(): GLSL built-in sine function, output range [-1.0, 1.0]
   // Result: Sine wave fluctuation values for horizontal (x) and vertical (y) directions respectively
   vec2 sine_wave = sin(tex_omega_product);

   // Step 3: Modulate the intensity of sine waves (controls the amplitude of horizontal/vertical fluctuations, vec2 type)
   // Component-wise multiplication: horizontal fluctuation = X*sin(x), vertical fluctuation = Y*sin(y), enabling controllable intensity
   vec2 scaled_sine_wave = sine_comp * sine_wave;

   // Step 4: Combine horizontal/vertical sine wave fluctuations (convert vec2 to scalar float to get total fluctuation value)
   // dot(vec2, vec2): Dot product function, calculation rule = component1 multiplication + component2 multiplication (i.e., x1*y1 + x2*y2)
   // Equivalent to: scaled_sine_wave.x * 1.0 + scaled_sine_wave.y * 1.0 = horizontal fluctuation + vertical fluctuation
   // Result: Single float value representing total brightness fluctuation increment caused by sine wave (range approximately [-(X+Y), X+Y])
	float total_sine_fluctuation = scaled_sine_wave.x + scaled_sine_wave.y;

	// Step 5: Calculate squared distance between res and midpoint value 0.5
	vec3 dist_linear = abs(res - 0.5) * 2.0; // First calculate linear distance dist_linear: 0-1
	vec3 dist = dist_linear * dist_linear;   // Then calculate squared distance (conforms to human eye observation curve)

   // Step 6: Calculate final brightness modulation coefficient
   // 1) 1.0 - ((sinCompX+sinCompY) * (1.0 - dist) * colAtten) → Attenuate extreme brightness based on chromatic attenuation
   // 2) + total_sine_fluctuation * (1.0 - dist) → Superimpose scanline brightness fluctuations weighted by sensitivity curve
	vec3 final_brightness = 1.0 - ((sinCompX+sinCompY) * (1.0 - dist) * colAtten) + total_sine_fluctuation * (1.0 - dist);

   vec3 scanline = res * final_brightness;

   FragColor = vec4(scanline, 1.0);
}