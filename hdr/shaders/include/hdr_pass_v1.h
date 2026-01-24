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
#include "hdr10.h"

vec3 InverseTonemapConditional(const vec3 linear)
{
   if(HCRT_HDR < 1.0f)
   {
      return linear;
   }
   else
   {
      return InverseTonemap(linear, HCRT_MAX_NITS, HCRT_PAPER_WHITE_NITS);
   }
}
 
void main()
{
   vec3 source = COMPAT_TEXTURE(Source, vTexCoord).rgb;

   vec3 hdr_colour   = InverseTonemapConditional(source);

   vec3 transformed_colour;

   if((HCRT_HDR >= 1.0f) && (HCRT_COLOUR_ACCURATE < 1.0f))
   {
      const vec3 rec2020  = hdr_colour * k2020Gamuts[uint(HCRT_EXPAND_GAMUT)];
      transformed_colour  = rec2020 * (HCRT_PAPER_WHITE_NITS / kMaxNitsFor2084);
   }
   else
   {      
      transformed_colour = hdr_colour;
   }

   FragColor = vec4(transformed_colour, 1.0);
}
