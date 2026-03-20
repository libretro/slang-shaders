# Parameters Cheatsheet

Copyright (c)  2025-2026  W. M. Martinez.

Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.  This file is offered as-is,
without any warranty.

A quick reference to common parameters across Scanline Classic presets and shaders. Values shown are typical ranges.

## User Settings

Represents controls accessible to an end user.

### Common Controls

  * USER_PICTURE - Picture (%): Display 'Picture' or 'Contrast' control

  * USER_BRIGHTNESS - Brightness (%): Display 'Brightness' or 'Black level' control

  * USER_SHARPNESS - Sharpness (%): Controls the mixing amount for a twin-peak sharpening circuit

### Video Controls

  * USER_COLOR - Color (%): Controls saturation, can be calibrated with blue toggle

  * USER_TINT - Tint (°): Controls tint, can be calibrated with blue toggle; should be set to 0 for PAL

  * USER_MONOCHROME - Monochrome toggle (off, standard, sepia): Disables color for black-and-white presentation; sepia biases the monochrome image toward a warm brown tone

### Professional Controls

  * USER_GAMMA - Gamma (0.1): Adjusts the relative gamma by 0.1 increments

  * USER_H_SIZE - Horizontal size (%): Adjusts electronic display width

  * USER_V_SIZE - Vertical size (%): Adjusts electronic display height

  * USER_H_POS - Horizontal position (%): Adjusts horizontal center

  * USER_V_POS - Vertical position (%): Adjusts vertical center

  * USER_BLUE_ONLY - Blue toggle (off, on): Sets the display to output only the blue channel for color calibration

  * USER_UNDERSCAN_TOGGLE - Underscan toggle (off, on): Shrinks the picture, allowing the user to see the overscan region

## Output Settings

Controls the presentation of the simulated display on the output display.

### Curvature

  * ZOOM - Viewport zoom (%): Zooms or shrinks the curved display

  * SCREEN_FOCUS - Focus (%): Controls the sharpness of the curvature filter; 50% is recommended

### Tone Mapping

  * TONEMAP_TYPE - Tone map output (off, Reinhard, Neutral, Hable, ACES): Selects a tone mapping technique; Neutral is a good default, while Hable and ACES are stronger filmic options

### Color Correction

  * MAKEUP_GAIN - Makeup gain (off, on): Restores brightness after color correction stages; usually best left on unless comparing raw transform behavior

  * CHROMATIC_ADAPTATION - Chromatic adaptation (off, LBrad, Z-L, Brad): Selects the technique for translating the source white point to the display white point; Linear Bradford or Zhang-Li is generally recommended

  * ADAPTATION_LEVEL - Adaptation Level (Z-L only): Controls how strongly the Zhang-Li adaptation model is applied; only used when Z-L is selected above

  * GAMUT_COMPRESSION - Gamut mapping (off, basic, Luv, IPT): SDR only; selects the technique for translating out-of-gamut colors to the display gamut; Luv is a good quality default, while off/basic are faster; IPT is an alternative to Luv that better maintains blue hues at the cost of saturation

  * GAMUT_SELECT - Output gamut (BT.2020, DCI-P3): WCG only; selects the target gamut container for wide-color output presets

### Bezel

  * VIEWPORT_H_POS - Viewport horizontal position: Adjusts horizontal center of the viewport relative to the final display

  * VIEWPORT_V_POS - Viewport vertical position: Adjusts vertical center of the viewport relative to the final display

  * BEZEL_ZOOM - Bezel zoom: Scales the bezel artwork independently of the viewport; useful when matching a larger or smaller cabinet opening

  * BEZEL_GAIN - Bezel gain (dB): Adjusts brightness of the bezel

  * BEZEL_BIAS - Bezel bias (IRE): Adjusts black level of the bezel

