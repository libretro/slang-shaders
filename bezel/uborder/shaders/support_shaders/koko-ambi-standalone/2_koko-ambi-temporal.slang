#version 450
// Released under: See LICENSE.txt

#define PastSampler ambi_temporal_passFeedback

// AMBIENT LIGHT STATIC CONFIG ##########################################################################################

	// 0.0-1.0: sensitivity to scene change (ambilike stuff), 0.0 changes more
#define AMBI_SCENE_CHG_THRSHLD 0.07  
	// The following will allow to sample at reduced interval
	// The scene change detection logic will take advantage of it
	// So that quick fades will still be treated as scene changes
#define AMBI_AVGLUM_DIVIDER 4

	// The following defines the speed of the color fades 
	// when changing scene. (range 0..1)
	// It is wise to correlate it with avglum_divider
	// try between (1/avglum_divider) and (1/avglum_divider)/3
//#define AMBI_FAST_STEP 0.125
#define AMBI_FAST_STEP 0.25



#pragma parameter LABEL3            "Koko-Ambi"		1.0  1.0  1.0     1.0
#pragma parameter AMBI_STEPS	            "        Slowness"						20.0 5.0  1000.0  5.0
#pragma parameter AMBI_INT_OFFSET           "        Led internalness"              0.0 -1.0 1.0 0.01
#pragma parameter AMBI_POWER                "        Led power"						0.4  0.0  100.0     0.05
#pragma parameter AMBI_FALLOFF              "        Light Falloff"						0.4  0.1  3.0     0.01
#pragma parameter AMBI_STRETCH              "        Widen lights"						0.0  0.0  1.0     0.01
#pragma parameter AMBI_GAMMA                "        Output Gamma"						1.3  0.1  8.0     0.1


#define smp_internalness 0.07  //The distance between the screen border and the color sampling point
#define leds_per_strip 8   //How many leds per border
#define radius 0.001       //The base radius of the emitted light (tuned by user parameter later)



layout(push_constant) uniform Push {
	mat4 MVP;
	vec4 SourceSize;
	uint FrameCount;
	vec4 FinalViewportSize;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
	mat4 MVP;
	float AMBI_STRETCH;
	float AMBI_INT_OFFSET ;
	float DO_AMBILIGHT;
	float AMBI_FALLOFF;
	float AMBI_POWER;
	float AMBI_GAMMA;
	float AMBI_STEPS;
} global;

#define AMBI_STRETCH	global.AMBI_STRETCH
#define AMBI_INT_OFFSET	global.AMBI_INT_OFFSET
#define DO_AMBILIGHT	global.DO_AMBILIGHT
#define AMBI_FALLOFF	global.AMBI_FALLOFF
#define AMBI_POWER	global.AMBI_POWER
#define AMBI_GAMMA	global.AMBI_GAMMA
#define AMBI_STEPS	global.AMBI_STEPS

#define ASPECT 1.33333


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float vLedBorder_min;
layout(location = 2) out float vLedBorder_max;
layout(location = 3) out float vLed_step;
layout(location = 4) out float lod;
layout(location = 8) out float vAMBI_POWER;
layout(location = 9) out float vSmpBorder_min;
layout(location = 10) out float vSmpBorder_max;
layout(location = 11) out float vSmp_step;
layout(location = 12) out vec2 vPre_pass_coords;


