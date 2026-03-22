#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 ScanTexelSize;
layout(location = 2) out float Phase;

// used in common/screen-helper.h
#define MIN_PIXEL_SIZE 0.0 // allow any pixel size
#define BASE_SIZE int(PARAM_SCREEN_RESOLUTION_SCALE) > 3 ? 480.0 : 240.0
#define ALLOW_AUTO_SCALE int(PARAM_SCREEN_RESOLUTION_SCALE) > 1
#define ALLOW_AUTO_UP_SCALE int(PARAM_SCREEN_RESOLUTION_SCALE) == 3 || int(PARAM_SCREEN_RESOLUTION_SCALE) == 5

#include "common/screen-helper.h"

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    float screen_scale = 1.0 / get_screen_multiple(global.OriginalSize.xy, ScreenOrientation, -(PARAM_SCREEN_SCALE + PARAM_NTSC_SCALE));

    ScanTexelSize = ScreenOrientation == 0
        ? vec2(global.SourceSize.z / screen_scale, 0.0)
        : vec2(0.0, global.SourceSize.w / screen_scale);

    // Quality:
    // 1 - Auto
    // 2 - Two Phase
    // 3 - Three Phase
    Phase = PARAM_NTSC_QUALITY < 1.5
        // auto
        ? min(global.OriginalSize.x, global.OriginalSize.y) * screen_scale > 240.0 ? 2.0 : 3.0
        // manual
        : PARAM_NTSC_QUALITY;
}
