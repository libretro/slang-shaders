#version 450

// Simple scanlines with curvature and mask effects lifted from crt-geom
// original by hunterk, edited by DariusG

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
 float warpx;
 float warpy;
 float a_vignette;
 float a_vigstr;
 float a_col_temp;
 float a_sat;
 float a_boostd;
 float a_boostb;
 float a_interlace;
 float scanl;
 float scanh;
 float a_MASK;
 float a_MSIZE;
 float a_MTYPE;
 float a_corner;
 float bsmooth;

} params;

// Parameter lines go here:
#pragma parameter bogus1 " [ COLORS ] " 0.0 0.0 0.0 0.0
#pragma parameter a_col_temp "Color Temperature (0.01 ~ 200K)" 0.0 -0.15 0.15 0.01
#pragma parameter a_sat "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter a_boostd "Bright Boost Dark" 1.45 1.0 2.0 0.05
#pragma parameter a_boostb "Bright Boost Bright" 1.05 1.0 2.0 0.05
#pragma parameter bogus2 " [ SCANLINES/MASK ] " 0.0 0.0 0.0 0.0
#pragma parameter scanl "Scanlines Low" 0.5 0.0 0.5 0.05
#pragma parameter scanh "Scanlines High" 0.35 0.0 0.5 0.05
#pragma parameter a_interlace "Interlace On/Off" 1.0 0.0 1.0 1.0
#pragma parameter a_MTYPE "Mask Type, Fine/Coarse/LCD" 0.0 0.0 2.0 1.0
#pragma parameter a_MSIZE "Mask Size" 1.0 1.0 2.0 1.0
#pragma parameter a_MASK "Mask Strength" 0.2 0.0 0.5 0.05
#pragma parameter bogus3 " [ GEOMETRY ] " 0.0 0.0 0.0 0.0
#pragma parameter warpx "Curvature Horizontal" 0.03 0.0 0.2 0.01
#pragma parameter warpy "Curvature Vertical" 0.04 0.0 0.2 0.01
#pragma parameter a_corner "Corner Roundness" 0.03 0.0 0.2 0.01
#pragma parameter bsmooth "Border Smoothness" 250.0 100.0 1000.0 25.0
#pragma parameter a_vignette "Vignette On/Off" 1.0 0.0 1.0 1.0
#pragma parameter a_vigstr "Vignette Strength" 0.5 0.0 1.0 0.05


#define a_col_temp params.a_col_temp
#define a_sat params.a_sat
#define a_boostd params.a_boostd
#define a_boostb params.a_boostb
#define scanl params.scanl
#define scanh params.scanh
#define a_interlace params.a_interlace
#define a_MTYPE params.a_MTYPE
#define a_MSIZE params.a_MSIZE
#define a_MASK params.a_MASK
#define warpx params.warpx
#define warpy params.warpy
#define a_corner params.a_corner
#define bsmooth params.bsmooth
#define a_vignette params.a_vignette
#define a_vigstr params.a_vigstr


#define OutputSize params.OutputSize
#define SourceSize params.SourceSize
#define OriginalSize params.OriginalSize
#define FrameCount params.FrameCount
#define pi 3.141592
#define scale vec2(SourceSize.xy/OriginalSize.xy)


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

//  VERTEX
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 ps;
layout(location = 2) out float maskpos;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord * 1.0001;
    ps = 1.0/SourceSize.xy;
    maskpos = vTexCoord.x*OutputSize.x/a_MSIZE*scale.x*pi;
}
// FRAGMENT
#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 ps;
layout(location = 2) in float maskpos;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;

#define TEX2D(c) texture(Source,(c))
#define FIX(c) max(abs(c), 1e-5)

vec2 Warp(vec2 pos)
{
    pos = pos*2.0-1.0;
    pos *= vec2(1.0+pos.y*pos.y*warpx, 1.0+pos.x*pos.x*warpy);
    pos = pos*0.5+0.5;
    return pos;
}

float corner(vec2 coord)
{
                coord = min(coord, vec2(1.0)-coord);
                vec2 cdist = vec2(a_corner);
                coord = (cdist - min(coord,cdist));
                float dist = sqrt(dot(coord,coord));
                return clamp((cdist.x-dist)*bsmooth,0.0, 1.0);
}  

void main()
{
vec2 pos = Warp(vTexCoord*scale);
vec2 cpos = pos;
pos /= scale;

// filter
  vec2 ogl2pos = pos*SourceSize.xy;

  vec2 ratio_scale = ogl2pos - vec2(0.5); ;
  vec2 uv_ratio = fract(ratio_scale);
  vec2 xy = (floor(ratio_scale) + vec2(0.5))*ps;
  // Horizontal Lanczos2 coeffs (4 taps)
  vec4 coeffs = pi * vec4(1.0 + uv_ratio.x, uv_ratio.x, 1.0 - uv_ratio.x, 2.0 - uv_ratio.x);
  coeffs = FIX(coeffs);
  coeffs = 2.0 * sin(coeffs) * sin(coeffs*0.5) / (coeffs*coeffs);
  coeffs /= dot(coeffs, vec4(1.0));

  // Fetch 4 samples from current and next scanline
  vec4 c0 = TEX2D(xy + vec2(-ps.x, 0.0));
  vec4 c1 = TEX2D(xy + vec2( 0.0 , 0.0));
  vec4 c2 = TEX2D(xy + vec2( ps.x, 0.0));
  vec4 c3 = TEX2D(xy + vec2( 2.0*ps.x, 0.0));
  vec4 res  = clamp(mat4(c0,c1,c2,c3) * coeffs, 0.0, 1.0);

float w = dot(vec3(0.33),res.rgb);

// color temp approximate
res.rgb *= vec3(1.0 + a_col_temp, 1.0 - a_col_temp * 0.2, 1.0 - a_col_temp);

float scan = mix(scanl, scanh,w);

// masks
float sz = 1.0;
float m_m = maskpos;
if (a_MTYPE == 1.0) sz = 0.6666;
if (a_MTYPE == 2.0) m_m = ogl2pos.x*2.0*pi;
res *= a_MASK*sin(m_m*sz)+1.0-a_MASK;

float vig = 0.0;
if (a_vignette == 1.0){
vig = cpos.x-0.5;
vig = vig*vig*a_vigstr;
}
// Interlace handling
if (OriginalSize.y>400.0) {ogl2pos /= 2.0;
if (mod(float(FrameCount),2.0) > 0.0 && a_interlace == 1.0) ogl2pos += 0.5;
}

res *= (scan+vig)*sin((ogl2pos.y+0.25)*2.0*pi)+(1.0-scan-vig);

float l = dot(res.rgb,vec3(0.3,0.6,0.1));
res.rgb = mix(vec3(l),res.rgb,a_sat);

res *= mix(a_boostd,a_boostb,l);

FragColor.rgb = sqrt(res.rgb)*corner(cpos);
}