### Glow

  * GLOW_WEIGHT - Glow weight: Adjusts the mixing amount of glow upon the bezel

  * USE_MIPMAPPING - Use mipmapping for glow (non-D3D only): Uses mipmap sampling for smoother glow accumulation on supported backends; usually best left on when available

  * GLOW_TEMPERATURE - Glow color temperature: Adjusts bias toward or away from blue; generally, white light appears bluer as it diffuses

  * GLOW_DIFFUSION - Glow diffusion (low, medium, high): Adjusts how diffuse the glow sampling will be; increasing it impacts performance

  * GLOW_RADIUS_PERCENT - Glow radius: Affects radius of sample steps for the glow

  * GLOW_COMPRESSION - Glow saturation: Lowering this value reduces the saturation of the glow, simulating how light becomes white as it mixes

  * GLOW_DITHER - Glow dither (dB): Adds dithering to large glow gradients to reduce banding; stronger dither can be helpful on low-bit-depth output paths

  * GLOW_FALLOFF - Glow falloff: Increasing this value causes the glow to darken more rapidly as it spreads away from the viewport

  * EDGE_GUARD_PERCENT - Glow edge margin: Reserves space near the viewport edge so the glow does not clip or sample too aggressively at the border

## Service Settings

Represents controls available either through the service menu, from the back of the unit, or otherwise practically possible for a technician to adjust.

### Geometry

  * UNDERSCAN - Underscan (%): The amount of extra space to display when the underscan mode is enabled

  * BEAM_FOCUS - Beam focus (%): Adjusts sharpness of the beam spot

  * S_CORRECTION_H - Horizontal S-correction (%): Electronic polynomial geometry correction

  * S_CORRECTION_V - Vertical S-correction (%): Electronic polynomial geometry correction

  * TRAPEZOIDAL_CORRECTION - Trapezoidal correction (%): Can be used to correct for pincushion, relative to the electronic picture

  * CORNER_CORRECTION - Corner correction (%): Tucks in the corners without affecting other parts of the screen

  * MAGNETIC_CORRECTION - Magnetic correction (%): Used to correct for pincushion, relative to the physical screen

### Scan Raster

  * DOUBLE_REFRESH - Double refresh rate (eliminates flicker): Some PAL displays worked at 100 Hz instead of 50 Hz. This simulates that effect by eliminating flicker; makes use of subframes when available

  * SCANLINE_BLANK_WEIGHT - Blank scanline weight (%): Controls how much blank scanlines are darkened. Simulates how different beam spot sizes and TVL can affect blank scanline visibility

### S-Video Input

  * DECODER_SETUP - Setup (off, on): When enabled, the decoder will pull down the luminance level by 7.5 IRE and then normalize gain after processing

  * DECODER_TYPE - Decoder type (NTSC, PAL): Selects the decoder standard for the incoming Y/C signal; use PAL only when the source actually uses PAL encoding

  * BW_MODE - Monitor mode (off, BW, Y, C, Y+C): Used for calibration; the technician connects the S-Video cable to a breakout and remixes: BW displays a composite-like sum, Y displays the luminance only, C displays the chroma, Y+C displays both as separate channels

  * DISPLAY_BANDWIDTH_Y - Display bandwidth Y (MHz): Frequency response of the luminance channel in the display decoder path

  * DISPLAY_BANDWIDTH_C - Display bandwidth C (MHz): Frequency response of the chroma channel in the display decoder path

  * DISPLAY_CUTOFF_ATTEN_Y - Display cutoff attenuation Y (dB): Cutoff slope strength for the luminance channel

  * DISPLAY_CUTOFF_ATTEN_C - Display cutoff attenuation C (dB): Cutoff slope strength for the chroma channel

