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


void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D black_crush_avglum_pass;


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
	float lum = textureLod(black_crush_avglum_pass, vec2(0.5), 20.0).a;
	vec3 c = texture(black_crush_avglum_pass, vTexCoord).rgb;
	c = adaptive_black(c, lum, abs(params.ADPT_BLK_RANGE), params.ADPT_BLK_RANGE > 0.0);
	FragColor.rgb = c;
}

