/* 
A shader that tries to emulate a sony PVM type aperture grille screen but with full brightness.

The novel thing about this shader is that it relies on the HDR shaders to brighten up the image so that when 
we apply this shader which emulates the apperture grille the resulting screen isn't left too dark.  

I think you need at least a DisplayHDR 600 monitor but to get close to CRT levels of brightness I think DisplayHDR 1000.

Please Enable HDR in RetroArch 1.22+

For this shader set Paper White Luminance to 200 and Peak Luminance to the peak luminance of your monitor.  

This shader doesn't do any geometry warping or bouncing of light around inside the screen etc
*/

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

#define kBGRAxis           3
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
#define kMG               ((kMagenta << 0) | (kGreen   << 6))
#define kYB               ((kYellow  << 0) | (kBlue    << 6))
#define kBY               ((kBlue    << 0) | (kYellow  << 6))
#define kGM               ((kGreen   << 0) | (kMagenta << 6))
#define kRRGGBBX          ((kRed  << 0) | (kRed  << 4) | (kGreen << 8) | (kGreen << 12) | (kBlue  << 16) | (kBlue  << 20) | (kBlack << 24))
#define kRRBBGGX          ((kRed  << 0) | (kRed  << 4) | (kBlue  << 8) | (kBlue  << 12) | (kGreen << 16) | (kGreen << 20) | (kBlack << 24))
#define kBBGGRRX          ((kBlue << 0) | (kBlue << 4) | (kGreen << 8) | (kGreen << 12) | (kRed   << 16) | (kRed   << 20) | (kBlack << 24))
#define kBGR              ((kBlue  << 0) | (kGreen << 4) | (kRed  << 8))
#define kGBR              ((kGreen << 0) | (kBlue  << 4) | (kRed  << 8))
#define kRGB              ((kRed   << 0) | (kGreen << 4) | (kBlue << 8))
#define kRYCBX            ((kRed  << 0) | (kYellow  << 6) | (kCyan   << 12) | (kBlue  << 18) | (kBlack << 24))
#define kRMCGX            ((kRed  << 0) | (kMagenta << 6) | (kCyan   << 12) | (kGreen << 18) | (kBlack << 24))
#define kBCYRX            ((kBlue << 0) | (kCyan    << 6) | (kYellow << 12) | (kRed   << 18) | (kBlack << 24))
#define kGRRBBG           ((kGreen << 0) | (kRed   << 4) | (kRed   << 8) | (kBlue  << 12) | (kBlue  << 16) | (kGreen << 20))
#define kBBGGRR           ((kBlue  << 0) | (kBlue  << 4) | (kGreen << 8) | (kGreen << 12) | (kRed   << 16) | (kRed   << 20))
#define kBRRGGB           ((kBlue  << 0) | (kRed   << 4) | (kRed   << 8) | (kGreen << 12) | (kGreen << 16) | (kBlue  << 20))
#define kGGBBRR           ((kGreen << 0) | (kGreen << 4) | (kBlue  << 8) | (kBlue  << 12) | (kRed   << 16) | (kRed   << 20))
#define kGBBRRG           ((kGreen << 0) | (kBlue  << 4) | (kBlue  << 8) | (kRed   << 12) | (kRed   << 16) | (kGreen << 20))
#define kRRGGBB           ((kRed   << 0) | (kRed   << 4) | (kGreen << 8) | (kGreen << 12) | (kBlue  << 16) | (kBlue  << 20))

