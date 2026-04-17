#version 450

#ifndef D3D_WORKAROUND
   #define FPS_ESTIMATE_PASS halo_pre_gamma_passFeedback
#else
   #define FPS_ESTIMATE_PASS Original
#endif

#define AUTOCROP_TOLERANCE (1.0/255.0) 
//How many pseudorandom samplings per line


/* In this pass we calculate the average luminance of the scene.
 * It is cheaply obtained by the use of mipmaps. */

#include "config.inc"

//The mipmap wideness needed by the highlights on the bezel.
//the higher, the smoother.
#define mip_lod 4

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) noperspective out vec2 vTexCoord;
layout(location = 1) flat out float lod;
layout(location = 2) flat out vec2 vFuzzy_main_pass_stage_1;

layout(location = 4) flat out float vAvglum_needed;

layout(location = 6) flat out float vResSwitch_res_changed;
layout(location = 7) flat out float vResChanged;
layout(location = 8) noperspective out vec2 vTexCoord_scaled;
layout(location = 9) flat out float vDo_autocrop;
layout(location = 10) flat out float vDo_dynzoom;

//layout(location = 9) flat out vec2 vLods;
#include "includes/functions.include.slang"


void main() {
    gl_Position = global.MVP * Position;
   
    vTexCoord = TexCoord;
    
    vTexCoord_scaled = TexCoord;
    
    if (DO_GAME_GEOM_OVERRIDE > 0.5)
        vTexCoord_scaled = content_geom_override_zoom(vTexCoord, GAME_GEOM_ASPECT, get_in_aspect(), GAME_GEOM_VSHIFT, GAME_GEOM_HSHIFT, GAME_GEOM_ZOOM);

	//Get fuzzy mul and pow factor
		vFuzzy_main_pass_stage_1 = apply_fuzzy_main_pass_stage_1();    
    
    vAvglum_needed = DO_BLOOM + DO_AMBILIGHT + DO_BEZEL + (DO_DYNZOOM*10.0) + (1-RESSWITCH_SYNC_SPEED) + AUTOCROP_MAX ;
    
    //RESSWITCH shaking:
        #define RESSWITCH_FORCE_GLITCH_INITIAL_FRAMES 5
        vResSwitch_res_changed = 0.0;
        if (abs(params.OutputSize.y - params.avglum_passFeedbackSize.y) / params.OutputSize.y > RESSWITCH_GLITCH_TRESHOLD
            || params.FrameCount < RESSWITCH_FORCE_GLITCH_INITIAL_FRAMES)
        vResSwitch_res_changed = 1.0;
    
        if (params.FrameCount == 0.0 || RESSWITCH_SYNC_SPEED == 1.0)
            vResSwitch_res_changed = 0.0;
    
    
        //Uncomment to continuously test glitch effect
        //if (mod(params.FrameCount, 100) > 100-2 && RESSWITCH_SYNC_SPEED < 1.0)
        //    vResSwitch_res_changed = 1.0;
        
    //AID Scene chnge detection
        vResChanged =  float(params.OutputSize.xy - params.avglum_passFeedbackSize.xy != vec2(0.0));
        //float lod_max = lodmax(params.OriginalSize.xy);
        //vLods.x = lod_max/2.0;
        //vLods.y = vLods.x/2.0;
        
    //Disable Autocrop and dynamic zoom when integer scaling is requested. 
        bool Autocrop_disabled = AUTOCROP_MAX == 0.0 || need_integer_scale();
        bool Dynzoom_disabled = DO_DYNZOOM == 0.0 || need_integer_scale();
        vDo_autocrop = float(!Autocrop_disabled);
        vDo_dynzoom = float(!Dynzoom_disabled);
}

#pragma stage fragment
layout(location = 0) noperspective in vec2 vTexCoord;
layout(location = 1) flat in float lod;
layout(location = 2) flat in vec2 vFuzzy_main_pass_stage_1;
layout(location = 4) flat in float vAvglum_needed;

layout(location = 6) flat in float vResSwitch_res_changed;
layout(location = 7) flat in float vResChanged;
layout(location = 8) noperspective in vec2 vTexCoord_scaled;
layout(location = 9) flat in float vDo_autocrop;
layout(location = 10) flat in float vDo_dynzoom;

layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D colortools_and_ntsc_passFeedback;
layout(set = 0, binding = 2) uniform sampler2D colortools_and_ntsc_pass;
layout(set = 0, binding = 3) uniform sampler2D avglum_passFeedback;
layout(set = 0, binding = 4) uniform sampler2D FPS_ESTIMATE_PASS;

/* The following will allow to sample at reduced interval
   The scene change detection logic will take advantage of it
   So that quick fades will still be treated as scene changes
*/
// #define avglum_divider 4  <-- in config.inc

#include "includes/functions.include.slang"


#define RGB_TO_GRAYSCALE vec3(0.299, 0.587, 0.114)
float get_avg_lum_from_mip() {
    vec3 mip = textureLod(colortools_and_ntsc_pass, vec2(0.5),20.0).rgb;
     mip = apply_fuzzy_main_pass_stage_2(mip, vFuzzy_main_pass_stage_1);
    //return (mip.r+mip.g+mip.b)/3.0;
    return rgb_to_gray(mip);
}

float get_avg_lum_from_mip_nocc() {
    vec3 mip = textureLod(colortools_and_ntsc_pass, vec2(0.5),20.0).rgb;
    return rgb_to_gray(mip);
}

float get_avglum() {
    /* avglum alpha has some zones:
     * TSMOOTH_NOCC_SAMPLING_POINT -> smoothed_sampling, no color corrections, adaptived black (/crush) uses this..
     * DYN_ZOOM_SAMPLING_POINT -> temporal smoothed_sampling, used to adapt fullscreen zoom
     * AUTOCROP_SAMPLING_POINT -> autocrop zoom value pixked up by final pass.
     * RESSWITCH_SAMPLING_POINT -> resolution change detection
     * anything else: continuous sampling
     */
            

    //WARNING: Use this for dynamic zoom only, since it returns 0.0 when dynzoom is disabled or when integer scaling is requested.
    bool smoothed_sampling_co_dynzoom = is_first_inside_rect(vTexCoord, vec4(DYN_ZOOM_SAMPLING_POINT-0.1, DYN_ZOOM_SAMPLING_POINT+0.1));
    #ifndef D3D_WORKAROUND
        if (smoothed_sampling_co_dynzoom) {

            float prev_lum = texture(avglum_passFeedback,DYN_ZOOM_SAMPLING_POINT).a;
            float myframecount = params.FrameCount;
            float transition_speed_breathing = 0.2;
            
            //Tube warmup:
                //Uncomment this to see the effect continuously
                //myframecount = (mod(params.FrameCount, 60*4));
                //Use this to have an higher speed when the screen is "small"
                /*float multiply = 2.0;
                float ramp_up_frames = 60;
                float transition_speed = (ramp_up_frames - myframecount)/ramp_up_frames;
                transition_speed = clamp(transition_speed, 0.1, 0.1*multiply);
                */
                
                
                if (myframecount < 10.0) {
                    //prev_lum = mix(0.0, -1.0, clamp( DO_DYNZOOM*100.0, 0.0, 1.0 ) );
                    prev_lum = -1/((DO_DYNZOOM+eps)*5.0);
                }
            // little breath-in effect when res-switching, less on high speed
            if (vResSwitch_res_changed == 1.0) prev_lum = prev_lum - (1.75 - RESSWITCH_SYNC_SPEED);
            return mix( prev_lum, get_avg_lum_from_mip(), transition_speed_breathing) * vDo_dynzoom;
        }
        bool smoothed_sampling_co_nocc = is_first_inside_rect(vTexCoord, vec4(TSMOOTH_NOCC_SAMPLING_POINT-0.1 , TSMOOTH_NOCC_SAMPLING_POINT+0.1)) ;
        if (smoothed_sampling_co_nocc) {
            float transition_speed_adaptive_black = 0.1;
            return mix(texture(avglum_passFeedback,TSMOOTH_NOCC_SAMPLING_POINT).a, get_avg_lum_from_mip_nocc(), transition_speed_adaptive_black);
        }
    #endif
    
    //Outside specific areas, update continuously; this is used by bezel highlights.
    return get_avg_lum_from_mip();

}


