#version 450

#define ADAMANT

#pragma format A2B10G10R10_UNORM_PACK32

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_hdr;
   float hcrt_colour_space;
   float hcrt_max_nits;
   float hcrt_paper_white_nits;
   float hcrt_content_gamut;
   float hcrt_scanline_colour_clamp;

   float hcrt_lcd_resolution;
   float hcrt_lcd_subpixel;

   float hcrt_red_vertical_convergence;
   float hcrt_green_vertical_convergence;
   float hcrt_blue_vertical_convergence;
   float hcrt_red_horizontal_convergence;
   float hcrt_green_horizontal_convergence;
   float hcrt_blue_horizontal_convergence;
   
   float hcrt_bloom_strength;

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
	float EnableHDR;
	float PaperWhiteNits;
	float ntsc_pseudo;
	
	float hcrt_r709_gamma_out;
	float hcrt_srgb_gamma_out;
	float hcrt_p3_gamma_out;
	float hcrt_r709_gamma_cutoff;
	float hcrt_srgb_gamma_cutoff;

   float hcrt_scanline_multi;
	
	float hcrt_h_size;
	float hcrt_v_size;
	float hcrt_h_cent;
	float hcrt_v_cent;
} global;

#include "include/parameters.h"
#define NTSC_PSEUDO                          global.ntsc_pseudo

#define HCRT_HDR                             params.hcrt_hdr
#define HCRT_OUTPUT_COLOUR_SPACE             params.hcrt_colour_space
#define HCRT_PAPER_WHITE_NITS                params.hcrt_paper_white_nits
#define HCRT_content_gamut                    params.hcrt_content_gamut
#define HCRT_SCANLINE_COLOUR_CLAMP           params.hcrt_scanline_colour_clamp
#define HCRT_R709_GAMMA_OUT                  global.hcrt_r709_gamma_out
#define HCRT_SRGB_GAMMA_OUT                  global.hcrt_srgb_gamma_out
#define HCRT_P3_GAMMA_OUT                    global.hcrt_p3_gamma_out
#define HCRT_R709_GAMMA_CUTOFF               global.hcrt_r709_gamma_cutoff
#define HCRT_SRGB_GAMMA_CUTOFF               global.hcrt_srgb_gamma_cutoff
#define HCRT_SCANLINE_MULTI                  global.hcrt_scanline_multi
#define HCRT_BLOOM_STRENGTH                  params.hcrt_bloom_strength

#define HCRT_LCD_RESOLUTION                  params.hcrt_lcd_resolution 
#define HCRT_LCD_SUBPIXEL                    params.hcrt_lcd_subpixel
#define HCRT_RED_VERTICAL_CONVERGENCE        params.hcrt_red_vertical_convergence
#define HCRT_GREEN_VERTICAL_CONVERGENCE      params.hcrt_green_vertical_convergence
#define HCRT_BLUE_VERTICAL_CONVERGENCE       params.hcrt_blue_vertical_convergence
#define HCRT_RED_HORIZONTAL_CONVERGENCE      params.hcrt_red_horizontal_convergence
#define HCRT_GREEN_HORIZONTAL_CONVERGENCE    params.hcrt_green_horizontal_convergence
#define HCRT_BLUE_HORIZONTAL_CONVERGENCE     params.hcrt_blue_horizontal_convergence

#define HCRT_CRT_SCREEN_TYPE                 params.hcrt_crt_screen_type
#define HCRT_CRT_RESOLUTION                  params.hcrt_crt_resolution

#define HCRT_RED_SCANLINE_MIN                params.hcrt_red_scanline_min
#define HCRT_RED_SCANLINE_MAX                params.hcrt_red_scanline_max
#define HCRT_RED_SCANLINE_ATTACK             params.hcrt_red_scanline_attack
#define HCRT_GREEN_SCANLINE_MIN              params.hcrt_green_scanline_min
#define HCRT_GREEN_SCANLINE_MAX              params.hcrt_green_scanline_max
#define HCRT_GREEN_SCANLINE_ATTACK           params.hcrt_green_scanline_attack
#define HCRT_BLUE_SCANLINE_MIN               params.hcrt_blue_scanline_min
#define HCRT_BLUE_SCANLINE_MAX               params.hcrt_blue_scanline_max
#define HCRT_BLUE_SCANLINE_ATTACK            params.hcrt_blue_scanline_attack

