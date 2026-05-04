// Global parameters
#pragma parameter GLOBAL_MASTER "· ¹Global > Master  (0-None .. 1-Full / 2-More)" 1.0 0.0 2.0 0.05

// Screen parameters
#pragma parameter SCREEN_ORIENTATION "·  Screen > Orientation  (0-Auto, 1-Horizontal, 2-Vertical)" 0.0 0.0 2.0 1.0
#pragma parameter SCREEN_RESOLUTION_SCALE "  ⁵Screen > Resolution  (1-Native, 2/3-Low/+, 4/5-High/+)" 2.0 1.0 5.0 1.0
#pragma parameter SCREEN_SCALE "   Screen > Scale⁵  (-Down / 0-Auto / +Up)" 0.0 -2.0 2.0 0.05
#pragma parameter SCREEN_FREQUENCY "  ⁴Screen > Frequency  (30Hz .. 60Hz)" 60.0 30.0 60.0 10.0
#pragma parameter SCREEN_INTERLACED "   Screen > Interlaced²⁴  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05

// Color parameters
#pragma parameter COLOR_PROFILE "·  Color > Profile¹  (-NTSC .. +Trinitron)" 0.0 -1.0 1.0 0.1
#pragma parameter COLOR_TEMPERATUE "   Color > Temperature¹  (-Colder .. +Warmer)" 0.0 -1.0 1.0 0.1
#pragma parameter COLOR_SATURATION "   Color > Saturation¹  (0-Low .. 2-High)" 1.1 0.0 2.0 0.05
#pragma parameter COLOR_CONTRAST "   Color > Contrast¹  (-Lower .. +Higher)" 0.1 -1.0 2.0 0.05
#pragma parameter COLOR_BRIGHTNESS "   Color > Brightness¹  (-Darken .. +Lighten)" 0.15 -1.0 4.0 0.05
#pragma parameter COLOR_OVERFLOW "   Color > Brightness Overflow¹  (0-None .. 1-Full / 2-More)" 1.0 0.0 2.0 0.25
#pragma parameter COLOR_COMPENSATION "  ²Color > Brightness Compensation  (0-Off, 1-On)" 1.0 0.0 1.0 1.0
#pragma parameter COLOR_BLACK_LIGHT "  ³Color > Black Lightening (0-None .. 1-Full / 2-More)" 0.5 0.0 2.0 0.1

// Scanline/beam parameters
#pragma parameter SCANLINES_STRENGTH "·  Scanlines > Strength¹²³  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter BEAM_WIDTH_MIN "   Scanlines > Beam Min. Width  (less-Shrink .. 1-Full)" 0.25 -1.0 1.0 0.05
#pragma parameter BEAM_WIDTH_MAX "   Scanlines > Beam Max. Width  (1-Full .. more-Grow)" 1.25 1.0 2.0 0.05
#pragma parameter BEAM_SHAPE "   Scanlines > Beam Shape²  (0-Sharp .. 1-Smooth)" 0.75 0.0 1.0 0.25
#pragma parameter BEAM_FILTER "   Scanlines > Beam Filter  (-Blocky .. +Blurry)" -0.25 -1.0 1.0 0.05
#pragma parameter ANTI_RINGING "   Scanlines > Anti-Ringing  (0-None .. 1-Full)" 1.0 0.0 1.0 0.1
#pragma parameter SCANLINES_COLOR_BURN "   Scanlines > Color Burn¹  (0-None .. 1-Full)" 1.0 0.0 1.0 0.25

// Mask parameters
#pragma parameter MASK_INTENSITY "·  Mask > Intensity¹²³  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter MASK_BLEND "   Mask > Blend²  (0-Multiplicative .. 1-Additive)" 0.25 0.0 1.0 0.05
#pragma parameter MASK_TYPE "   Mask > Type²  (1-Aperture, 2-Slot, 3-Shadow)" 1.0 1.0 3.0 1.0
#pragma parameter MASK_SUBPIXEL "   Mask > Sub-Pixel²  (1-BY, 2,3-MG/x, 4,5-RGB/x)" 4.0 1.0 5.0 1.0
#pragma parameter MASK_SUBPIXEL_SHAPE "   Mask > Sub-Pixel Shape²  (0-Sharp .. 1-Smooth)  [4K]" 1.0 0.0 1.0 0.25
#pragma parameter MASK_COLOR_BLEED "   Mask > Color Bleed¹²  (0-None .. 1-Full)" 0.25 0.0 1.0 0.25
#pragma parameter MASK_SCALE "   Mask > Scale⁵  (-1 Down / 0-Auto / +½ Up)" 0.0 -2.0 2.0 0.5

// CRT parameters
#pragma parameter CRT_CURVATURE_AMOUNT "·  CRT > Curvature¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_VIGNETTE_AMOUNT "   CRT > Vignette¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_NOISE_AMOUNT "   CRT > Noise¹³  (0-None .. 1-Full)" 0.25 0.0 1.0 0.05
#pragma parameter CRT_CORNER_RAIDUS "   CRT > Corner Radius¹  (0-None .. 25%)" 0.0 0.0 0.25 0.01
#pragma parameter CRT_CORNER_SMOOTHNESS "   CRT > Corner Smoothness  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05

#pragma parameter INFO1 " ¹ Reduces marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO2 " ² Compensates brightness changes of marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO3 " ³ Increases black level of marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO4 " ⁴ Affects frequency of marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO5 " ⁵ Affects scaling of marked effects" 0.0 0.0 0.0 0.0

#include "parameters.shared.h"
