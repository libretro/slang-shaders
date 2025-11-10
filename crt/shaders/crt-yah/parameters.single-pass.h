// Global parameters
#pragma parameter GLOBAL_MASTER "·  Global > ¹Master  (0-None .. 1-Full / 2-More)" 1.0 0.0 2.0 0.05

// Screen parameters
#pragma parameter SCREEN_ORIENTATION "·  Screen > Orientation  (0-Auto, 1-Horizontal, 2-Vertical)" 0.0 0.0 2.0 1.0
#pragma parameter SCREEN_SCALE "   Screen > Scale  (-Down / 0-Auto / +Up)" 0.0 -2.0 2.0 0.05

// Color parameters
#pragma parameter COLOR_TEMPERATUE "   Color > Temperature¹  (-Colder .. +Warmer)" 0.0 -1.0 1.0 0.1
#pragma parameter COLOR_SATURATION "   Color > Saturation¹  (0-Low .. 2-High)" 1.0 0.0 2.0 0.05
#pragma parameter COLOR_CONTRAST "   Color > Contrast¹  (-Lower .. +Higher)" 0.5 -1.0 1.0 0.05
#pragma parameter COLOR_BRIGHTNESS "   Color > Brightnes¹  (-Darken .. +Lighten)" 0.25 -1.0 2.0 0.05
#pragma parameter COLOR_OVERFLOW "   Color > Brightnes Overflow¹  (0-None .. 1-Full / 2-More)" 1.0 0.0 2.0 0.25
#pragma parameter COLOR_COMPENSATION "   Color > ²Brightnes Compensation  (0-Off, 1-On)" 1.0 0.0 1.0 1.0
#pragma parameter COLOR_BLACK_LIGHT "   Color > ³Black Lightening (0-None .. 1-Full / 2-More)" 1.0 0.0 2.0 0.1

// Scanline/beam parameters
#pragma parameter SCANLINES_STRENGTH "·  Scanlines > Strength¹²  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter BEAM_WIDTH_MIN "   Scanlines > Beam Min. Width  (less-Shrink .. 1-Full)" 0.25 0.0 1.0 0.05
#pragma parameter BEAM_WIDTH_MAX "   Scanlines > Beam Max. Width  (1-Full .. more-Grow)" 1.25 1.0 2.0 0.05
#pragma parameter BEAM_SHAPE "   Scanlines > Beam Shape²  (0-Sharp .. 1-Smooth)" 1.0 0.0 1.0 0.25
#pragma parameter BEAM_FILTER "   Scanlines > Beam Filter  (-Blocky .. +Blurry)" 0.0 -1.0 1.0 0.05
#pragma parameter ANTI_RINGING "   Scanlines > Anti-Ringing  (0-None .. 1-Full)" 1.0 0.0 1.0 0.1
#pragma parameter SCANLINES_COLOR_BURN "   Scanlines > Color Burn¹  (0-None .. 1-Full)" 1.0 0.0 1.0 0.25
#pragma parameter SCANLINES_OFFSET "   Scanlines > Offset  (-with .. +without Jitter)" -0.25 -2.0 2.0 0.05

// Mask parameters
#pragma parameter MASK_INTENSITY "·  Mask > Intensity¹²  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter MASK_BLEND "   Mask > Blend²  (0-Multiplicative .. 1-Additive)" 0.5 0.0 1.0 0.05
#pragma parameter MASK_TYPE "   Mask > Type²  (1-Aperture, 2-Slot, 3-Shadow)" 1.0 1.0 3.0 1.0
#pragma parameter MASK_SUBPIXEL "   Mask > Sub-Pixel²  (1-BY, 2-MG, 3-MGK, 4-RGB, 5-RGBK)" 4.0 1.0 5.0 1.0
#pragma parameter MASK_COLOR_BLEED "   Mask > Color Bleed¹  (0-None .. 1-Full)" 0.25 0.0 1.0 0.25
#pragma parameter MASK_SIZE "   Mask > Size  (-Down / 0-Auto / +Up)" 0.0 -2.0 2.0 1.0

