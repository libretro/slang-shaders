#version 450

/*
ntsc-simple by DariusG 2024-25

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.
*/


#define PI   3.14159265358979323846
#define TAU  6.28318530717958647693
#define ntsc 3.579545
#define nes256 0.6666
#define md320  0.5333
#define pce320 0.5
#define secs float(FrameCount)/60.0

#pragma parameter u_mode "SNES, MD/PS1, PCE" 0.0 -1.0 2.0 1.0
#pragma parameter u_pal "PAL" 0.0 0.0 1.0 1.0
#pragma parameter u_cable "RF, Composite, S-Video" 1.0 0.0 2.0 1.0
#pragma parameter l_bw "Luma Bandwidth" 2.4 0.0 5.0 0.05
#pragma parameter c_bw "Chroma Bandwidth" 0.6 0.0 4.0 0.05
#pragma parameter u_gain "Chroma Gain" 1.5 0.0 3.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
    float u_mode, c_bw, l_bw, u_gain, u_pal, u_cable;
} params;

#define SourceSize params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize params.OutputSize
#define FrameCount params.FrameCount
#define u_mode params.u_mode
#define c_bw params.c_bw
#define l_bw params.l_bw
#define u_gain params.u_gain
#define u_pal params.u_pal
#define u_cable params.u_cable

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
   cycles = PI * (u_mode == 0.0 ? nes256 \
             : u_mode == 1.0 ? OriginalSize.x < 300.0 ? nes256 : md320 \
             : u_mode == 2.0 ? OriginalSize.x < 300.0 ? nes256 : pce320  \
             : ntsc);
   float rf_drift = (u_cable == 0.0) ? sin(secs * 0.8) * 0.002 * 0.2 : 0.0;
   vTexCoord.x += rf_drift * sin(vTexCoord.y * 120.0 + secs * 5.0);

}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in vec2 ogl2pos;
layout(location = 2) in vec2 invdims;
layout(location = 3) in float cycles;

layout(set = 0, binding = 2) uniform sampler2D Source;


vec3 rgb2yiq(vec3 rgb) {
    float Y = dot(rgb, vec3(0.299,  0.587, 0.114));
    float I = dot(rgb, vec3(0.596, -0.274,-0.322));
    float Q = dot(rgb, vec3(0.211, -0.523, 0.312));
    return vec3(Y, I, Q);
}

vec3 yiq2rgb(vec3 yiq) {
    float r = dot(yiq, vec3(1.000,  0.956, 0.621));
    float g = dot(yiq, vec3(1.000, -0.272,-0.647));
    float b = dot(yiq, vec3(1.000, -1.106, 1.703));
    return vec3(r, g, b);
}

#define radius (u_cable == 0.0 ? 13.0 : u_cable == 1.0 ? 11.0 : 9.0)

float blackman(float n, float N, float bw) {
    return (0.5-bw) - (0.5 * cos((TAU * n) / N)) + (bw * cos((2.0 * TAU * n) / N));
}


float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
    vec2 dx = vec2(invdims.x,0.0);
    float total_luma = 0.0;
    float total_chroma = 0.0;
    vec3 color = vec3(0.0);
    float line = u_mode == 0.0 ? floor(ogl2pos.y)*cycles : u_pal == 1.0 ? mod(floor(ogl2pos.y),2.0)*PI : 0.0;
    float timer = u_mode == 0.0 && u_cable != 0.0 ? mod(float(FrameCount),2.0)*PI \
    : u_mode == 0.0 && u_cable == 0.0 ? mod(float(FrameCount),3.0)*PI \
    : 0.0;
// chroma
    for (float n = 0.0; n<radius; n++)
    {
    float offset = n - (radius-1.0)/2.0 ;   
    float rf_jitter = (u_cable == 0.0) ? (rand(vec2(vTexCoord.y, secs + offset)) - 0.5) * 0.2 :0.0;
 
    float weight = blackman(n, radius, c_bw/10.0); total_chroma += weight;  
      
    vec3 res = rgb2yiq(texture(Source,vTexCoord + offset*dx).rgb);
    float phase = (floor(ogl2pos.x) + offset + rf_jitter)*cycles + line + timer;
    float cs = cos(phase); float sn = sin(phase);
    vec2 burst = vec2(cs,sn);
    res.gb *= burst;
    float signal = u_cable != 2.0? dot(vec3(1.0),res) : dot(vec2(1.0),res.gb) ;
    color.gb += signal*weight*burst*u_gain;

    float weightY = blackman(n, radius, l_bw/10.0); total_luma += weightY;        
    color.r += u_cable != 2.0 ? signal*weightY : res.r*weightY;
    }

    color.r  /= total_luma;
    color.gb /= total_chroma;
    FragColor = vec4(yiq2rgb(color),1.0);
}
