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

// Returns offsets alternating between positive an negative depending whether the given index is even or odd.
//   @index - The index to get the offset for.
float get_offset(float index)
{
    // return alternating offset
    return mod(index, 2.0) > 0.0
        ? ceil(index / 2.0)
        : -ceil(index / 2.0);
}

// Get the blur color based on the given parameters.
//   @source - The source texture to sample from.
//   @tex_coord - The texture coordinates.
//   @diffusion - The diffusion of the blur.
//   @tabs - The number of samples.
// Requires:
//   #define INPUT(vec3) vec3 - To transform the input color.
//   #define OUTPUT(vec3) vec3 - To transform the output color.
//   #define OFFSET(vec2, float) vec2 - To transform the texture coordinate by the given offset.
vec3 get_blur_color(sampler2D source, vec2 tex_coord, float diffusion, float tabs)
{
    vec3 color = vec3(0.0);
    float sum = 0.0;

    // limit to 64 tabs
    const float max_tabs = 64.0;
    float tab_size = tabs > max_tabs
        ? tabs / max_tabs
        : 1.0;
    int index = 0;
    do
    {
        float offset = get_offset(index) * tab_size;

        vec2 offset_tex_coord = OFFSET(tex_coord, offset);

        float k = exp(-diffusion * offset * offset);
        color += k * INPUT(texture(source, offset_tex_coord).rgb);
        sum += k;

        index++;
    }
    while (index <= tabs && index <= max_tabs); // break after limit

    return OUTPUT(color / sum);
}

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
