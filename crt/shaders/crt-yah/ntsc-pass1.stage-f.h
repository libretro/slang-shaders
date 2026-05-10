#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in vec2 PixCoord;
layout(location = 2) in float Fringing;
layout(location = 3) in float Artifacting;
layout(location = 4) flat in int Phase;
layout(location = 5) in vec3 ChromaProfile;
layout(location = 6) flat in uint FrameCount;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const float Brightness = 1.0;
const float Saturation = 1.0;

#define MIX mat3(                       \
    Brightness, Fringing, Fringing,     \
    Artifacting, 2.0 * Saturation, 0.0, \
    Artifacting, 0.0, 2.0 * Saturation)

#include "common/screen-helper.h"
#include "common/math-helper.h"

#include "ntsc-pass1.stage-f.core.h"

// without gamma correction
void main()
{
    // return if effect is disabled
    if (PARAM_NTSC_PROFILE == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    // return if other orientation
    if (get_orientation(global.SourceSize.xy, PARAM_SCREEN_ORIENTATION) != ScreenOrientation)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 yiq = pass1(Source, TexCoord, PixCoord, Phase, ChromaProfile, PARAM_NTSC_JITTER, FrameCount, MIX);

    FragColor = vec4(yiq, 1.0);
}
