#version 450
/*
    crt-consumer-1w, A simple CRT shader by metallic77.

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.
    
*/
#pragma parameter dummy2 " [ ----CRT---- ]" 0.0 0.0 0.0 0.0
#pragma parameter u_sharp "Reverse Sharpness" 0.25 0.0 0.5 0.01
#pragma parameter u_warp "Curvature" 0.04 0.0 0.15 0.01
#pragma parameter u_overscanx "Overscan Horiz." 0.3 0.3 2.0 0.05
#pragma parameter u_overscany "Overscan Vertic." 0.3 0.3 2.0 0.05
#pragma parameter res_flash "Resolution Switch Glitch" 0.0 0.0 1.0 1.0
#pragma parameter u_scan "Scanlines Strength" 0.35 0.0 1.0 0.05
#pragma parameter u_wid "Mask Fine/Coarse" 2.0 2.0 3.0 1.0
#pragma parameter u_mask "Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter u_slot "Slot Mask On/Off" 0.0 0.0 1.0 1.0
#pragma parameter slot_str "Slot Mask Strength" 0.7 0.0 1.0 0.05
#pragma parameter u_deconv "De-Convergence Horiz." 0.3 -2.0 2.0 0.05
#pragma parameter u_brightb "Bright Boost" 1.35 1.0 2.0 0.05
#pragma parameter u_vignette "Vignette" 0.15 0.0 0.5 0.01
#pragma parameter u_smptec "sRGB, SMPTE-C, Japan NTSC" 0.0 0.0 2.0 1.0

layout(push_constant) uniform Push
{
float u_sharp,u_warp,u_overscanx,u_overscany,u_scan,u_mask,u_wid,u_deconv,u_brightb,u_vignette,
u_smptec,slot_str,u_slot,res_flash;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
    vec4 OriginalHistorySize1;
	vec4 OutputSize;
	uint FrameCount;
} global;

#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
#define OriginalHistorySize1 global.OriginalHistorySize1
#define OutputSize global.OutputSize
#define FrameCount global.FrameCount

#define u_sharp params.u_sharp
#define u_warp params.u_warp
#define u_overscanx params.u_overscanx
#define u_overscany params.u_overscany
#define u_scan params.u_scan
#define u_mask params.u_mask
#define u_wid params.u_wid
#define u_deconv params.u_deconv
#define u_brightb params.u_brightb
#define u_vignette params.u_vignette
#define u_smptec params.u_smptec
#define slot_str params.slot_str
#define u_slot params.u_slot
#define res_flash params.res_flash

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 ogl2pos;
layout(location = 2) out vec2 invdims;
layout(location = 3) out vec2 maskpos;
layout(location = 4) out vec2 barrel;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   ogl2pos = vTexCoord*SourceSize.xy;
   invdims = u_deconv/SourceSize.xy;
   maskpos = vTexCoord.xy*OutputSize.xy*2.0/u_wid;
   barrel = vec2(1.0-u_warp*u_overscanx, 1.0-u_warp*u_overscany);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 ogl2pos;
layout(location = 2) in vec2 invdims;
layout(location = 3) in vec2 maskpos;
layout(location = 4) in vec2 barrel;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

mat3 smpte_c = mat3(
0.8407,   0.0809,   0.0663,
-0.0373,  0.9960,   0.0363,
0.0089,   -0.0411,  1.1619
);

/* Japanese primaries as in 
Association of Radio Industries and Businesses TECHNICAL REPORT
Association of Radio Industries and Businesses TR-B9 Version 1.0
July 21, 1998 Version 1.0 
Source
https://web.archive.org/web/20130413104152/http://arib.or.jp/english/html/overview/doc/4-TR-B09v1_0.pdf
Page 26

xr  0.618
yr  0.35
xg  0.28
yg  0.605
xb  0.152
yb  0.063
wx  0.2848
wy  0.2933

RGB-->XYZ-->RGB final 
*/
mat3 japan_d93 = mat3(
1.0617,  -0.1145, 0.0702,
0.1261,  0.8585,  0.0199,
0.0196,  -0.0606, 1.3597
);