vec2 get_scaled_coords_aspect(vec2 pTexCoord, vec4 destsize, float in_aspect , bool is_rotated){
	float scale_x = 1.0;
	float scale_y = 1.0;
	float offset_x = 0.0 ;
	float offset_y = 0.0 ;
	if (is_rotated) {
		scale_y = destsize.x/(destsize.y / in_aspect );
		offset_y = (0.5 * scale_y ) - 0.5 ;
	} else {
		//to fit width, use this:
			scale_x = destsize.x/(destsize.y * in_aspect);
			offset_x = (0.5 * scale_x ) - 0.5 ;
			
		//to fit height, use this:
			//scale_y = destsize.y/(destsize.x / in_aspect);
			//offset_y = (0.5 * scale_y ) - 0.5 ;
	}

	vec2 scale_coord=vec2(pTexCoord.x*scale_x - offset_x , pTexCoord.y*scale_y - offset_y);
	return scale_coord;
}

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord ;
	vPre_pass_coords = get_scaled_coords_aspect(TexCoord, params.FinalViewportSize, ASPECT, false);

    //Min/Max points to sample colors:
        vSmpBorder_min = smp_internalness;
        vSmpBorder_max = 1.0-smp_internalness;

    //Move virtual leds position inside to compensate for widen effect
       float  led_internalness = AMBI_INT_OFFSET + (AMBI_STRETCH *0.025);

    //Min/Max points to show Leds;
        vLedBorder_min=led_internalness;
        vLedBorder_max=1.0-led_internalness;

	//Led and sampling point distance
		vLed_step = (vLedBorder_max - vLedBorder_min)  / (leds_per_strip-1);
		vSmp_step = (vSmpBorder_max - vSmpBorder_min)  / (leds_per_strip-1);

    //Calc a lod for a texture sized led_strip x led_strip
        lod = log2(params.SourceSize.y / leds_per_strip);

    //Every cycle counts!
        vAMBI_POWER = AMBI_POWER -1;

}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vLedBorder_min;
layout(location = 2) in float vLedBorder_max;
layout(location = 3) in float vLed_step;
layout(location = 4) in float lod;
layout(location = 8) in float vAMBI_POWER;
layout(location = 9) in float vSmpBorder_min;
layout(location = 10) in float vSmpBorder_max;
layout(location = 11) in float vSmp_step;
layout(location = 12) in vec2 vPre_pass_coords;

layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D PastSampler;
layout(set = 0, binding = 2) uniform sampler2D avglum_pass;
layout(set = 0, binding = 3) uniform sampler2D avglum_passFeedback;
layout(set = 0, binding = 4) uniform sampler2D Source;


vec3 pixel_push_luminance(vec3 c, float strength) {
	if (strength == 0.0) return c;
	float whiteness = max(max(c.r, c.g), c.b);
	whiteness = clamp(whiteness, 0.0, 1.0);
	return c * (1+vec3((1-whiteness) * strength));
}

vec3 ambi_push_pass(vec2 coords, float f_lod) {
   vec3 pixel_out = textureLod(Source, coords, f_lod).rgb;
   pixel_out = pow(pixel_out, vec3(AMBI_GAMMA) );
   pixel_out = pixel_push_luminance(pixel_out, vAMBI_POWER);
   return pixel_out;
}

vec2 zoomxy(vec2 in_coords, vec2 zoom_factor) {
   vec2 off = 1.0/(zoom_factor*2.0) - 0.5;
   return (in_coords/zoom_factor)-off;
}

float fcircle_smooth(vec2 coords, vec2 middle, float f_radius, float FALLOFF) {
    float fdistance = distance(middle, vec2(coords.x, coords.y));
    return (1-smoothstep(f_radius-FALLOFF, f_radius+FALLOFF, fdistance));
}


