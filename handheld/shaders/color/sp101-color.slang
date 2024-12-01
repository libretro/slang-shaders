#version 450

/*
   Shader Modified: Pokefan531
   Color Mangler
   Author: hunterk
   License: Public domain
*/
// Shader that replicates the LCD Colorspace from a Gameboy SP 101 (backlit version) --

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	float mode;
} global;

#pragma parameter mode "Color Profile (1=sRGB, 2=DCI, 3=Rec2020)" 1.0 1.0 3.0 1.0
int color_mode = int(global.mode);

#define target_gamma 2.2
#define display_gamma 2.2

/*
We'll define our color weights in this pattern:
	r,   rg,  rb,  0.0,  //red channel
	gr,  g,   gb,  0.0,  //green channel
	br,  bg,  b,   0.0,  //blue channel
	blr, blg, blb, lum   //alpha channel; we'll hide lum at the end, too
*/

const mat4 SP1_sRGB = mat4(
	0.96, 0.0325, 0.001, 0.0,  //red channel
	0.11, 0.89, -0.03, 0.0,  //green channel
	-0.07, 0.0775, 1.029, 0.0,  //blue channel
	0.0,  0.0,  0.0,  0.935   //alpha channel
); 

const mat4 SP1_DCI = mat4(
	0.805, 0.0675, 0.017, 0.0,  //red channel
	0.24, 0.86, 0.02, 0.0,  //green channel
	-0.045, 0.0725, 0.963, 0.0,  //blue channel
	0.0,   0.0,   0.0,   0.955  //alpha channel
); 

const mat4 SP1_Rec2020 = mat4(
	0.625, 0.10, 0.015, 0.0,  //red channel
	0.35, 0.82, 0.0325, 0.0,  //green channel
	0.025, 0.08, 0.9525, 0.0,  //blue channel
	0.0,   0.0,   0.0,   1.0  //alpha channel
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

	if (color_mode == 1) profile = SP1_sRGB;
	else if (color_mode == 2) profile = SP1_DCI;
	else if (color_mode == 3) profile = SP1_Rec2020;
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
	vec4 screen = pow(texture(Source, vTexCoord), vec4(target_gamma)).rgba;

	screen = clamp(screen * lum, 0.0, 1.0);
	screen = profile * screen;
	FragColor = pow(screen, vec4(1.0 / display_gamma));
}