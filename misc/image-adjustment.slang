#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	float target_gamma;
	float monitor_gamma;
	float overscan_percent_x;
	float overscan_percent_y;
	float saturation;
	float contrast;
	float luminance;
	float black_level;
	float bright_boost;
	float R;
	float G;
	float B;
	float ZOOM;
	float XPOS;
	float YPOS;
	float TOPMASK;
	float BOTMASK;
	float LMASK;
	float RMASK;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma parameter target_gamma "Target Gamma" 2.4 0.1 5.0 0.1
#pragma parameter monitor_gamma "Monitor Gamma" 2.2 0.1 5.0 0.1
#pragma parameter overscan_percent_x "Horizontal Overscan %" 0.0 -25.0 25.0 1.0
#pragma parameter overscan_percent_y "Vertical Overscan %" 0.0 -25.0 25.0 1.0
#pragma parameter saturation "Saturation" 1.0 0.0 5.0 0.1
#pragma parameter contrast "Contrast" 1.0 0.0 7.5 0.1
#pragma parameter luminance "Luminance" 1.0 0.0 2.0 0.1
#pragma parameter black_level "Black Level" 0.00 -0.30 0.30 0.01
#pragma parameter bright_boost "Brightness Boost" 0.0 -1.0 1.0 0.1
#pragma parameter R "Red Channel" 1.0 0.0 2.0 0.05
#pragma parameter G "Green Channel" 1.0 0.0 2.0 0.05
#pragma parameter B "Blue Channel" 1.0 0.0 2.0 0.05
#pragma parameter ZOOM "Zoom Factor" 1.0 0.0 4.0 0.01
#pragma parameter XPOS "X Modifier" 0.0 -2.0 2.0 0.005
#pragma parameter YPOS "Y Modifier" 0.0 -2.0 2.0 0.005
#pragma parameter TOPMASK "Overscan Mask Top" 0.0 0.0 1.0 0.0025
#pragma parameter BOTMASK "Overscan Mask Bottom" 0.0 0.0 1.0 0.0025
#pragma parameter LMASK "Overscan Mask Left" 0.0 0.0 1.0 0.0025
#pragma parameter RMASK "Overscan Mask Right" 0.0 0.0 1.0 0.0025

//   Image Adjustment
//   Author: hunterk
//   License: Public domain

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vec2 shift = vec2(0.5);
   vec2 overscan_coord = ((TexCoord - shift) / registers.ZOOM) * (1.0 - vec2(registers.overscan_percent_x / 100.0, registers.overscan_percent_y / 100.0)) + shift;
   vTexCoord = overscan_coord + vec2(registers.XPOS, registers.YPOS);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

vec3 grayscale(vec3 col)
{
   // ATSC grayscale standard
   return vec3(dot(col, vec3(0.2126, 0.7152, 0.0722)));
}

void main()
{
   vec3 res = texture(Source, vTexCoord).rgb; // sample the texture
   vec3 gamma = vec3(registers.monitor_gamma / registers.target_gamma); // setup ratio of display's gamma vs desired gamma
   vec3 AvgLumin = vec3(0.5, 0.5, 0.5);
   vec3 intensity = grayscale(res); // find luminance
   vec3 satColor = mix(intensity, res, registers.saturation); // apply saturation
   vec3 conColor = mix(AvgLumin, satColor, registers.contrast);   // apply contrast
   conColor = pow(conColor, 1.0 / vec3(gamma)); // Apply gamma correction
   conColor = clamp(conColor * registers.luminance, 0.0, 1.0); // apply luminance
   conColor += vec3(registers.bright_boost); // apply brightboost
   conColor *= vec3(registers.R, registers.G, registers.B);
if (vTexCoord.y > registers.TOPMASK && vTexCoord.y < (1.0 - registers.BOTMASK))
conColor = conColor;
else
conColor = vec3(0.0);

if (vTexCoord.x > registers.LMASK && vTexCoord.x < (1.0 - registers.RMASK))
conColor = conColor;
else
conColor = vec3(0.0);
   FragColor = vec4(conColor, 1.0);
}