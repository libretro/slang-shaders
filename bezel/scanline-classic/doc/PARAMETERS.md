# Parameters Cheatsheet

Copyright (c)  2025  W. M. Martinez.

Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.  This file is offered as-is,
without any warranty.

A quick reference to common parameters across Scanline Classic presets and shaders. Values shown are typical ranges

## User Settings

Represents controls accessible to an end user

### Common Controls

  * USER_PICTURE - Picture (%): Display 'Picture' or 'Contrast' control

  * USER_BRIGHTNESS - Brightness (%): Display 'Brightness' or 'Black level' control

  * USER_SHARPNESS - Sharpness (%): Controls the mixing amount for a twin-peak sharpening circuit

### Video Controls

  * USER_COLOR - Color (%): Controls saturation, can be calibrated with blue toggle

  * USER_TINT - Tint (°): Controls tint, can be calibrated with blue toggle; should be set to 0 for PAL

### Professional Controls
  * USER_GAMMA - Gamma (0.1): Adjusts the relative gamma by 0.1 increments

  * USER_H_SIZE - Horizontal size (%): Adjusts electronic display width

  * USER_V_SIZE - Vertical size (%): Adjust electronic display height

  * USER_H_POS - Horizontal position (%): Adjusts horizontal center

  * USER_V_POS - Vertical position (%): Adjusts vertical center

  * USER_BLUE_ONLY - Blue toggle (off, on): Sets the display to output 
  only the blue channel for color calibration

  * USER_UNDERSCAN_TOGGLE - Underscan toggle (off, on): Shrinks the picture, allowing the user to see the overscan region

## Output Settings

Controls the presentation of the simulated display on the output display

### Curvature

  * ZOOM - Viewport zoom (%): Zooms or shrinks the curved display

  * SCREEN_FOCUS - Focus (%): Controls the sharpness of the curvature filter; 50% is recommended

### Tone Mapping

  * TONEMAP_TYPE - Tone map output (off, Reinhard, Neutral, ACES): Selects a tonemapping technique; neutral is recommended

### Color Correction

  * CHROMATIC_ADAPTATION - Chromatic adaptation (off, Linear Bradford, Zhang-Li, Bradford): Selects the technique for translating the source whitepoint to the display whitepoint; either Linear Bradford or Zhang-Li is recommmended

  * GAMUT_COMPRESSION - Gamut mapping (off, basic, advanced clip, advanced compress): SDR only; selects the technique for translating out of gamut colors to the display gamut; advanced compress is recommended; choose off or basic for speeed

### Bezel

  * VIEWPORT_H_POS - Viewport horizontal position: Adjusts horizontal center of the viewport relative to the final display

  * VIWEPORT_V_POS - Viewport vertical position: Adjusts vertical center of the viewport relative to the final display

  * BEZEL_GAIN - Bezel gain (dB): Adjusts brightness of the bezel

  * BEZEL_BIAS - Bezel bias (IRE): Adjusts black level of the bezel

### Glow

  * GLOW_WEIGHT - Glow weight: Adjusts the mixing amount of glow upon the bezel

  * GLOW_TEMPERATURE - Glow color temperature: Adjusts bias towards or away from blue (generally, white light appears bluer as it diffuses)

  * GLOW_RADIUS - Glow radius: Affects radius of sample steps for the glow

  * GLOW_DIFFUSION - Glow diffusion: Adjusts how diffuse the glow sampling will be; increasing impacts performance

  * GLOW_COMPRESSION - Glow compression: Lowering this value reduces the saturation of the glow, simulating how light becomes white as it mixes

  * GLOW_FALLOFF - Glow radial falloff: Increasing this value causes the glow to darken more rapidly as it spreads away from the viewport

  * GLOW_VERTICAL_BIAS - Glow vertical bias: Makes the glow from samples arranged above and below the viewport stronger than the horizontal samples

## Sevice Settings

Represents controls available either through the service menu, from the back of the unit, or otherwise practically possible for a technician to adjust.