#define HCRT_RED_BEAM_SHARPNESS              params.hcrt_red_beam_sharpness
#define HCRT_RED_BEAM_ATTACK                 params.hcrt_red_beam_attack
#define HCRT_GREEN_BEAM_SHARPNESS            params.hcrt_green_beam_sharpness
#define HCRT_GREEN_BEAM_ATTACK               params.hcrt_green_beam_attack
#define HCRT_BLUE_BEAM_SHARPNESS             params.hcrt_blue_beam_sharpness
#define HCRT_BLUE_BEAM_ATTACK                params.hcrt_blue_beam_attack

#define HCRT_H_SIZE                          global.hcrt_h_size
#define HCRT_V_SIZE                          global.hcrt_v_size
#define HCRT_H_CENT                          global.hcrt_h_cent
#define HCRT_V_CENT                          global.hcrt_v_cent


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
#define kThirdChannelShift    6

#define kRedId   0
#define kGreenId 1
#define kBlueId  2

#define kRed     (1 | (kRedId << kFirstChannelShift))
#define kGreen   (1 | (kGreenId << kFirstChannelShift))
#define kBlue    (1 | (kBlueId << kFirstChannelShift))
#define kMagenta (2 | (kRedId << kFirstChannelShift) | (kBlueId << kSecondChannelShift))
#define kYellow  (2 | (kRedId << kFirstChannelShift) | (kGreenId << kSecondChannelShift))
#define kCyan    (2 | (kGreenId << kFirstChannelShift) | (kBlueId << kSecondChannelShift))
#define kWhite   (3 | (kRedId << kFirstChannelShift) | (kGreenId << kSecondChannelShift) | (kBlueId << kThirdChannelShift))
#define kBlack   0

#define kRedChannel     vec3(1.0, 0.0, 0.0)
#define kGreenChannel   vec3(0.0, 1.0, 0.0)
#define kBlueChannel    vec3(0.0, 0.0, 1.0)

const vec3 kColourMask[3] = { kRedChannel, kGreenChannel, kBlueChannel };

#define kApertureGrille    0
#define kShadowMask        1
#define kSlotMask          2
#define kBlackWhiteMask    3

#define kBGRAxis           4
#define kTVLAxis           4
#define kResolutionAxis    3

// APERTURE GRILLE MASKS

const float kApertureGrilleMaskSize[kResolutionAxis * kTVLAxis] = { 
     4.0f, 2.0f, 1.0f, 1.0f ,      // 1080p:   300 TVL, 600 TVL, 800 TVL, 1000 TVL 
     7.0f, 4.0f, 3.0f, 2.0f ,      // 4K:      300 TVL, 600 TVL, 800 TVL, 1000 TVL   
    13.0f, 7.0f, 5.0f, 4.0f   };   // 8K:      300 TVL, 600 TVL, 800 TVL, 1000 TVL

// SHADOW MASKS

const float kShadowMaskSizeX[kResolutionAxis * kTVLAxis] = {   6.0f, 2.0f, 1.0f, 1.0f  ,   12.0f, 6.0f, 2.0f, 2.0f  ,   12.0f, 12.0f, 6.0f, 6.0f   }; 
const float kShadowMaskSizeY[kResolutionAxis * kTVLAxis] = {   4.0f, 2.0f, 1.0f, 1.0f  ,    8.0f, 4.0f, 2.0f, 2.0f  ,    8.0f,  8.0f, 4.0f, 4.0f   }; 

// SLOT MASKS

const float kSlotMaskSizeX[kResolutionAxis * kTVLAxis] = {   
    4.0f, 2.0f, 1.0f, 1.0f,   // 1080p: 300 TVL, 600 TVL, 800 TVL, 1000 TVL
    7.0f, 4.0f, 3.0f, 2.0f,   // 4K:    300 TVL, 600 TVL, 800 TVL, 1000 TVL
    7.0f, 7.0f, 5.0f, 4.0f    // 8K:    300 TVL, 600 TVL, 800 TVL, 1000 TVL
}; 

const float kSlotMaskSizeY[kResolutionAxis * kTVLAxis] = {   
    4.0f, 4.0f, 1.0f, 1.0f,   // 1080p: 300 TVL, 600 TVL, 800 TVL, 1000 TVL
    8.0f, 6.0f, 4.0f, 4.0f,   // 4K: 	300 TVL, 600 TVL, 800 TVL, 1000 TVL
    6.0f, 6.0f, 4.0f, 4.0f    // 8K: 	300 TVL, 600 TVL, 800 TVL, 1000 TVL
};

