#version 450

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
   vTexCoord = TexCoord;
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
   
   vec3 cscrn = pow(screen.rgb, vec3(gamma));
   vec3 cphos = pow(phosphor.rgb, vec3(gamma));
   
   // encode the upper 2 bits of the time elapsed in the lower 2 bits of b
   float t = 255.0*phosphor.a + fract(phosphor.b*255.0/4.0)*1024.0;

   cphos *= vec3( phosphor_amplitude * pow(t,-phosphor_power) );
   
   vec3 col = pow(cscrn + cphos, vec3(1.0/gamma));
   
   FragColor = vec4(col, 1.0);
}
