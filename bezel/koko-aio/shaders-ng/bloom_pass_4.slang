#version 450

// This is one of several passes needed to cheaply emulate the bloom effect.

#include "config.inc"
#include "includes/functions.include.slang"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vFuzzy_main_pass_stage_1;
layout(location = 5) out vec2 blur_radius_adpt;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    blur_radius_adpt = radius_blur_adapt(BLOOM_SIZE);

    //Get fuzzy mul and pow factor
    vFuzzy_main_pass_stage_1 = apply_fuzzy_main_pass_stage_1();

}

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vFuzzy_main_pass_stage_1;
layout(location = 5) in vec2 blur_radius_adpt;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D Source;
layout(set = 0, binding = 2) uniform sampler2D colortools_and_ntsc_pass;
layout(set = 0, binding = 5) uniform sampler2D avglum_pass;

#include "includes/blooms.include.slang"

#define offset 0.5890486225480862 // TAU/8.0/4.0*3.0

//The curve shoulder to map scene luminance to bloom mix strength
#define BLOOM_PUPIL_EXPOSURE_CURVE_SHOULDER 0.33

//How big is the zone in which the luminance will be computed for puple temporal adaption (range 2..20)
#define BLOOM_PUPIL_LUM_ZONE_W 6

float get_avg_lum_from_mip(sampler2D tex, vec2 co, float lod) {
    vec3 mip = textureLod(colortools_and_ntsc_pass, co, lod).rgb;
    mip = apply_fuzzy_main_pass_stage_2(mip, vFuzzy_main_pass_stage_1);
    return rgb_to_gray(mip) + eps;
}


vec3 get_halation(sampler2D mip_texture, vec4 mip_textureSize, vec2 co) {
    //too much lod will cause halation to be visible only when there are wide solid areas (outrun)
    //a lower low will allow to "colorize" smaller parts too
    //too much low lod will produce visible artifacts.
    float halation_lod = 6.0;

        
    //sample and blur mip to clear artifacts:
    vec2 mipsize = mip_textureSize.zw * pow(2, halation_lod) * 1.0;
    vec3 h0 = textureLod(mip_texture, co , halation_lod).rgb;
    vec3 h1 = textureLod(mip_texture, co + vec2(0.0,mipsize.y) , halation_lod).rgb;
    vec3 h2 = textureLod(mip_texture, co + vec2(0.0,-mipsize.y) , halation_lod).rgb;
    vec3 h3 = textureLod(mip_texture, co + vec2(mipsize.x, 0.0) , halation_lod).rgb;
    vec3 h4 = textureLod(mip_texture, co + vec2(-mipsize.x, 0.0) , halation_lod).rgb;
    vec3 halation = (h1+h2+h3+h4)/4.0;

    /*vec3 h5 = textureLod(mip_textureFeedback, co + vec2(mipsize.x, mipsize.y) , halation_lod).rgb;
    vec3 h6 = textureLod(mip_textureFeedback, co + vec2(mipsize.x,-mipsize.y) , halation_lod).rgb;
    vec3 h7 = textureLod(mip_textureFeedback, co + vec2(-mipsize.x,mipsize.y) , halation_lod).rgb;
    vec3 h8 = textureLod(mip_textureFeedback, co + vec2(-mipsize.x,-mipsize.y) , halation_lod).rgb;
    vec3 halation = (h1+h2+h3+h4+h5+h6+h7+h8)/8.0;*/

    //make it colorful
    halation = pow(halation, vec3(4.0));
    halation = pixel_push_luminance(halation, 1.5);

    float lum = max3(textureLod(colortools_and_ntsc_pass, vTexCoord, 7.0).rgb ); //  texture(avglum_pass, vec2(0.5)).a;
    float halation_mix_adapted = BLOOM_HALATION_MIX  * mix(1.0, 0.125, pow(lum, 0.5));
    halation*=halation_mix_adapted;


    
/*  halation = pow(halation, vec3(4.0));
    halation = pixel_push_luminance(halation, 1.5);   
    
    float s_source = saturation_get(halation) ;
    float sat_source_k = mix(1.0, 4.0, s_source);
    
    float s_target = saturation_get(textureLod(colortools_and_ntsc_pass, vTexCoord, 6.0).rgb);
    float sat_target_k = mix(1.0, 0.25, s_target ); //don't oversturate

    
    float lum_target = max3(textureLod(colortools_and_ntsc_pass, vTexCoord, 7.0).rgb );
    float lum_target_k = mix(1,0.125, pow(lum_target, 0.5)); //don't clip

    halation = halation * BLOOM_HALATION_MIX * sat_source_k * sat_target_k * min(sat_target_k,lum_target_k);
*/
    
    return halation;
}

void main() {
  
    vec3 bloomed = bloom(
        Source,
        vTexCoord,
        params.SourceSize,
        blur_radius_adpt,
        BLOOM_QUALITY,
        offset,
        0.0
    );
    

    bloomed = pow(bloomed,vec3(BLOOM_GAMMA_OUT));
    bloomed = pixel_push_luminance(bloomed, BLOOM_POWER);
    
    bloomed*=BLOOM_POWER;
    
    // Modulate exposure over time too.
    //Smooth luminance with specified lod in this alpha channel
    // (Branching with (if BLOOM_EYE_ADPT_SRT == 0.0) does not gain anything.)
    float zone_luminance = get_avg_lum_from_mip(colortools_and_ntsc_pass, vTexCoord, BLOOM_PUPIL_LUM_ZONE_W);
    float smoothed_avglum = zone_luminance * BLOOM_EYE_ADPT_SRT;
    float bloom_mix_adapted = max(0.0, BLOOM_MIX - smoothed_avglum);
        
    float pow_exp = BLOOM_PUPIL_EXPOSURE_CURVE_SHOULDER - smoothed_avglum * BLOOM_PUPIL_EXPOSURE_CURVE_SHOULDER;
    pow_exp = max(0.0, pow_exp); //avoid negative exps.
    bloom_mix_adapted = BLOOM_MIX * ( 1- pow(smoothed_avglum, pow_exp) );
    bloomed = soft_limiter01_chroma_safe(bloomed, bloom_mix_adapted, BLOOM_SOFT_LIMITER);
    
    //Halation
    vec3 halation = vec3(0.0);
    if (!bdelta_render_enabled())
        halation = get_halation(colortools_and_ntsc_pass, global.colortools_and_ntsc_passSize, vTexCoord);
        
    bloomed = max(bloomed,halation);

    
    FragColor.rgb = bloomed;    
}
