#version 450

#pragma name BlurVPass

#include "blur.layout.h"

#include "parameters.h"

#define OFFSET(tex_coord, offset) vec2(tex_coord.x, tex_coord.y + (offset * global.SourceSize.w))

#include "blur.stage-v.h"

#include "blur.stage-f.h"
