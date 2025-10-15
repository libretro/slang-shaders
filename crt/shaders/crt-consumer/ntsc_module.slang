#version 450
/*
    NTSC module, DariusG 2025 — Universal NTSC Composite Emulator

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.
    
*/
#pragma parameter dummy1 " [ ----NTSC---- ]" 0.0 0.0 0.0 0.0 
#pragma parameter u_svideo "S-Video" 0.0 0.0 1.0 1.0
#pragma parameter u_system "Clock: SNES/PS1-256, MD/PCE/PS1-320" 0.0 0.0 1.0 1.0
#pragma parameter u_comb "Comb Filter Strength" 0.6 0.0 1.0 0.05
#pragma parameter u_chroma "Chroma Gain" 1.5 0.0 3.0 0.05
#pragma parameter LPY "Luma Resolution" 1.6 0.0 3.0 0.02
#pragma parameter LPC "Chroma Resolution" 0.32 0.0 0.8 0.01
#pragma parameter u_res "Taps" 3.0 1.0 3.0 1.0
#pragma parameter dummy2 " [ ----NTSC---- ]" 0.0 0.0 0.0 0.0 

layout(push_constant) uniform Push
{
float u_svideo,u_system,u_comb,u_chroma,LPY,LPC,u_res;
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

#define u_svideo params.u_svideo
#define u_system params.u_system
#define u_comb params.u_comb
#define u_chroma params.u_chroma
#define LPY params.LPY
#define LPC params.LPC
#define u_res params.u_res

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 ogl2pos;
layout(location = 2) out vec2 invdims;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   ogl2pos = vTexCoord*SourceSize.xy;
   invdims = 1.0/SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 ogl2pos;
layout(location = 2) in vec2 invdims;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


#define PI 3.14159265358979323846 
#define TAU 6.2831852
#define cycles 170.666/OriginalSize.x
#define crawl ((u_system == 0.0) ? mod(float(FrameCount), 2.0) * PI : 0.0)

vec3 yiq(vec3 c) {
  float Y = 0.299*c.r + 0.587*c.g + 0.114*c.b;
  float I = 0.5959*c.r - 0.2746*c.g - 0.3213*c.b;
  float Q = 0.2115*c.r - 0.5227*c.g + 0.3112*c.b;
  return vec3(Y,I,Q);
}
vec3 rgb(vec3 yiq) {
  float Y = yiq.x, I = yiq.y, Q = yiq.z;
  float R = Y + 0.9563*I + 0.6210*Q;
  float G = Y - 0.2721*I - 0.6474*Q;
  float B = Y - 1.1069*I + 1.7046*Q;
  return vec3(R,G,B);
}

#define taps int(u_res)

void main()
{   
    vec3 final = vec3(0.0);
    vec2 dx = vec2(invdims.x,0.0);
    vec2 dy = vec2(0.0,invdims.y*0.25);
    float sumY = 0.0;
    float sumI = 0.0;
    float sumQ = 0.0;

    float line = u_system == 0.0? floor(ogl2pos.y)*TAU*cycles :floor(ogl2pos.y)*PI;

    for (int i=-taps; i<taps+1; i++)
    {
    float n = float(i);
    float p = n;
    float wY = exp(-LPY*n*n);
    float wI = exp(-LPC*p*p);
    float wQ = exp(-LPC*p*p);
    sumY += wY;    
    sumI += wI;    
    sumQ += wQ;    
    float phase = (ogl2pos.x + n)*cycles*PI + line + crawl;
    float cs = cos(phase);
    float sn = sin(phase);
    vec3 burst1 = vec3(1.0,cs,sn);
    vec3 burst2 = vec3(1.0,-cs,-sn);
    vec3 res1 = yiq(texture(Source,vTexCoord + dx*n).rgb)*burst1;
    vec3 res2 = yiq(texture(Source,vTexCoord + dx*n - dy).rgb)*burst2;
    float signal1 = u_svideo == 0.0 ? dot(vec3(1.0),res1) : dot(vec2(1.0),res1.gb);
    float signal2 = dot(vec3(1.0),res2);
    float luma = u_svideo == 0.0 ? (signal1 + signal2)*0.5 : res1.r;
    final.r += luma*wY;
    final.g += u_svideo == 0.0 ? (signal1 - luma*u_comb)*wI*burst1.g*u_chroma :
    signal1 * wI*burst1.g*u_chroma;
    final.b += u_svideo == 0.0 ? (signal1 - luma*u_comb)*wQ*burst1.b*u_chroma :
    signal1 * wQ*burst1.b*u_chroma;
    }   
    final.r /= sumY;
    final.g += final.b*0.2;
    final.g /= sumI;
    final.b /= sumQ;
    FragColor.rgb = rgb(final);
}