#define PI 3.14159265358979323846 
#define TAU 6.2831852

float slot(vec2 pos)
{
    float odd = 1.0;
    if (fract(pos.x/(u_wid*2.0)) < 0.5) odd = 0.0;

 return slot_str*sin((pos.y+odd)*PI)+1.0;
}

float res_glitch (vec2 uv)
{
float flash_strength = 0.7;
float flash_width = 0.08;
float flash_decay = 0.92;

// res-switch crt glitch emulator
    float flashTimer = 0.0;

    float curx  = OriginalSize.x;
    float cury  = OriginalSize.y;
    float prevx = OriginalHistorySize1.x;
    float prevy = OriginalHistorySize1.y;

    // detect change in input resolution
    if (curx != prevx || cury != prevy) flashTimer = 1.0;
    flashTimer *= flash_decay;

    float y = uv.y;
    float bar = exp( -pow((y - 0.50) / flash_width, 2.0) );
   
   return flashTimer*bar*flash_strength;
}

void main() {
    vec2 interlace = OriginalSize.y >300.0? vec2(0.0,mod(float(FrameCount),2.0)) : vec2(0.0);
    float interl_lines = OriginalSize.y >300.0? 0.5:1.0;
    // uv in [0,1]
    vec2 uv = vTexCoord;
    // keep "crt frame" stable regardless of overscan
    vec2 pos = uv;
    // --- Barrel warp ---
    // normalized coords centered at 0
    vec2 n = uv * 2.0 - 1.0;
    // polynomial warp
    float rsq = dot(n, n);
    n *= 1.0 + u_warp*rsq*1.5;
    n -= n*(barrel*u_warp);
    n *= barrel;
    uv = (n + 1.0) * 0.5;
    vec2 corn   = min(pos, 1.0-pos); // This is used to mask the rounded
         corn.x = 0.0012/corn.x;   // corners later on 
    
    // pixel size for subpixel offsets
    float px = invdims.x;
    uv += interlace*1.0/SourceSize.y;

    // chroma separation: shift R and B horizontally by +/- small amounts
    vec2 offR = vec2(  px, 0.0);
    vec2 offB = vec2(- px, 0.0);
    vec2 dx = vec2(1.0/SourceSize.x, 0.0);

    // fetch center (G), left/right for R/B
    vec3 colG = texture(Source, uv).rgb;
    vec3 colR = texture(Source, uv + offR).rgb;
    vec3 colB = texture(Source, uv + offB).rgb;

    // reconstruct approximate RGB (we sampled full RGB for each tap,
    // but treat them as subpixel contributions)
    vec3 col = vec3(colR.r, colG.g, colB.b);
    vec3 sharpl  = texture(Source, uv      -dx).rgb*(-u_sharp);
    vec3 sharpl2 = texture(Source, uv - 2.0*dx).rgb*(u_sharp*0.1);
    vec3 sharpr  = texture(Source, uv     + dx).rgb*(-u_sharp);
    vec3 sharpr2 = texture(Source, uv + 2.0*dx).rgb*(u_sharp*0.1);
    
    col = col*(1.0 + u_sharp*1.8) + sharpl+sharpr+sharpl2+sharpr2;
    if (u_smptec == 1.0) col *= smpte_c;
    if (u_smptec == 2.0) col *= japan_d93;
    // --- Scanlines / Mask ---
    float scan = 0.5*sin((uv.y*SourceSize.y*interl_lines-0.25 - interlace.y)*TAU)+0.5;
    float mask = 0.5*sin((maskpos.x)*PI)+0.5;
    col *= mix(1.0, scan, u_scan);
    if (u_slot == 1.0){ 
        mask *= slot(vTexCoord*OutputSize.xy);
    }
    col *= mix(u_brightb, mask, u_mask);
    if (res_flash == 1.0) col += res_glitch(uv);
    // --- Vignette ---
    float vig = 1.0 - u_vignette * pow(length(n), 1.5);
    col *= vig;
if (u_warp > 0.0){  
if (corn.y <= corn.x || corn.x < 0.0001)
    col = vec3(0.0);}
    FragColor = vec4(col, 1.0);
}
