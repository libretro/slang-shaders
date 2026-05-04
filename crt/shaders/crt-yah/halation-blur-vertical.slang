#version 450

#pragma name HalationBlurVPass

#include "halation-blur.layout.h"

#include "parameters.h"

const float MIN_TABS = 4.0;
const float MAX_TABS = 16.0;
const float TABS_LIMIT = 64.0;
#define BLUR_AMOUNT PARAM_HALATION_INTENSITY
#define BLUR_RADIUS PARAM_HALATION_DIFFUSION
#define OFFSET(tex_coord, offset) vec2(tex_coord.x, tex_coord.y + (offset * global.SourceSize.w))

#include "blur.stage-v.h"

#include "blur.stage-f.h"