// Pattern definitions
#define kRGBX             ((kRed  << 0) | (kGreen << 4) | (kBlue  << 8) | (kBlack << 12))
#define kRBGX             ((kRed  << 0) | (kBlue  << 4) | (kGreen << 8) | (kBlack << 12))
#define kBGRX             ((kBlue << 0) | (kGreen << 4) | (kRed   << 8) | (kBlack << 12))
#define kBRGX             ((kBlue << 0) | (kRed << 4) | (kGreen   << 8) | (kBlack << 12))
#define kMG               ((kMagenta << 0) | (kGreen   << 6))
#define kYB               ((kYellow  << 0) | (kBlue    << 6))
#define kBY               ((kBlue    << 0) | (kYellow  << 6))
#define kGM               ((kGreen   << 0) | (kMagenta << 6))
#define kRC               ((kRed << 0) | (kCyan << 6))
#define kCR               ((kCyan << 0) | (kRed << 6))
#define kRRGGBBX          ((kRed  << 0) | (kRed  << 4) | (kGreen << 8) | (kGreen << 12) | (kBlue  << 16) | (kBlue  << 20) | (kBlack << 24))
#define kRRBBGGX          ((kRed  << 0) | (kRed  << 4) | (kBlue  << 8) | (kBlue  << 12) | (kGreen << 16) | (kGreen << 20) | (kBlack << 24))
#define kBBGGRRX          ((kBlue << 0) | (kBlue << 4) | (kGreen << 8) | (kGreen << 12) | (kRed   << 16) | (kRed   << 20) | (kBlack << 24))
#define kBBRRGGX          ((kBlue << 0) | (kBlue << 4) | (kRed << 8) | (kRed << 12) | (kGreen   << 16) | (kGreen   << 20) | (kBlack << 24))
#define kBGR              ((kBlue  << 0) | (kGreen << 4) | (kRed  << 8))
#define kGBR              ((kGreen << 0) | (kBlue  << 4) | (kRed  << 8))
#define kRGB              ((kRed   << 0) | (kGreen << 4) | (kBlue << 8))
#define kGRB              ((kGreen   << 0) | (kRed << 4) | (kBlue << 8))
#define kRYCBX            ((kRed  << 0) | (kYellow  << 6) | (kCyan   << 12) | (kBlue  << 18) | (kBlack << 24))
#define kRMCGX            ((kRed  << 0) | (kMagenta << 6) | (kCyan   << 12) | (kGreen << 18) | (kBlack << 24))
#define kBCYRX            ((kBlue << 0) | (kCyan    << 6) | (kYellow << 12) | (kRed   << 18) | (kBlack << 24))
#define kBMYGX            ((kBlue << 0) | (kMagenta    << 6) | (kYellow << 12) | (kGreen   << 18) | (kBlack << 24))
#define kGRRBBG           ((kGreen << 0) | (kRed   << 4) | (kRed   << 8) | (kBlue  << 12) | (kBlue  << 16) | (kGreen << 20))
#define kBBGGRR           ((kBlue  << 0) | (kBlue  << 4) | (kGreen << 8) | (kGreen << 12) | (kRed   << 16) | (kRed   << 20))
#define kBRRGGB           ((kBlue  << 0) | (kRed   << 4) | (kRed   << 8) | (kGreen << 12) | (kGreen << 16) | (kBlue  << 20))
#define kGGBBRR           ((kGreen << 0) | (kGreen << 4) | (kBlue  << 8) | (kBlue  << 12) | (kRed   << 16) | (kRed   << 20))
#define kGBBRRG           ((kGreen << 0) | (kBlue  << 4) | (kBlue  << 8) | (kRed   << 12) | (kRed   << 16) | (kGreen << 20))
#define kRRGGBB           ((kRed   << 0) | (kRed   << 4) | (kGreen << 8) | (kGreen << 12) | (kBlue  << 16) | (kBlue  << 20))
#define kRBBGGR           ((kRed   << 0) | (kBlue   << 4) | (kBlue << 8) | (kGreen << 12) | (kGreen  << 16) | (kRed  << 20))
#define kGGRRBB           ((kGreen   << 0) | (kGreen   << 4) | (kRed << 8) | (kRed << 12) | (kBlue  << 16) | (kBlue  << 20))

// LUTs for each screen type
const uint kApertureGrilleLUT[kResolutionAxis][kTVLAxis][kBGRAxis] = {
    // 1080p
    {
        { kRGBX, kRBGX, kBGRX, kBRGX },              // 300 TVL
        { kMG, kYB, kGM, kRC },                    // 600 TVL
        { kWhite, kWhite, kWhite, kWhite },           // 800 TVL
        { kWhite, kWhite, kWhite, kWhite }            // 1000 TVL
    },
    // 4K
    {
        { kRRGGBBX, kRRBBGGX, kBBGGRRX, kBBRRGGX },     // 300 TVL
        { kRGBX, kRBGX, kBGRX, kBRGX },              // 600 TVL
        { kBGR, kGBR, kRGB, kGRB },                 // 800 TVL
        { kMG, kYB, kGM, kRC }                     // 1000 TVL
    },
    // 8K
    {
        // 300 TVL uses a specialized lookup
        { 0, 0, 0, 0 },                          // Placeholder (handled specially)
        { kRRGGBBX, kRRBBGGX, kBBGGRRX, kBBRRGGX },     // 600 TVL
        { kRYCBX, kRMCGX, kBCYRX, kBMYGX },           // 800 TVL
        { kRGBX, kRBGX, kBGRX, kBRGX }               // 1000 TVL
    }
};

