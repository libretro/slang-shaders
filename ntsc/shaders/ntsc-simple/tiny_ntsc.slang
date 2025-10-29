#version 450

/*
Tiny_NTSC by DariusG 2024-2025

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.
*/

layout(push_constant) uniform Push
{
float comb;
float taps;
float lpf_w;
float lpf_w_c;
float y_lpf;
float c_lpf;
float ntsc_sat;
} params;

#pragma parameter comb "Comb Filter Strength" 0.4 0.0 1.0 0.05
#pragma parameter taps "Filter Taps (slower)" 6.0 2.0 8.0 2.0
#pragma parameter lpf_w "Low Pass Width Y" 0.5 0.25 2.0 0.25
#pragma parameter lpf_w_c "Low Pass Width C" 1.0 0.25 4.0 0.25
#pragma parameter y_lpf "Luma Low Pass (sharpness)" 0.35 0.0 1.0 0.01
#pragma parameter c_lpf "Chroma Low Pass (bleed)" 0.15 0.0 1.0 0.01
#pragma parameter ntsc_sat "Saturation" 0.8 0.0 3.0 0.05

#define comb params.comb
#define taps params.taps
#define lpf_w params.lpf_w
#define lpf_w_c params.lpf_w_c
#define c_lpf params.c_lpf
#define y_lpf params.y_lpf
#define ntsc_sat params.ntsc_sat

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   uint FrameCount;

} global;

#define OutputSize global.OutputSize
#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
#define FrameCount global.FrameCount

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 ogl2pos;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
   ogl2pos = vTexCoord*SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 ogl2pos;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define PI 3.1415926
#define ntsc 3.579545e6
#define clock (OriginalSize.x ==256.0 ? ntsc*1.5 : OriginalSize.x == 320.0 ? ntsc*15.0/8.0 : ntsc*160.0/OriginalSize.x)
#define cycles PI*ntsc/clock
#define timer (OriginalSize.x == 256.0 ? mod(float(FrameCount),2.0)*cycles : 0.0)
#define phase_y (OriginalSize.x<300.0? mod(floor(ogl2pos.y),3.0)*cycles*2.0 : mod(floor(ogl2pos.y),2.0)*cycles*2.0)

mat3 RGBYUV = mat3(0.299, 0.587, 0.114,
                   -0.299, -0.587, 0.886, 
                   0.701, -0.587, -0.114);

mat3 YUV2RGB = mat3(1.0, 0.0, 1.13983,
                    1.0, -0.39465, -0.58060,
                    1.0, 2.03211, 0.0);

void main()
{
    vec2 p = vec2(SourceSize.z*lpf_w,0.0);
    vec2 pc = vec2(SourceSize.z*lpf_w_c,0.0);
    vec2 y = vec2(0.0,SourceSize.w*0.25);
    vec3 final = vec3(0.0);
    float sum = 0.0;
    float sumY = 0.0;
    int steps = int(taps); 
for (int i=-int(steps); i<int(steps+1); i++)
{
    float n = float(i);    
    float w  = exp(-c_lpf*n*n);
    float wY = exp(-y_lpf*n*n);
    // phase cycles horizontally:
    float phase_x = floor(ogl2pos.x + n)*cycles;

// Combined horizontal + vertical phase in 3-phase space (NES):
    float phase = phase_x + phase_y  + timer;
    vec3 carrier   = vec3(1.0, cos(phase ),   sin(phase));
    vec3 carrierup = vec3(1.0, -carrier.y, -carrier.z);
    
    vec3 res    = texture(Source,vTexCoord + n*p).rgb*RGBYUV;
    vec3 resc   = texture(Source,vTexCoord + n*pc).rgb*RGBYUV;
    vec3 resup  = texture(Source,vTexCoord + n*p -y).rgb*RGBYUV;
    vec3 resupc = texture(Source,vTexCoord + n*pc -y).rgb*RGBYUV;
    
    res    *= carrier;
    resc   *= carrier;
    resup  *= carrierup;
    resupc *= carrierup;

    //get composite sample
    float line   = dot(res,vec3(1.0));
    float linec   = dot(resc,vec3(1.0));

    float lineup = dot(resup,vec3(1.0));
    float lineupc = dot(resupc,vec3(1.0));

    // comb luma is line adding previous line, chroma is cancelled!
    float luma  = (line  + lineup)*0.5;
    float lumac = (linec + lineupc)*0.5;
    // comb chroma is line subtracting luma we already have!
    float chroma = linec - lumac*comb;
    // lowpass Y and C, Luma has more bandwidth than Chroma (sharper)
    if (i>-(steps/2) && i<(steps/2 + 1))
    {
    final.r  += luma*wY;
    sumY += wY;
    }
    final.gb += vec2(chroma)*vec2(ntsc_sat*1.5,ntsc_sat*2.0)*carrier.yz*w;

    sum  += w;
}
    final.r  /= sumY;
    final.gb /= sum;
    FragColor.rgb = clamp(final*YUV2RGB,vec3(0.0),vec3(1.0));
}
