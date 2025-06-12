#version 450

/*
    Hyllian's CRT Shader

    Copyright (C) 2011-2024 Hyllian - sergiogdb@gmail.com

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

layout(push_constant) uniform Push
{
    float HFILTER_PROFILE;
    float SHARPNESS_HACK;
    float CRT_ANTI_RINGING;
    float CURVATURE;
    float WARP_X;
    float WARP_Y;
} params;

#pragma parameter H_OUTPUT_GAMMA    "    Output Gamma"    2.2 1.0 3.0 0.05
#pragma parameter BRIGHTBOOST       "    Brightboost"     1.0 0.5 2.0 0.01

#pragma parameter scan_nonono        "SCANLINES SETTINGS:"                         0.0  0.0 0.0 1.0
#pragma parameter BEAM_MIN_WIDTH     "    Min Beam Width"                        0.72 0.0 1.0 0.01
#pragma parameter BEAM_MAX_WIDTH     "    Max Beam Width"                        1.0  0.0 1.0 0.01
#pragma parameter SCANLINES_STRENGTH "    Scanlines Strength"                    0.72 0.0 1.0 0.01
#pragma parameter SCANLINES_SHAPE    "    Scanlines Shape [ SHARP, SOFT ]"       1.0  0.0 1.0 1.0

#pragma parameter msk_nonono        "MASK SETTINGS:"                                             0.0 0.0  0.0 1.0
#pragma parameter PHOSPHOR_LAYOUT   "    Mask [1-6 APERT, 7-10 DOT, 11-14 SLOT, 15-17 LOTTES]" 1.0 0.0 17.0 1.0
#pragma parameter MASK_STRENGTH     "    Mask Strength"                                          1.0 0.0  1.0 0.02
#pragma parameter H_MaskGamma       "    Mask Gamma"                                             2.4 1.0  3.0 0.05
#pragma parameter MONITOR_SUBPIXELS "    Monitor Subpixels Layout [ RGB, BGR ]"                  0.0 0.0  1.0 1.0

#pragma parameter fil_nonono        "FILTERING SETTINGS:"                            0.0 0.0 0.0 1.0
#pragma parameter HFILTER_PROFILE   "    Horizontal Filter Profile [ Sharp1 | Sharp2 ]"  1.0 0.0 1.0 1.0
#pragma parameter SHARPNESS_HACK    "    Sharpness Hack"                             1.0 1.0 4.0 1.0
#pragma parameter CRT_ANTI_RINGING  "    Anti Ringing"                               1.0 0.0 1.0 1.0

#pragma parameter h_nonono        "CURVATURE SETTINGS:"                 0.0  0.0  0.0 1.0
#pragma parameter CURVATURE         "    Curvature Toggle" 0.0 0.0 1.0 1.0
#pragma parameter WARP_X            "        Curvature-X" 0.015 0.0 0.125 0.005
#pragma parameter WARP_Y            "        Curvature-Y" 0.015 0.0 0.125 0.005
#pragma parameter CORNER_SIZE       "        Corner Size" 0.02 0.001 1.0 0.005
#pragma parameter CORNER_SMOOTHNESS "        Corner Smoothness" 1.10 1.0 2.2 0.02


#define HFILTER_PROFILE params.HFILTER_PROFILE
#define CRT_ANTI_RINGING params.CRT_ANTI_RINGING
#define SHARPNESS_HACK params.SHARPNESS_HACK
#define CURVATURE params.CURVATURE
#define WARP_X params.WARP_X
#define WARP_Y params.WARP_Y

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
} global;


/* Curvature code. Credits to torridgristle! */
vec2 CRT_Distortion = vec2(WARP_X, 0.0) * 15.;

#define SQRT_OF_2  1.4142135623730950488016887242097

// Radius of Convergence = 1.0 - SQRT_OF_2 / 2

#define CONVERGENCE_RADIUS 0.29289321881345247559915563789515