// For mask shifts
const uint kApertureGrilleShifts[kResolutionAxis][kTVLAxis] = {
    { 4, 6, 0, 0 },  // 1080p
    { 4, 4, 4, 6 },  // 4K
    { 0, 4, 6, 4 }   // 8K
};

const uint kApertureGrilleMasks[kResolutionAxis][kTVLAxis] = {
    { 0xF, 0x3F, 0, 0 },  // 1080p
    { 0xF, 0xF, 0xF, 0x3F }, // 4K
    { 0, 0xF, 0x3F, 0xF }   // 8K
};

// Shadow mask LUTs
const uint kShadowMaskLUT_Row0[kResolutionAxis][kTVLAxis][kBGRAxis] = {
    // 1080p
    {
        { kGRRBBG, kBRRGGB, kGBBRRG, kRBBGGR },        // 300 TVL
        { kMG, kYB, kGM, kRC },                    // 600 TVL
        { kWhite, kWhite, kWhite, kWhite },           // 800 TVL
        { kWhite, kWhite, kWhite, kWhite }            // 1000 TVL
    },
    // 4K and 8K handled separately
    { {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0} },
    { {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0} }
};

const uint kShadowMaskLUT_Row1[kResolutionAxis][kTVLAxis][kBGRAxis] = {
    // 1080p
    {
        { kBBGGRR, kGGBBRR, kRRGGBB, kGGRRBB },        // 300 TVL
        { kGM, kBY, kMG, kCR },                    // 600 TVL
        { kWhite, kWhite, kWhite, kWhite },           // 800 TVL
        { kWhite, kWhite, kWhite, kWhite }            // 1000 TVL
    },
    // 4K and 8K handled separately
    { {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0} },
    { {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0} }
};

// Slot mask LUTs
const uint kSlotMaskLUT[kResolutionAxis][kTVLAxis][kBGRAxis] = {
    // 1080p
    {
        { kRGBX, kRBGX, kBGRX, kBRGX },              // 300 TVL
        { kMG, kYB, kGM, kRC },                    // 600 TVL
        { kWhite, kWhite, kWhite, kWhite },           // 800 TVL
        { kWhite, kWhite, kWhite, kWhite }            // 1000 TVL
    },
    // 4K
    {
        { kRRGGBBX, kRRBBGGX, kBBGGRRX, kBBRRGGX },     // 300 TVL
        { kRGBX, kRBGX, kBGRX, kBRGX },              // 600 TVL
        { kBGR, kGBR, kRGB, kGRB },                 // 800 TVL
        { kMG, kYB, kGM, kRC }                     // 1000 TVL
    },
    // 8K
    {
        { kRRGGBBX, kRRBBGGX, kBBGGRRX, kBBRRGGX },     // 300 TVL
        { kRRGGBBX, kRRBBGGX, kBBGGRRX, kBBRRGGX },     // 600 TVL
        { kRYCBX, kRMCGX, kBCYRX , kBMYGX },           // 800 TVL
        { kRGBX, kRBGX, kBGRX, kBRGX }               // 1000 TVL
    }
};

// Special patterns for 8K 300TVL Aperture Grille
const uint kApertureGrille8K300TVL[13][4] = {
    { kRed,   kRed,   kBlue,  kBlue  },
    { kRed,   kRed,   kBlue,  kBlue  },
    { kRed,   kRed,   kBlue,  kBlue  },
    { kRed,   kRed,   kBlue,  kBlue  },
    { kGreen, kBlue,  kGreen, kRed   },
    { kGreen, kBlue,  kGreen, kRed   },
    { kGreen, kBlue,  kGreen, kRed   },
    { kGreen, kBlue,  kGreen, kRed   },
    { kBlue,  kGreen, kRed,   kGreen },
    { kBlue,  kGreen, kRed,   kGreen },
    { kBlue,  kGreen, kRed,   kGreen },
    { kBlue,  kGreen, kRed,   kGreen },
    { kBlack, kBlack, kBlack, kBlack }
};

