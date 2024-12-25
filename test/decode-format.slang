#version 450

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 SourceSize;
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
layout(set = 0, binding = 1) uniform usampler2D Source;

void main()
{
// Sampling non-float textures is not supported in HLSL, so use texelFetch() instead of texture()
   vec4 current = unpackUnorm4x8(texelFetch(Source, ivec2(vTexCoord.xy * global.SourceSize.xy), 0).r);
   FragColor = current;
}
