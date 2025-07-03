#version 450

layout(push_constant) uniform Push
{
    float hardScan;
    float hardPix;
    float warpX;
    float warpY;
    float maskDark;
    float maskLight;
    float scaleInLinearGamma;
    float shadowMask;
    float brightBoost;
    float hardBloomScan;
    float hardBloomPix;
    float bloomAmount;
    float shape;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
    float geom_d;
    float geom_R;
    float geom_cornersize;
    float geom_cornersmooth;
    float geom_x_tilt;
    float geom_y_tilt;
    float geom_overscan_x;
    float geom_overscan_y;
    float geom_center_x;
    float geom_center_y;
    float geom_inner_center_x;
    float geom_inner_center_y;
    float geom_curvature;
    float geom_invert_aspect;
    float box_scale;
    float in_res_x;
    float in_res_y;
    float ub_rotate;
} global;

#include "include/uborder_params.inc"


#pragma parameter lottes_nonono       "CRT-LOTTES:"                           0.0  0.0 1.0 1.0
#pragma parameter hardScan "hardScan" -8.0 -20.0 0.0 1.0
#pragma parameter hardPix "hardPix" -3.0 -20.0 0.0 1.0
#pragma parameter warpX "warpX" 0.0 0.0 0.125 0.01
#pragma parameter warpY "warpY" 0.0 0.0 0.125 0.01
#pragma parameter maskDark "maskDark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "maskLight" 1.5 0.0 2.0 0.1
#pragma parameter scaleInLinearGamma "scaleInLinearGamma" 1.0 0.0 1.0 1.0
#pragma parameter shadowMask "shadowMask" 3.0 0.0 4.0 1.0
#pragma parameter brightBoost "brightness boost" 1.0 0.0 2.0 0.05
#pragma parameter hardBloomPix "bloom-x soft" -1.5 -2.0 -0.5 0.1
#pragma parameter hardBloomScan "bloom-y soft" -2.0 -4.0 -1.0 0.1
#pragma parameter bloomAmount "bloom ammount" 0.15 0.0 1.0 0.05
#pragma parameter shape "filter kernel shape" 2.0 0.0 10.0 0.05

#define FIX(c) max(abs(c), 1e-5)
#define PI 3.141592653589

// aspect ratio
vec2 aspect     = vec2(global.geom_invert_aspect > 0.5 ? (0.75, 1.0) : (1.0, 0.75));
vec2 overscan   = vec2(1.01, 1.01);

vec2 ScaledOutputSize = vec2(global.in_res_x, global.in_res_y) * global.box_scale;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 sinangle;
layout(location = 2) out vec2 cosangle;
layout(location = 3) out vec3 stretch;
layout(location = 4) out float R_d_cx_cy;
layout(location = 5) out float d2;

/*
    Geom code - a modified Geom code without CRT features made to provide
    curvature/warping/oversampling features.

    Adapted by Hyllian (2024).
*/

/*
    Copyright (C) 2010-2012 cgwg, Themaister and DOLLS

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

    (cgwg gave their consent to have the original version of this shader
    distributed under the GPL in this message:

    http://board.byuu.org/viewtopic.php?p=26075#p26075

    "Feel free to distribute my shaders under the GPL. After all, the
    barrel distortion code was taken from the Curvature shader, which is
    under the GPL."
    )
    This shader variant is pre-configured with screen curvature
*/


float intersect(vec2 xy)
{
    float A = dot(xy,xy) + global.geom_d*global.geom_d;
    float B = 2.0 * (global.geom_R * (dot(xy,sinangle) - global.geom_d * cosangle.x * cosangle.y) - global.geom_d * global.geom_d);
    float C = global.geom_d*global.geom_d + 2.0*global.geom_R*global.geom_d*cosangle.x*cosangle.y;
    
    return (-B-sqrt(B*B-4.0*A*C))/(2.0*A);
}

