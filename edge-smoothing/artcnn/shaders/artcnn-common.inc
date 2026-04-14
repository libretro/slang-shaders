ivec2 artcnn_output_pixel(vec2 output_size)
{
    ivec2 size_i = ivec2(output_size);
    ivec2 pixel = ivec2(floor(gl_FragCoord.xy));
    return clamp(pixel, ivec2(0), size_i - ivec2(1));
}

bool artcnn_in_bounds(ivec2 coord, vec2 texture_size)
{
    ivec2 size_i = ivec2(texture_size);
    return all(greaterThanEqual(coord, ivec2(0))) && all(lessThan(coord, size_i));
}

float artcnn_fetch_scalar(sampler2D tex, vec4 tex_size, ivec2 pos)
{
    return artcnn_in_bounds(pos, tex_size.xy) ? texelFetch(tex, pos, 0).x : 0.0;
}

vec4 artcnn_fetch4(sampler2D tex, vec4 tex_size, ivec2 pos)
{
    return artcnn_in_bounds(pos, tex_size.xy) ? texelFetch(tex, pos, 0) : vec4(0.0);
}
