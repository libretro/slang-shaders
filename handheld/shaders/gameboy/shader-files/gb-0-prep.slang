#version 450

#pragma name GameBoyOpacity
#pragma format R32G32B32A32_SFLOAT

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.5                          //
//                                                                       //
// Copyright (C) 2013 Harlequin : unknown92835@gmail.com                 //
// Copyright (C) 2024-2026 Matt Akins                                    //
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
 // Color, opacity & response time preparation                          //
/////////////////////////////////////////////////////////////////////////

#include "gb-params.inc"

layout(push_constant) uniform Push
{
    float color_toggle;
    float response_time;
    float brightness_mode;
    float grey_balance;
    float baseline_alpha;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

  /////////////////////////////////////////////////////////////////////////
 // Vertex shader                                                        //
/////////////////////////////////////////////////////////////////////////

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

  /////////////////////////////////////////////////////////////////////////
 // Fragment shader                                                      //
/////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D OriginalHistory1;
layout(set = 0, binding = 4) uniform sampler2D OriginalHistory2;
layout(set = 0, binding = 5) uniform sampler2D OriginalHistory3;
layout(set = 0, binding = 6) uniform sampler2D OriginalHistory4;
layout(set = 0, binding = 7) uniform sampler2D OriginalHistory5;
layout(set = 0, binding = 8) uniform sampler2D OriginalHistory6;
layout(set = 0, binding = 9) uniform sampler2D OriginalHistory7;

void main()
{
    vec3 foreground_source = texture(Source, vTexCoord).rgb;
    vec3 rgb = abs(1.0 - foreground_source);
    vec3 matching_rgb = abs(1.0 -
        roundEven(clamp(foreground_source, 0.0, 1.0) * 255.0) / 255.0);

    // Apply the existing seven-frame response to both opacity calculations.
    if (registers.response_time > 0.0) {
        vec3 prev1_rgb = abs(1.0 - texture(OriginalHistory1, vTexCoord).rgb);
        rgb += (prev1_rgb - rgb) * registers.response_time;
        matching_rgb += (prev1_rgb - matching_rgb) * registers.response_time;
        vec3 prev2_rgb = abs(1.0 - texture(OriginalHistory2, vTexCoord).rgb);
        rgb += (prev2_rgb - rgb) * pow(registers.response_time, 2.0);
        matching_rgb += (prev2_rgb - matching_rgb) * pow(registers.response_time, 2.0);
        vec3 prev3_rgb = abs(1.0 - texture(OriginalHistory3, vTexCoord).rgb);
        rgb += (prev3_rgb - rgb) * pow(registers.response_time, 3.0);
        matching_rgb += (prev3_rgb - matching_rgb) * pow(registers.response_time, 3.0);
        vec3 prev4_rgb = abs(1.0 - texture(OriginalHistory4, vTexCoord).rgb);
        rgb += (prev4_rgb - rgb) * pow(registers.response_time, 4.0);
        matching_rgb += (prev4_rgb - matching_rgb) * pow(registers.response_time, 4.0);
        vec3 prev5_rgb = abs(1.0 - texture(OriginalHistory5, vTexCoord).rgb);
        rgb += (prev5_rgb - rgb) * pow(registers.response_time, 5.0);
        matching_rgb += (prev5_rgb - matching_rgb) * pow(registers.response_time, 5.0);
        vec3 prev6_rgb = abs(1.0 - texture(OriginalHistory6, vTexCoord).rgb);
        rgb += (prev6_rgb - rgb) * pow(registers.response_time, 6.0);
        matching_rgb += (prev6_rgb - matching_rgb) * pow(registers.response_time, 6.0);
        vec3 prev7_rgb = abs(1.0 - texture(OriginalHistory7, vTexCoord).rgb);
        rgb += (prev7_rgb - rgb) * pow(registers.response_time, 7.0);
        matching_rgb += (prev7_rgb - matching_rgb) * pow(registers.response_time, 7.0);
    }

    // Prepare full-precision opacity from the selected brightness model.
    float brightness = registers.brightness_mode < 0.5 ? rgb.r + rgb.g + rgb.b
        : (0.2126 * rgb.r) + (0.7152 * rgb.g) + (0.0722 * rgb.b);
    float balance = registers.grey_balance;
    // Compensate for brightness range difference between modes
    // Perceptual mode outputs 0-1, simple mode outputs 0-3
    if (registers.brightness_mode >= 0.5)
        balance = balance / 3.0;
    float base = brightness / balance + registers.baseline_alpha;

    // Retain full-precision dot opacity and the original 16-bit grayscale word.
    if (registers.color_toggle == 0.0) {
        float range = 3.0 / registers.grey_balance + registers.baseline_alpha;
        float word = round(clamp(base / range, 0.0, 1.0) * 65535.0);
        FragColor = vec4(base, word, 0.0, 0.0);
        return;
    }

    // Cache matching opacity and losslessly packed RGB8 color.
    float matching_brightness = registers.brightness_mode < 0.5
        ? matching_rgb.r + matching_rgb.g + matching_rgb.b
        : 3.0 * dot(matching_rgb, vec3(0.2126, 0.7152, 0.0722));
    float matching_base = matching_brightness / registers.grey_balance +
                          registers.baseline_alpha;
    vec3 bytes = roundEven(clamp(foreground_source, 0.0, 1.0) * 255.0);
    float packed_color = bytes.r * 65536.0 + bytes.g * 256.0 + bytes.b;
    FragColor = vec4(packed_color, base, matching_base, 0.0);
}