vec3 ambi_pre_pass(vec2 coords) {
    //Stretch the lights?
        float z1=distance(vec2(0.5,0.5), coords);
        vec2 zoomed_coords = zoomxy(coords, vec2(1+z1));
        coords = mix(coords, zoomed_coords, AMBI_STRETCH*0.5);
        float lAMBI_FALLOFF = AMBI_FALLOFF + (z1 * AMBI_STRETCH*0.5);
		
    //Led emulation starts here
	vec3 pixel_out = vec3(0.0);

	vec2 smp_point; //The coords where the source color is sampled
	vec2 led_point; //The coords where the led is shown
		
    //LEFT strip
    led_point = vec2(vLedBorder_min);
    smp_point = vec2(vSmpBorder_min);
    for (int i=1 ; i <= leds_per_strip ; i++) {
        float circle_shape = fcircle_smooth(coords, led_point, radius, lAMBI_FALLOFF);
        vec3  circle_color = ambi_push_pass(smp_point, lod);
        pixel_out += circle_shape * circle_color;
        led_point.y += vLed_step;
        smp_point.y += vSmp_step;
    }
    
    //RIGHT strip
    led_point = vec2(vLedBorder_max, vLedBorder_min);
    smp_point = vec2(vSmpBorder_max, vSmpBorder_min);
    for (int i=1 ; i <= leds_per_strip ; i++) {
        float circle_shape = fcircle_smooth(coords, led_point, radius, lAMBI_FALLOFF);
        vec3  circle_color = ambi_push_pass(smp_point, lod);
        pixel_out += circle_shape * circle_color;
        led_point.y += vLed_step;
        smp_point.y += vSmp_step;
    }

    //TOP strip
    led_point = vec2(vLedBorder_min + vLed_step, vLedBorder_min);
    smp_point = vec2(vSmpBorder_min + vSmp_step, vSmpBorder_min);
    for (int i=1 ; i <= leds_per_strip-2 ; i++) {
        float circle_shape = fcircle_smooth(coords, led_point, radius, lAMBI_FALLOFF);
        vec3  circle_color = ambi_push_pass(smp_point, lod);
        pixel_out += circle_shape * circle_color;
        led_point.x += vLed_step;
        smp_point.x += vSmp_step;
    }

    //BOTTOM strip
    led_point = vec2(vLedBorder_min + vLed_step, vLedBorder_max);
    smp_point = vec2(vSmpBorder_min + vSmp_step, vSmpBorder_max);
    for (int i=1 ; i <= leds_per_strip-2 ; i++) {
        float circle_shape = fcircle_smooth(coords, led_point, radius, lAMBI_FALLOFF);
        vec3  circle_color = ambi_push_pass(smp_point, lod);
        pixel_out += circle_shape * circle_color;
        led_point.x += vLed_step;
        smp_point.x += vSmp_step;
    }
    //pixel_out = pow(pixel_out, 1/vec3(AMBI_GAMMA));
    return pow(pixel_out, 1/vec3(1+AMBI_STRETCH));

}

#define MAX_STEPS AMBI_STEPS

float ambi_step(float start, float end, float mystep) {
    float diff = start-end;
    if (abs(diff) < mystep) return end;
    //Does not worth to try to unbranch:
    if (start >= end)
        return start - mystep;
            else
        return start + mystep;

}

vec3 ambi_step_rgb(vec3 s,vec3 d, vec3 mystep){
    //step fade from s to d
    return vec3 ( ambi_step(s.r, d.r, mystep.r),
                  ambi_step(s.g, d.g, mystep.g),
                  ambi_step(s.b, d.b, mystep.b)
                );
}


vec4 pixel_ambilight(vec2 local_pre_pass_coords) {

    vec4 past_pixel_vec4 = texture(PastSampler, vTexCoord);
    vec3 present_pixel =  ambi_pre_pass(local_pre_pass_coords).rgb;
    vec3 past_pixel =     past_pixel_vec4.rgb;

    float scene_change_remaining = past_pixel_vec4.a;

    float past_avg_lum = texture(avglum_passFeedback,vec2(0.25,0.25)).a;
    float present_avg_lum = texture(avglum_pass        ,vec2(0.25,0.25)).a;
    float diff_avg_lum = abs(past_avg_lum - present_avg_lum);

    if (diff_avg_lum >= AMBI_SCENE_CHG_THRSHLD) {
        scene_change_remaining = 1.0;
    }

    // Are we changing scene?
		vec3 mystep;
		if (scene_change_remaining > 0.0) {
			mystep = vec3(max(1.0/MAX_STEPS, AMBI_FAST_STEP)); // <- Never slow down fades due to fast step when changing scene
			scene_change_remaining -=  AMBI_FAST_STEP;
		} else {
			mystep = abs((past_pixel - present_pixel) / MAX_STEPS); //OK
		}

    return vec4(ambi_step_rgb(past_pixel, present_pixel, mystep), scene_change_remaining);
}

//3.0 makes scene detection not working.
#define FRAME_DIVIDER 2.0

void main() {
    //Nvidia + flycast core + glcore goes crazy with modulo operation and instead of returning 0,1,2 0,1,2 they returns 1,2,3 1,2,3 and so on.
    //Don't check for != 0.0 here, but use != 1.0.
    //Also this particular bug does not seem to happen in the last pass.
    if ( mod(params.FrameCount, FRAME_DIVIDER) != 1.0) { 
        vec4 past_sampler = texture(PastSampler, vTexCoord);
        past_sampler = max(past_sampler, 0.0); // <- Sanitize input to avoid glitches when enabling the option runtime.
        FragColor = past_sampler;
        return;
    }


    FragColor = pixel_ambilight(vPre_pass_coords);
}
 
  
