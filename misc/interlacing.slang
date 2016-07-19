#version 450

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   uint FrameCount;
} global;

#define percent 0.0
#define enable_480i 1.0
#define top_field_first 0.0

/*
   Interlacing
   Author: hunterk
   License: Public domain
   
   Note: This shader is designed to work with the typical interlaced output from an emulator, which displays both even and odd fields twice.
   This shader will un-weave the image, resulting in a standard, alternating-field interlacing.
*/

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
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
   vec4 res = texture(Source, vTexCoord).rgba;
   float y = 0.0;

   // assume anything with a vertical resolution greater than 400 lines is interlaced
   if (global.SourceSize.y > 400.0)
   {y = global.SourceSize.y * vTexCoord.y + (global.FrameCount * enable_480i) + top_field_first;}
   else
   {y = 2.0 * global.SourceSize.y * vTexCoord.y + top_field_first;}

   if (mod(y, 2.0) > 0.99999)
   {FragColor = res;}
   else
   {FragColor = vec4(percent) * res;}
}