#ifndef BLOOM_FUNCTIONS_H
#define BLOOM_FUNCTIONS_H

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA


/////////////////////////////////  DESCRIPTION  ////////////////////////////////

//  These utility functions and constants help several passes determine the
//  size and center texel weight of the phosphor bloom in a uniform manner.


//////////////////////////////////  INCLUDES  //////////////////////////////////

#include "blur-functions.h"

///////////////////////////////  BLOOM CONSTANTS  //////////////////////////////

//  Compute constants with manual inlines of the functions below:
float bloom_diff_thresh = 1.0/256.0;

///////////////////////////////////  HELPERS  //////////////////////////////////

float get_min_sigma_to_blur_triad(float triad_size, float thresh)
{
    //  Requires:   1.) triad_size is the final phosphor triad size in pixels
    //              2.) thresh is the max desired pixel difference in the
    //                  blurred triad (e.g. 1.0/256.0).
    //  Returns:    Return the minimum sigma that will fully blur a phosphor
    //              triad on the screen to an even color, within thresh.
    //              This closed-form function was found by curve-fitting data.
    //  Estimate: max error = ~0.086036, mean sq. error = ~0.0013387:

    return -0.05168 + 0.6113*triad_size - 1.122*triad_size*sqrt(0.000416 + thresh);

    //  Estimate: max error = ~0.16486, mean sq. error = ~0.0041041:
    //return 0.5985*triad_size - triad_size*sqrt(thresh)
}

float get_absolute_scale_blur_sigma(float thresh)
{
    //  Requires:   1.) min_expected_triads must be a global float.  The number
    //                  of horizontal phosphor triads in the final image must be
    //                  >= min_allowed_viewport_triads.x for realistic results.
    //              2.) bloom_approx_scale_x must be a global float equal to the
    //                  absolute horizontal scale of BLOOM_APPROX.
    //              3.) bloom_approx_scale_x/min_allowed_viewport_triads.x
    //                  should be <= 1.1658025090 to keep the final result <
    //                  0.62666015625 (the largest sigma ensuring the largest
    //                  unused texel weight stays < 1.0/256.0 for a 3x3 blur).
    //              4.) thresh is the max desired pixel difference in the
    //                  blurred triad (e.g. 1.0/256.0).
    //  Returns:    Return the minimum Gaussian sigma that will blur the pass
    //              output as much as it would have taken to blur away
    //              bloom_approx_scale_x horizontal phosphor triads.
    //  Description:
    //  BLOOM_APPROX should look like a downscaled phosphor blur.  Ideally, we'd
    //  use the same blur sigma as the actual phosphor bloom and scale it down
    //  to the current resolution with (bloom_approx_scale_x/viewport_size_x), but
    //  we don't know the viewport size in this pass.  Instead, we'll blur as
    //  much as it would take to blur away min_allowed_viewport_triads.x.  This
    //  will blur "more than necessary" if the user actually uses more triads,
    //  but that's not terrible either, because blurring a constant fraction of
    //  the viewport may better resemble a true optical bloom anyway (since the
    //  viewport will generally be about the same fraction of each player's
    //  field of view, regardless of screen size and resolution).
    //  Assume an extremely large viewport size for asymptotic results.

    float min_sigma = get_min_sigma_to_blur_triad(max_viewport_size_x/min_allowed_viewport_triads.x, thresh);

    return bloom_approx_scale_x/max_viewport_size_x * min_sigma;
}

float get_center_weight(float sigma)
{
    //  Given a Gaussian blur sigma, get the blur weight for the center texel.
    return get_fast_gaussian_weight_sum_inv(sigma);
}


float get_bloom_approx_sigma(float output_size_x_runtime, float estimated_viewport_size_x)
{
    //  Requires:   1.) output_size_x_runtime == BLOOM_APPROX.output_size.x.
    //                  This is included for dynamic codepaths just in case the
    //                  following two globals are incorrect:
    //              2.) bloom_approx_size_x_for_skip should == the same
    //                  if PHOSPHOR_BLOOM_FAKE is #defined
    //              3.) bloom_approx_size_x should == the same otherwise
    //  Returns:    For gaussian4x4, return a dynamic small bloom sigma that's
    //              as close to optimal as possible given available information.
    //              For blur3x3, return the a static small bloom sigma that
    //              works well for typical cases.  Otherwise, we're using simple
    //              bilinear filtering, so use static calculations.
    //  Assume the default static value.  This is a compromise that ensures
    //  typical triads are blurred, even if unusually large ones aren't.
    float mask_num_triads_static    = max(min_allowed_viewport_triads.x, mask_num_triads_desired_static);

    //  Assume an extremely large viewport size for asymptotic results:
    float max_viewport_size_x = 1080.0*1024.0*(4.0/3.0);

    //  We're either using blur3x3 or bilinear filtering.  The biggest
    //  reason to choose blur3x3 is to avoid dynamic weights, so use a
    //  static calculation.
    float output_size_x_static = bloom_approx_size_x;

    float asymptotic_triad_size = max_viewport_size_x/mask_num_triads_static;
    float asymptotic_sigma      = get_min_sigma_to_blur_triad(asymptotic_triad_size, bloom_diff_thresh);
    float bloom_approx_sigma    = asymptotic_sigma * output_size_x_static/max_viewport_size_x;

    //  The BLOOM_APPROX input has to be ORIG_LINEARIZED to avoid moire, but
    //  try accounting for the Gaussian scanline sigma from the last pass
    //  too; use the static default value:
    return length(vec2(bloom_approx_sigma, beam_max_sigma_static));
}

#endif  //  BLOOM_FUNCTIONS_H

