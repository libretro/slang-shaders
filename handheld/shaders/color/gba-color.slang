#version 450

/*
   Shader Modified: Pokefan531
   Color Mangler
   Author: hunterk
   Optimized by: crashGG
   License: Public domain
*/
// Shader that replicates the LCD Colorspace from Gameboy Advance --

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

const mat4 GBA_sRGB = mat4(
	0.905, 0.10,  0.1575, 0.0,
	0.195, 0.65,  0.1425, 0.0,
	-0.10, 0.25,  0.70,   0.0,
	0.0,   0.0,   0.0,    0.91
); 

const mat4 GBA_DCI = mat4(
	0.76,  0.125,  0.16,  0.0,
	0.27,  0.6375, 0.18,  0.0,
	-0.03, 0.2375, 0.66,  0.0,
	0.0,   0.0,    0.0,   0.97
); 

const mat4 GBA_Rec2020 = mat4(
	0.61,  0.155, 0.16,   0.0,
	0.345, 0.615, 0.1875, 0.0,
	0.045, 0.23,  0.6525, 0.0,
	0.0,   0.0,   0.0,    1.0
); 

const float sRGB_lum = GBA_sRGB[3].w;
const float DCI_lum = GBA_DCI[3].w;
const float Rec2020_lum = GBA_Rec2020[3].w;


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

    if (color_mode == 1) screen = mat3(GBA_sRGB) * screen * sRGB_lum;
    else if (color_mode == 2) screen = mat3(GBA_DCI) * screen * DCI_lum;
    else if (color_mode == 3) screen = mat3(GBA_Rec2020) * screen * Rec2020_lum;

	screen = clamp(screen, 0.0, 1.0);

	// Merge screen darkening into the final gamma encoding step
	float final_gamma = params.darken_screen * INV_GAMMA_SQ + INV_GAMMA;

	screen = pow(screen, vec3(final_gamma));

    FragColor = vec4(screen, 1.0);
}
