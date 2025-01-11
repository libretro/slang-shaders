// See main shader file for copyright and other information.

// Similar to smoothstep, but has a configurable slope at x = 0.5.
// Original smoothstep has a slope of 1.5 at x = 0.5
#define INSTANTIATE_SLOPESTEP(T)                               \
    T slopestep(T edge0, T edge1, T x, float slope) {          \
        x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);    \
        const T s = sign(x - 0.5);                             \
        const T o = (1.0 + s) * 0.5;                           \
        return o - 0.5 * s * pow(2.0 * (o - s * x), T(slope)); \
    }
INSTANTIATE_SLOPESTEP(vec2)

// Function to get a pixel value, taking into consideration possible subpixel
// interpolation.
vec3 pixel_aa(sampler2D tex, vec2 tx_coord, vec2 tx_to_uv, vec2 trans_lb, vec2 trans_ub,
              float trans_slope) {
    // The offset for interpolation is a periodic function with
    // a period length of 1 texel.
    // The input coordinate is shifted so that the center of the texel
    // aligns with the start of the period.
    // First, get the period and phase.
    const vec2 period = floor(tx_coord - 0.5);
    const vec2 phase = tx_coord - 0.5 - period;
    // The function starts at 0, then starts transitioning at
    // 0.5 - 0.5 / pixels_per_texel, then reaches 0.5 at 0.5,
    // Then reaches 1 at 0.5 + 0.5 / pixels_per_texel.
    // For sharpness values < 1.0, blend to bilinear filtering.
    const vec2 offset = slopestep(trans_lb, trans_ub, phase, trans_slope);

    // When the input is in linear color space, we can make use of a single tap
    // using bilinear interpolation. The offsets are shifted back to the texel
    // center before sampling.
    return texture(tex, (period + 0.5 + offset) * tx_to_uv).rgb;
}

vec3 pixel_aa_subpx(sampler2D tex, vec2 tx_coord, vec2 sub_tx_offset, vec2 tx_to_uv, vec2 trans_lb,
                    vec2 trans_ub, float trans_slope) {
    vec3 res;
    vec2 period, phase, offset;

    // Red
    period = floor(tx_coord - sub_tx_offset - 0.5);
    phase = tx_coord - sub_tx_offset - 0.5 - period;
    offset = slopestep(trans_lb, trans_ub, phase, trans_slope);
    res.r = texture(tex, (period + 0.5 + offset) * tx_to_uv).r;
    // Green
    period = floor(tx_coord - 0.5);
    phase = tx_coord - 0.5 - period;
    offset = slopestep(trans_lb, trans_ub, phase, trans_slope);
    res.g = texture(tex, (period + 0.5 + offset) * tx_to_uv).g;
    // Blue
    period = floor(tx_coord + sub_tx_offset - 0.5);
    phase = tx_coord + sub_tx_offset - 0.5 - period;
    offset = slopestep(trans_lb, trans_ub, phase, trans_slope);
    res.b = texture(tex, (period + 0.5 + offset) * tx_to_uv).b;

    return res;
}

// This is recurring vertex shader code.
void calculate_pixel_aa_params(vec2 tx_per_px, float sharpness, uint subpx_orientation,
                               uint rotation, inout vec2 trans_lb, inout vec2 trans_ub,
                               inout float trans_slope, inout vec2 sub_tx_offset) {
    const float sharpness_upper = min(1.0, sharpness);
    trans_lb = sharpness_upper * (0.5 - 0.5 * tx_per_px);
    trans_ub = 1.0 - sharpness_upper * (1.0 - (0.5 + 0.5 * tx_per_px));
    trans_slope = max(1.0, sharpness);

    // Subpixel sampling: Shift the sampling by 1/3rd of an output pixel for
    // each subpixel, assuming that the output size is at monitor
    // resolution.
    // Compensate for possible rotation of the screen in certain cores.
    const vec4 rot_corr = vec4(1.0, 0.0, -1.0, 0.0);
    sub_tx_offset = tx_per_px / 3.0 *
                    vec2(rot_corr[(rotation + subpx_orientation) % 4],
                         rot_corr[(rotation + subpx_orientation + 3) % 4]);
}
