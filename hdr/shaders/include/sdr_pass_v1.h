
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

#include "colour_grade.h"

void main()
{
   vec3 source = COMPAT_TEXTURE(Source, vTexCoord).rgb;

   const vec3 colour   = ColourGrade(source);

   vec3 transformed_colour;

   if((HCRT_HDR < 1.0f) && (HCRT_COLOUR_ACCURATE < 1.0f))
   {
      if(HCRT_OUTPUT_COLOUR_SPACE == 2.0f)
      {
         transformed_colour = (colour * k709_to_XYZ) * kXYZ_to_DCIP3; 
      }
      else
      {
         transformed_colour = colour;
      }
   }
   else
   {
      transformed_colour = colour;
   }

   FragColor = vec4(transformed_colour, 1.0);
}
