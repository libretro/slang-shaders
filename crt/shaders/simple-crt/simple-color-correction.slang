#version 450
precision mediump float;

/*
	Simple color corrections without color space conversions.
	
	License:
		This work is provided "as-is" and may be freely used, modified, and distributed without restriction.
		No warranty of any kind is implied or given.
*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SHARPNESS, COLOR_BRIGHTNESS, COLOR_BRIGHTNESS_O, COLOR_SATURATION, COLOR_CONTRAST_SIG, COLOR_CONTRAST_SQR, COLOR_CONTRAST_SQRL, COLOR_GAMMA, COLOR_BMIN, COLOR_BMAX, VIGNETTE_STRENGTH, VIGNETTE_SIZE, VIGNETTE_POW, MAX_COLOR_BITS;
} params;


//                                    NAME                                DEF     MIN   MAX   STEP
#pragma parameter SHARPNESS           "[IMG] Sharpness/Blur"            -0.25   -1.00  1.00   0.05 // < 0 sharpens, > 0 blurs
#pragma parameter COLOR_BRIGHTNESS    "[IMG] Brightness (Exposure)"      1.25    0.00  2.00   0.05 // multiplies color by this, affecting bright pixels more, black remains black
#pragma parameter COLOR_BRIGHTNESS_O  "[IMG] Brightness (Offset)"        0.00   -0.25  0.25   0.01 // < 0 drowns out dark details, > 0 makes black gray
#pragma parameter COLOR_SATURATION    "[IMG] Saturation"                 0.75   -2.00  2.00   0.05 // < 0 decrease saturation, > 0 increase saturation
#pragma parameter COLOR_CONTRAST_SIG  "[IMG] Contrast (sigmoid)"         0.20    0.00  1.00   0.05 // increase contrast in bright areas, high values may drown out light details
#pragma parameter COLOR_CONTRAST_SQR  "[IMG] Contrast (squared)"         1.10    0.00  2.00   0.05 // < 1 decrease contrast, > 1 increase contrast, affects color
#pragma parameter COLOR_CONTRAST_SQRL "[IMG] Contrast (squared) [luma]"  1.10    0.00  2.00   0.05 // < 1 decrease contrast, > 1 increase contrast, does not affect color
#pragma parameter COLOR_GAMMA         "[IMG] Gamma"                      1.10    0.00  2.00   0.05 // < 1 lighter, > 1 darker, for mid-tones
#pragma parameter COLOR_BMIN          "[IMG] Brightness min"             0.00    0.00  1.00   0.05 // used with max to limit the color values to a range of min..max
#pragma parameter COLOR_BMAX          "[IMG] Brightness max"             1.00    0.00  1.00   0.05 // see min
#pragma parameter VIGNETTE_STRENGTH   "[IMG] Vignette strength"          0.50    0.00  1.00   0.10 // 
#pragma parameter VIGNETTE_SIZE       "[IMG] Vignette size"              4.00    1.00  4.00   0.25 // 
#pragma parameter VIGNETTE_POW        "[IMG] Vignette hardness"          4.00    1.00  4.00   0.25 // 
#pragma parameter MAX_COLOR_BITS      "[IMG] Color bits"                 6.00    1.00  8.00   1.00 // 


#define SHARPNESS           params.SHARPNESS
#define COLOR_BRIGHTNESS    params.COLOR_BRIGHTNESS
#define COLOR_BRIGHTNESS_O  params.COLOR_BRIGHTNESS_O
#define COLOR_SATURATION    params.COLOR_SATURATION
#define COLOR_CONTRAST_SIG  params.COLOR_CONTRAST_SIG
#define COLOR_CONTRAST_SQR  params.COLOR_CONTRAST_SQR
#define COLOR_CONTRAST_SQRL params.COLOR_CONTRAST_SQRL
#define COLOR_GAMMA         params.COLOR_GAMMA
#define COLOR_BMIN          params.COLOR_BMIN
#define COLOR_BMAX          params.COLOR_BMAX
#define VIGNETTE_STRENGTH   params.VIGNETTE_STRENGTH
#define VIGNETTE_SIZE       params.VIGNETTE_SIZE
#define VIGNETTE_POW        params.VIGNETTE_POW
#define MAX_COLOR_BITS      params.MAX_COLOR_BITS


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;




#pragma stage vertex
layout(location = 0) in  vec4 Position;
layout(location = 1) in  vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;


void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord   = TexCoord;
}




#pragma stage fragment
layout(location = 0) in  vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


float max_component(const vec3 comp) {
	return max(comp.r, max(comp.g, comp.b));
}


vec4 blur_sampler2D(const sampler2D texture_sampler, const vec2 coord, const float strength) {
	const vec4 color  = texture(texture_sampler, coord);
	vec4 values       = color;
	values           += textureOffset(texture_sampler, coord, ivec2( 0, -1));
	values           += textureOffset(texture_sampler, coord, ivec2( 1,  0));
	values           += textureOffset(texture_sampler, coord, ivec2( 0,  1));
	values           += textureOffset(texture_sampler, coord, ivec2(-1,  0));
	const vec3 blur   = values.rgb * 0.2;
	
	// the alpha channel is used to store a blurred monochrome version of the image
	
	return vec4(mix(color.rgb, blur, strength), dot(blur, vec3(0.299,0.587,0.114)));
}


vec3 change_saturation(const vec3 color, const float strength) {
	return mix(vec3(dot(color, vec3(1.0/3.0))), color, strength);
}


vec3 change_contrast_sigmoid(const vec3 color, const float contrast) {
	return color / (0.5 + exp(-(contrast*contrast) * color));
}


vec3 change_contrast_squared(const vec3 color, const float contrast) {
	return mix(color, color*color, contrast - 1.0);
}


vec3 change_contrast_squared_luma(const vec3 color, const float contrast) {
	return mix(color, color*max_component(color), contrast - 1.0);
}


vec3 change_gamma(const vec3 color, const float gamma) {
	return pow(color, vec3(gamma));
}


vec3 rescale_brightness(const vec3 color, const float brightness_min, const float brightness_max) {
	return color * (brightness_max - brightness_min) + (brightness_min);
}


vec3 renormalize(const vec3 color) {
	return color / max(max(max(color.r, color.g), color.b), 1.0);
}




void main() {
	const vec4 ca = blur_sampler2D(Source, vTexCoord, SHARPNESS);
	vec3 color = ca.rgb;
	
	color = color * COLOR_BRIGHTNESS;
	color = color + COLOR_BRIGHTNESS_O;
	color = change_saturation(color, COLOR_SATURATION);
	color = change_contrast_sigmoid(color, COLOR_CONTRAST_SIG);
	color = change_contrast_squared(color, COLOR_CONTRAST_SQR);
	color = change_contrast_squared_luma(color, COLOR_CONTRAST_SQRL);
	color = change_gamma(color, COLOR_GAMMA);
	
	color = rescale_brightness(color, COLOR_BMIN, COLOR_BMAX);
	
	// quantize
	const float m = pow(2, MAX_COLOR_BITS);
	color         = round(color * m) / m;
	
	// vignette
	const vec2  normalizedCoords   = (gl_FragCoord.xy / params.OutputSize.xy) * 2 - 1;
	const float distanceFromCenter = length(normalizedCoords);
	float vignetteFactor           = pow(distanceFromCenter, VIGNETTE_POW);
	vignetteFactor                 = 1.0 - smoothstep(0.0, VIGNETTE_SIZE, vignetteFactor);
	vignetteFactor                 = mix(1.0, vignetteFactor, VIGNETTE_STRENGTH);
	color                         *= vignetteFactor;
	
	// done
	FragColor = vec4(clamp(renormalize(color), 0.0, 1.0), ca.a);
}




