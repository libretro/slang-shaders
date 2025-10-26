#version 450

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.1                          //
//                                                                       //
// Copyright (C) 2013 Harlequin : unknown92835@gmail.com                 //
// Copyright (C) 2024-2025 Matt Akins                                    //
//                                                                       //
// 2/6/24 - Modified to support color output by mattakins                //
// 9/30/25 - v1.0 by mattakins                                           //
//   • Fullscreen mode scales dot matrix effect to any screen size       //
//   • Swap between display modes (full / max integer / scale factor)    //
//   • Built-in palette presets while maintaining image pallete support  //
//   • Drop shadow ON / OFF toggle                                       //
//   • Simple vs perceptual pixel brightness calculation modes           //
//   • Performance optimizations (vertex pre-calc, early-exit)           //
//   • Parameter reorganization for ease of use                          //
//   • Fixed issue with artifacts sometimes appearing in border          //
// 10/25/25 - v1.1 by mattakins                                          //
//   • Fixed fullscreen mode right and bottom border bug                 //
//   • Improved brightness compensation for fullscreen pixel parameters  //
//                                                                       //
// This program is free software: you can redistribute it and/or modify  //
// it under the terms of the GNU General Public License as published by  //
// the Free Software Foundation, either version 3 of the License, or     //
// (at your option) any later version.                                   //
//                                                                       //
// This program is distributed in the hope that it will be useful,       //
// but WITHOUT ANY WARRANTY; without even the implied warranty of        //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         //
// GNU General Public License for more details.                          //
//                                                                       //
// You should have received a copy of the GNU General Public License     //
// along with this program.  If not, see <http://www.gnu.org/licenses/>. //
//                                                                       //
/////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////
 // gb-pass5 - Optional console border					                //
/////////////////////////////////////////////////////////////////////////

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 SourceSize;
	vec4 OriginalSize;
	float video_scale;
	float border_texture_scale;
	float border_brightness;
	float gb_x_offset, gb_y_offset;
} registers;

#include "gb-params.inc"

#pragma parameter CONSOLE_BORDER "== Console border ==" 0.0 0.0 1.0 1.0
#pragma parameter border_texture_scale "     ↳ Border scale" 4.0 1.0 20.0 0.005
#pragma parameter border_brightness "     ↳ Border brightness" 1.0 0.0 1.0 0.01
#pragma parameter gb_x_offset "     ↳ Border offset horizontal" 0.0 -10000.0 10000.0 1.0
#pragma parameter gb_y_offset "     ↳ Border offset vertical" 0.0 -10000.0 10000.0 1.0

vec2 middle	= vec2(0.5, 0.5);
vec2 border_scale = vec2(3200, 1600) * registers.video_scale / registers.border_texture_scale;
vec2 offset_xy = vec2(registers.gb_x_offset, -registers.gb_y_offset) * registers.SourceSize.zw * 5.0;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 tex_border;

void main()
{
	gl_Position	=	global.MVP * Position;

	vTexCoord	=	TexCoord.xy + offset_xy;
	
	vec2 diff	=	vTexCoord.xy - middle;
	tex_border	=	middle + diff * registers.OutputSize.xy / border_scale;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 tex_border;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;

void main()
{
	vec4 frame	=	texture(Source, vTexCoord).rgba;
	vec4 border	=	texture(BORDER, tex_border).rgba;
	FragColor	=	vec4(mix(frame, border * registers.border_brightness, border.a));
}