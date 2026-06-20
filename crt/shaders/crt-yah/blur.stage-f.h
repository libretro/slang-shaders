#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) flat in float TabSize;
layout(location = 2) flat in float TabWeight;
layout(location = 3) flat in int HalfTabCount;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "common/colorspace-srgb.h"

#define INPUT(color) decode_gamma(color)
#define OUTPUT(color) encode_gamma(color)

// Requires:
//   #define OFFSET(vec2, float) vec2 - To transform the texture coordinate by the given offset.
void main()
{
    // return if effect is disabled
    if (BLUR_AMOUNT == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    float sum = 1.0;

    // sample center
    vec3 color = INPUT(texture(Source, TexCoord).rgb);

    float weight = TabWeight;
    float weight_factor = weight * weight;
    float weight_step = weight * weight_factor;

    for (int i = 1; i <= HalfTabCount; i++)
    {
        float base_offset = float(i) * TabSize;

        // sample positive side
        vec2 pos_coord = OFFSET(TexCoord, base_offset);
        color += INPUT(texture(Source, pos_coord).rgb) * weight;

        // sample negative side
        vec2 neg_coord = OFFSET(TexCoord, -base_offset);
        color += INPUT(texture(Source, neg_coord).rgb) * weight;

        // weight both samples
        sum += 2.0 * weight;

        // prepare next weight
        weight *= weight_step;
        weight_step *= weight_factor;
    }

    color = OUTPUT(color / sum);

    FragColor = vec4(color, 1.0);
}
