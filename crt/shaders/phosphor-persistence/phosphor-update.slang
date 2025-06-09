#version 450
#pragma name phosphor

/*  Phosphot Persistence - code copied from crt-geom-deluxe
 *
 *  Copyright (C) 2010-2016 cgwg, Themaister and DOLLS
 *
 *  This program is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation; either version 2 of the License, or (at your option)
 *  any later version.
 */


layout(push_constant) uniform Push
{
	float phosphor_power;
	float phosphor_amplitude;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
    vec4 FinalViewportSize;
    vec4 internal1Size;
	mat4 MVP;
} global;

#pragma parameter phosphor_power "Phosphor decay power" 1.2 0.5 3.0 0.05
#pragma parameter phosphor_amplitude "Phosphor persistence amplitude" 0.04 0.0 0.2 0.01

#define phosphor_power params.phosphor_power
#define phosphor_amplitude params.phosphor_amplitude

const float gamma = 2.2;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D phosphorFeedback;

void main()
{
   vec4 screen = texture(Source, vTexCoord);
   vec4 phosphor = texture(phosphorFeedback, vTexCoord);
   
   vec3 lum = vec3(0.299,0.587,0.114);
   float bscrn = dot(pow(screen.rgb,vec3(gamma)),lum);
   float bphos = dot(pow(phosphor.rgb,vec3(gamma)),lum);
   // encode the upper 2 bits of the time elapsed in the lower 2 bits of b
   float t = 1.0 + 255.0*phosphor.a + fract(phosphor.b*255.0/4.0)*1024.0;

   bphos = ( t > 1023.0 ? 0.0 : bphos*pow(t,-phosphor_power) );

   FragColor = ( bscrn >= bphos ?
      vec4(screen.rg,floor(screen.b*255.0/4.0)*4.0/255.0,1.0/255.0)
      : vec4(phosphor.rg,
         (floor(phosphor.b*255.0/4.0)*4.0 + floor(t/256.0))/255.0,
         fract(t/256.0)*256.0/255.0 ) );
}
