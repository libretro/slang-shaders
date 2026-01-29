#version 450

// Filename: 3do-interpolation.slang
//
// Copyright (C) 2026 W. M. Martinez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

#pragma parameter INTERPOLATION_3DO_HEADER " —— 3DO Interpolation —— " 0.0 0.0 0.0 0.0
#pragma parameter INTERPOLATION_MODE "Interpolation mode (nearest, bilinear, original)" 2.0 0.0 2.0 1.0
#pragma parameter FAKE_CORNER_WEIGHTS "Simulate corner weights (off, on)" 1.0 0.0 1.0 1.0
#pragma parameter SPECIAL_INTERP_H "Apply special interpolation horizontally" 1.0 0.0 1.0 1.0
#pragma parameter SPECIAL_INTERP_V "Apply special interpolation vertically" 1.0 0.0 1.0 1.0
#pragma parameter DEBUG_SHOW_CORNERS "Debug: Show corner weight positions" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
    float INTERPOLATION_MODE;
    float FAKE_CORNER_WEIGHTS;
    float SPECIAL_INTERP_H;
    float SPECIAL_INTERP_V;
    float DEBUG_SHOW_CORNERS;
} params;

#define INTERPOLATION_MODE params.INTERPOLATION_MODE
#define FAKE_CORNER_WEIGHTS params.FAKE_CORNER_WEIGHTS
#define SPECIAL_INTERP_H params.SPECIAL_INTERP_H
#define SPECIAL_INTERP_V params.SPECIAL_INTERP_V
#define DEBUG_SHOW_CORNERS params.DEBUG_SHOW_CORNERS

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

vec4 nearest_neighbor(vec2 tc)
{
    return texture(Source, tc);
}

vec4 bilinear_interpolation(vec2 tc)
{
    vec2 sourceSize = params.SourceSize.xy;
    vec2 texelSize = 1.0 / sourceSize;
    
    // Get fractional part of texture coordinate
    vec2 f = fract(tc * sourceSize - 0.5);
    vec2 texCoord = (floor(tc * sourceSize - 0.5) + 0.5) / sourceSize;
    
    // Sample four corners
    vec4 p0q0 = texture(Source, texCoord);
    vec4 p1q0 = texture(Source, texCoord + vec2(texelSize.x, 0.0));
    vec4 p0q1 = texture(Source, texCoord + vec2(0.0, texelSize.y));
    vec4 p1q1 = texture(Source, texCoord + vec2(texelSize.x, texelSize.y));
    
    // Blend
    vec4 pq0 = mix(p0q0, p1q0, f.x);
    vec4 pq1 = mix(p0q1, p1q1, f.x);
    
    return mix(pq0, pq1, f.y);
}

// Determine which quadrant we are in within pixel space based on fractional position
// Returns quadrant info in out parameters
void get_pixel_quadrant(vec2 f, out int topBottom, out int rightLeft)
{
    // Determine quadrant based on which half of the pixel we're in
    topBottom = (f.y >= 0.5) ? 1 : 0;  // 0 = top, 1 = bottom
    rightLeft = (f.x < 0.5) ? 1 : 0;   // 0 = right, 1 = left
}

// Calculate luminance using standard coefficients
float get_luminance(vec3 color)
{
    return dot(color, vec3(0.299, 0.587, 0.114));
}

// Predict corner weights based on luminance gradients
void predict_corner_weights(vec2 texCoord, out int topBottom, out int rightLeft)
{
    vec2 texelSize = 1.0 / params.SourceSize.xy;
    
    // Sample center and neighbors
    vec3 center = texture(Source, texCoord).rgb;
    vec3 left = texture(Source, texCoord + vec2(-texelSize.x, 0.0)).rgb;
    vec3 right = texture(Source, texCoord + vec2(texelSize.x, 0.0)).rgb;
    vec3 top = texture(Source, texCoord + vec2(0.0, -texelSize.y)).rgb;
    vec3 bottom = texture(Source, texCoord + vec2(0.0, texelSize.y)).rgb;
    
    // Calculate luminances
    float lumCenter = get_luminance(center);
    float lumLeft = get_luminance(left);
    float lumRight = get_luminance(right);
    float lumTop = get_luminance(top);
    float lumBottom = get_luminance(bottom);
    
    // Determine horizontal bias: bias towards brighter direction
    // Add small epsilon to center for stability
    float horizThreshold = lumCenter + 0.01;
    if (lumLeft > horizThreshold && lumRight <= horizThreshold) {
        rightLeft = 1;  // Left is brighter, bias left
    } else if (lumRight > horizThreshold && lumLeft <= horizThreshold) {
        rightLeft = 0;  // Right is brighter, bias right
    } else {
        // Both similar or both darker, use average comparison
        rightLeft = (lumLeft >= lumRight) ? 1 : 0;
    }
    
    // Determine vertical bias: bias towards brighter direction
    float vertThreshold = lumCenter + 0.01;
    if (lumTop > vertThreshold && lumBottom <= vertThreshold) {
        topBottom = 0;  // Top is brighter, bias top
    } else if (lumBottom > vertThreshold && lumTop <= vertThreshold) {
        topBottom = 1;  // Bottom is brighter, bias bottom
    } else {
        // Both similar or both darker, use average comparison
        topBottom = (lumTop >= lumBottom) ? 0 : 1;
    }
}