### Geometry

  * UNDERSCAN - Underscan (%): The amount of extra space to display when the underscan mode is enabled

  * BEAM_FOCUS - Beam focus (%): Adjusts sharpness of the beam spot

  * S_CORRECTION_H - Horizontal S-correction (%): Electronic polynomial geometry correction

  * S_CORRECTION_V - Vertical S-correction (%): Electronic polynomial geometry correction

  * TRAPEZOIDAL_CORRECTION - Trapezoidal correction (%): Can be used to correct for pincushion, relative to electronic picture

  * CORNER_CORRECTION - Corner correction (%): Tucks in the coners without affecting other parts of the screen

  * MAGNETIC_CORRECTION - Magnetic correction (%): Used to correct for pincushion, relative to the physical screen

### Scan Raster

  * DOUBLE_REFRESH - Double refresh rate (eliminates flicker): Some PAL displays worked at 100 Hz instead of 50 Hz.  This simulates that effect by eliminating flicker and adjusting the brightness to match with progressive scan mode.

  * SCANLINE_BLANK_WEIGHT - Blank scanline weight (%): Controls how much blank scanlines are darkened.  Simulates how different beam spot sizes and TVL can affect blank scanline visibility.

### S-Video Input

  * DECODER_SETUP - Setup (off, on): When enabled, the decoder will pull down the luminance level by 7.5 IRE and then normalize gain after processing

  * BW_MODE - Monitor mode (off, BW, Y, C, Y+C): Used for calibration; the technician connects the S-Video cable to a break out and remixes: BW displays a composite signal, Y displays the luminance only, C displays the chroma, Y+C displays both as separate channels

  * DISPLAY_BANDWIDTH_Y - Display bandwidth Y (MHz): Frequency response of the display

  * DISPLAY_BANDWIDTH_C - Display bandwidth C (MHz): Frequency response of the display

  * DISPLAY_CUTOFF_ATTEN_Y - Display cutoff attenuation Y (dB): Frequency response of the display

  * DISPLAY_CUTOFF_ATTEN_C - Display cutoff attenuation C (dB): Frequency response of the display

### Composite Input

  * DECODER_SETUP - Setup (off, on): See S-Video Input

  * DECODER_TYPE - Decoder type (YIQ, YPbPr, PAL): Selects the color conevrsion matrix for the input signal; when PAL is selected, the PAL line decoder is used

  * BW_MODE - Monitor mode (off, BW, Y, C, Y+C): Practically the same as the S-Video setting, but represents feeding off the encoder hardware directly

  * COLOR_FILTER_MODE - Filter mode (notch, comb filter, adaptive comb): Selects the composite separation filter technique; notch is recommended for 2D content, adaptive for 3D

  * NOTCH_WIDTH - Luma notch filter width (MHz): Increasing this value reduces color bleeding at the expense of sharpness

  * NOTCH_ATTEN_DB - Luma notch filter attenuation (dB): Increasing this value reduces color bleeding at the expense of sharpness

  * BANDPASS_WIDTH - Chroma bandpass width (MHz): Increasing this value improves color resolution at the expense of introducing artifacts

  * BANDPASS_ATTEN_DB - Chroma bandpass attenuation (dB): Decreasing this value improves color resolution at the expense of introducing artifacts

  * COMB_FILTER_LUMA_ADAPT - Comb filter luma correlation factor: Affects the threshold for determining whether to engage the comb filter on luma channel when the adaptive comb filter is used; higher values require a stronger correlation between lines

  * COMB_FILTER_CHROMA_ADAPT - Comb filter chroma correlation factor: Like the luma correlation factor but for chroma channel

  * COMB_FILTER_2D - Comb filter type (1D, 2D): When 2D is used, the comb filter will analyze the output result with the input for luma restoration; recommended to leave this on 2D

  * DISPLAY_BANDWIDTH_Y - Display bandwidth Y (MHz): See S-Video Input

  * DISPLAY_BANDWIDTH_C - Display bandwidth C (MHz): See S-Video Input

  * DISPLAY_CUTOFF_ATTEN_Y - Display cutoff attenuation Y (dB): See S-Video Input

  * DISPLAY_CUTOFF_ATTEN_C - Display cutoff attenuation C (dB): See S-Video Input

### RGB

These controls affect the translation of color to the electron guns.

  * DISPLAY_BIAS_R/G/B - Bias R/G/B (IRE): Adjusts gun level

  * DISPLAY_GAIN_R/G/B - Drive R/G/B (dB): Adjusts gun gain

  * DISPLAY_BANDWIDTH/CUTOFF_ATTEN_R/G/B - Bandwidth / Cutoff attenuation R/G/B (MHz/dB): Adjusts frequency response of R/G/B channels

