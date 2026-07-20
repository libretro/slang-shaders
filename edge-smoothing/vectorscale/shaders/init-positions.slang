#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass: Initialize the position texture from cell graph original positions.
// The optimizer chain stores absolute positions in F32 framebuffers.

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

layout(set = 0, binding = 3) uniform sampler2D CellGraph; // Pass 3

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);
    // CellGraph: 1 texel per (cx, cy_slot). RG = original position; the
    // BA channels hold packed flags/dirs/neighbors which we don't need.
    vec4 val = texelFetch(CellGraph, opos, 0);
    FragColor = vec4(val.r, val.g, 0.0, 0.0);
}
