#version 450

/*
   Shader Modified: Pokefan531
   Color Mangler
   Author: hunterk
   License: Public domain
*/
// Shader that replicates the LCD dynamics from a GameBoy Advance based from VBA-M and No$GBA --

layout(push_constant) uniform Push
{
   float darken_screen;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	float mode;
} global;

#pragma parameter mode "Color Mode (1=Full, 2=Slightly Cold)" 1.0 1.0 2.0 1.0
int color_mode = int(global.mode);

#pragma parameter darken_screen "Darken Screen" 1.0 0.0 1.0 0.05

#define target_gamma 1.45
#define display_gamma 1.45

/*
We'll define our color weights in this pattern:
	r,   rg,  rb,  0.0,  //red channel
	gr,  g,   gb,  0.0,  //green channel
	br,  bg,  b,   0.0,  //blue channel
	blr, blg, blb, lum   //alpha channel; we'll hide lum at the end, too
*/

const mat4 VBA_COLOR1 = mat4(
	0.73, 0.0825, 0.0825, 0.0,  //red channel
	0.27, 0.6775, 0.24, 0.0,  //green channel
	0.0, 0.24, 0.6775, 0.0,  //blue channel
	0.0,  0.0,  0.0,  1.0   //alpha channel
); 

const mat4 VBA_COLOR2 = mat4(
	0.68, 0.0825, 0.0825, 0.0,  //red channel
	0.24, 0.6775, 0.24, 0.0,  //green channel
	0.0, 0.24, 0.6775, 0.0,  //blue channel
	0.0,  0.0,  0.0,  1.0   //alpha channel
); 

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out mat4 profile;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord;

	if (color_mode == 1) profile = VBA_COLOR1;
	else if (color_mode == 2) profile = VBA_COLOR2;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in mat4 profile;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
	// bring out our stored luminance value
	float lum = profile[3].w;

	// our adjustments need to happen in linear gamma
	vec4 screen = pow(texture(Source, vTexCoord), vec4(target_gamma + params.darken_screen)).rgba;

	screen = clamp(screen * lum, 0.0, 1.0);
	screen = profile * screen;
	FragColor = pow(screen, vec4(1.0 / display_gamma));
}