vec2 bkwtrans(vec2 xy)
{
    float c     = intersect(xy);
    vec2 point  = (vec2(c, c)*xy - vec2(-global.geom_R, -global.geom_R)*sinangle) / vec2(global.geom_R, global.geom_R);
    vec2 poc    = point/cosangle;
    
    vec2 tang   = sinangle/cosangle;
    float A     = dot(tang, tang) + 1.0;
    float B     = -2.0*dot(poc, tang);
    float C     = dot(poc, poc) - 1.0;
    
    float a     = (-B + sqrt(B*B - 4.0*A*C))/(2.0*A);
    vec2 uv     = (point - a*sinangle)/cosangle;
    float r     = FIX(global.geom_R*acos(a));
    
    return uv*r/sin(r/global.geom_R);
}

vec2 fwtrans(vec2 uv)
{
    float r = FIX(sqrt(dot(uv,uv)));
    uv *= sin(r/global.geom_R)/r;
    float x = 1.0-cos(r/global.geom_R);
    float D = global.geom_d/global.geom_R + x*cosangle.x*cosangle.y+dot(uv,sinangle);
    
    return global.geom_d*(uv*cosangle-x*sinangle)/D;
}

vec3 maxscale()
{
    vec2 c  = bkwtrans( -global.geom_R * sinangle / (1.0 + global.geom_R / global.geom_d * cosangle.x * cosangle.y) );
    vec2 a  = vec2(0.5,0.5) * aspect;
    
    vec2 lo = vec2(fwtrans(vec2(-a.x,  c.y)).x,
                   fwtrans(vec2( c.x, -a.y)).y)/aspect;

    vec2 hi = vec2(fwtrans(vec2(+a.x,  c.y)).x,
                   fwtrans(vec2( c.x, +a.y)).y)/aspect;
    
    return vec3( (hi + lo) * aspect * 0.5, max(hi.x - lo.x, hi.y - lo.y) );
}

void main()
{
   gl_Position = global.MVP * Position;
//   vTexCoord = TexCoord;

    vTexCoord = mix(TexCoord.xy, vec2(1.0-TexCoord.y, TexCoord.x), global.ub_rotate);
//   vTexCoord = mix(TexCoord.xy, vec2(1.0-TexCoord.y, TexCoord.x), float(global.Rotation==1.0)); // Doesn't work in this pass...

   vec2 corrected_size = vec2(global.in_res_x, global.in_res_y) * global.box_scale;
   vec2 scale  = vec2(1920.0, 1080.0) / corrected_size;
   vec2 middle = vec2(global.geom_center_x, global.geom_center_y) + vec2(0.5, 0.5);
   vec2 diff   = vTexCoord - middle;
   vTexCoord   = middle + diff * scale;

    // Precalculate a bunch of useful values we'll need in the fragment
    // shader.
    sinangle    = sin(vec2(global.geom_x_tilt, global.geom_y_tilt));
    cosangle    = cos(vec2(global.geom_x_tilt, global.geom_y_tilt));
    stretch     = maxscale();

    d2        = global.geom_d * global.geom_d;
    R_d_cx_cy = global.geom_R * global.geom_d * cosangle.x * cosangle.y;
}

// PUBLIC DOMAIN CRT STYLED SCAN-LINE SHADER
//
//   by Timothy Lottes
//
// This is more along the style of a really good CGA arcade monitor.
// With RGB inputs instead of NTSC.
// The shadow mask example has the mask rotated 90 degrees for less chromatic aberration.
//
// Left it unoptimized to show the theory behind the algorithm.
//
// It is an example what I personally would want as a display option for pixel art games.
// Please take and use, change, or whatever.

#pragma stage fragment
layout(location = 0) in  vec2 vTexCoord;
layout(location = 1) in vec2 sinangle;
layout(location = 2) in vec2 cosangle;
layout(location = 3) in vec3 stretch;
layout(location = 4) in float R_d_cx_cy;
layout(location = 5) in float d2;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

//Uncomment to reduce instructions with simpler linearization
//(fixes HD3000 Sandy Bridge IGP)
//#define SIMPLE_LINEAR_GAMMA
#define DO_BLOOM 1

// ------------- //

