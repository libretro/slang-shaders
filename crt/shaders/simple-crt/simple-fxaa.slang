#version 450
precision mediump float;


/*
	Just added the parameters with some defaults for my CRT shader.
	Defaults should do minimal blurring on 2D consoles so it should just work, may need sharpness at -0.40 for some games/systems.
*/


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float FXAA_EDGE_THRESHOLD, FXAA_EDGE_THRESHOLD_MIN, FXAA_SEARCH_STEPS, FXAA_SEARCH_THRESHOLD, FXAA_SUBPIX_TRIM, FXAA_SUBPIX_CAP;
} params;


//                                        NAME                              DEF     MIN    MAX   STEP
#pragma parameter FXAA_EDGE_THRESHOLD     "[FXAA] Edge threshold"          4.00    2.00   8.00   1.00  // 4.0 seems good
#pragma parameter FXAA_EDGE_THRESHOLD_MIN "[FXAA] Edge threshold min"     16.00    8.00  32.00   4.00  // no effect observed with my quick test I didn't notice any differences
#pragma parameter FXAA_SEARCH_STEPS       "[FXAA] Search steps"            8.00    8.00  32.00   4.00  // no effect observed with my quick test I didn't notice any differences
#pragma parameter FXAA_SEARCH_THRESHOLD   "[FXAA] Search threshold"        8.00    2.00   8.00   1.00  // higher values may be better for 2D
#pragma parameter FXAA_SUBPIX_TRIM        "[FXAA] Sub-pixel trim"          2.00    2.00   8.00   1.00  // sub-pixel blurs low-res 2D on higher values, bad for SNES, etc.
#pragma parameter FXAA_SUBPIX_CAP         "[FXAA] Sub-pixel cap"           0.10    0.10   0.90   0.10  // similar to trim, blurs 2D


#define FXAA_EDGE_THRESHOLD      (1.0 / params.FXAA_EDGE_THRESHOLD)
#define FXAA_EDGE_THRESHOLD_MIN  (1.0 / params.FXAA_EDGE_THRESHOLD_MIN)
#define FXAA_SEARCH_STEPS               params.FXAA_SEARCH_STEPS
#define FXAA_SEARCH_THRESHOLD    (1.0 / params.FXAA_SEARCH_THRESHOLD)
#define FXAA_SUBPIX_TRIM         (1.0 / params.FXAA_SUBPIX_TRIM)
#define FXAA_SUBPIX_CAP                 params.FXAA_SUBPIX_CAP


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


/**
 * @license
 * Copyright (c) 2011 NVIDIA Corporation. All rights reserved.
 *
 * TO  THE MAXIMUM  EXTENT PERMITTED  BY APPLICABLE  LAW, THIS SOFTWARE  IS PROVIDED
 * *AS IS*  AND NVIDIA AND  ITS SUPPLIERS DISCLAIM  ALL WARRANTIES,  EITHER  EXPRESS
 * OR IMPLIED, INCLUDING, BUT NOT LIMITED  TO, NONINFRINGEMENT,IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL  NVIDIA 
 * OR ITS SUPPLIERS BE  LIABLE  FOR  ANY  DIRECT, SPECIAL,  INCIDENTAL,  INDIRECT,  OR  
 * CONSEQUENTIAL DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION,  DAMAGES FOR LOSS 
 * OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR ANY 
 * OTHER PECUNIARY LOSS) ARISING OUT OF THE  USE OF OR INABILITY  TO USE THIS SOFTWARE, 
 * EVEN IF NVIDIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
 */

/*
FXAA_PRESET - Choose compile-in knob preset 0-5.
------------------------------------------------------------------------------
FXAA_EDGE_THRESHOLD - The minimum amount of local contrast required 
                      to apply algorithm.
                      1.0/3.0  - too little
                      1.0/4.0  - good start
                      1.0/8.0  - applies to more edges
                      1.0/16.0 - overkill
------------------------------------------------------------------------------
FXAA_EDGE_THRESHOLD_MIN - Trims the algorithm from processing darks.
                          Perf optimization.
                          1.0/32.0 - visible limit (smaller isn't visible)
                          1.0/16.0 - good compromise
                          1.0/12.0 - upper limit (seeing artifacts)
------------------------------------------------------------------------------
FXAA_SEARCH_STEPS - Maximum number of search steps for end of span.
------------------------------------------------------------------------------
FXAA_SEARCH_THRESHOLD - Controls when to stop searching.
                        1.0/4.0 - seems to be the best quality wise
------------------------------------------------------------------------------
FXAA_SUBPIX_TRIM - Controls sub-pixel aliasing removal.
                   1.0/2.0 - low removal
                   1.0/3.0 - medium removal
                   1.0/4.0 - default removal
                   1.0/8.0 - high removal
                   0.0 - complete removal
------------------------------------------------------------------------------
FXAA_SUBPIX_CAP - Insures fine detail is not completely removed.
                  This is important for the transition of sub-pixel detail,
                  like fences and wires.
                  3.0/4.0 - default (medium amount of filtering)
                  7.0/8.0 - high amount of filtering
                  1.0 - no capping of sub-pixel aliasing removal
*/