### Composite Input

  * DECODER_SETUP - Setup (off, on): See S-Video Input

  * DECODER_TYPE - Decoder type (NTSC, PAL): Selects the composite decoder standard; PAL enables the PAL line decoder path

  * PAL_DECODER_MODE - PAL Decoder Mode (simple, delay-line, adaptive): Selects the PAL line decoding method; adaptive is usually the most robust, while simple can better resemble low-cost sets

  * BW_MODE - Monitor mode (off, BW, Y, C, Y+C): Practically the same as the S-Video setting, but represents feeding off the encoder hardware directly

  * COLOR_FILTER_MODE - Filter mode (notch, simple comb, adaptive comb): Selects the composite separation filter technique; notch is usually best for 2D content, adaptive comb is often better for 3D or detailed motion

  * NOTCH_WIDTH - Luma notch filter width (MHz): Increasing this value reduces color bleeding at the expense of sharpness

  * NOTCH_ATTEN_DB - Luma notch filter attenuation (dB): Increasing this value reduces color bleeding at the expense of sharpness

  * BANDPASS_WIDTH - Chroma bandpass width (MHz): Increasing this value improves color resolution at the expense of introducing artifacts

  * BANDPASS_ATTEN_DB - Chroma bandpass attenuation (dB): Decreasing this value improves color resolution at the expense of introducing artifacts

  * COMB_FILTER_LUMA_ADAPT - Comb filter luma correlation factor: Affects the threshold for determining whether to engage the comb filter on luma when the adaptive comb filter is used; higher values require a stronger correlation between lines

  * COMB_FILTER_2D - Comb filter type (1D, 2D): When 2D is used, the comb filter will analyze the output result against the input for luma restoration; recommended to leave this on 2D

  * DISPLAY_BANDWIDTH_Y - Display bandwidth Y (MHz): See S-Video Input

  * DISPLAY_BANDWIDTH_C - Display bandwidth C (MHz): See S-Video Input

  * DISPLAY_CUTOFF_ATTEN_Y - Display cutoff attenuation Y (dB): See S-Video Input

  * DISPLAY_CUTOFF_ATTEN_C - Display cutoff attenuation C (dB): See S-Video Input

### RGB

These controls affect the translation of color to the electron guns.

  * DISPLAY_BIAS_R, DISPLAY_BIAS_G, DISPLAY_BIAS_B - Bias R/G/B (IRE): Adjust gun black level for each channel

  * DISPLAY_GAIN_R, DISPLAY_GAIN_G, DISPLAY_GAIN_B - Drive R/G/B (dB): Adjust gun gain for each channel

  * DISPLAY_BANDLIMIT_R, DISPLAY_BANDLIMIT_G, DISPLAY_BANDLIMIT_B - Bandwidth R/G/B (MHz): Adjust high-frequency response of the R/G/B channels

  * DISPLAY_CUTOFF_ATTEN_R, DISPLAY_CUTOFF_ATTEN_G, DISPLAY_CUTOFF_ATTEN_B - Cutoff attenuation R/G/B (dB): Adjust filter roll-off strength for the R/G/B channels

## Factory Settings

These settings represent design parameters that are fixed to the display and cannot be changed after manufacturing.

### Geometry

  * ASPECT - Display aspect ratio (4:3, 16:9, 5:4, 16:10): Selects the aspect ratio of the simulated display. Content is adjusted to fit within the frame without distortion; this setting does not affect the content presentation aspect ratio

  * DEFLECTION_ANGLE - Deflection angle (°): Represents the CRT deflection geometry. Higher angles generally imply a shallower tube and stronger geometric demands on the raster

  * SCREEN_ANGLE_H - Screen angle H (°): The horizontal screen angle of curvature, typically a low angle of no more than 45°

  * SCREEN_ANGLE_V - Screen angle V (°): The vertical screen angle of curvature; use 0 for Trinitron displays

### Shadow Mask

  * TVL - Horizontal phosphor triad count: Effective horizontal phosphor density of the display

  * MASK_TYPE - Mask type (aperture, slot, shadow): Selects the mask layout; aperture is brightest, slot has medium brightness, shadow is darkest

  * MASK_INTENSITY - Mask intensity (%): Adjusts the strength of the mask effect; recommended to leave at 100 unless brightness is limited

  * MASK_DIFFUSION - Mask diffusion (standard deviations): Adjusts how phosphor dots are blended; it is often preferable to use this to reduce moire patterns due to insufficient resolution