// sRGB to Linear.
// Assuming using sRGB typed textures this should not be needed.
#ifdef SIMPLE_LINEAR_GAMMA
float ToLinear1(float c)
{
    return c;
}
vec3 ToLinear(vec3 c)
{
    return c;
}
vec3 ToSrgb(vec3 c)
{
    return pow(c, vec3(1.0 / 2.2));
}
#else
float ToLinear1(float c)
{
    if (params.scaleInLinearGamma == 0) 
        return c;
    
    return(c<=0.04045) ? c/12.92 : pow((c + 0.055)/1.055, 2.4);
}

vec3 ToLinear(vec3 c)
{
    if (params.scaleInLinearGamma==0) 
        return c;
    
    return vec3(ToLinear1(c.r), ToLinear1(c.g), ToLinear1(c.b));
}

// Linear to sRGB.
// Assuming using sRGB typed textures this should not be needed.
float ToSrgb1(float c)
{
    if (params.scaleInLinearGamma == 0) 
        return c;
    
    return(c<0.0031308 ? c*12.92 : 1.055*pow(c, 0.41666) - 0.055);
}

vec3 ToSrgb(vec3 c)
{
    if (params.scaleInLinearGamma == 0) 
        return c;
    
    return vec3(ToSrgb1(c.r), ToSrgb1(c.g), ToSrgb1(c.b));
}
#endif



// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.
vec3 Fetch(vec2 pos,vec2 off){
  pos=(floor(pos*global.SourceSize.xy+off)+vec2(0.5,0.5))/global.SourceSize.xy;
#ifdef SIMPLE_LINEAR_GAMMA
  return ToLinear(params.brightBoost * pow(texture(Source,pos.xy).rgb, vec3(2.2)));
#else
  return ToLinear(params.brightBoost * texture(Source,pos.xy).rgb);
#endif
}
  
// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos)
{
    pos = pos*global.SourceSize.xy;
    
    return -((pos - floor(pos)) - vec2(0.5));
}
    
// 1D Gaussian.
float Gaus(float pos, float scale)
{
    return exp2(scale*pow(abs(pos), params.shape));
}

// 3-tap Gaussian filter along horz line.
vec3 Horz3(vec2 pos, float off)
{
    vec3 b    = Fetch(pos, vec2(-1.0, off));
    vec3 c    = Fetch(pos, vec2( 0.0, off));
    vec3 d    = Fetch(pos, vec2( 1.0, off));
    float dst = Dist(pos).x;

    // Convert distance to weight.
    float scale = params.hardPix;
    float wb = Gaus(dst-1.0,scale);
    float wc = Gaus(dst+0.0,scale);
    float wd = Gaus(dst+1.0,scale);

    // Return filtered sample.
    return (b*wb+c*wc+d*wd)/(wb+wc+wd);
}

// 5-tap Gaussian filter along horz line.
vec3 Horz5(vec2 pos,float off){
    vec3 a = Fetch(pos,vec2(-2.0, off));
    vec3 b = Fetch(pos,vec2(-1.0, off));
    vec3 c = Fetch(pos,vec2( 0.0, off));
    vec3 d = Fetch(pos,vec2( 1.0, off));
    vec3 e = Fetch(pos,vec2( 2.0, off));
    
    float dst = Dist(pos).x;
    // Convert distance to weight.
    float scale = params.hardPix;
    float wa = Gaus(dst - 2.0, scale);
    float wb = Gaus(dst - 1.0, scale);
    float wc = Gaus(dst + 0.0, scale);
    float wd = Gaus(dst + 1.0, scale);
    float we = Gaus(dst + 2.0, scale);
    
    // Return filtered sample.
    return (a*wa+b*wb+c*wc+d*wd+e*we)/(wa+wb+wc+wd+we);
}
  
