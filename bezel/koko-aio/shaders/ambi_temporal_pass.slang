#version 450

/* In this pass the led light is temporally smoothed to give smooth fades.
 * the slowness is configurable by user parameter.
 * It also detect when a full scene is changed to produces fast fades, instead
 */

#include "config.inc"

#define PreviousSampler ambi_temporal_passFeedback
#define CurrentSampler ambi_pre_pass1

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D CurrentSampler;
layout(set = 0, binding = 3) uniform sampler2D PreviousSampler;
layout(set = 0, binding = 4) uniform sampler2D avglum_pass;
layout(set = 0, binding = 5) uniform sampler2D avglum_passFeedback;
                                                                                    
#define MAX_STEPS AMBI_STEPS

float ambi_step(float start, float end, float mystep) {
    float diff = start-end;
    if (abs(diff) < mystep) return end;
    if (start >= end)
        return start - mystep;
            else
        return start + mystep;
}

vec3 ambi_step_rgb(vec3 s,vec3 d, vec3 mystep){
    //step fade (f) rom s to d
    return vec3 ( ambi_step(s.r,d.r,mystep.r),
                  ambi_step(s.g,d.g,mystep.g),
                  ambi_step(s.b,d.b,mystep.b)
                );
}


vec4 pixel_ambilight() {
    vec3 mystep;

    vec4 previous_pixel_vec4 = texture(PreviousSampler, vTexCoord);
    vec3 current_pixel =  texture(CurrentSampler, vTexCoord).rgb;
    vec3 previous_pixel = previous_pixel_vec4.rgb;

    float scene_change_remaining = previous_pixel_vec4.a;
    
    float prev_avg_lum = texture(avglum_passFeedback,vec2(0.25,0.25)).a;
    float curr_avg_lum = texture(avglum_pass        ,vec2(0.25,0.25)).a;
    float diff_avg_lum = abs(prev_avg_lum - curr_avg_lum);

    if (diff_avg_lum >= AMBI_SCENE_CHG_THRSHLD) {
        scene_change_remaining = 1.0;
    }

    // Are we changing scene?
    if (scene_change_remaining > 0.0) {
        mystep = vec3(max(1.0/MAX_STEPS, AMBI_FAST_STEP)); // <- Never slow down fades due to fast step when changing scene
        scene_change_remaining -=  AMBI_FAST_STEP;
            } else {
        mystep = abs((previous_pixel-current_pixel) / MAX_STEPS);
        
    }
    return vec4(ambi_step_rgb(previous_pixel,current_pixel,mystep),scene_change_remaining);

}

void main() {
    if (DO_AMBILIGHT != 1.0) return;
    
    FragColor = pixel_ambilight();
}
