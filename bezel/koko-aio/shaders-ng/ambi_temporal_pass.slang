#version 450

/* This pass simulates the presence of a led strip placed on the back of the virtual screen */

#include "config.inc"
#include "includes/functions.include.slang"

#define PastSampler ambi_temporal_passFeedback

#define smp_internalness AMBI_SMP_INT_OFFSET  //The distance between the screen border and the color sampling point
#define leds_per_strip 8   //How many leds per border
#define radius 0.001       //The base radius of the emitted light (tuned by user parameter later)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) noperspective out vec2 vTexCoord;
layout(location = 1) flat out float vLedBorder_min;
layout(location = 2) flat out float vLedBorder_max;
layout(location = 3) flat out float vLed_step;
layout(location = 4) flat out float lod;
layout(location = 5) noperspective out vec2 pre_pass_coords;
layout(location = 6) flat out float vIs_rotated;
layout(location = 7) flat out float vAMBI_STRETCH;

layout(location = 9) flat out float vSmpBorder_min;
layout(location = 10) flat out float vSmpBorder_max;
layout(location = 11) flat out float vSmp_step;


void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    //Min/Max points to sample colors:
        vSmpBorder_min = smp_internalness;
        vSmpBorder_max = 1.0-smp_internalness;

        if (DO_GAME_GEOM_OVERRIDE > 0.5) {
            vSmpBorder_min = content_geom_override_zoom(vec2(vSmpBorder_min), GAME_GEOM_ASPECT, get_in_aspect(), GAME_GEOM_VSHIFT, GAME_GEOM_HSHIFT, GAME_GEOM_ZOOM).x;
            vSmpBorder_max = content_geom_override_zoom(vec2(vSmpBorder_max), GAME_GEOM_ASPECT, get_in_aspect(), GAME_GEOM_VSHIFT, GAME_GEOM_HSHIFT, GAME_GEOM_ZOOM).x;
        }

    bool isrotated = is_rotated();
    vIs_rotated = float(isrotated);

    if (isrotated)
        vAMBI_STRETCH = AMBI_STRETCH_VERTICAL;
            else
        vAMBI_STRETCH = AMBI_STRETCH;

        //Keep leds in place when content geometry zoom changes
        float ambi_int_offset = AMBI_INT_OFFSET;
        if (DO_GAME_GEOM_OVERRIDE + DO_BEZEL > 1.5) {
                ambi_int_offset = content_geom_override_zoom    (vec2(ambi_int_offset), GAME_GEOM_ASPECT, get_in_aspect(), GAME_GEOM_VSHIFT, GAME_GEOM_HSHIFT, GAME_GEOM_ZOOM).x;
        }
        
        //Move virtual leds position inside to compensate for widen effect
        float led_internalness = ambi_int_offset + (vAMBI_STRETCH *0.025);

       
    //less internalness when using bezel:
        led_internalness -= 0.07 * DO_BEZEL;
       
        //led_internalness = -0.18   ;

    //Min/Max points to show Leds;
        vLedBorder_min=led_internalness;
        vLedBorder_max=1.0-led_internalness;

    vLed_step = (vLedBorder_max - vLedBorder_min)  / (leds_per_strip-1);
    vSmp_step = (vSmpBorder_max - vSmpBorder_min)  / (leds_per_strip-1);

    //Calc a lod for a texture sized led_strip x led_strip
        lod = log2(global.upscale_passSize.y / leds_per_strip) - 1;


   //Scale to the original aspect, then scale according to zoom modifiers.
    float in_aspect = get_in_aspect();

    float Do_Tate = need_tate(isrotated);
    
    bool bNeed_NO_integer_scale = need_NO_integer_scale();
    
    if (bNeed_NO_integer_scale)
        pre_pass_coords = get_scaled_coords_aspect(TexCoord,global.FinalViewportSize, in_aspect, isrotated) + vec2(0.00001);
            else
        pre_pass_coords = integer_scale(TexCoord, in_aspect, isrotated, Do_Tate, GAME_GEOM_INT_SCALE-1.0 ) ;


    if (DO_GLOBAL_SHZO >0.5) {
        if (bNeed_NO_integer_scale)
            pre_pass_coords = zoom(pre_pass_coords + vec2(-GLOBAL_OFFX, -GLOBAL_OFFY), GLOBAL_ZOOM );
        else
            pre_pass_coords += vec2(-GLOBAL_OFFX, -GLOBAL_OFFY);
    }
    
    if (bNeed_NO_integer_scale) {
        if (DO_GAME_GEOM_OVERRIDE > 0.5)
            pre_pass_coords = content_geom_override_zoom(pre_pass_coords, GAME_GEOM_ASPECT, in_aspect, GAME_GEOM_VSHIFT, GAME_GEOM_HSHIFT, GAME_GEOM_ZOOM);
    }

}

