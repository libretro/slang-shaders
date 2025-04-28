#version 450

/*
   Lanczos8 - passX 

   Multipass code by Hyllian 2022.

*/


/*
   Copyright (C) 2010 Team XBMC
   http://www.xbmc.org
   Copyright (C) 2011 Stefanos A.
   http://www.opentk.com

This Program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

This Program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with XBMC; see the file COPYING.  If not, write to
the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
http://www.gnu.org/copyleft/gpl.html
*/


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float LANCZOS8_ANTI_RINGING;
} params;

#pragma parameter LANCZOS8_ANTI_RINGING "Lanczos8 Anti-Ringing [ OFF | ON ]" 1.0 0.0 1.0 1.0

#define LANCZOS8_ANTI_RINGING params.LANCZOS8_ANTI_RINGING

#define FIX(c) (max(abs(c), 1e-5))

const float PI     = 3.1415926535897932384626433832795;
const float radius = 8.0;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


vec4 weight4(float x)
{
   // Looks like "sample" is a reserved word in slang.
   vec4 Sample = FIX(2.0 * PI * vec4(x - 1.5, x - 0.5, x + 0.5,  x + 1.5));

   // Lanczos. Note: we normalize outside this function, so no point in multiplying by radius.
   return sin(Sample) * sin(Sample / radius) / (Sample * Sample);
}
	

void main()
{
    vec2 ps  = params.SourceSize.zw;
    vec2 pos = vTexCoord.xy + ps * vec2(0.5, 0.0);
    vec2 fp  = fract(pos / ps);

    vec2 xystart = (-7.5 - fp) * ps + pos;

    float ypos = xystart.y  + ps.y * 8.0;

    vec3 C0 = texture(Source, vec2(xystart.x             , ypos)).rgb;
    vec3 C1 = texture(Source, vec2(xystart.x + ps.x      , ypos)).rgb;
    vec3 C2 = texture(Source, vec2(xystart.x + ps.x * 2.0, ypos)).rgb;
    vec3 C3 = texture(Source, vec2(xystart.x + ps.x * 3.0, ypos)).rgb;
    vec3 C4 = texture(Source, vec2(xystart.x + ps.x * 4.0, ypos)).rgb;
    vec3 C5 = texture(Source, vec2(xystart.x + ps.x * 5.0, ypos)).rgb; 
    vec3 C6 = texture(Source, vec2(xystart.x + ps.x * 6.0, ypos)).rgb; 
    vec3 C7 = texture(Source, vec2(xystart.x + ps.x * 7.0, ypos)).rgb; 
    vec3 C8 = texture(Source, vec2(xystart.x + ps.x * 8.0, ypos)).rgb;
    vec3 C9 = texture(Source, vec2(xystart.x + ps.x * 9.0, ypos)).rgb;
    vec3 CA = texture(Source, vec2(xystart.x + ps.x *10.0, ypos)).rgb;
    vec3 CB = texture(Source, vec2(xystart.x + ps.x *11.0, ypos)).rgb;
    vec3 CC = texture(Source, vec2(xystart.x + ps.x *12.0, ypos)).rgb;
    vec3 CD = texture(Source, vec2(xystart.x + ps.x *13.0, ypos)).rgb;
    vec3 CE = texture(Source, vec2(xystart.x + ps.x *14.0, ypos)).rgb;
    vec3 CF = texture(Source, vec2(xystart.x + ps.x *15.0, ypos)).rgb;

    vec4 w1 = weight4(-2.0 - fp.x * 0.5);
    vec4 w2 = weight4(-1.5 - fp.x * 0.5);
    vec4 w3 = weight4( 2.0 - fp.x * 0.5);
    vec4 w4 = weight4( 2.5 - fp.x * 0.5);

    vec3 color = mat4x3( C0, C2, C4, C6 ) * w1 + 
                 mat4x3( C1, C3, C5, C7 ) * w2 + 
                 mat4x3( C8, CA, CC, CE ) * w3 + 
                 mat4x3( C9, CB, CD, CF ) * w4;

    color /= dot(w1+w2+w3+w4, vec4(1.0)); // Normalization

    // Anti-ringing
    if (LANCZOS8_ANTI_RINGING == 1.0)
    {
        vec3 aux = color;
        vec3 min_sample = min(min(C6, C7), min(C8, C9));
        vec3 max_sample = max(max(C6, C7), max(C8, C9));
        color = clamp(color, min_sample, max_sample);
        color = mix(aux, color, step(0.0, (C6-C7)*(C8-C9)));
    }

    FragColor = vec4(color, 1.0);
}