#include "include/scanline_generation.h"
#include "include/gamma_correct.h"

#define k1080p     0
#define k4K        1
#define k8K        2

#define k300TVL    0
#define k600TVL    1
#define k800TVL    2
#define k1000TVL   3

#define kMaxSlotSizeX 2

// Function to get color mask for aperture grille
uint GetApertureGrilleMask(uint lcd_resolution, uint crt_resolution, uint lcd_subpixel, vec2 current_pos) {
    const int index = int(lcd_resolution * kTVLAxis + crt_resolution);
    const float maskSize = kApertureGrilleMaskSize[index];
    const uint mask = uint(floor(mod(current_pos.x, maskSize)));
    
    // Special case for 8K 300TVL
    if (lcd_resolution == k8K && crt_resolution == k300TVL) {
        if (mask < 13) { // Only first 13 positions defined in array
            return kApertureGrille8K300TVL[mask][lcd_subpixel];
        }
        return (mask < 13) ? kRed : kBlack; // Default
    }
    
    const uint pattern = kApertureGrilleLUT[lcd_resolution][crt_resolution][lcd_subpixel];
    
    // Use white directly if pattern is white
    if (pattern == kWhite) return kWhite;
    
    // Use the appropriate shift and mask
    const uint shift = kApertureGrilleShifts[lcd_resolution][crt_resolution];
    const uint mask_bits = kApertureGrilleMasks[lcd_resolution][crt_resolution];
    
    if (shift == 0 || mask_bits == 0) return pattern; // No shift needed
    
    return (pattern >> (mask * shift)) & mask_bits;
}

