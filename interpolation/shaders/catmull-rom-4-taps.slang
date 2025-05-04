#version 450

/* 
     Four tap Catmull-Rom upsampling shader - ported by Hyllian 2025

  Unfortunately, it breaks clamp_to_edge and ring at the image borders...


  Source: https://www.shadertoy.com/view/NlBXWR


  This takes the ideas from:
  https://vec3.ca/bicubic-filtering-in-fewer-taps/
    9 taps
  https://research.activision.com/publications/archives/filmic-smaasharp-morphological-and-temporal-antialiasing
    5 taps, with 4 removed sidelobes

  This example:
    4 taps, with 0 removed sidelobes (but checkerboard preprocessing)

  By inverting the source texture in a checkerboard style (which can be baked into
  the texture or previous render pass) and utilising existing bilinear filtering,
  Catmull-Rom reduces from 16 to 4 texture reads.

  Every other pixel of the source texture is inverted in a checkerboard pattern.
  This matches the positive/negative flips of the Catmull-Rom lobes.

  offset works out the position where bilinear filtering will get the correct ratio of
  sidelobes. This allows 1 texture fetch to read 4 taps. This needs to be a 4th order
  polynomial to preserve partition of unity, but only 2dp of precision is needed.
  The polynomial coefficients were derived using Excel's trendline function. X and Y
  negative and positive sides are evaluated simultaneously in the vec4.

  w is the appropriate final weighting of the reads, assuming each read is 2D lerp of 4
  taps. The some weights are inverted to compensate for the source texture checkerboard.

  This checkerboard strategy only works where each sidelobe is of opposing sign.
  So it works for Catmull-Rom and Lanczos-2, but not Mitchell–Netravali.

  I have chosen Catmull-Rom over Lanczos-2 as it has a partition of unity, which induces
  less ripple in solid colours where local clamping can't be easily done.

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
layout(set = 0, binding = 3) uniform sampler2D Original;

void main()
{
    // Split into whole pixel and subpixel position
    vec2 src_subpixel = vTexCoord * params.SourceSize.xy + .5;
    vec2 src_pixel = floor(src_subpixel);
    src_subpixel -= src_pixel;

    // Map texel offsets and weights
    vec4 f=vec4(src_subpixel,1.-src_subpixel);
    // Offset adds the correct ratio of each lobe using texture bilinear interpolation
    //vec4 offset = (((-.94117*f+1.67489)*f-1.2601)*f+.52875)*f+.49921; // Catmull Rom
    vec4 Offset = (((-.94*f+1.68)*f-1.26)*f+.53)*f+.5; // Catmull Rom
    vec4 texpos = (src_pixel.xyxy + vec4(-Offset.xy, Offset.zw)) / params.SourceSize.xyxy;
    // Weight adds textures in correct ratio, and corrects for checkerboard across kernel.
    vec4 w = ((2.*f-3.5)*f+.5)*f+1.; // Catmull Rom

    // Texture lookup
    vec3 color  = w.x * w.y * texture(Source, texpos.xy).xyz;
         color -= w.z * w.y * texture(Source, texpos.zy).xyz;
         color += w.z * w.w * texture(Source, texpos.zw).xyz;
         color -= w.x * w.w * texture(Source, texpos.xw).xyz;

    // De-checkerboard
    float z = mod(src_pixel.x + src_pixel.y, 2.);
    if (z>.5) color = -color;

    // Catmull-Rom can ring, so clamp.
    // It would be nice to clamp to local min/max, but that would require additional
    // texture reads. If texture reads are done as a textureGather, this would be
    // possible.
    FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
