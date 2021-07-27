#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float WP;
	float wp_saturation;
	float tate, fliph, flipv;
} params;

#pragma parameter tate "TATE Mode" 0.0 0.0 1.0 1.0
#pragma parameter fliph "Flip The Image Horizontally" -1.0 -1.0 1.0 2.0 
#pragma parameter flipv "Flip The Image Vertically" 1.0 -1.0 1.0 2.0
#pragma parameter WP "Color Temperature %" 0.0 -100.0 100.0 5.0 
#pragma parameter wp_saturation "Saturation Adjustment" 1.0 0.0 2.0 0.05 

#define WP params.WP
#define wp_saturation params.wp_saturation
#define tate params.tate
#define fliph params.fliph
#define flipv params.flipv

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define TEX0 vTexCoord

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
   gl_Position = global.MVP * Position * mix(vec4(1.0), vec4(flipv, fliph, 1.0, 1.0), tate); 
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const mat3 D65_to_XYZ = mat3 (
           0.4306190,  0.2220379,  0.0201853,
           0.3415419,  0.7066384,  0.1295504,
           0.1783091,  0.0713236,  0.9390944);

const mat3 XYZ_to_D65 = mat3 (
           3.0628971, -0.9692660,  0.0678775,
          -1.3931791,  1.8760108, -0.2288548,
          -0.4757517,  0.0415560,  1.0693490);
		   
const mat3 D50_to_XYZ = mat3 (
           0.4552773,  0.2323025,  0.0145457,
           0.3675500,  0.7077956,  0.1049154,
           0.1413926,  0.0599019,  0.7057489);
		   
const mat3 XYZ_to_D50 = mat3 (
           2.9603944, -0.9787684,  0.0844874,
          -1.4678519,  1.9161415, -0.2545973,
          -0.4685105,  0.0334540,  1.4216174);	

void main()
{
	vec3 color = COMPAT_TEXTURE(Source, TEX0.xy).rgb;
   
   color = normalize(pow(color + 1e-4, vec3(wp_saturation)))*length(color);
   
	float p = 2.4;
	
	color = pow(color, vec3(p));
	
	vec3 warmer = D50_to_XYZ*color;
	warmer = XYZ_to_D65*warmer;
	
	vec3 cooler = D65_to_XYZ*color;
	cooler = XYZ_to_D50*cooler;
	
	float m = abs(WP)/100.0;
	
	vec3 comp = (WP < 0.0) ? cooler : warmer;
	
	color = mix(color, comp, m);

	color = pow(color, vec3(1.0/p));	

	float a = 0.0; if (tate > 0.5) a = 0.5;
	
	FragColor = vec4(color,a);
}