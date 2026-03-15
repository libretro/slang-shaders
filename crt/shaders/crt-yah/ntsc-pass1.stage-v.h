#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 PixCoord;
layout(location = 2) out float Fringing;
layout(location = 3) out float Artifacting;
layout(location = 4) out float Phase;

// used in common/screen-helper.h
#define PIXEL_SIZE_LIMIT 0.0
#define RESOLUTION_AUTO_SCALE PARAM_SCREEN_RESOLUTION_SCALE < 0.5

#include "common/screen-helper.h"

void main()
{
    gl_Position = global.MVP * Position;

    float screen_scale = 1.0 / get_screen_multiple(global.OriginalSize.xy, ScreenOrientation, -(PARAM_SCREEN_SCALE + PARAM_NTSC_SCALE));

    TexCoord = Coord;
    PixCoord = TexCoord * global.OutputSize.xy;
    PixCoord = screen_scale < 1.0
        ? PixCoord * screen_scale
        : PixCoord;
    PixCoord = ScreenOrientation == 0
        ? PixCoord.xy
        : PixCoord.yx;
    PixCoord.x *= max(screen_scale, 1.0);

    // Profile:
    // 1 - Separate Y/C
    // 2 - Composite
    // 3 - Radio Frequency
    Fringing = (PARAM_NTSC_PROFILE - 1.0);
    Artifacting = (PARAM_NTSC_PROFILE - 1.0) * 0.5 * (max(screen_scale, 1.0) + 1.0);

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