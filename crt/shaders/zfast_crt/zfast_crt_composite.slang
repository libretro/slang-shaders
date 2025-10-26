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
     float WARP;
 float SCANLINE;
 float MASK;
 float MASK_WID;
 float BORDER;
 float U_NOISE;
 float U_CONVERG;
 float NTSC_J;
 float U_SAT;
} params;

#pragma parameter WARP "Curvature" 0.08 0.0 0.3 0.01
#pragma parameter BORDER "Border Smooth" 0.015 0.0 0.1 0.005
#pragma parameter U_CONVERG "Convergence" 0.8 0.0 3.0 0.05
#pragma parameter SCANLINE "Scanline Brightness" 0.25 0.0 0.5 0.05
#pragma parameter MASK "Mask Brightness" 0.35 0.0 0.5 0.05
#pragma parameter MASK_WID "Mask: CGWG, Slot2, Slot3" 1.0 1.0 3.0 1.0
#pragma parameter U_NOISE "Glass Dust/Noise" 0.15 0.0 1.0 0.05
#pragma parameter U_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter NTSC_J "NTSC-J colors" 0.0 0.0 1.0 1.0

#define PI 3.14159
#define TAU 6.28318
#define u_time float(FrameCount)/60.0
#define pix 1.0/OutputSize.xy
#define SourceSize params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize params.OutputSize
#define FrameCount params.FrameCount
#define WARP params.WARP
#define SCANLINE  params.SCANLINE
#define MASK  params.MASK
#define MASK_WID  params.MASK_WID
#define BORDER  params.BORDER
#define U_NOISE  params.U_NOISE
#define U_CONVERG  params.U_CONVERG
#define NTSC_J  params.NTSC_J
#define U_SAT  params.U_SAT

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float interlace;
layout(location = 2) out vec2 invdims;
layout(location = 3) out vec2 maskpos;

void main()
{
    gl_Position = global.MVP * Position;
    invdims = 1.0/SourceSize.xy;
    interlace = OriginalSize.y > 300.0 ? mod(float(FrameCount),2.0) : 0.0;
    vTexCoord = TexCoord*1.0001 + vec2(0.0,invdims.y)*interlace;
    maskpos = vTexCoord.xy*OutputSize.xy;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float interlace;
layout(location = 2) in vec2 invdims;
layout(location = 3) in vec2 maskpos;

layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#if defined GL_ES

mat3 hue = mat3(                
0.60722     ,0.25198 ,   0.27164,
-0.10833    ,0.98873 ,   0.19229,
-0.02558    ,0.12980 ,   1.10027);

#else
mat3 hue = mat3(                    
0.9501  ,   -0.0431 ,   0.0857  ,
0.0265  ,   0.9278  ,   0.0432  ,
0.0011  ,   -0.0206 ,   1.3153  );

#endif

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main()
{
// 0.0 to 1.0 range
vec2 pos = vTexCoord*(1.0-WARP*0.12) + WARP*vec2(0.06,0.); 

// curve horizontally & vertically
float cx = pos.x - 0.5; // -0.5 to 0.5
float cy = pos.y - 0.5; // -0.5 to 0.5
    pos.x = pos.x + (cy * cy * WARP * cx);
    pos.y = pos.y + (cx * cx * WARP*2.0 * cy);
vec2 cpos = pos;

float spos = pos.y*SourceSize.y;    

    pos = pos*SourceSize.xy + 0.5;
vec2 i = floor(pos);
vec2 f = pos - i;        // -0.5 to 0.5
float s1 = f.y;
float s2 = 1.0-f.y;
    f = f*f*(3.0-2.0*f);
    f.y *= f.y*f.y*f.y;
    pos = (i + f - 0.5)*invdims;

vec3 rgb = texture(Source,pos).rgb;

// shift red and blue sideways (simulate chroma smear)
float shift = U_CONVERG * 1.5; // adjustable bleed amount in pixels
// optional blur on chroma to get softer smear
if (U_CONVERG > 0.01) {
    vec3 r_blur = texture(Source, pos + vec2(pix.x * shift * 0.5, 0.0)).rgb;
    vec3 g_blur = texture(Source, pos - vec2(pix.x * shift * 0.5, 0.0)).rgb;
    vec3 b_blur = texture(Source, pos + vec2(pix.x * shift * 0.5, 0.0)).rgb;
        rgb.r = mix(rgb.r, r_blur.r, 0.5 * U_CONVERG);
        rgb.g = mix(rgb.g, g_blur.g, 0.5 * U_CONVERG);
        rgb.b = mix(rgb.b, b_blur.b, 0.5 * U_CONVERG);
    }

 // Subtle noise/dust
if (U_NOISE > 0.001) {
    float nval = rand(vec2(0.0, pos.y * SourceSize.y + u_time));
    float dust = smoothstep(0.9 - U_NOISE * 0.2, 1.0, nval) * 0.08 * U_NOISE;
        rgb += dust;
    } 

if (NTSC_J == 1.0) {rgb *= hue;}
// calc scanlines
vec3 lumS = SCANLINE*rgb;
vec3 scan = 0.5-lumS;
if (OriginalSize.y > 300.0) spos *= 0.5;
    rgb *= scan*sin((spos - 0.5 + interlace)*TAU)+0.5+lumS;

// calc mask
vec3 lumM = MASK*rgb;
vec3 mask = 0.5-lumM;
float slot = MASK_WID > 1.0? floor(maskpos.y): 0.0;
float mpos = mod(floor(maskpos.x/MASK_WID) + slot ,2.0) ;
    rgb *= mix(vec3(1.0),0.7+lumM,mpos);


float l = dot(vec3(0.3,0.6,0.1),rgb);
rgb = mix(vec3(l),rgb, U_SAT);
 
// fade screen edges (linear falloff)
float fade_x = smoothstep(0.0, BORDER, cpos.x) *
               smoothstep(0.0, BORDER, 1.0 - cpos.x);
float fade_y = smoothstep(0.0, BORDER*1.5, cpos.y) *
               smoothstep(0.0, BORDER*1.5, 1.0 - cpos.y);
// combine fades
float fade = fade_x * fade_y; 

    FragColor.rgb = sqrt(rgb)*fade;
}