#pragma stage fragment
layout(location = 0) noperspective in vec2 vTexCoord;
layout(location = 1) flat in float vLedBorder_min;
layout(location = 2) flat in float vLedBorder_max;
layout(location = 3) flat in float vLed_step;
layout(location = 4) flat in float lod;
layout(location = 5) noperspective in vec2 pre_pass_coords;
layout(location = 6) flat in float vIs_rotated;
layout(location = 7) flat in float vAMBI_STRETCH;

layout(location = 9) flat in float vSmpBorder_min;
layout(location = 10) flat in float vSmpBorder_max;
layout(location = 11) flat in float vSmp_step;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D PastSampler;
layout(set = 0, binding = 2) uniform sampler2D avglum_pass;
layout(set = 0, binding = 3) uniform sampler2D avglum_passFeedback;
layout(set = 0, binding = 4) uniform sampler2D colortools_and_ntsc_pass;
layout(set = 0, binding = 5) uniform sampler2D colortools_and_ntsc_passFeedback;
layout(set = 0, binding = 6) uniform sampler2D backdrop;


vec3 ambi_push_pass(vec2 coords, float f_lod) {
    vec2 smp_coords = coords;
    if (AUTOCROP_MAX > 0.0) {
        float autocrop_zoom = texture(avglum_pass, AUTOCROP_SAMPLING_POINT).a;
        smp_coords = zoom(smp_coords, autocrop_zoom);
    }
    
    vec3 pixel_out = textureLod(colortools_and_ntsc_pass, smp_coords, f_lod).rgb;

    if (DO_BACKDROP * BACKDROP_JUST_TUBE > 0.0) {
        vec4 backdrop_img = pixel_overlay_image_stretch(backdrop, coords);
        vec3 blended = (pixel_out.rgb + DO_BACKDROP) * backdrop_img.rgb;
        pixel_out = mix( pixel_out.rgb, blended, backdrop_img.a );
    }

    pixel_out = pow(pixel_out, vec3(AMBI_GAMMA)); 

    pixel_out = pixel_push_luminance(pixel_out, AMBI_POWER - 1);
    return pixel_out;
}


float fcircle_smooth(vec2 coords, vec2 middle, float f_radius, float FALLOFF) {
    float fdistance = distance(middle, vec2(coords.x, coords.y));
    return (1-smoothstep(f_radius-FALLOFF, f_radius+FALLOFF, fdistance));
}

#define tol_start 0.08 //skip tolerance
#define tol_end   1-tol_start



