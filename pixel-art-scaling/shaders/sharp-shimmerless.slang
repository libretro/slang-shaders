#version 450

layout(push_constant) uniform Push
{
  vec4 OutputSize;
  vec4 OriginalSize;
  vec4 SourceSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

// Slang Optimizations made by Hyllian - 2025.
// Original code: https://github.com/Woohyun-Kang/Sharp-Shimmerless-Shader/blob/main/shaders_slang/shaders/sharp-shimmerless.slang

/*
 * sharp-shimmerless
 * Author: zadpos
 * License: Public domain
 * 
 * A retro gaming shader for sharpest pixels with no aliasing/shimmering.
 * Instead of pixels as point samples, this shader considers pixels as
 * ideal rectangles forming a grid, and interpolates pixel by calculating
 * the surface area an input pixel would occupy on an output pixel.
 */

#define FIX(c) max(abs(c), 1e-5)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 pixel;
layout(location = 1) out vec2 scale;
layout(location = 2) out vec2 invscale;

void main()
{
   gl_Position = global.MVP * Position;

   // These lines don't need calculation for each fragment. For each vertex is well optimized.
   pixel    = TexCoord * params.OutputSize.xy * params.SourceSize.xy * params.OriginalSize.zw;
   scale    = params.OutputSize.xy * params.SourceSize.zw;
   invscale = 1.0 / scale;
}

#pragma stage fragment
layout(location = 0) in vec2 pixel;
layout(location = 1) in vec2 scale;
layout(location = 2) in vec2 invscale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec4 pixel_borders = vec4(floor(pixel), ceil(pixel));
    vec4 texel_borders = floor(invscale.xyxy*pixel_borders);

    vec2 same_texel = step(FIX(0.0), abs(texel_borders.xy - texel_borders.zw));

    vec2 mod_texel  = texel_borders.zw + 0.5.xx - (scale * texel_borders.zw - pixel_borders.xy) * same_texel;

    FragColor = vec4(texture(Source, mod_texel * params.SourceSize.zw).rgb, 1.0);
} 