## Factory Settings

These settings represent design parameters that are fixed to the display and cannot be changed after manufacturing.

### Geometry

  * ASPECT - Display aspect ratio (4:3, 16:9, 5:4, 16:10): Selects the aspect ratio of the simulated display.  Content is adjusted to fit within the frame without distortion; this setting does not affect the content presentation aspect ratio

  * SCREEN_ANGLE_H - Screen angle H (°): The horizontal screen angle of curvature, typically a low angle of no more than 45°

  * SCREEN_ANGLE_V - Screen angel V (°): The vertical screen angle of curvature, use 0 for Trinitron displays

### Shadow Mask

  * TVL: Horizontal phosphor triad count

  * MASK_TYPE - Mask type (aperture grille, slot mask, shadow mask): Selects the mask layout, aperture grille is bright, slot mask has medium brightness, shadow mask is the darkest

  * MASK_INTENSITY - Mask intensity (%): Adjusts the strength of the mask effect; recommended to leave at 100 unless brightness is limited

  * MASK_DIFFUSION - Mask diffusion (standard deviations): Adjusts how phosphor dots are blended; it's preferable to use this to recover brightness.  Higher brightness displays can use a lower setting

### Colorimetry

  * COLORIMETRY_PRESET - Colorimetry preset (off, SMPTE, Japan, EBU, Rec. 709): Presets colorimetry to the given standard

  * R/G/B_X/Y - Phosphor R/G/B x/y: Selects the chromaticity coordinate for a primary when a preset is not used

  * W_X/Y - White point x/y: Selects the white point chromaticity coordinate

### Phosphors

  * PHOSPHOR_MANTISSA/EXPONENT_R/G/B - Phosphor decay mantissa/exponent R/G/B (s/base-10): Selects the phosphor decay time where decay time is mantissa * 10 ^ exponent in seconds

  * PHOSPHOR_HOLD_R/G/B - Phosphos tail hold R/G/B (order): Adjusts the tail strength of the phosphor decay.  Higher values results in a longer overall decay

### Limiter

  * NTSC_CONVERSION - NTSC conversion matrix (off, on): Enables a conversion matrix to approximate 1953 NTSC colors with limited phosphors; approximates non-standard color decoding on consumer-grade televisions

  * NTSC_CONVERSION_WIGHT - NTSC conversion weight: The level of approximation the display should attempt to correct for when using the NTSC conversion matrix

  * LIMITER_TYPE - Limiter type (soft, hard): Chooses a soft or hard knee for signals that go beyond the compression point (after input gains and biases, before user controls)

  * LIMITER_COMPRESSION_POINT - Compression point (IRE): The IRE level at which the compression knee will begin to be applied.  When the hard knee is enabled, this will be the maximum allowed output level.

  * LIMITER_MAX_OUTPUT - Maximum output (IRE): The absolute IRE level that is allowed when the soft knee is used.  Levels higher will be clipped.

### RF Input

  * IQ_DEMOD_Q_WEIGHT - Vestigial weight: Has a minor effect on restoring luminance after RF demodulation

## System Settings

These settings apply to the system, i.e. everything that happens before the signal gets to the simulated display.

### RF Modulator

  * USB_BANDWIDTH - Video channel bandwidth (MHz): The upper sideband bandwidth of the RF signal

  * LSB_BANDWIDTH - Vestigial bandwidth (MHz): The lower sideband bandwidth of the RF signal

  * USB_ROLL_OFF - Video channel roll-off (MHz): How much transition is allowed between the passband and stop band for the upper sideband RF signal

  * LSB_ROLL_OFF - Vestigial roll-off (MHz): How much transition is allowed between the passband and stop band for the lower sideband RF signal; usually 0.75 MHz

  * NOISE_MODE - Noise mode (fast, advanced): Fast is AWGN only, advanced has more realistic effects at the expense of performance

  * NOISE_AWGN_DB - AWGN level (dB): Determines the overall noise level of the RF signal

  * NOISE_PHASE_JITTER_DEG - Phase jitter (° RMS): The amount of phase jitter introduced to the RF signal

  * NOISE_GHOST1_DB - Ghost1 level (dB): Controls visibility of multipath ghost; for direct connections, a ghost is unlikely

  * NOISE_GHOST1_PIX - Ghost1 delay (px): Controls the offset of the multipath ghost

  * NOISE_IMPULSE_RATE - Impulse rate (ppm): The frequency of shot noise

  * NOISE_IMPULSE_DB - Impulse level (dB): The level for each shot noise impule

