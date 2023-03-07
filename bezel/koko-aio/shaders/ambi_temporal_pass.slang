#version 450

/* This pass simulates the presence of a led strip placed on the back of the virtual screen */

#include "config.inc"

#define PastSampler ambi_temporal_passFeedback

#define internalness 0.07 //The distance between the screen border and the led strip
#define leds_per_strip 8   //How many leds per border
#define radius 0.001       //The base radius of the emitted light (tuned by user parameter later)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float border_min;
layout(location = 2) out float border_max;
layout(location = 3) out float fstep;
layout(location = 4) out float lod;
layout(location = 5) out vec2 vWarp_vexp;
layout(location = 6) out vec2 vWarp_arg2;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    border_min=internalness ;
    border_max=1.0-internalness ;
    fstep = (border_max - border_min)  / (leds_per_strip-1);
    
    //Calc a lod for a texture sized led_strip x led_strip
        lod = log2(global.first_passSize.y / leds_per_strip);
    
    //Precalc some Curvature/Warp values:
        vWarp_vexp = 1.0/ (1 + (vec2(GEOM_WARP_X, GEOM_WARP_Y) * 0.2)) ;
        vWarp_arg2 = 1.0 - pow(vec2(0.29289321881345247559915563789515), vWarp_vexp );
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float border_min;
layout(location = 2) in float border_max;
layout(location = 3) in float fstep;
layout(location = 4) in float lod;
layout(location = 5) in vec2 vWarp_vexp;
layout(location = 6) in vec2 vWarp_arg2;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D PastSampler;
layout(set = 0, binding = 2) uniform sampler2D avglum_pass;
layout(set = 0, binding = 3) uniform sampler2D avglum_passFeedback;
layout(set = 0, binding = 4) uniform sampler2D first_pass;


#include "includes/functions.include.slang"

vec3 ambi_push_pass(vec2 coords, float f_lod) {
   vec3 pixel_out = textureLod(first_pass, coords, f_lod).rgb;
   pixel_out = apply_fuzzy_main_pass(pixel_out);
   pixel_out = pixel_push_luminance(pixel_out, AMBI_POWER-1);
   return pixel_out;
}

vec3 circle_smooth(vec2 coords, vec2 middle, float f_radius, float FALLOFF, float f_lod) {
    float fdistance=distance(middle, vec2(coords.x, coords.y));
    float circle = (1-smoothstep(f_radius-FALLOFF, f_radius+FALLOFF, fdistance));
    vec3 circle_color = ambi_push_pass(middle, f_lod) * circle;
    return circle_color;
}

#define tol_start 0.06 //skip tolerance
#define tol_end   0.94 //1-tol_start

vec3 ambi_pre_pass() {
   
    //Scale to the original aspect
    vec2 coords = get_scaled_coords(vTexCoord, global.FinalViewportSize, is_rotated());
    if (DO_GLOBAL_SHZO >0.5)
        coords = zoom(coords + vec2(-GLOBAL_OFFX, -GLOBAL_OFFY), GLOBAL_ZOOM );
    
    if (DO_BEZEL==1.0) coords = zoomout_coords(coords, -BEZEL_INNER_ZOOM , 1.0);
    
    //Skip coords in the rect "under the monitor"
    FragColor = vec4(0.0);
    
    //First consider to skip the curved coords
    if (DO_CURVATURE == 1.0) {
        if ((GEOM_WARP_X > 0.0) || (GEOM_WARP_Y > 0.0)) {
            vec2 coords_curved = Warp_fast(coords, vWarp_vexp, vWarp_arg2); // vec2 coords_curved = Warp(coords, GEOM_WARP_X, GEOM_WARP_Y);
            if ( ( (coords_curved.x > tol_start && coords_curved.x < 1.0 - tol_start ) && (coords_curved.y > tol_start && coords_curved.y < 1.0 - tol_start) ) &&
                !( (coords.x < - tol_start || coords.x > 1.0 + tol_start) ||  (coords.y < - tol_start || coords.y > 1.0 + tol_start) ) )
                return vec3(0.0);                               
        }       
    }    

    //...next, the straight ones (needed even when curvature is due, because it returns particular values in the corners)
    //skip_pass = skip_pass && !( (coords.x < 0.0 -tol || coords.x > 1.0 +tol) ||  (coords.y < 0.0 -tol || coords.y > 1.0 +tol) );
if (coords.x > tol_start && coords.x < tol_end && coords.y > tol_start && coords.y < tol_end)  return vec3(0.0);
   
    //Finally, emulate leds.
    vec3 pixel_out = vec3(0.0);
    float middle_x; float middle_y ;
    middle_x=border_min;
    for (middle_y=border_min ; middle_y <= border_max+eps ; middle_y=middle_y + fstep ) {
        pixel_out +=circle_smooth(coords, vec2(middle_x,middle_y), radius, AMBI_FALLOFF, lod);
    }
    middle_x=border_max;
    for (middle_y=border_min ; middle_y <=  border_max+eps ; middle_y=middle_y + fstep ) {
        pixel_out +=circle_smooth(coords, vec2(middle_x,middle_y), radius, AMBI_FALLOFF, lod);
    }    

    middle_y=border_min;
    for (middle_x=border_min+fstep ; middle_x <= border_max-fstep+eps ; middle_x=middle_x + fstep ) {
        pixel_out +=circle_smooth(coords, vec2(middle_x,middle_y), radius, AMBI_FALLOFF, lod);
    }
    middle_y=border_max;
    for (middle_x=border_min+fstep ; middle_x <= border_max-fstep+eps ; middle_x=middle_x + fstep ) {
        pixel_out +=circle_smooth(coords, vec2(middle_x,middle_y), radius, AMBI_FALLOFF, lod);
    }    

    return pixel_out;
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


vec4 pixel_ambilight() {

    vec4 past_pixel_vec4 = texture(PastSampler, vTexCoord);
    vec3 present_pixel =  ambi_pre_pass().rgb;
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
    if (DO_AMBILIGHT != 1.0)
        return; 

    
    if ( mod(params.FrameCount,FRAME_DIVIDER) != 0.0) {
        vec4 past_sampler = texture(PastSampler, vTexCoord);
        past_sampler = max(past_sampler, 0.0); // <- Sanitize input to avoid glitches when enabling the option runtime.
        FragColor = past_sampler;
        return;
    }
    
    
    FragColor = pixel_ambilight();
}
