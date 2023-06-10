#version 450

#include "parameters.slang"

#define EFF_CROP_TOP (param.OS_CROP_TOP)
#define EFF_CROP_BOTTOM (param.InputSize.y - param.OS_CROP_TOP - param.SAMPLE_SIZE)
#define EFF_CROP_LEFT (param.OS_CROP_LEFT)
#define EFF_CROP_RIGHT (param.OS_CROP_RIGHT)

#include "crop_and_sample_common.slang"