### Colorimetry

  * COLORIMETRY_PRESET - Colorimetry preset (off, SMPTE, Japan, EBU, 709): Presets colorimetry to the given standard

  * R_X, R_Y - Phosphor red x/y: Selects the chromaticity coordinate for the red primary when a preset is not used

  * G_X, G_Y - Phosphor green x/y: Selects the chromaticity coordinate for the green primary when a preset is not used

  * B_X, B_Y - Phosphor blue x/y: Selects the chromaticity coordinate for the blue primary when a preset is not used

  * W_X, W_Y - White point x/y: Selects the white point chromaticity coordinate

### Phosphors

  * PHOSPHOR_MANTISSA_R/G/B - Phosphor decay mantissa R/G/B (s): Selects the phosphor decay mantissa where decay time is mantissa * 10 ^ exponent seconds

  * PHOSPHOR_EXPONENT_R/G/B - Phosphor decay exponent R/G/B (base-10): Selects the phosphor decay exponent where decay time is mantissa * 10 ^ exponent seconds

  * PHOSPHOR_HOLD_R/G/B - Phosphor tail hold R/G/B (order): Adjusts tail strength of the phosphor decay. Higher values result in a longer overall decay

### Limiter

  * NTSC_CONVERSION - NTSC conversion matrix (off, on): Enables a conversion matrix to approximate 1953 NTSC colors with limited phosphors; approximates non-standard color decoding on consumer-grade televisions

  * NTSC_CONVERSION_WEIGHT - NTSC conversion weight: The level of approximation the display should attempt to correct for when using the NTSC conversion matrix

  * LIMITER_TYPE - Limiter type (soft, hard): Chooses a soft or hard knee for signals that go beyond the compression point, after input gains and biases but before user controls

  * LIMITER_COMPRESSION_POINT - Compression point (IRE): The IRE level at which the compression knee will begin to be applied. When the hard knee is enabled, this becomes the maximum allowed output level

  * LIMITER_MAX_OUTPUT - Maximum output (IRE): The absolute IRE level that is allowed when the soft knee is used. Higher levels will be clipped

### RF Input

  * IQ_DEMOD_Q_WEIGHT - Vestigial weight: Has a minor effect on restoring luminance after RF demodulation

## System Settings

These settings apply to the system, i.e. everything that happens before the signal gets to the simulated display.

### RF Modulator

  * USB_BANDWIDTH - Video channel bandwidth (MHz): The upper sideband bandwidth of the RF signal

  * LSB_BANDWIDTH - Vestigial bandwidth (MHz): The lower sideband bandwidth of the RF signal

  * USB_ROLL_OFF - Video channel roll-off (MHz): How much transition is allowed between the passband and stop band for the upper sideband RF signal

  * LSB_ROLL_OFF - Vestigial roll-off (MHz): How much transition is allowed between the passband and stop band for the lower sideband RF signal; usually 0.75 MHz

  * NOISE_MODE - Noise mode (fast, advanced): Fast is AWGN only; advanced has more realistic effects at the expense of performance

  * NOISE_AWGN_DB - AWGN level (dB): Determines the overall noise level of the RF signal

  * NOISE_PHASE_JITTER_DEG - Phase jitter (° RMS): The amount of phase jitter introduced to the RF signal

  * NOISE_GHOST1_DB - Ghost1 level (dB): Controls visibility of multipath ghost; for direct connections, a ghost is unlikely

  * NOISE_GHOST1_PIX - Ghost1 delay (px): Controls the offset of the multipath ghost

  * NOISE_IMPULSE_RATE - Impulse rate (ppm): The frequency of shot noise

  * NOISE_IMPULSE_DB - Impulse level (dB): The level for each shot-noise impulse

