#version 450

/*

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
   float U_RADIUS ;
   float c_gain,COMB;
} params;

#pragma parameter dummy1 " [ ----NTSC---- ] " 0.0 0.0 0.0 0.0
#pragma parameter N_SYSTEM "SNES,MD/PS320,PCE256,PCE320/STELLA" 0.0 0.0 3.0 1.0
#pragma parameter COMB "Comb Filter" 0.25 0.0 1.0 0.05
#pragma parameter Luma_bw "Luma Bandwidth" 2.2 0.0 12.0 0.05
#pragma parameter Chroma_bw "Chroma Bandwidth" 1.0 0.0 6.0 0.05
#pragma parameter U_RADIUS "Radius (slower)" 7.0 3.0 12.0 1.0
#pragma parameter c_gain "Chroma Gain" 2.0 0.0 4.0 0.05

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

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord*1.0001;
   ogl2pos = vTexCoord*SourceSize.xy;
   invdims = 1.0/SourceSize.xy;
   }

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in vec2 ogl2pos;
layout(location = 2) in vec2 invdims;

layout(set = 0, binding = 2) uniform sampler2D Source;

#define PI 3.1415926
#define TAU 6.283185
#define ntsc 3.579545e6
#define SNES256 ntsc*6.0/4.0
#define MD320 ntsc*15.0/8.0
#define PCE256 SNES256
#define PCE320 ntsc*6.0/3.0
#define clock (N_SYSTEM == 0.0 ? SNES256 : N_SYSTEM == 1.0 ? MD320 : N_SYSTEM == 2.0 ? PCE256 : PCE320)
#define cycles ntsc/clock


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
    for (float i = -radius; i <= radius; i += 1.0)
    {
        vec3 tap1  = rgb2yiq*texture(Source, uv + vec2(i * one.x, 0.0)).xyz;
        vec3 tap2  = rgb2yiq*texture(Source, uv + vec2(i * one.x, 0.0) - vec2(0.0,one.y)).xyz;
        // double X samples position to compensate for 0.5*invidms.x
        float phase = (floor(ogl2pos.x*2.0) + i + line + time )*PI*cycles ;
        vec3 carrier1 = vec3(1.0,cos(phase),sin(phase)); 
        vec3 carrier2 = vec3(1.0,-carrier1.y,-carrier1.z); 
        tap1  *= carrier1;
        tap2  *= carrier2;
        float wl = ntsc_filter_weight(i, bandwidth_luma, radius);
        float wc = ntsc_filter_weight(i, bandwidth_chroma, radius);
        float compo1 = dot(tap1,vec3(1.0));
        float compo2 = dot(tap2,vec3(1.0));
        float luma = (compo1+compo2)*0.5;
        signal.r  +=  luma* wl;
        signal.gb += (compo1 - luma*COMB) * carrier1.gb * vec2(wc) * c_gain;
        
        total_luma   += wl;
        total_chroma += wc;
    }

    signal /= vec3(total_luma, total_chroma, total_chroma);
    return signal;
}

void main() {
// keep sharper with 0.5 size horiz. samples
vec2 one = vec2(invdims.x*0.5,invdims.y*0.25);
vec3 rgb = filter_ntsc(vTexCoord, Luma_bw, Chroma_bw, U_RADIUS, one);
FragColor = vec4(yiq2rgb*rgb, 1.0);

}