#version 450

/*
   GBA Fast Color Fix shader
   Author: crashGG
   License: Public Domain

   Fast approximation of NSO GBA color correction.
   Fixes washed-out and overbright colors with a low ALU cost.

   Technical Details:
   - Uses the official NSO GBA matrix for linear space.
   - Derives a custom NSO-weighted sqrt matrix for non-linear space.
   - Applies a quadratic curve transition for the darkness slider.
   - Low runtime overhead.
*/

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
	float darkness;
} params;

#pragma parameter darkness "Screen Darkness" 0.75 0.0 1.0 0.05

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

// Nintendo Switch Online's GBA
const mat3 NSO_sRGB = mat3(
    0.865,  0.0575, 0.0575,
    0.1225, 0.925,  0.1225,
    0.0125, 0.0125, 0.82
);

// Nintendo Switch Online's GBA sqrt matrix
// Main RGB channels use square root
// Cross-channel crosstalk matches the original matrix weight ratios
const mat3 NSO_sRGB_sqrt = mat3(
    0.9300, 0.0293, 0.0302,
    0.0635, 0.9618, 0.0643,
    0.0065, 0.0064, 0.9055
);

void main()
{

	vec3 texel = texture(Source, vTexCoord).rgb;

	vec3 srgbCol = NSO_sRGB_sqrt * texel;
	vec3 linCol  = NSO_sRGB * (texel * texel);
	float darkVal = params.darkness;

	FragColor = vec4(mix(srgbCol,linCol,darkVal), 1.0);
}