### Timing

  * SC_FREQ_MODE - Subcarrier frequency mode (auto, NTSC, PAL, PAL-M, custom): Auto mode attempts to determine the standard from core refresh rate; NTSC, PAL, and PAL-M are fixed to standards, and custom is determined by SC_FREQ

  * SC_FREQ - Custom subcarrier frequency (MHz): See SC_FREQ_MODE

  * PIXEL_CLOCK_MODE - Pixel clock mode (fixed, multiple of subcarrier): Selects whether to treat PIXEL_CLOCK as an absolute value or as a multiple of the subcarrier frequency

  * PIXEL_CLOCK - Pixel clock frequency (MHz) / multiplier: Determines the pixel clock according to PIXEL_CLOCK_MODE; affects how horizontal frequency and line count are determined

  * H_FREQ_MODE - Horizontal frequency mode (standard, pixel clock divisor, custom): Selects how to determine horizontal frequency. Standard chooses a horizontal frequency according to the detected video standard regardless of pixel clock, pixel clock divisor divides the pixel clock by H_FREQ, and custom treats H_FREQ as an absolute value

  * H_FREQ - Custom horizontal frequency (kHz) / divisor: Determines the horizontal frequency according to H_FREQ_MODE; affects how vertical lines and vertical frequency are determined

  * V_FREQ_MODE - Vertical sync mode (auto, NTSC, PAL, horizontal frequency divisor, custom): Determines how the vertical sync rate is determined. Auto uses an algorithm based on the reported core refresh to recover exact precision. NTSC and PAL select 59.94 and 50 respectively, horizontal frequency divisor takes the horizontal frequency and divides by V_FREQ, and custom is an absolute value

  * V_FREQ - Custom vertical sync rate (Hz) / divisor: Determines the vertical frequency according to V_FREQ_MODE

  * H_BLANK_FUZZ - Horizontal blanking fuzz factor (%): Sets a factor used to recover the total horizontal pixel timing using fuzzy math. It does not need to be precise

  * FIELD_ORDER - Field order (even first, odd first): Sets which field is considered first

  * SHORTEN_ODD_FIELD_TIME - NES/SNES field time adjust (off, on): Adjusts signal timing according to interlace mode and detected video standard, specifically for the NES and SNES; should be off on any other systems

### RGB

These settings are identical in purpose to Display RGB, but apply at the system level earlier in the shader pipeline.

  * SYS_BIAS_R, SYS_BIAS_G, SYS_BIAS_B - Offset R/G/B (IRE): Sets black level for the system RGB channels before display simulation

  * SYS_GAIN_R, SYS_GAIN_G, SYS_GAIN_B - Gain R/G/B (dB): Sets gain for the system RGB channels before display simulation

  * SYS_BANDWIDTH_R, SYS_BANDWIDTH_G, SYS_BANDWIDTH_B - Bandwidth R/G/B (MHz): Controls frequency response of the system RGB channels

  * SYS_CUTOFF_ATTEN_R, SYS_CUTOFF_ATTEN_G, SYS_CUTOFF_ATTEN_B - Cutoff attenuation R/G/B (dB): Controls filter roll-off strength for the system RGB channels

### Component Video

  * YC_MODEL - System color space (YPbPr, YDbDr, YCbCr): Selects the RGB-to-component conversion matrix

  * SYS_BIAS_Y, SYS_BIAS_U, SYS_BIAS_V - Offset Y/U/V (IRE): Sets the offset for the given component channel

  * SYS_GAIN_Y, SYS_GAIN_U, SYS_GAIN_V - Gain Y/U/V (dB): Sets the gain for the given component channel

  * SYS_BANDWIDTH_Y, SYS_BANDWIDTH_U, SYS_BANDWIDTH_V - Bandwidth Y/U/V (MHz): Controls frequency response of the Y/C components

  * SYS_CUTOFF_ATTEN_Y, SYS_CUTOFF_ATTEN_U, SYS_CUTOFF_ATTEN_V - Cutoff attenuation Y/U/V (dB): Controls filter roll-off strength of the Y/C components

