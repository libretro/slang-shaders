#version 450
/*
    zfast_crt_standard - A simple, fast CRT shader.
    Composite YIQ blur, interlace, curvature added by metallic77
    Copyright (C) 2017 Greg Hogan (SoltanGris42)

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.


Notes:  This shader does scaling with a weighted linear filter for adjustable
    sharpness on the x and y axes based on the algorithm by Inigo Quilez here:
    http://http://www.iquilezles.org/www/articles/texture/texture.htm
    but modified to be somewhat sharper.  Then a scanline effect that varies
    based on pixel brighness is applied along with a monochrome aperture mask.
    This shader runs at 60fps on the Raspberry Pi 3 hardware at 2mpix/s
    resolutions (1920x1080 or 1600x1200).
*/

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
   float BLURSCALEX, LOWLUMSCAN, HILUMSCAN, BRIGHTBOOST, MASK_DARK, MASK_FADE, FINEMASK, 
   WARP;
} params;

#pragma parameter WARP "Curvature" 0.03 0.0 0.3 0.01
#pragma parameter BLURSCALEX "Blur Amount X-Axis" 0.5 0.0 1.0 0.05
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 6.0 0.0 10.0 0.5
#pragma parameter HILUMSCAN "Scanline Darkness - High" 8.0 0.0 50.0 1.0
#pragma parameter BRIGHTBOOST "Dark Pixel Brightness Boost" 1.25 0.5 1.5 0.05
#pragma parameter MASK_DARK "Mask Effect Amount" 0.25 0.0 1.0 0.05
#pragma parameter MASK_FADE "Mask/Scanline Fade" 0.8 0.0 1.0 0.05
#pragma parameter FINEMASK "Mask Fine/Coarse" 0.0 0.0 1.0 1.0

#define BLURSCALEX params.BLURSCALEX
#define LOWLUMSCAN params.LOWLUMSCAN
#define HILUMSCAN params.HILUMSCAN
#define BRIGHTBOOST params.BRIGHTBOOST
#define MASK_DARK params.MASK_DARK
#define MASK_FADE params.MASK_FADE
#define FINEMASK params.FINEMASK
#define WARP params.WARP
#define SourceSize params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize params.OutputSize
#define FrameCount params.FrameCount


layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

//For testing compilation 
//#define FRAGMENT
//#define VERTEX

//Some drivers don't return black with texture coordinates out of bounds
//SNES Classic is too slow to black these areas out when using fullscreen
//overlays.  But you can uncomment the below to black them out if necessary
//#define BLACK_OUT_BORDER

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float maskFade;
layout(location = 2) out vec2 invDims;
layout(location = 3) out vec2 maskpos;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
    maskFade = 0.3333*MASK_FADE;
    invDims = 1.0/SourceSize.xy;
    maskpos = vTexCoord*OutputSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float maskFade;
layout(location = 2) in vec2 invDims;
layout(location = 3) in vec2 maskpos;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define timer mod(float(FrameCount),2.0)


// Colorspace conversion matrix for RGB-to-YIQ
const mat3 RGBYIQ = mat3(
      0.2989, 0.5870, 0.1140,
      0.5959, -0.2744, -0.3216,
      0.2115, -0.5229, 0.3114
);
// Colorspace conversion matrix for YIQ-to-RGB
const mat3 YIQ2RGB = mat3(
   1.0, 0.9563, 0.6210,
   1.0, -0.2721, -0.6474,
   1.0, -1.1070, 1.7046);

// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*WARP, 1.0 + (pos.x*pos.x)*WARP*1.5);
    
    return pos*0.5 + 0.5;
}

void main()
{
    vec2 dx = vec2(invDims.x*0.5,0.0);
    vec2 ilace_pos = OriginalSize.y>300.0? vTexCoord + vec2(0.0,SourceSize.w)*timer : vTexCoord;
    vec2 pos = Warp(ilace_pos);
    vec2 corn = min(pos,vec2(1.0)-pos); // This is used to mask the rounded
    corn.x = 0.00001/corn.x;           // corners later on
    //This is just like "Quilez Scaling" but sharper
    vec2 p = pos * SourceSize.xy;
    vec2 i = floor(p) + 0.50;
    vec2 f = p - i;
    p = (i + 4.0*f*f*f)*invDims;
    p.x = mix( p.x , pos.x, BLURSCALEX);
    float f_laced = OriginalSize.y > 300.0 ? pos.y*SourceSize.y*0.5 - (floor(pos.y*SourceSize.y*0.5)+0.5) : f.y; 
    float Y = f_laced*f_laced;
    float YY = Y*Y;
float mask = 0.0;

if (FINEMASK == 0.0) {
    float whichmask = fract(floor(maskpos.x)*-0.4999);
     mask = 1.0 + float(whichmask < 0.5) * -MASK_DARK;}
else {
    float whichmask = fract(floor(maskpos.x)*-0.3333);
     mask = 1.0 + float(whichmask <= 0.33333) * -MASK_DARK;
}
    float sumY = 0.0;
    float sumC = 0.0;
    vec3 colour = vec3(0.0);
    for (float i=-8; i<9; i += 1.0)
    {
        float wY = exp(-0.6*i*i); sumY += wY;
        float wC = exp(-0.05*i*i); sumC += wC;
        colour.r +=  (RGBYIQ*texture(Source,p + dx*i).rgb).r*wY;
        colour.gb += (RGBYIQ*texture(Source,p + dx*i).rgb).gb*wC;
    }
    colour.r /= sumY;
    colour.gb /= sumC;

    colour = YIQ2RGB*colour;
    float scanLineWeight = (BRIGHTBOOST - LOWLUMSCAN*(Y - 2.05*YY));
    float scanLineWeightB = 1.0 - HILUMSCAN*(YY-2.8*YY*Y);  
    colour = colour.rgb*mix(scanLineWeight*mask, scanLineWeightB, dot(colour.rgb,vec3(maskFade)));
     if (WARP != 0.0 && corn.y < corn.x || WARP != 0.0 && corn.x < 0.00001 )
    colour = vec3(0.0);
    FragColor.rgb = colour;
}
