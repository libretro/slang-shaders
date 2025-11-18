#version 450


/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////
//
//  crt-black_crush-koko
//  Copyright (C) 2024 Antonio Orefice <kokoko3k@gmail.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or any later version.
//
////////////////////////////////////////////////////////////////////////////////


layout(push_constant) uniform Push {
	uint FrameCount;
	float OriginalFPS;
} params;


layout(std140, set = 0, binding = 0) uniform UBO {
	mat4 MVP;
} global;


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float vTsmooth;

float get_fps() {
	//Can't do anything without frametime uniforms.
	#ifndef _HAS_FRAMETIME_UNIFORMS
		return 60;
	#else
		return (params.OriginalFPS);
	#endif
}

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   vTsmooth = 0.8;
   const float tsmooth_at_60 = 0.8;
   const float tsmooth_at_30 = 0.65;
   float t = (60.0 - get_fps()) / 30.0;
   vTsmooth = mix(tsmooth_at_60, tsmooth_at_30, t);
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vTsmooth;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D black_crush_avglum_passFeedback;


void main() {
	vec3 c_current = texture(Source, vTexCoord).rgb;
	float lum_past = texture(black_crush_avglum_passFeedback, vTexCoord).a;
	float lum_current = (c_current.r+c_current.g+c_current.b)/3.0;
		
	if (params.FrameCount == 0.0) lum_past = lum_current;
	float lum_avg = mix(lum_current, lum_past, vTsmooth);
	FragColor = vec4(c_current,lum_avg);
}
