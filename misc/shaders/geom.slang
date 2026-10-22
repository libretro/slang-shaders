#version 450

layout(push_constant) uniform Push
{
   uint FrameCount;
   float geom_target_gamma;
   float geom_monitor_gamma;
   float geom_d;
   float geom_R;
   float geom_cornersize;
   float geom_cornersmooth;
   float geom_x_tilt;
   float geom_y_tilt;
   float geom_overscan_x;
   float geom_overscan_y;
   float geom_sharper;
   float geom_lod_bias;
   float geom_curvature;
   float geom_lum;
   float geom_invert_aspect;
} reg;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 SourceSize;
} global;

#pragma parameter geom_params "[ GEOM USER PARAMETERS ]" 0.0 0.0 1.0 1.0
#pragma parameter geom_curvature "Geom Curvature Toggle" 1.0 0.0 1.0 1.0
#pragma parameter geom_R "Geom Curvature Radius" 2.0 0.1 10.0 0.1
#pragma parameter geom_d "Geom Distance" 1.5 0.1 3.0 0.1
#pragma parameter geom_invert_aspect "Geom Curvature Aspect Inversion" 0.0 0.0 1.0 1.0
#pragma parameter geom_cornersize "Geom Corner Size" 0.03 0.001 1.0 0.005
#pragma parameter geom_cornersmooth "Geom Corner Smoothness" 1000.0 80.0 2000.0 100.0
#pragma parameter geom_x_tilt "Geom Horizontal Tilt" 0.0 -0.5 0.5 0.05
#pragma parameter geom_y_tilt "Geom Vertical Tilt" 0.0 -0.5 0.5 0.05
#pragma parameter geom_overscan_x "Geom Horiz. Overscan %" 100.0 -125.0 125.0 0.5
#pragma parameter geom_overscan_y "Geom Vert. Overscan %" 100.0 -125.0 125.0 0.5
#pragma parameter geom_sharper "Geom Sharpness" 1.0 1.0 3.0 1.0
#pragma parameter geom_lod_bias "Geom LOD Bias" 0.0 0.0 1.0 0.05
#pragma parameter geom_lum "Geom Luminance" 1.0 0.5 2.0 0.01
#pragma parameter geom_target_gamma "Geom Target Gamma" 2.4 0.1 5.0 0.1
#pragma parameter geom_monitor_gamma "Geom Monitor Gamma" 2.2 0.1 5.0 0.1


