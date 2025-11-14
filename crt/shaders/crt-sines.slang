#version 450

/*

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.
*/

#pragma parameter glow_str "Glow Strength in mask" 1.25 1.0 2.0 0.05
#pragma parameter dark_boost "Boost Dark Palettes" 2.5 1.0 4.0 0.05
#pragma parameter SCNL "Scanline Strength" 0.5 0.0 0.5 0.05
#pragma parameter mask_type "Mask Fine/Coarse" 0.0 0.0 1.0 1.0
#pragma parameter MSK_BRI "Mask Brightness" 0.15 0.0 1.0 0.05
#pragma parameter u_vignette "Vignette Strength" 0.3 0.0 1.0 0.05

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float glow_str,dark_boost,SCNL,MSK_BRI,u_vignette,mask_type;
} params;

#define SourceSize params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize params.OutputSize
#define FrameCount params.FrameCount
#define glow_str params.glow_str
#define dark_boost params.dark_boost
#define SCNL params.SCNL
#define MSK_BRI params.MSK_BRI
#define u_vignette params.u_vignette
#define mask_type params.mask_type



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
layout(location = 3) out float maskpos;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   ogl2pos = vTexCoord*SourceSize.xy;
   invdims = 1.0/SourceSize.xy;
   maskpos = vTexCoord.x*OutputSize.x;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in vec2 ogl2pos;
layout(location = 2) in vec2 invdims;
layout(location = 3) in float maskpos;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define TAU 6.28315
const vec3 grayWeights = vec3(0.3, 0.6, 0.1); 

// barrel distortion / CRT curvature
vec2 curveUV(vec2 uv) {
    // uv is assumed in 0–1 range
    vec2 warp = vec2(0.0,0.1);
    vec2 centered = uv * 2.0 - 1.0;    // map to -1..1
    float r2 = dot(centered, centered);  // radius²

    // polynomial warp
    centered *= 1.0 + r2 * warp * 0.5;

    return (centered * 0.5) + 0.5;       // back to 0–1
}

void main() {
   vec2 uv = curveUV(vTexCoord*vec2(1.0,0.95) + vec2(0.0,0.025));
   vec2 dx = vec2(invdims.x,0.0);
   float fpos = uv.y*SourceSize.y;
   float near = floor(fpos) + 0.5;
   float f = fpos - near;
   float s = sign(f);
   float y = (near + s*f*f*(2.0-f))*invdims.y;
   vec2 pos = vec2(uv.x,y);
   vec3 res = texture(Source, pos).rgb;
   vec3 res1 = texture(Source, pos + dx).rgb;
   vec3 res2 = texture(Source, pos - dx).rgb;
   float l = max(max(res.r,res.g),res.b);
   res *= mix(dark_boost,1.05,l);
   
   float scan = SCNL*sin((fpos-0.25)*TAU)+1.0-SCNL;
   res *= mix(scan,1.0,l*0.6);
   float m = mod(floor(maskpos),2.0);

   vec3 mask = mix(vec3(1.0,MSK_BRI,1.0),vec3(MSK_BRI,1.0,MSK_BRI),m);
if (mask_type == 1.0) {m =  mod(floor(maskpos),3.0);
   if (m==0.0) mask = vec3(1.0,1.0,MSK_BRI);
   if (m==1.0) mask = vec3(1.0,MSK_BRI,1.0);
   if (m==2.0) mask = vec3(MSK_BRI,1.0,1.0);
}

   vec3 glow = (res+res1+res2)*0.12;
   float lm = dot(vec3(1.0),glow);
   res *= mix(mask,vec3(glow_str), lm*0.4);
   float vig = 1.0 - u_vignette * pow(length(vTexCoord.x*2.0-1.0), 1.5);
    res *= vig;

   FragColor = vec4(sqrt(res), 1.0);
}
