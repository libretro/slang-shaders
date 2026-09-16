// Global parameters
#pragma parameter GLOBAL_MASTER "· ¹Global > Master  (0-None .. 1-Full / 2-More)" 1.0 0.0 2.0 0.05

// Screen parameters
#pragma parameter SCREEN_ORIENTATION "·  Screen > Orientation  (0-Auto, 1-Horizontal, 2-Vertical)" 0.0 0.0 2.0 1.0
#pragma parameter SCREEN_RESOLUTION_SCALE "  ⁵Screen > Resolution  (1-Native, 2~240p/↑, 4~480p/↑)" 2.0 1.0 5.0 1.0
#pragma parameter SCREEN_FREQUENCY "  ⁴Screen > Frequency  (30Hz .. 60Hz)" 60.0 30.0 60.0 10.0
#pragma parameter SCREEN_INTERLACED "   Screen > Interlaced²⁴  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05

// Color parameters
#pragma parameter COLOR_PROFILE "·  Color > Profile¹  (-NTSC .. +Trinitron)" 0.0 -1.0 1.0 0.1
#pragma parameter COLOR_TEMPERATUE "   Color > Temperature¹  (-Colder .. +Warmer)" 0.0 -1.0 1.0 0.1
#pragma parameter COLOR_SATURATION "   Color > Saturation¹  (0-Low .. 2-High)" 1.1 0.0 2.0 0.05
#pragma parameter COLOR_CONTRAST "   Color > Contrast¹  (-Lower .. +Higher)" 0.1 -1.0 2.0 0.05
#pragma parameter COLOR_BRIGHTNESS "   Color > Brightness¹  (-Darken .. +Lighten)" 0.15 -1.0 4.0 0.05

// Brightness parameters
#pragma parameter COLOR_OVERFLOW "·  Brightness > Glow¹  (0-None .. 1-Full / 2-More)" 1.0 0.0 2.0 0.25
#pragma parameter CRT_NOISE_AMOUNT "   Brightness > Noise¹³  (0-None .. 1-Full)" 0.25 0.0 1.0 0.05
#pragma parameter COLOR_BRIGHTNESS_FLICKER "   Brightness > Flicker⁴  (0-None .. 1-Full)" 0.25 0.0 1.0 0.05
#pragma parameter COLOR_BLACK_LIGHT "  ³Brightness > Black Lighten  (0-None .. 1-Full / 2-More)" 0.5 0.0 2.0 0.1
#pragma parameter COLOR_COMPENSATION "  ²Brightness > Compensation  (0-Off, 1-On)" 1.0 0.0 1.0 1.0

// Scanlines parameters
#pragma parameter SCANLINES_STRENGTH "·  Scanlines > Strength¹²³  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter SCANLINES_COLOR_BURN "   Scanlines > Burn¹  (0-None .. 1-Full)" 1.0 0.0 1.0 0.25
#pragma parameter SCANLINES_OFFSET "   Scanlines > Offset⁴  (-Static / 0-None / +Jitter)" 0.25 -1.0 1.0 0.05
#pragma parameter SCREEN_SCALE "   Scanlines > Scale⁵  (-Down / 0-Auto / +Up)" 0.0 -4.0 2.0 0.05

// Beam parameters
#pragma parameter BEAM_WIDTH_MIN "·  Beam > Min. Width  (less-Shrink .. 1-Full)" 0.25 -1.0 1.0 0.05
#pragma parameter BEAM_WIDTH_MAX "   Beam > Max. Width  (1-Full .. more-Grow)" 1.25 1.0 2.0 0.05
#pragma parameter BEAM_SHAPE "   Beam > Shape²  (0-Sharp .. 1-Smooth)" 0.75 0.0 1.0 0.25
#pragma parameter BEAM_FILTER "   Beam > Filter  (-Blocky .. +Blurry)" -0.25 -1.0 1.0 0.05
#pragma parameter ANTI_RINGING "   Beam > Anti-Ringing  (0-None .. 1-Full)" 1.0 0.0 1.0 0.1

// Mask parameters
#pragma parameter MASK_INTENSITY "·  Mask > Intensity¹²³  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter MASK_BLEND "   Mask > Blend²  (0-Multiplicative .. 1-Additive)" 0.25 0.0 1.0 0.05
#pragma parameter MASK_TYPE "   Mask > Type²  (1-Aperture, 2-Slot, 3-Shadow)" 1.0 1.0 3.0 1.0
#pragma parameter MASK_SCALE "   Mask > Scale⁵  (-1 Down / 0-Auto / +½ Up)" 0.0 -2.0 4.0 0.5

