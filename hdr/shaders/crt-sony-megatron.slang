#version 450

/* 
A shader that tries to emulate a sony PVM type aperture grille screen but with full brightness.

The novel thing about this shader is that it relies on the HDR shaders to brighten up the image so that when 
we apply this shader which emulates the apperture grille the resulting screen isn't left too dark.  

I think you need at least a DisplayHDR 600 monitor but to get close to CRT levels of brightness I think DisplayHDR 1000.

Please Enable HDR in RetroArch 1.10+

NOTE: when this shader is envoked the Contrast, Peak Luminance and Paper White Luminance in the HDR menu do nothing instead set those values through the shader parameters 

For this shader set Paper White Luminance to above 700 and Peak Luminance to the peak luminance of your monitor.  

Also try to use a integer scaling - its just better - overscaling is fine.

This shader doesn't do any geometry warping or bouncing of light around inside the screen etc - I think these effects just add unwanted noise, I know people disagree. Please feel free to make you own and add them

Dont use this shader directly - use the hdr\crt-make-model-hdr.slangp where make and model are the make and model of the CRT you want.

THIS SHADER DOES NOT SUPPORT WRGB OLED (Due to the sub pixel layout of WRGB - RGB QD-OLED or LCD (and variants thereof screens are fine)
*/

#pragma format A2B10G10R10_UNORM_PACK32

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_hdr;
   float hcrt_colour_space;
   float hcrt_max_nits;
   float hcrt_paper_white_nits;
   float hcrt_expand_gamut;
   float hcrt_gamma;

   float hcrt_lcd_resolution;
   float hcrt_lcd_subpixel;

   float hcrt_red_vertical_convergence;
   float hcrt_green_vertical_convergence;
   float hcrt_blue_vertical_convergence;
   float hcrt_red_horizontal_convergence;
   float hcrt_green_horizontal_convergence;
   float hcrt_blue_horizontal_convergence;

   // Developer Settings
   float hcrt_crt_screen_type;
   float hcrt_crt_resolution;

   // Vertical Settings
   float hcrt_red_scanline_min;
   float hcrt_red_scanline_max;
   float hcrt_red_scanline_attack;
   float hcrt_green_scanline_min;
   float hcrt_green_scanline_max;
   float hcrt_green_scanline_attack;
   float hcrt_blue_scanline_min;
   float hcrt_blue_scanline_max;
   float hcrt_blue_scanline_attack;

   // Horizontal Settings
   float hcrt_red_beam_sharpness;
   float hcrt_red_beam_attack;
   float hcrt_green_beam_sharpness;
   float hcrt_green_beam_attack;
   float hcrt_blue_beam_sharpness;
   float hcrt_blue_beam_attack;

} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} global;

#include "include/parameters.h"

#define HCRT_HDR                            params.hcrt_hdr
#define HCRT_OUTPUT_COLOUR_SPACE            params.hcrt_colour_space
#define HCRT_MAX_NITS                       params.hcrt_max_nits
#define HCRT_PAPER_WHITE_NITS               params.hcrt_paper_white_nits
#define HCRT_EXPAND_GAMUT                   params.hcrt_expand_gamut
#define HCRT_GAMMA                          params.hcrt_gamma

#define HCRT_LCD_RESOLUTION                 params.hcrt_lcd_resolution 
#define HCRT_LCD_SUBPIXEL                   params.hcrt_lcd_subpixel
#define HCRT_RED_VERTICAL_CONVERGENCE       params.hcrt_red_vertical_convergence
#define HCRT_GREEN_VERTICAL_CONVERGENCE     params.hcrt_green_vertical_convergence
#define HCRT_BLUE_VERTICAL_CONVERGENCE      params.hcrt_blue_vertical_convergence
#define HCRT_RED_HORIZONTAL_CONVERGENCE     params.hcrt_red_horizontal_convergence
#define HCRT_GREEN_HORIZONTAL_CONVERGENCE   params.hcrt_green_horizontal_convergence
#define HCRT_BLUE_HORIZONTAL_CONVERGENCE    params.hcrt_blue_horizontal_convergence