vec3 ambi_pre_pass(vec2 coords) {
    if (DO_TILT == 1.0)
        coords = tilt(coords, vIs_rotated, TILT_X);

    //Skip coords in the rect "under the tube"
   // if (is_first_inside_rect(coords, vec4(tol_start, tol_start, tol_end ,tol_end)))
   //     return vec3(0.0);
    vec2 skip_coords = coords;
    
    if (DO_GAME_GEOM_OVERRIDE > 0.5 )
        skip_coords = content_geom_override_zoom_inv(skip_coords, GAME_GEOM_ASPECT, get_in_aspect(), GAME_GEOM_VSHIFT, GAME_GEOM_HSHIFT, GAME_GEOM_ZOOM);
    
    if (is_first_inside_rect(skip_coords, vec4(tol_start, tol_start, tol_end ,tol_end)))
        return vec3(0.0);

    //Stretch the lights?
        float z1=distance(vec2(0.5,0.5), coords);
        vec2 zoomed_coords = zoomxy(coords, vec2(1+z1));
        coords = mix(coords, zoomed_coords, vAMBI_STRETCH*0.5);
        float lAMBI_FALLOFF = AMBI_FALLOFF + (z1 * vAMBI_STRETCH*0.5);

    //Finally, emulate leds.
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
    return pow(pixel_out, 1/vec3(1+vAMBI_STRETCH));
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


vec3 pixel_sanitize(vec3 color_in) {
    return clamp(color_in, vec3(0), vec3(10.0));
    //return max(color_in.rgb, vec3(0.0));
}

vec4 pixel_sanitize(vec4 color_in) {
    return clamp(color_in, vec4(0), vec4(10.0,10.0,10.0,1.0));
    //return max(color_in, vec4(0.0));
}


bool scene_changed() {
    vec3 present_color = textureLod(colortools_and_ntsc_pass, vec2(0.5), 20.0).rgb;
    vec3 past_color    = textureLod(colortools_and_ntsc_passFeedback, vec2(0.5), 20.0).rgb;
    float past_lum = rgb_to_gray(past_color);
    float present_lum = rgb_to_gray(present_color);
    float diff_lum = abs(past_lum - present_lum);
    return (diff_lum >= AMBI_SCENE_CHG_THRSHLD );
}


bool scene_changed_test() {
    vec3 present_color = textureLod(colortools_and_ntsc_pass, vec2(0.5), 20.0).rgb;
    vec3 past_color    = textureLod(colortools_and_ntsc_passFeedback, vec2(0.5), 20.0).rgb;
    
    float past_lum = rgb_to_gray(past_color);
    float present_lum = rgb_to_gray(present_color);
    
    float past_hue = rgb2hsv(past_color).x;
    float present_hue = rgb2hsv(present_color).x;
    float diff_hue = abs(past_hue - present_hue);
    float diff_lum = abs(past_lum - present_lum);
    
    float lum_weight = 1.0;
    float hue_weight = 0.0;
        
    float diff = diff_hue * hue_weight + diff_lum * lum_weight;
    
    
    float t = AMBI_SCENE_CHG_THRSHLD*(lum_weight+hue_weight);
    
    t=0.25;
    
    return (diff >= t );
}

vec4 pixel_ambilight(vec2 local_pre_pass_coords) {

    vec3 present_pixel =  ambi_pre_pass(local_pre_pass_coords).rgb;

    present_pixel.rgb = pixel_sanitize(present_pixel.rgb);
    
    if ( dot(global.colortools_and_ntsc_passSize.xy, vec2(1.0)) != dot(global.colortools_and_ntsc_passFeedbackSize.xy, vec2(1.0) ) ) {
        // Under vulkan, when the framebuffer chain is reconfigured (due to the source resolution changed?)
        // Feeedback status is unrlieble, so to avoid glitches, return current color.
        return vec4(present_pixel, 0.0);
    }
    
    vec4 past_pixel = texture(PastSampler, vTexCoord);    
    float scene_change_remaining = past_pixel.a;


    #ifndef D3D_WORKAROUND        
        if (scene_changed()) scene_change_remaining = 1/AMBI_FAST_STEP;
    #endif 
    
    // Are we changing scene?
    vec3 mystep;
    if (scene_change_remaining > 0.0) {
        mystep = vec3(max(1.0/MAX_STEPS, AMBI_FAST_STEP)); // <- Never slow down fades due to fast step when changing scene
        scene_change_remaining -=  AMBI_FAST_STEP;
    } else {
        mystep = abs((past_pixel.rgb - present_pixel) / MAX_STEPS); //OK
    }
        
    return vec4(ambi_step_rgb(past_pixel.rgb, present_pixel, mystep), scene_change_remaining);
}


void main() {
    if (DO_AMBILIGHT != 1.0) {
        //set alpha to 1.0 to produce a fast switch to ambientlight.
        FragColor = vec4(0,0,0,1);
        return;
    }

    FragColor = pixel_ambilight(pre_pass_coords);
}
