#version 450

// Required shader pass settings:
//    filter_linear1 = true
//    scale_type_x1 = source
//    scale_type_y1 = source
//    scale_x1 = 0.25
//    scale_y1 = 1.0

#pragma name NtscHPass2

#include "ntsc-pass2.layout.h"

#include "parameters.h"

const int ScreenOrientation = 0;

#include "ntsc-pass2.stage-v.h"

#include "ntsc-pass2.stage-f.h"