#define HCRT_CRT_SCREEN_TYPE                params.hcrt_crt_screen_type
#define HCRT_CRT_RESOLUTION                 params.hcrt_crt_resolution

#define HCRT_RED_SCANLINE_MIN               params.hcrt_red_scanline_min
#define HCRT_RED_SCANLINE_MAX               params.hcrt_red_scanline_max
#define HCRT_RED_SCANLINE_ATTACK            params.hcrt_red_scanline_attack
#define HCRT_GREEN_SCANLINE_MIN             params.hcrt_green_scanline_min
#define HCRT_GREEN_SCANLINE_MAX             params.hcrt_green_scanline_max
#define HCRT_GREEN_SCANLINE_ATTACK          params.hcrt_green_scanline_attack
#define HCRT_BLUE_SCANLINE_MIN              params.hcrt_blue_scanline_min
#define HCRT_BLUE_SCANLINE_MAX              params.hcrt_blue_scanline_max
#define HCRT_BLUE_SCANLINE_ATTACK           params.hcrt_blue_scanline_attack

#define HCRT_RED_BEAM_SHARPNESS             params.hcrt_red_beam_sharpness
#define HCRT_RED_BEAM_ATTACK                params.hcrt_red_beam_attack
#define HCRT_GREEN_BEAM_SHARPNESS           params.hcrt_green_beam_sharpness
#define HCRT_GREEN_BEAM_ATTACK              params.hcrt_green_beam_attack
#define HCRT_BLUE_BEAM_SHARPNESS            params.hcrt_blue_beam_sharpness
#define HCRT_BLUE_BEAM_ATTACK               params.hcrt_blue_beam_attack

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
layout(set = 0, binding = 2) uniform sampler2D SourceSDR;
layout(set = 0, binding = 3) uniform sampler2D SourceHDR;


#define kChannelMask          3
#define kFirstChannelShift    2
#define kSecondChannelShift   4

#define kRedId   0
#define kGreenId 1
#define kBlueId  2

#define kRed     (1 | (kRedId << kFirstChannelShift))
#define kGreen   (1 | (kGreenId << kFirstChannelShift))
#define kBlue    (1 | (kBlueId << kFirstChannelShift))
#define kMagenta (2 | (kRedId << kFirstChannelShift) | (kBlueId << kSecondChannelShift))
#define kYellow  (2 | (kRedId << kFirstChannelShift) | (kGreenId << kSecondChannelShift))
#define kCyan    (2 | (kGreenId << kFirstChannelShift) | (kBlueId << kSecondChannelShift))
#define kBlack   0

#define kRedChannel     vec3(1.0, 0.0, 0.0)
#define kGreenChannel   vec3(0.0, 1.0, 0.0)
#define kBlueChannel    vec3(0.0, 0.0, 1.0)

const vec3 kColourMask[3] = { kRedChannel, kGreenChannel, kBlueChannel };

#define kApertureGrille    0
#define kShadowMask        1
#define kSlotMask          2

#define kBGRAxis           2
#define kTVLAxis           3
#define kResolutionAxis    2

// APERTURE GRILLE MASKS

#define kMaxApertureGrilleSize       7

#define kMG             { kMagenta, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kGM             { kGreen, kMagenta, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kBGR            { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack }
#define kRGB            { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack }

#define kRGBX           { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack }
#define kBGRX           { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack }

#define kRYCBX          { kRed, kYellow, kCyan, kBlue, kBlack, kBlack, kBlack }
#define kBCYRX          { kBlue, kCyan, kYellow, kRed, kBlack, kBlack, kBlack }

#define kRRGGBBX        { kRed, kRed, kGreen, kGreen, kBlue, kBlue, kBlack }
#define kBBGGRRX        { kBlue, kBlue, kGreen, kGreen, kRed, kRed, kBlack }

const uint kApertureGrilleMaskSize[kResolutionAxis][kTVLAxis] = { { 4, 3, 2 }, { 7, 5, 4 } }; //4K: 600 TVL, 800 TVL, 1000 TVL   8K: 600 TVL, 800 TVL, 1000 TVL

