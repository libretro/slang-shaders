#version 450

// Analog Service Menu
// by hunterk and chatGPT 4.o
// license: public domain, I guess, since AI can't own copyrights lol

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float scurveStrengthY, inflectionY, pinPhaseStrengthX, pinPhaseStrengthY,
      pinCushionStrengthX, pinCushionStrengthY, vAngleStrengthX,
      vAngleStrengthY,  vCenter, hCenter, /*nonLinHStr, nonLinVStr,*/ hSize,
      vSize, scurveStrengthX, inflectionX, dummy1, dummy2;
} params;

#pragma parameter dummy1 "======== Analog Service Menu Start ========" 0.0 0.0 0.00001 0.00001

#pragma parameter hSize "H Size" 1.0 0.0 2.0 0.01
#pragma parameter vSize "V Size" 1.0 0.0 2.0 0.01

#pragma parameter hCenter "H Center" 0.0 -1.0 1.0 0.01
#pragma parameter vCenter "V Center" 0.0 -1.0 1.0 0.01

#pragma parameter vAngleStrengthY "H Angle" 0.0 -1.0 1.0 0.01
#pragma parameter vAngleStrengthX "V Angle" 0.0 -1.0 1.0 0.01
vec2 vAngleStrength = vec2(params.vAngleStrengthX, params.vAngleStrengthY);

#pragma parameter pinPhaseStrengthX "H Pin Phase" 0.0 -1.0 1.0 0.01
#pragma parameter pinPhaseStrengthY "V Pin Phase" 0.0 -1.0 1.0 0.01
vec2 pinPhaseStrength = vec2(params.pinPhaseStrengthX,
   params.pinPhaseStrengthY);

#pragma parameter pinCushionStrengthX "H Pin Cushion" 0.0 -1.0 1.0 0.01
#pragma parameter pinCushionStrengthY "V Pin Cushion" 0.0 -1.0 1.0 0.01
vec2 pinCushionStrength = vec2(params.pinCushionStrengthX,
   params.pinCushionStrengthY);

#pragma parameter scurveStrengthY "S-Curve Correction (Vert)" 0.0 -1.0 1.0 0.01
#pragma parameter inflectionY "S-Curve Inflection Point (Vert)" 0.5 0.0 1.0 0.01

#pragma parameter scurveStrengthX "S-Curve Correction (Horz)" 0.0 -1.0 1.0 0.01
#pragma parameter inflectionX "S-Curve Inflection Point (Horz)" 0.5 0.0 1.0 0.01

//#pragma parameter nonLinHStr "Horizontal Non-Linearity" 0.0 0.0 1.0 0.01
//#pragma parameter nonLinVStr "Vertical Non-Linearity" 0.0 0.0 1.0 0.01

#pragma parameter dummy2 "========= Analog Service Menu End =========" 0.0 0.0 0.00001 0.00001

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

/* comment these out for now, since they're kinda broken
vec2 nonLinearH(vec2 uv, float strength) {
    vec2 centered = uv * 2.0 - 1.0; // [-1, 1]
    
    float x2 = centered.x * centered.x; // only X component squared

    // Distort only the X component
    centered.x *= (1.0 + strength * x2);

    return centered * 0.5 + 0.5;
}

vec2 nonLinearV(vec2 uv, float strength) {
    vec2 centered = uv * 2.0 - 1.0;

    float y2 = centered.y * centered.y;
    centered.y *= (1.0 + strength * y2);

    return centered * 0.5 + 0.5;
}
*/

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = ((TexCoord - 0.5) / vec2(params.hSize, params.vSize) + 0.5);
    vTexCoord = vTexCoord + vec2(-params.hCenter, params.vCenter);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float sCorrection(float y, float strength, float inflection) {
    // Remap [0,1] so inflection point becomes the center
    y = clamp(y, 0.0, 1.0);

    if (inflection != 0.5) {
        if (y < inflection) {
            y = 0.5 * y / inflection;
        } else {
            y = 0.5 + 0.5 * (y - inflection) / (1.0 - inflection);
        }
    }

    float t = y;
    float smoothie = t * t * (3.0 - 2.0 * t);
    float curved = mix(t, smoothie, strength);

    // Remap back to [0,1] with inflection
    if (inflection != 0.5) {
        if (curved < 0.5) {
            curved = inflection * curved / 0.5;
        } else {
            curved = inflection + (1.0 - inflection) * (curved - 0.5) / 0.5;
        }
    }

    return curved;
}

