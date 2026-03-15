#version 450

// Required shader pass settings:
//    filter_linear0 = false
//    float_framebuffer0 = true
//    scale_type_x0 = source
//    scale_type_y0 = source
//    scale_x0 = 4.0
//    scale_y0 = 1.0

#pragma name NtscHPass1

#include "ntsc-pass1.layout.h"

#include "parameters.h"

const int ScreenOrientation = 0;

#include "ntsc-pass1.stage-v.h"

#include "ntsc-pass1.stage-f.h"
