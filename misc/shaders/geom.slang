#version 450

layout(push_constant) uniform Push
{
   uint FrameCount;
   float targetgamma;
   float monitorgamma;
   float d;
   float R;
   float cornersize;
   float cornersmooth;
   float x_tilt;
   float y_tilt;
   float overscan_x;
   float overscan_y;
   float SHARPER;
   float CURVATURE;
   float interlace_detect;
   float lum;
   float invert_aspect;
   float xsize;
   float ysize;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 SourceSize;
} global;

#pragma parameter targetgamma "Geom Target Gamma" 2.4 0.1 5.0 0.1
#pragma parameter monitorgamma "Geom Monitor Gamma" 2.2 0.1 5.0 0.1
#pragma parameter d "Geom Distance" 1.5 0.1 3.0 0.1
#pragma parameter CURVATURE "Geom Curvature Toggle" 1.0 0.0 1.0 1.0
#pragma parameter invert_aspect "Geom Curvature Aspect Inversion" 0.0 0.0 1.0 1.0
#pragma parameter R "Geom Curvature Radius" 2.0 0.1 10.0 0.1
#pragma parameter cornersize "Geom Corner Size" 0.03 0.001 1.0 0.005
#pragma parameter cornersmooth "Geom Corner Smoothness" 1000.0 80.0 2000.0 100.0
#pragma parameter x_tilt "Geom Horizontal Tilt" 0.0 -0.5 0.5 0.05
#pragma parameter y_tilt "Geom Vertical Tilt" 0.0 -0.5 0.5 0.05
#pragma parameter overscan_x "Geom Horiz. Overscan %" 100.0 -125.0 125.0 0.5
#pragma parameter overscan_y "Geom Vert. Overscan %" 100.0 -125.0 125.0 0.5
#pragma parameter SHARPER "Geom Sharpness" 1.0 1.0 3.0 1.0
#pragma parameter lum "Geom Luminance" 1.0 0.5 2.0 0.01
#pragma parameter interlace_detect "Geom Interlacing Simulation" 1.0 0.0 1.0 1.0

#pragma parameter xsize "Simulated Width (0==Auto)" 0.0 0.0 1920.0 16.0
#pragma parameter ysize "Simulated Height (0==Auto)" 0.0 0.0 1080.0 16.0

vec2 height = (registers.ysize > 0.001) ? vec2(registers.ysize, 1./registers.ysize) : global.SourceSize.yw;
vec2 width = (registers.xsize > 0.001) ? vec2(registers.xsize, 1./registers.xsize) : global.SourceSize.xz;
vec4 SourceSize = vec4(width.x, height.x, width.y, height.y);

/*
    Geom Shader - a modified CRT-Geom without CRT features made to be appended/integrated
    into any other shaders and provide curvature/warping/oversampling features.

    Adaptation by Hyllian (2024).
*/