bool scene_changed( sampler2D pre_smp, sampler2D cur_smp, float threshold) {
    
    vec3 pre_mip = textureLod( pre_smp, vec2(0.5), 20.0).rgb;
    vec3 cur_mip = textureLod( cur_smp, vec2(0.5), 20.0).rgb;
    
    //If resolution changes, we definitely need to change scene.
    //This should be optimal for Amiga games.
    if (vResChanged == 1.0) return true;
            
    float pre_v = rgb_to_gray(pre_mip);
    float cur_v = rgb_to_gray(cur_mip);

    float diff_v = cur_v - pre_v;
    
    // fadein: if the previous image is almost black and 
    // image is fading in, trigger a scene scange 
    if (pre_v < 2.0/255.0)
        if (pre_v < cur_v)
            return true;
    
    float diff_v_abs = abs(diff_v);
        
    // if lum is different enough trigger scene change
    if (diff_v_abs >= threshold)
        return true;
     
    /*
    // from blank screen to something else, trigger SC
    // This compares different lod mipmaps from the same samplig point
    // to guess if the screen is solid or not.
    vec3 pre_mip_l20 = pre_mip;    
    vec3 pre_mip_l1 =  textureLod( pre_smp, vec2(0.5), vLods.x).rgb;
    vec3 pre_mip_l2 =  textureLod( pre_smp, vec2(0.5), vLods.y).rgb;

    if ( pre_mip_l1 == pre_mip_l2 && pre_mip_l2 == pre_mip_l20 )
        return true;
    */  
    
    return false;
}

float quasirandom(float n) {
    //n has to be integer for this to work.
	// https://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
	return fract(n*0.754877626895905);
    //return abs(sin(n));
}

