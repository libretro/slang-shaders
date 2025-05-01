#version 450

/*
    Jinc2-Bilateral shader - Hyllian 2025

    This is a modified jinc2 shader to perform bilateral filtering guided
    by another filter output, which will be used as the range domain
    (high frequencies), while jinc2 is performed in the space domain.
*/


/*
   Hyllian's jinc windowed-jinc 2-lobe with anti-ringing Shader
   
   Copyright (C) 2011-2014 Hyllian/Jararaca - sergiogdb@gmail.com

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

*/

      /*
         This is an approximation of Jinc(x)*Jinc(x*r1/r2) for x < 2.5,
         where r1 and r2 are the first two zeros of jinc function.
         For a jinc 2-lobe best approximation, use A=0.5 and B=0.825.
      */  

// A=0.5, B=0.825 is the best jinc approximation for x<2.5. if B=1.0, it's a lanczos filter.
// Increase A to get more blur. Decrease it to get a sharper picture. 
// B = 0.825 to get rid of dithering. Increase B to get a fine sharpness, though dithering returns.

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float J2B_WA_BILATERAL;
    float J2B_WB_BILATERAL;
    float J2B_AR_STR;
    float J2B_STR;
} params;

#pragma parameter J2B_NONONO        "JINC2-BILATERAL:"         0.0  0.0 1.0 1.0
#pragma parameter J2B_WA_BILATERAL  "   Window A Param"        0.50 0.0 1.0 0.01
#pragma parameter J2B_WB_BILATERAL  "   Window B Param"        0.88 0.0 1.0 0.01
#pragma parameter J2B_AR_STR        "   Anti-Ringing Strength" 1.0  0.0 1.0 0.05
#pragma parameter J2B_STR           "   Bilateral Strength"    1.0  0.1 1.5 0.05

#define J2B_WA_BILATERAL     params.J2B_WA_BILATERAL
#define J2B_WB_BILATERAL        params.J2B_WB_BILATERAL
#define J2B_AR_STR params.J2B_AR_STR
#define J2B_STR             params.J2B_STR

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#define halfpi  1.5707963267948966192313216916398
#define pi      3.1415926535897932384626433832795
#define wa      (J2B_WA_BILATERAL*pi)
#define wb      (J2B_WB_BILATERAL*pi)

const vec3 Y   = vec3(.2126, .7152, .0722);
const vec3 dt  = vec3(.00001, .00001, .00001);

// Calculates the distance between two points
float d(vec2 pt1, vec2 pt2)
{
  vec2 v = pt2 - pt1;
  return sqrt(dot(v,v)) + dt.x;
}

float luma(vec3 color)
{
  return dot(color, Y);
}

/* Some window functions. Easy to add more. Radius is 2 pixels only. */
float sinc(float x)              { return sin(pi*x)/(pi*x); }
float hann_window(float x)       { return 0.5 * ( 1.0 - cos( 0.5 * pi * ( x + 2.0 ) ) ); }
float blackman_window(float x)   { return 0.42 - 0.5*cos(0.5*pi*(x+2.0)) + 0.08*cos(pi*(x+2.0)); }
float nuttall_window(float x)    { return 0.35875 - 0.48829*cos(0.5*pi*(x+2.0)) + 0.14128*cos(pi*(x+2.0)) + 0.01168*cos(1.5*pi*(x+2.0)); }

/* Some windowed filters. Easy to add more. */
float lanczos(float x, float a)  { return sinc(x) * sinc(x / a); }
float blackman(float x, float a) { return sinc(x) * blackman_window(x); }
float hann(float x, float a)     { return sinc(x) * hann_window(x); }
float nuttall(float x, float a)  { return sinc(x) * nuttall_window(x); }

float I(vec3 A, vec3 B)
{
    return lanczos( luma(abs(A-B)) * J2B_STR + dt.x, 2.0 );
}

vec3 min4(vec3 a, vec3 b, vec3 c, vec3 d)
{
    return min(a, min(b, min(c, d)));
}

vec3 max4(vec3 a, vec3 b, vec3 c, vec3 d)
{
    return max(a, max(b, max(c, d)));
}

vec4 resampler(vec4 x)
{
    return sin(x*wa)*sin(x*wb)/(x*x);
}


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * vec2(1.0000);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D XbrSource;
layout(set = 0, binding = 3) uniform sampler2D Source;

