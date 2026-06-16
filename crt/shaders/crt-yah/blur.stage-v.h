#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) flat out float TabSize;
layout(location = 2) flat out float TabWeight;
layout(location = 3) flat out int HalfTabCount;

#include "common/screen-helper.h"
#include "common/math-helper.h"

#define INVERSE_MAX_TABS (1.0 / MAX_TABS)

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    float multiple = get_multiple(global.OriginalSize.xy);
    multiple = max(1.0, round(multiple));

    // square-root relative blur radius [0,1] and avoid 1
    float diffusion = sqrt(BLUR_RADIUS) * (1.0 - INVERSE_MAX_TABS);
    // invert parameter and avoid 0
    diffusion = max(INVERSE_MAX_TABS, 1.0 - diffusion);
    // scale diffusion
    diffusion = diffusion / (multiple * multiple);

    // square relative blur radius [0,1]
    float tabs = BLUR_RADIUS * BLUR_RADIUS * MAX_TABS;
    // limit tabs
    tabs = max(MIN_TABS, round(tabs));
    // scale tabs
    tabs = tabs * multiple * 2.0;

    // half tab count for symetric gaussian curve
    HalfTabCount = int(ceil(min(tabs, TABS_LIMIT) / 2.0));

    // increase tab size if tabs exceed limit to keep blur radius
    TabSize = tabs > TABS_LIMIT
        ? tabs / TABS_LIMIT
        : 1.0;

    // initial tab weight
    TabWeight = exp(-diffusion * TabSize * TabSize);
}