float get_next_autocrop_amount(float max_autocrop_amount) {
   
    //Implementation requires the line_step to be the same for vertical and horizontal sampling.
    //This could be a bit inefficient tho.
        const float size_max = max(params.OriginalSize.x,params.OriginalSize.y) ;
        const float next_line_step = 1/size_max;
        
    //This is needed to avoid sampling edges which may return out out of range values.
        const vec2 d = params.OriginalSize.zw * 0.5 * (1+AUTOCROP_MIN*2);
    //Reference color, topleft.
        vec3 ref = textureLod(colortools_and_ntsc_pass, vec2(d), 0.0).rgb; // FIXME, ref sample needs to be fuzzy too?
        float ref_lum = ref.r + ref.g + ref.b ;
    
    //convert zoom back to maximum cropped lines
        const float max_crop_lines = ( size_max * (max_autocrop_amount -1) )  / ( 2*max_autocrop_amount) ;
    
    
    //Sample top,bottom,left,right lines; stop when a line sum contain a different pixel color than the reference
    for (float croppedlines = AUTOCROP_MIN ; croppedlines < max_crop_lines ; croppedlines++) {
        
        vec3 smp_sum;
        float line_lum;
        float fuzzy = AUTOCROP_SAMPLE_SIZE;
        
        //Top
        smp_sum = vec3(0.0);
        for ( float x = params.FrameCount ; x < params.FrameCount+AUTOCROP_SAMPLES ;  x ++ ) {
            smp_sum += textureLod(colortools_and_ntsc_pass, vec2( scale_to_range( quasirandom(x), d.x, 1-d.x )  , 0.0 + next_line_step * croppedlines), fuzzy).rgb;
            // One should skip already sampled zones, but benchmarks say that for 20 to 50 samples gain is low or even less than 1.0
            // Probably because computing ranges is time consuming per se.
            //float start = croppedlines*params.OriginalSize.z+d.x;
            //float end = 1-(croppedlines*params.OriginalSize.z)-d.x;
            //smp_sum += textureLod(colortools_and_ntsc_pass, vec2( scale_to_range( quasirandom(x), start, end)  , d.y + next_line_step * croppedlines)).rgb;
        }
        
        line_lum = (smp_sum.r + smp_sum.g + smp_sum.b) / (AUTOCROP_SAMPLES);
        
        if ( abs(ref_lum - line_lum) > AUTOCROP_TOLERANCE)
            return size_max / (size_max - (croppedlines) * 2) ;

        //BOTTOM
        smp_sum = vec3(0.0);
        for ( float x = params.FrameCount ; x < params.FrameCount+AUTOCROP_SAMPLES ; x ++ )  {   
            smp_sum += textureLod(colortools_and_ntsc_pass, vec2(  scale_to_range( quasirandom(x), d.x, 1-d.x )  , (1.0-eps)-next_line_step*croppedlines), fuzzy).rgb;
            // One should skip already sampled zones, but benchmarks say that for 20 to 50 samples gain is low or even less than 1.0
            // Probably because computing ranges is time consuming per se.
            //float start = croppedlines*params.OriginalSize.z+d.x;
            //float end = 1-(croppedlines*params.OriginalSize.z)-d.x;
            //smp_sum += textureLod(colortools_and_ntsc_pass, vec2( scale_to_range( quasirandom(x), start, end)  , (1.0-d.y)-next_line_step*croppedlines)).rgb;
        }

        line_lum = (smp_sum.r + smp_sum.g + smp_sum.b) / (AUTOCROP_SAMPLES);
        
        if (abs( ref_lum - line_lum) > AUTOCROP_TOLERANCE) {
            return size_max / (size_max - (croppedlines) * 2) ;
        }
        
        //LEFT
        smp_sum = vec3(0.0);
        for ( float y = params.FrameCount; y < params.FrameCount+AUTOCROP_SAMPLES; y ++ ) {
            smp_sum += textureLod(colortools_and_ntsc_pass, vec2(0.0+next_line_step*croppedlines, scale_to_range( quasirandom(y), d.y, 1-d.y )  ), fuzzy).rgb;
            // One should skip already sampled zones, but benchmarks say that for 20 to 50 samples gain is low or even less than 1.0
            // Probably because computing ranges is time consuming per se.
            //float start = (croppedlines+1)*params.OriginalSize.w+d.y;
            //float end = 1-(croppedlines+1)*params.OriginalSize.w-d.y;
            //smp_sum += textureLod(colortools_and_ntsc_pass, vec2(d.x+next_line_step*croppedlines, scale_to_range( quasirandom(y), start, end )  )).rgb;
        }
        
        line_lum = (smp_sum.r + smp_sum.g + smp_sum.b) / (AUTOCROP_SAMPLES);

        if (abs( ref_lum - line_lum) > AUTOCROP_TOLERANCE)
            return size_max / (size_max - (croppedlines) * 2)     ;

        //RIGHT
        smp_sum = vec3(0.0);
        for ( float y = params.FrameCount; y < params.FrameCount+AUTOCROP_SAMPLES; y ++ ) {
            smp_sum += textureLod(colortools_and_ntsc_pass, vec2((1.0-eps)-next_line_step*croppedlines, scale_to_range( quasirandom(y), d.y, 1-d.y )    ), fuzzy).rgb;
            // One should skip already sampled zones, but benchmarks say that for 20 to 50 samples gain is low or even less than 1.0
            // Probably because computing ranges is time consuming per se.
            //float start = (croppedlines+1)*params.OriginalSize.w+d.y;
            //float end = 1-(croppedlines+1)*params.OriginalSize.w-d.y;
            //smp_sum += textureLod(colortools_and_ntsc_pass, vec2((1.0-d.x)-next_line_step*croppedlines, scale_to_range( quasirandom(y), d.y, 1-d.y )    )).rgb;
        }

        line_lum = (smp_sum.r + smp_sum.g + smp_sum.b) / (AUTOCROP_SAMPLES);

        if (abs( ref_lum - line_lum) > AUTOCROP_TOLERANCE)
            return size_max / (size_max - (croppedlines) * 2);

    }

    return max_autocrop_amount;

}