// CRT parameters
#pragma parameter CRT_CURVATURE_AMOUNT "·  CRT > Curvature¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_VIGNETTE_AMOUNT "   CRT > Vignette¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_NOISE_AMOUNT "   CRT > Noise¹  (0-None .. 1-Full)" 0.25 0.0 1.0 0.05
#pragma parameter CRT_CORNER_RAIDUS "   CRT > Corner Radius¹  (0-None .. 25%)" 0.0 0.0 0.25 0.01
#pragma parameter CRT_CORNER_SMOOTHNESS "   CRT > Corner Smoothness  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05

#pragma parameter INFO1 "¹ Reduces marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO2 "² Compensates brightness changes of marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO3 "³ Increases the black level of marked effects" 0.0 0.0 0.0 0.0

float mix_master(float value, float off_value, float min_value, float max_value)
{
    return param.GLOBAL_MASTER > 1.0
        ? mix(
            value,
            clamp(
                (value - off_value * 0.5) * param.GLOBAL_MASTER,
                min(value, min_value),
                max(value, max_value)),
            param.GLOBAL_MASTER - 1.0)
        : mix(
            off_value,
            value,
            param.GLOBAL_MASTER);
}

#define PARAM_COLOR_FLOOR max(PARAM_SCANLINES_STRENGTH, PARAM_MASK_INTENSITY) * (1.0 / 256.0)
#define PARAM_COLOR_COMPENSATION param.COLOR_COMPENSATION
#define PARAM_COLOR_BRIGHTNESS mix_master(param.COLOR_BRIGHTNESS, 0.0, -1.0, 2.0)
#define PARAM_COLOR_OVERFLOW mix_master(param.COLOR_OVERFLOW, 0.0, 0.0, 2.0)
#define PARAM_COLOR_CONTRAST mix_master(param.COLOR_CONTRAST, 0.0, -1.0, 1.0)
#define PARAM_COLOR_SATURATION mix_master(param.COLOR_SATURATION, 1.0, 0.0, 2.0)
#define PARAM_COLOR_TEMPERATUE mix_master(param.COLOR_TEMPERATUE * -1.0, 0.0, -1.0, 1.0)
#define PARAM_COLOR_BLACK_LIGHT param.COLOR_BLACK_LIGHT
#define PARAM_MASK_INTENSITY mix_master(param.MASK_INTENSITY, 0.0, 0.0, 1.0)
#define PARAM_MASK_BLEND param.MASK_BLEND
#define PARAM_MASK_SIZE param.MASK_SIZE
#define PARAM_MASK_TYPE param.MASK_TYPE
#define PARAM_MASK_SUBPIXEL param.MASK_SUBPIXEL
#define PARAM_MASK_COLOR_BLEED mix_master(param.MASK_COLOR_BLEED, 0.0, 0.0, 1.0)
#define PARAM_SCANLINES_STRENGTH mix_master(param.SCANLINES_STRENGTH, 0.0, 0.0, 1.0)
#define PARAM_SCANLINES_OFFSET mix_master(param.SCANLINES_OFFSET, 0.0, -2.0, 2.0)
#define PARAM_SCANLINES_COLOR_BURN mix_master(param.SCANLINES_COLOR_BURN, 0.0, 0.0, 1.0)
#define PARAM_BEAM_WIDTH_MIN param.BEAM_WIDTH_MIN
#define PARAM_BEAM_WIDTH_MAX param.BEAM_WIDTH_MAX
#define PARAM_BEAM_SHAPE param.BEAM_SHAPE
#define PARAM_BEAM_FILTER mix_master(param.BEAM_FILTER, 0.0, -1.0, 1.0)
#define PARAM_ANTI_RINGING param.ANTI_RINGING
#define PARAM_CRT_CURVATURE_AMOUNT mix_master(param.CRT_CURVATURE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_VIGNETTE_AMOUNT mix_master(param.CRT_VIGNETTE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_NOISE_AMOUNT mix_master(param.CRT_NOISE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_CORNER_RAIDUS mix_master(param.CRT_CORNER_RAIDUS, 0.0, 0.0, 0.25)
#define PARAM_CRT_CORNER_SMOOTHNESS param.CRT_CORNER_SMOOTHNESS
#define PARAM_SCREEN_ORIENTATION param.SCREEN_ORIENTATION
#define PARAM_SCREEN_SCALE param.SCREEN_SCALE
#define PARAM_HALATION_INTENSITY 0.0 // unused for single-pass
