#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass 1: Graph snapshot — passthrough copy of the similarity graph.
//
// The resolve-crossings pass needs to read the original graph state while
// writing modifications. RetroArch's multi-pass system naturally provides
// this by letting Pass 2 read Pass 1's output (snapshot) while writing to
// its own framebuffer. This pass simply copies Source unchanged.

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
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

layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    // Exact texel copy — no filtering
    FragColor = texelFetch(Source, ivec2(gl_FragCoord.xy), 0);
}
