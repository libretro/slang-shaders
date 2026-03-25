#version 450

// Pass: Initialize the offset texture to zero.
// The optimizer chain stores OFFSETS from original positions (not absolute positions)
// to avoid FP16 precision loss at large position values (80-160 range).
// Offsets are small (<1 pixel) so FP16 gives ~0.0005 precision.

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 CellGraphSize;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;    // Previous pass (unused)
layout(set = 0, binding = 3) uniform sampler2D CellGraph; // Pass 3

void main() {
    // All offsets start at zero (positions = originals).
    FragColor = vec4(0.0);
}