const uint kApertureGrilleMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxApertureGrilleSize] = {
   { // 4K
      { kRGBX, kBGRX },            // 600 TVL
      { kBGR, kRGB },              // 800 TVL
      { kMG, kGM }                 // 1000 TVL
   },
   { // 8K
      { kRRGGBBX, kBBGGRRX },      // 600 TVL
      { kRYCBX, kRYCBX },          // 800 TVL
      { kRGBX, kBGRX }             // 1000 TVL
   }
};

#undef kXXXX
#undef kMG
#undef kGM
#undef kBGR
#undef kRGB
#undef kRGBX
#undef kBGRX
#undef kRYCBX
#undef kBCYRX
#undef kRRGGBBX
#undef kBBGGRRX

// SHADOW MASKS

#define kMaxShadowMaskSizeX     12
#define kMaxShadowMaskSizeY     8

#define kXXXX              { kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kMG                { kMagenta, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kGM                { kGreen, kMagenta, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGRRBBG            { kGreen, kRed, kRed, kBlue, kBlue, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kBBGGRR            { kBlue, kBlue, kGreen, kGreen, kRed, kRed, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGBBRRG            { kGreen, kBlue, kBlue, kRed, kRed, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kRRGGBB            { kRed, kRed, kGreen, kGreen, kBlue, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGGRRRRBBBBGG      { kGreen, kGreen, kRed, kRed, kRed, kRed, kBlue, kBlue, kBlue, kBlue, kGreen, kGreen }
#define kBBBBGGGGRRRR      { kBlue, kBlue, kBlue, kBlue, kGreen, kGreen, kGreen, kGreen, kRed, kRed, kRed, kRed }

#define kGGBBBBRRRRGG      { kGreen, kGreen, kBlue, kBlue, kBlue, kBlue, kRed, kRed, kRed, kRed, kGreen, kGreen }
#define kRRRRGGGGBBBB      { kRed, kRed, kRed, kRed, kGreen, kGreen, kGreen, kGreen, kBlue, kBlue, kBlue, kBlue }

#define kMG_GM             { kMG, kGM, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }
#define kGM_MG             { kGM, kMG, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }

#define kGRRBBG_GRRBBG_BBGGRR_BBGGRR  { kGRRBBG, kGRRBBG, kBBGGRR, kBBGGRR, kXXXX, kXXXX, kXXXX, kXXXX }
#define kGBBRRG_GBBRRG_RRGGBB_RRGGBB  { kGBBRRG, kGBBRRG, kRRGGBB, kRRGGBB, kXXXX, kXXXX, kXXXX, kXXXX }

#define kGGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR  { kGGRRRRBBBBGG, kGGRRRRBBBBGG, kGGRRRRBBBBGG, kGGRRRRBBBBGG, kBBBBGGGGRRRR, kBBBBGGGGRRRR, kBBBBGGGGRRRR, kBBBBGGGGRRRR }
#define kGGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB  { kGGBBBBRRRRGG, kGGBBBBRRRRGG, kGGBBBBRRRRGG, kGGBBBBRRRRGG, kRRRRGGGGBBBB, kRRRRGGGGBBBB, kRRRRGGGGBBBB, kRRRRGGGGBBBB }

const uint kShadowMaskSizeX[kResolutionAxis][kTVLAxis] = { { 6, 2, 2 }, { 12, 6, 6 } }; 
const uint kShadowMaskSizeY[kResolutionAxis][kTVLAxis] = { { 4, 2, 2 }, {  8, 4, 4 } }; 

const uint kShadowMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxShadowMaskSizeY][kMaxShadowMaskSizeX]  = {
   { // 4K
      { kGRRBBG_GRRBBG_BBGGRR_BBGGRR, kGBBRRG_GBBRRG_RRGGBB_RRGGBB },                                                      // 600 TVL
      { kMG_GM, kGM_MG },                                                                                                  // 800 TVL
      { kMG_GM, kGM_MG }                                                                                                   // 1000 TVL
   },
   { // 8K
      { kGGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR, 
        kGGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB },        // 600 TVL
      { kGRRBBG_GRRBBG_BBGGRR_BBGGRR, kGBBRRG_GBBRRG_RRGGBB_RRGGBB },                                                      // 800 TVL
      { kGRRBBG_GRRBBG_BBGGRR_BBGGRR, kGBBRRG_GBBRRG_RRGGBB_RRGGBB }                                                       // 1000 TVL
   }
};

