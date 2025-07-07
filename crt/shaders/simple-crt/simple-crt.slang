#version 450
precision mediump float;
precision highp int;

/*
	Simple CRT shader with flicker/noise functions.
	Uses simple sin/cos mask which very slowly moves to be OLED friendly.
	Set strength to 0.0 for the various options to disable them.
	
	Oscillate brightness, uses sin to fluctuate the brightness, can flicker a lot.
	Noise, adds random noise to the image, raise lower threshold to get more noise in dark areas, same for bright areas and upper threshold.
	Flicker, unlike oscillate this is random.
	Mask, uses sin/cos to make a simple CRT mask, usually you want X to be smaller than Y to get the horizontal scanline pattern.
	
	No benchmarks where done, but I tried to keep it simple.
	
	NOTES:
		For best retro experience use native resolutions and maybe antialiasing (2x) or downsampling.
		LG OLED TVs may need to disable all OLED dimming (service menu) or the TV may dim the image slowly over time because of the CRT mask. This may also depend on the game, Duke Nukem Zero Hour Fort Roswell was really bad.
		The CRT mask will move very slowly to prevent OLED burn in, this can be observed with turbo mode when reaching very high frame rates.
		On Intel Iris XE graphics (NUC 11gen) there may be some vertical lines visible occasionally, not sure why. Works on NVIDIA RTX 4000. AMD untested. ARC untested. [Win10]
		
	
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
	float OSC_STRENGTH, OSC_SPEED,
	NOISE_STRENGTH, NOISE_SIZE, NOISE_MIN, NOISE_MAX,
	FLICKER_STRENGTH, FLICKER_MIN, FLICKER_MAX,
	CRT_MASK_STRENGTH, CRT_MASK_RES_X, CRT_MASK_RES_Y, CRT_MASK_MODE,
	LUMA_INTENSITY, LUMA_THRESHOLD;
} params;


//                                  NAME                                   DEF    MIN   MAX   STEP
#pragma parameter LUMA_INTENSITY    "[CRT] Luma boost strength"           4.00   0.00  8.00   1.00 // how strong the boost is
#pragma parameter LUMA_THRESHOLD    "[CRT] Luma boost threshold"          0.50   0.00  1.00   0.10 // 0.00 all pixels are boosted // 1.00 no pixels are boosted
#pragma parameter OSC_STRENGTH      "[CRT] Oscillate brightness strength" 0.05   0.00  0.25   0.01
#pragma parameter OSC_SPEED         "[CRT] Oscillate brightness speed"    0.50   0.00  0.75   0.05
#pragma parameter NOISE_STRENGTH    "[CRT] Noise strength"                0.20   0.00  0.50   0.01
#pragma parameter NOISE_SIZE        "[CRT] Noise size"                    2.00   0.25  4.00   0.25
#pragma parameter NOISE_MIN         "[CRT] Noise lower threshold"         0.05   0.00  1.00   0.05
#pragma parameter NOISE_MAX         "[CRT] Noise upper threshold"         0.25   0.00  1.00   0.05
#pragma parameter FLICKER_STRENGTH  "[CRT] Flicker strength"              0.05   0.00  0.50   0.01
#pragma parameter FLICKER_MIN       "[CRT] Flicker lower threshold"       0.05   0.00  1.00   0.05
#pragma parameter FLICKER_MAX       "[CRT] Flicker upper threshold"       0.25   0.00  1.00   0.05
#pragma parameter CRT_MASK_STRENGTH "[CRT] Mask strength"                 1.00   0.00  1.00   0.10
#pragma parameter CRT_MASK_RES_X    "[CRT] Mask resolution X"             1.00   0.25  4.00   0.25
#pragma parameter CRT_MASK_RES_Y    "[CRT] Mask resolution Y"             3.00   0.25  4.00   0.25
#pragma parameter CRT_MASK_MODE     "[CRT] Mask mode SD/HD"               2.00   1.00  2.00   1.00


#define OSC_STRENGTH      params.OSC_STRENGTH
#define OSC_SPEED         params.OSC_SPEED
#define NOISE_STRENGTH    params.NOISE_STRENGTH
#define NOISE_SIZE        params.NOISE_SIZE
#define NOISE_MIN         params.NOISE_MIN
#define NOISE_MAX         params.NOISE_MAX
#define FLICKER_STRENGTH  params.FLICKER_STRENGTH
#define FLICKER_MIN       params.FLICKER_MIN
#define FLICKER_MAX       params.FLICKER_MAX
#define CRT_MASK_STRENGTH params.CRT_MASK_STRENGTH
#define CRT_MASK_RES_X    params.CRT_MASK_RES_X
#define CRT_MASK_RES_Y    params.CRT_MASK_RES_Y
#define CRT_MASK_MODE     params.CRT_MASK_MODE
#define LUMA_INTENSITY    params.LUMA_INTENSITY
#define LUMA_THRESHOLD    params.LUMA_THRESHOLD


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


const float PIE                = 3.1415926535897932384626433832795;
const float TWO_PIE            = PIE * 2.0;
const int   NOISE_TEXTURE_SIZE = 1021; // do not use power of two


uvec4 pcg_hash4(const uint x) {
	const uvec4 c     = (uvec4(0x2f15, 0x5935, 0x755b, 0x1dcf) * x);
	const uvec4 state = c * 747796405u + 2891336453u;
	const uvec4 word  = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}


// pseudo-random value in half-open range [0:1].
vec4 simple_noise4(const float f) {
	return uintBitsToFloat((pcg_hash4(floatBitsToUint(f)) & 0x007fffffu) | 0x3f800000u) - 1.0;
}


vec4 simple_noise4(const uint u) {
	return uintBitsToFloat((pcg_hash4(u) & 0x007fffffu) | 0x3f800000u) - 1.0;
}


float counter_to_angle(const uint counter, const float resolution) {
	return mod(counter, resolution) / resolution * TWO_PIE;
}


#pragma stage vertex
layout(location = 0) in       vec4  Position;
layout(location = 1) in       vec2  TexCoord;
layout(location = 0) out      vec2  vTexCoord;
layout(location = 1) out flat float osc_mul;
layout(location = 2) out flat vec2  noise_div;
layout(location = 3) out flat int   noise_offset;
layout(location = 4) out flat vec3  flicker;
layout(location = 5) out flat float crt_add;
layout(location = 6) out flat float crt_mul;


void main() {
	gl_Position = global.MVP * Position;
	vTexCoord   = TexCoord;
	
	
	// oscillate brightness
	const float omax      = 1.0 + OSC_STRENGTH * 0.1;
	const float omin      = 1.0 - OSC_STRENGTH * 0.1;
	const float period    = (omax - omin);
	const float amplitude = (period * 0.5) + omin;
	const float phase     = sin(counter_to_angle(params.FrameCount, (1.0 - pow(OSC_SPEED, 0.5)) * 10)) * period;
	osc_mul               = (amplitude * sin(phase)) + omin;
	
	
	// noise
	noise_div     = 1.0 / (params.OutputSize.xy * vec2(NOISE_SIZE));
	noise_offset  = int(mod(pcg_hash4(params.FrameCount).r, NOISE_TEXTURE_SIZE));
	
	
	// flicker
	flicker = vec3(dot(simple_noise4(params.FrameCount), vec4(1.0/4.0)));
	
	
	// crt
	// very slowly move the mask to prevent OLED burn-in, this should not be noticeable
	crt_add = counter_to_angle(params.FrameCount, 0x3fff); // max 14 bits for mediump float range
	crt_mul = (1.0 + CRT_MASK_STRENGTH * 1.5); // compensate for mask brightness loss
	
	
}




#pragma stage fragment
layout(location = 0) in       vec2  vTexCoord;
layout(location = 1) in  flat float osc_mul;
layout(location = 2) in  flat vec2  noise_div;
layout(location = 3) in  flat int   noise_offset;
layout(location = 4) in  flat vec3  flicker;
layout(location = 5) in  flat float crt_add;
layout(location = 6) in  flat float crt_mul;
layout(location = 0) out      vec4  FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


void main() {
	const vec4 ca = texture(Source, vTexCoord);
	vec3 color = ca.rgb;
	
	
	// apply, oscillate brightness
	color.rgb *= osc_mul;
	
	
	// simulate noise by adding random variation to each color channel
	const vec2 no    = mod(vec2(round(fract(gl_FragCoord.xy * noise_div) * NOISE_TEXTURE_SIZE)) + noise_offset, NOISE_TEXTURE_SIZE) + 1.0; // +1 needed to avoid black stripes
	const vec3 noise = simple_noise4((5000.0 + no.x) * no.y).rgb;
	color.rgb        = mix(color.rgb, noise * clamp(color.rgb, NOISE_MIN, NOISE_MAX), NOISE_STRENGTH);
	
	
	// simulate flicker on the whole image
	color.rgb = mix(color.rgb, flicker * clamp(color.rgb, FLICKER_MIN, FLICKER_MAX), FLICKER_STRENGTH);
	
	
	// boost brightness of bright areas while keeping dark areas as is
	// this can greatly enhance contrast, especially for special effects
	// ca.a is the luma of the current and surrounding pixels, prepared by simple_color_correction.slang
	const float luma = ca.a; // dot(color, vec3(0.299,0.587,0.114));
	const float diff = luma - LUMA_THRESHOLD;
	color = mix(color, color * (luma * LUMA_INTENSITY + 1.0), pow(diff, 3.0)) * float(diff > 0.0) + color * float(diff <= 0.0);
	
	
	// simple CRT mask
	const vec2 mask_offset = mod(gl_FragCoord.xy / vec2(CRT_MASK_RES_X, CRT_MASK_RES_Y) + crt_add, TWO_PIE);
	const vec2 csm         = vec2(cos(mask_offset.x), sin(mask_offset.y));
	
	// mode 1: default pattern
	vec3 mask = vec3(dot(csm, vec2(1.0/2.0)));
	// mode 2: X style pattern
	mask = mask * mask * float(CRT_MASK_MODE > 1.5) + mask * float(CRT_MASK_MODE <= 1.5);
	
	// apply mask
	color.rgb = mix(color.rgb, mask * color.rgb, CRT_MASK_STRENGTH) * crt_mul;
	
	
	// done
	FragColor.rgb = color.rgb;
}





