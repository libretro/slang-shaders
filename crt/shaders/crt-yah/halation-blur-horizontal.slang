#version 450

#pragma name HalationBlurHPass

#include "halation-blur.layout.h"

#include "parameters.h"

const float MIN_TABS = 4.0;
const float MAX_TABS = 16.0;
const float TABS_LIMIT = 64.0;
#define Source PhosphorPass
#define BLUR_AMOUNT PARAM_HALATION_INTENSITY
#define BLUR_RADIUS PARAM_HALATION_DIFFUSION
#define OFFSET(tex_coord, offset) vec2(tex_coord.x + (offset * global.SourceSize.z), tex_coord.y)

#include "blur.stage-v.h"

#include "blur.stage-f.h"