float get_autocrop() {
    // This return a value that will be used  in the final pass to zoom the picture.
    float previous_autocrop_amount = AUTOCROP_MAX+1;
    if (params.FrameCount < 30) {
        previous_autocrop_amount =  AUTOCROP_MAX+1; //Good start point.
    } else {
        previous_autocrop_amount = texture(avglum_passFeedback,AUTOCROP_SAMPLING_POINT).a;
    }

    //next_autocrop_amount = get_next_autocrop_amount(AUTOCROP_MAX);
                

    // Reset crop if scene has changed?
    float next_autocrop_amount;
    
    if (scene_changed( colortools_and_ntsc_passFeedback, colortools_and_ntsc_pass, AUTOCROP_STEADINESS) ) {
        //When a scene changes, we must release the maximum crop amount and find a new one.
        
        //For entrance effect:
            //return AUTOCROP_MAX+1; //"entrance effect?
        
        //No frills way:
            next_autocrop_amount = get_next_autocrop_amount(AUTOCROP_MAX+1);
            return next_autocrop_amount;
        
        //Mix can't work in the long run if we don't track scene changing over multiple frames.
            //next_autocrop_amount = get_next_autocrop_amount(AUTOCROP_MAX+1);
            //previous_autocrop_amount = texture(avglum_passFeedback,AUTOCROP_SAMPLING_POINT).a;
            //float r = mix( previous_autocrop_amount , next_autocrop_amount, 0.75);
            //return r;


        return next_autocrop_amount;
    } else {
        previous_autocrop_amount = texture(avglum_passFeedback,AUTOCROP_SAMPLING_POINT).a;
        next_autocrop_amount = get_next_autocrop_amount(previous_autocrop_amount);
        float r =  mix( previous_autocrop_amount , next_autocrop_amount, AUTOCROP_TRANSITION_SPEED);
        return clamp(r, 1.0, AUTOCROP_MAX+1); // needed to sanitize output when Feedback is unavailable (eg: just switched autocrop on)
    }
}


void main() {
    /*Grab a mipmap from the colortools_and_ntsc_pass.
      Calculate the average luminance from the smallest mipmap and put into the alpha channel
      So that can be used:
      1 - continuously at coordinate 0.5,0.5
      2 - sampled less often for scene detection logic at coordinate 0.25,0.25
      Put another small mipmap into the rgb channel to be used by the reflection code.
    */
    
    if ( vAvglum_needed == 0.0) return;
    
    vec4 pixel_out;
    pixel_out.a = 1.0;
    
    //We also reserve a sampling point in alpha channel to store if the resolution has changed.
    //The value stored will be used by the first pass as an argument to sin() to shake the image.
    if (is_first_inside_rect(vTexCoord, vec4(RESSWITCH_SAMPLING_POINT-0.01 , RESSWITCH_SAMPLING_POINT+0.01) )) {
        if (vResSwitch_res_changed == 1.0 ) {
            pixel_out.a = 1.0;  
        } else {
            #ifndef D3D_WORKAROUND
                vec2 early_late_cut = vec2(0.04,2.0); // decay rate before/after RESSWITCH_SYNC_SPEED threshold;
                if (low_fps(FPS_ESTIMATE_PASS)) early_late_cut*= 2.0;

                float t = texture(avglum_passFeedback,vTexCoord).a;
                if (t >= RESSWITCH_SYNC_SPEED) {
                    pixel_out.a = clamp( t - early_late_cut.x, 0,1);
                } else {
                    pixel_out.a = t/early_late_cut.y;
                }
            #else
                 pixel_out.a = 0.0;
            #endif
                 
        }

    } else if (is_first_inside_rect(vTexCoord, vec4(AUTOCROP_SAMPLING_POINT-0.01, AUTOCROP_SAMPLING_POINT+0.01) ))  {
        if (vDo_autocrop == 1.0)
            pixel_out.a = get_autocrop();
        
    } else {
        pixel_out.a = get_avglum();
    }
    

    
    //Create a small mipmap to be used to light the bezel corners
    //and by the bloom pass to identify bright areas.
    if (DO_BEZEL > 0.0) 
        pixel_out.rgb = textureLod(colortools_and_ntsc_pass, vTexCoord_scaled, mip_lod).rgb;


    FragColor = pixel_out;
    
}
