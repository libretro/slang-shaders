/*
    Dual filter v1.0, ported to Slang by fishku
    Copyright (C) 2023
    Public domain license (CC0)

    Follows the notes of the SIGGRAPH 2015 talk here:
    https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_marius_2D00_notes.pdf
    Dual filtering is a fast large-radius blur that approximates a Gaussian blur. It is closely
    related to the popular blur filter by Kawase, but runs faster at equal quality.

    How it works: Any number of downsampling passes are chained with the same number of upsampling
    passes in an hourglass configuration. Both types of resampling passes exploit bilinear
    interpolation with carefully chosen coordinates and weights to produce a smooth output.
    There are just 5 + 8 = 13 texture samples per combined down- and upsampling pass.
    The effective blur radius increases with the number of passes.

    This implementation adds a configurable blur strength which can diminish or accentuate the
    effect compared to the reference implementation, equivalent to strength 1.0.

    Changelog:
    v1.0: Initial release.
*/

// clang-format off
#pragma parameter DUAL_FILTER_SETTINGS "=== Dual filter v1.0 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter BLUR_STRENGTH "Blur strength" 1.0 0.6 5.0 0.1
// clang-format on