// Function to get color mask for shadow mask
uint GetShadowMask(uint lcd_resolution, uint crt_resolution, uint lcd_subpixel, vec2 current_pos) {
    const int index = int(lcd_resolution * kTVLAxis + crt_resolution);
    const float maskSizeX = kShadowMaskSizeX[index];
    const float maskSizeY = kShadowMaskSizeY[index];
    
    const uint mask = uint(floor(mod(current_pos.x, maskSizeX)));
    const uint shadow_y = uint(floor(mod(current_pos.y, maskSizeY)));
    
    // 1080p lookup
    if (lcd_resolution == k1080p) {
        uint pattern;
		
        // FIX: 300TVL has a height of 4 (split at 2), 600TVL has a height of 2 (split at 1)
        uint split_point = (crt_resolution == k600TVL) ? 1 : 2;
		
        if (shadow_y < split_point) {
            pattern = kShadowMaskLUT_Row0[lcd_resolution][crt_resolution][lcd_subpixel];
        } else {
            pattern = kShadowMaskLUT_Row1[lcd_resolution][crt_resolution][lcd_subpixel];
        }
        
        // Special cases where pattern is direct value
        if (crt_resolution == k800TVL || crt_resolution == k1000TVL) {
            return pattern;
        }
        
        // Apply mask
        uint shift_amount = (crt_resolution == k300TVL) ? 4 : 6;
        uint mask_bits = (crt_resolution == k300TVL) ? 0xF : 0x3F;
        
        return (pattern >> (mask * shift_amount)) & mask_bits;
    }
    
    // 4K special case
    if (lcd_resolution == k4K) {
        if (crt_resolution == k300TVL) {
            // Special pattern selection for 4K 300TVL
            if (shadow_y < 4) {
                if (lcd_subpixel == 0) return (mask < 12) ? ((mask < 2) ? kGreen : ((mask < 6) ? kRed : ((mask < 10) ? kBlue : kGreen))) : kBlack;
                if (lcd_subpixel == 1) return (mask < 12) ? ((mask < 2) ? kBlue : ((mask < 6) ? kRed : ((mask < 10) ? kGreen : kBlue))) : kBlack;
                if (lcd_subpixel == 2) return (mask < 12) ? ((mask < 2) ? kGreen : ((mask < 6) ? kBlue : ((mask < 10) ? kRed : kGreen))) : kBlack;
                if (lcd_subpixel == 3) return (mask < 12) ? ((mask < 2) ? kRed : ((mask < 6) ? kBlue : ((mask < 10) ? kGreen : kRed))) : kBlack;
            } else {
                if (lcd_subpixel == 0) return (mask < 12) ? ((mask < 4) ? kBlue : ((mask < 8) ? kGreen : kRed)) : kBlack;
                if (lcd_subpixel == 1) return (mask < 12) ? ((mask < 4) ? kGreen : ((mask < 8) ? kBlue : kRed)) : kBlack;
                if (lcd_subpixel == 2) return (mask < 12) ? ((mask < 4) ? kRed : ((mask < 8) ? kGreen : kBlue)) : kBlack;
                if (lcd_subpixel == 3) return (mask < 12) ? ((mask < 4) ? kGreen : ((mask < 8) ? kRed : kBlue)) : kBlack;
            }
            return kBlack;
        } else {
            // 4K other resolutions
            // 600TVL (height 4) splits at 2; others (height 2) split at 1
            if (shadow_y < ((crt_resolution == k600TVL) ? 2 : 1)) {
                if (crt_resolution == k600TVL) {
                    uint pattern = (lcd_subpixel == 0) ? kGRRBBG : (lcd_subpixel == 1) ? kBRRGGB : ((lcd_subpixel == 2) ? kGBBRRG : kRBBGGR);
                    return (pattern >> (mask * 4)) & 0xF;
                } else {
                    uint pattern = (lcd_subpixel == 0) ? kMG : (lcd_subpixel == 1) ? kYB : ((lcd_subpixel == 2) ? kGM : kRC);
                    return (pattern >> (mask * 6)) & 0x3F;
                }
            } else {
                if (crt_resolution == k600TVL) {
                    uint pattern = (lcd_subpixel == 0) ? kBBGGRR : (lcd_subpixel == 1) ? kGGBBRR : ((lcd_subpixel == 2) ? kRRGGBB: kRBBGGR);
                    return (pattern >> (mask * 4)) & 0xF;
                } else {
                    uint pattern = (lcd_subpixel == 0) ? kGM : (lcd_subpixel == 1) ? kBY : ((lcd_subpixel == 2) ? kMG: kCR);
                    return (pattern >> (mask * 6)) & 0x3F;
                }
            }
        }
    }
    
    // 8K handling
    if (lcd_resolution == k8K) {
        // 8K 300TVL and 600TVL use the specific 4K-style pattern generation
        if (crt_resolution == k300TVL || crt_resolution == k600TVL) {
            if (shadow_y < 4) {
                if (lcd_subpixel == 0) return (mask < 12) ? ((mask < 2) ? kGreen : ((mask < 6) ? kRed : ((mask < 10) ? kBlue : kGreen))) : kBlack;
                if (lcd_subpixel == 1) return (mask < 12) ? ((mask < 2) ? kBlue : ((mask < 6) ? kRed : ((mask < 10) ? kGreen : kBlue))) : kBlack;
                if (lcd_subpixel == 2) return (mask < 12) ? ((mask < 2) ? kGreen : ((mask < 6) ? kBlue : ((mask < 10) ? kRed : kGreen))) : kBlack;
                if (lcd_subpixel == 3) return (mask < 12) ? ((mask < 2) ? kRed : ((mask < 6) ? kBlue : ((mask < 10) ? kGreen : kRed))) : kBlack;
            } else {
                if (lcd_subpixel == 0) return (mask < 12) ? ((mask < 4) ? kBlue : ((mask < 8) ? kGreen : kRed)) : kBlack;
                if (lcd_subpixel == 1) return (mask < 12) ? ((mask < 4) ? kGreen : ((mask < 8) ? kBlue : kRed)) : kBlack;
                if (lcd_subpixel == 2) return (mask < 12) ? ((mask < 4) ? kRed : ((mask < 8) ? kGreen : kBlue)) : kBlack;
                if (lcd_subpixel == 3) return (mask < 12) ? ((mask < 4) ? kGreen : ((mask < 8) ? kRed : kBlue)) : kBlack;
            }
            return kBlack;
        } else {
            // 8K other resolutions (800TVL, 1000TVL)
            if (shadow_y < 2) {
                uint pattern = (lcd_subpixel == 0) ? kGRRBBG : (lcd_subpixel == 1) ? kBRRGGB : ((lcd_subpixel == 2) ? kGBBRRG : kRBBGGR);
                return (pattern >> (mask * 4)) & 0xF;
            } else {
                uint pattern = (lcd_subpixel == 0) ? kBBGGRR : (lcd_subpixel == 1) ? kGGBBRR : ((lcd_subpixel == 2) ? kRRGGBB : kGGRRBB);
                return (pattern >> (mask * 4)) & 0xF;
            }
        }
    }
    
    return kBlack;
}

