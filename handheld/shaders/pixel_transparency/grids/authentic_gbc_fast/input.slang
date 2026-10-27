#version 450

// Authentic GBC – Grid Input Pass

// Authentic's integrated controls in a separate LCD pass.
#include "parameters.inc"
#define LCDInput PTNativeColour
layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 OriginalSize;
    vec4 FinalViewportSize;
    PT_LCD_UNIFORMS
} global;
layout(push_constant) uniform Push { vec4 OutputSize; } param;
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
void prepareLCD();
void main() { gl_Position = global.MVP * Position; prepareLCD(); }
#pragma stage fragment
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D PTNativeColour;
layout(set = 0, binding = 3) uniform sampler2D PTGridX;
layout(set = 0, binding = 4) uniform sampler2D PTGridY;
vec4 sampleLCD();
void main() { FragColor = sampleLCD(); }
#include "grid.inc"
