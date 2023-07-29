// See compose.slang for copyright and other information.

// clang-format off
#pragma parameter AVERAGE_FILL_SETTINGS "=== Average fill v1.5 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter OS_CROP_TOP "Overscan crop top" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_BOTTOM "Overscan crop bottom" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_LEFT "Overscan crop left" 0.0 0.0 1024.0 1.0
#pragma parameter OS_CROP_RIGHT "Overscan crop right" 0.0 0.0 1024.0 1.0

#pragma parameter CENTER_CROP "Center cropped area" 1.0 0.0 1.0 1.0

#pragma parameter SAMPLE_SIZE "No. of lines for calculating the average" 4.0 1.0 64.0 1.0

#pragma parameter EXTEND_H "Extend the fill horizontally" 1.0 0.0 1.0 1.0
#pragma parameter EXTEND_V "Extend the fill vertically" 1.0 0.0 1.0 1.0

#pragma parameter CORNER_BLEND_MODE "Cropped corner blend mode" 0.0 0.0 3.0 1.0

#pragma parameter FORCE_ASPECT_RATIO "Force aspect ratio" 1.0 0.0 1.0 1.0
#pragma parameter ASPECT_H "Horizontal aspect ratio before crop (0 = original)" 0.0 0.0 256.0 1.0
#pragma parameter ASPECT_V "Vertical aspect ratio before crop (0 = original)" 0.0 0.0 256.0 1.0
#pragma parameter FORCE_INTEGER_SCALING "Force integer scaling" 1.0 0.0 1.0 1.0

#pragma parameter FILL_GAMMA "Background fill gamma adjustment" 1.0 0.5 2.0 0.1
// clang-format on
