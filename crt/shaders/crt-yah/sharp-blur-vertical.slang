#version 450

#pragma name SharpBlurVPass

#include "sharp-blur.layout.h"

#include "parameters.h"

const float MIN_TABS = 1.0;
const float MAX_TABS = 4.0;
const float TABS_LIMIT = 16.0;
#define BLUR_AMOUNT PARAM_SHARP_AMOUNT
#define BLUR_RADIUS 0
#define OFFSET(tex_coord, offset) vec2(tex_coord.x, tex_coord.y + (offset * global.SourceSize.w))

#include "blur.stage-v.h"

#include "blur.stage-f.h"
