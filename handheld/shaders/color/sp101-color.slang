#version 450

/*
   Shader Modified: Pokefan531
   Color Mangler
   Author: hunterk
   Optimized by: crashGG
   License: Public domain
*/
// Shader that replicates the LCD Colorspace from a Gameboy SP 101 (backlit version) --

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
	float profile;
	float darken_screen;
} params;

#pragma parameter profile "Color Profile (1=sRGB, 2=DCI, 3=Rec2020)" 1.0 1.0 3.0 1.0
#pragma parameter darken_screen "Screen Darkness" 0.0 0.0 2.2 0.1

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

const float GAMMA = 2.2;
const float INV_GAMMA = 1.0 / GAMMA;
const float INV_GAMMA_SQ = 1.0 / (GAMMA * GAMMA);

/*  define color weights in pattern:
      r2R   r2G   r2B  -
      g2R   g2G   g2B  -
      b2R   b2G   b2B  -
       -     -     -  lum   //global lum
*/

const mat4 SP1_sRGB = mat4(
	0.96,   0.0325, 0.001, 0.0,
	0.11,   0.89,   -0.03, 0.0,
	-0.07,  0.0775, 1.029, 0.0,
	0.0,    0.0,    0.0,   0.935
); 

const mat4 SP1_DCI = mat4(
	0.805,  0.0675, 0.017, 0.0,
	0.24,   0.86,   0.02,  0.0,
	-0.045, 0.0725, 0.963, 0.0,
	0.0,    0.0,    0.0,   0.955
); 

const mat4 SP1_Rec2020 = mat4(
	0.625, 0.10, 0.015,  0.0,
	0.35,  0.82, 0.0325, 0.0,
	0.025, 0.08, 0.9525, 0.0,
	0.0,   0.0,  0.0,    1.0
); 

const float sRGB_lum = SP1_sRGB[3].w;
const float DCI_lum = SP1_DCI[3].w;
const float Rec2020_lum = SP1_Rec2020[3].w;


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
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {

    vec3 texel = texture(Source, vTexCoord).rgb;

    vec3 screen = pow(texel, vec3(GAMMA));

    int color_mode = int(round(params.profile));

    if (color_mode == 1) screen = mat3(SP1_sRGB) * screen * sRGB_lum;
    else if (color_mode == 2) screen = mat3(SP1_DCI) * screen * DCI_lum;
    else if (color_mode == 3) screen = mat3(SP1_Rec2020) * screen * Rec2020_lum;

	screen = clamp(screen, 0.0, 1.0);

	// Merge screen darkening into the final gamma encoding step
	float final_gamma = params.darken_screen * INV_GAMMA_SQ + INV_GAMMA;

	screen = pow(screen, vec3(final_gamma));

    FragColor = vec4(screen, 1.0);
}
