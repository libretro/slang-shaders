#version 450

// Simple scanlines with curvature and mask effects lifted from crt-geom
// original by hunterk, edited by DariusG

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
  float SCANLINE;
  float cgwg;
  float boost;
} params;

// Parameter lines go here:

#pragma parameter boost "Bright boost " 1.20 1.00 2.00 0.02
#define boost params.boost

#pragma parameter SCANLINE "Scanline Intensity" 0.50 0.0 1.0 0.05
#define SCANLINE params.SCANLINE

#pragma parameter cgwg "Mask Intensity " 0.3 0.0 1.0 0.05
#define cgwg params.cgwg


#define pi 3.141592654
	
layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 p;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord * 1.0001;
        p = vTexCoord * params.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in vec2 p;

layout(set = 0, binding = 1) uniform sampler2D Source;


///////////////////////////////////////////////////////////////////////////////////////////////


void main()
{
	vec2 pos = vTexCoord.xy;

	vec3 res = texture(Source, pos).rgb;

    res *= SCANLINE * sin(fract(p.y)*pi) +(1.0-SCANLINE);
    
    //scanlines will misalign if res*res is run before scanlines applied.
    res *= res;
    
    // apply the mask
	res *= cgwg*(sin(pos.x*params.OutputSize.x*pi))+1.0-cgwg ;
   
        res = sqrt(res);
	res *= boost;

    FragColor = vec4(res,1.0);
} 
