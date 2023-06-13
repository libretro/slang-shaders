// See compose.slang for copyright and other information.

// clang-format off
#pragma parameter SCALING_MODE "Input scaling mode" 0.0 0.0 3.0 1.0
#pragma parameter ASPECT_H "Horizontal aspect ratio" 4.0 1.0 100.0 1.0
#pragma parameter ASPECT_V "Vertical aspect ratio" 3.0 1.0 100.0 1.0
#pragma parameter BLUR_STRETCH_H "Stretch blur horizontally" 0.0 0.0 1.0 1.0
#pragma parameter BLUR_STRETCH_V "Stretch blur vertically" 0.0 0.0 1.0 1.0
#pragma parameter OS_CROP_TOP "Overscan crop top" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_BOTTOM "Overscan crop bottom" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_LEFT "Overscan crop left" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_RIGHT "Overscan crop right" 0.0 0.0 1024.0 1.0
#pragma parameter SAMPLE_SIZE "No. of lines for rendering the blur" 8.0 1.0 1024.0 1.0
// clang-format on
