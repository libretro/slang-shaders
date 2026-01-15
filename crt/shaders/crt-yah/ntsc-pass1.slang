#version 450

/*
    NTSC-Adaptive pass 1 by Hunter K.
    Based on NTSC shader by The Maister
    Modified by Jezze
*/

// Required shader pass settings:
//    filter_linear0 = false
//    float_framebuffer0 = true
//    scale_type_x0 = source
//    scale_type_y0 = source
//    scale_x0 = 4.0
//    scale_y0 = 4.0

const float Prescale = 4.0;

#pragma name NtscPass1

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
    uint FrameTimeDelta;
    float GLOBAL_MASTER;
    float SCREEN_ORIENTATION;
    float SCREEN_SCALE;
    float SCREEN_FREQUENCY;
} global;

layout (push_constant) uniform Push
{
    float NTSC_PROFILE;
    float NTSC_QUALITY;
    float NTSC_SCALE;
    float NTSC_SHIFT;
    float NTSC_JITTER;
} param;

#include "parameters.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 PixCoord;
layout(location = 2) out float Fringing;
layout(location = 3) out float Artifacting;

#include "common/screen-helper.h"

void main()
{
	gl_Position = global.MVP * Position;

    float screen_orientation = get_orientation(global.OutputSize.xy, PARAM_SCREEN_ORIENTATION);
    float screen_scale = 1.0 / get_multiple(global.OriginalSize.xy, screen_orientation, -(PARAM_SCREEN_SCALE + PARAM_NTSC_SCALE));

    TexCoord = Coord;
    PixCoord = TexCoord * global.OutputSize.xy;
    PixCoord = screen_scale < 1.0
        ? PixCoord * screen_scale
        : PixCoord;
    PixCoord = int(screen_orientation) == 0
        ? PixCoord.xy
        : PixCoord.yx;
    PixCoord.x *= max(screen_scale, 1.0);
    PixCoord.y /= Prescale;

    // Quallity:
    // 1 - Separate Y/C
    // 2 - Composite
    // 3 - Radio Frequency
    Fringing = (PARAM_NTSC_PROFILE - 1.0);
    Artifacting = (PARAM_NTSC_PROFILE - 1.0) * 0.5 * (max(screen_scale, 1.0) + 1.0);
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in vec2 PixCoord;
layout(location = 2) in float Fringing;
layout(location = 3) in float Artifacting;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const float Brightness = 1.0;
const float Saturation = 1.0;

#define MIX mat3(                       \
    Brightness, Fringing, Fringing,     \
    Artifacting, 2.0 * Saturation, 0.0, \
    Artifacting, 0.0, 2.0 * Saturation)

#include "common/frame-helper.h"

#include "ntsc-pass1.h"

void main()
{
    if (PARAM_NTSC_PROFILE == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    // used for chroma phase offset with 30/60Hz
    uint frame_count = GetUniformFrameCount(PARAM_SCREEN_FREQUENCY);

    vec3 yiq = pass1(Source, TexCoord, PixCoord, int(PARAM_NTSC_QUALITY), PARAM_NTSC_SHIFT, PARAM_NTSC_JITTER, MIX, frame_count);

    FragColor = vec4(yiq, 1.0);
}
