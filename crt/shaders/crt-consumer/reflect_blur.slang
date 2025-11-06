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

} params;

#define SourceSize params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize params.OutputSize
#define FrameCount params.FrameCount


#pragma parameter dummy1 "[ NTSC ]" 0.0 0.0 0.0 0.0

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 ogl2pos;
layout(location = 2) out vec2 pix;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   ogl2pos = vTexCoord*SourceSize.xy;
   pix = 1.0/SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in vec2 ogl2pos;
layout(location = 2) in vec2 pix;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define linear(c) c*c

// Mirrors a value outward from an interval [a, b]
float mirrorBorder1D(float x, float a, float b)
{
    float len = b - a;

    if (x < a)
    {
        float d = a - x;              // distance outside left
        float m = mod(d, len * 2.0);  // fold into stripes
        return (m <= len) ? a + m : b - (m - len);
    }
    else if (x > b)
    {
        float d = x - b;              // distance outside right
        float m = mod(d, len * 2.0);
        return (m <= len) ? b - m : a + (m - len);
    }

    // Inside: unchanged
    return x;
}

vec2 mirrorBorderUV(vec2 uv, vec2 rectMin, vec2 rectMax)
{
    return vec2(
        mirrorBorder1D(uv.x, rectMin.x, rectMax.x),
        mirrorBorder1D(uv.y, rectMin.y, rectMax.y)
    );
}
vec2 Warp(vec2 pos)
{
    pos = pos*2.0-1.0;
    pos *= vec2(1.0+pos.y*pos.y*-0.03, 1.0+pos.x*pos.x*0.03);
    pos = pos*0.5+0.5;

    return pos;
}

void main() {
vec2 pos = Warp(vTexCoord);    
// your border rectangle (normalized UV)
// adjust these so they match the red outlinex
vec2 rectMin = vec2(0.0);
float x = pos.x*2.0-1.0; x *= x; 
float y = pos.y*2.0-1.0; y *= y;
rectMin.x = mix(0.0, 0.02,x);
rectMin.y = mix(0.0, 0.02,y);

vec2 rectMax = vec2(0.0);
rectMax.x = mix(1.0, 0.98,x);
rectMax.y = mix(1.0, 0.98,y);

vec2 dx = vec2(pix.x,0.0);
vec2 dy = vec2(0.0,pix.y);
vec4 col = vec4(0.0);
float sum = 0.0;
vec2 uv = mirrorBorderUV(pos, rectMin, rectMax);

for (int i=-2; i<3; i++)
{
   for (int j=-2; j<3; j++)
   {
   float n = float(i);
   float w = exp(-0.1*n*n);   
   col += texture(Source, uv + n*dx + j*dy)*w;
   sum += w;
   }
}

col /= sum;
//col = linear(col);
FragColor = col*1.25;
}
