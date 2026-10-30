#version 450

// LCD Grid v2 – Y Integral Cache
// Adapted from lcd-cgwg/lcd-grid-v2.slang.

#pragma name PTIntegratedY
#pragma format R32G32B32A32_SFLOAT
#define PT_GRID_LCD_GRID_V2
#include "parameters.inc"
layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 OriginalSize;
    vec4 FinalViewportSize;
    PT_LCD_UNIFORMS
} global;
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
void main() { gl_Position = global.MVP * Position; }
#pragma stage fragment
layout(location = 0) out vec4 FragColor;
#include "integral.inc"
void main() {
    float coordinate = gl_FragCoord.y / global.FinalViewportSize.y / global.OriginalSize.w - 0.4999;
    float origin = floor(coordinate);
    float phase = coordinate - origin;
    float width = global.FinalViewportSize.w / global.OriginalSize.w;
    FragColor = vec4(intsmear(phase, width, 0.63, coeffs_y),
                     intsmear(phase - 1.0, width, 0.63, coeffs_y), origin, 0.0);
}
