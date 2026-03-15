#version 450

#pragma name BlurHPass

#include "blur.layout.h"

#include "parameters.h"

#define OFFSET(tex_coord, offset) vec2(tex_coord.x + (offset * global.SourceSize.z), tex_coord.y)

#include "blur.stage-v.h"

#include "blur.stage-f.h"