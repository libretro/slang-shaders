#version 450

/*
    Mega Bezel - Creates a graphic treatment for the game play area to give a retro feel
    Copyright (C) 2019-2022 HyperspaceMadness - HyperspaceMadness@outlook.com

    Incorporates much great feedback from the libretro forum, and thanks 
    to Hunterk who helped me get started

    See more at the libretro forum
    https://forums.libretro.com/t/hsm-mega-bezel-reflection-shader-feedback-and-updates

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include "../base/common/helper-functions.inc"

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float HSM_DEDITHER_MODE;
   float HSM_DEDITHER_BRIGHTNESS_BIAS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter HSM_DEDITHERING_EMPTY_LINE							" " 0 0 0.001 0.001
#pragma parameter HSM_DEDITHERING_TITLE "[ --- MDAPT & HYLLIAN DE-DITHERING --- ]:" 0 0 0.01 0.01

#pragma parameter HSM_DEDITHER_MODE "Mode: OFF| STRICT | RELAXED | HYLLIAN | HYL + STRIPES | STRIPES"	0 0 5 1
#define HSM_DEDITHER_MODE  params.HSM_DEDITHER_MODE

#pragma parameter HSM_DEDITHER_BRIGHTNESS_BIAS "          Transparency Brightness Bias"	100 10 300 5
#define HSM_DEDITHER_BRIGHTNESS_BIAS  params.HSM_DEDITHER_BRIGHTNESS_BIAS * 0.013

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{  
   FragColor = texture(Source, vTexCoord);
   if (HSM_DEDITHER_MODE > 0.5)
      FragColor = HSM_Delinearize(texture(Source, vTexCoord), HSM_DEDITHER_BRIGHTNESS_BIAS);
}