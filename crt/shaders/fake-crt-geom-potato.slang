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
  float gamma;
} params;

// Parameter lines go here:

#pragma parameter boost "Bright boost " 1.00 1.00 2.00 0.02
#define boost params.boost

#pragma parameter SCANLINE "Scanline Intensity" 0.70 0.0 1.0 0.05
#define SCANLINE params.SCANLINE

#pragma parameter cgwg "CGWG mask brightness " 0.7 0.0 1.0 0.1
#define cgwg params.cgwg

#pragma parameter gamma "Gamma Fix (slower)" 1.0 0.0 1.0 1.0
#define gamma params.gamma

#define pi 3.141592654
	
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
	vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;


///////////////////////////////////////////////////////////////////////////////////////////////

// CGWG mask calculation
	
      vec3 Mask(float pos)
      {
      float mf = fract(pos * 0.5);

      if (mf <0.5) return vec3(1.0,cgwg,1.0);
      else return vec3(cgwg,1.0,cgwg);
  
      }

void main()
{
	vec2 pos = vTexCoord.xy;
	vec3 res = texture(Source, pos).rgb;
	if (gamma == 1.0)  res *=res;
	if (params.OriginalSize.y < 400.0)
    res *= SCANLINE * sin(fract(vTexCoord.y*params.SourceSize.y)*3.141529) +(1.0-SCANLINE);
	else res;

// apply the mask
	res *= Mask(pos.x*params.OutputSize.x * 1.0001);
	if (gamma == 1.0)  res = sqrt(res);
	res *= boost;

    FragColor = vec4(res,1.0);
} 