vec2 applyPinPhase(vec2 uv, vec2 strength) {
    float directionY = sign(strength.y); // 1.0 = top pivot, -1.0 = bottom pivot
    float directionX = sign(strength.x); // 1.0 = right pivot, -1.0 = left pivot
    float y = uv.y;
    float x = uv.x;

    // Distance from pivot edge (0.0 or 1.0 depending on sign)
    float distanceFromPivotY = (directionY > 0.0) ? y : (1.0 - y);
    float distanceFromPivotX = (directionX > 0.0) ? x : (1.0 - x);

    // Distortion falls off from pivot edge to the other edge
    uv.x += (uv.x - 0.5) * abs(strength.y) * distanceFromPivotY;
    uv.y += (uv.y - 0.5) * abs(strength.x) * distanceFromPivotX;

    return uv;
}

vec2 pincushionWarp(vec2 uv, vec2 strength) {
    float x = uv.x;
    float y = uv.y;

    // Centered Y in [-1, 1]
    float yc = y * 2.0 - 1.0;
    float xc = x * 2.0 - 1.0;

    // Vertical weighting curve (e.g. inverted parabola)
    float warpY = 1.0 - yc * yc;  // peaks at y = 0.5, 0 at y=0 and y=1
    // Horizontal weighting curve (e.g. inverted parabola)
    float warpX = 1.0 - xc * xc;  // peaks at x = 0.5, 0 at x=0 and x=1

    // Shift X based on Y curve
    uv.x += (uv.x - 0.5) * warpY * strength.y;
    // Shift Y based on X curve
    uv.y += (uv.y - 0.5) * warpX * strength.x;

    return uv;
}

vec2 applyVAngle(vec2 uv, vec2 strength) {
    // Vertical offset from center [-0.5, 0.5]
    float offsetY = uv.y - 0.5;
    // Horizontal offset from center [-0.5, 0.5]
    float offsetX = uv.x - 0.5;

    // Apply shear: X shifts proportionally to vertical offset
    uv.y += offsetX * strength.x;

    // Apply shear: Y shifts proportionally to horizontal offset
    uv.x += offsetY * strength.y;

    return uv;
}

#define pi 3.141592654
#define FIX_ZERO(c) (max(abs(c), 0.0000152587890625))   //  2^-16

#include "../../../include/compat_macros.inc"
#include "../../shaders/crt-royale/src/tex2Dantialias.h"

mat2 mul_scale(vec2 scale, mat2 matrix)
{
    vec4 temp_matrix = (vec4(matrix[0][0], matrix[0][1], matrix[1][0], matrix[1][1])* scale . xxyy);
    return mat2(temp_matrix.x, temp_matrix.y, temp_matrix.z, temp_matrix.w);
}

vec4 royaleAASampler(sampler2D tex, vec2 coord, vec2 inputSize, vec2 outputSize)
{
	vec2 invOutputSize = 1.0 / outputSize.xy;
	vec2 invInputSize  = 1.0 / inputSize.xy;
	mat2 pixel_to_video_uv = mat2(
            invOutputSize.x, 0.0, 0.0, invOutputSize.y);
	mat2 pixel_to_tex_uv =
        mul_scale(inputSize.xy * invInputSize.xy /
            vec2(1.0), pixel_to_video_uv);
    return vec4(tex2Daa(tex, coord, pixel_to_tex_uv, 1.0).rgb, 1.0);
}

void main()
{
    vec2 uv = vTexCoord.xy;
    uv = applyPinPhase(uv, pinPhaseStrength);
    uv = pincushionWarp(uv, pinCushionStrength);
    uv = applyVAngle(uv, vAngleStrength);
    vec2 hold = uv;
    uv.y = sCorrection(uv.y, params.scurveStrengthY, params.inflectionY);
    uv.x = sCorrection(uv.x, params.scurveStrengthX, params.inflectionX);
    FragColor = vec4(royaleAASampler(Source, uv, params.SourceSize.xy, params.OutputSize.xy).rgb, 1.0);
    // hide some weird behavior when coords are out of bounds
    FragColor *= (hold.y > 1.0 || hold.y < 0.0) ? 0.0 : 1.0;
    FragColor *= (hold.x > 1.0 || hold.x < 0.0) ? 0.0 : 1.0;
}