// Sub-pixel parameters
#pragma parameter MASK_SUBPIXEL "·  Sub-Pixel > Pattern²  (1-Mono, 2-MG/x, 4-RGB/x)" 4.0 1.0 5.0 1.0
#pragma parameter MASK_SUBPIXEL_ORDER "   Sub-Pixel > Colors  (1-RGB/←, 3-RBG/←, 5-BRG/←)" 1.0 1.0 6.0 1.0
#pragma parameter MASK_COLOR_BLEED "   Sub-Pixel > Bleed¹²  (0-None .. 1-Full)" 0.5 0.0 1.0 0.25
#pragma parameter MASK_SUBPIXEL_SHAPE "   Sub-Pixel > Shape²  (0-Sharp .. 1-Smooth)  [4K]" 1.0 0.0 1.0 0.25

// Deconverge parameters
#pragma parameter DECONVERGE_LINEAR "·  Deconverge > Linear Amount¹  (0-None .. -/+ 1-Full)" 0.25 -2.0 2.0 0.05
#pragma parameter DECONVERGE_RADIAL "   Deconverge > Radial Amount¹  (0-None .. -/+ 1-Full)" 0.0 -2.0 2.0 0.05

// Phosphor parameters
#pragma parameter PHOSPHOR_AMOUNT "·  Phosphor > Amount¹  (0-None .. 1-Full)" 0.25 0.0 1.0 0.05
#pragma parameter PHOSPHOR_DECAY "   Phosphor > Decay  (0-Slow .. 1-Fast)" 0.5 0.0 1.0 0.05

// Halation parameters
#pragma parameter HALATION_INTENSITY "·  Halation > Intensity¹  (0-None .. 1-Full / 2-More)" 0.25 0.0 2.0 0.05
#pragma parameter HALATION_DIFFUSION "   Halation > Diffusion  (0-Low .. 1-Medium .. 2-High)" 0.5 0.0 2.0 0.05
#pragma parameter HALATION_WEIGHT "   Halation > Weight  (0-None .. 1-Luma)" 0.75 0.0 1.0 0.05
#pragma parameter HALATION_INFLUENCE "   Halation > Influence  (-Mask / 0-Both / +Scanlines)" 0.5 -1.0 1.0 0.05

// NTSC parameters
#pragma parameter NTSC_PROFILE "·  NTSC > Profile  (0-Off, 1-Separate Y/C, 2-Composite, 3-RF)" 0.0 0.0 3.0 0.1
#pragma parameter NTSC_PHASE "   NTSC > Chroma Phase  (0-Auto, 1-Two, 2-Three)" 1.0 0.0 2.0 1.0
#pragma parameter NTSC_SAMPLES "   NTSC > Chroma Samples  (¼-Min .. 1-Max)" 1.0 0.25 1.0 0.25
#pragma parameter NTSC_SHIFT "   NTSC > Chroma Shift  (-left .. +right)" 0.0 -1.0 1.0 0.1
#pragma parameter NTSC_JITTER "   NTSC > Offset⁴  (-Merge / 0-Static / +Jitter)" 1.0 -1.0 1.0 0.1
#pragma parameter NTSC_SCALE "   NTSC > Scale⁵  (-Down / 0-Auto / +Up)" 0.0 -0.5 0.5 0.05

// CRT parameters
#pragma parameter CRT_CURVATURE_AMOUNT "·  CRT > Curvature¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_VIGNETTE_AMOUNT "   CRT > Vignette¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_CORNER_RAIDUS "   CRT > Corner Roundness¹  (0-None .. 25%)" 0.0 0.0 0.25 0.01
#pragma parameter CRT_CORNER_SMOOTHNESS "   CRT > Edge Smoothness  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05

// Sharpness parameters
#pragma parameter SHARP_AMOUNT "·  Sharpen > Amount¹  (0-None .. 1-Full)" 0.0 0.0 2.0 0.25

#pragma parameter INFO1 " ¹ Reduces marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO2 " ² Compensates brightness changes of marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO3 " ³ Increases black level of marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO4 " ⁴ Affects frequency of marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO5 " ⁵ Affects scaling of marked effects" 0.0 0.0 0.0 0.0

#include "parameters.shared.h"
