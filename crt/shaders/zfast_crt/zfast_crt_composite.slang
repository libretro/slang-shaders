#version 450
/*
    zfast_crt - A very simple CRT shader.

    Copyright (C) 2017 Greg Hogan (SoltanGris42)
    edited by metallic 77.
    ported to slang by gregoricavichioli & hunterk.

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

*/

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
float pi, blurx, blury, HIGHSCANAMOUNT1, HIGHSCANAMOUNT2, MASK_DARK, MASK_FADE, sat,TYPE,Curvature;
} params;

#pragma parameter Curvature "Curvature" 1.0 0.0 1.0 1.0
#pragma parameter blurx "Convergence X-Axis" 0.85 -1.0 2.0 0.05
#pragma parameter blury "Convergence Y-Axis" -0.10 -1.0 1.0 0.05
#pragma parameter HIGHSCANAMOUNT1 "Scanline Amount (Low)" 0.3 0.0 1.0 0.05
#pragma parameter HIGHSCANAMOUNT2 "Scanline Amount (High)" 0.15 0.0 1.0 0.05
#pragma parameter TYPE "Mask Type" 0.0 0.0 1.0 1.0
#pragma parameter MASK_DARK "Mask Effect Amount" 0.3 0.0 1.0 0.05
#pragma parameter MASK_FADE "Mask/Scanline Fade" 0.7 0.0 1.0 0.05
#pragma parameter sat "Saturation" 1.0 0.0 3.0 0.05


#define pi 3.14159
#define blurx params.blurx
#define blury params.blury
#define HIGHSCANAMOUNT1 params.HIGHSCANAMOUNT1
#define HIGHSCANAMOUNT2 params.HIGHSCANAMOUNT2
#define BRIGHTBOOST params.BRIGHTBOOST
#define MASK_DARK params.MASK_DARK
#define MASK_FADE params.MASK_FADE
#define sat params.sat
#define Curvature params.Curvature
#define TYPE params.TYPE

#define SourceSize params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize params.OutputSize
#define FrameCount params.FrameCount
#define scale vec4(SourceSize.xy/OriginalSize.xy,OriginalSize.xy/SourceSize.xy)

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float maskFade;
layout(location = 2) out float omega;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord*1.0001;
    maskFade = 0.3333*MASK_FADE;
    omega = 2.0*pi*SourceSize.y;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float maskFade;
layout(location = 2) in float omega;

layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define blur_y blury/(SourceSize.y*2.0)
#define blur_x blurx/(SourceSize.x*2.0)
#define timer mod(float(FrameCount),2.0)

// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*0.03, 1.0 + (pos.x*pos.x)*0.05);
    
    return pos*0.5 + 0.5;
}



void main()
{
    vec2 pos,corn;
    if (Curvature == 1.0) 
{
    pos = Warp(vTexCoord.xy);
    corn = min(pos,vec2(1.0)-pos); // This is used to mask the rounded
    corn.x = 0.00001/corn.x;           // corners later on
}
     else pos = vTexCoord ; 

     float OGL2Pos = pos.y*SourceSize.y;
     float cent = floor(OGL2Pos)+0.5;
     float ycoord = cent*SourceSize.w; 
     ycoord = mix(pos.y,ycoord,0.5);
     pos = vec2(pos.x,ycoord);
     pos += OriginalSize.y > 300.0? timer*vec2(0.0,SourceSize.w) : vec2(0.0);
    
    if (OriginalSize.y > 300.0) {
    OGL2Pos = OGL2Pos+timer;
    } 

     vec3 sample1 = texture(Source,vec2(pos.x + blur_x, pos.y - blur_y)).rgb;
     vec3 sample2 = 0.5*texture(Source,pos).rgb;
     vec3 sample3 = texture(Source,vec2(pos.x - blur_x, pos.y + blur_y)).rgb;
    
     vec3 colour = vec3 (sample1.r*0.5  + sample2.r, 
                         sample1.g*0.25 + sample2.g + sample3.g*0.25, 
                                          sample2.b + sample3.b*0.5);
     colour = sqrt(colour);
     vec3 lumweight=vec3(0.3,0.6,0.1);
     float grays = dot(colour,lumweight);
   
     vec3 graycolour = vec3(grays);
     colour = vec3(mix(graycolour,colour,sat));

     float SCANAMOUNT = mix(HIGHSCANAMOUNT1,HIGHSCANAMOUNT2,max(max(colour.r,colour.g),colour.b));
     float interlace = OriginalSize.y > 300.0 ? 1.0 :2.0; 

     colour *= SCANAMOUNT * sin((OGL2Pos-0.25)*3.14159*interlace)+1.0-SCANAMOUNT;
    
     float steps; if (TYPE == 0.0) steps = 0.5; else steps = 0.3333;
     float whichmask = fract(vTexCoord.x*OutputSize.x*steps);
     float mask = 1.0 + float(whichmask < steps) * -MASK_DARK;

    colour.rgb = mix(mask*colour, colour, dot(colour.rgb,vec3(maskFade)));

    if (Curvature == 1.0 && corn.y < corn.x || Curvature == 1.0 && corn.x < 0.00001 )
    colour = vec3(0.0); 
    colour = clamp(colour,vec3(0.0),vec3(1.0));
    FragColor.rgb = (colour);
} 
