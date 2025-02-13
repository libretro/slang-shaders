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

layout(set = 0, binding = 1) uniform sampler2D colortools_and_ntsc_pass;

#include "includes/blooms.include.slang"

vec3 bloom_gamma_power2(sampler2D smp, vec2 uv, vec4 smpsize, float gamma) {
    const vec2 d = smpsize.zw;
    vec3 color = vec3(0.0);
    vec3 lookup;
    const vec3 vec3gamma = vec3(gamma);
    lookup = textureLod(smp, uv + vec2(-1,-1) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    lookup = textureLod(smp, uv + vec2(-1, 0) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    lookup = textureLod(smp, uv + vec2(-1,+1) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    lookup = textureLod(smp, uv + vec2( 0,-1) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    lookup = textureLod(smp, uv + vec2( 0, 0) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    lookup = textureLod(smp, uv + vec2( 0,+1) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    lookup = textureLod(smp, uv + vec2(+1,-1) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    lookup = textureLod(smp, uv + vec2(+1, 0) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    lookup = textureLod(smp, uv + vec2(+1,+1) * d, 0).rgb; color +=pow(lookup.rgb, vec3gamma);
    return color/(9.0);
}

void main() {
    if (DO_BLOOM == 0.0) return;
    //vec3 bloom_gamma_power2(sampler2D smp, vec2 uv, vec4 smpsize, float gamma) {
    vec3 bloomed = bloom_gamma_power2( colortools_and_ntsc_pass, vTexCoord, params.OriginalSize, BLOOM_GAMMA);
    bloomed = apply_fuzzy_main_pass_stage_2(bloomed, vFuzzy_main_pass_stage_1);
    FragColor.rgb = bloomed;
}
