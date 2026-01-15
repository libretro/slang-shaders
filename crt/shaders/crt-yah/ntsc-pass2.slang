#version 450

/*
    NTSC-Adaptive pass 2 by Hunter K.
    Based on NTSC shader by The Maister
    Modified by Jezze
*/

// Required shader pass settings:
//    filter_linear1 = true
//    float_framebuffer1 = false
//    scale_type_x1 = source
//    scale_type_y1 = source
//    scale_x1 = 0.25
//    scale_y1 = 0.25

const float Prescale = 0.25;

#pragma name NtscPass2

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    float GLOBAL_MASTER;
    float SCREEN_ORIENTATION;
    float SCREEN_SCALE;
} global;

layout (push_constant) uniform Push
{
    float NTSC_PROFILE;
    float NTSC_QUALITY;
    float NTSC_SCALE;
} param;

#include "parameters.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 ScanTexelSize;

#include "common/screen-helper.h"

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    float screen_orientation = get_orientation(global.OutputSize.xy, PARAM_SCREEN_ORIENTATION);
    float screen_scale = 1.0 / get_multiple(global.OriginalSize.xy, screen_orientation, -(PARAM_SCREEN_SCALE + PARAM_NTSC_SCALE));

    ScanTexelSize = int(screen_orientation) == 0
        ? vec2(global.SourceSize.z / screen_scale, 0.0)
        : vec2(0.0, global.SourceSize.w / screen_scale);
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in vec2 ScanTexelSize;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "ntsc-pass2.h"

void main()
{
    if (PARAM_NTSC_PROFILE == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 rgb = pass2(Source, TexCoord, ScanTexelSize, int(PARAM_NTSC_QUALITY));

    FragColor = vec4(rgb, 1.0);
}
