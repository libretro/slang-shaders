#version 450

/*

  Deblur-fast shader - Hyllian 2025. 

  Based on awesome guest's deblur (license below) shader.

*/

/*
   Deblur Shader
   
   Copyright (C) 2005 - 2019 guest(r) - guest.r@gmail.com

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

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OFFSET_F, DEBLUR_F, SMART_F;
} params;

#pragma parameter OFFSET_F "Deblur Offset    " 0.5 0.0  1.0 0.05 
#pragma parameter DEBLUR_F "Deblur Strength  " 7.0 1.0 10.0 0.5 
#pragma parameter SMART_F  "Smart Deblur     " 1.0 0.0  1.0 0.1 

#define OFFSET params.OFFSET_F
#define DEBLUR params.DEBLUR_F
#define SMART  params.SMART_F


const vec3 Y   = vec3(0.2627, 0.6780, 0.0593);
const vec3 dtt = vec3(0.0001, 0.0001, 0.0001); 


layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 t1;
layout(location = 2) out vec4 t2;
layout(location = 3) out vec4 t3;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord   = TexCoord * 1.0001;

    vec2 d = OFFSET * params.OutputSize.xy * params.OriginalSize.zw * params.SourceSize.zw;

    t1 = vTexCoord.xxxy + vec4( -d.x, 0.0, d.x, -d.y ); //  A  B  C
    t2 = vTexCoord.xxxy + vec4( -d.x, 0.0, d.x,  0.0 ); //  D  E  F
    t3 = vTexCoord.xxxy + vec4( -d.x, 0.0, d.x,  d.y ); //  G  H  I
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 t1;
layout(location = 2) in vec4 t2;
layout(location = 3) in vec4 t3;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


vec3 weight(vec3 c1, vec3 c2)
{
    return vec3(clamp(DEBLUR*max(dot(c1, Y), dot(c2, Y)), 2.0-SMART, 10.0));
} 

void main()
{
    vec3 A = texture(Source, t1.xw).xyz;  
    vec3 B = texture(Source, t1.yw).xyz;  
    vec3 C = texture(Source, t1.zw).xyz;  
    vec3 D = texture(Source, t2.xw).xyz;  
    vec3 E = texture(Source, t2.yw).xyz;  
    vec3 F = texture(Source, t2.zw).xyz;  
    vec3 G = texture(Source, t3.xw).xyz;  
    vec3 H = texture(Source, t3.yw).xyz;  
    vec3 I = texture(Source, t3.zw).xyz;  

    vec3 mn1 = min(A, min(B, C));
    vec3 mn2 = min(D, min(E, F));
    vec3 mn3 = min(G, min(H, I));
    vec3 mx1 = max(A, max(B, C));
    vec3 mx2 = max(D, max(E, F));
    vec3 mx3 = max(G, max(H, I));

    vec3 Cmin = min(mn1, min(mn2, mn3));
    vec3 Cmax = max(mx1, max(mx2, mx3));

    vec3 Dmin = abs(E - Cmin) + dtt;
    vec3 Dmax = abs(E - Cmax) + dtt;

    vec3 vexp = weight(Dmin, Dmax);

    Dmin = pow(Dmin, vexp);
    Dmax = pow(Dmax, vexp);

    vec3 color = ( Dmin*Cmax + Dmax*Cmin )/( Dmin + Dmax );

    FragColor = vec4(color, 1.0);
}
