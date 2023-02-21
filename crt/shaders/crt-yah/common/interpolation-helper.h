#ifndef INTERPOLATION_HELPER

#define INTERPOLATION_HELPER

#define EPSILON 1e-6

// Gets the texture coordinates for sharp bi-linear filtering, when the texture is filtered bi-linear.
// @tex_coord: the original texture coordinate
// @source_size: the size of the input sampler
// @output_size: the size of the output target
// Remarks: Based on the sharp bi-linear shader by The Maister.
vec2 sharp_bilinear(vec2 tex_coord, vec2 source_size, vec2 output_size)
{
    vec2 texel = tex_coord * source_size;

    // figure out where in the texel to sample to get correct pre-scaled bilinear
    float scale = floor(output_size.y / source_size.y + EPSILON);
    float region_range = 0.5 - 0.5 / scale;
    vec2 center_distance = fract(texel) - 0.5;
    vec2 fraction = (center_distance - clamp(center_distance, -region_range, region_range)) * scale + 0.5;

    vec2 sharp_texel = floor(texel) + fraction;

    return sharp_texel / source_size;
}

#endif // INTERPOLATION_HELPER
