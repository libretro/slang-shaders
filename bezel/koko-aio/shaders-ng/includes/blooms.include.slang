#define bdirections 8

vec3 bloom_gamma(sampler2D smp, vec2 uv, vec4 smpsize, vec2 bsize, float quality, float gamma, float start_offset, float lod) {
    vec3 color = vec3(0.0);
    const vec3 g = vec3(gamma);

    float step_d = TAU / bdirections;
    float step_i = 1.0 / quality;

    for (float d = start_offset; d < TAU; d += step_d) {
        vec2 dir = vec2(cos(d), sin(d)) * bsize;
        for (float i = step_i; i <= 1.0; i += step_i)
            color += pow(textureLod(smp, uv + dir * i, lod).rgb, g);
    }

    return color * (step_i / bdirections);
}

vec3 bloom_gamma_power(sampler2D smp, vec2 uv, vec4 smpsize, vec2 bsize, float quality, float gamma, float power, float start_offset, float lod) {
    vec3 color = vec3(0.0);
    const vec3 g = vec3(gamma);

    float step_d = TAU / bdirections;
    float step_i = 1.0 / quality;

    for (float d = start_offset; d < TAU; d += step_d) {
        vec2 dir = vec2(cos(d), sin(d)) * bsize;
        for (float i = step_i; i <= 1.0; i += step_i)
            color += pow(textureLod(smp, uv + dir * i, lod).rgb, g);
    }

    return color * (step_i / bdirections * power);
}


vec3 bloom(sampler2D smp, vec2 uv, vec4 smpsize, vec2 bsize, float quality, float start_offset, float lod) {
    vec3 color = vec3(0.0);
    float step_d = TAU / bdirections;   // costante fuori da tutto
    float step_i = 1.0 / quality;       // costante fuori da tutto
    for (float d = start_offset; d < TAU; d += step_d) {
        vec2 dir = vec2(cos(d), sin(d)) * bsize;  // ← fuori dal loop interno
        for (float i = step_i; i <= 1.0; i += step_i) {
            color += textureLod(smp, uv + dir * i, lod).rgb;
        }
    }
    return color * (step_i / bdirections); // /quality*bdirections → *precomputed
}
