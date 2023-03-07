#version 450

/* In this pass we calculate the average luminance of the scene.
 * It is cheaply obtained by the use of mipmaps. */

#include "config.inc"

//The mipmap wideness needed by the highlights on the bezel.
//the higher, the smoother.
#define mip_lod 5

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float lod;

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;  
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float lod;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D first_pass;
layout(set = 0, binding = 3) uniform sampler2D avglum_passFeedback;

/* The following will allow to sample at reduced interval
   The scene change detection logic will take advantage of it
   So that quick fades will still be treated as scene changes
*/
// #define avglum_divider 4  <-- in config.inc

#include "includes/functions.include.slang"


#define RGB_TO_GRAYSCALE = vec3(0.299, 0.587, 0.114)
float get_avg_lum_from_mip() {
    vec3 mip = textureLod(first_pass, vec2(0.5,0.5),20.0).rgb;
    mip = apply_fuzzy_main_pass(mip);
    //return (mip.r+mip.g+mip.b)/3.0;
    return rgb_to_gray(mip);
}


//0.1 seems like a good tradeoff that works well with bloom exposire and fullscreen zoom
//...maybe bloom exposure works best at 0.05; you may consider another zone of smooth sampling.
#define SMOOTHNESS_SPEED 0.1

float get_avglum() {
    /* avglum alpha has 3 zones::
     * 0.25 -> reduced sampling, used for to aid scene detection
     * 0.75 -> smoothed_sampling, used to adapt fullscreen zoom
     * anything else: continuous sampling
     */


    bool reduced_sampling_co =
            vTexCoord.x > 0.24 && vTexCoord.x < 0.26 &&
            vTexCoord.y > 0.24 && vTexCoord.y < 0.26 ;

    bool smoothed_sampling_co =
            vTexCoord.x > 0.74 && vTexCoord.x < 0.76 &&
            vTexCoord.y > 0.74 && vTexCoord.y < 0.76 ;


    if (reduced_sampling_co) {
        //in the reduced sampling zone, only update at right time; else return the previous frame.
        bool reduced_sample_time_is_now = (mod(params.FrameCount,AMBI_AVGLUM_DIVIDER) == 0);
        if (reduced_sample_time_is_now)
            return get_avg_lum_from_mip();
        float avglum_feedback = texture(avglum_passFeedback,vTexCoord).a;
        avglum_feedback = max(avglum_feedback, 0.0); // <- Sanitize input to avoid glitches when enabling the option runtime.
        return avglum_feedback;
    }

    if (smoothed_sampling_co) {
        return mix(texture(avglum_passFeedback,vTexCoord).a, get_avg_lum_from_mip(), SMOOTHNESS_SPEED);
    }

    //Outside specific areas, update continuously; this is used by bezel highlights.
    return get_avg_lum_from_mip();

}

void main() {
    /*Grab a mipmap from the first pass.
      Calculate the average luminance from the smallest mipmap and put into the alpha channel
      So that can be used:
      1 - continuously at coordinate 0.5,0.5
      2 - sampled less often for scene detection logic at coordinate 0.25,0.25
      Put another small mipmap into the rgb channel to be used by the reflection code.
    */
    //FIXME: see which is faster:
    //if (DO_AMBILIGHT == 1.0 || DO_BEZEL == 1.0 || DO_DYNZOOM == 1.0) {
    if ( DO_AMBILIGHT + DO_BEZEL + DO_DYNZOOM + DO_BLOOM == 0 ) return;
    
    vec4 pixel_out;
    pixel_out.a = get_avglum();
    if (DO_BEZEL + DO_BLOOM > 0.0) {
        //Create a small mipmap to be used to light the bezel corners.
        pixel_out.rgb = textureLod(first_pass, vTexCoord, mip_lod).rgb;
    }
    FragColor = pixel_out;

}