### Timing

  * SC_FREQ_MODE - Subcarrier frequency mode (auto, NTSC, PAL, PAL-M, custom): Auto mode attempts to determine from core refresh rate, NTSC, PAL, and PAL-M are fixed to standards, and custom is determined by SC_FREQ

  * SC_FREQ - Custom subcarrier frequency (MHz): See SC_FREQ_MODE

  * PIXEL_CLOCK_MODE - Pixel clock mode (fixed, multiple of subcarrier): Selects whether to treat PIXEL_CLOCK as an absolute value or as a multiple of the subcarrier frequency

  * PIXEL_CLOCK - Pixel clock frequency (MHz) / multiplier - Determines the pixel clock according to PIXEL_CLOCK_MODE, affects how horizontal frequency and line count are determined

  * H_FREQ_MODE - Horizontal frequency mode (standard, pixel clock divisor, custom): Selects how to determine horizontal frequency.  Standard chooses a horizontal frequency according to detected video standard, regardless of pixel clock, pixel clock divisor divides the pixel clock by H_FREQ, custom treats H_FREQ as an absolute value

  * H_FREQ - Custom horizontal frequency (kHz) / divisor: Determines the horizontal frequency according to H_FREQ_MODE, affects how vertical lines and vertical frequency are determined

  * V_FREQ_MODE - Vertical sync mode (auto, NTSC, PAL, horizontal frequency divisor, custom): Determines how the vertical sync rate is determined.  Auto uses an algorithm based on the reported core refresh to recover exact precision. NTSC and PAL select 59.94 and 50 respectively, horizontal frequency divisor takes the horizontal frequency and divides by V_FREQ, custom is an absolute value

  * V_FREQ - Custom vertical sync rate (Hz) / divisor": Determines the vertical frequency according to V_FREQ_MODE

  * H_BLANK_FUZZ - Horizontal blanknig fuzz factor (%): Sets a factor used to recover the total horizontal pixel timing using fuzzy math.  It does not need to be precise.

  * FIELD_ORDER - Field order (even first, odd first): Sets which field is considered first

  * SHORTEN_ODD_FIELD_TIME - NES/SNES field time adjust (off, on): adjusts signal timing according to interlace mode and detected video standard, specifically for the NES and SNES; should be off on any other systems

### RGB

These settings are identical to Display RGB but apply at the system level, earlier in the shader pipeline

### Component Video

  * YC_MODEL - System color space (YIQ, YPbPr, YUV, YDbDr, YCbCr): Selects the RGB to Y/C conversion matrix

  * SYS_BIAS/GAIN_Y/U/V - Offset/Gain Y/U/V (IRE/dB): Sets the offset and gain for the given channel

  * SYS_BANDWIDTH/CUTOFF_ATTEN_Y/U/V - Bandwidth/Cutoff attenuation Y/U/V (MHz/dB): Controls frequency response of the Y/C components

### Encoder

  * ENCODER_SETUP - Setup (off, on): Pushes the luminance level by 7.5 IRE and normalizes gain before encoding

  * PAL - Phase alternating line (off, on): Enables PAL line encoding for phase recovery

### Y/C Processing

  * LUMA_LOWPASS_CUTOFF/ATTEN - Y lowpass cutoff/attenuation (MHz/dB): Controls luma frequency response

  * LUMA_NOCH_ENABLE - Y notch filter (off, on): Enables a sysem-level notch filter to reduce color bleeding at the expense of sharpness

  * LUMA_NOCH_WIDTH/ATTEN_DB - Y notch filter width/attenuation (MHz/dB): Controls notch frequency response

  * CHROMA_BANDPASS_WIDTH - Chroma bandpass width / edge attenuation (MHz/dB): Controls chroma separation frequency response; unlike the notch, this is strictly necessary for correct encoding