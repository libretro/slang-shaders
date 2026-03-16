#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out float Diffusion;
layout(location = 2) out float Tabs;
layout(location = 3) out float Multiple;

#include "common/screen-helper.h"

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    // invert parameter, avoid 0
    Diffusion = sqrt(PARAM_HALATION_DIFFUSION);
    Diffusion = max(1.0 / 16.0, 1.0 - Diffusion);

    // 4 to 16 tabs
    Tabs = PARAM_HALATION_DIFFUSION * PARAM_HALATION_DIFFUSION * 16.0;
    Tabs = max(4.0, round(Tabs));

    Multiple = get_multiple(global.SourceSize.xy);
    Multiple = max(1.0, round(Multiple));
}
