#version 450

/*
   Shader Modified: Pokefan531
   Color Mangler
   Author: hunterk
   Optimized by: crashGG
   License: Public domain
*/
// Shader that replicates the Nintendo Switch Online's GBA color filter --

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
	float profile;
	float darken_screen;
} params;

#pragma parameter profile "Color Profile (1=sRGB, 2=DCI, 3=Rec2020)" 1.0 1.0 3.0 1.0
#pragma parameter darken_screen "Screen Darkness" 0.8 0.0 2.2 0.1

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

const float GAMMA = 2.2;
const float INV_GAMMA = 1.0 / GAMMA;
const float INV_GAMMA_SQ = 1.0 / (GAMMA * GAMMA);

/*  define color weights in pattern:
      r2R   r2G   r2B  -
      g2R   g2G   g2B  -
      b2R   b2G   b2B  -
       -     -     -   -   //global lum=1.0
*/

const mat3 GBA_sRGB = mat3(
    0.865, 0.0575, 0.0575,
    0.1225, 0.925, 0.1225,
    0.0125, 0.0125, 0.82
);

const mat3 GBA_DCI = mat3(
    0.72, 0.0875, 0.0725,
    0.2675, 0.9, 0.185,
    0.0125, 0.0125, 0.7425
);

const mat3 GBA_Rec2020 = mat3(
    0.57, 0.115, 0.0725,
    0.3825, 0.8625, 0.195,
    0.0475, 0.0225, 0.7325
);


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

    if (color_mode == 1) screen = GBA_sRGB * screen;
    else if (color_mode == 2) screen = GBA_DCI * screen;
    else if (color_mode == 3) screen = GBA_Rec2020 * screen;

	screen = clamp(screen, 0.0, 1.0);

	// Merge screen darkening into the final gamma encoding step
	float final_gamma = params.darken_screen * INV_GAMMA_SQ + INV_GAMMA;

	screen = pow(screen, vec3(final_gamma));

    FragColor = vec4(screen, 1.0);
}
