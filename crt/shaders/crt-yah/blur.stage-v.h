#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out float Diffusion;
layout(location = 2) out float Tabs;
layout(location = 3) out float Multiple;

#include "common/screen-helper.h"

#define INVERSE_MAX_TABS (1.0 / MAX_TABS)

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    // square parameter and avoid 1
    Diffusion = sqrt(BLUR_RADIUS) * (1.0 - INVERSE_MAX_TABS);
    // invert parameter and avoid 0
    Diffusion = max(INVERSE_MAX_TABS, 1.0 - Diffusion);

    // limit tabs
    Tabs = BLUR_RADIUS * BLUR_RADIUS * MAX_TABS;
    Tabs = max(MIN_TABS, round(Tabs));

    Multiple = get_multiple(global.SourceSize.xy);
    Multiple = max(1.0, round(Multiple));
}
