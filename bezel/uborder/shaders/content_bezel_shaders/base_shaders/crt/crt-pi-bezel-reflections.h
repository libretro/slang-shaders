
layout(push_constant) uniform Push
{
    float CURVATURE_X;
    float CURVATURE_Y;
    float MASK_BRIGHTNESS;
    float SCANLINE_WEIGHT;
    float SCANLINE_GAP_BRIGHTNESS;
    float BLOOM_FACTOR;
    float INPUT_GAMMA;
    float OUTPUT_GAMMA;
} param;

#define USE_GLOBAL_UNIFORMS
#define USE_BEZEL_REFLECTIONS_COMMON

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;

#include "../../include/uborder_bezel_reflections_global_declarations.inc"

} global;

#include "../../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     global.OutputSize
#define ub_OriginalSize   global.OriginalSize
#define ub_Rotation       global.Rotation

#include "../../include/uborder_bezel_reflections_common.inc"

#pragma parameter PI_NONONO            "CRT-PI:"                     0.0  0.0   1.0 1.0
#pragma parameter CURVATURE_X             "Screen curvature - horizontal" 0.10 0.0 1.0  0.01
#pragma parameter CURVATURE_Y             "Screen curvature - vertical"   0.15 0.0 1.0  0.01
#pragma parameter MASK_BRIGHTNESS         "Mask brightness"               0.70 0.0 1.0  0.01
#pragma parameter SCANLINE_WEIGHT         "Scanline weight"               6.0  0.0 15.0 0.1
#pragma parameter SCANLINE_GAP_BRIGHTNESS "Scanline gap brightness"       0.12 0.0 1.0  0.01
#pragma parameter BLOOM_FACTOR            "Bloom factor"                  1.5  0.0 5.0  0.01
#pragma parameter INPUT_GAMMA             "Input gamma"                   2.4  0.0 5.0  0.01
#pragma parameter OUTPUT_GAMMA            "Output gamma"                  2.2  0.0 5.0  0.01

float  mask_sizex  = ub_OutputSize.x* fr_scale.x * (1.0 - 0.5*global.h_curvature);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 uv;
layout(location = 2) out float filterWidth;
layout(location = 3) out vec2 border_uv;
layout(location = 4) out vec2 bezel_uv;