// Sample texture and extract corner weight quadrant from alpha channel
// Returns: sampled color with quadrant info in out parameters
vec4 sample_with_quadrant(vec2 texCoord, out int topBottom, out int rightLeft)
{
    // Sample the pixel
    vec4 color = texture(Source, texCoord);
    
    if (FAKE_CORNER_WEIGHTS > 0.5) {
        // Predict corner weights from luminance
        predict_corner_weights(texCoord, topBottom, rightLeft);
    } else {
        // Extract from alpha channel
        // Convert alpha to integer (0-255)
        int alphaInt = int(color.a * 255.0);
        
        // Extract bits: bit 7 (MSB) for top/bottom, bit 6 for right/left
        topBottom = (alphaInt >> 7) & 1;  // 0 = top, 1 = bottom
        rightLeft = (alphaInt >> 6) & 1;  // 0 = right, 1 = left
    }
    
    return color;
}

// Calculate the position of a corner within a pixel based on corner weight quadrant
vec2 get_corner_position(vec2 pixelCenter, int topBottom, int rightLeft)
{
    vec2 texelSize = 1.0 / params.SourceSize.xy;
    vec2 cornerOffset;
    
    if (topBottom == 0 && rightLeft == 1) {
        // Top-left corner
        cornerOffset = vec2(-0.5, -0.5) * texelSize;
    } else if (topBottom == 0 && rightLeft == 0) {
        // Top-right corner
        cornerOffset = vec2(0.5, -0.5) * texelSize;
    } else if (topBottom == 1 && rightLeft == 1) {
        // Bottom-left corner
        cornerOffset = vec2(-0.5, 0.5) * texelSize;
    } else {
        // Bottom-right corner
        cornerOffset = vec2(0.5, 0.5) * texelSize;
    }
    
    return pixelCenter + cornerOffset;
}

// Debug visualization: show corner weight positions
vec4 debug_show_corners(vec2 tc)
{
    vec2 sourceSize = params.SourceSize.xy;
    vec2 texelSize = 1.0 / sourceSize;
    
    // Get fractional part of texture coordinate
    vec2 f = fract(tc * sourceSize - 0.5);
    vec2 texCoord = (floor(tc * sourceSize - 0.5) + 0.5) / sourceSize;
    
    // Sample source pixel and get its corner weight quadrant
    int srcTopBottom, srcRightLeft;
    vec4 sourceColor = sample_with_quadrant(texCoord, srcTopBottom, srcRightLeft);
    
    // Get the corner position
    vec2 cornerPos = get_corner_position(texCoord, srcTopBottom, srcRightLeft);
    
    // Calculate distance from current fragment to corner
    float distToCorner = distance(tc, cornerPos);
    
    // Create crosshair: bright where corner is, fade with distance
    float crosshairSize = 0.002; // Size of crosshair in texture space
    vec2 cornerPixelDist = abs(tc - cornerPos);
    float crosshairX = step(cornerPixelDist.y, crosshairSize);
    float crosshairY = step(cornerPixelDist.x, crosshairSize);
    float crosshair = max(crosshairX, crosshairY);
    
    // Color based on corner quadrant
    vec3 quadrantColor;
    if (srcTopBottom == 0 && srcRightLeft == 1) {
        quadrantColor = vec3(1.0, 0.0, 0.0); // Red = Top-left
    } else if (srcTopBottom == 0 && srcRightLeft == 0) {
        quadrantColor = vec3(0.0, 1.0, 0.0); // Green = Top-right
    } else if (srcTopBottom == 1 && srcRightLeft == 1) {
        quadrantColor = vec3(0.0, 0.0, 1.0); // Blue = Bottom-left
    } else {
        quadrantColor = vec3(1.0, 1.0, 0.0); // Yellow = Bottom-right
    }
    
    // Blend: show corner indicator strongly, fade source color in background
    vec3 debugColor = mix(sourceColor.rgb * 0.5, quadrantColor, crosshair * 0.7);
    
    // Add subtle glow around corner based on distance
    float glow = exp(-distToCorner * 100.0) * 0.3;
    debugColor += quadrantColor * glow;
    
    return vec4(debugColor, 1.0);
}

