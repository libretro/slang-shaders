// See pixel_aa.slang for copyright and other information.

// clang-format off
#pragma parameter PIX_AA_SETTINGS "=== Pixel AA v1.1 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter PIX_AA_SHARP "Pixel AA sharpening amount" 1.5 0.0 4.0 0.05
#pragma parameter PIX_AA_GAMMA "Enable gamma-correct blending" 1.0 0.0 1.0 1.0
#pragma parameter PIX_AA_SUBPX "Enable subpixel AA" 1.0 0.0 1.0 1.0
#pragma parameter PIX_AA_SUBPX_BGR "Use BGR subpx. instead of RGB" 0.0 0.0 1.0 1.0
// clang-format on

// Similar to smoothstep, but has a configurable slope at x = 0.5.
// Original smoothstep has a slope of 1.5 at x = 0.5
#define INSTANTIATE_SLOPESTEP(T)                               \
    T slopestep(T edge0, T edge1, T x, float slope) {          \
        x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);    \
        const T s = sign(x - 0.5);                             \
        const T o = (1.0 + s) * 0.5;                           \
        return o - 0.5 * s * pow(2.0 * (o - s * x), T(slope)); \
    }
INSTANTIATE_SLOPESTEP(float)
INSTANTIATE_SLOPESTEP(vec2)

vec3 to_lin(vec3 x) { return pow(x, vec3(2.2)); }

vec3 to_srgb(vec3 x) { return pow(x, vec3(1.0 / 2.2)); }

// Params:
// pix_coord: Coordinate in source pixel (texel) coordinates
vec3 sample_aa(sampler2D tex, vec4 input_size, vec4 output_size, vec2 pix_coord,
               bool gamma_correct, float sharpness) {
    // The offset for interpolation is a periodic function with
    // a period length of 1 pixel in source pixel coordinates.
    // The input coordinate is shifted so that the center of the pixel
    // aligns with the start of the period.
    const vec2 pix_center = vec2(0.5);
    const vec2 pix_coord_shifted = pix_coord - pix_center;
    // Get the period and phase.
    vec2 period;
    const vec2 phase = modf(pix_coord_shifted, period);
    // Get texels per pixel
    const vec2 tx_per_pix = input_size.xy * output_size.zw;
    // The function starts at 0, then starts transitioning at
    // 0.5 - 0.5 / pixels_per_texel, then reaches 0.5 at 0.5,
    // Then reaches 1 at 0.5 + 0.5 / pixels_per_texel.
    // For sharpness values < 1.0, transition to bilinear filtering.
    const vec2 offset =
        slopestep(min(1.0, sharpness) * (0.5 - 0.5 * tx_per_pix),
                  1.0 - min(1.0, sharpness) * (1.0 - (0.5 + 0.5 * tx_per_pix)),
                  phase, max(1.0, sharpness));

    // With gamma correct blending, we have to do 4 taps and blend manually.
    // Without it, we can make use of a single tap using bilinear interpolation.
    if (gamma_correct) {
        const vec3 samples[] = {
            to_lin(texture(tex, (period + 0.5) * input_size.zw).rgb),
            to_lin(texture(tex, (period + vec2(1.5, 0.5)) * input_size.zw).rgb),
            to_lin(texture(tex, (period + vec2(0.5, 1.5)) * input_size.zw).rgb),
            to_lin(texture(tex, (period + 1.5) * input_size.zw).rgb)};
        return to_srgb(mix(mix(samples[0], samples[1], offset.x),
                           mix(samples[2], samples[3], offset.x), offset.y));
    } else {
        return texture(tex, (period + 0.5 + offset) * input_size.zw).rgb;
    }
}
