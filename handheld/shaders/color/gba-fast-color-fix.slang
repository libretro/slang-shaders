#version 450

/*
   GBA Fast Color Fix shader
   Author: crashGG
   License: Public Domain

   A high-throughput GBA color grading shader optimized for maximum GPU efficiency.
   Corrects overbright, bleached colors via a lightweight 1st-degree linear span.

   Technical Details:
   - Uses a symmetrical, 1st-degree linear pivot curve across RGB channels.
   - Keeps 0.0 and 1.0 limits untouched to prevent color clipping, channel hard-clipping distortion, and shadow crushing.
   - Fixes washed-out GBA colors using simple mathematical logic.
   - low runtime overhead.

   can deliver results comparable other GBA-color fix shaders.
*/

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
	float paletteFix;
} params;

// RGB color restoration: 0.0 = stock washed-out, 1.0 = maximum restoration.
#pragma parameter paletteFix "Color Restoration" 0.75 0.0 1.0 0.01

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

    vec3 texel = texture(Source, vTexCoord).rgb;

	// Smoothly dampens brightness based on white-point distance
	vec3 final_brightness = 1.0 -  (1.0 - texel) * params.paletteFix;

	// final out
    FragColor = vec4(texel * final_brightness, 1.0);
}
