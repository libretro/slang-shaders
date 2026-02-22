#version 450

/*
Drop-in replacement for RetroArch's internal Vulkan HDR pipeline (minus scanline simulation).
User-configurable variant — MaxNits, PaperWhiteNits, etc. are exposed as shader parameters
rather than sourced from RetroArch's HDR menu settings.

Handles all HDR conversion modes:
  HDRMode 0 = Off/passthrough (SDR)
  HDRMode 1 = HDR10 (SDR -> inverse tonemap -> Rec.2020 -> PQ encode)
  HDRMode 2 = scRGB (sRGB -> linear, scale by MaxNits/80)
  HDRMode 3 = PQ->scRGB (decode PQ, Rec.2020->Rec.709, scale x125)

Originally part of the crt\crt-sony-pvm-4k-hdr.slangp but can be used for any shader
*/

#define SONY_MEGATRON_VERSION_2

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
    float MaxNits;
    float PaperWhiteNits;
    float ExpandGamut;
    float DisplayGamma;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    uint HDRMode;
} global;

#pragma parameter MaxNits           "Peak Luminance (cd/m2)"                                    1000.0   0.0 10000.0 10.0
#pragma parameter PaperWhiteNits    "Paper White Luminance (cd/m2)"                             200.0    0.0 10000.0 10.0
#pragma parameter ExpandGamut       "Colour Boost: Accurate | Expanded | Wide | Super"          0.0      0.0 3.0     1.0
#pragma parameter DisplayGamma      "Display Gamma"                                             2.2      0.0 5.0     0.1

#include "include\hdr10.h"
#include "include\inverse_tonemap.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

/* PQ (ST.2084) decode — not in hdr10.h, only the encoder is */
vec3 ST2084ToLinear(vec3 ST2084)
{
   vec3 normalizedLinear = pow(abs(max(pow(abs(ST2084), vec3(1.0 / 78.84375)) - 0.8359375, 0.0)
                             / (18.8515625 - 18.6875 * pow(abs(ST2084), vec3(1.0 / 78.84375)))),
                             vec3(1.0 / 0.1593017578));
   return normalizedLinear;
}

/* Convert PQ HDR10 (Rec.2020) to scRGB (linear Rec.709, 1.0 = 80 nits).
 * PQ normalised linear 1.0 = 10000 nits, scRGB 1.0 = 80 nits -> scalar = 125. */
vec3 ConvertHDR10_To_scRGB(vec3 hdr10Color)
{
   vec3 linear10k = ST2084ToLinear(hdr10Color);
   vec3 linear709 = linear10k * k2020_to_sRGB;
   return linear709 * 125.0;
}

void main()
{
   vec4 source = texture(Source, vTexCoord);

   if(global.HDRMode == 3u)
   {
      /* PQ HDR10 -> scRGB: decode PQ, Rec.2020->Rec.709, scale by 125 */
      FragColor = vec4(ConvertHDR10_To_scRGB(source.rgb), source.a);
   }
   else if(global.HDRMode == 2u)
   {
      /* sRGB -> scRGB: linearize with display gamma, scale by MaxNits/80.
       * scRGB 1.0 = 80 nits; MaxNits maps SDR white to display peak. */
      vec3 linear = pow(abs(source.rgb), vec3(params.DisplayGamma));

      /* Colour boost in scRGB: always convert back to Rec.709 via k2020_to_sRGB,
       * with the forward matrix controlling saturation boost.
       * 0=Accurate (just k2020_to_sRGB), 1=Expanded, 2=Wide, 3=Super (passthrough) */
      uint gamut = uint(params.ExpandGamut);
      if(gamut == 0u)
         linear = linear * k2020_to_sRGB;
      else if(gamut == 1u)
         linear = (linear * kExpanded709_to_2020) * k2020_to_sRGB;
      else if(gamut == 2u)
         linear = (linear * kP3_to_2020) * k2020_to_sRGB;

      linear *= params.MaxNits / 80.0;
      FragColor = vec4(linear, source.a);
   }
   else if(global.HDRMode >= 1u)
   {
      /* HDR10: linearize, inverse tonemap, gamut convert, PQ encode.
       * Matches RetroArch's internal Vulkan HDR pipeline (To2020 + HDR10). */
      vec3 sdr = pow(abs(source.rgb), vec3(params.DisplayGamma));
      vec3 hdr = InverseTonemap(sdr, params.MaxNits, params.PaperWhiteNits);

      /* Gamut conversion — matches RetroArch menu "Colour Boost" setting:
       * 0=Accurate (709->2020), 1=Expanded, 2=Wide (P3->2020), 3=Super (2020 passthrough) */
      uint gamut = uint(params.ExpandGamut);
      vec3 rec2020;
      if(gamut == 0u)
         rec2020 = hdr * k709_to_2020;
      else if(gamut == 1u)
         rec2020 = hdr * kExpanded709_to_2020;
      else if(gamut == 2u)
         rec2020 = hdr * kP3_to_2020;
      else
         rec2020 = hdr;
      rec2020 = max(rec2020, vec3(0.0));

      vec3 pq = LinearToST2084(rec2020 * (params.PaperWhiteNits / kMaxNitsFor2084));
      FragColor = vec4(pq, source.a);
   }
   else
   {
      /* Passthrough (SDR) */
      FragColor = source;
   }
}
