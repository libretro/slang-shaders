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
	float exc;
	float upc;
	float dwc;
	float exp;
	float vuc;
} params;

#pragma parameter exc "extra correction factor (cause extra distorsion game dependent)" 0.0 -5.0 5.0 0.1
#pragma parameter upc "vertical Up cropping tweaks" 0.00 0.00 0.20 0.0025
#pragma parameter dwc "vertical Down cropping tweaks" 0.00 0.00 0.20 0.0025
#pragma parameter exp "extra 2.5 pixel orizontal tweaks" 1.0 0.0 1.0 1.0
#pragma parameter vuc "vertical resize tweaks" 0.0 0.0 5.0 1.0

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
	float rx = length(CoordX);
	float fx = -radians(params.exc+5.0);
	return (1.0-fx)/(1.0-fx*rx);
}

float AnamorphY(float CoordY)
{
	float ry = CoordY;
	float fy = -radians(params.vuc*0.5);
	if (ry > 0.0) return 1.0;
	return (1.0-fy)/(1.00-fy*ry);
}

float AnamorphB(float CoordB)
{
	float rb = length(CoordB);
	float fb = -radians(40);
	if (rb < 0.9975) return 1.0;
	return (1.0-fb)/(1.005-fb*rb);
}

void main()
{
	vec2 RCoord = vTexCoord * 2.0 - 1.0;
	if (params.exp == 1.0)
	{
	RCoord.x *=1.0078125;
	RCoord.x *= AnamorphB(RCoord.x);
	}
	RCoord.x *= AnamorphX(RCoord.x);
	RCoord.y *= AnamorphY(RCoord.y);
	RCoord = RCoord * 0.5 + 0.5;
	RCoord.y = (RCoord.y+params.upc)/(1.0+params.upc+params.dwc);
	vec3 res = texture(Source, RCoord).rgb;
    FragColor = vec4(res,0.0);
}