#undef kXXXX
#undef kMG
#undef kGM
#undef kBGR
#undef kRGB
#undef kRGBX
#undef kBGRX
#undef kRYCBX
#undef kBCYRX
#undef kRRGGBBX
#undef kBBGGRRX

// SLOT MASKS

#define kMaxSlotMaskSize   8
#define kMaxSlotSizeX      2
#define kMaxSlotSizeY      4

#define kXXXX     { kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kMG       { kMagenta, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kGM       { kGreen, kMagenta, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kBGR      { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kRGB      { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kRGBX     { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kBGRX     { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kRYCBX    { kRed, kYellow, kCyan, kBlue, kBlack, kBlack, kBlack, kBlack }
#define kBCYRX    { kBlue, kCyan, kYellow, kRed, kBlack, kBlack, kBlack, kBlack }

#define kRRGGBBX  { kRed, kRed, kGreen, kGreen, kBlue, kBlue, kBlack, kBlack }
#define kBBGGRRX  { kBlue, kBlue, kGreen, kGreen, kRed, kRed, kBlack, kBlack }

#define kMGMG_MGXX_MGMG_XXMG   { { kMG, kMG }, { kMG, kXXXX }, { kMG, kMG }, { kXXXX, kMG } }
#define kGMGM_GMXX_GMGM_XXGM   { { kGM, kGM }, { kGM, kXXXX }, { kGM, kGM }, { kXXXX, kGM } }

#define kBGRBGR_BGRXXX_BGRBGR_XXXBGR   { { kBGR, kBGR }, { kBGR, kXXXX }, { kBGR, kBGR }, { kXXXX, kBGR } }
#define kRGBRGB_RGBXXX_RGBRGB_XXXRGB   { { kRGB, kRGB }, { kRGB, kXXXX }, { kRGB, kRGB }, { kXXXX, kRGB } }

#define kRGBXRGBX_RGBXXXXX_RGBXRGBX_XXXXRGBX   { { kRGBX, kRGBX }, { kRGBX, kXXXX }, { kRGBX, kRGBX }, { kXXXX, kRGBX } }
#define kBGRXBGRX_BGRXXXXX_BGRXBGRX_XXXXBGRX   { { kBGRX, kBGRX }, { kBGRX, kXXXX }, { kBGRX, kBGRX }, { kXXXX, kBGRX } }

#define kRYCBXRYCBX_RYCBXXXXX_RYCBXRYCBX_XXXXRYCBX   { { kRYCBX, kRYCBX }, { kRYCBX, kXXXX }, { kRYCBX, kRYCBX }, { kXXXX, kRYCBX } }
#define kBCYRXBCYRX_BCYRXXXXX_BCYRXBCYRX_XXXXBCYRX   { { kBCYRX, kBCYRX }, { kBCYRX, kXXXX }, { kBCYRX, kBCYRX }, { kXXXX, kBCYRX } }

#define kRRGGBBXRRGGBBX_RRGGBBXXXXX_RRGGBBXRRGGBBX_XXXXRRGGBBX   { { kRRGGBBX, kRRGGBBX }, { kRRGGBBX, kXXXX }, { kRRGGBBX, kRRGGBBX }, { kXXXX, kRRGGBBX } }
#define kBBGGRRXBBGGRRX_BBGGRRXXXXX_BBGGRRXBBGGRRX_XXXXBBGGRRX   { { kBBGGRRX, kBBGGRRX }, { kBBGGRRX, kXXXX }, { kBBGGRRX, kBBGGRRX }, { kXXXX, kBBGGRRX } }

const uint kSlotMaskSize[kResolutionAxis][kTVLAxis] = { { 4, 3, 2 }, { 7, 5, 4 } }; //4K: 600 TVL, 800 TVL, 1000 TVL   8K: 600 TVL, 800 TVL, 1000 TVL

