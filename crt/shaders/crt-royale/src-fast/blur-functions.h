#ifndef BLUR_FUNCTIONS_H
#define BLUR_FUNCTIONS_H

/////////////////////////////////  MIT LICENSE  ////////////////////////////////

//  Copyright (C) 2014 TroggleMonkey
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.


/////////////////////////////  SETTINGS MANAGEMENT  ////////////////////////////

//  Set static standard deviations, but allow users to override them with their
//  own constants (even non-static uniforms if they're okay with the speed hit):

        //  blurN_std_dev values are specified in terms of dxdy strides.
        //  The defaults are the largest values that keep the largest unused
        //  blur term on each side <= 1.0/256.0.  (We could get away with more
        //  or be more conservative, but this compromise is pretty reasonable.)
        float blur3_std_dev = 0.62666015625;
        float blur4_std_dev = 0.66171875;
        float blur5_std_dev = 0.9845703125;
        float blur6_std_dev = 1.02626953125;
        float blur7_std_dev = 1.36103515625;
        float blur8_std_dev = 1.4080078125;
        float blur9_std_dev = 1.7533203125;
        float blur10_std_dev = 1.80478515625;
        float blur11_std_dev = 2.15986328125;
        float blur12_std_dev = 2.215234375;
        float blur17_std_dev = 3.45535583496;
        float blur25_std_dev = 5.3409576416;
        float blur31_std_dev = 6.86488037109;
        float blur43_std_dev = 10.1852050781;

    //  error_blurring should be in [0.0, 1.0].  Higher values reduce ringing
    //  in shared-sample blurs but increase blurring and feature shifting.
    float error_blurring = 0.5;

///////////////////////////////////  HELPERS  //////////////////////////////////


vec4 uv2_to_uv4(vec2 tex_uv)
{
    //  Make a vec2 uv offset safe for adding to vec4 tex2Dlod coords:
    return vec4(tex_uv, 0.0, 0.0);
}

//  Make a length squared helper macro (for usage with static constants):
#define LENGTH_SQ(vec) (dot(vec, vec))

float get_fast_gaussian_weight_sum_inv(float sigma)
{
    //  We can use the Gaussian integral to calculate the asymptotic weight for
    //  the center pixel.  Since the unnormalized center pixel weight is 1.0,
    //  the normalized weight is the same as the weight sum inverse.  Given a
    //  large enough blur (9+), the asymptotic weight sum is close and faster:
    //      center_weight = 0.5 *
    //          (erf(0.5/(sigma*sqrt(2.0))) - erf(-0.5/(sigma*sqrt(2.0))))
    //      erf(-x) == -erf(x), so we get 0.5 * (2.0 * erf(blah blah)):
    //  However, we can get even faster results with curve-fitting.  These are
    //  also closer than the asymptotic results, because they were constructed
    //  from 64 blurs sizes from [3, 131) and 255 equally-spaced sigmas from
    //  (0, blurN_std_dev), so the results for smaller sigmas are biased toward
    //  smaller blurs.  The max error is 0.0031793913.
    //  Relative FPS: 134.3 with erf, 135.8 with curve-fitting.
    //float temp = 0.5/sqrt(2.0);
    //return erf(temp/sigma);
    return min(exp(exp(0.348348412457428/
        (sigma - 0.0860587260734721))), 0.399334576340352/sigma);
}



vec3 tex2Dblur9resize(sampler2D tex, vec2 tex_uv,
    vec2 dxdy, float sigma)
{
    //  Requires:   Global requirements must be met (see file description).
    //  Returns:    A 1D 9x Gaussian blurred texture lookup using a 9-tap blur.
    //              It may be mipmapped depending on settings and dxdy.
    //  First get the texel weights and normalization factor as above.
    float denom_inv = 0.5/(sigma*sigma);
    float w0 = 1.0;
    float w1 = exp(-1.0 * denom_inv);
    float w2 = exp(-4.0 * denom_inv);
    float w3 = exp(-9.0 * denom_inv);
    float w4 = exp(-16.0 * denom_inv);
    float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3 + w4));
    //  Statically normalize weights, sum weighted samples, and return:
    vec3 sum = vec3(0.0,0.0,0.0);

    sum += w4 * texture(tex, tex_uv - 4.0 * dxdy).rgb;
    sum += w3 * texture(tex, tex_uv - 3.0 * dxdy).rgb;
    sum += w2 * texture(tex, tex_uv - 2.0 * dxdy).rgb;
    sum += w1 * texture(tex, tex_uv - 1.0 * dxdy).rgb;
    sum += w0 * texture(tex, tex_uv).rgb;
    sum += w1 * texture(tex, tex_uv + 1.0 * dxdy).rgb;
    sum += w2 * texture(tex, tex_uv + 2.0 * dxdy).rgb;
    sum += w3 * texture(tex, tex_uv + 3.0 * dxdy).rgb;
    sum += w4 * texture(tex, tex_uv + 4.0 * dxdy).rgb;

    return sum * weight_sum_inv;
}

vec3 tex2Dblur17fastest(sampler2D tex, vec2 tex_uv,
    vec2 dxdy, float weight_sum_inv, vec4 w1_8, vec4 w1_8_ratio)
{
    //  Requires:   Same as tex2Dblur11()
    //  Returns:    A 1D 17x Gaussian blurred texture lookup using 1 nearest
    //              neighbor and 8 linear taps.  It may be mipmapped depending
    //              on settings and dxdy.
    //  First get the texel weights and normalization factor as above.

    float w0 = 1.0;

    vec3 sum = vec3(0.0,0.0,0.0);

    sum += (w1_8.w * texture(tex, tex_uv - (7.0 + w1_8_ratio.w) * dxdy).rgb);
    sum += (w1_8.z * texture(tex, tex_uv - (5.0 + w1_8_ratio.z) * dxdy).rgb);
    sum += (w1_8.y * texture(tex, tex_uv - (3.0 + w1_8_ratio.y) * dxdy).rgb);
    sum += (w1_8.x * texture(tex, tex_uv - (1.0 + w1_8_ratio.x) * dxdy).rgb);
    sum += (w0 * texture(tex, tex_uv).rgb);
    sum += (w1_8.x * texture(tex, tex_uv + (1.0 + w1_8_ratio.x) * dxdy).rgb);
    sum += (w1_8.y * texture(tex, tex_uv + (3.0 + w1_8_ratio.y) * dxdy).rgb);
    sum += (w1_8.z * texture(tex, tex_uv + (5.0 + w1_8_ratio.z) * dxdy).rgb);
    sum += (w1_8.w * texture(tex, tex_uv + (7.0 + w1_8_ratio.w) * dxdy).rgb);

    return sum * weight_sum_inv;
}


#endif  //  BLUR_FUNCTIONS_H

