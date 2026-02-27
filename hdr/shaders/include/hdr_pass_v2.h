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

/* Convert Rec.709 input to Rec.2020 via Colour Space setting.
 * Same trick as hdr.frag To2020() — the mismatch between the
 * conversion matrix and the final k2020_to_sRGB creates the boost:
 *   r709/sRGB (0/1):   k709_to_2020 — proper conversion (no boost)
 *   Adobe (2):         kAdobe_to_2020 — moderate boost
 *   DCI-P3 (3):        kP3_to_2020 — wide boost
 *   r2020 (4):         passthrough — 709 data as-is (max boost) */
vec3 To2020(const vec3 linear_709)
{
   uint space = uint(HCRT_OUTPUT_COLOUR_SPACE);

   if(space == 4u)        // r2020 → passthrough (max boost)
   {
      return max(linear_709, vec3(0.0f));
   }
   else if(space == 3u)   // DCI-P3 → wide boost
   {
      return max(linear_709 * kP3_to_2020, vec3(0.0f));
   }
   else if(space == 2u)   // Adobe → moderate boost
   {
      return max(linear_709 * kAdobe_to_2020, vec3(0.0f));
   }
   else                   // r709 (0), sRGB (1) → no boost
   {
      return max(linear_709 * k709_to_2020, vec3(0.0f));
   }
}

void main()
{
   vec3 hdr_colour = COMPAT_TEXTURE(Source, vTexCoord).rgb;

   if(HCRT_HDR > 0u)
   {
      // HDR: convert from Rec.709 (colour_grade output) to Rec.2020 with ExpandGamut boost
      hdr_colour = To2020(hdr_colour);

      if(HCRT_HDR == 1u)
      {
         hdr_colour = InverseTonemap(hdr_colour, HCRT_MAX_NITS, HCRT_PAPER_WHITE_NITS);
      }
   }

   const vec3 signal_colour = LinearToSignal(hdr_colour);

   FragColor = vec4(signal_colour, 1.0);
}
