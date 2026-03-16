#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in float Diffusion;
layout(location = 2) in float Tabs;
layout(location = 3) in float Multiple;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "common/colorspace-srgb.h"

// required by blur.h
#define INPUT(color) decode_gamma(color)
#define OUTPUT(color) encode_gamma(color)

#include "blur.h"

void main()
{
    // return if effect is disabled
    if (PARAM_HALATION_INTENSITY == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    // scale diffusion
    float diffusion = Diffusion / (Multiple * Multiple);

    // scale tabs
    float tabs = Tabs * Multiple * 2.0;

    vec3 color = get_blur_color(Source, TexCoord, diffusion, tabs);

    FragColor = vec4(color, 1.0);
}
