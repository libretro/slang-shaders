#version 450

// Simple scanlines with curvature and mask effects lifted from crt-geom
// original by hunterk, edited by DariusG

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
  float SCANLINE_BASE_BRIGHTNESS;
  float SCANLINE_SINE_COMP_A;
  float SCANLINE_SINE_COMP_B;
  float warpX;
  float warpY;
  float corner_round;
  float cgwg;
  float crt_gamma;
  float monitor_gamma;
  float boost;
} params;

// Parameter lines go here:
#pragma parameter SCANLINE_SINE_COMP_B "Scanline Intensity" 0.60 0.0 1.0 0.05
#define SCANLINE_SINE_COMP_B params.SCANLINE_SINE_COMP_B

#pragma parameter warpX "warpX" 0.03 0.0 0.125 0.01
#define warpX params.warpX

#pragma parameter warpY "warpY" 0.05 0.0 0.125 0.01
#define warpY params.warpY

#pragma parameter corner_round "Corner Roundness" 0.030 0.005 0.100 0.005
#define corner_round params.corner_round

#pragma parameter cgwg "CGWG mask str. " 0.5 0.0 1.0 0.1
#define cgwg params.cgwg

#pragma parameter crt_gamma "CRT Gamma" 2.5 1.0 4.0 0.05
#define crt_gamma params.crt_gamma

#pragma parameter monitor_gamma "Monitor Gamma" 2.2 1.0 4.0 0.05
#define monitor_gamma params.monitor_gamma

#pragma parameter boost "Bright boost " 1.00 1.00 2.00 0.02
#define boost params.boost

#pragma parameter SCANLINE_SINE_COMP_A "Scanline Sine Comp A" 0.0 0.0 0.10 0.01
#define SCANLINE_SINE_COMP_A params.SCANLINE_SINE_COMP_A

#pragma parameter SCANLINE_BASE_BRIGHTNESS "Scanline Base Brightness" 0.95 0.0 1.0 0.01
#define SCANLINE_BASE_BRIGHTNESS params.SCANLINE_BASE_BRIGHTNESS






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

vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*warpX, 1.0 + (pos.x*pos.x)*warpY);
    
    return pos*0.5 + 0.5;
}

vec4 scanline(vec2 coord, vec4 frame)
{

	vec2 omega = vec2(3.1415 * params.OutputSize.x, 2.0 * 3.1415 * params.SourceSize.y);
	vec2 sine_comp = vec2(SCANLINE_SINE_COMP_A, SCANLINE_SINE_COMP_B);
	vec3 res = frame.xyz;

	vec3 scanline = res * (SCANLINE_BASE_BRIGHTNESS + dot(sine_comp * sin(coord * omega), vec2(1.0, 1.0)));

	return vec4(scanline.x, scanline.y, scanline.z, 1.0);
}

float corner(vec2 coord)
{
                coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
                coord = min(coord, vec2(1.0)-coord) * vec2(1.0, params.SourceSize.z/params.SourceSize.zw);
                vec2 cdist = vec2(corner_round);
                coord = (cdist - min(coord,cdist));
                float dist = sqrt(dot(coord,coord));
                return clamp((cdist.x-dist)*300.0,0.0, 1.0);
}  

// mask calculation
	// cgwg mask.
	vec4 Mask(vec2 pos)
	{
	  vec3 mask = vec3(1.0);
	{
      float mf = floor(mod(pos.x,2.0));
      float mc = 1.0 - cgwg;	
      if (mf == 0.0) { mask.g = mc; }
      else { mask.r = mc; mask.b = mc; };
   }  
		return vec4(mask, 1.0);
	}

///////////////////////////////////////////////////////////////////

void main()
{
	vec2 pos = Warp(vTexCoord.xy);

//borrowed from CRT-Pi
		vec2 OGL2Pos = pos * params.SourceSize.xy;
		vec2 pC4 = floor(OGL2Pos) + 0.5;
		vec2 coord = pC4 / params.SourceSize.xy;
		vec2 deltas = OGL2Pos - pC4;
		vec2 signs = sign(deltas);
		deltas.x *= 2.0;
		deltas = deltas * deltas;
		deltas.y = deltas.y * deltas.y;
		deltas.x *= 0.5;
		deltas.y *= 8.0;
		deltas /= params.SourceSize.xy;
		deltas *= signs;
		vec2 tc = coord + deltas;


// mask effects look bad unless applied in linear gamma space
	vec4 in_gamma = vec4(crt_gamma, crt_gamma, crt_gamma, 1.0);
	vec4 out_gamma = vec4(1.0 / monitor_gamma, 1.0 / monitor_gamma, 1.0 / monitor_gamma, 1.0);
	
	vec4 res = texture(Source, tc);
	
	res=pow(res,in_gamma);

	// apply the mask; looks bad with vert scanlines so make them mutually exclusive
	res *= Mask(vTexCoord * params.OutputSize.xy * 1.0001);

    // re-apply the gamma curve for the mask path
    vec4 color = pow(scanline(pos, res), out_gamma);
    float lum = color.r*0.3+color.g*0.6+color.b*0.1;
	color*= mix(1.0,boost,lum);
    FragColor = color*corner(tc);

} 