/*
    Geom Shader - a modified CRT-Geom without CRT features made to be appended/integrated
    into any other shaders and provide curvature/warping/oversampling features.

    Adapted by Hyllian (2024).
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

// Geometry filtering integrates the transformed pixel footprint to reduce moire.
#define OVERSAMPLE

// Use the older, purely gaussian beam profile; uncomment for speed
//#define USEGAUSSIAN

// Macros.
#define FIX(c) max(abs(c), 1e-5);
#define PI 3.141592653589

#ifdef LINEAR_PROCESSING
#       define TEX2D(c) trilinear(Source, (c), TextureSize)
#else
#       define TEX2D(c) texture(Source, (c))
#endif

// aspect ratio
vec2 aspect     = vec2(reg.geom_invert_aspect > 0.5 ? (0.75, 1.0) : (1.0, 0.75));
vec2 overscan   = vec2(1.01, 1.01);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 sinangle;
layout(location = 2) out vec2 cosangle;
layout(location = 3) out vec3 stretch;
layout(location = 4) out vec2 TextureSize;

float intersect(vec2 xy)
{
    float A = dot(xy,xy) + reg.geom_d*reg.geom_d;
    float B = 2.0*(reg.geom_R*(dot(xy,sinangle)-reg.geom_d*cosangle.x*cosangle.y)-reg.geom_d*reg.geom_d);
    float C = reg.geom_d*reg.geom_d + 2.0*reg.geom_R*reg.geom_d*cosangle.x*cosangle.y;
    
    return (-B-sqrt(B*B-4.0*A*C))/(2.0*A);
}

vec2 bkwtrans(vec2 xy)
{
    float c     = intersect(xy);
    vec2 point  = (vec2(c, c)*xy - vec2(-reg.geom_R, -reg.geom_R)*sinangle) / vec2(reg.geom_R, reg.geom_R);
    vec2 poc    = point/cosangle;
    
    vec2 tang   = sinangle/cosangle;
    float A     = dot(tang, tang) + 1.0;
    float B     = -2.0*dot(poc, tang);
    float C     = dot(poc, poc) - 1.0;
    
    float a     = (-B + sqrt(B*B - 4.0*A*C))/(2.0*A);
    vec2 uv     = (point - a*sinangle)/cosangle;
    float r     = FIX(reg.geom_R*acos(a));
    
    return uv*r/sin(r/reg.geom_R);
}

vec2 fwtrans(vec2 uv)
{
    float r = FIX(sqrt(dot(uv,uv)));
    uv *= sin(r/reg.geom_R)/r;
    float x = 1.0-cos(r/reg.geom_R);
    float D = reg.geom_d/reg.geom_R + x*cosangle.x*cosangle.y+dot(uv,sinangle);
    
    return reg.geom_d*(uv*cosangle-x*sinangle)/D;
}

vec3 maxscale()
{
    vec2 c  = bkwtrans(-reg.geom_R * sinangle / (1.0 + reg.geom_R/reg.geom_d*cosangle.x*cosangle.y));
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
    sinangle    = sin(vec2(reg.geom_x_tilt, reg.geom_y_tilt));
    cosangle    = cos(vec2(reg.geom_x_tilt, reg.geom_y_tilt));
    stretch     = maxscale();
    
    TextureSize = global.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 sinangle;
layout(location = 2) in vec2 cosangle;
layout(location = 3) in vec3 stretch;
layout(location = 4) in vec2 TextureSize;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float intersect(vec2 xy)
{
    float A = dot(xy,xy) + reg.geom_d*reg.geom_d;
    float B, C;

       B = 2.0*(reg.geom_R*(dot(xy,sinangle) - reg.geom_d*cosangle.x*cosangle.y) - reg.geom_d*reg.geom_d);
       C = reg.geom_d*reg.geom_d + 2.0*reg.geom_R*reg.geom_d*cosangle.x*cosangle.y;

    return (-B-sqrt(B*B - 4.0*A*C))/(2.0*A);
}

vec2 bkwtrans(vec2 xy)
{
    float c     = intersect(xy);
    vec2 point  = (vec2(c, c)*xy - vec2(-reg.geom_R, -reg.geom_R)*sinangle) / vec2(reg.geom_R, reg.geom_R);
    vec2 poc    = point/cosangle;
    vec2 tang   = sinangle/cosangle;

    float A     = dot(tang, tang) + 1.0;
    float B     = -2.0*dot(poc, tang);
    float C     = dot(poc, poc) - 1.0;

    float a     = (-B + sqrt(B*B - 4.0*A*C)) / (2.0*A);
    vec2 uv     = (point - a*sinangle) / cosangle;
    float r     = FIX(reg.geom_R*acos(a));
    
    return uv*r/sin(r/reg.geom_R);
}

vec2 fwtrans(vec2 uv)
{
    float r = FIX(sqrt(dot(uv, uv)));
    uv *= sin(r/reg.geom_R)/r;
    float x = 1.0 - cos(r/reg.geom_R);
    float D;
    
      D = reg.geom_d/reg.geom_R + x*cosangle.x*cosangle.y + dot(uv,sinangle);

    return reg.geom_d*(uv*cosangle - x*sinangle)/D;
}

vec3 maxscale()
{
       vec2 c = bkwtrans(-reg.geom_R * sinangle / (1.0 + reg.geom_R/reg.geom_d*cosangle.x*cosangle.y));
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
        vec2(reg.geom_overscan_x / 100.0, reg.geom_overscan_y / 100.0)/aspect + vec2(0.5, 0.5));
}

float corner(vec2 coord)
{
    coord = (coord - vec2(0.5)) * vec2(reg.geom_overscan_x / 100.0, reg.geom_overscan_y / 100.0) + vec2(0.5, 0.5);
    coord = min(coord, vec2(1.0) - coord) * aspect;
    vec2 cdist = vec2(reg.geom_cornersize);
    coord = (cdist - min(coord, cdist));
    float dist = sqrt(dot(coord, coord));
    
      return clamp((cdist.x - dist)*reg.geom_cornersmooth, 0.0, 1.0);
}

// Footprint-aware anisotropic filtering.
//
// Instead of adding a fixed LOD bias, estimate the source-texel footprint
// of one output pixel. Integrate along its major axis with adaptive samples,
// and use mip-level filtering across the minor axis. This helps when curvature
// or tilt makes the CRT mask/scanline pattern highly anisotropic.
vec4 sampleLinearGamma(sampler2D Src, vec2 uv, float lod)
{
    vec4 c = textureLod(Src, uv, lod);
#ifdef LINEAR_PROCESSING
    c = pow(max(c, vec4(0.0)), vec4(reg.geom_target_gamma));
#endif
    return c;
}

vec4 trilinear(sampler2D Src, vec2 uv, vec2 texsize)
{
    // Pixel-footprint integration in screen space. Sampling a small grid over
    // the transformed pixel footprint approximates an elliptical/area filter,
    // and follows both axes of the warp instead of guessing a fixed LOD bias.
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    float lx = length(dx * texsize);
    float ly = length(dy * texsize);
    float majorLen = max(lx, ly);
    float minorLen = max(min(lx, ly), 1.0);

    // Increase the grid only when the footprint is being minified. The minor
    // axis is prefiltered with mipmaps; grid integration handles orientation.
    int taps = int(clamp(ceil(majorLen), 1.0, 6.0));
    float lod = max(0.0, log2(minorLen) + reg.geom_lod_bias);
    vec4 sum = vec4(0.0);
    vec4 lo = vec4(1e20);
    vec4 hi = vec4(-1e20);
    float weightSum = 0.0;

    // Gaussian-like separable weights, evaluated over a regular grid spanning
    // the output pixel. Up to 36 samples for extreme curvature/tilt.
    for (int y = 0; y < 6; ++y) {
        if (y >= taps) break;
        float oy = (float(y) + 0.5) / float(taps) - 0.5;
        float wy = exp(-8.0 * oy * oy);
        for (int x = 0; x < 6; ++x) {
            if (x >= taps) break;
            float ox = (float(x) + 0.5) / float(taps) - 0.5;
            float wx = exp(-8.0 * ox * ox);
            float w = wx * wy;
            vec2 sampleUV = uv + dx * ox + dy * oy;
            vec4 c = textureLod(Src, sampleUV, lod);
#ifdef LINEAR_PROCESSING
            c = pow(max(c, vec4(0.0)), vec4(reg.geom_target_gamma));
#endif
            sum += c * w;
            weightSum += w;
            lo = min(lo, c);
            hi = max(hi, c);
        }
    }

    vec4 filtered = sum / max(weightSum, 1e-6);

    // Detail recovery: blend in a bounded high-frequency residual from the
    // center sample. Clamping to the footprint's sample range prevents large
    // overshoots and limits the sharpening from bringing back strong moire.
    float sharp = clamp((reg.geom_sharper - 1.0) * 0.30, 0.0, 0.60);
    if (sharp > 0.0) {
        vec4 center = textureLod(Src, uv, 0.0);
#ifdef LINEAR_PROCESSING
        center = pow(max(center, vec4(0.0)), vec4(reg.geom_target_gamma));
#endif
        vec4 sharpened = filtered + (center - filtered) * sharp;
        filtered = clamp(sharpened, lo, hi);
    }

    return filtered;
}

void main()
{
    // Texture coordinates of the texel containing the active pixel.
    vec2 xy;

    if (reg.geom_curvature > 0.5)
        xy = transform(vTexCoord);
    else
        xy = vTexCoord;

    float cval = corner(xy);

    vec2 uv_ratio = fract((xy * TextureSize - vec2(0.5, 0.5)) / TextureSize);

    vec4 col = TEX2D(xy);

#ifndef LINEAR_PROCESSING
    col  = pow(col , vec4(reg.geom_target_gamma));
#endif

    col.rgb *= (reg.geom_lum * step(0.0, uv_ratio.y));

    vec3 mul_res  =  col.rgb * vec3(cval);

    // Convert the image gamma for display on our output device.
    mul_res = pow(mul_res, vec3(1.0 / reg.geom_monitor_gamma));

    FragColor = vec4(mul_res, 1.0);
}