// 7-tap Gaussian filter along horz line.
vec3 Horz7(vec2 pos,float off)
{
    vec3 a = Fetch(pos, vec2(-3.0, off));
    vec3 b = Fetch(pos, vec2(-2.0, off));
    vec3 c = Fetch(pos, vec2(-1.0, off));
    vec3 d = Fetch(pos, vec2( 0.0, off));
    vec3 e = Fetch(pos, vec2( 1.0, off));
    vec3 f = Fetch(pos, vec2( 2.0, off));
    vec3 g = Fetch(pos, vec2( 3.0, off));

    float dst = Dist(pos).x;
    // Convert distance to weight.
    float scale = params.hardBloomPix;
    float wa = Gaus(dst - 3.0, scale);
    float wb = Gaus(dst - 2.0, scale);
    float wc = Gaus(dst - 1.0, scale);
    float wd = Gaus(dst + 0.0, scale);
    float we = Gaus(dst + 1.0, scale);
    float wf = Gaus(dst + 2.0, scale);
    float wg = Gaus(dst + 3.0, scale);

    // Return filtered sample.
    return (a*wa+b*wb+c*wc+d*wd+e*we+f*wf+g*wg)/(wa+wb+wc+wd+we+wf+wg);
}
  
// Return scanline weight.
float Scan(vec2 pos, float off)
{
    float dst = Dist(pos).y;

    return Gaus(dst + off, params.hardScan);
}
  
// Return scanline weight for bloom.
float BloomScan(vec2 pos, float off)
{
    float dst = Dist(pos).y;
    
    return Gaus(dst + off, params.hardBloomScan);
}

// Allow nearest three lines to effect pixel.
vec3 Tri(vec2 pos)
{
    vec3 a = Horz3(pos,-1.0);
    vec3 b = Horz5(pos, 0.0);
    vec3 c = Horz3(pos, 1.0);
    
    float wa = Scan(pos,-1.0); 
    float wb = Scan(pos, 0.0);
    float wc = Scan(pos, 1.0);
    
    return a*wa + b*wb + c*wc;
}
  
// Small bloom.
vec3 Bloom(vec2 pos)
{
    vec3 a = Horz5(pos,-2.0);
    vec3 b = Horz7(pos,-1.0);
    vec3 c = Horz7(pos, 0.0);
    vec3 d = Horz7(pos, 1.0);
    vec3 e = Horz5(pos, 2.0);

    float wa = BloomScan(pos,-2.0);
    float wb = BloomScan(pos,-1.0); 
    float wc = BloomScan(pos, 0.0);
    float wd = BloomScan(pos, 1.0);
    float we = BloomScan(pos, 2.0);

    return a*wa+b*wb+c*wc+d*wd+e*we;
}
  
// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*params.warpX, 1.0 + (pos.x*pos.x)*params.warpY);
    
    return pos*0.5 + 0.5;
}
  
// Shadow mask.
vec3 Mask(vec2 pos)
{
    vec3 mask = vec3(params.maskDark, params.maskDark, params.maskDark);
  
    // Very compressed TV style shadow mask.
    if (params.shadowMask == 1.0) 
    {
        float line = params.maskLight;
        float odd = 0.0;
        
        if (fract(pos.x*0.166666666) < 0.5) odd = 1.0;
        if (fract((pos.y + odd) * 0.5) < 0.5) line = params.maskDark;  
        
        pos.x = fract(pos.x*0.333333333);

        if      (pos.x < 0.333) mask.r = params.maskLight;
        else if (pos.x < 0.666) mask.g = params.maskLight;
        else                    mask.b = params.maskLight;
        mask*=line;  
    } 

    // Aperture-grille.
    else if (params.shadowMask == 2.0) 
    {
        pos.x = fract(pos.x*0.333333333);

        if      (pos.x < 0.333) mask.r = params.maskLight;
        else if (pos.x < 0.666) mask.g = params.maskLight;
        else                    mask.b = params.maskLight;
    } 

    // Stretched VGA style shadow mask (same as prior shaders).
    else if (params.shadowMask == 3.0) 
    {
        pos.x += pos.y*3.0;
        pos.x  = fract(pos.x*0.166666666);

        if      (pos.x < 0.333) mask.r = params.maskLight;
        else if (pos.x < 0.666) mask.g = params.maskLight;
        else                    mask.b = params.maskLight;
    }

    // VGA style shadow mask.
    else if (params.shadowMask == 4.0) 
    {
        pos.xy  = floor(pos.xy*vec2(1.0, 0.5));
        pos.x  += pos.y*3.0;
        pos.x   = fract(pos.x*0.166666666);

        if      (pos.x < 0.333) mask.r = params.maskLight;
        else if (pos.x < 0.666) mask.g = params.maskLight;
        else                    mask.b = params.maskLight;
    }

    return mask;
}