void main()
{
    gl_Position  = global.MVP * Position;

    vec2 diff = TexCoord.xy * vec2(1.000001) - middle;
    vTexCoord = middle + diff/fr_scale - fr_center;

    uv        = 2.0*vTexCoord - 1.0.xx;
    bezel_uv  = uv - 2.0*bz_center;

    border_uv = get_unrotated_coords(get_unrotated_coords(TexCoord.xy, ub_Rotation), int(global.border_allow_rot));

    border_uv.y = mix(border_uv.y, 1.0-border_uv.y, border_mirror_y);

    border_uv = middle + (border_uv.xy - middle - border_pos) / (global.border_scale*all_zoom);

    border_uv = border_uv.xy * vec2(1.000001);

#ifdef KEEP_BORDER_ASPECT_RATIO
    border_uv -= 0.5.xx;
#endif

    filterWidth = (global.SourceSize.y * global.OutputSize.w) * 0.333333333;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 uv;
layout(location = 2) in float filterWidth;
layout(location = 3) in vec2 border_uv;
layout(location = 4) in vec2 bezel_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;
layout(set = 0, binding = 4) uniform sampler2D LAYER2;
#ifdef USE_AMBIENT_LIGHT
layout(set = 0, binding = 5) uniform sampler2D ambi_temporal_pass;
#endif

/* MASK_TYPE: 0 = none, 1 = green/magenta, 2 = trinitron(ish) */
#define MASK_TYPE 2

#define SCANLINES
#define CURVATURE
//#define FAKE_GAMMA
//#define GAMMA
//#define SHARPER
#define MULTISAMPLE

/*
    crt-pi - A Raspberry Pi friendly CRT shader.
    Copyright (C) 2015-2016 davej
    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

Notes:
This shader is designed to work well on Raspberry Pi GPUs (i.e. 1080P @ 60Hz on
a game with a 4:3 aspect ratio). 
It pushes the Pi's GPU hard and enabling some features will slow it down so that
it is no longer able to match 1080P @ 60Hz. 
You will need to overclock your Pi to the fastest setting in raspi-config to get
the best results from this shader: 'Pi2' for Pi2 and 'Turbo' for original Pi and
Pi Zero. 
Note: Pi2s are slower at running the shader than other Pis, this seems to be
down to Pi2s lower maximum memory speed. 
Pi2s don't quite manage 1080P @ 60Hz - they drop about 1 in 1000 frames. 
You probably won't notice this, but if you do, try enabling FAKE_GAMMA.
SCANLINES enables scanlines. 
You'll almost certainly want to use it with MULTISAMPLE to reduce moire effects. 
SCANLINE_WEIGHT defines how wide scanlines are (it is an inverse value so a
higher number = thinner lines). 
SCANLINE_GAP_BRIGHTNESS defines how dark the gaps between the scan lines are. 
Darker gaps between scan lines make moire effects more likely.
GAMMA enables gamma correction using the values in INPUT_GAMMA and OUTPUT_GAMMA.
FAKE_GAMMA causes it to ignore the values in INPUT_GAMMA and OUTPUT_GAMMA and 
approximate gamma correction in a way which is faster than true gamma whilst 
still looking better than having none. 
You must have GAMMA defined to enable FAKE_GAMMA.
CURVATURE distorts the screen by CURVATURE_X and CURVATURE_Y. 
Curvature slows things down a lot.
By default the shader uses linear blending horizontally. If you find this too
blury, enable SHARPER.
BLOOM_FACTOR controls the increase in width for bright scanlines.
MASK_TYPE defines what, if any, shadow mask to use. MASK_BRIGHTNESS defines how
much the mask type darkens the screen.
*/

#if defined(CURVATURE)
vec2 CURVATURE_DISTORTION = vec2(param.CURVATURE_X, param.CURVATURE_Y);
// Barrel distortion shrinks the display area a bit, this will allow us to counteract that.
vec2 barrelScale = 1.0 - (0.23 * CURVATURE_DISTORTION);

vec2 Distort(vec2 coord)
{
//  coord *= screenScale; // not necessary in slang
    coord -= vec2(0.5);
    float rsq = coord.x * coord.x + coord.y * coord.y;
    coord += coord * (CURVATURE_DISTORTION * rsq);
    coord *= barrelScale;
    if (abs(coord.x) >= 0.5 || abs(coord.y) >= 0.5)
        coord = vec2(-1.0);     // If out of bounds, return an invalid value.
    else
    {
        coord += vec2(0.5);
//      coord /= screenScale; // not necessary in slang
    }

    return coord;
}
#endif

float CalcScanLineWeight(float dist)
{
    return max(1.0-dist*dist*param.SCANLINE_WEIGHT, param.SCANLINE_GAP_BRIGHTNESS);
}

float CalcScanLine(float dy)
{
    float scanLineWeight = CalcScanLineWeight(dy);
#if defined(MULTISAMPLE)
    scanLineWeight += CalcScanLineWeight(dy - filterWidth);
    scanLineWeight += CalcScanLineWeight(dy + filterWidth);
    scanLineWeight *= 0.3333333;
#endif
    return scanLineWeight;
}

vec3 get_content(vec2 vTex, vec2 uv)
{
//    vec2 texcoord = vTexCoord;
    vec2 texcoord = vTex;

#if defined(CURVATURE)
    texcoord = Distort(texcoord);
    if (texcoord.x < 0.0) 
    {
        //FragColor = vec4(0.0);
        return vec3(0.0);
    }
#endif

    vec2 texcoordInPixels = texcoord * global.SourceSize.xy;

#if defined(SHARPER)
    vec2 tempCoord       = floor(texcoordInPixels) + 0.5;
    vec2 coord           = tempCoord * global.SourceSize.zw;
    vec2 deltas          = texcoordInPixels - tempCoord;
    float scanLineWeight = CalcScanLine(deltas.y);
    
    vec2 signs = sign(deltas);
    
    deltas   = abs(deltas) * 2.0;
    deltas.x = deltas.x * deltas.x;
    deltas.y = deltas.y * deltas.y * deltas.y;
    deltas  *= 0.5 * global.SourceSize.zw * signs;

    vec2 tc = coord + deltas;
#else
    float tempCoord       = floor(texcoordInPixels.y) + 0.5;
    float coord           = tempCoord * global.SourceSize.w;
    float deltas          = texcoordInPixels.y - tempCoord;
    float scanLineWeight  = CalcScanLine(deltas);
    
    float signs = sign(deltas);
    
    deltas   = abs(deltas) * 2.0;
    deltas   = deltas * deltas * deltas;
    deltas  *= 0.5 * global.SourceSize.w * signs;

    vec2 tc = vec2(texcoord.x, coord + deltas);
#endif

    vec3 colour = texture(Source, tc).rgb;

#if defined(SCANLINES)


#if defined(GAMMA) && defined(FAKE_GAMMA)
    colour = colour * colour;
#elif defined(GAMMA)
    colour = pow(colour, vec3(param.INPUT_GAMMA));
#endif
    
    /* Apply scanlines */
    scanLineWeight *= param.BLOOM_FACTOR;
    colour *= scanLineWeight;

#if defined(GAMMA) && defined(FAKE_GAMMA)
    colour = sqrt(colour);
#elif defined(GAMMA)
    colour = pow(colour, vec3(1.0/param.OUTPUT_GAMMA));
#endif


#endif /* SCANLINES */

#if MASK_TYPE == 1
//    float whichMask = fract((vTexCoord.x * global.OutputSize.x) * 0.5);
    float whichMask = fract((mix(vTex.x, uv.x, global.h_curvature) * mask_sizex) * 0.5);
    vec3 mask       = vec3(1.0);

    if (whichMask < 0.5) mask.rb = vec2(param.MASK_BRIGHTNESS);
    else                 mask.g  = param.MASK_BRIGHTNESS;

    colour *= mask;
#elif MASK_TYPE == 2
//    float whichMask = fract((vTexCoord.x * global.OutputSize.x)  * 0.3333333);
    float whichMask = fract((mix(vTex.x, uv.x, global.h_curvature) * mask_sizex)  * 0.3333333);
    vec3 mask       = vec3(param.MASK_BRIGHTNESS);
    
    if      (whichMask < 0.3333333) mask.r = 1.0;
    else if (whichMask < 0.6666666) mask.g = 1.0;
    else                            mask.b = 1.0;

    colour *= mask;
#endif

//    FragColor = vec4(colour, 1.0);
    return colour;
}


#define ReflexSrc Source

// Yeah, an unorthodox 'include' usage.
#include "../../include/uborder_bezel_reflections_main.inc"