const uint kSlotMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxSlotSizeY][kMaxSlotSizeX][kMaxSlotMaskSize] = {
   { // 4K
      { kRGBXRGBX_RGBXXXXX_RGBXRGBX_XXXXRGBX, kBGRXBGRX_BGRXXXXX_BGRXBGRX_XXXXBGRX },   // 600 TVL
      { kBGRBGR_BGRXXX_BGRBGR_XXXBGR, kRGBRGB_RGBXXX_RGBRGB_XXXRGB },                   // 800 TVL
      { kMGMG_MGXX_MGMG_XXMG, kGMGM_GMXX_GMGM_XXGM }                                    // 1000 TVL
   },
   { // 8K
      { kRRGGBBXRRGGBBX_RRGGBBXXXXX_RRGGBBXRRGGBBX_XXXXRRGGBBX, kBBGGRRXBBGGRRX_BBGGRRXXXXX_BBGGRRXBBGGRRX_XXXXBBGGRRX },   // 600 TVL
      { kRYCBXRYCBX_RYCBXXXXX_RYCBXRYCBX_XXXXRYCBX, kBCYRXBCYRX_BCYRXXXXX_BCYRXBCYRX_XXXXBCYRX },                           // 800 TVL
      { kRGBXRGBX_RGBXXXXX_RGBXRGBX_XXXXRGBX, kBGRXBGRX_BGRXXXXX_BGRXBGRX_XXXXBGRX }                                        // 1000 TVL
   }
};

#undef kXXXX
#undef kMG
#undef kGM
#undef kBGR
#undef kRGB
#undef kRGBX
#undef kBGRX
#undef kRYCBX
#undef kBCYRX
#undef kRRGGBBX
#undef kBBGGRRX

float ModInteger(float a, float b) 
{
    float m = a - floor((a + 0.5) / b) * b;
    return floor(m + 0.5);
}

#include "include/scanline_generation.h"
#include "include/hdr10.h"

// SDR Colour output spaces
float sRGBToLinear_1(const float channel)
{
	return (channel > 0.04045f) ? pow((channel + 0.055f) * (1.0f / 1.055f), 2.4f + HCRT_GAMMA) : channel * (1.0f / 12.92f);
}

vec3 sRGBToLinear(const vec3 colour)
{
	return vec3(sRGBToLinear_1(colour.r), sRGBToLinear_1(colour.g), sRGBToLinear_1(colour.b));
}

float LinearTosRGB_1(const float channel)
{
	return (channel > 0.0031308f) ? (1.055f * pow(channel, 1.0f / 2.4f)) - 0.055f : channel * 12.92f;
}

vec3 LinearTosRGB(const vec3 colour)
{
	return vec3(LinearTosRGB_1(colour.r), LinearTosRGB_1(colour.g), LinearTosRGB_1(colour.b));
}

vec3 LinearToDCIP3(const vec3 colour)
{
	return pow(colour, vec3(1.0f / 2.6f));
}

vec3 GammaCorrect(const vec3 scanline_colour)
{
   if(HCRT_HDR > 0.0f)
   {
      return HCRT_OUTPUT_COLOUR_SPACE == 0.0f ? LinearTosRGB(scanline_colour) : LinearToDCIP3(scanline_colour);
   }
   else
   {
      return Hdr10(scanline_colour, HCRT_PAPER_WHITE_NITS, HCRT_EXPAND_GAMUT);
   }
}

