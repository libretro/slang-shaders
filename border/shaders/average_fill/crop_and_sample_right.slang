#version 450

// See compose.slang for copyright and other information.

#include "parameters.slang"

// clang-format off
#define EFF_CROP_TOP (param.OS_CROP_TOP)
#define EFF_CROP_BOTTOM (param.OS_CROP_BOTTOM)
#define EFF_CROP_LEFT (param.InputSize.x - param.OS_CROP_RIGHT - param.SAMPLE_SIZE)
#define EFF_CROP_RIGHT (param.OS_CROP_RIGHT)
// clang-format on

#include "crop_and_sample_common.slang"