vec4 special_interpolation(vec2 tc)
{
    vec2 sourceSize = params.SourceSize.xy;
    vec2 texelSize = 1.0 / sourceSize;
    
    // Get fractional part of texture coordinate
    vec2 f = fract(tc * sourceSize - 0.5);
    vec2 texCoord = (floor(tc * sourceSize - 0.5) + 0.5) / sourceSize;
    
    // Determine which quadrant we're in within the current pixel
    int currentQuadTopBottom, currentQuadRightLeft;
    get_pixel_quadrant(f, currentQuadTopBottom, currentQuadRightLeft);
    
    // Sample source pixel and get its corner weight quadrant
    int srcTopBottom, srcRightLeft;
    vec4 color0 = sample_with_quadrant(texCoord, srcTopBottom, srcRightLeft);
    
    // If current quadrant matches source corner weight, use source color directly
    if (currentQuadTopBottom == srcTopBottom && currentQuadRightLeft == srcRightLeft) {
        return color0;
    }
    
    // Determine which adjacent pixels to sample based on enabled directions
    bool doHorizontal = SPECIAL_INTERP_H > 0.5;
    bool doVertical = SPECIAL_INTERP_V > 0.5;
    
    // If neither direction is enabled, return source color
    if (!doHorizontal && !doVertical) {
        return color0;
    }
    
    vec2 offset1, offset2, offset3;
    int tb1, rl1, tb2, rl2, tb3, rl3;
    
    // Determine offsets based on current quadrant
    if (currentQuadTopBottom == 0 && currentQuadRightLeft == 1) {
        // Top-left quadrant
        offset1 = vec2(0.0, -texelSize.y);           // above (vertical)
        offset2 = vec2(-texelSize.x, 0.0);           // left (horizontal)
        offset3 = vec2(-texelSize.x, -texelSize.y);  // above-left (diagonal)
    } else if (currentQuadTopBottom == 0 && currentQuadRightLeft == 0) {
        // Top-right quadrant
        offset1 = vec2(0.0, -texelSize.y);           // above (vertical)
        offset2 = vec2(texelSize.x, 0.0);            // right (horizontal)
        offset3 = vec2(texelSize.x, -texelSize.y);   // above-right (diagonal)
    } else if (currentQuadTopBottom == 1 && currentQuadRightLeft == 1) {
        // Bottom-left quadrant
        offset1 = vec2(0.0, texelSize.y);            // down (vertical)
        offset2 = vec2(-texelSize.x, 0.0);           // left (horizontal)
        offset3 = vec2(-texelSize.x, texelSize.y);   // down-left (diagonal)
    } else {
        // Bottom-right quadrant
        offset1 = vec2(0.0, texelSize.y);            // down (vertical)
        offset2 = vec2(texelSize.x, 0.0);            // right (horizontal)
        offset3 = vec2(texelSize.x, texelSize.y);    // down-right (diagonal)
    }
    
    // Sample and blend based on enabled directions
    if (doVertical && doHorizontal) {
        // Sample vertical, horizontal, and diagonal
        vec4 color1 = sample_with_quadrant(texCoord + offset1, tb1, rl1);
        vec4 color2 = sample_with_quadrant(texCoord + offset2, tb2, rl2);
        vec4 color3 = sample_with_quadrant(texCoord + offset3, tb3, rl3);
        
        vec2 corner1 = get_corner_position(texCoord + offset1, tb1, rl1);
        vec2 corner2 = get_corner_position(texCoord + offset2, tb2, rl2);
        vec2 corner3 = get_corner_position(texCoord + offset3, tb3, rl3);
        
        float dist1 = distance(tc, corner1);
        float dist2 = distance(tc, corner2);
        float dist3 = distance(tc, corner3);
        
        float weight1 = 1.0 / (dist1 + 0.0001);
        float weight2 = 1.0 / (dist2 + 0.0001);
        float weight3 = 1.0 / (dist3 + 0.0001);
        float totalWeight = weight1 + weight2 + weight3;
        
        weight1 /= totalWeight;
        weight2 /= totalWeight;
        weight3 /= totalWeight;
        
        vec4 blendedColor = color1 * weight1 + color2 * weight2 + color3 * weight3;
        return mix(color0, blendedColor, 0.5);
    } else if (doVertical) {
        // Sample only vertical
        vec4 color1 = sample_with_quadrant(texCoord + offset1, tb1, rl1);
        
        vec2 corner1 = get_corner_position(texCoord + offset1, tb1, rl1);
        float dist1 = distance(tc, corner1);
        float weight1 = 1.0 / (dist1 + 0.0001);
        
        return mix(color0, color1, 0.5 * weight1 / (1.0 + weight1));
    } else {
        // Sample only horizontal
        vec4 color2 = sample_with_quadrant(texCoord + offset2, tb2, rl2);
        
        vec2 corner2 = get_corner_position(texCoord + offset2, tb2, rl2);
        float dist2 = distance(tc, corner2);
        float weight2 = 1.0 / (dist2 + 0.0001);
        
        return mix(color0, color2, 0.5 * weight2 / (1.0 + weight2));
    }
}

void main()
{
    vec4 color;
    
    if (DEBUG_SHOW_CORNERS > 0.5) {
        // Show debug visualization of corner weights
        color = debug_show_corners(vTexCoord);
    } else if (INTERPOLATION_MODE < 0.5) {
        color = nearest_neighbor(vTexCoord);
    } else if (INTERPOLATION_MODE < 1.5) {
        color = bilinear_interpolation(vTexCoord);
    } else if (INTERPOLATION_MODE < 2.5) {
        color = special_interpolation(vTexCoord);
    }
    
    FragColor = vec4(color.rgb, 1.0);
}