void main()
{
   const uint screen_type           = uint(HCRT_CRT_SCREEN_TYPE);
   const uint crt_resolution        = uint(HCRT_CRT_RESOLUTION);
   const uint lcd_resolution        = uint(HCRT_LCD_RESOLUTION);
   const uint lcd_subpixel_layout   = uint(HCRT_LCD_SUBPIXEL);

   const vec2 current_position      = vTexCoord * global.OutputSize.xy;

   uint colour_mask;

   switch(screen_type)
   {
      case kApertureGrille:
      {
         uint mask = uint(ModInteger(floor(current_position.x), kApertureGrilleMaskSize[lcd_resolution][crt_resolution]));

         colour_mask = kApertureGrilleMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][mask];      

         break;
      }
      case kShadowMask:
      {
         uint shadow_y = uint(ModInteger(floor(current_position.y), kShadowMaskSizeY[lcd_resolution][crt_resolution]));

         uint mask = uint(ModInteger(floor(current_position.x), kShadowMaskSizeX[lcd_resolution][crt_resolution]));

         colour_mask = kShadowMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][shadow_y][mask];    

         break;
      }
      case kSlotMask:
      {
         uint slot_x = uint(ModInteger(floor(current_position.x / float(kSlotMaskSize[lcd_resolution][crt_resolution])), kMaxSlotSizeX));
         uint slot_y = uint(ModInteger(floor(current_position.y), kMaxSlotSizeY));

         uint mask = uint(ModInteger(floor(current_position.x), kSlotMaskSize[lcd_resolution][crt_resolution]));

         colour_mask = kSlotMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][slot_x][slot_y][mask];

         break;
      }
      default:
      {
         break;
      }
   }

   const float scanline_size           = global.OutputSize.y / global.SourceSize.y;

   const vec3 horizontal_convergence   = vec3(HCRT_RED_HORIZONTAL_CONVERGENCE, HCRT_GREEN_HORIZONTAL_CONVERGENCE, HCRT_BLUE_HORIZONTAL_CONVERGENCE);
   const vec3 vertical_convergence     = vec3(HCRT_RED_VERTICAL_CONVERGENCE, HCRT_GREEN_VERTICAL_CONVERGENCE, HCRT_BLUE_VERTICAL_CONVERGENCE);
   const vec3 beam_sharpness           = vec3(HCRT_RED_BEAM_SHARPNESS, HCRT_GREEN_BEAM_SHARPNESS, HCRT_BLUE_BEAM_SHARPNESS);
   const vec3 beam_attack              = vec3(HCRT_RED_BEAM_ATTACK, HCRT_GREEN_BEAM_ATTACK, HCRT_BLUE_BEAM_ATTACK);
   const vec3 scanline_min             = vec3(HCRT_RED_SCANLINE_MIN, HCRT_GREEN_SCANLINE_MIN, HCRT_BLUE_SCANLINE_MIN);
   const vec3 scanline_max             = vec3(HCRT_RED_SCANLINE_MAX, HCRT_GREEN_SCANLINE_MAX, HCRT_BLUE_SCANLINE_MAX);
   const vec3 scanline_attack          = vec3(HCRT_RED_SCANLINE_ATTACK, HCRT_GREEN_SCANLINE_ATTACK, HCRT_BLUE_SCANLINE_ATTACK);

   const uint channel_count            = colour_mask & 3;

   vec3 scanline_colour = vec3(0.0f);

   if(channel_count > 0)
   {
      const uint channel_0             = (colour_mask >> 2) & 3;

      const float scanline_channel_0   = GenerateScanline(channel_0,
                                                            global.SourceSize.xy, 
                                                            scanline_size, 
                                                            horizontal_convergence[channel_0], 
                                                            vertical_convergence[channel_0], 
                                                            beam_sharpness[channel_0], 
                                                            beam_attack[channel_0], 
                                                            scanline_min[channel_0], 
                                                            scanline_max[channel_0], 
                                                            scanline_attack[channel_0]);

      scanline_colour =  scanline_channel_0 * kColourMask[channel_0];
   }

   if(channel_count > 1)
   {
      const uint channel_1       = (colour_mask >> 4) & 3;

      const float scanline_channel_1   = GenerateScanline(channel_1,
                                                          global.SourceSize.xy, 
                                                          scanline_size, 
                                                          horizontal_convergence[channel_1], 
                                                          vertical_convergence[channel_1], 
                                                          beam_sharpness[channel_1], 
                                                          beam_attack[channel_1], 
                                                          scanline_min[channel_1], 
                                                          scanline_max[channel_1], 
                                                          scanline_attack[channel_1]);

      scanline_colour += scanline_channel_1 * kColourMask[channel_1];
   }

   const vec3 hdr10 = GammaCorrect(scanline_colour);

   FragColor = vec4(hdr10, 1.0f);
}