// LUTs for each screen type
const uint kApertureGrilleLUT[kResolutionAxis][kTVLAxis][kBGRAxis] = {
    // 1080p
    {
        { kRGBX, kRBGX, kBGRX },              // 300 TVL
        { kMG, kYB, kGM },                    // 600 TVL
        { kWhite, kWhite, kWhite },           // 800 TVL
        { kWhite, kWhite, kWhite }            // 1000 TVL
    },
    // 4K
    {
        { kRRGGBBX, kRRBBGGX, kBBGGRRX },     // 300 TVL
        { kRGBX, kRBGX, kBGRX },              // 600 TVL
        { kBGR, kGBR, kRGB },                 // 800 TVL
        { kMG, kYB, kGM }                     // 1000 TVL
    },
    // 8K
    {
        // 300 TVL uses a specialized lookup
        { 0, 0, 0 },                          // Placeholder (handled specially)
        { kRRGGBBX, kRRBBGGX, kBBGGRRX },     // 600 TVL
        { kRYCBX, kRMCGX, kBCYRX },           // 800 TVL
        { kRGBX, kRBGX, kBGRX }               // 1000 TVL
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
        { kGRRBBG, kBRRGGB, kGBBRRG },        // 300 TVL
        { kMG, kYB, kGM },                    // 600 TVL
        { kWhite, kWhite, kWhite },           // 800 TVL
        { kWhite, kWhite, kWhite }            // 1000 TVL
    },
    // 4K and 8K handled separately
    { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} },
    { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} }
};

const uint kShadowMaskLUT_Row1[kResolutionAxis][kTVLAxis][kBGRAxis] = {
    // 1080p
    {
        { kBBGGRR, kGGBBRR, kRRGGBB },        // 300 TVL
        { kGM, kBY, kMG },                    // 600 TVL
        { kWhite, kWhite, kWhite },           // 800 TVL
        { kWhite, kWhite, kWhite }            // 1000 TVL
    },
    // 4K and 8K handled separately
    { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} },
    { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} }
};

// Slot mask LUTs
const uint kSlotMaskLUT[kResolutionAxis][kTVLAxis][kBGRAxis] = {
    // 1080p
    {
        { kRGBX, kRBGX, kBGRX },              // 300 TVL
        { kMG, kYB, kGM },                    // 600 TVL
        { kWhite, kWhite, kWhite },           // 800 TVL
        { kWhite, kWhite, kWhite }            // 1000 TVL
    },
    // 4K
    {
        { kRRGGBBX, kRRBBGGX, kBBGGRRX },     // 300 TVL
        { kRGBX, kRBGX, kBGRX },              // 600 TVL
        { kBGR, kGBR, kRGB },                 // 800 TVL
        { kMG, kYB, kGM }                     // 1000 TVL
    },
    // 8K
    {
        { kRRGGBBX, kRRBBGGX, kBBGGRRX },     // 300 TVL
        { kRRGGBBX, kRRBBGGX, kBBGGRRX },     // 600 TVL
        { kRYCBX, kRMCGX, kBCYRX },           // 800 TVL
        { kRGBX, kRBGX, kBGRX }               // 1000 TVL
    }
};

// Special patterns for 8K 300TVL Aperture Grille
const uint kApertureGrille8K300TVL[13][3] = {
    { kRed,   kRed,   kBlue  },
    { kRed,   kRed,   kBlue  },
    { kRed,   kRed,   kBlue  },
    { kRed,   kRed,   kBlue  },
    { kGreen, kBlue,  kGreen },
    { kGreen, kBlue,  kGreen },
    { kGreen, kBlue,  kGreen },
    { kGreen, kBlue,  kGreen },
    { kBlue,  kGreen, kRed   },
    { kBlue,  kGreen, kRed   },
    { kBlue,  kGreen, kRed   },
    { kBlue,  kGreen, kRed   },
    { kBlack, kBlack, kBlack }
};

#include "inverse_tonemap.h"
#include "scanline_generation.h"
#include "gamma_correct.h"

