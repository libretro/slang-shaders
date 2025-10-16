#version 450
/*
    crt-consumer-1w, A simple CRT shader by metallic77.

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.
    
*/
#pragma parameter u_sharp "Reverse Sharpness" 0.25 0.0 0.5 0.01
#pragma parameter u_warp "Curvature" 0.04 0.0 0.15 0.01
#pragma parameter u_overscanx "Overscan Horiz." 0.3 0.3 2.0 0.05
#pragma parameter u_overscany "Overscan Vertic." 0.3 0.3 2.0 0.05
#pragma parameter u_scan "Scanlines Strength" 0.35 0.0 1.0 0.05
#pragma parameter u_mask "Mask Strength" 0.25 0.0 1.0 0.05
#pragma parameter u_wid "Mask Fine/Coarse" 2.0 2.0 3.0 1.0
#pragma parameter u_deconv "De-Convergence Horiz." 0.3 -2.0 2.0 0.05
#pragma parameter u_brightb "Bright Boost" 1.35 1.0 2.0 0.05
#pragma parameter u_vignette "Vignette" 0.15 0.0 0.5 0.01

layout(push_constant) uniform Push
{
float u_sharp,u_warp,u_overscanx,u_overscany,u_scan,u_mask,u_wid,u_deconv,u_brightb,u_vignette;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} global;

#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
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


#define PI 3.14159265358979323846 
#define TAU 6.2831852

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

    // --- Scanlines / Mask ---
    float scan = 0.5*sin((uv.y*SourceSize.y*interl_lines-0.25 - interlace.y)*TAU)+0.5;
    float mask = 0.5*sin((maskpos.x)*PI)+0.5;
    col *= mix(1.0, scan, u_scan);
    col *= mix(u_brightb, mask, u_mask);


    // --- Vignette ---
    float vig = 1.0 - u_vignette * pow(length(n), 1.5);
    col *= vig;
if (u_warp > 0.0){  
if (corn.y <= corn.x || corn.x < 0.0001)
    col = vec3(0.0);}
    FragColor = vec4(col, 1.0);
}
