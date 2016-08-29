#version 450

layout(push_constant) uniform Push
{
  float SHARP_BILINEAR_PRE_SCALE;
} param;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
} global;

/*
 * sharp-bilinear.slang
 * Author: Themaister
 * License: Public domain
 * 
 * Does a bilinear stretch, with a preapplied Nx nearest-neighbor scale, giving a
 * sharper image than plain bilinear.
 */

#pragma parameter SHARP_BILINEAR_PRE_SCALE "Sharp Bilinear Prescale" 4.0 1.0 10.0 1.0

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
   vec2 texel = vTexCoord * global.SourceSize.xy;
   vec2 texel_floored = floor(texel);
   vec2 s = fract(texel);
   float region_range = 0.5 - 0.5 / param.SHARP_BILINEAR_PRE_SCALE;

   // Figure out where in the texel to sample to get correct pre-scaled bilinear.
   // Uses the hardware bilinear interpolator to avoid having to sample 4 times manually.

   vec2 center_dist = s - 0.5;
   vec2 f = (center_dist - clamp(center_dist, -region_range, region_range)) * param.SHARP_BILINEAR_PRE_SCALE + 0.5;

   vec2 mod_texel = texel_floored + f;

   FragColor = vec4(texture(Source, mod_texel / global.SourceSize.xy).rgb, 1.0);
}