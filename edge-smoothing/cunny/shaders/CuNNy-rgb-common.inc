ivec2 cunny_output_pixel(vec2 output_size)
{
    ivec2 size_i = ivec2(output_size);
    ivec2 pixel = ivec2(floor(gl_FragCoord.xy));
    return clamp(pixel, ivec2(0), size_i - ivec2(1));
}

ivec2 cunny_clamp_coord(ivec2 coord, vec2 texture_size)
{
    ivec2 size_i = ivec2(texture_size);
    return clamp(coord, ivec2(0), size_i - ivec2(1));
}

ivec2 cunny_macro_coord(ivec2 pos, vec2 texture_size, ivec2 delta, ivec2 phase, ivec2 macro_grid)
{
    ivec2 safe_grid = max(macro_grid, ivec2(1));
    ivec2 logical_size = max(ivec2(texture_size) / safe_grid, ivec2(1));
    ivec2 logical = clamp(pos + delta, ivec2(0), logical_size - ivec2(1));
    ivec2 tile = clamp(phase, ivec2(0), safe_grid - ivec2(1));
    return tile * logical_size + logical;
}

vec4 cunny_fetch4(sampler2D tex, vec4 tex_size, ivec2 pos, ivec2 delta)
{
    return texelFetch(tex, cunny_clamp_coord(pos + delta, tex_size.xy), 0);
}

float cunny_fetch_scalar(sampler2D tex, vec4 tex_size, ivec2 pos, ivec2 delta)
{
    return texelFetch(tex, cunny_clamp_coord(pos + delta, tex_size.xy), 0).x;
}

float cunny_fetch_luma(sampler2D tex, vec4 tex_size, ivec2 pos, ivec2 delta)
{
    vec3 rgb = texelFetch(tex, cunny_clamp_coord(pos + delta, tex_size.xy), 0).rgb;
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

vec3 cunny_fetch3(sampler2D tex, vec4 tex_size, ivec2 pos, ivec2 delta)
{
    return texelFetch(tex, cunny_clamp_coord(pos + delta, tex_size.xy), 0).rgb;
}

vec4 cunny_fetch_macro4(sampler2D tex, vec4 tex_size, ivec2 pos, ivec2 delta, ivec2 phase, ivec2 macro_grid)
{
    return texelFetch(tex, cunny_macro_coord(pos, tex_size.xy, delta, phase, macro_grid), 0);
}

float cunny_fetch_macro_scalar(sampler2D tex, vec4 tex_size, ivec2 pos, ivec2 delta, ivec2 phase, ivec2 macro_grid)
{
    return texelFetch(tex, cunny_macro_coord(pos, tex_size.xy, delta, phase, macro_grid), 0).x;
}

float cunny_fetch_macro_luma(sampler2D tex, vec4 tex_size, ivec2 pos, ivec2 delta, ivec2 phase, ivec2 macro_grid)
{
    vec3 rgb = texelFetch(tex, cunny_macro_coord(pos, tex_size.xy, delta, phase, macro_grid), 0).rgb;
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

vec3 cunny_fetch_macro3(sampler2D tex, vec4 tex_size, ivec2 pos, ivec2 delta, ivec2 phase, ivec2 macro_grid)
{
    return texelFetch(tex, cunny_macro_coord(pos, tex_size.xy, delta, phase, macro_grid), 0).rgb;
}

float cunny_phase_component(vec4 v, ivec2 phase)
{
    int index = phase.y * 2 + phase.x;
    if (index == 0) return v.x;
    if (index == 1) return v.y;
    if (index == 2) return v.z;
    return v.w;
}

vec3 cunny_manual_bilinear_rgb(sampler2D tex, vec4 tex_size, ivec2 output_pixel, vec2 output_size)
{
    vec2 source_pos = ((vec2(output_pixel) + vec2(0.5)) * (tex_size.xy / output_size)) - vec2(0.5);
    ivec2 base = ivec2(floor(source_pos));
    vec2 frac = clamp(source_pos - vec2(base), vec2(0.0), vec2(1.0));

    vec3 c00 = texelFetch(tex, cunny_clamp_coord(base + ivec2(0, 0), tex_size.xy), 0).rgb;
    vec3 c10 = texelFetch(tex, cunny_clamp_coord(base + ivec2(1, 0), tex_size.xy), 0).rgb;
    vec3 c01 = texelFetch(tex, cunny_clamp_coord(base + ivec2(0, 1), tex_size.xy), 0).rgb;
    vec3 c11 = texelFetch(tex, cunny_clamp_coord(base + ivec2(1, 1), tex_size.xy), 0).rgb;

    vec3 top = mix(c00, c10, frac.x);
    vec3 bottom = mix(c01, c11, frac.x);
    return mix(top, bottom, frac.y);
}

float cunny_manual_bilinear_scalar(sampler2D tex, vec4 tex_size, ivec2 output_pixel, vec2 output_size)
{
    vec2 source_pos = ((vec2(output_pixel) + vec2(0.5)) * (tex_size.xy / output_size)) - vec2(0.5);
    ivec2 base = ivec2(floor(source_pos));
    vec2 frac = clamp(source_pos - vec2(base), vec2(0.0), vec2(1.0));

    float c00 = texelFetch(tex, cunny_clamp_coord(base + ivec2(0, 0), tex_size.xy), 0).x;
    float c10 = texelFetch(tex, cunny_clamp_coord(base + ivec2(1, 0), tex_size.xy), 0).x;
    float c01 = texelFetch(tex, cunny_clamp_coord(base + ivec2(0, 1), tex_size.xy), 0).x;
    float c11 = texelFetch(tex, cunny_clamp_coord(base + ivec2(1, 1), tex_size.xy), 0).x;

    float top = mix(c00, c10, frac.x);
    float bottom = mix(c01, c11, frac.x);
    return mix(top, bottom, frac.y);
}

#define M4 CUNNY_M4
#define M3x4 CUNNY_M3X4
#define mul(v, m) ((m) * (v))
#define saturate(x) clamp(x, 0.0, 1.0)
#define CUNNY_M4(a0, a1, a2, a3, b0, b1, b2, b3, c0, c1, c2, c3, d0, d1, d2, d3) mat4(a0, a1, a2, a3, b0, b1, b2, b3, c0, c1, c2, c3, d0, d1, d2, d3)
#define CUNNY_M3X4(a0, a1, a2, a3, b0, b1, b2, b3, c0, c1, c2, c3) mat3x4(a0, a1, a2, a3, b0, b1, b2, b3, c0, c1, c2, c3)
