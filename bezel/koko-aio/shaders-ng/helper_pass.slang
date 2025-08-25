#version 450

#include "config.inc"

#include "includes/functions.include.slang"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float vIn_aspect;
layout(location = 2) out vec2 vTexCoord_rotated_maybe;
layout(location = 3) out float vUniformity_return_current; //or feedback


void main() {
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord;// + 0.0001;
	vIn_aspect = get_in_aspect();
	vTexCoord_rotated_maybe = vTexCoord;
	#ifdef _HAS_ROTATION_UNIFORM
		if (params.Rotation == 1.0) { // 90
			vTexCoord_rotated_maybe.y = 1-vTexCoord_rotated_maybe.y;
		} else
		if (params.Rotation == 2.0){ // 180
			vTexCoord_rotated_maybe = 1-vTexCoord_rotated_maybe;
		} else
		if (params.Rotation == 3.0) { // 270
			vTexCoord_rotated_maybe.x = 1-vTexCoord_rotated_maybe.x;
		}
	#endif

    bool bIs_Interlaced = is_interlaced();

    vUniformity_return_current = float ( (!bdelta_render_enabled()) || 
                                         (!deltarender_preconditions_met(bIs_Interlaced)) || 
                                         (params.FrameCount == 0.0)
								 );
}

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vIn_aspect;
layout(location = 2) in vec2 vTexCoord_rotated_maybe;
layout(location = 3) in float vUniformity_return_current; //or feedback



layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D monitor_body_curved;
layout(set = 0, binding = 3) uniform sampler2D helper_passFeedback;
layout(set = 0, binding = 4) uniform sampler2D colortools_and_ntsc_pass;
layout(set = 0, binding = 5) uniform sampler2D colortools_and_ntsc_passFeedback;



float vignette(vec2 co){	
	//pillow:
	co=zoom(co, 1.05);
	float s = mix(0.3, 0.8,abs(V_SHAPE) );	
	
	
	
	float pillow_exp = mix(0.0, 0.30, 1-abs(V_SHAPE));
	vec2 xo=1-abs(co*2-1);
	//vec2 veryedge = 1-pow(cos(co*pi), vec2(500.0));
	//vec2 veryedge = smoothstep_fast(0.00, 0.06, xo);	
	//veryedge = mix( veryedge, vec2(1.0), clamp(abs( abs(V_SHAPE)-0.8), 0.0, 1.0)  );
	
	xo=pow(xo, vec2(pillow_exp));
	vec2 pillow = smoothstep(s,0.9,xo);

	//Vignette
	vec2 vignette = cos((co-0.5) / V_SIZE);
	
	//Tube shape
	if (V_SHAPE < 0.0) {
		vignette.y = 1.0; 
		pillow.y = 1.0;
	    //veryedge.y = 1.0;
	}
	
	//veryedge = vec2(1.0);
	return (vignette.x * vignette.y) * (pillow.x * pillow.y); // * (veryedge.x * veryedge.y);

}


float screen_uniformity(vec2 co) {

	#define _USPOTSIZE 100
	#define _USPOTSIZE_INV 100/_USPOTSIZE
	#define _USPEED 0.005
	
    vec4  subscale=vec4(5,3,7,4);
    co *= _USPOTSIZE_INV;
	float t = params.FrameCount*_USPEED;
    float uniformity = sin(co.x * subscale.x + t) * cos(co.y * subscale.y - t);
    uniformity += sin(co.y * subscale.z * sin(t * 0.5)) * cos(co.x * subscale.w + t);
	uniformity *= uniformity;
    uniformity = map_range(uniformity, -1, 1, UNIFORMITY,  (1-UNIFORMITY)/2.5 +1 );
	return uniformity * vignette(co);
}

bool DR_uniformity_safe_update() {
	//when it is ok to update uniformity when deltarender is enabled
	float present_avg_lum = rgb_to_gray(textureLod(colortools_and_ntsc_pass, vec2(0.5,0.5),20.0).rgb);
	
	//almost black screens:
	if (present_avg_lum < 5.0/255.0)
		return true;
	
	//scene changed:
	float past_avg_lum = rgb_to_gray(textureLod(colortools_and_ntsc_passFeedback, vec2(0.5,0.5),20.0).rgb);
	float diff_avg_lum = abs(past_avg_lum - present_avg_lum);
	return diff_avg_lum >= AMBI_SCENE_CHG_THRSHLD;
}


float screen_uniformity_wrap(vec2 co) {
	
	//wrap screen uniformity for deltarender support
	
	float current_uniformity = screen_uniformity(co);

	//no DR (faster version at compile time)? -> update uniformity.
	if (!bdelta_render_enabled())
		return current_uniformity;
	
	//no DR? -> update uniformity.
	if (vUniformity_return_current == 1.0)
		return current_uniformity;
	
	//DR enabled and scene changed, update uniformity.
	if (DR_uniformity_safe_update())
		return current_uniformity;
	
	//unreliable feedback, update uniformity.
	if (params.FrameCount < 10.0)
		return current_uniformity;
	
	//unreliable feedback, update uniformity.
	if (global.colortools_and_ntsc_passFeedbackSize != global.colortools_and_ntsc_passSize)
		return current_uniformity;

	//dr enabled and working, return feedback
	return texture(helper_passFeedback, vTexCoord).z;
	
}



vec2 get_curved_coords(vec2 co) {
    if ( curvature_needed() > 0.0 ) {
        co = Warp_koko(co, vec2(GEOM_WARP_X, GEOM_WARP_Y*float(need_NO_integer_scale())), 0.5);
    }
	return co; //stub
}

void main() {
	
   #ifndef D3D_WORKAROUND
      if (is_skipped_frame())
         return;
   #endif
    
   FragColor = vec4(0.0);
	

	//Vignette/Spot:
		vec2 curved_coords = get_curved_coords(vTexCoord);
		//Vignette defaults to 1.0 (multiplied in final pass), spot to 0.0 (added in final pass)
		FragColor.zw = vec2(1.0, 0.0); 
		
		if (DO_VIGNETTE == 1.0) {
			FragColor.z = screen_uniformity_wrap(curved_coords);
		}
		
		//Spot:
		if (DO_SPOT == 1.0) {
			float dist = length( vec2(  (vTexCoord_rotated_maybe.x-0.5) * vIn_aspect, vTexCoord_rotated_maybe.y-0.5) +
			                     vec2(   S_POSITION_X     * vIn_aspect, S_POSITION_Y) );
			FragColor.w = smoothstep(S_SIZE,0.0,dist) * S_POWER;
		}

}
