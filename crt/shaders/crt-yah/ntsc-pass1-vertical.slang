#version 450

// Required shader pass settings:
//    filter_linear0 = false
//    scale_type_x0 = source
//    scale_type_y0 = source
//    scale_x0 = 1.0
//    scale_y0 = 4.0

#pragma name NtscVPass1
#pragma format R16G16B16A16_SFLOAT

#include "ntsc-pass1.layout.h"

#include "parameters.h"

const int ScreenOrientation = 1;

#include "ntsc-pass1.stage-v.h"

#include "ntsc-pass1.stage-f.h"
