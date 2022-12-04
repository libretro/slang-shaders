#include "pows.include.slang"
#define Pi2 6.283
#define bloom_directions 8

#define b_offset_x -0.05 //Why is this needed by bloom?

#define bdirections 8

vec3 bloom(sampler2D smp, vec2 uv, vec4 smpsize, vec2 dest_size, float quality, float gamma, float start_offset, float lod) {
    vec2 r = dest_size/smpsize.xy ;
    vec3 lookup;
    vec3 color  = vec3(0.0,0.0,0.0);
    float steps=0.0;

    for( float d=start_offset; d<Pi2; d+=Pi2/bdirections) {
        for(float i=1.0/quality; i<=1.0; i+=1.0/quality) {
            lookup = textureLod(smp, uv + vec2( cos(d), sin(d)) * r * i, lod ).rgb ;
            color +=pow(lookup.rgb,vec3(gamma));
        }
    }
    color /= (quality*bdirections);
    return color;
}
