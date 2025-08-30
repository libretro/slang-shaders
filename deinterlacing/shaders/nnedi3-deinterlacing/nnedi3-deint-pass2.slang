#version 450

/*
   Nnedi3-Deinterlacing
   Author: AviSynth original plugin by tritical, this slang shader by Jobima
   License: GPLv2
   
   Note: This shader is designed to work with the typical interlaced output from
   an emulator, which displays both even and odd fields twice.
   
   As such, it is inappropriate for general video use unless the video has
   already been similarly woven beforehand.
*/

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 2 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float is_interlaced;

void main (void) {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   is_interlaced = float(params.OriginalSize.y > 400.0);
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float is_interlaced;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D nnedipreint0;
layout(set = 0, binding = 3) uniform sampler2D Source;

void main()
{
	vec4 origp = texture(nnedipreint0, vTexCoord);
	FragColor = origp;
	if(!bool(is_interlaced)) return;
	vec4 inputUV = texture(Source, vTexCoord - vec2(0.0, mod(float(params.FrameCount), 2.0)*params.SourceSize.w));
	FragColor = inputUV;
}
