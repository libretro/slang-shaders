#version 450

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Do a 1:1 copy of a texture

#include "slang_params.inc"
#include "cathode-retro-util-lanczos.inc"
#define inTexCoord vTexCoord

//DECLARE_TEXTURE2D(g_sourceTexture, g_sampler);
layout(set = 0, binding = 2) uniform sampler2D Source;
#define g_sourceTexture Source

void main()
{
  FragColor = texture(g_sourceTexture, inTexCoord);
}