void main()
{
    vec3 color;
    mat4x4 weights;

    vec2 dx = vec2(1.0, 0.0);
    vec2 dy = vec2(0.0, 1.0);

    vec2 pc = vTexCoord*params.OriginalSize.xy;

    vec2 tc = (floor(pc-vec2(0.5,0.5))+vec2(0.5,0.5));
     
    // Calculating Jinc2-Bilateral weights (space domain)
    weights[0] = resampler(vec4(d(pc, tc -dx    -dy), d(pc, tc     -dy), d(pc, tc +dx    -dy), d(pc, tc+2.0*dx    -dy)));
    weights[1] = resampler(vec4(d(pc, tc -dx       ), d(pc, tc        ), d(pc, tc +dx       ), d(pc, tc+2.0*dx       )));
    weights[2] = resampler(vec4(d(pc, tc -dx    +dy), d(pc, tc     +dy), d(pc, tc +dx    +dy), d(pc, tc+2.0*dx    +dy)));
    weights[3] = resampler(vec4(d(pc, tc -dx+2.0*dy), d(pc, tc +2.0*dy), d(pc, tc +dx+2.0*dy), d(pc, tc+2.0*dx+2.0*dy)));

    dx = dx * params.OriginalSize.zw;
    dy = dy * params.OriginalSize.zw;
    tc = tc * params.OriginalSize.zw;
     
    // reading the texels from original source
    vec3 c00 = texture(XbrSource, tc    -dx    -dy).xyz;
    vec3 c10 = texture(XbrSource, tc           -dy).xyz;
    vec3 c20 = texture(XbrSource, tc    +dx    -dy).xyz;
    vec3 c30 = texture(XbrSource, tc+2.0*dx    -dy).xyz;
    vec3 c01 = texture(XbrSource, tc    -dx       ).xyz;
    vec3 c11 = texture(XbrSource, tc              ).xyz;
    vec3 c21 = texture(XbrSource, tc    +dx       ).xyz;
    vec3 c31 = texture(XbrSource, tc+2.0*dx       ).xyz;
    vec3 c02 = texture(XbrSource, tc    -dx    +dy).xyz;
    vec3 c12 = texture(XbrSource, tc           +dy).xyz;
    vec3 c22 = texture(XbrSource, tc    +dx    +dy).xyz;
    vec3 c32 = texture(XbrSource, tc+2.0*dx    +dy).xyz;
    vec3 c03 = texture(XbrSource, tc    -dx+2.0*dy).xyz;
    vec3 c13 = texture(XbrSource, tc       +2.0*dy).xyz;
    vec3 c23 = texture(XbrSource, tc    +dx+2.0*dy).xyz;
    vec3 c33 = texture(XbrSource, tc+2.0*dx+2.0*dy).xyz;

    // reading hires color reference from (guide) source
    vec3 p00 = texture(Source, vTexCoord).xyz;

    // Calculating Jinc2-Bilateral weights (range domain)
    mat4 I_weights = mat4(vec4(I(p00, c00), I(p00, c10), I(p00, c20), I(p00, c30)),
                          vec4(I(p00, c01), I(p00, c11), I(p00, c21), I(p00, c31)),
                          vec4(I(p00, c02), I(p00, c12), I(p00, c22), I(p00, c32)),
                          vec4(I(p00, c03), I(p00, c13), I(p00, c23), I(p00, c33)) );

    weights = matrixCompMult(weights, I_weights);

    // Filtering and normalization
    color = mat4x3(c00, c10, c20, c30) * weights[0];
    color+= mat4x3(c01, c11, c21, c31) * weights[1];
    color+= mat4x3(c02, c12, c22, c32) * weights[2];
    color+= mat4x3(c03, c13, c23, c33) * weights[3];
    color = color/(dot(weights * vec4(1.0), vec4(1.0)));

    // Anti-ringing
    //  Get min/max samples
    vec3 min_sample = min4(c11, c21, c12, c22);
    vec3 max_sample = max4(c11, c21, c12, c22);
    vec3 aux = color;
    color = clamp(color, min_sample, max_sample);
    color = mix(aux, color, J2B_AR_STR);
 
    // final sum and weight normalization
    FragColor = vec4(color, 1.0);
}
