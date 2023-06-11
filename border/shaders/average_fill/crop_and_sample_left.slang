#version 450

// See compose.slang for copyright and other information.

#include "parameters.slang"

// clang-format off
#define EFF_CROP_TOP (param.OS_CROP_TOP)
#define EFF_CROP_BOTTOM (param.OS_CROP_BOTTOM)
#define EFF_CROP_LEFT (param.OS_CROP_LEFT)
#define EFF_CROP_RIGHT (param.InputSize.x - param.OS_CROP_LEFT - param.SAMPLE_SIZE)
// clang-format on

#include "crop_and_sample_common.slang"
