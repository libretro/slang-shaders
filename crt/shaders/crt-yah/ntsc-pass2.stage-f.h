#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in vec2 ScanTexelSize;
layout(location = 2) in float Phase;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source; // output frame of the 1st NTSC pass
layout(set = 0, binding = 3) uniform sampler2D OriginalHistory1; // input frame of the 1st NTSC pass

#include "common/screen-helper.h"

#include "ntsc-pass2.h"

// without gamma correction
void main()
{
    // return if effect is disabled
    if (PARAM_NTSC_PROFILE == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    // return if vertical orientation
    if (get_orientation(global.OutputSize.xy, int(PARAM_SCREEN_ORIENTATION)) != ScreenOrientation)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 rgb = pass2(Source, TexCoord, ScanTexelSize, int(Phase));

    // merge frames between 0-Off and 1-Separate Y/C
    if (PARAM_NTSC_PROFILE < 1.0)
    {
        vec3 original = texture(OriginalHistory1, TexCoord).rgb;

        rgb = mix(original, rgb, PARAM_NTSC_PROFILE);
    }

    FragColor = vec4(rgb, 1.0);
}
