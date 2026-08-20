#version 450

/*
   Shader Modified: Pokefan531
   Color Mangler
   Author: hunterk
   Optimized by: crashGG
   License: Public domain
*/
// Shader that replicates the LCD Colorspace from a Nintendo DS Lite --

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

const mat4 DSL_sRGB = mat4(
	0.93, 0.025, 0.008, 0.0,
	0.14, 0.90, -0.03, 0.0,
	-0.07, 0.075, 1.022, 0.0,
	0.0,  0.0,  0.0,  0.935
); 

const mat4 DSL_DCI = mat4(
	0.76, 0.055, 0.0225, 0.0,
	0.27, 0.875, 0.0225, 0.0,
	-0.03, 0.07, 0.955, 0.0,
	0.0,   0.0,   0.0,   0.97
); 

const mat4 DSL_Rec2020 = mat4(
	0.585, 0.09, 0.0225, 0.0,
	0.3725, 0.825, 0.035, 0.0,
	0.0425, 0.085, 0.9425, 0.0,
	0.0,   0.0,   0.0,   1.0
); 

const float sRGB_lum = DSL_sRGB[3].w;
const float DCI_lum = DSL_DCI[3].w;
const float Rec2020_lum = DSL_Rec2020[3].w;


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

    if (color_mode == 1) screen = mat3(DSL_sRGB) * screen * sRGB_lum;
    else if (color_mode == 2) screen = mat3(DSL_DCI) * screen * DCI_lum;
    else if (color_mode == 3) screen = mat3(DSL_Rec2020) * screen * Rec2020_lum;

	screen = clamp(screen, 0.0, 1.0);

	// Merge screen darkening into the final gamma encoding step
	float final_gamma = params.darken_screen * INV_GAMMA_SQ + INV_GAMMA;

	screen = pow(screen, vec3(final_gamma));

    FragColor = vec4(screen, 1.0);
}
