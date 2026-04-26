#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 ScanTexCoord;
layout(location = 2) out int ScreenOrientation;
layout(location = 3) out float ScreenMultiple;
layout(location = 4) out float ScreenMultipleAuto;
layout(location = 5) out float BrightnessCompensation;
layout(location = 6) out vec2 MaskProfile;
layout(location = 7) out vec4 BeamProfile;
layout(location = 8) out float AntiRining;
layout(location = 9) out mat4x4 BeamFilter;

// required by crt-yah.stage-v.core.h
#define INPUT_SCREEN_ORIENTATION ScreenOrientation
#define INPUT_SCREEN_MULTIPLE ScreenMultiple
#define INPUT_SCREEN_MULTIPLE_AUTO ScreenMultipleAuto
#define INPUT_MASK_PROFILE MaskProfile

#include "crt-yah.stage-v.core.h"

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;
    ScanTexCoord = Coord;

    ScreenOrientation = get_orientation(global.OutputSize.xy, int(PARAM_SCREEN_ORIENTATION));
    ScreenMultiple = get_screen_multiple(global.OriginalSize.xy, ScreenOrientation, -PARAM_SCREEN_SCALE);
    ScreenMultipleAuto = get_screen_multiple(global.OriginalSize.xy, ScreenOrientation, 0.0);
    MaskProfile = get_mask_profile();
    BeamProfile = get_beam_profile();
    BeamFilter = get_beam_filter();
    BrightnessCompensation = get_brightness_compensation();
    AntiRining = get_anti_ringing_amount();

    // when automatic down-scaled
    if (INPUT_SCREEN_MULTIPLE_AUTO > 1.0)
    {
        // compensate half texel x-offset (applied in fragment shader)
        ScanTexCoord += vec2o(0.5, 0.0) / global.OriginalSize.xy;
    }
}
