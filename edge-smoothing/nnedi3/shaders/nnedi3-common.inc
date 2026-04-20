float nnedi3_core(vec4 samples[8]);

float nnedi3_fetch_component(float dx, float dy, int comp)
{
    return texture(Source, vTexCoord.xy + (vec2(dx, dy) / params.SourceSize.xy))[comp];
}

float nnedi3_scalar(int comp)
{
    vec2 output_pixel = floor(vTexCoord.xy * params.OutputSize.xy);
    vec4 samples[8];
#if NNEDI3_VERTICAL
    if (mod(output_pixel.y, 2.0) == 0.0) {
        return texture(Source, vTexCoord.xy)[comp];
    }
    samples[0] = vec4(nnedi3_fetch_component(-3.0, -1.5, comp), nnedi3_fetch_component(-2.0, -1.5, comp), nnedi3_fetch_component(-1.0, -1.5, comp), nnedi3_fetch_component(0.0, -1.5, comp));
    samples[1] = vec4(nnedi3_fetch_component(1.0, -1.5, comp), nnedi3_fetch_component(2.0, -1.5, comp), nnedi3_fetch_component(3.0, -1.5, comp), nnedi3_fetch_component(4.0, -1.5, comp));
    samples[2] = vec4(nnedi3_fetch_component(-3.0, -0.5, comp), nnedi3_fetch_component(-2.0, -0.5, comp), nnedi3_fetch_component(-1.0, -0.5, comp), nnedi3_fetch_component(0.0, -0.5, comp));
    samples[3] = vec4(nnedi3_fetch_component(1.0, -0.5, comp), nnedi3_fetch_component(2.0, -0.5, comp), nnedi3_fetch_component(3.0, -0.5, comp), nnedi3_fetch_component(4.0, -0.5, comp));
    samples[4] = vec4(nnedi3_fetch_component(-3.0, 0.5, comp), nnedi3_fetch_component(-2.0, 0.5, comp), nnedi3_fetch_component(-1.0, 0.5, comp), nnedi3_fetch_component(0.0, 0.5, comp));
    samples[5] = vec4(nnedi3_fetch_component(1.0, 0.5, comp), nnedi3_fetch_component(2.0, 0.5, comp), nnedi3_fetch_component(3.0, 0.5, comp), nnedi3_fetch_component(4.0, 0.5, comp));
    samples[6] = vec4(nnedi3_fetch_component(-3.0, 1.5, comp), nnedi3_fetch_component(-2.0, 1.5, comp), nnedi3_fetch_component(-1.0, 1.5, comp), nnedi3_fetch_component(0.0, 1.5, comp));
    samples[7] = vec4(nnedi3_fetch_component(1.0, 1.5, comp), nnedi3_fetch_component(2.0, 1.5, comp), nnedi3_fetch_component(3.0, 1.5, comp), nnedi3_fetch_component(4.0, 1.5, comp));
#else
    if (mod(output_pixel.x, 2.0) == 0.0) {
        return texture(Source, vTexCoord.xy)[comp];
    }
    samples[0] = vec4(nnedi3_fetch_component(-1.5, -3.0, comp), nnedi3_fetch_component(-1.5, -2.0, comp), nnedi3_fetch_component(-1.5, -1.0, comp), nnedi3_fetch_component(-1.5, 0.0, comp));
    samples[1] = vec4(nnedi3_fetch_component(-1.5, 1.0, comp), nnedi3_fetch_component(-1.5, 2.0, comp), nnedi3_fetch_component(-1.5, 3.0, comp), nnedi3_fetch_component(-1.5, 4.0, comp));
    samples[2] = vec4(nnedi3_fetch_component(-0.5, -3.0, comp), nnedi3_fetch_component(-0.5, -2.0, comp), nnedi3_fetch_component(-0.5, -1.0, comp), nnedi3_fetch_component(-0.5, 0.0, comp));
    samples[3] = vec4(nnedi3_fetch_component(-0.5, 1.0, comp), nnedi3_fetch_component(-0.5, 2.0, comp), nnedi3_fetch_component(-0.5, 3.0, comp), nnedi3_fetch_component(-0.5, 4.0, comp));
    samples[4] = vec4(nnedi3_fetch_component(0.5, -3.0, comp), nnedi3_fetch_component(0.5, -2.0, comp), nnedi3_fetch_component(0.5, -1.0, comp), nnedi3_fetch_component(0.5, 0.0, comp));
    samples[5] = vec4(nnedi3_fetch_component(0.5, 1.0, comp), nnedi3_fetch_component(0.5, 2.0, comp), nnedi3_fetch_component(0.5, 3.0, comp), nnedi3_fetch_component(0.5, 4.0, comp));
    samples[6] = vec4(nnedi3_fetch_component(1.5, -3.0, comp), nnedi3_fetch_component(1.5, -2.0, comp), nnedi3_fetch_component(1.5, -1.0, comp), nnedi3_fetch_component(1.5, 0.0, comp));
    samples[7] = vec4(nnedi3_fetch_component(1.5, 1.0, comp), nnedi3_fetch_component(1.5, 2.0, comp), nnedi3_fetch_component(1.5, 3.0, comp), nnedi3_fetch_component(1.5, 4.0, comp));
#endif
    return nnedi3_core(samples);
}