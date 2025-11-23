#version 450

/*

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

*/

layout(push_constant) uniform Push
{
   float beam_max, beam_min, scan_max, scan_min,CURVATURE_X,
   CURVATURE_Y,CURVATURE_SCALE,u_vignette,MSK_BRI,mask_type,
   boost_bright,boost_dark,glow_str,color_sat,deconv,glass_refl,
   MSK_WIDTH,MSK_HEIGHT,MSK_STAG,glass_refl_pos;
} params;

#pragma parameter dummy_beam " [ BEAM ] " 0.0 0.0 0.0 0.0
#pragma parameter beam_min "Scanline Beam Min." 8.0 2.0 15.0 1.0 
#pragma parameter beam_max "Scanline Beam Max." 6.0 2.0 15.0 1.0 
#pragma parameter scan_min "Scanlines Min" 1.3 0.0 2.5 0.05
#pragma parameter scan_max "Scanlines Max" 1.0 0.0 2.5 0.05

#pragma parameter dummy_mask " [ MASK ] " 0.0 0.0 0.0 0.0
#pragma parameter mask_type "Mask Fine/Coarse" 0.0 0.0 1.0 1.0
#pragma parameter MSK_WIDTH "Mask Width" 1.0 1.0 4.0 1.0
#pragma parameter MSK_HEIGHT "Mask Height" 1.0 1.0 4.0 1.0
#pragma parameter MSK_STAG "Mask Stagger" 0.0 0.0 2.0 1.0
#pragma parameter MSK_BRI "Mask Brightness" 0.4 0.0 1.0 0.05

#pragma parameter dummy_tube " [ TUBE ] " 0.0 0.0 0.0 0.0
#pragma parameter CURVATURE_X "Curvature Horiz." 0.0 0.0 0.3 0.01
#pragma parameter CURVATURE_Y "Curvature Vert." 0.06 0.0 0.3 0.01
#pragma parameter CURVATURE_SCALE "Curvature Scale" 0.0 0.0 1.0 0.01
#pragma parameter u_vignette "Vignette" 0.25 0.0 1.0 0.01
#pragma parameter deconv "Deconvergence" 0.0 0.0 1.0 1.0
#pragma parameter glass_refl "Glass Reflection" 0.15 0.0 0.5 0.01
#pragma parameter glass_refl_pos "Glass Reflection Pos." 0.5 0.0 1.0 0.01

#pragma parameter dymmy_col " [ COLORS ] " 0.0 0.0 0.0 0.0
#pragma parameter boost_dark "Boost Dark Pixels" 1.5 1.0 4.0 0.05
#pragma parameter boost_bright "Boost Bright Pixels" 1.2 1.0 4.0 0.05
#pragma parameter glow_str "Glow Strength" 0.15 0.0 1.0 0.01
#pragma parameter color_sat "Saturation" 1.0 0.0 2.0 0.05

#define beam_max params.beam_max
#define beam_min params.beam_min
#define scan_max params.scan_max
#define scan_min params.scan_min
#define CURVATURE_X params.CURVATURE_X
#define CURVATURE_Y params.CURVATURE_Y
#define CURVATURE_SCALE params.CURVATURE_SCALE
#define u_vignette params.u_vignette
#define MSK_BRI params.MSK_BRI
#define MSK_WIDTH params.MSK_WIDTH
#define MSK_HEIGHT params.MSK_HEIGHT
#define MSK_STAG params.MSK_STAG
#define mask_type params.mask_type
#define boost_bright params.boost_bright
#define boost_dark params.boost_dark
#define glow_str params.glow_str
#define color_sat params.color_sat
#define deconv params.deconv
#define glass_refl params.glass_refl
#define glass_refl_pos params.glass_refl_pos

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

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 invDims;
layout(location = 2) out vec2 maskpos;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord*1.0001;
   invDims = 1.0/SourceSize.xy;
   maskpos = (vTexCoord*OutputSize.xy)/vec2(MSK_WIDTH,MSK_HEIGHT);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 invDims;
layout(location = 2) in vec2 maskpos;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define grayweights vec3(0.3,0.6,0.1)

vec2 applyCurvature(vec2 uv)
{
    // Convert UV from 0–1 space to -1–1 space
    vec2 p = uv * 2.0 - 1.0;
    // Store original for later
    vec2 original = p;
    // Horizontal curvature
    p.x += (original.y * original.y) * original.x * CURVATURE_X;
    // Vertical curvature
    p.y += (original.x * original.x) * original.y * CURVATURE_Y;
    // Optional uniform curvature (tube warping)
    float r = dot(original, original);
    p *= 1.0 + r * CURVATURE_SCALE;
    
    // Return to 0–1 space
    return p * 0.5 + 0.5;
}

float kernel[5] = float[](
    0.0625,   // tap -2
    0.25,     // tap -1
    0.375,    // tap  0
    0.25,     // tap +1
    0.0625    // tap +2
);

vec3 glow(vec2 uv)
{
   vec3 final = vec3(0.0);

   for (int i=-2; i<3; i++)
   {
      float n = float(i);
      final += texture(Source,uv + vec2(invDims.x,0.0)*n).rgb*kernel[i+2];
   }
   for (int i=-2; i<3; i++)
   {
      float n = float(i);
      final += texture(Source,uv + vec2(0.0,invDims.y)*n).rgb*kernel[i+2];
   }
   return final*0.5;
}

vec3 mask(vec2 maskpos)
{
int m = int(mod(floor(maskpos.x) + mod(floor(maskpos.y),2.0)*MSK_STAG, mask_type == 1.0 ? 3.0 : 2.0));

vec3 mask_ = (m == 0.0)? vec3(MSK_BRI) : vec3(1.0);

 return mask_;
}

void main()
{
// curve screen   
   vec2 uv = applyCurvature(vTexCoord);

// calculate some x,y axis filtering   
   vec2 p = uv * SourceSize.xy;
   float scanpos = p.y;
   vec2 i = floor(p) + 0.50;

   float y = p.y - i.y;
   float x = fract(p.x);

   // blurrier X axis
   p.x = (i.x + x*x*(3.0-2.0*x))*invDims.x;
   // sharp Y axis, max sharp quillez modification
   p.y = (i.y + 16.0*y*y*y*y*y)*invDims.y;

   vec3 colour = texture(Source, p).rgb;

// hardcoded deconvergence
if (deconv == 1.0){   
colour.r = texture(Source, applyCurvature(vTexCoord + vec2(0.001,0))).r;
colour.b = texture(Source, applyCurvature(vTexCoord - vec2(0.001,0))).b;
}

// glass reflect
float glass = pow(1.0 - distance(uv, vec2(glass_refl_pos)), 6.0) * glass_refl/10.0;
colour += vec3(glass);

// grab max pixel R/G/B value
   float l = max(max(colour.r,colour.g),colour.b);

// calculate beam width based on the above
   float beam = mix(beam_min, beam_max, l);
   float scan = mix(scan_min, scan_max, l);

// add cheap glow effect  
   colour += glow(p)*glow_str;

// apply gaussian scanlines
   colour *= exp(-beam*y*y*scan);

// apply mask
   colour *= mix(mask(maskpos),vec3(boost_bright),l*0.5);

// boost dark palettes
   colour *= mix(vec3(boost_dark),vec3(1.0),l);

// gamma out
   colour = sqrt(colour);

// vignette
float dist = distance(uv, vec2(0.5));
float vig = 1.0 - u_vignette * dist;
colour *= vig;

// saturation
   vec3 gray = vec3(dot(vec3(grayweights),colour));
   colour = mix(gray,colour,color_sat);

   FragColor.rgb = colour;
}
