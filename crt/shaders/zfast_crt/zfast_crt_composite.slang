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
float pi, blurx, blury, HIGHSCANAMOUNT1, HIGHSCANAMOUNT2, MASK_DARK, MASK_FADE, sat, SEGA;
} params;

#pragma parameter blurx "Convergence X-Axis" 0.45 -1.0 2.0 0.05
#pragma parameter blury "Convergence Y-Axis" -0.25 -1.0 2.0 0.05
#pragma parameter HIGHSCANAMOUNT1 "Scanline Amount (Low)" 0.3 0.0 1.0 0.05
#pragma parameter HIGHSCANAMOUNT2 "Scanline Amount (High)" 0.2 0.0 1.0 0.05
#pragma parameter MASK_DARK "Mask Effect Amount" 0.25 0.0 1.0 0.05
#pragma parameter MASK_FADE "Mask/Scanline Fade" 0.8 0.0 1.0 0.05
#pragma parameter sat "Saturation" 1.1 0.0 3.0 0.05
#pragma parameter SEGA "Sega Brightness Fix" 0.0 0.0 1.0 1.0

#define pi 3.14159
#define blurx params.blurx
#define blury params.blury
#define HIGHSCANAMOUNT1 params.HIGHSCANAMOUNT1
#define HIGHSCANAMOUNT2 params.HIGHSCANAMOUNT2
#define BRIGHTBOOST params.BRIGHTBOOST
#define MASK_DARK params.MASK_DARK
#define MASK_FADE params.MASK_FADE
#define sat params.sat
#define SEGA params.SEGA

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float omega;
layout(location = 2) out vec2 blur;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord*1.0001;
    omega = 2.0*pi*params.SourceSize.y;
    blur = vec2(blurx/1000.0,blury/1000.0);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float omega;
layout(location = 2) in vec2 blur;

layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

vec2 Warp(vec2 pos)
{
    pos  = 2.0*pos - 1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y) * 0.02, 
                1.0 + (pos.x*pos.x) * 0.04);
    
    return pos*0.5 + 0.5;
}

void main()
{
    vec2 pos = Warp(vTexCoord.xy);
  
    vec3 sample1 = texture(Source,vec2(pos.x + blur.x, pos.y - blur.y)).rgb;
    vec3 sample2 = texture(Source,pos).rgb*0.5;
    vec3 sample3 = texture(Source,vec2(pos.x - blur.x, pos.y + blur.y)).rgb;
    
    vec3 colour = vec3 (sample1.r*0.5  + sample2.r, 
                        sample1.g*0.25 + sample2.g + sample3.g*0.25,
                                         sample2.b + sample3.b*0.5);
    
    vec3 lumweight=vec3(0.22,0.7,0.08);
    float lum = dot(colour,lumweight);
    vec3 graycolour = vec3(lum);

    //Gamma-like
    colour*=mix(0.8,1.0,lum);    
    
    float SCANAMOUNT = mix(HIGHSCANAMOUNT1,HIGHSCANAMOUNT2,lum);
    float scanLine =  SCANAMOUNT * sin(pos.y*omega);
    
    float whichmask = fract((pos.x*params.OutputSize.x)*0.4999);
    float mask = 1.0 + float(whichmask < 0.5) * -MASK_DARK;
    colour = vec3(mix(graycolour,colour,sat));

    colour *= mix(mask*(1.0-scanLine), 1.0-scanLine, dot(lum, MASK_FADE));

    if (SEGA == 1.0) colour *= 1.0625;
    FragColor.rgb = colour.rgb;
}
