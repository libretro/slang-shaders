#version 450

layout(push_constant) uniform Push
{
    float BRIGHT_BOOST;
    float DILATION;
    float GAMMA_INPUT;
    float GAMMA_OUTPUT;
    float MASK_SIZE;
    float MASK_STAGGER;
    float MASK_STRENGTH;
    float MASK_DOT_HEIGHT;
    float MASK_DOT_WIDTH;
    float SCANLINE_CUTOFF;
    float SCANLINE_BEAM_WIDTH_MAX;
    float SCANLINE_BEAM_WIDTH_MIN;
    float SCANLINE_BRIGHT_MAX;
    float SCANLINE_BRIGHT_MIN;
    float SCANLINE_STRENGTH;
    float SHARPNESS_H;
    float SHARPNESS_V;
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


#pragma parameter easy_nonono        "CRT-EASYMODE:"                0.0  0.0 1.0 1.0
#pragma parameter SHARPNESS_H "Sharpness Horizontal" 0.5 0.0 1.0 0.05
#pragma parameter SHARPNESS_V "Sharpness Vertical" 1.0 0.0 1.0 0.05
#pragma parameter MASK_STRENGTH "Mask Strength" 0.3 0.0 1.0 0.01
#pragma parameter MASK_DOT_WIDTH "Mask Dot Width" 1.0 1.0 100.0 1.0
#pragma parameter MASK_DOT_HEIGHT "Mask Dot Height" 1.0 1.0 100.0 1.0
#pragma parameter MASK_STAGGER "Mask Stagger" 0.0 0.0 100.0 1.0
#pragma parameter MASK_SIZE "Mask Size" 1.0 1.0 100.0 1.0
#pragma parameter SCANLINE_STRENGTH "Scanline Strength" 1.0 0.0 1.0 0.05
#pragma parameter SCANLINE_BEAM_WIDTH_MIN "Scanline Beam Width Min." 1.5 0.5 5.0 0.5
#pragma parameter SCANLINE_BEAM_WIDTH_MAX "Scanline Beam Width Max." 1.5 0.5 5.0 0.5
#pragma parameter SCANLINE_BRIGHT_MIN "Scanline Brightness Min." 0.35 0.0 1.0 0.05
#pragma parameter SCANLINE_BRIGHT_MAX "Scanline Brightness Max." 0.65 0.0 1.0 0.05
#pragma parameter SCANLINE_CUTOFF "Scanline Cutoff" 400.0 1.0 1000.0 1.0
#pragma parameter GAMMA_INPUT "Gamma Input" 2.0 0.1 5.0 0.1
#pragma parameter GAMMA_OUTPUT "Gamma Output" 1.8 0.1 5.0 0.1
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.0 0.01
#pragma parameter DILATION "Dilation" 1.0 0.0 1.0 1.0

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

/*
    CRT Shader by EasyMode
    License: GPL

    A flat CRT shader ideally for 1080p or higher displays.

    Recommended Settings:

    Video
    - Aspect Ratio:  4:3
    - Integer Scale: Off

    Shader
    - Filter: Nearest
    - Scale:  Don't Care

    Example RGB Mask Parameter Settings:

    Aperture Grille (Default)
    - Dot Width:  1
    - Dot Height: 1
    - Stagger:    0

    Lottes' Shadow Mask
    - Dot Width:  2
    - Dot Height: 1
    - Stagger:    3
*/

#pragma stage fragment
layout(location = 0) in  vec2 vTexCoord;
layout(location = 1) in vec2 sinangle;
layout(location = 2) in vec2 cosangle;
layout(location = 3) in vec3 stretch;
layout(location = 4) in float R_d_cx_cy;
layout(location = 5) in float d2;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

//#define FIX(c) max(abs(c), 1e-5)
//#define PI 3.141592653589

#define TEX2D(c) dilate(texture(Source, c))

// Set to 0 to use linear filter and gain speed
#define ENABLE_LANCZOS 1

vec4 dilate(vec4 col)
{
    vec4 x = mix(vec4(1.0), col, params.DILATION);

    return col * x;
}

float curve_distance(float x, float sharp)
{

/*
    apply half-circle s-curve to distance for sharper (more pixelated) interpolation
    single line formula for Graph Toy:
    0.5 - sqrt(0.25 - (x - step(0.5, x)) * (x - step(0.5, x))) * sign(0.5 - x)
*/

    float x_step = step(0.5, x);
    float curve = 0.5 - sqrt(0.25 - (x - x_step) * (x - x_step)) * sign(0.5 - x);

    return mix(x, curve, sharp);
}

mat4x4 get_color_matrix(vec2 co, vec2 dx)
{
    return mat4x4(TEX2D(co - dx), TEX2D(co), TEX2D(co + dx), TEX2D(co + 2.0 * dx));
}

vec3 filter_lanczos(vec4 coeffs, mat4x4 color_matrix)
{
    vec4 col        = color_matrix * coeffs;
    vec4 sample_min = min(color_matrix[1], color_matrix[2]);
    vec4 sample_max = max(color_matrix[1], color_matrix[2]);

    col = clamp(col, sample_min, sample_max);

    return col.rgb;
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

/* main_fragment */
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


    vec2 dx     = vec2(global.SourceSize.z, 0.0);
    vec2 dy     = vec2(0.0, global.SourceSize.w);
//    vec2 pix_co = vTexCoord * global.SourceSize.xy - vec2(0.5, 0.5);
    vec2 pix_co = uv * global.SourceSize.xy - vec2(0.5, 0.5);
    vec2 tex_co = (floor(pix_co) + vec2(0.5, 0.5)) * global.SourceSize.zw;
    vec2 dist   = fract(pix_co);
    float curve_x;
    vec3 col, col2;

#if ENABLE_LANCZOS
    curve_x = curve_distance(dist.x, params.SHARPNESS_H * params.SHARPNESS_H);

    vec4 coeffs = PI * vec4(1.0 + curve_x, curve_x, 1.0 - curve_x, 2.0 - curve_x);

    coeffs = FIX(coeffs);
    coeffs = 2.0 * sin(coeffs) * sin(coeffs * 0.5) / (coeffs * coeffs);
    coeffs /= dot(coeffs, vec4(1.0));

    col  = filter_lanczos(coeffs, get_color_matrix(tex_co, dx));
    col2 = filter_lanczos(coeffs, get_color_matrix(tex_co + dy, dx));
#else
    curve_x = curve_distance(dist.x, params.SHARPNESS_H);

    col  = mix(TEX2D(tex_co).rgb,      TEX2D(tex_co + dx).rgb,      curve_x);
    col2 = mix(TEX2D(tex_co + dy).rgb, TEX2D(tex_co + dx + dy).rgb, curve_x);
#endif

    col = mix(col, col2, curve_distance(dist.y, params.SHARPNESS_V));
    col = pow(col, vec3(params.GAMMA_INPUT / (params.DILATION + 1.0)));

    float luma        = dot(vec3(0.2126, 0.7152, 0.0722), col);
    float bright      = (max(col.r, max(col.g, col.b)) + luma) * 0.5;
    float scan_bright = clamp(bright, params.SCANLINE_BRIGHT_MIN, params.SCANLINE_BRIGHT_MAX);
    float scan_beam   = clamp(bright * params.SCANLINE_BEAM_WIDTH_MAX, params.SCANLINE_BEAM_WIDTH_MIN, params.SCANLINE_BEAM_WIDTH_MAX);
//    float scan_weight = 1.0 - pow(cos(vTexCoord.y * 2.0 * PI * global.SourceSize.y) * 0.5 + 0.5, scan_beam) * params.SCANLINE_STRENGTH;
    float scan_weight = 1.0 - pow(cos(uv.y * 2.0 * PI * global.SourceSize.y) * 0.5 + 0.5, scan_beam) * params.SCANLINE_STRENGTH;

    float mask   = 1.0 - params.MASK_STRENGTH;    
//    vec2 mod_fac = floor(vTexCoord * global.OutputSize.xy * global.SourceSize.xy / (global.SourceSize.xy * vec2(params.MASK_SIZE, params.MASK_DOT_HEIGHT * params.MASK_SIZE)));
    vec2 mod_fac = floor(vTexCoord * ScaledOutputSize.xy * global.SourceSize.xy / (global.SourceSize.xy * vec2(params.MASK_SIZE, params.MASK_DOT_HEIGHT * params.MASK_SIZE)));
    int dot_no   = int(mod((mod_fac.x + mod(mod_fac.y, 2.0) * params.MASK_STAGGER) / params.MASK_DOT_WIDTH, 3.0));
    vec3 mask_weight;

    if      (dot_no == 0) mask_weight = vec3(1.0,  mask, mask);
    else if (dot_no == 1) mask_weight = vec3(mask, 1.0,  mask);
    else                  mask_weight = vec3(mask, mask, 1.0);

    if (global.SourceSize.y >= params.SCANLINE_CUTOFF) 
        scan_weight = 1.0;

    col2 = col.rgb;
    col *= vec3(scan_weight);
    col  = mix(col, col2, scan_bright);
    col *= mask_weight;
    col  = pow(col, vec3(1.0 / params.GAMMA_OUTPUT));

//    FragColor = vec4(col * params.BRIGHT_BOOST, 1.0);
    FragColor = vec4(col * params.BRIGHT_BOOST * vec3(cval), cval);
}
