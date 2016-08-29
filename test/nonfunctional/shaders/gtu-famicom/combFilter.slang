#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float combFilter;
	float phaseOffset;
} params;

#pragma parameter combFilter "comb filter" 0.0 0.0 1.0 1.0
#pragma parameter phaseOffset "phase offset" 0.0 -0.5 0.5 0.01

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

////////////////////////////////////////////////////////
//	GTU version 0.50
//	Author: aliaspider - aliaspider@gmail.com
//	License: GPLv3
////////////////////////////////////////////////////////

//#include "config.h"

#define pi			3.14159265358

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float colorPhase;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   vec2 pos = (vTexCoord.xy*params.OutputSize.xy)-0.5;
   colorPhase = 8.0001 + pos.x + pos.y * 4.0001 + params.FrameCount * 4.0001 + 4.0001 + params.phaseOffset * 12.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float colorPhase;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
	float current = texture(Source,vTexCoord.xy).r;
	
	float signal, I, Q;
	
	if (params.combFilter > 0.0)
	{
		float prev6 = texture(Source, vTexCoord.xy - vec2(5.9999 * (params.OutputSize.z), 0.0)).r;
		signal = (current + prev6) / 2.0001;
		float chromaSignal = current - signal;
		I = chromaSignal * cos (colorPhase * (2.0001 * pi / 12.0001))*2.0001;
		Q = chromaSignal * sin (colorPhase * (2.0001 * pi / 12.0001))*2.0001;
	}
	else
	{
		signal = current;
		I = signal * cos (colorPhase * (2.0001 * pi / 12.0001))*2.0001;
		Q = signal * sin (colorPhase * (2.0001 * pi / 12.0001))*2.0001;
	}
	
	FragColor = vec4(signal, I, Q, 1.0);
}