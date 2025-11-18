#version 450

/*
NTSC module XL, DariusG 2025 — Universal NTSC Composite Emulator

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
   float N_SYSTEM;
  float Luma_bw ;
   float Chroma_bw ;
   float U_RADIUS,uModePAL ;
   float c_gain,COMB,SVIDEO,RY_boost;
} params;

#pragma parameter dummy1 " [ ----NTSC---- ] " 0.0 0.0 0.0 0.0
#pragma parameter SVIDEO "S-VIDEO" 0.0 0.0 1.0 1.0
#pragma parameter uModePAL "PAL" 0.0 0.0 1.0 1.0
#pragma parameter N_SYSTEM "SNES, Sega/PS1, PCE, A26, ZX Spec" 0.0 0.0 4.0 1.0
#pragma parameter COMB "Comb Filter" 0.25 0.0 1.0 0.05
#pragma parameter Luma_bw "Luma Bandwidth (RF -0.5, SVID +0.5)" 2.8 0.0 12.0 0.05
#pragma parameter Chroma_bw "Chroma Bandwidth" 1.0 0.0 6.0 0.05
#pragma parameter U_RADIUS "Radius (slower)" 7.0 3.0 12.0 1.0
#pragma parameter RY_boost "R-Y boost" 1.35 1.0 2.0 0.05
#pragma parameter c_gain "Chroma Gain" 1.8 0.0 4.0 0.05

#define SourceSize params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize params.OutputSize
#define FrameCount params.FrameCount
#define N_SYSTEM params.N_SYSTEM
#define Luma_bw params.Luma_bw
#define Chroma_bw params.Chroma_bw
#define U_RADIUS params.U_RADIUS
#define c_gain params.c_gain
#define COMB params.COMB
#define SVIDEO params.SVIDEO
#define uModePAL params.uModePAL
#define RY_boost params.RY_boost

#define PI 3.1415926
#define TAU 6.283185
#define ntsc 3.579545e6
#define SNES256 ntsc*6.0/4.0
#define MD320 ntsc*15.0/8.0
#define PCE320 ntsc*6.0/3.0


layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 ogl2pos;
layout(location = 2) out vec2 invdims;
layout(location = 3) out float cycles;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord*1.0001;
   ogl2pos = vTexCoord*SourceSize.xy;
   invdims = 1.0/SourceSize.xy;
   float clock = \
     (N_SYSTEM == 0.0 ? SNES256 \
    : N_SYSTEM == 1.0 ? OriginalSize.x<300.0 ? SNES256: MD320 \
    : N_SYSTEM == 2.0 ? OriginalSize.x<300.0 ? SNES256 :PCE320 \
    : N_SYSTEM == 3.0 ? PCE320 \
    : SNES256 );
   cycles = ntsc/clock;
   }

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in vec2 ogl2pos;
layout(location = 2) in vec2 invdims;
layout(location = 3) in float cycles;

layout(set = 0, binding = 2) uniform sampler2D Source;




const mat3 yiq2rgb = mat3(
   1.0, 0.956, 0.6210,
   1.0, -0.2720, -0.6474,
   1.0, -1.1060, 1.7046);

const mat3 rgb2yiq = mat3(
      0.2989, 0.5870, 0.1140,
      0.5959, -0.2744, -0.3216,
      0.2115, -0.5229, 0.3114
);

// NTSC-style FIR filter generation (no arrays)

float sinc(float x)
{
    if (abs(x) < 1e-5) return 1.0;
    return sin(PI * x) / (PI * x);
}

float hamming(float x, float radius)
{
    // Hamming window for |x| <= radius
    float n = (x + radius) / (2.0 * radius);
    return 0.54 - 0.46 * cos(TAU * n);
}

// Generic FIR filter for NTSC simulation
// bandwidth = cutoff frequency ratio 
// radius = how many pixels to sample each side 
float ntsc_filter_weight(float offset, float bandwidth, float radius)
{
    float x = offset / radius;
    return sinc(x * bandwidth) * hamming(offset, radius);
}

vec3 filter_ntsc(vec2 uv, float bandwidth_luma, float bandwidth_chroma, float radius, vec2 one)
{
    vec3 signal = vec3(0.0);
    float total_luma = 0.0;
    float total_chroma = 0.0;
    float line = N_SYSTEM == 0.0 ? mod(floor(ogl2pos.y),3.0) : 0.0 ;
    float time = N_SYSTEM == 0.0 ? mod(float(FrameCount),2.0) : 0.0;
    float pal_alt = 0.0;
    // PAL alternate lines  
    if (uModePAL == 1.0) {
        // flip sign every other line (equivalent to add PI)
        if (mod(floor(ogl2pos.y), 2.0) < 0.5) {
            pal_alt = PI; // add pi on odd lines
        }
    }

    for (float i = -radius; i <= radius; i += 1.0)
    {
        vec3 tap1  = rgb2yiq*texture(Source, uv + vec2(i * one.x, 0.0)).xyz;
        vec3 tap2  = rgb2yiq*texture(Source, uv + vec2(i * one.x, 0.0) - vec2(0.0,one.y)).xyz;
        // double X samples position to compensate for 0.5*invidms.x
        float phase = (floor(ogl2pos.x*2.0) + i + line + time )*PI*cycles ;
        phase += pal_alt;
        vec3 carrier1 = vec3(1.0,cos(phase),sin(phase)); 
        vec3 carrier2 = vec3(1.0,-carrier1.y,-carrier1.z); 
        tap1  *= carrier1;
        tap2  *= carrier2;
        float wl = ntsc_filter_weight(i, bandwidth_luma, radius);
        float wc = ntsc_filter_weight(i, bandwidth_chroma, radius);
        float compo1 = SVIDEO == 0.0 ? dot(tap1,vec3(1.0)) : dot(vec2(1.0),tap1.gb);
        float compo2 = dot(tap2,vec3(1.0));
        float luma = SVIDEO == 0.0 ? (compo1+compo2)*0.5 : tap1.r;
        signal.r  +=  luma* wl;
        signal.gb += SVIDEO == 0.0 ?(compo1 - luma*COMB) * carrier1.gb * vec2(wc) * c_gain*vec2(RY_boost,1.0) : 
        compo1 * carrier1.gb * vec2(wc) * c_gain * vec2(RY_boost,1.0);
        
        total_luma   += wl;
        total_chroma += wc;
    }

    signal /= vec3(total_luma, total_chroma, total_chroma);
    return signal;
}

void main() {
// grab the next "480p" Y pixel in 240p mode, 
// and 2 pixels away (we don't have access in interlace) in 480i for Comb filtering
// keep it sharp for better visual clarity
vec2 one = vec2(invdims.x*0.5, invdims.y*(OriginalSize.y <300.0 ? 0.5:1.0));
vec3 rgb = filter_ntsc(vTexCoord, Luma_bw, Chroma_bw, U_RADIUS, one);
FragColor = vec4(yiq2rgb*rgb, 1.0);
}
