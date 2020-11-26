#version 450

/*
	Anamorphic v1.1b Shader 2020
	by Nerboruto 
	
	Permission is hereby granted, free of charge, to any person obtaining a copy of	this
	software and associated documentation files (the “Software”), to deal in the Software
	without restriction, including without limitation the rights to use, copy, modify, 
	merge, publish, distribute, sublicense, and/or sell copies of the Software, and to 
	permit persons to whom the Software is furnished to do so, subject to the following 
	conditions:

	The above copyright notice and this permission notice shall be included in all copies
	or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
	INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
	PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
	CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
	OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	float extraCorrection;
	float upcrop;
	float downcrop;
} params;

#pragma parameter extraCorrection "extra correction factor (cause extra distorsion)" 0.0 -5.0 5.0 0.1
#pragma parameter upcrop "vertical Up cropping tweaks" 0.00 0.00 0.20 0.005
#pragma parameter downcrop "vertical Down cropping tweaks" 0.00 0.00 0.20 0.005

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

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

float AnamorphX(float CoordX)
{
	float k=params.extraCorrection;
	float RX = length(CoordX);
	float FACX = -radians(k+5.55-RX);
	return (1.0-FACX)/(1.0-FACX*RX);
}

float AnamorphE(float CoordE)
{
	float RB = length(CoordE);
	float FACB = -radians(17);
	if (RB < 0.99) return 1.0;
	return (1.0-FACB)/(1.006-FACB*RB);
}

void main()
{
	float cu=params.upcrop;
	float cd=params.downcrop;
	vec2 RCoord = vTexCoord * 2.0 - 1.0;
	RCoord.x *=1.006;
	RCoord.x *= AnamorphE(RCoord.x);
	RCoord.x *= AnamorphX(RCoord.x);
	RCoord = RCoord * 0.5 + 0.5;
	RCoord.y = (RCoord.y+cu)/(1.0+cu+cd);
	vec3 res = texture(Source, RCoord).rgb;
    FragColor = vec4(res,0.0);
}