/*
#ifndef FXAA_PRESET
	#define FXAA_PRESET 5
#endif
#if (FXAA_PRESET == 3)
	#define FXAA_EDGE_THRESHOLD      (1.0/8.0)
	#define FXAA_EDGE_THRESHOLD_MIN  (1.0/16.0)
	#define FXAA_SEARCH_STEPS        16
	#define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
	#define FXAA_SUBPIX_CAP          (3.0/4.0)
	#define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif
#if (FXAA_PRESET == 4)
	#define FXAA_EDGE_THRESHOLD      (1.0/8.0)
	#define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
	#define FXAA_SEARCH_STEPS        24
	#define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
	#define FXAA_SUBPIX_CAP          (3.0/4.0)
	#define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif
#if (FXAA_PRESET == 5)
	#define FXAA_EDGE_THRESHOLD      (1.0/8.0)
	#define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
	#define FXAA_SEARCH_STEPS        32
	#define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
	#define FXAA_SUBPIX_CAP          (3.0/4.0)
	#define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif
*/

#define FXAA_SUBPIX_TRIM_SCALE (1.0/(1.0 - FXAA_SUBPIX_TRIM))

// Return the luma, the estimation of luminance from rgb inputs.
// This approximates luma using one FMA instruction,
// skipping normalization and tossing out blue.
// FxaaLuma() will range 0.0 to 2.963210702.
float FxaaLuma(vec3 rgb) {
	return rgb.y * (0.587/0.299) + rgb.x;
}

vec3 FxaaLerp3(vec3 a, vec3 b, float amountOfA) {
	return (vec3(-amountOfA) * b) + ((a * vec3(amountOfA)) + b);
}

vec4 FxaaTexOff(sampler2D tex, vec2 pos, ivec2 off, vec2 rcpFrame) {
	float x = pos.x + float(off.x) * rcpFrame.x;
	float y = pos.y + float(off.y) * rcpFrame.y;
	return texture(tex, vec2(x, y));
}

