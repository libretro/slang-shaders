#version 450

/* 
     Checkerboard Inverted shader - ported by Hyllian 2025

  IMPORTANT: It only works using float_framebuffer.

  Source: https://www.shadertoy.com/view/NlBXWR

  Checkerboard invert half the texture pixels

  The checkerboarding allows bilinear filtering to be used to read 4 taps
  simultaneously at the correct ratios, by strategic selection of the subpixel
  position. 16 taps are read as 4 texture reads.

  This buffer should be the same size as the source image.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
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
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Pixel number, integer
    vec2 pixel = floor(vTexCoord.xy*params.SourceSize.xy);
    
    // Get texture, 1:1 pixel ratio, sampling at centre of texel.
    vec3 c = texture(Source, (pixel + 0.5.xx)/params.SourceSize.xy).xyz;
    
    // Checkerboard flip
    float flip = (pixel.x + pixel.y)*.5;
    flip = flip - floor(flip);
    if (flip > .25) c = -c;

    FragColor = vec4(c,1.0);
}
