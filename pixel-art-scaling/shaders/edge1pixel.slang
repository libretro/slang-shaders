#version 450

// Interpolate a single row of display pixels between each pair of adjacent source pixels.
// by decavoid


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
layout(location = 1) out vec2 inverseScale;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   inverseScale = vec2(params.OriginalSize.xy / params.OutputSize.xy);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 inverseScale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

vec2 isInside(vec2 v, vec2 left, vec2 right)
{
	return step(left, v) - step(right, v);
}

// uncomment to see a red grid of modified pixels
//#define DEBUG_DRAW_EDGES

void main()
{
	vec2 pixelCoords = vTexCoord * params.SourceSize.xy; // NES x: [0; 256], y: [0; 240]
	vec2 coordAtPixelCenter = (floor(pixelCoords) + vec2(0.5));
	vec2 coordBetweenPixels = round(pixelCoords);
	vec2 f = fract(pixelCoords) + vec2(1e-4);
	vec2 isFractionInside = isInside(f, 0.5 * inverseScale, 1.0 - 0.5 * inverseScale);

/*
	Equivalent:
	if (isFractionInside.x)
	{
		// shift coord to the nearest pixel center to prevent interpolation
		newCoord.x = coordAtPixelCenter.x;
	}
	else
	{
		// shift exactly between pixels for perfect interpolation
		newCoord.x = coordBetweenPixels.x;
	}
*/

	vec2 newCoord = isFractionInside * coordAtPixelCenter + (1 - isFractionInside) * coordBetweenPixels;
	vec2 newTexCoord = newCoord / params.SourceSize.xy;
	FragColor = texture(Source, newTexCoord);

#ifdef DEBUG_DRAW_EDGES
	if (isFractionInside.x + isFractionInside.y < 2)
		FragColor.r = 1;
#endif
}