// Function to get color mask for slot mask
uint GetSlotMask(uint lcd_resolution, uint crt_resolution, uint lcd_subpixel, vec2 current_pos) {
    const int index = int(lcd_resolution * kTVLAxis + crt_resolution);
    const float maskSizeX = kSlotMaskSizeX[index];
    const float maskSizeY = kSlotMaskSizeY[index];
    
    const uint slot_x = uint(floor(mod(current_pos.x / maskSizeX, kMaxSlotSizeX)));
    const uint slot_y = uint(floor(mod(current_pos.y, maskSizeY)));
    const uint element = (slot_y * kMaxSlotSizeX) + slot_x;
    const uint mask = uint(floor(mod(current_pos.x, maskSizeX)));
    
    // Handle Black Slots (Blank elements)
    if (lcd_resolution == k1080p) {
        if (element == 3 || element == 6) return kBlack;
    } else if (lcd_resolution == k4K) {
        if (crt_resolution == k300TVL) {
            if (element == 7 || element == 14) return kBlack;
        } else if (crt_resolution == k600TVL) {
             // FIX: 4K 600TVL uses 5/10 in old shader, not 3/6
            if (element == 5 || element == 10) return kBlack;
        } else {
            if (element == 3 || element == 6) return kBlack; 
        }
    } else if (lcd_resolution == k8K) {
        if (crt_resolution == k800TVL) {
             if (element == 3 || element == 6) return kBlack;
        } else {
             // FIX: 8K 300, 600 and 1000TVL use 5/10 in old shader
             if (element == 5 || element == 10) return kBlack;
        }
    }
    
    // Get pattern from LUT
    const uint pattern = kSlotMaskLUT[lcd_resolution][crt_resolution][lcd_subpixel];
    
    // FIX: Removed the early return for 1080p 800/1000TVL so the black slot check above applies.
    if (lcd_resolution == k1080p && (crt_resolution == k800TVL || crt_resolution == k1000TVL)) {
        return kWhite;
    }
    
    // Apply specific bit shifting for each resolution and TVL
    if (lcd_resolution == k4K) {
        if (crt_resolution == k800TVL) {
            return (pattern >> (mask * 4)) & 0xF;
        } else if (crt_resolution == k1000TVL) {
            return (pattern >> (mask * 6)) & 0x3F;
        } else {
            return (pattern >> (mask * 4)) & 0xF;
        }
    } else if (lcd_resolution == k8K) {
        if (crt_resolution == k800TVL) {
            return (pattern >> (mask * 6)) & 0x3F;
        } else {
            return (pattern >> (mask * 4)) & 0xF;
        }
    } else if (lcd_resolution == k1080p) {
        if (crt_resolution == k300TVL) {
            return (pattern >> (mask * 4)) & 0xF;
        } else if (crt_resolution == k600TVL) {
            return (pattern >> (mask * 6)) & 0x3F;
        }
    }
    
    // Default fallback
    return (pattern >> (mask * 4)) & 0xF;
}