/*
    CRT-interlaced

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

// Comment the next line to disable interpolation in linear gamma (and
// gain speed).
#define LINEAR_PROCESSING

// Enable 3x oversampling of the beam profile; improves moire effect caused by scanlines+curvature
#define OVERSAMPLE

// Use the older, purely gaussian beam profile; uncomment for speed
//#define USEGAUSSIAN

// Macros.
#define FIX(c) max(abs(c), 1e-5);
#define PI 3.141592653589

#ifdef LINEAR_PROCESSING
#       define TEX2D(c) pow(texture(Source, (c)), vec4(registers.targetgamma))
#else
#       define TEX2D(c) texture(Source, (c))
#endif

// aspect ratio
vec2 aspect     = vec2(registers.invert_aspect > 0.5 ? (0.75, 1.0) : (1.0, 0.75));
vec2 overscan   = vec2(1.01, 1.01);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 sinangle;
layout(location = 2) out vec2 cosangle;
layout(location = 3) out vec3 stretch;
layout(location = 4) out vec2 ilfac;
layout(location = 5) out vec2 TextureSize;

float intersect(vec2 xy)
{
    float A = dot(xy,xy) + registers.d*registers.d;
    float B = 2.0*(registers.R*(dot(xy,sinangle)-registers.d*cosangle.x*cosangle.y)-registers.d*registers.d);
    float C = registers.d*registers.d + 2.0*registers.R*registers.d*cosangle.x*cosangle.y;
    
    return (-B-sqrt(B*B-4.0*A*C))/(2.0*A);
}

vec2 bkwtrans(vec2 xy)
{
    float c     = intersect(xy);
    vec2 point  = (vec2(c, c)*xy - vec2(-registers.R, -registers.R)*sinangle) / vec2(registers.R, registers.R);
    vec2 poc    = point/cosangle;
    
    vec2 tang   = sinangle/cosangle;
    float A     = dot(tang, tang) + 1.0;
    float B     = -2.0*dot(poc, tang);
    float C     = dot(poc, poc) - 1.0;
    
    float a     = (-B + sqrt(B*B - 4.0*A*C))/(2.0*A);
    vec2 uv     = (point - a*sinangle)/cosangle;
    float r     = FIX(registers.R*acos(a));
    
    return uv*r/sin(r/registers.R);
}

vec2 fwtrans(vec2 uv)
{
    float r = FIX(sqrt(dot(uv,uv)));
    uv *= sin(r/registers.R)/r;
    float x = 1.0-cos(r/registers.R);
    float D = registers.d/registers.R + x*cosangle.x*cosangle.y+dot(uv,sinangle);
    
    return registers.d*(uv*cosangle-x*sinangle)/D;
}

vec3 maxscale()
{
    vec2 c  = bkwtrans(-registers.R * sinangle / (1.0 + registers.R/registers.d*cosangle.x*cosangle.y));
    vec2 a  = vec2(0.5,0.5)*aspect;
    
    vec2 lo = vec2(fwtrans(vec2(-a.x,  c.y)).x,
                   fwtrans(vec2( c.x, -a.y)).y)/aspect;

    vec2 hi = vec2(fwtrans(vec2(+a.x,  c.y)).x,
                   fwtrans(vec2( c.x, +a.y)).y)/aspect;
    
    return vec3((hi+lo)*aspect*0.5,max(hi.x-lo.x,hi.y-lo.y));
}



void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord * vec2(1.00001);

    // Precalculate a bunch of useful values we'll need in the fragment
    // shader.
    sinangle    = sin(vec2(registers.x_tilt, registers.y_tilt));
    cosangle    = cos(vec2(registers.x_tilt, registers.y_tilt));
    stretch     = maxscale();
    
    TextureSize = vec2(registers.SHARPER * SourceSize.x, SourceSize.y);
       
    ilfac = vec2(1.0, clamp(floor(SourceSize.y/(registers.interlace_detect > 0.5 ? 200.0 : 1000)),  1.0, 2.0));
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 sinangle;
layout(location = 2) in vec2 cosangle;
layout(location = 3) in vec3 stretch;
layout(location = 4) in vec2 ilfac;
layout(location = 5) in vec2 TextureSize;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float intersect(vec2 xy)
{
    float A = dot(xy,xy) + registers.d*registers.d;
    float B, C;

       B = 2.0*(registers.R*(dot(xy,sinangle) - registers.d*cosangle.x*cosangle.y) - registers.d*registers.d);
       C = registers.d*registers.d + 2.0*registers.R*registers.d*cosangle.x*cosangle.y;

    return (-B-sqrt(B*B - 4.0*A*C))/(2.0*A);
}

vec2 bkwtrans(vec2 xy)
{
    float c     = intersect(xy);
    vec2 point  = (vec2(c, c)*xy - vec2(-registers.R, -registers.R)*sinangle) / vec2(registers.R, registers.R);
    vec2 poc    = point/cosangle;
    vec2 tang   = sinangle/cosangle;

    float A     = dot(tang, tang) + 1.0;
    float B     = -2.0*dot(poc, tang);
    float C     = dot(poc, poc) - 1.0;

    float a     = (-B + sqrt(B*B - 4.0*A*C)) / (2.0*A);
    vec2 uv     = (point - a*sinangle) / cosangle;
    float r     = FIX(registers.R*acos(a));
    
    return uv*r/sin(r/registers.R);
}

vec2 fwtrans(vec2 uv)
{
    float r = FIX(sqrt(dot(uv, uv)));
    uv *= sin(r/registers.R)/r;
    float x = 1.0 - cos(r/registers.R);
    float D;
    
      D = registers.d/registers.R + x*cosangle.x*cosangle.y + dot(uv,sinangle);

    return registers.d*(uv*cosangle - x*sinangle)/D;
}

vec3 maxscale()
{
       vec2 c = bkwtrans(-registers.R * sinangle / (1.0 + registers.R/registers.d*cosangle.x*cosangle.y));
       vec2 a = vec2(0.5, 0.5)*aspect;

       vec2 lo = vec2(fwtrans(vec2(-a.x,  c.y)).x,
                      fwtrans(vec2( c.x, -a.y)).y)/aspect;
       vec2 hi = vec2(fwtrans(vec2(+a.x,  c.y)).x,
                      fwtrans(vec2( c.x, +a.y)).y)/aspect;

       return vec3((hi+lo)*aspect*0.5,max(hi.x-lo.x, hi.y-lo.y));
}


vec2 transform(vec2 coord)
{
    coord = (coord - vec2(0.5, 0.5))*aspect*stretch.z + stretch.xy;
    
    return (bkwtrans(coord) /
        vec2(registers.overscan_x / 100.0, registers.overscan_y / 100.0)/aspect + vec2(0.5, 0.5));
}

float corner(vec2 coord)
{
    coord = (coord - vec2(0.5)) * vec2(registers.overscan_x / 100.0, registers.overscan_y / 100.0) + vec2(0.5, 0.5);
    coord = min(coord, vec2(1.0) - coord) * aspect;
    vec2 cdist = vec2(registers.cornersize);
    coord = (cdist - min(coord, cdist));
    float dist = sqrt(dot(coord, coord));
    
      return clamp((cdist.x - dist)*registers.cornersmooth, 0.0, 1.0);
}

void main()
{
    // Texture coordinates of the texel containing the active pixel.
    vec2 xy;

    if (registers.CURVATURE > 0.5)
        xy = transform(vTexCoord);
    else
        xy = vTexCoord;

    float cval = corner(xy);

    // Of all the pixels that are mapped onto the texel we are
    // currently rendering, which pixel are we currently rendering?
    vec2 ilvec;
    ilvec = vec2(0.0, ilfac.y * registers.interlace_detect > 1.5 ? mod(float(registers.FrameCount), 2.0) : 0.0);

    vec2 ratio_scale = (xy * TextureSize - vec2(0.5, 0.5) + ilvec) / ilfac;
    vec2 uv_ratio = fract(ratio_scale);

    // Snap to the center of the underlying texel.
    xy = (floor(ratio_scale)*ilfac + vec2(0.5, 0.5) - ilvec) / TextureSize;

    vec4 col = TEX2D(xy);


#ifndef LINEAR_PROCESSING
    col  = pow(col , vec4(registers.targetgamma));
#endif

    col.rgb *= (registers.lum * step(0.0, uv_ratio.y));

    vec3 mul_res  =  col.rgb * vec3(cval);

    // Convert the image gamma for display on our output device.
    mul_res = pow(mul_res, vec3(1.0 / registers.monitorgamma));

    FragColor = vec4(mul_res, 1.0);
}
