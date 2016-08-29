#version 450

// Created by inigo quilez - iq/2014
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// modified for slang border shader by hunterk

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	uint FrameCount;
	float box_scale;
	float location_x;
	float location_y;
	float in_res_x;
	float in_res_y;
	float border_on_top;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma parameter box_scale "Image Scale" 4.0 1.0 10.0 1.0
#pragma parameter location_x "Viewport X Pos." 0.5 0.0 1.0 0.05
#pragma parameter location_y "Viewport Y Pos." 0.5 0.0 1.0 0.05
#pragma parameter in_res_x "Viewport Size X" 320.0 100.0 600.0 1.0
#pragma parameter in_res_y "Viewport Size Y" 240.0 64.0 512.0 1.0
#pragma parameter border_on_top "Show Viewport" 1.0 0.0 1.0 1.0

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 screen_coord;

void main()
{
   gl_Position = global.MVP * Position;
   vec2 corrected_size = vec2(params.in_res_x, params.in_res_y);
   vec2 scale = (params.OutputSize.xy / corrected_size) / params.box_scale;
   vec2 middle = vec2(params.location_x, params.location_y);
   vec2 diff = TexCoord.xy - middle;
   screen_coord = middle + diff * scale;
   middle = vec2(0.4999, 0.4999);
   vec2 dist = vTexCoord - middle;
   vTexCoord = TexCoord * 0.25;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 screen_coord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;
layout(set = 0, binding = 4) uniform sampler2D iChannel0;

//raymarch demo functions
vec4 hexagon( vec2 p ) 
{
	vec2 q = vec2( p.x*2.0*0.5773503, p.y + p.x*0.5773503 );
	
	vec2 pi = floor(q);
	vec2 pf = fract(q);

	float v = mod(pi.x + pi.y, 3.0);

	float ca = step(1.0,v);
	float cb = step(2.0,v);
	vec2  ma = step(pf.xy,pf.yx);
	
    // distance to borders
	float e = dot( ma, 1.0-pf.yx + ca*(pf.x+pf.y-1.0) + cb*(pf.yx-2.0*pf.xy) );

	// distance to center	
	p = vec2( q.x + floor(0.5+p.y/1.5), 4.0*p.y/3.0 )*0.5 + 0.5;
	float f = length( (fract(p) - 0.5)*vec2(1.0,0.85) );		
	
	return vec4( pi + ca - cb*ma, e, f );
}

float hash1( vec2  p ) { float n = dot(p,vec2(127.1,311.7) ); return fract(sin(n)*43758.5453); }

float noise( in vec3 x )
{
    vec3 p = floor(x);
    vec3 f = fract(x);
	f = f*f*(3.0-2.0*f);
	vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
	vec2 rg = texture(iChannel0, (uv+0.5) / 32.0, -1.0).yx;
	return mix( rg.x, rg.y, f.z );
}
// end raymarch demo functions

void main()
{
// from raymarch demo
    vec2 uv = gl_FragCoord.xy / params.OutputSize.xy;
	vec2 pos = (-params.OutputSize.xy + 2.0*gl_FragCoord.xy)/ params.OutputSize.y;
	float timer = params.FrameCount * 0.025;
	
    // distort
	pos *= 1.0 + 0.9*length(pos);
	
    // gray
	vec4 h = hexagon(8.0*pos + 0.5*timer);
	float n = noise( vec3(0.3*h.xy+timer*0.1,timer) );
	vec3 col = 0.15 + 0.15*hash1(h.xy+1.2)*vec3(1.0);
	col *= smoothstep( 0.10, 0.11, h.z );
	col *= smoothstep( 0.10, 0.11, h.w );
	col *= 1.0 + 0.15*sin(40.0*h.z);
	col *= 0.75 + 0.5*h.z*n;

	// red
	h = hexagon(6.0*pos + 0.6*timer);
	n = noise( vec3(0.3*h.xy+timer*0.1, timer) );
	vec3 colb = 0.9 + 0.8*sin( hash1(h.xy)*1.5 + 2.0 + vec3(0.0,1.0,1.0) );
	colb *= smoothstep( 0.10, 0.11, h.z );
	colb *= 1.0 + 0.15*sin(40.0*h.z);
	colb *= 0.75 + 0.5*h.z*n;

	h = hexagon(6.0*(pos+0.1*vec2(-1.3,1.0)) + 0.6*timer);
    col *= 1.0-0.8*smoothstep(0.45,0.451,noise( vec3(0.3*h.xy+timer*0.1,timer) ));

	col = mix( col, colb, smoothstep(0.45,0.451,n) );

	
	col *= pow( 16.0*uv.x*(1.0-uv.x)*uv.y*(1.0-uv.y), 0.1 );
// end raymarch demo

vec4 screen = texture(Source, screen_coord); //the main video screen
vec4 background = vec4(col, 1.0); //put your background function's output here
if ( screen_coord.x < 0.9999 && screen_coord.x > 0.0001 && screen_coord.y < 0.9999 && screen_coord.y > 0.0001 && params.border_on_top > 0.5 )
background.a *= 0.0;
   FragColor = vec4(mix(screen, background, background.a));
}