vec2 transform(vec2 coord)
{
    coord = (coord - vec2(0.5, 0.5) - vec2(global.geom_inner_center_x, global.geom_inner_center_y)) * aspect * stretch.z + stretch.xy;
  //  coord = (coord - vec2(0.5, 0.5)) * aspect * stretch.z + stretch.xy;

    float A = dot(coord, coord) + d2;
    float B = 2.0 * ( global.geom_R * dot(coord, sinangle) - R_d_cx_cy - d2);
    float C = d2 + 2.0 * R_d_cx_cy;
    
    float c     = (-B - sqrt(B*B - 4.0*A*C)) / (2.0*A);

    vec2 point  = (vec2(c, c) * coord - vec2(-global.geom_R, -global.geom_R) * sinangle) / vec2(global.geom_R, global.geom_R);
    vec2 poc    = point / cosangle;
    
    vec2 tang   = sinangle / cosangle;
    A     = dot(tang, tang) + 1.0;
    B     = -2.0 * dot(poc, tang);
    C     = dot(poc, poc) - 1.0;
    
    float a     = (-B + sqrt(B*B - 4.0*A*C))/(2.0*A);
    vec2 uv     = (point - a*sinangle)/cosangle;
    float r     = FIX(global.geom_R*acos(a));
    
    vec2 bkw = uv*r/sin(r/global.geom_R);

    return (bkw / vec2(global.geom_overscan_x / 100.0, global.geom_overscan_y / 100.0)/aspect + vec2(0.5, 0.5));
}

float corner(vec2 coord)
{
    coord = (coord - vec2(0.5, 0.5) + vec2(global.geom_inner_center_x, global.geom_inner_center_y)) * vec2(global.geom_overscan_x / 100.0, global.geom_overscan_y / 100.0) + vec2(0.5, 0.5);

   // coord = (coord - vec2(0.5, 0.5)) * vec2(global.geom_overscan_x / 100.0, global.geom_overscan_y / 100.0) + vec2(0.5, 0.5);

    coord = min(coord, vec2(1.0) - coord) * aspect;
    vec2 cdist = vec2(global.geom_cornersize);
    coord = (cdist - min(coord, cdist));
    float dist = sqrt(dot(coord, coord));
    
      return clamp((cdist.x - dist)*global.geom_cornersmooth, 0.0, 1.0);
}


void main()
{
    float draw = step(max(vTexCoord.x, vTexCoord.y), 1.0) * step(0.0, min(vTexCoord.x, vTexCoord.y));

    if (draw < 0.5) discard;

    vec2  uv   = vTexCoord;
    float cval = 1.0;

    if (global.geom_curvature > 0.5)
    {
        uv  = transform(uv);
    }
    else
    {
        uv -= vec2(global.geom_inner_center_x, global.geom_inner_center_y);
    }

    cval = corner(uv)  *  step(0.0, fract(uv.y));  // Discard off limit pixels


//    vec2 pos = Warp(vTexCoord);
    vec2 pos = Warp(uv);
    vec3 outColor = Tri(pos);

#ifdef DO_BLOOM
    //Add Bloom
    outColor.rgb += Bloom(pos)*params.bloomAmount;
#endif

    if (params.shadowMask > 0.0)
//        outColor.rgb *= Mask(vTexCoord.xy / global.OutputSize.zw * 1.000001);
        outColor.rgb *= Mask(vTexCoord.xy * ScaledOutputSize * 1.000001);
    
#ifdef GL_ES    /* TODO/FIXME - hacky clamp fix */
    vec2 bordertest = (pos);
    if ( bordertest.x > 0.0001 && bordertest.x < 0.9999 && bordertest.y > 0.0001 && bordertest.y < 0.9999)
        outColor.rgb = outColor.rgb;
    else
        outColor.rgb = vec3(0.0);
#endif
    FragColor = vec4(ToSrgb(outColor.rgb) * vec3(cval), cval);
}
