#version 450

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////
//
//  crt-resswitch-glitch-koko
//  Copyright (C) 2024 Antonio Orefice <kokoko3k@gmail.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or any later version.
//
////////////////////////////////////////////////////////////////////////////////


layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 SourceSize;
    vec4 OriginalHistorySize1;
    vec4 OriginalHistorySize2;
    vec4 OriginalHistorySize3;
    vec4 OriginalHistorySize4;
    vec4 OriginalHistorySize5;
    float RESSWITCH_ENABLE;
    float RESSWITCH_GLITCH_TRESHOLD;
    float RESSWITCH_GLITCH_BAR;
    float RESSWITCH_GLITCH_SHAKE_MAX;
    uint FrameCount;
} global;

#pragma parameter RESSWITCH_ENABLE "★ Resolution switch glitch enable? ==>"     1.0  0.0 1.0  1.0
#pragma parameter RESSWITCH_GLITCH_TRESHOLD  "    Glitch if vertical resolution changes at least by" 0.1 0.01 1.0 0.01
#pragma parameter RESSWITCH_GLITCH_BAR       "    Bright glitch bars strength"  0.2 0.0 1.0 0.01
#pragma parameter RESSWITCH_GLITCH_SHAKE_MAX "    Screen shake amplitude"       0.2  0.0 1.0 0.01

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float vSwitchres_show_bar;

#define _3kHIST0 global.SourceSize.xy
#define _3kHIST1 global.OriginalHistorySize1.xy
#define _3kHIST2 global.OriginalHistorySize2.xy
#define _3kHIST3 global.OriginalHistorySize3.xy
#define _3kHIST4 global.OriginalHistorySize4.xy
#define _3kHIST5 global.OriginalHistorySize5.xy

bool changed_enough(vec2 current, vec2 past){
    return (abs(current.y - past.y) / current.y > global.RESSWITCH_GLITCH_TRESHOLD) ||
           (abs(current.x - past.x) / current.x > global.RESSWITCH_GLITCH_TRESHOLD);
}

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord * 1.0001;

    vSwitchres_show_bar = 0.0;
    // Skip a bunch of frames at the beginning to prevent unwanted glitches
    // with flycast core and maybe with fast-forward too.
    if (global.RESSWITCH_ENABLE > 0.5 && global.FrameCount > 10 ) {
        if (changed_enough(_3kHIST0, _3kHIST1)) {
            //first frame
            vSwitchres_show_bar = global.RESSWITCH_GLITCH_BAR;
            vTexCoord.y += global.RESSWITCH_GLITCH_SHAKE_MAX * +1.0 ;
        }

        else if (changed_enough(_3kHIST0, _3kHIST2)) {
            vSwitchres_show_bar = global.RESSWITCH_GLITCH_BAR;
            vTexCoord.y += global.RESSWITCH_GLITCH_SHAKE_MAX * -1.0;
        }

        else if (changed_enough(_3kHIST0, _3kHIST3)) {
            vSwitchres_show_bar = global.RESSWITCH_GLITCH_BAR;
            vTexCoord.y += global.RESSWITCH_GLITCH_SHAKE_MAX * +0.5;
        }

        else if (changed_enough(_3kHIST0, _3kHIST4)) {
            vSwitchres_show_bar = global.RESSWITCH_GLITCH_BAR;
            vTexCoord.y += global.RESSWITCH_GLITCH_SHAKE_MAX * -0.5;
        }

        else if (changed_enough(_3kHIST0, _3kHIST5)) {
            //last frame
            vTexCoord.y += global.RESSWITCH_GLITCH_SHAKE_MAX * +0.25;
            vSwitchres_show_bar = global.RESSWITCH_GLITCH_BAR;
        }
    }
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vSwitchres_show_bar;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D Source;

#define _3kPI 3.141592653589793

void main() {
   float switchresglitch = 0.0;

   if (vTexCoord.y < 0.0 ||vTexCoord.y > 1.0 )
      switchresglitch = sin( vTexCoord.y * _3kPI * (2/global.RESSWITCH_GLITCH_SHAKE_MAX) ) * vSwitchres_show_bar;

   FragColor = texture(Source, vTexCoord) + switchresglitch;
}
