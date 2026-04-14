#version 450

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
	vec4 artcnn_yuvSize;
	vec4 OutputSize;
	uint FrameCount;
	float JINC2_WINDOW_SINC;
	float JINC2_SINC;
	float JINC2_AR_STRENGTH;
} params;

#pragma parameter JINC2_WINDOW_SINC "Window Sinc Param" 0.44 0.0 1.0 0.01
#define JINC2_WINDOW_SINC params.JINC2_WINDOW_SINC
#pragma parameter JINC2_SINC "Sinc Param" 0.82 0.0 1.0 0.01
#define JINC2_SINC params.JINC2_SINC
#pragma parameter JINC2_AR_STRENGTH "Anti-ringing Strength" 0.5 0.0 1.0 0.1
#define JINC2_AR_STRENGTH params.JINC2_AR_STRENGTH

#include "artcnn-jinc-math.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * vec2(1.0001);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D artcnn_yuv;

void main()
{
      vec3 color;
      mat4x4 weights;

      vec2 dx = vec2(1.0, 0.0);
      vec2 dy = vec2(0.0, 1.0);
	  
      vec2 pc = vTexCoord * params.artcnn_yuvSize.xy;

      vec2 tc = (floor(pc - vec2(0.5, 0.5)) + vec2(0.5, 0.5));
     
      weights[0] = resampler(vec4(d(pc, tc    -dx    -dy), d(pc, tc           -dy), d(pc, tc    +dx    -dy), d(pc, tc+2.0*dx    -dy)));
      weights[1] = resampler(vec4(d(pc, tc    -dx       ), d(pc, tc              ), d(pc, tc    +dx       ), d(pc, tc+2.0*dx       )));
      weights[2] = resampler(vec4(d(pc, tc    -dx    +dy), d(pc, tc           +dy), d(pc, tc    +dx    +dy), d(pc, tc+2.0*dx    +dy)));
      weights[3] = resampler(vec4(d(pc, tc    -dx+2.0*dy), d(pc, tc       +2.0*dy), d(pc, tc    +dx+2.0*dy), d(pc, tc+2.0*dx+2.0*dy)));

      dx = dx * params.artcnn_yuvSize.zw;
      dy = dy * params.artcnn_yuvSize.zw;
      tc = tc * params.artcnn_yuvSize.zw;
	 
     // reading the texels
     
      vec3 c00 = texture(artcnn_yuv, tc    -dx    -dy).xyz;
      vec3 c10 = texture(artcnn_yuv, tc           -dy).xyz;
      vec3 c20 = texture(artcnn_yuv, tc    +dx    -dy).xyz;
      vec3 c30 = texture(artcnn_yuv, tc+2.0*dx    -dy).xyz;
      vec3 c01 = texture(artcnn_yuv, tc    -dx       ).xyz;
      vec3 c11 = texture(artcnn_yuv, tc              ).xyz;
      vec3 c21 = texture(artcnn_yuv, tc    +dx       ).xyz;
      vec3 c31 = texture(artcnn_yuv, tc+2.0*dx       ).xyz;
      vec3 c02 = texture(artcnn_yuv, tc    -dx    +dy).xyz;
      vec3 c12 = texture(artcnn_yuv, tc           +dy).xyz;
      vec3 c22 = texture(artcnn_yuv, tc    +dx    +dy).xyz;
      vec3 c32 = texture(artcnn_yuv, tc+2.0*dx    +dy).xyz;
      vec3 c03 = texture(artcnn_yuv, tc    -dx+2.0*dy).xyz;
      vec3 c13 = texture(artcnn_yuv, tc       +2.0*dy).xyz;
      vec3 c23 = texture(artcnn_yuv, tc    +dx+2.0*dy).xyz;
      vec3 c33 = texture(artcnn_yuv, tc+2.0*dx+2.0*dy).xyz;

      //  Get min/max samples
      vec3 min_sample = min4(c11, c21, c12, c22);
      vec3 max_sample = max4(c11, c21, c12, c22);

      color = mat4x3(c00, c10, c20, c30) * weights[0];
      color+= mat4x3(c01, c11, c21, c31) * weights[1];
      color+= mat4x3(c02, c12, c22, c32) * weights[2];
      color+= mat4x3(c03, c13, c23, c33) * weights[3];
      color = color/(dot(weights * vec4(1.0), vec4(1.0)));

      // Anti-ringing
      vec3 aux = color;
      color = clamp(color, min_sample, max_sample);

      color = mix(aux, color, JINC2_AR_STRENGTH);
 
      // final sum and weight normalization
   FragColor = vec4(color, 1.0);
}
