#define COMPAT_TEXTURE(c, d) texture(c, d)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * vec2(1.00001);  // To resolve rounding issues when sampling
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "inverse_tonemap.h"
#include "gamma_correct.h"

void main()
{
   vec3 hdr_colour = COMPAT_TEXTURE(Source, vTexCoord).rgb;

   if(HCRT_HDR == 1u)
   {
      hdr_colour = InverseTonemap(hdr_colour, HCRT_MAX_NITS, HCRT_PAPER_WHITE_NITS);
   }

   const vec3 signal_colour = LinearToSignal(hdr_colour);

   FragColor = vec4(signal_colour, 1.0);
}