vec2 Warp(vec2 texCoord)
{
   vec2 cCoords = texCoord * 2.0 - 1.0;
   float cCoordsDist = sqrt(cCoords.x * cCoords.x + cCoords.y * cCoords.y);
   cCoords = cCoords / cCoordsDist;
   cCoords = cCoords * (1.0 - pow(vec2(1.0 - (cCoordsDist/SQRT_OF_2)),(1.0/(1.0+CRT_Distortion*0.2))));
   cCoords = cCoords / (1.0-pow(vec2(CONVERGENCE_RADIUS),(1.0/(vec2(1.0)+CRT_Distortion*0.2))));
   cCoords = cCoords * 0.5 + 0.5;

   return cCoords;
}

// Horizontal cubic filter.
// Some known filters use these values:

//    B = 0.5, C = 0.0        =>  A sharp almost gaussian filter.
//    B = 0.0, C = 0.0        =>  Hermite cubic filter.
//    B = 1.0, C = 0.0        =>  Cubic B-Spline filter.
//    B = 0.0, C = 0.5        =>  Catmull-Rom Spline filter.
//    B = C = 1.0/3.0         =>  Mitchell-Netravali cubic filter.
//    B = 0.3782, C = 0.3109  =>  Robidoux filter.
//    B = 0.2620, C = 0.3690  =>  Robidoux Sharp filter.

// For more info, see: http://www.imagemagick.org/Usage/img_diagrams/cubic_survey.gif

mat4 get_hfilter_profile()
{
    float bf = 0.0;
    float cf = 0.0;

    if (HFILTER_PROFILE > 0.5) {bf = 0.0; cf = 0.5;}

    return mat4( (          -bf - 6.0*cf)/6.0,         (3.0*bf + 12.0*cf)/6.0, (-3.0*bf - 6.0*cf)/6.0,             bf/6.0,
                 (12.0 - 9.0*bf - 6.0*cf)/6.0, (-18.0 + 12.0*bf + 6.0*cf)/6.0,                    0.0, (6.0 - 2.0*bf)/6.0,
                -(12.0 - 9.0*bf - 6.0*cf)/6.0, (18.0 - 15.0*bf - 12.0*cf)/6.0,  (3.0*bf + 6.0*cf)/6.0,             bf/6.0,
                 (           bf + 6.0*cf)/6.0,                            -cf,                    0.0,                0.0);
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord*1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 FragCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec2 texture_size = vec2(SHARPNESS_HACK*global.SourceSize.x, global.SourceSize.y);

    vec2 dx = vec2(1.0/texture_size.x, 0.0);

    vec2 WarpedTexCoord = vTexCoord.xy;

    WarpedTexCoord = (CURVATURE > 0.5) ? Warp(WarpedTexCoord) : WarpedTexCoord;

    vec2 pix_coord = WarpedTexCoord.xy*texture_size + vec2(-0.5, 0.0);

    vec2 tc = (floor(pix_coord) + vec2(0.5,0.5))/texture_size;

    vec2 fp = fract(pix_coord);

    vec3 c10 = texture(Source, tc     - dx).xyz;
    vec3 c11 = texture(Source, tc         ).xyz;
    vec3 c12 = texture(Source, tc     + dx).xyz;
    vec3 c13 = texture(Source, tc + 2.0*dx).xyz;

    mat4x3 color_matrix = mat4x3(c10, c11, c12, c13);

    mat4 invX    = get_hfilter_profile();
    vec4 lobes   = vec4(fp.x*fp.x*fp.x, fp.x*fp.x, fp.x, 1.0);
    vec4 invX_Px = lobes * invX;
    vec3 color   = clamp(color_matrix * invX_Px, 0.0, 1.0);

    // Anti-ringing
    if (CRT_ANTI_RINGING > 0.5)
    {
        vec3 aux = color;
        vec3 min_sample = min(min(c10, c11), min(c12, c13));
        vec3 max_sample = max(max(c10, c11), max(c12, c13));
        color = clamp(color, min_sample, max_sample);
        color = mix(aux, color, step(0.0, (c10-c11)*(c12-c13)));
    }

    FragColor = vec4(color, 1.0);
}
