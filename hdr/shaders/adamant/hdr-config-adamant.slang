#version 450

#define ADAMANT

#pragma format A2B10G10R10_UNORM_PACK32

layout(push_constant) uniform Push
{
    float hcrt_hdr;
    float MaxNits;
    float PaperWhiteNits;
    float content_gamut;
    float DisplayGamma;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    float EnableHDR;
} global;


#pragma parameter hcrt_hdr          "Enable HDR"                                            1.0    0.0 1.0 1.0
#pragma parameter MaxNits           "Peak Luminance"                                            100.0    0.0 10000.0 10.0
#pragma parameter PaperWhiteNits    "Paper White Luminance"                                     100.0    0.0 10000.0 10.0
#pragma parameter DisplayGamma      "Display Gamma"                                             2.2      0.0 5.0     0.1
#pragma parameter content_gamut       "Content Color Gamut"   17.0      0.0   27.0   1.0
#pragma parameter gamutsupport1                      "    0:CBS1951 | 1:1953 | 2:1953RP | 3:1961RP | 4:1964"       0.0      0.0   0.0001   0.0001
#pragma parameter gamutsupport2                      "    5:PAL | 6:Rec601 | 7:P22-J | 8:1970sRP"       0.0      0.0   0.0001   0.0001
#pragma parameter gamutsupport3                      "    9:1980sRP | 10:AppleRGB | 11:PhilipsPC | 12:P22-80"       0.0      0.0   0.0001   0.0001
#pragma parameter gamutsupport4                      "    13:P22-90 | 14:RPTV | 15:GBA | 16:PSP | 17:Rec709"       0.0      0.0   0.0001   0.0001
#pragma parameter gamutsupport5                      "    18:AdobeRGB | 19:DSLite | 20:OGiPhone(PH) | 21:PSP3K(PH)"       0.0      0.0   0.0001   0.0001
#pragma parameter gamutsupport6                      "    22:DisplayP3 | 23:AMOLED(PH) | 24:PSV(PH) | 25:PSV2K(PH)"       0.0      0.0   0.0001   0.0001
#pragma parameter gamutsupport7                      "    26:Ex709 | 27:Rec2020"       0.0      0.0   0.0001   0.0001

#include "include/hdr10.h"
#include "include/inverse_tonemap.h"

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

void main()
{
   vec4 source = texture(Source, vTexCoord);

   vec3 sdr = pow(abs(source.rgb), vec3(params.DisplayGamma));       /* Display Gamma - needs to be determined by calibration screen */

   if(params.hcrt_hdr >= 1.0f)
   {
      vec4 hdr_linear = vec4(InverseTonemap(sdr, params.MaxNits, params.PaperWhiteNits), source.a); 

      FragColor = vec4(Hdr10(hdr_linear.rgb, params.PaperWhiteNits, params.content_gamut), hdr_linear.a); 
   }
   else
   {
      FragColor = vec4 (sdr, source.a); 
   }
}
