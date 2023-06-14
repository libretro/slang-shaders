// See compose.slang for copyright and other information.

// clang-format off
#pragma parameter OS_CROP_TOP "Overscan crop top" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_BOTTOM "Overscan crop bottom" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_LEFT "Overscan crop left" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_RIGHT "Overscan crop right" 0.0 0.0 1024.0 1.0

#pragma parameter CENTER_CROP "Center cropped area" 1.0 0.0 1.0 1.0

#pragma parameter SAMPLE_SIZE "No. of lines for rendering the blur" 8.0 1.0 1024.0 1.0

#pragma parameter BLUR_EXTEND_H "Extend blur horizontally" 1.0 0.0 1.0 1.0
#pragma parameter BLUR_EXTEND_V "Extend blur vertically" 1.0 0.0 1.0 1.0
#pragma parameter MIRROR_BLUR "Mirror the repeating blur" 1.0 0.0 1.0 1.0

#pragma parameter FORCE_ASPECT_RATIO "Force aspect ratio" 0.0 0.0 1.0 1.0
#pragma parameter ASPECT_H "Horizontal aspect ratio before crop" 4.0 1.0 100.0 1.0
#pragma parameter ASPECT_V "Vertical aspect ratio before crop" 3.0 1.0 100.0 1.0
#pragma parameter FORCE_INTEGER_SCALING "Force integer scaling" 1.0 0.0 1.0 1.0
// clang-format on
