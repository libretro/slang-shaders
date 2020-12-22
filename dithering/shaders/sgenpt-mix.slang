#version 450

/*
   SGENPT-MIX - Sega Genesis Pseudo Transparency Mixer Shader - v4
   
   2011-2020 Hyllian - sergiogdb@gmail.com

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is 
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

*/


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SGPT_SHARPNESS;
	float SGPT_BLEND_OPTION;
} params;

#pragma parameter SGPT_SHARPNESS "SGENPT-MIX Sharpness" 1.0 0.0 1.0 0.1
#pragma parameter SGPT_BLEND_OPTION "OFF | Transparency | Checkerboard" 1.0 0.0 2.0 1.0
#define SGPT_SHARPNESS params.SGPT_SHARPNESS
#define SGPT_BLEND_OPTION params.SGPT_BLEND_OPTION

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

void main()
{
	vec2 dx = vec2(1.0, 0.0)*params.SourceSize.zw;
	vec2 dy = vec2(0.0, 1.0)*params.SourceSize.zw;

	// Reading the texels.
	vec3 C = texture(Source, vTexCoord    ).xyz;
	vec3 L = texture(Source, vTexCoord -dx).xyz;
	vec3 R = texture(Source, vTexCoord +dx).xyz;
	vec3 U = texture(Source, vTexCoord -dy).xyz;
	vec3 D = texture(Source, vTexCoord +dy).xyz;

	vec3 color = C;

	if (SGPT_BLEND_OPTION > 0.0)
	{
		//  Get min/max samples
		vec3 min_sample = min(C, max(L, R));
		vec3 max_sample = max(C, min(L, R));

		color = 0.5*C + 0.25*(L + R);

		if (SGPT_BLEND_OPTION > 1.0)
		{
			//  Get min/max samples
			min_sample = max(min_sample, min(C, max(U, D)));
			max_sample = min(max_sample, max(C, min(U, D)));

			color = 0.5*C + 0.125*(L + R + U + D);
		}

		// Sharpness control
		vec3 aux = color;
		color = clamp(color, min_sample, max_sample);
		color = mix(aux, color, SGPT_SHARPNESS);
	}

	FragColor = vec4(color, 1.0);
}
