#version 450

// This is one of several passes needed to cheaply emulate the bloom effect.

#include "config.inc"
#include "includes/functions.include.slang"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) noperspective out vec2 vTexCoord;
layout(location = 1) flat out vec2 vFuzzy_main_pass_stage_1;
layout(location = 5) flat out vec2 blur_radius_adpt;


void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    blur_radius_adpt = radius_blur_adapt(BLOOM_SIZE);
    
    //Get fuzzy mul and pow factor
    vFuzzy_main_pass_stage_1 = apply_fuzzy_main_pass_stage_1();
}

#pragma stage fragment

layout(location = 0) noperspective in vec2 vTexCoord;
layout(location = 1) flat in vec2 vFuzzy_main_pass_stage_1;
layout(location = 5) flat in vec2 blur_radius_adpt;
 
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D colortools_and_ntsc_pass;

#include "includes/blooms.include.slang"

vec3 bloom_gamma_power2(sampler2D smp, vec2 uv, vec4 smpsize, float gamma) {
    const vec2 d = smpsize.zw;
    const vec3 g = vec3(gamma);

    vec2 uv_minus_d = uv - d;
    vec2 uvC = uv;
    vec2 uv_plus_d = uv + d;

    vec3 c = pow(textureLod(smp, vec2(uv_minus_d.x, uv_minus_d.y), 0).rgb, g)
           + pow(textureLod(smp, vec2(uv_minus_d.x, uvC.y), 0).rgb, g)
           + pow(textureLod(smp, vec2(uv_minus_d.x, uv_plus_d.y), 0).rgb, g)
           + pow(textureLod(smp, vec2(uvC.x, uv_minus_d.y), 0).rgb, g)
           + pow(textureLod(smp, vec2(uvC.x, uvC.y), 0).rgb, g)
           + pow(textureLod(smp, vec2(uvC.x, uv_plus_d.y), 0).rgb, g)
           + pow(textureLod(smp, vec2(uv_plus_d.x, uv_minus_d.y), 0).rgb, g)
           + pow(textureLod(smp, vec2(uv_plus_d.x, uvC.y), 0).rgb, g)
           + pow(textureLod(smp, vec2(uv_plus_d.x, uv_plus_d.y), 0).rgb, g);

    return c * (1.0 / 9.0);
}

void main() {
    if (DO_BLOOM == 0.0) return;
    //vec3 bloom_gamma_power2(sampler2D smp, vec2 uv, vec4 smpsize, float gamma) {
    vec3 bloomed = bloom_gamma_power2( colortools_and_ntsc_pass, vTexCoord, params.OriginalSize, BLOOM_GAMMA);
    bloomed = apply_fuzzy_main_pass_stage_2(bloomed, vFuzzy_main_pass_stage_1);
    FragColor.rgb = bloomed;
}