/* Convert Rec.709 linear to Rec.2020 linear via Colour Space setting.
 * The mismatch between the conversion matrix and the final k2020_to_sRGB
 * in the output stage creates the colour boost effect. */
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
            } else {
                if (lcd_subpixel == 0) return (mask < 12) ? ((mask < 4) ? kBlue : ((mask < 8) ? kGreen : kRed)) : kBlack;
                if (lcd_subpixel == 1) return (mask < 12) ? ((mask < 4) ? kGreen : ((mask < 8) ? kBlue : kRed)) : kBlack;
                if (lcd_subpixel == 2) return (mask < 12) ? ((mask < 4) ? kRed : ((mask < 8) ? kGreen : kBlue)) : kBlack;
            }
            return kBlack;
        } else {
            // 4K other resolutions
            // 600TVL (height 4) splits at 2; others (height 2) split at 1
            if (shadow_y < ((crt_resolution == k600TVL) ? 2 : 1)) {
                if (crt_resolution == k600TVL) {
                    uint pattern = (lcd_subpixel == 0) ? kGRRBBG : ((lcd_subpixel == 1) ? kBRRGGB : kGBBRRG);
                    return (pattern >> (mask * 4)) & 0xF;
                } else {
                    uint pattern = (lcd_subpixel == 0) ? kMG : ((lcd_subpixel == 1) ? kYB : kGM);
                    return (pattern >> (mask * 6)) & 0x3F;
                }
            } else {
                if (crt_resolution == k600TVL) {
                    uint pattern = (lcd_subpixel == 0) ? kBBGGRR : ((lcd_subpixel == 1) ? kGGBBRR : kRRGGBB);
                    return (pattern >> (mask * 4)) & 0xF;
                } else {
                    uint pattern = (lcd_subpixel == 0) ? kGM : ((lcd_subpixel == 1) ? kBY : kMG);
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
            } else {
                if (lcd_subpixel == 0) return (mask < 12) ? ((mask < 4) ? kBlue : ((mask < 8) ? kGreen : kRed)) : kBlack;
                if (lcd_subpixel == 1) return (mask < 12) ? ((mask < 4) ? kGreen : ((mask < 8) ? kBlue : kRed)) : kBlack;
                if (lcd_subpixel == 2) return (mask < 12) ? ((mask < 4) ? kRed : ((mask < 8) ? kGreen : kBlue)) : kBlack;
            }
            return kBlack;
        } else {
            // 8K other resolutions (800TVL, 1000TVL)
            if (shadow_y < 2) {
                uint pattern = (lcd_subpixel == 0) ? kGRRBBG : ((lcd_subpixel == 1) ? kBRRGGB : kGBBRRG);
                return (pattern >> (mask * 4)) & 0xF;
            } else {
                uint pattern = (lcd_subpixel == 0) ? kBBGGRR : ((lcd_subpixel == 1) ? kGGBBRR : kRRGGBB);
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
   const vec2 source_size           = global.SourceSize.xy;
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

   // DEBUG: disable mask for testing
   // colour_mask = kWhite;  

   const float scanline_size           = output_size.y / source_size.y;

   const vec3 horizontal_convergence   = vec3(HCRT_RED_HORIZONTAL_CONVERGENCE, HCRT_GREEN_HORIZONTAL_CONVERGENCE, HCRT_BLUE_HORIZONTAL_CONVERGENCE);
   const vec3 vertical_convergence     = vec3(HCRT_RED_VERTICAL_CONVERGENCE, HCRT_GREEN_VERTICAL_CONVERGENCE, HCRT_BLUE_VERTICAL_CONVERGENCE);
   const vec3 beam_sharpness           = vec3(HCRT_RED_BEAM_SHARPNESS, HCRT_GREEN_BEAM_SHARPNESS, HCRT_BLUE_BEAM_SHARPNESS);
   const vec3 beam_attack              = vec3(HCRT_RED_BEAM_ATTACK, HCRT_GREEN_BEAM_ATTACK, HCRT_BLUE_BEAM_ATTACK);
   const vec3 scanline_min             = vec3(HCRT_RED_SCANLINE_MIN, HCRT_GREEN_SCANLINE_MIN, HCRT_BLUE_SCANLINE_MIN);
   const vec3 scanline_max             = vec3(HCRT_RED_SCANLINE_MAX, HCRT_GREEN_SCANLINE_MAX, HCRT_BLUE_SCANLINE_MAX);
   const vec3 scanline_attack          = vec3(HCRT_RED_SCANLINE_ATTACK, HCRT_GREEN_SCANLINE_ATTACK, HCRT_BLUE_SCANLINE_ATTACK);

   /* Scanline generation in Rec.709 space.
    * Working in Rec.709 preserves chromaticity: a pure Rec.709 primary
    * (e.g. green = 0,1,0) only has one non-zero channel, so per-channel
    * beam width differences cannot cause chromaticity shift.
    * Conversion to Rec.2020 and HDR brightness boost happen afterward. */
   vec3 scanline_colour = GenerateScanline(tex_coord,
                                           source_size.xy,
                                           scanline_size,
                                           horizontal_convergence,
                                           vertical_convergence,
                                           beam_sharpness,
                                           beam_attack,
                                           scanline_min,
                                           scanline_max,
                                           scanline_attack);

   /* SourceSDR is already linear Rec.709 (linearised by ColourGrade in pass 0),
    * so the scanline result (luminance * sdr_channel) is already linear. */
   vec3 linear_colour = max(scanline_colour, 0.0f);

   /* Build mask vector from colour_mask bitfield.
    * Uses comparisons instead of dynamic vec3[idx] writes to avoid
    * SPIRV-Cross generating HLSL array l-values that fxc rejects. */
   vec3 mask = vec3(0.0f);
   const uint channel_count = colour_mask & 3u;
   if (channel_count > 0u) { uint idx = (colour_mask >> kFirstChannelShift)  & 3u; mask += vec3(float(idx == 0u), float(idx == 1u), float(idx == 2u)); }
   if (channel_count > 1u) { uint idx = (colour_mask >> kSecondChannelShift) & 3u; mask += vec3(float(idx == 0u), float(idx == 1u), float(idx == 2u)); }
   if (channel_count > 2u) { uint idx = (colour_mask >> kThirdChannelShift)  & 3u; mask += vec3(float(idx == 0u), float(idx == 1u), float(idx == 2u)); }

   if (HCRT_HDR > 0u)
   {
      /* HDR path: convert to Rec.2020, then apply mask in the OUTPUT space.
       * HDR10 output is BT.2020 → mask in Rec.2020.
       * scRGB output is Rec.709 → mask in Rec.709 (after 2020→709 conversion). */
      linear_colour = To2020(linear_colour);

      if (HCRT_HDR == 1u)
      {
         /* HDR10: InverseTonemap, mask in Rec.2020, PQ encode */
         linear_colour = InverseTonemap(linear_colour, HCRT_MAX_NITS, HCRT_PAPER_WHITE_NITS);
         linear_colour *= mask;

         vec3 pq_input = linear_colour * (HCRT_PAPER_WHITE_NITS / kMaxNitsFor2084);
         FragColor = vec4(LinearToST2084(pq_input), 1.0f);
      }
      else /* HCRT_HDR == 2u, scRGB */
      {
         /* scRGB: convert Rec.2020 → Rec.709 BEFORE mask, then mask in Rec.709.
          * Each mask channel gates one LCD subpixel which is a Rec.709 primary.
          * Colour boost is baked in via the Colour Space setting in To2020():
          *   r709/sRGB (0/1):   proper 709→2020→709 round-trip — no boost
          *   Adobe (2):         moderate boost
          *   DCI-P3 (3):        wide boost
          *   r2020 (4):         passthrough — maximum boost */
         linear_colour = linear_colour * k2020_to_sRGB;
         linear_colour *= mask;

         FragColor = vec4(linear_colour * (HCRT_MAX_NITS / 80.0f), 1.0f);
      }
   }
   else
   {
      /* SDR path: apply mask in Rec.709 space (no Rec.2020 conversion needed),
       * then gamma-encode for the selected output colour space. */
      linear_colour *= mask;

      uint output_space = uint(HCRT_OUTPUT_COLOUR_SPACE);

      if (output_space == 0u) // r709
      {
         FragColor = vec4(LinearTo709(linear_colour), 1.0f);
      }
      else if (output_space == 1u) // sRGB
      {
         FragColor = vec4(LinearTosRGB(linear_colour), 1.0f);
      }
      else if (output_space == 2u) // Adobe
      {
         FragColor = vec4(LinearToAdobe(linear_colour), 1.0f);
      }
      else if (output_space == 3u) // DCI-P3
      {
         FragColor = vec4(LinearToDCIP3(linear_colour), 1.0f);
      }
      else // r2020 (4)
      {
         FragColor = vec4(LinearTo709(linear_colour), 1.0f);
      }
   }
}
