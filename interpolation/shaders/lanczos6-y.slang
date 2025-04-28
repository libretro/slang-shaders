#version 450

/*
   Lanczos6 - passY 

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
	float LANCZOS6_ANTI_RINGING;
} params;

#pragma parameter LANCZOS6_ANTI_RINGING "Lanczos6 Anti-Ringing [ OFF | ON ]" 1.0 0.0 1.0 1.0

#define LANCZOS6_ANTI_RINGING params.LANCZOS6_ANTI_RINGING

#define AR_STRENGTH 1.0

#define FIX(c) (max(abs(c), 1e-5))

const float PI     = 3.1415926535897932384626433832795;
const float radius = 6.0;

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
   vec4 Sample = FIX(2.0 * PI * vec4(x - 1.5, x - 0.5, x + 0.5, x + 1.5));

   // Lanczos3. Note: we normalize outside this function, so no point in multiplying by radius.
   return sin(Sample) * sin(Sample / radius) / (Sample * Sample);
}


vec3 weight3(float x)
{
   // Looks like "sample" is a reserved word in slang.
   vec3 Sample = FIX(2.0 * PI * vec3(x - 1.5, x - 0.5, x + 0.5));

   // Lanczos3. Note: we normalize outside this function, so no point in multiplying by radius.
   return sin(Sample) * sin(Sample / radius) / (Sample * Sample);
}

void main()
{
    vec2 ps = params.SourceSize.zw;
    vec2 pos = vTexCoord.xy + ps * vec2(0.0, 0.5);
    vec2 fp = fract(pos / ps);

    vec2 xystart = (-5.5 - fp) * ps + pos;

    float xpos = xystart.x  + ps.x * 6.0;

    vec3 C0 = texture(Source, vec2(xpos, xystart.y             )).rgb;
    vec3 C1 = texture(Source, vec2(xpos, xystart.y + ps.y      )).rgb;
    vec3 C2 = texture(Source, vec2(xpos, xystart.y + ps.y * 2.0)).rgb;
    vec3 C3 = texture(Source, vec2(xpos, xystart.y + ps.y * 3.0)).rgb;
    vec3 C4 = texture(Source, vec2(xpos, xystart.y + ps.y * 4.0)).rgb;
    vec3 C5 = texture(Source, vec2(xpos, xystart.y + ps.y * 5.0)).rgb; 
    vec3 C6 = texture(Source, vec2(xpos, xystart.y + ps.y * 6.0)).rgb; 
    vec3 C7 = texture(Source, vec2(xpos, xystart.y + ps.y * 7.0)).rgb; 
    vec3 C8 = texture(Source, vec2(xpos, xystart.y + ps.y * 8.0)).rgb; 
    vec3 C9 = texture(Source, vec2(xpos, xystart.y + ps.y * 9.0)).rgb; 
    vec3 CA = texture(Source, vec2(xpos, xystart.y + ps.y *10.0)).rgb; 
    vec3 CB = texture(Source, vec2(xpos, xystart.y + ps.y *11.0)).rgb; 

    vec3 w1 = weight3(-1.0 - fp.y * 0.5);
    vec3 w2 = weight3(-0.5 - fp.y * 0.5);
    vec3 w3 = weight3( 2.0 - fp.y * 0.5);
    vec3 w4 = weight3( 2.5 - fp.y * 0.5);

    vec3 color = mat3( C0, C2, C4 ) * w1 + 
                 mat3( C1, C3, C5 ) * w2 + 
                 mat3( C6, C8, CA ) * w3 +
                 mat3( C7, C9, CB ) * w4;

    color /= dot(w1+w2+w3+w4, vec3(1.0)); // Normalization

    // Anti-ringing
    if (LANCZOS6_ANTI_RINGING == 1.0)
    {
        vec3 aux = color;
        vec3 min_sample = min(min(C4, C5), min(C6, C7));
        vec3 max_sample = max(max(C4, C5), max(C6, C7));
        color = clamp(color, min_sample, max_sample);
        color = mix(aux, color, step(0.0, (C4-C5)*(C6-C7)));
    }

    FragColor = vec4(color, 1.0);
}
