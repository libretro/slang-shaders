#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 ScanTexelSize;
layout(location = 2) flat out int Phase;
layout(location = 3) flat out int Tabs;

// used in common/screen-helper.h
#define MIN_PIXEL_SIZE 0.0 // allow any pixel size
#define BASE_SIZE (PARAM_SCREEN_RESOLUTION_SCALE > 3 ? 480.0 : 240.0)
#define ALLOW_AUTO_SCALE (PARAM_SCREEN_RESOLUTION_SCALE > 1)
#define ALLOW_AUTO_UP_SCALE (PARAM_SCREEN_RESOLUTION_SCALE == 3 || PARAM_SCREEN_RESOLUTION_SCALE == 5)

#include "common/screen-helper.h"

// orientation-aware vec2 constructors
vec2 vec2o(vec2 v)
{
    return mix(
        v.xy,
        v.yx,
        ScreenOrientation);
}

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    float multiple_auto = get_screen_multiple(global.OriginalSize.xy, ScreenOrientation, 0.0);
    float multiple = get_screen_multiple(global.OriginalSize.xy, ScreenOrientation, -(PARAM_SCREEN_SCALE + PARAM_NTSC_SCALE));
    float screen_scale = 1.0 / multiple;

    ScanTexelSize = ScreenOrientation == 0
        ? vec2(global.SourceSize.z * multiple, 0.0)
        : vec2(0.0, global.SourceSize.w * multiple);

    // Phase:
    // 0 - Auto
    // 1 - Two
    // 2 - Three
    Phase = PARAM_NTSC_PHASE == 0
        // auto
        ? (vec2o(global.OriginalSize.xy).x * screen_scale) > 300.0 ? 2 : 3
        // manual
        : PARAM_NTSC_PHASE + 1;

    // change range [0.25, 1.0] to [0, 3]
    int samples = int(PARAM_NTSC_SAMPLES * 4.0 - 1.0);
    if (Phase == 2)
    {
        Tabs =
            samples == 0 ? 8 :
            samples == 1 ? 16 :
            samples == 2 ? 24 : 32;
    }
    else
    {
        Tabs =
            samples == 0 ? 6 :
            samples == 1 ? 12 :
            samples == 2 ? 18 : 24;
    }
}
