#version 450

/*
	Anti-Flicker Shader
	Original by hunterk
	License: Public Domain
	
	This shader detects large variations in luminance from frame to frame
	and then blends frames to smooth the transition. In flicker-based
	shadow effects, this should result in true transparency.

	====================================================================
	Extended & Optimized by crashGG
	
	Key enhancements:
	- Expanded the frame history to build a more stable temporal detection chain.
	- Added an alternating frame color-lock to prevent false positives and tracking errors.
	- Swapped to BT.601 luma weights to properly match 16bit and CRT-era specifications.
	- Implemented 1st-order Taylor series expansion to replace expensive pow() calls.
	- Added an adjustable Flicker detection window to skip processing outside range.
*/

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float thresh;
    float startRow;
    float endRow;
} params;

#pragma parameter thresh "Luma Diff Threshold" 0.20 0.0 1.0 0.01
#pragma parameter startRow "Flicker detection start row (%)" 0.00 0.0 1.0 0.01
#pragma parameter endRow   "Flicker detection end row (%)" 1.00 0.0 1.0 0.01

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
layout(set = 0, binding = 2) uniform sampler2D Original;
layout(set = 0, binding = 3) uniform sampler2D OriginalHistory1;
layout(set = 0, binding = 4) uniform sampler2D OriginalHistory2;
layout(set = 0, binding = 5) uniform sampler2D OriginalHistory3;
layout(set = 0, binding = 6) uniform sampler2D OriginalHistory4;
layout(set = 0, binding = 7) uniform sampler2D OriginalHistory5;

void main()
{
    // Local variable mappings
    float thresh   = params.thresh;
    float startRow = params.startRow;
    float endRow   = params.endRow;

    vec3 curr0 = texture(Original, vTexCoord).rgb;
    vec3 prev1 = texture(OriginalHistory1, vTexCoord).rgb;
    vec3 prev2 = texture(OriginalHistory2, vTexCoord).rgb;
    vec3 prev3 = texture(OriginalHistory3, vTexCoord).rgb;
    vec3 prev4 = texture(OriginalHistory4, vTexCoord).rgb;
    vec3 prev5 = texture(OriginalHistory5, vTexCoord).rgb;

    // Bounds check: active only within [startRow, endRow] Y-range
    float isInRegion = step(startRow, vTexCoord.y) * step(vTexCoord.y, endRow);
    
    // BT.601 luma weights
    const vec3 luma_weight = vec3(0.299, 0.587, 0.114);
    float curr0Luma = dot(curr0, luma_weight);
    float prev1Luma = dot(prev1, luma_weight);
    float prev2Luma = dot(prev2, luma_weight);
    float prev3Luma = dot(prev3, luma_weight);
    float prev4Luma = dot(prev4, luma_weight);
    float prev5Luma = dot(prev5, luma_weight);
    
    // Interlaced frame lock: even/odd 3-frame sequences must match
    bool chain024 = abs(curr0Luma - prev2Luma) < 0.01 && abs(prev2Luma - prev4Luma) < 0.01;
    bool chain135 = abs(prev1Luma - prev3Luma) < 0.01 && abs(prev3Luma - prev5Luma) < 0.01;

    bool flicker = bool(isInRegion)
                && (chain024 || chain135)
                && (abs(curr0Luma - prev1Luma) > thresh)
                && (abs(prev2Luma - prev3Luma) > thresh)
                && (abs(prev4Luma - prev5Luma) > thresh);
				   
	// Base summation & delta with dark-end curvature adjustment & noise-gating lock
	vec3 sum = max(curr0, vec3(0.05)) + max(prev1, vec3(0.05));
	vec3 inv_sum = vec3(1.0) / sum;
	vec3 diff = curr0 - prev1;

	// 1st-order Taylor series expansion
	vec3 blendedRgb = sum * 0.5 + diff * diff * inv_sum * 0.25;

    vec3 finalRgb = flicker ? blendedRgb : curr0;
    
    FragColor = vec4(finalRgb, 1.0);
}
