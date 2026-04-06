#version 450

// Front-lit, Reflective LCD shader
// by hunterk
// license: public domain

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	uint FrameCount;
	float ambient_bright, point_bright, point_light_x, point_light_y, light_tilt,
	   tilt_mult_x, tilt_mult_y, green_bias, focus, schmutz, car_mode, fr_dummy1,
	   fr_dummy2, tilt_correction_x, tilt_correction_y;
} params;

#pragma parameter fr_dummy1 "=== Front-lit LCD Parameters ===" 0.001 0.0 0.001 0.0001 

#pragma parameter ambient_bright "Ambient Light Level" 0.15 0.0 0.5 0.01
#define ambient_bright params.ambient_bright
#pragma parameter point_bright "Point Light Intensity" 0.65 0.0 1.0 0.01
#define point_bright params.point_bright
#pragma parameter light_tilt "Control Light With Tilt" 0.0 0.0 1.0 1.0
#define light_tilt params.light_tilt
#pragma parameter tilt_mult_x "Horizontal Tilt Multipler" 2.0 0.01 5.0 0.1
#define tilt_mult_x params.tilt_mult_x
#pragma parameter tilt_mult_y "Vertical Tilt Multipler" 2.0 0.01 5.0 0.1
#define tilt_mult_y params.tilt_mult_y
#pragma parameter tilt_correction_x "Horizontal Tilt Correction" 0.0 -5.0 5.0 0.25
#define tilt_correction_x params.tilt_correction_x
#pragma parameter tilt_correction_y "Vertical Tilt Correction" 0.0 -5.0 5.0 0.25
#define tilt_correction_y params.tilt_correction_y
#pragma parameter point_light_x "Point Light Position X" 0.72 -5.0 5.0 0.01
#define point_light_x params.point_light_x
#pragma parameter point_light_y "Point Light Position Y" 0.89 -5.0 5.0 0.01
#define point_light_y params.point_light_y
#pragma parameter car_mode  "Nighttime Car Mode" 0.0 0.0 1.0 1.0
#define car_mode params.car_mode
#pragma parameter schmutz "Schmutz Mix" 0.3 0.0 1.0 0.01
#define schmutz params.schmutz
#pragma parameter green_bias "Green Bias" 1.0 0.0 2.0 0.05
#define green_bias params.green_bias
#pragma parameter focus "Light Focus" 0.8 0.0 0.95 0.01
#define focus params.focus

const float black_lift_amt = 0.35;

const float gamma_shift_amt = 0.6;

#pragma parameter fr_dummy2 "=== End Front-lit LCD Parameters ===" 0.001 0.0 0.001 0.0001 

// comment if you don't want to fool with the dirt LUT
#define HAVE_DIRT_LUT

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
#ifdef _HAS_SENSOR_UNIFORMS
	vec3 Accelerometer;
	vec3 Gyroscope;
#endif
} global;

#define Accelerometer global.Accelerometer
#define Gyroscope global.Gyroscope

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 lightCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
   vec2 lightxy = vec2(0.,0.);
#ifdef _HAS_SENSOR_UNIFORMS
   lightxy = (light_tilt > 0.5) ? vec2(tilt_mult_x*Accelerometer.x + tilt_correction_x, tilt_mult_y*-Accelerometer.y + tilt_correction_y) : vec2(point_light_x, point_light_y);
#else
   lightxy = vec2(point_light_x, point_light_y);
#endif
   lightCoord = vec2(lightxy.x * 0.5 + 0.5, -1.*lightxy.y * 0.5 + 0.5);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 lightCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
#ifdef HAVE_DIRT_LUT
layout(set = 0, binding = 3) uniform sampler2D dirt;
#endif

float gaussianFalloff(vec2 uv, vec2 lightPos, float sigma)
{
   float aspect_ratio = params.SourceSize.x * params.SourceSize.w;
   vec2 d = (uv - lightPos) * vec2(aspect_ratio, 1.0);
   float r2 = dot(d, d);
   return exp(-r2 / (2.0 * (1.0-sigma) * (1.0-sigma)));
}

