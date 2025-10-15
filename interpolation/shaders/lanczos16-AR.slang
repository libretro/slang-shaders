#version 450

/*
 AR: Copyright (C) 2010 Team XBMC
   http://www.xbmc.org
   Copyright (C) 2011 Stefanos A.
   http://www.opentk.com

Lanczos implementation: Copyright (C) 2007 guest(r) - guest.r@gmail.com

This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

   
   Modified by djayjp aka CreativeForce
   Lanczos-4 (16-tap) with optional anti-ringing.
   FIX: Corrected half-texel alignment (centering on texel middle) to remove
   the ~1-pixel up/left shift some drivers/backends exhibited.
*/

#pragma parameter AR_STRENGTH "Anti-ringing Strength" 0.61 0.0 1.0 0.01

layout(push_constant) uniform Push {
    vec4 SourceSize;   // xy = size, zw = 1/size
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float AR_STRENGTH;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

const float floatpi = 1.5707963267948966192313216916398; // pi/2
const float pi      = 3.1415926535897932384626433832795;

vec4 l(vec4 x)
{
    vec4 res;
    res.x = (x.x==0.0) ?  (pi*floatpi)  :  sin(x.x*floatpi)*sin(x.x*pi)/(x.x*x.x);
    res.y = (x.y==0.0) ?  (pi*floatpi)  :  sin(x.y*floatpi)*sin(x.y*pi)/(x.y*x.y);
    res.z = (x.z==0.0) ?  (pi*floatpi)  :  sin(x.z*floatpi)*sin(x.z*pi)/(x.z*x.z);
    res.w = (x.w==0.0) ?  (pi*floatpi)  :  sin(x.w*floatpi)*sin(x.w*pi)/(x.w*x.w);
    return res;
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    // Pass through without the tiny expansion factor that could skew edges.
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Pixel size in UV
    vec2 ps = params.SourceSize.zw;

    // Compute "texel-space" coordinate centered on texel middles
    // NOTE: the -0.5 is the essential fix (centers on half-integers).
    vec2 tex      = vTexCoord * params.SourceSize.xy - vec2(0.5);
    vec2 fraction = fract(tex);

    // Separable 1D Lanczos-4 weights (x then y)
    vec4 abcd = l(vec4(1.0 + fraction.x, fraction.x, 1.0 - fraction.x, 2.0 - fraction.x));
    vec4 pqrs = l(vec4(1.0 + fraction.y, fraction.y, 1.0 - fraction.y, 2.0 - fraction.y));

    // Anchor sampling to the center of the "base" texel.
    vec2 base = (floor(tex) + vec2(0.5)) * ps;

    // Read 4x4 neighborhood around base; lay out as:
    //  c00 c10 c20 c30
    //  c01 c11 c21 c31
    //  c02 c12 c22 c32
    //  c03 c13 c23 c33
    vec3 c00 = texture(Source, base + vec2(-ps.x, -ps.y)).xyz;
    vec3 c10 = texture(Source, base + vec2( 0.0 , -ps.y)).xyz;
    vec3 c20 = texture(Source, base + vec2( ps.x, -ps.y)).xyz;
    vec3 c30 = texture(Source, base + vec2( 2.0*ps.x, -ps.y)).xyz;

    vec3 c01 = texture(Source, base + vec2(-ps.x,  0.0 )).xyz;
    vec3 c11 = texture(Source, base + vec2( 0.0 ,  0.0 )).xyz;
    vec3 c21 = texture(Source, base + vec2( ps.x,  0.0 )).xyz;
    vec3 c31 = texture(Source, base + vec2( 2.0*ps.x,  0.0 )).xyz;

    vec3 c02 = texture(Source, base + vec2(-ps.x,  ps.y)).xyz;
    vec3 c12 = texture(Source, base + vec2( 0.0 ,  ps.y)).xyz;
    vec3 c22 = texture(Source, base + vec2( ps.x,  ps.y)).xyz;
    vec3 c32 = texture(Source, base + vec2( 2.0*ps.x,  ps.y)).xyz;

    vec3 c03 = texture(Source, base + vec2(-ps.x,  2.0*ps.y)).xyz;
    vec3 c13 = texture(Source, base + vec2( 0.0 ,  2.0*ps.y)).xyz;
    vec3 c23 = texture(Source, base + vec2( ps.x,  2.0*ps.y)).xyz;
    vec3 c33 = texture(Source, base + vec2( 2.0*ps.x,  2.0*ps.y)).xyz;

    // Horizontal combine (use the same sign pattern as original shader)
    mat4x3 pix;
    pix[0] = mat4x3(-c00,  c10,  c20, -c30) * abcd;
    pix[1] = mat4x3( c01,  c11,  c21,  c31) * abcd;
    pix[2] = mat4x3( c02,  c12,  c22,  c32) * abcd;
    pix[3] = mat4x3(-c03,  c13,  c23, -c33) * abcd;

    // Final sum and weight normalization
    float sumx = dot(abcd, vec4(1.0));
    float sumy = dot(pqrs, vec4(1.0));
    // Keep the original denominator structure (accounts for the sign pattern)
    float denom = sumx * sumy - 2.0 * (abcd.x + abcd.w) * (pqrs.x + pqrs.w);

    vec3 col_tmp = (pix * pqrs) / max(denom, 1e-8);

    // Anti-ringing clamp in the 4x4 footprint
    vec3 cmin = min(min(min(c00, c01), min(c02, c03)), min(min(c10, c11), min(c12, c13)));
    cmin = min(cmin, min(min(c20, c21), min(c22, c23)));
    cmin = min(cmin, min(min(c30, c31), min(c32, c33)));

    vec3 cmax = max(max(max(c00, c01), max(c02, c03)), max(max(c10, c11), max(c12, c13)));
    cmax = max(cmax, max(max(c20, c21), max(c22, c23)));
    cmax = max(cmax, max(max(c30, c31), max(c32, c33)));

    col_tmp = mix(col_tmp, clamp(col_tmp, cmin, cmax), clamp(params.AR_STRENGTH, 0.0, 1.0));
    FragColor = vec4(col_tmp, 1.0);
}