### Encoder

  * ENCODER_SETUP - Setup (off, on): Pushes the luminance level by 7.5 IRE and normalizes gain before encoding

  * PAL - Phase alternating line (off, on): Enables PAL line encoding for phase recovery

### Y/C Processing

  * YC_MODEL - System color space (YPbPr, YDbDr, YCbCr): Selects the RGB-to-Y/C conversion matrix used before encoding or modulation

  * SYS_BIAS_Y, SYS_BIAS_U, SYS_BIAS_V - Offset Y/U/V (IRE): Sets offset for the luminance and chroma channels in the Y/C path

  * SYS_GAIN_Y, SYS_GAIN_U, SYS_GAIN_V - Gain Y/U/V (dB): Sets gain for the luminance and chroma channels in the Y/C path

  * LUMA_LOWPASS_CUTOFF - Y lowpass cutoff (MHz): Controls luma lowpass frequency response

  * LUMA_LOWPASS_ATTEN - Y lowpass attenuation (dB): Controls the amount of attenuation at the lowpass cutoff

  * LUMA_NOTCH_ENABLE - Y notch filter (off, on): Enables a system-level notch filter to reduce color bleeding at the expense of sharpness

  * LUMA_NOTCH_WIDTH - Y notch filter width (MHz): Controls notch filter width

  * LUMA_NOTCH_ATTEN_DB - Y notch filter attenuation (dB): Controls notch filter attenuation

  * CHROMA_BANDPASS_WIDTH - Chroma bandpass width (MHz): Controls chroma separation frequency response; unlike the notch, this is strictly necessary for correct encoding

  * CHROMA_EDGE_ATTEN_DB - Chroma edge attenuation (dB): Controls how strongly the chroma bandpass tapers near its edge; increasing it can suppress artifacts at the expense of color detail

### Digital Video

  * WORKING_BITS - Working bit depth: Sets internal digital precision before later analog-style stages are applied; higher values reduce quantization error

  * YCBCR_MODEL - System color space (601, 709): Selects the digital YCbCr conversion matrix for the source path

  * DIGITAL_Y_FILTER_DECIMATION - Y bandwidth decimation: Reduces luminance bandwidth in the digital domain; lower effective bandwidth simulates softer filtering

  * DIGITAL_Cb_FILTER_DECIMATION - Cb bandwidth decimation: Reduces Cb chroma bandwidth in the digital domain

  * DIGITAL_Cr_FILTER_DECIMATION - Cr bandwidth decimation: Reduces Cr chroma bandwidth in the digital domain

  * DAC_BITS - Output bit depth: Sets the precision of the simulated digital-to-analog converter; lower values make quantization artifacts easier to see

  * DITHER - Dithering (off, on): Applies dithering before the DAC stage to reduce visible banding and quantization steps

  * VIDEO_MODE - Output mode (Composite, S-Video, Component): Selects which analog output path the digital encoder feeds

  * SYS_BIAS_Y, SYS_BIAS_U, SYS_BIAS_V - Offset Y/C/Pb/Pr (IRE): Sets output offsets for the simulated DAC path; exact channel meaning depends on VIDEO_MODE

  * SYS_GAIN_Y, SYS_GAIN_U, SYS_GAIN_V - Gain Y/C/Pb/Pr (dB): Sets output gain for the simulated DAC path; exact channel meaning depends on VIDEO_MODE

### Chroma Subsampling

  * CHROMA_SUBSAMPLE - Subsampling mode (auto, 4:4:4, 4:2:2, 4:2:0): Selects digital chroma subsampling format before later processing; lower chroma resolution can better match consumer digital video paths

### Digital Upsampler

  * UPSAMPLER_INPUT - Upsampler input type (RGB, YCbCr): Selects the signal domain fed into the digital upsampler

  * GAMMA_CORRECT_BLENDING - RGB: gamma correct blending (off, fast, accurate): Controls whether RGB upsampling blends in gamma-corrected space; accurate is best quality, fast is cheaper