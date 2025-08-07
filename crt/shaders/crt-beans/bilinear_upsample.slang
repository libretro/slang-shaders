#version 450

// SPDX-License-Identifier: MIT

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
};

// #pragma format R8G8B8A8_SRGB
#pragma format R16G16B16A16_SFLOAT

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    FragColor.rgb = texture(Source, vTexCoord).rgb;
}
