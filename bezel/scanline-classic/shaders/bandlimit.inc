// Shared bandlimit utilities (Gaussian lobe-based 1D convolution)
// Requires: common.h (gaussian3), GLSL 450+ context

// Perform horizontal Gaussian bandlimit via lobe summation.
// - vTexCoord: normalized texture coordinates (0..1)
// - OutputSize: vec4(width, height, 1/width, 1/height)
// - Source: sampler2D of the source image
// - sigma: per-channel Gaussian standard deviations in texel units (uv domain)
// Returns filtered RGB color.
vec3 bandlimit_convolve_gaussian_x(vec2 vTexCoord, vec4 OutputSize, sampler2D Source, vec3 sigma)
{
    vec2 UV = vTexCoord * OutputSize.xy;

    // Nearest pixel center
    float baseIndex = floor(UV.x + 0.5);              // rounds to nearest integer
    float baseCenter = (baseIndex + 0.5);              // pixel center in pixel units
    float Ax = UV.x - baseCenter;                      // offset in [-0.5, 0.5]
    
    float baseX = baseCenter * OutputSize.z;
    float baseY = (floor(UV.y) + 0.5) * OutputSize.w;
    vec2 Tex = vec2(baseX, baseY);

    vec3 color = vec3(0.0);
    vec3 wsum  = vec3(0.0);
    vec2 dx = vec2(OutputSize.z, 0.0);

    // Central pixel: distance = Ax
    vec3 pixel = texture(Source, Tex).rgb;
    vec3 w0 = gaussian3(Ax, sigma);
    color = w0 * pixel;
    wsum  = w0;

    const float THRESHOLD = 1.0 / 255.0;

    for (int n = 1; n <= 16; ++n) {
        float nf = float(n);

        // Correct symmetric distances
        vec3 wr = gaussian3(nf - Ax, sigma); // right
        vec3 wl = gaussian3(nf + Ax, sigma); // left

        if (all(lessThan(wr, vec3(FILTER_THRESHOLD))) &&
            all(lessThan(wl, vec3(FILTER_THRESHOLD))))
            break;

        vec3 pr = texture(Source, Tex + nf * dx).rgb;
        vec3 pl = texture(Source, Tex - nf * dx).rgb;

        color += wr * pr + wl * pl;
        wsum  += wr + wl;
    }

    return color / wsum;
}