#version 450

// LCD Grid v2 – X Integral Cache
// Adapted from lcd-cgwg/lcd-grid-v2.slang.

#pragma name PTIntegratedX
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
    float coordinate = gl_FragCoord.x / global.FinalViewportSize.x / global.OriginalSize.z - 0.4999;
    float origin = floor(coordinate);
    float phase = (coordinate - origin) * 3.0;
    float width = global.FinalViewportSize.z / global.OriginalSize.z * 3.0;
    if (int(gl_FragCoord.y) == 1) phase -= 3.0;
    vec3 weights = vec3(intsmear(phase + 1.0, width, 1.5, coeffs_x),
                        intsmear(phase, width, 1.5, coeffs_x),
                        intsmear(phase - 1.0, width, 1.5, coeffs_x));
    if (global.BGR > 0.5) weights = weights.bgr;
    FragColor = vec4(weights, origin);
}
