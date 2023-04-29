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
  float warpX;
  float warpY;
  float corner_round;
  float cgwg;
  float boost;
  float SHARPNESS;
  float SPEEDUP;	
  float WP;
  float sat;

} params;

// Parameter lines go here:
#pragma parameter warpX "warpX" 0.02 0.0 0.125 0.01
#define warpX params.warpX

#pragma parameter warpY "warpY" 0.04 0.0 0.125 0.01
#define warpY params.warpY

#pragma parameter corner_round "Corner Roundness" 0.020 0.005 0.100 0.01
#define corner_round params.corner_round

#pragma parameter SHARPNESS "   Blurriness" 0.5 0.0 0.5 0.01
#define SHARPNESS params.SHARPNESS

#pragma parameter SCANLINE "Scanline Intensity" 0.60 0.0 1.0 0.05
#define SCANLINE params.SCANLINE

#pragma parameter cgwg "CGWG mask brightness " 0.6 0.0 1.0 0.1
#define cgwg params.cgwg

#pragma parameter boost "   Bright boost " 1.00 1.00 2.00 0.02
#define boost params.boost

#pragma parameter sat "   Saturation" 1.0 0.0 2.0 0.05
#define sat params.sat

#pragma parameter WP "   Color Temperature" 0.0 -0.25 0.25 0.01
#define WP params.WP

#pragma parameter SPEEDUP "Speed-up. Warp,Gamma,Corner disabled" 0.0 0.0 1.0 1.0
#define SPEEDUP params.SPEEDUP

#define pi 3.141592654
#define in_gamma   vec3(2.4)
#define out_gamma  vec3(1.0 / 2.25)
	
layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float omega;
layout(location = 2) out vec2 pix;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord * 1.0001;
	omega =   pi * params.SourceSize.y * 2.0;
	pix = vec2(1.0, params.SourceSize.z/params.SourceSize.zw);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float omega;
layout(location = 2) in vec2 pix;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;


///////////////////////////////////////////////////////////////////////////////////////////////

vec2 Warp(vec2 pos)
{
    pos  = 2.0*pos - 1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y) * warpX, 
    	        1.0 + (pos.x*pos.x) * warpY);
    
    return pos*0.5 + 0.5;
}

vec3 scanline(float y, vec3 frame)
{
	vec3 scanline = frame*( 1.0 + SCANLINE*sin(y*omega));

	return scanline;
}

float corner(vec2 coord)
{
                coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
                coord = min(coord, vec2(1.0)-coord) * pix;
           vec2 cdist = vec2(corner_round);
                coord = (cdist - min(coord,cdist));
           float dist = sqrt(dot(coord,coord));
            
           return clamp( (cdist.x-dist)*300.0, 0.0, 1.0);
}  

// mask calculation
	vec3 Mask(float pos)
	{
	  vec3 mask = vec3(1.0);
	  
      float mf = fract(pos*0.5);	
      if (mf <0.5) mask.g = cgwg; 
      else { mask.r = cgwg; mask.b = cgwg; };
   		  
		return mask;
	}

///////////////////////////////////////////////////////////////////

void main()
{   
	vec2 pos;
	if (SPEEDUP == 0.0 )
	 pos = Warp(vTexCoord.xy);
		else pos = vTexCoord;

//borrowed from CRT-Pi
	vec2 OGL2Pos = pos * params.SourceSize.xy;
	vec2 pC4 = floor(OGL2Pos) + 0.5;
	vec2 coord = pC4 / params.SourceSize.xy;
	vec2 deltas = OGL2Pos - pC4;
	vec2 signs = sign(deltas);
		deltas.x *= 2.0;
		deltas = deltas * deltas;
		deltas.y = deltas.y * deltas.y;
		deltas.x *= SHARPNESS;
		deltas.y *= 8.0;
		deltas /= params.SourceSize.xy;
		deltas *= signs;
	vec2 tc = coord + deltas;

	vec3 res = texture(Source, tc).rgb;

// mask effects look bad unless applied in linear gamma space
	
    float lum  = max(max(res.r,res.b),res.b);
    if (SPEEDUP == 0.0)  res = pow(res,in_gamma); else res *= mix(0.82,1.05,lum);
    
    if (boost != 1.0) res *= mix(1.0,boost,lum);

// apply the mask; 
	res *= Mask(vTexCoord.x * params.OutputSize.x * 1.0001);

// re-apply the gamma curve for the mask path
    vec3 color = scanline(pos.y, res);
    if (SPEEDUP == 0.0) color = pow( color, out_gamma); else color;
    if (SPEEDUP == 0.0 ) color = color*corner(tc);
	color.rgb *= vec3(1.0+WP,1.0,1.0-WP);

    vec3 lumweight=vec3(0.3,0.6,0.1);
	float gray = dot(color,lumweight);
    vec3 graycolour = vec3(gray);
    color = vec3(mix(graycolour,color,sat));


    FragColor = vec4(color,1.0) ;

} 