float computeIllumination(vec2 uv, float ambient_light, float point_light_intensity,
    vec2 point_light_pos, float sigma)
{
   // Gaussian rolloff of the point light intensity
   float point = gaussianFalloff(uv, point_light_pos, sigma);

   // Base ambient light contribution, but limit it from getting too bright when zero
   float L = max(ambient_light, 0.0) + point_light_intensity * point;

   // If ambient light is very low, clamp the value to avoid brightness increase
   L = clamp(L, 0.0, 1.0);

   return L;
}

vec3 applyLCDToneResponse(vec3 color, float L)
{
   // adjust black floor lift based on ambient light level
   // if ambient is low, black floor remains lower
   float black_floor = black_lift_amt * pow(L, 1.5);

   // lift blacks only if the ambient light allows for it
   color = max(color, black_floor);

   // flatten gamma under light
   float gamma = 1.0 - gamma_shift_amt * pow(L, 1.2);
   gamma = max(gamma, 0.4); // prevent complete gamma collapse

   color = pow(color, vec3(gamma));

   return clamp(color, 0.0, 1.0);
}

vec3 applyChannelBias(vec3 color, float L)
{
   float bias_strength = green_bias * 5. * pow(L, 1.5);
   vec3 bias = vec3(1.0 - 0.05 * L, 1.0, 1.0 - 0.08 * L);
   
   // the GBC and GBA screens have a bit of a green cast to them
   return color * mix(vec3(1.0), bias, bias_strength);
}

vec3 simulateReflectiveLCD(vec3 color_linear, vec2 uv, float ambient_light,
   float point_light_intensity, vec2 point_light_pos, float sigma)
{
   float L = computeIllumination(uv, ambient_light, point_light_intensity,
      point_light_pos, sigma);

   vec3 c = color_linear;

   c = applyLCDToneResponse(c, L);
   c = applyChannelBias(c, L);

   return c;
}

void main()
{
   // how fast the wave moves
	float lightTime = params.FrameCount * 0.0035;
	// wave frequency
	float lightFreq = 0.05;
	// wipe the light wave across the screen
	float lightPhase = lightTime + (1.-(vTexCoord.y+vTexCoord.x)) * lightFreq;
	// wave goes up and down
	float streetlights = abs(fract(lightPhase) * 2.0 - 1.0);
	// smooth out the peaks and troughs. I think it looks more real without it
//	streetlights = smoothstep(0.0, 1.0, streetlights);
   // move the wave range down
	streetlights -= 0.5;
	// don't let it go below the ambient light level. This also lets us have a
	// longer down time to simulate gaps between the streetlights
	streetlights = clamp(streetlights, ambient_bright, 1.0);
	
   float ambLight = (car_mode > 0.5) ? streetlights : ambient_bright;
   vec3 color = pow(texture(Source, vTexCoord).rgb, vec3(2.2));
   vec3 inverse_color = 1.-color;
   
   color = simulateReflectiveLCD(color, vTexCoord, ambLight, point_bright, lightCoord, focus);
      
   // delinearize
   color = pow(color, vec3(1.0/2.2));
  
   float luma = dot(color, vec3(0.299, 0.587, 0.114));
   
   // raise black level with the ambient light value
   vec3 black = pow(color, vec3(1./ambLight));
   
   color = mix(black, color, (ambLight + point_bright) / 2.0);
   
   // make a halo of light
   float focal_light = computeIllumination(vTexCoord, ambient_bright, point_bright, lightCoord, focus);

   // make a halo of inverted color, slightly larger
   float inverse_light = computeIllumination(vTexCoord, ambient_bright, point_bright, lightCoord, focus / 1.25);
   
   // mix inverted spot with the main image, then mix the regular spot with that
   color = mix(black, mix(inverse_color * luma, color, focal_light), inverse_light);
   
#ifdef HAVE_DIRT_LUT
   vec4 dirty_glass = texture(dirt, vTexCoord);
   // make dirty glass more visible with more light
   color = mix(color, dirty_glass.rgb, dirty_glass.a * schmutz * clamp(ambLight + focal_light, 0.0, 1.0));
#endif
   
   FragColor = vec4(color, 1.0);
}
