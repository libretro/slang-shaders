#version 450

/*
   Checkerboard Dedither - pass3
   
   2011-2022 Hyllian - sergiogdb@gmail.com

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
	float CD_HUD_DETAILS;
	float CD_ADJUST_VIEW;
	float HSM_DEDITHER_MODE;
} params;

#pragma parameter HSM_DEDITHER_MODE "Mode: OFF| STRICT | RELAXED | HYLLIAN | HYL + STRIPES | STRIPES"	0 0 5 1
#define HSM_DEDITHER_MODE  params.HSM_DEDITHER_MODE

#pragma parameter CD_HUD_DETAILS               "          Hyllian Checkerboard Details Threshold"          1.0  0.0 5.0  1.0
// #pragma parameter CD_ADJUST_VIEW               "          Hyllian Checkerboard Debug View"                0.0  0.0 1.0  1.0

#define CD_HUD_DETAILS             params.CD_HUD_DETAILS
#define CD_ADJUST_VIEW             0

#define GAMMA_EXP		2.0
#define GAMMA_IN(color)		pow(color, vec3(GAMMA_EXP, GAMMA_EXP, GAMMA_EXP))
#define GAMMA_OUT(color)	pow(color, vec3(1.0 / GAMMA_EXP, 1.0 / GAMMA_EXP, 1.0 / GAMMA_EXP))

const float Delta = 0.000000001;
const vec3 Y = vec3( 0.299,  0.587,  0.114);

vec3 min_s(vec3 central, vec3 adj1, vec3 adj2) {return min(central, max(adj1, adj2));}
vec3 max_s(vec3 central, vec3 adj1, vec3 adj2) {return max(central, min(adj1, adj2));}

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
layout(set = 0, binding = 3) uniform sampler2D LinearGamma;

void main()
{
	if (HSM_DEDITHER_MODE < 2.5 || HSM_DEDITHER_MODE > 4.5)
	{
		FragColor = texture(Source, vTexCoord);
		return;
	}

	vec2 dx = vec2(1.0, 0.0)*params.SourceSize.zw;
	vec2 dy = vec2(0.0, 1.0)*params.SourceSize.zw;

	// Reading the texels.
	vec4 C =  texture(Source, vTexCoord        );
	vec4 L =  texture(Source, vTexCoord -dx    );
	vec4 R =  texture(Source, vTexCoord +dx    );
	vec4 U =  texture(Source, vTexCoord     -dy);
	vec4 D =  texture(Source, vTexCoord     +dy);
	vec4 UL = texture(Source, vTexCoord -dx -dy);
	vec4 UR = texture(Source, vTexCoord +dx -dy);
	vec4 DL = texture(Source, vTexCoord -dx +dy);
	vec4 DR = texture(Source, vTexCoord +dx +dy);

	vec3 color =  C.rgb;

	vec3 oriC = texture(LinearGamma, vTexCoord        ).rgb;

	float count   = 0.0;
	float count2  = 0.0;

//  UL  U UR
//   L  C  R
//  DL  D DR

	count += step(Delta, L.a);
	count += step(Delta, R.a);
	count += step(Delta, U.a);
	count += step(Delta, D.a);
	count += step(Delta, UL.a*UR.a*DL.a*DR.a);

	count2 += (step(Delta, L.a*UL.a*U.a + U.a*UR.a*R.a + R.a*DR.a*D.a + D.a*DL.a*L.a));

	if ((count < CD_HUD_DETAILS)  && (count2 < 1.0))
		color = oriC;

	float luma_diff = abs(dot(oriC, Y)-dot(color, Y));

	color = mix(color, vec3(luma_diff), CD_ADJUST_VIEW);

	// FragColor = vec4(GAMMA_OUT(color), 1.0);
	FragColor = vec4(color, 1.0);
}
