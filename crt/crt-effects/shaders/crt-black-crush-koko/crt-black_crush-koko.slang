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
	float ADPT_BLK_RANGE;
} params;


layout(std140, set = 0, binding = 0) uniform UBO {
	mat4 MVP;
} global;


#pragma parameter ADPT_BLK_RANGE   "CRT Black crush (<0: Darker gamma, >0: Black Crush)"  0.5 -2.0 2.0 0.1

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
   float t = (60.0 - min(get_fps(),90.0) ) / 30.0;
   vTsmooth = mix(tsmooth_at_60, tsmooth_at_30, t);
}



#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vTsmooth;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D black_crush_passFeedback;


vec3 scale_to_range(vec3 x, float dmin, float dmax) {
    return ( (dmax-dmin) * x ) + dmin;  //Scales 0..1 range to a..b range
}


vec3 adaptive_black(vec3 c, float lum_in, float range, bool dark_crush) {
	if (dark_crush) {
		//Black crush
		return clamp(scale_to_range(c, -lum_in*range,1.0), 0,1);
	} else {
		//Increase gamma
		return pow(c, vec3(1+lum_in*2.0*range));
	}
}


void main() {
	float lum_current = dot ( textureLod(Source, vec2(0.5), 20.0).rgb, vec3(0.3333) );
	float lum_past = texture(black_crush_passFeedback, vec2(0.5)).a ;
	if (params.FrameCount == 0.0) lum_past = lum_current;
	float lum_avg = mix(lum_current, lum_past, vTsmooth);
	vec3 c = texture(Source, vTexCoord).rgb;
	c = adaptive_black(c, lum_avg, abs(params.ADPT_BLK_RANGE), params.ADPT_BLK_RANGE > 0.0);
	FragColor = vec4(c,lum_avg);
}

