#version 450

/* In this pass we calculate the average luminance of the scene.
 * It is cheaply obtained by the use of mipmaps. */

#include "config.inc"

//The mipmap wideness needed by the reflection on the bezel.
#define min_w 16 

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float lod;

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   lod = log2(params.SourceSize.y / min_w);
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

float get_avg_lum_from_mip() {
    vec3 mip = textureLod(first_pass, vec2(0.5,0.5),20.0).rgb;
    mip = apply_fuzzy_main_pass(mip);
    return (mip.r+mip.g+mip.b)/3.0;
}

float get_avglum() {
    bool coordinate_for_scene_detection = 
            vTexCoord.x > 0.24 && vTexCoord.x < 0.26 &&
            vTexCoord.y > 0.24 && vTexCoord.y < 0.26 ;
            
    bool reduced_sample_time_is_now = (mod(params.FrameCount,AMBI_AVGLUM_DIVIDER) == 0);

    if (!coordinate_for_scene_detection) return get_avg_lum_from_mip();
    if (reduced_sample_time_is_now)      return get_avg_lum_from_mip();
    if (coordinate_for_scene_detection && reduced_sample_time_is_now) return get_avg_lum_from_mip();
    
    /* Implicit else: we are in a coordinate that is not used for scene detection
     * So just return the feedback of this pass to spare gpu cycles. */
    return texture(avglum_passFeedback,vTexCoord).a;
}

void main() {
    /*Grab a mipmap from the previous pass.
      Calculate the average luminance from the smallest mipmap and put into the alpha channel
      So that can be used:
      1 - continuously at coordinate 0.5,0.5
      2 - sampled less often for scene detection logic at coordinate 0.25,0.25
      Put another small mipmap into the rgb channel to be used by the reflection code.
    */
    //FIXME: see which is faster:
    //if (DO_AMBILIGHT == 1.0 || DO_BEZEL == 1.0 || DO_DYNZOOM == 1.0) {
    if ( DO_AMBILIGHT + DO_BEZEL + DO_DYNZOOM == 0 ) return;
    
    vec4 pixel_out;
    pixel_out.a = get_avglum();
    if (DO_BEZEL == 1.0) {
        //Create a small mipmap to be used to light the bezel corners.
        pixel_out.rgb = textureLod(first_pass, vTexCoord,lod).rgb;
    }
    FragColor = pixel_out;

     
}
