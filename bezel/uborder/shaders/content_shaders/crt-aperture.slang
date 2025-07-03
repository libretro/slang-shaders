#version 450

/*
    CRT Shader by EasyMode
    License: GPL
*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float SHARPNESS_IMAGE;
	float SHARPNESS_EDGES;
	float GLOW_WIDTH;
	float GLOW_HEIGHT;
	float GLOW_HALATION;
	float GLOW_DIFFUSION;
	float MASK_COLORS;
	float MASK_STRENGTH;
	float MASK_SIZE;
	float SCANLINE_SIZE_MIN;
	float SCANLINE_SIZE_MAX;
   float SCANLINE_SHAPE;
   float SCANLINE_OFFSET;
	float GAMMA_INPUT;
	float GAMMA_OUTPUT;
	float BRIGHTNESS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
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

#pragma parameter apert_nonono       "CRT-APERTURE:"                           0.0  0.0 1.0 1.0
#pragma parameter SHARPNESS_IMAGE "Sharpness Image" 1.0 1.0 5.0 1.0
#pragma parameter SHARPNESS_EDGES "Sharpness Edges" 3.0 1.0 5.0 1.0
#pragma parameter GLOW_WIDTH "Glow Width" 0.5 0.05 0.65 0.05
#pragma parameter GLOW_HEIGHT "Glow Height" 0.5 0.05 0.65 0.05
#pragma parameter GLOW_HALATION "Glow Halation" 0.1 0.0 1.0 0.01
#pragma parameter GLOW_DIFFUSION "Glow Diffusion" 0.05 0.0 1.0 0.01
#pragma parameter MASK_COLORS "Mask Colors" 2.0 2.0 3.0 1.0
#pragma parameter MASK_STRENGTH "Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter MASK_SIZE "Mask Size" 1.0 1.0 9.0 1.0
#pragma parameter SCANLINE_SIZE_MIN "Scanline Size Min." 0.5 0.5 1.5 0.05
#pragma parameter SCANLINE_SIZE_MAX "Scanline Size Max." 1.5 0.5 1.5 0.05
#pragma parameter SCANLINE_SHAPE "Scanline Shape" 2.5 1.0 100.0 0.1
#pragma parameter SCANLINE_OFFSET "Scanline Offset" 1.0 0.0 1.0 1.0
#pragma parameter GAMMA_INPUT "Gamma Input" 2.4 1.0 5.0 0.1
#pragma parameter GAMMA_OUTPUT "Gamma Output" 2.4 1.0 5.0 0.1
#pragma parameter BRIGHTNESS "Brightness" 1.5 0.0 2.0 0.05



#define FIX(c) max(abs(c), 1e-5)
#define PI 3.141592653589
#define TEX2D(c) pow(texture(tex, c).rgb, vec3(params.GAMMA_INPUT))
#define saturate(c) clamp(c, 0.0, 1.0)

// aspect ratio
vec2 aspect     = vec2(global.geom_invert_aspect > 0.5 ? (0.75, 1.0) : (1.0, 0.75));
vec2 overscan   = vec2(1.01, 1.01);

vec2 ScaledOutputSize = vec2(global.in_res_x, global.in_res_y) * global.box_scale;


mat3x3 get_color_matrix(sampler2D tex, vec2 co, vec2 dx)
{
    return mat3x3(TEX2D(co - dx), TEX2D(co), TEX2D(co + dx));
}

vec3 blur(mat3 m, float dist, float rad)
{
    vec3 x = vec3(dist - 1.0, dist, dist + 1.0) / rad;
    vec3 w = exp2(x * x * -1.0);

    return (m[0] * w.x + m[1] * w.y + m[2] * w.z) / (w.x + w.y + w.z);
}

vec3 filter_gaussian(sampler2D tex, vec2 co, vec2 tex_size)
{
    vec2 dx = vec2(1.0 / tex_size.x, 0.0);
    vec2 dy = vec2(0.0, 1.0 / tex_size.y);
    vec2 pix_co = co * tex_size;
    vec2 tex_co = (floor(pix_co) + 0.5) / tex_size;
    vec2 dist = (fract(pix_co) - 0.5) * -1.0;

    mat3x3 line0 = get_color_matrix(tex, tex_co - dy, dx);
    mat3x3 line1 = get_color_matrix(tex, tex_co, dx);
    mat3x3 line2 = get_color_matrix(tex, tex_co + dy, dx);
    mat3x3 column = mat3x3(blur(line0, dist.x, params.GLOW_WIDTH),
                               blur(line1, dist.x, params.GLOW_WIDTH),
                               blur(line2, dist.x, params.GLOW_WIDTH));

    return blur(column, dist.y, params.GLOW_HEIGHT);
}

vec3 filter_lanczos(sampler2D tex, vec2 co, vec2 tex_size, float sharp)
{
    tex_size.x *= sharp;

    vec2 dx = vec2(1.0 / tex_size.x, 0.0);
    vec2 pix_co = co * tex_size - vec2(0.5, 0.0);
    vec2 tex_co = (floor(pix_co) + vec2(0.5, 0.001)) / tex_size;
    vec2 dist = fract(pix_co);
    vec4 coef = PI * vec4(dist.x + 1.0, dist.x, dist.x - 1.0, dist.x - 2.0);

    coef = FIX(coef);
    coef = 2.0 * sin(coef) * sin(coef / 2.0) / (coef * coef);
    coef /= dot(coef, vec4(1.0));

    vec4 col1 = vec4(TEX2D(tex_co), 1.0);
    vec4 col2 = vec4(TEX2D(tex_co + dx), 1.0);

    return (mat4x4(col1, col1, col2, col2) * coef).rgb;
}

vec3 get_scanline_weight(float x, vec3 col)
{
    vec3 beam = mix(vec3(params.SCANLINE_SIZE_MIN), vec3(params.SCANLINE_SIZE_MAX), pow(col, vec3(1.0 / params.SCANLINE_SHAPE)));
    vec3 x_mul = 2.0 / beam;
    vec3 x_offset = x_mul * 0.5;

    return smoothstep(0.0, 1.0, 1.0 - abs(x * x_mul - x_offset)) * x_offset;
}

vec3 get_mask_weight(float x)
{
//    float i = mod(floor(x * params.OutputSize.x * params.SourceSize.x / (params.SourceSize.x * params.MASK_SIZE)), params.MASK_COLORS);
    float i = mod(floor(x * ScaledOutputSize.x * params.SourceSize.x / (params.SourceSize.x * params.MASK_SIZE)), params.MASK_COLORS);

    if (i == 0.0) return mix(vec3(1.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), params.MASK_COLORS - 2.0);
    else if (i == 1.0) return vec3(0.0, 1.0, 0.0);
    else return vec3(0.0, 0.0, 1.0);
}



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

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 sinangle;
layout(location = 2) in vec2 cosangle;
layout(location = 3) in vec3 stretch;
layout(location = 4) in float R_d_cx_cy;
layout(location = 5) in float d2;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

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


//    float scale = floor(params.OutputSize.y * params.SourceSize.w);
    float scale = floor(ScaledOutputSize.y * params.SourceSize.w);
    float offset = 1.0 / scale * 0.5;
    
    if (bool(mod(scale, 2.0))) offset = 0.0;
    
//    vec2 co = (vTexCoord * params.SourceSize.xy - vec2(0.0, offset * params.SCANLINE_OFFSET)) * params.SourceSize.zw;
    vec2 co = (uv * params.SourceSize.xy - vec2(0.0, offset * params.SCANLINE_OFFSET)) * params.SourceSize.zw;
    vec3 col_glow = filter_gaussian(Source, co, params.SourceSize.xy);
    vec3 col_soft = filter_lanczos(Source, co, params.SourceSize.xy, params.SHARPNESS_IMAGE);
    vec3 col_sharp = filter_lanczos(Source, co, params.SourceSize.xy, params.SHARPNESS_EDGES);
    vec3 col = sqrt(col_sharp * col_soft);

    col *= get_scanline_weight(fract(co.y * params.SourceSize.y), col_soft);
    col_glow = saturate(col_glow - col);
    col += col_glow * col_glow * params.GLOW_HALATION;
    col = mix(col, col * get_mask_weight(vTexCoord.x) * params.MASK_COLORS, params.MASK_STRENGTH); // Do not apply curvature to mask coordinates. Prevents moiré!
    col += col_glow * params.GLOW_DIFFUSION;
    col = pow(col * params.BRIGHTNESS, vec3(1.0 / params.GAMMA_OUTPUT));
//   FragColor = vec4(col, 1.0);
   FragColor = vec4(col * vec3(cval), cval);
}