void main()
{
   const uint screen_type           = uint(HCRT_CRT_SCREEN_TYPE);
   const uint crt_resolution        = uint(HCRT_CRT_RESOLUTION);
   const uint lcd_resolution        = uint(HCRT_LCD_RESOLUTION);
   const uint lcd_subpixel_layout   = uint(HCRT_LCD_SUBPIXEL);
   
	float OriginalSizeX = global.OriginalSize.x;
	float OriginalSizeY = global.OriginalSize.y;
	float scanline_multi = HCRT_SCANLINE_MULTI;
	float ntsc_pseudo = NTSC_PSEUDO;
//	float auto_res = AUTO_RES;
	float ntsc_pseudo_div = 1;
	float scanlinemult = 1;
	
	if (ntsc_pseudo == 1) { ntsc_pseudo_div = 1; }
	
	if (ntsc_pseudo == 2) { ntsc_pseudo_div = 1; }
	
	if (ntsc_pseudo == 3)
	{
	   if (OriginalSizeX >= 480) 
	   {
	   if ((OriginalSizeX / OriginalSizeY) >= 2) { ntsc_pseudo_div = 1; }
	   else if ((OriginalSizeX / OriginalSizeY) < 2) { ntsc_pseudo_div = 0.5; }
	   }
	   else if (OriginalSizeX < 480) { ntsc_pseudo_div = 1; }
	}
	
	if (scanline_multi == 1) { scanlinemult = 1; }
	else if (scanline_multi == 2) { scanlinemult = 2; }
	else if (scanline_multi == 3)
	{
	if (ntsc_pseudo == 1)
	{
   if (OriginalSizeY >= 300) { scanlinemult = 1; }
   else if (OriginalSizeY < 300) { scanlinemult = 2; }
	}
	if (ntsc_pseudo == 2)
	{
   if (OriginalSizeY >= 300) { scanlinemult = 1; }
   else if (OriginalSizeY < 300) { scanlinemult = 2; }
	}
	else if (ntsc_pseudo == 3)
	{
   if (OriginalSizeY >= 300) { scanlinemult = 2; }
   else if (OriginalSizeY < 300) { scanlinemult = 2; }
	}
	}
	if (scanline_multi == 0) { scanlinemult = 1; }	
	if (scanline_multi == -1) { scanlinemult = 1; }	
	else if (scanline_multi == -2) { scanlinemult = 0.5; }
	else if (scanline_multi == -3) { scanlinemult = 0.33333333333333333333333333333333; }
	else if (scanline_multi == -4) { scanlinemult = 0.25; }
	else if (scanline_multi == -5) { scanlinemult = 0.2; }
	else if (scanline_multi == -6) { scanlinemult = 0.16666666666666666666666666666667; }
	else if (scanline_multi == -7) { scanlinemult = 0.14285714285714285714285714285714; }
	else if (scanline_multi == -8) { scanlinemult = 0.125; }
	else if (scanline_multi == -9) { scanlinemult = 0.11111111111111111111111111111111; }
	else if (scanline_multi == -10) { scanlinemult = 0.1; }
	else if (scanline_multi == -11) { scanlinemult = 0.09090909090909090909090909090909; }
	else if (scanline_multi == -12) { scanlinemult = 0.08333333333333333333333333333333; }
	else if (scanline_multi == -13) { scanlinemult = 0.07692307692307692307692307692308; }
	else if (scanline_multi == -14) { scanlinemult = 0.07142857142857142857142857142857; }
	else if (scanline_multi == -15) { scanlinemult = 0.06666666666666666666666666666667; }
	else if (scanline_multi == -16) { scanlinemult = 0.0625; }


	
   const vec2 source_size           = (global.SourceSize.xy * ntsc_pseudo_div) * scanlinemult;

   const vec2 output_size           = global.OutputSize.xy;

   vec2 tex_coord                   = vTexCoord - vec2(0.5f);
   tex_coord                        = tex_coord * vec2(HCRT_H_SIZE, HCRT_V_SIZE);
   tex_coord                        = tex_coord + vec2(0.5f);
   tex_coord                        = tex_coord + (vec2(HCRT_H_CENT, HCRT_V_CENT) / output_size); 

   const vec2 current_position      = vTexCoord * output_size;

   uint colour_mask = 0;

   // Get the appropriate mask based on screen type
   if (screen_type == kApertureGrille) {
      colour_mask = GetApertureGrilleMask(lcd_resolution, crt_resolution, lcd_subpixel_layout, current_position);
   } else if (screen_type == kShadowMask) {
      colour_mask = GetShadowMask(lcd_resolution, crt_resolution, lcd_subpixel_layout, current_position);
   } else if (screen_type == kSlotMask) {
      colour_mask = GetSlotMask(lcd_resolution, crt_resolution, lcd_subpixel_layout, current_position);
   }

   const float scanline_size           = output_size.y / source_size.y;

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
      const uint channel_0       = (colour_mask >> kFirstChannelShift) & 3;

      float scanline_channel_0   = GenerateScanline(channel_0,
                                                    tex_coord,
                                                    source_size.xy, 
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
      const uint channel_1       = (colour_mask >> kSecondChannelShift) & 3;

      float scanline_channel_1   = GenerateScanline(channel_1,
                                                    tex_coord,
                                                    source_size.xy, 
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

   if(channel_count > 2)
   {
      const uint channel_2       = (colour_mask >> kThirdChannelShift) & 3;

      float scanline_channel_2   = GenerateScanline(channel_2,
													tex_coord,
													source_size.xy, 
													scanline_size, 
													horizontal_convergence[channel_2], 
													vertical_convergence[channel_2], 
													beam_sharpness[channel_2], 
													beam_attack[channel_2], 
													scanline_min[channel_2], 
													scanline_max[channel_2], 
													scanline_attack[channel_2]);

      scanline_colour += scanline_channel_2 * kColourMask[channel_2];
   }

   vec3 transformed_colour;

   if(HCRT_HDR >= 1.0f)
   {
      const vec3 rec2020  = scanline_colour * k2020Gamuts[uint(HCRT_content_gamut)];
      transformed_colour  = rec2020 * (HCRT_PAPER_WHITE_NITS / kMaxNitsFor2084);
   }
   else if(HCRT_OUTPUT_COLOUR_SPACE == 2.0f)
   {
      transformed_colour = (scanline_colour * k709_to_XYZ) * kXYZ_to_DCIP3; 
   }
   else
   {
      transformed_colour = scanline_colour;
   }

   vec3 gamma_corrected; 
   
   GammaCorrect(transformed_colour, gamma_corrected);

   FragColor = vec4(gamma_corrected, 1.0f);
}
