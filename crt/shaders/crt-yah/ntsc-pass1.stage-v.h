#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 PixCoord;
layout(location = 2) out float Fringing;
layout(location = 3) out float Artifacting;
layout(location = 4) flat out int Phase;
layout(location = 5) out vec3 ChromaProfile;
layout(location = 6) flat out uint FrameCount;

// used in common/screen-helper.h
#define MIN_PIXEL_SIZE 0.0 // allow any pixel size
#define BASE_SIZE (PARAM_SCREEN_RESOLUTION_SCALE > 3 ? 480.0 : 240.0)
#define ALLOW_AUTO_SCALE (PARAM_SCREEN_RESOLUTION_SCALE > 1)
#define ALLOW_AUTO_UP_SCALE (PARAM_SCREEN_RESOLUTION_SCALE == 3 || PARAM_SCREEN_RESOLUTION_SCALE == 5)

#include "common/constants.h"
#include "common/screen-helper.h"
#include "common/frame-helper.h"

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

    float screen_scale = 1.0 / get_screen_multiple(global.OriginalSize.xy, ScreenOrientation, -(PARAM_SCREEN_SCALE + PARAM_NTSC_SCALE));

    TexCoord = Coord;
    PixCoord = TexCoord * global.OutputSize.xy;
    PixCoord = screen_scale < 1.0
        ? PixCoord * screen_scale
        : PixCoord;
    PixCoord = vec2o(PixCoord.xy);
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
    Phase = PARAM_NTSC_QUALITY == 1
        // auto
        ? (vec2o(global.OriginalSize.xy).x * screen_scale) > 300.0 ? 2 : 3
        // manual
        : PARAM_NTSC_QUALITY;

    float chromaFrequency = Phase == 2
        ? PI / (15.0 / 4.0)
        : PI / 3.0;
    float chromaAmplitude = Phase == 2
        ? PI
        : PI * (2.0 / 3.0);
    float chromaShift = Phase == 2
        ? PARAM_NTSC_SHIFT + 1.0
        : (PARAM_NTSC_SHIFT * 1.5) + 1.5;
    ChromaProfile = vec3(chromaFrequency, chromaAmplitude, chromaShift);

    // used for chroma phase offset with 30/60Hz
    FrameCount = GetUniformFrameCount(PARAM_SCREEN_FREQUENCY);
}
