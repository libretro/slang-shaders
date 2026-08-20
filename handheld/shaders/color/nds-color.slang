#version 450

/*
   Shader Modified: Pokefan531
   Color Mangler
   Author: hunterk
   Optimized by: crashGG
   License: Public domain
*/
// Shader that replicates the LCD Colorspace from a Nintendo DS Phat --

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
	float profile;
} params;

#pragma parameter profile "Color Profile (1=sRGB, 2=DCI, 3=Rec2020)" 1.0 1.0 3.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

const float GAMMA = 2.2;
const float INV_GAMMA = 1.0 / GAMMA;


/*  define color weights in pattern:
      r2R   r2G   r2B  -
      g2R   g2G   g2B  -
      b2R   b2G   b2B  -
       -     -     -  lum   //global lum
*/

const mat4 NDS_sRGB = mat4(
	0.835,  0.10,   0.105, 0.0,
	0.27,   0.6375, 0.175, 0.0,
	-0.105, 0.2625, 0.72,  0.0,
	0.0,    0.0,    0.0,   0.905
); 

const mat4 NDS_DCI = mat4(
	0.70,  0.125, 0.12, 0.0,
	0.34,  0.625, 0.20, 0.0,
	-0.04, 0.25,  0.68, 0.0,
	0.0,   0.0,   0.0,  0.96
); 

const mat4 NDS_Rec2020 = mat4(
	0.555, 0.1475, 0.1175, 0.0,
	0.39,  0.6075, 0.2075, 0.0,
	0.055, 0.245,  0.675,  0.0,
	0.0,   0.0,    0.0,    1.0
); 

const float sRGB_lum = NDS_sRGB[3].w;
const float DCI_lum = NDS_DCI[3].w;
const float Rec2020_lum = NDS_Rec2020[3].w;


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

    if (color_mode == 1) screen = mat3(NDS_sRGB) * screen * sRGB_lum;
    else if (color_mode == 2) screen = mat3(NDS_DCI) * screen * DCI_lum;
    else if (color_mode == 3) screen = mat3(NDS_Rec2020) * screen * Rec2020_lum;

	screen = clamp(screen, 0.0, 1.0);

	float final_gamma = INV_GAMMA;

	screen = pow(screen, vec3(final_gamma));

    FragColor = vec4(screen, 1.0);
}
