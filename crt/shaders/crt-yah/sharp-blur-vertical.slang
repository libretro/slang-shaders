#version 450

#pragma name SharpBlurVPass

#include "sharp-blur.layout.h"

#include "parameters.h"

const float MIN_TABS = 1.0;
const float MAX_TABS = 4.0;
const float TABS_LIMIT = 12.0;

#define BLUR_AMOUNT PARAM_SHARP_AMOUNT
#define BLUR_RADIUS 0.0
#define OFFSET(tex_coord, offset) vec2(tex_coord.x, tex_coord.y + (offset * global.OriginalSize.w))

#include "blur.stage-v.h"

#include "blur.stage-f.h"