// pos is the output of FxaaVertexShader interpolated across screen.
// xy -> actual texture position {0.0 to 1.0}
// rcpFrame should be a uniform equal to  {1.0/frameWidth, 1.0/frameHeight}
vec3 FxaaPixelShader(vec2 pos, sampler2D tex, vec2 rcpFrame)
{
	vec3 rgbN = FxaaTexOff(tex, pos.xy, ivec2( 0,-1), rcpFrame).xyz;
	vec3 rgbW = FxaaTexOff(tex, pos.xy, ivec2(-1, 0), rcpFrame).xyz;
	vec3 rgbM = FxaaTexOff(tex, pos.xy, ivec2( 0, 0), rcpFrame).xyz;
	vec3 rgbE = FxaaTexOff(tex, pos.xy, ivec2( 1, 0), rcpFrame).xyz;
	vec3 rgbS = FxaaTexOff(tex, pos.xy, ivec2( 0, 1), rcpFrame).xyz;
	
	float lumaN = FxaaLuma(rgbN);
	float lumaW = FxaaLuma(rgbW);
	float lumaM = FxaaLuma(rgbM);
	float lumaE = FxaaLuma(rgbE);
	float lumaS = FxaaLuma(rgbS);
	float rangeMin = min(lumaM, min(min(lumaN, lumaW), min(lumaS, lumaE)));
	float rangeMax = max(lumaM, max(max(lumaN, lumaW), max(lumaS, lumaE)));
	
	float range = rangeMax - rangeMin;
	if(range < max(FXAA_EDGE_THRESHOLD_MIN, rangeMax * FXAA_EDGE_THRESHOLD))
	{
		return rgbM;
	}
	
	vec3 rgbL = rgbN + rgbW + rgbM + rgbE + rgbS;
	
	float lumaL = (lumaN + lumaW + lumaE + lumaS) * 0.25;
	float rangeL = abs(lumaL - lumaM);
	float blendL = max(0.0, (rangeL / range) - FXAA_SUBPIX_TRIM) * FXAA_SUBPIX_TRIM_SCALE; 
	blendL = min(FXAA_SUBPIX_CAP, blendL);
	
	vec3 rgbNW = FxaaTexOff(tex, pos.xy, ivec2(-1,-1), rcpFrame).xyz;
	vec3 rgbNE = FxaaTexOff(tex, pos.xy, ivec2( 1,-1), rcpFrame).xyz;
	vec3 rgbSW = FxaaTexOff(tex, pos.xy, ivec2(-1, 1), rcpFrame).xyz;
	vec3 rgbSE = FxaaTexOff(tex, pos.xy, ivec2( 1, 1), rcpFrame).xyz;
	rgbL += (rgbNW + rgbNE + rgbSW + rgbSE);
	rgbL *= vec3(1.0/9.0);
	
	float lumaNW = FxaaLuma(rgbNW);
	float lumaNE = FxaaLuma(rgbNE);
	float lumaSW = FxaaLuma(rgbSW);
	float lumaSE = FxaaLuma(rgbSE);
	
	float edgeVert = 
		abs((0.25 * lumaNW) + (-0.5 * lumaN) + (0.25 * lumaNE)) +
		abs((0.50 * lumaW ) + (-1.0 * lumaM) + (0.50 * lumaE )) +
		abs((0.25 * lumaSW) + (-0.5 * lumaS) + (0.25 * lumaSE));
	float edgeHorz = 
		abs((0.25 * lumaNW) + (-0.5 * lumaW) + (0.25 * lumaSW)) +
		abs((0.50 * lumaN ) + (-1.0 * lumaM) + (0.50 * lumaS )) +
		abs((0.25 * lumaNE) + (-0.5 * lumaE) + (0.25 * lumaSE));
		
	bool horzSpan = edgeHorz >= edgeVert;
	float lengthSign = horzSpan ? -rcpFrame.y : -rcpFrame.x;
	
	if(!horzSpan)
	{
		lumaN = lumaW;
		lumaS = lumaE;
	}
	
	float gradientN = abs(lumaN - lumaM);
	float gradientS = abs(lumaS - lumaM);
	lumaN = (lumaN + lumaM) * 0.5;
	lumaS = (lumaS + lumaM) * 0.5;
	
	if (gradientN < gradientS)
	{
		lumaN = lumaS;
		lumaN = lumaS;
		gradientN = gradientS;
		lengthSign *= -1.0;
	}
	
	vec2 posN;
	posN.x = pos.x + (horzSpan ? 0.0 : lengthSign * 0.5);
	posN.y = pos.y + (horzSpan ? lengthSign * 0.5 : 0.0);
	
	gradientN *= FXAA_SEARCH_THRESHOLD;
	
	vec2 posP = posN;
	vec2 offNP = horzSpan ? vec2(rcpFrame.x, 0.0) : vec2(0.0, rcpFrame.y); 
	float lumaEndN = lumaN;
	float lumaEndP = lumaN;
	bool doneN = false;
	bool doneP = false;
	posN += offNP * vec2(-1.0, -1.0);
	posP += offNP * vec2( 1.0,  1.0);
	
	for(int i = 0; i < int(FXAA_SEARCH_STEPS); i++) {
		if(!doneN)
		{
			lumaEndN = FxaaLuma(texture(tex, posN.xy).xyz);
		}
		if(!doneP)
		{
			lumaEndP = FxaaLuma(texture(tex, posP.xy).xyz);
		}
		
		doneN = doneN || (abs(lumaEndN - lumaN) >= gradientN);
		doneP = doneP || (abs(lumaEndP - lumaN) >= gradientN);
		
		if(doneN && doneP)
		{
			break;
		}
		if(!doneN)
		{
			posN -= offNP;
		}
		if(!doneP)
		{
			posP += offNP;
		}
	}
	
	float dstN = horzSpan ? pos.x - posN.x : pos.y - posN.y;
	float dstP = horzSpan ? posP.x - pos.x : posP.y - pos.y;
	bool directionN = dstN < dstP;
	lumaEndN = directionN ? lumaEndN : lumaEndP;
	
	if(((lumaM - lumaN) < 0.0) == ((lumaEndN - lumaN) < 0.0))
	{
		lengthSign = 0.0;
	}
	
	
	float spanLength = (dstP + dstN);
	dstN = directionN ? dstN : dstP;
	float subPixelOffset = (0.5 + (dstN * (-1.0/spanLength))) * lengthSign;
	vec3 rgbF = texture(tex, vec2(
		pos.x + (horzSpan ? 0.0 : subPixelOffset),
		pos.y + (horzSpan ? subPixelOffset : 0.0))).xyz;
	return FxaaLerp3(rgbL, rgbF, blendL); 
}




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
	FragColor = vec4(FxaaPixelShader(vTexCoord, Source, vec2(params.SourceSize.z, params.SourceSize.w)), 1.0) * 1.0;
}




