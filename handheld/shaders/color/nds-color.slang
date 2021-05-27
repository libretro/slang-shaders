#version 450

/*
   Shader Modified: Pokefan531
   Color Mangler
   Author: hunterk
   License: Public domain
*/
// Shader that replicates the LCD dynamics from a Nintendo DS Phat --

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	float mode, white_toggle;
} global;

#pragma parameter mode "Color Profile (1=sRGB, 2=DCI, 3=Rec2020)" 1.0 1.0 3.0 1.0
int color_mode = int(global.mode);

#pragma parameter white_toggle "Toggle White Balance" 0.0 0.0 1.0 1.0
bool white = bool(global.white_toggle);

#define target_gamma 2.2
#define display_gamma 2.2

/*
We'll define our color weights in this pattern:
	r,   rg,  rb,  0.0,  //red channel
	gr,  g,   gb,  0.0,  //green channel
	br,  bg,  b,   0.0,  //blue channel
	blr, blg, blb, lum   //alpha channel; we'll hide luma at the end, too
*/

const mat4 NDS_Rec2020 = mat4(
	0.58, 0.13,  0.09, 0.0,
	0.38, 0.645, 0.20, 0.0,
	0.04, 0.225, 0.71, 0.0,
	0.0,  0.0,   0.0,  1.0
); 

const mat4 NDS_Rec2020_white = mat4(
	0.535, 0.12,  0.09, 0.0,
	0.345, 0.585, 0.20, 0.0,
	0.04,  0.215, 0.71, 0.0,
	0.0,   0.0,   0.0,  1.0
); 

const mat4 NDS_DCI = mat4(
	0.745, 0.10,  0.09,  0.0,
	0.315, 0.665, 0.195, 0.0,
	-0.06, 0.235, 0.715, 0.0,
	0.0,   0.0,   0.0,   0.95
); 

const mat4 NDS_DCI_white = mat4(
	0.685, 0.095, 0.09,  0.0,
	0.29,  0.605, 0.19,  0.0,
	-0.06, 0.215, 0.715, 0.0,
	0.0,   0.0,   0.0,   1.0
); 

const mat4 NDS_sRGB = mat4(
	0.815, 0.07, 0.075, 0.0,
	0.215, 0.62, 0.155, 0.0,
	-0.12, 0.22, 0.77,  0.0,
	0.0,   0.0,  0.0,   0.89
); 

const mat4 NDS_sRGB_white = mat4(
	0.815, 0.07, 0.075, 0.0,
	0.215, 0.62, 0.155, 0.0,
	-0.12, 0.22, 0.77,  0.0,
	0.0,   0.0,  0.0,   0.97
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

	if (color_mode == 3) profile = (!white) ? NDS_Rec2020 : NDS_Rec2020_white;
	else if (color_mode == 2) profile = (!white) ? NDS_DCI : NDS_DCI_white;
	else if (color_mode == 1) profile = (!white) ? NDS_sRGB : NDS_sRGB_white;
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
