#version 450

/*

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

*/

layout(push_constant) uniform Push
{
   float beam_max, beam_min, scan_max, scan_min,CURVATURE_X,
   CURVATURE_Y,CURVATURE_SCALE,u_vignette,MSK_BRI,mask_type,
   boost_bright,boost_dark,glow_str,color_sat;
} params;

#pragma parameter beam_min "Beam Min." 8.0 2.0 15.0 1.0 
#pragma parameter beam_max "Beam Max." 6.0 2.0 15.0 1.0 
#pragma parameter scan_min "Scanlines Min" 1.3 0.0 2.5 0.05
#pragma parameter scan_max "Scanlines Max" 1.0 0.0 2.5 0.05
#pragma parameter CURVATURE_X "Curvature Horiz." 0.0 0.0 0.3 0.01
#pragma parameter CURVATURE_Y "Curvature Vert." 0.06 0.0 0.3 0.01
#pragma parameter CURVATURE_SCALE "Curvature Scale" 0.0 0.0 1.0 0.01
#pragma parameter u_vignette "Vignette" 0.25 0.0 1.0 0.01
#pragma parameter mask_type "Mask Fine/Coarse" 0.0 0.0 1.0 1.0
#pragma parameter MSK_BRI "Mask Brightness" 0.4 0.0 1.0 0.05
#pragma parameter boost_dark "Boost Dark" 1.5 1.0 4.0 0.05
#pragma parameter boost_bright "Boost Bright" 1.2 1.0 4.0 0.05
#pragma parameter glow_str "Glow Strength" 0.1 0.0 1.0 0.01
#pragma parameter color_sat "Saturation" 1.0 0.0 2.0 0.05

#define beam_max params.beam_max
#define beam_min params.beam_min
#define scan_max params.scan_max
#define scan_min params.scan_min
#define CURVATURE_X params.CURVATURE_X
#define CURVATURE_Y params.CURVATURE_Y
#define CURVATURE_SCALE params.CURVATURE_SCALE
#define u_vignette params.u_vignette
#define MSK_BRI params.MSK_BRI
#define mask_type params.mask_type
#define boost_bright params.boost_bright
#define boost_dark params.boost_dark
#define glow_str params.glow_str
#define color_sat params.color_sat

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} global;

#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
#define OutputSize global.OutputSize
#define FrameCount global.FrameCount

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 invDims;
layout(location = 2) out float maskpos;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
	invDims = 1.0/SourceSize.xy;
   maskpos = vTexCoord.x*OutputSize.x;

}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 invDims;
layout(location = 2) in float maskpos;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define grayweights vec3(0.3,0.6,0.1)

vec2 applyCurvature(vec2 uv)
{
    // Convert UV from 0–1 space to -1–1 space
    vec2 p = uv * 2.0 - 1.0;
    // Store original for later
    vec2 original = p;
    // Horizontal curvature
    p.x += (original.y * original.y) * original.x * CURVATURE_X;
    // Vertical curvature
    p.y += (original.x * original.x) * original.y * CURVATURE_Y;
    // Optional uniform curvature (tube warping)
    float r = dot(original, original);
    p *= 1.0 + r * CURVATURE_SCALE;

    // Return to 0–1 space
    return p * 0.5 + 0.5;
}
float kernel[5] = float[](
    0.0625,   // tap -2
    0.25,     // tap -1
    0.375,    // tap  0
    0.25,     // tap +1
    0.0625    // tap +2
);

vec3 glow(vec2 uv)
{
	vec3 final = vec3(0.0);

	for (int i=-2; i<3; i++)
	{
		float n = float(i);
		final += texture(Source,uv + vec2(invDims.x,0.0)*n).rgb*kernel[i+2];
	}
	for (int i=-2; i<3; i++)
	{
		float n = float(i);
		final += texture(Source,uv + vec2(0.0,invDims.y)*n).rgb*kernel[i+2];
	}
	return final;
}

void main()
{
	vec2 uv = applyCurvature(vTexCoord);
	vec2 p = uv * SourceSize.xy;
	vec2 i = floor(p) + 0.50;
	float y = p.y - i.y;

	float x = fract(p.x);

	// blurrier X axis
	p.x = (i.x + x*x*(3.0-2.0*x))*invDims.x;
	// sharp Y axis
	p.y = (i.y + 16.0*y*y*y*y*y)*invDims.y;

	vec3 colour = texture(Source, p).rgb;

	float l = max(max(colour.r,colour.g),colour.b);
	float beam = mix(beam_min, beam_max, l);
	float scan = mix(scan_min, scan_max, l);

	colour *= exp(-beam*y*y*scan);

 	float m = mod(floor(maskpos),2.0);
   vec3 mask = mix(vec3(1.0,MSK_BRI,1.0),vec3(MSK_BRI,1.0,MSK_BRI),m);
   if (mask_type == 1.0) {m =  mod(floor(maskpos),3.0);
  
   if (m==0.0) mask = vec3(MSK_BRI,MSK_BRI,1.0);
   if (m==1.0) mask = vec3(MSK_BRI,1.0,MSK_BRI);
   if (m==2.0) mask = vec3(1.0,MSK_BRI,MSK_BRI);
}

	colour *= mix(mask,vec3(boost_bright),l*0.5);
	colour *= mix(vec3(boost_dark),vec3(1.0),l);

	colour = sqrt(colour);
	colour += glow(p)*glow_str;
 	float vig = 1.0 - u_vignette*length(uv.x*2.0-1.0);
   colour *= vig;

   vec3 gray = vec3(dot(vec3(grayweights),colour));
   colour = mix(gray,colour,color_sat);
	FragColor.rgb = colour;
}
