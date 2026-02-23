#version 450

/*
Drop-in replacement for RetroArch's internal Vulkan HDR pipeline (minus scanline simulation).

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
   float DisplayGamma;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
	uint HDRMode;
    float MaxNits;
    float PaperWhiteNits;
    uint ExpandGamut;
} global;

#pragma parameter DisplayGamma      "Display Gamma"                                             2.2      0.0   5.0   0.1

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
      /* sRGB -> scRGB: linearize, convert to target colour space with ExpandGamut,
       * then k2020_to_sRGB creates the boost by "interpreting" as Rec.2020. */
      vec3 linear = pow(abs(source.rgb), vec3(params.DisplayGamma));

      /* Convert Rec.709 to target colour space, then apply k2020_to_sRGB for boost. */
      vec3 target;
      if(global.ExpandGamut == 0u)
         target = linear * k709_to_2020;
      else if(global.ExpandGamut == 1u)
         target = linear * k709_to_Expanded709;
      else if(global.ExpandGamut == 2u)
         target = linear * k709_to_P3;
      else
         target = linear;
      target = max(target, vec3(0.0));

      linear = target * k2020_to_sRGB;

      linear *= global.MaxNits / 80.0;
      FragColor = vec4(linear, source.a);
   }
   else if(global.HDRMode >= 1u)
   {
      /* HDR10: linearize, inverse tonemap, convert to target colour space, PQ encode.
       * The PQ encoder treats data as Rec.2020 — gamut mismatch creates the boost. */
      vec3 sdr = pow(abs(source.rgb), vec3(params.DisplayGamma));
      vec3 hdr = InverseTonemap(sdr, global.MaxNits, global.PaperWhiteNits);

      /* Convert Rec.709 to target colour space for ExpandGamut colour boost:
       * 0=Accurate (709->2020, no boost), 1=Expanded, 2=Wide (709->P3), 3=Super (passthrough) */
      vec3 rec2020;
      if(global.ExpandGamut == 0u)
         rec2020 = hdr * k709_to_2020;
      else if(global.ExpandGamut == 1u)
         rec2020 = hdr * k709_to_Expanded709;
      else if(global.ExpandGamut == 2u)
         rec2020 = hdr * k709_to_P3;
      else
         rec2020 = hdr;
      rec2020 = max(rec2020, vec3(0.0));

      vec3 pq = LinearToST2084(rec2020 * (global.PaperWhiteNits / kMaxNitsFor2084));
      FragColor = vec4(pq, source.a);
   }
   else
   {
      /* Passthrough (SDR) */
      FragColor = source;
   }
}
