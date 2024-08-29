
/*
Patchy NTSC
Copyright (C) 2024 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

#ifndef __patchy_ntsc_inc_params_inc__
#define __patchy_ntsc_inc_params_inc__

// NES simulation requires SIGNAL_RES to be exactly 8. Not 16. Not 4. Only 8.
// Some code involving NES has 8 hardcoded, and some code uses SIGNAL_RES instead.
#define SIGNAL_RES 8
#define pi 3.14159265358

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    
    float pn_test_pattern,
          pn_width_uncropped,
          pn_height_uncropped,
          pn_scanline_dur,
          pn_color_amplitude,
          pn_color_freq,
          pn_color_init_offset,
          pn_color_line_offset,
          pn_color_screen_offset,
          pn_nes_enable,
          pn_nes_phase_mod,
          pn_nes_real_capture,
          pn_nes_hue_skew,
          pn_genesis_palette,
          pn_genesis_jailbar_enable,
          pn_genesis_jailbar_offset,
          pn_genesis_jailbar_amplitude,
          pn_modulator_std,
          pn_modulator_luma_filter_type,
          pn_modulator_luma_filter_width,
          pn_modulator_luma_filter_level,
          pn_modulator_luma_radius,
          pn_modulator_luma_sigma,
          pn_modulator_luma_res,
          pn_modulator_luma_eq_f_lo,
          pn_modulator_luma_eq_f_hi,
          pn_modulator_luma_eq_g_lo,
          pn_modulator_luma_eq_g_mid,
          pn_modulator_luma_eq_g_hi,
          pn_modulator_luma_eq_off,
          pn_modulator_luma_eq_dist,
          pn_modulator_chroma_filter_type,
          pn_modulator_chroma_filter_width,
          pn_modulator_chroma_filter_level,
          pn_modulator_chroma_filter_level_diff,
          pn_modulator_chroma_eq_f_lo,
          pn_modulator_chroma_eq_f_hi,
          pn_modulator_chroma_eq_g_lo,
          pn_modulator_chroma_eq_g_mid,
          pn_modulator_chroma_eq_g_hi,
          pn_modulator_chroma_eq_off,
          pn_modulator_chroma_eq_dist,
          pn_demodulator_std,
          pn_demodulator_r_off,
          pn_demodulator_r_amp,
          pn_demodulator_g_off,
          pn_demodulator_g_amp,
          pn_demodulator_luma_filter_type,
          pn_demodulator_luma_filter_width,
          pn_demodulator_luma_filter_level,
          pn_demodulator_luma_radius,
          pn_demodulator_luma_sigma,
          pn_demodulator_luma_res,
          pn_demodulator_luma_eq_f_lo,
          pn_demodulator_luma_eq_f_hi,
          pn_demodulator_luma_eq_g_lo,
          pn_demodulator_luma_eq_g_mid,
          pn_demodulator_luma_eq_g_hi,
          pn_demodulator_luma_eq_off,
          pn_demodulator_luma_eq_dist,
          pn_demodulator_chroma_filter_type,
          pn_demodulator_chroma_filter_width,
          pn_demodulator_chroma_filter_level,
          pn_demodulator_chroma_filter_level_diff,
          pn_demodulator_chroma_eq_f_lo,
          pn_demodulator_chroma_eq_f_hi,
          pn_demodulator_chroma_eq_g_lo,
          pn_demodulator_chroma_eq_g_mid,
          pn_demodulator_chroma_eq_g_hi,
          pn_demodulator_chroma_eq_off,
          pn_demodulator_chroma_eq_dist,
          pn_demodulator_uv_filter_width,
          pn_demodulator_uv_filter_level,
          pn_knob_contrast,
          pn_knob_brightness,
          pn_knob_saturation,
          pn_knob_tint,
          pn_rgb_smear_enable,
          pn_rgb_smear_clamp,
          pn_rgb_smear_rate,
          pn_rgb_smear_limit,
          pn_rgb_smear_res,
          pn_gamma_type,
          pn_g_CRT_l,
          pn_power_gamma;
} global;

#pragma parameter pn_comment_header "======= Patchy NTSC Settings =======" 0 0 0 1

#pragma parameter pn_comment_test_pattern "=== Test Patterns ===" 0 0 0 1
#pragma parameter pn_test_pattern "Test Pattern: Color Bars, Ramps, HSV, Focused HSV, NES Full" 0 0 5 1

#pragma parameter pn_comment_resolution "=== Auto detect cropped overscan ===" 0 0 0 1
#pragma parameter pn_width_uncropped "Console Horizontal Resolution (pixels)" 320 128 720 1
#pragma parameter pn_height_uncropped "Console Vertical Resolution (pixels)" 224 128 480 1

#pragma parameter pn_comment_nes "=== NES Settings ===" 0 0 0 1
#pragma parameter pn_comment_nes_palette "== Note: Use Mesen (not FCEUmm) and change palette to Raw ==" 0 0 0 1
#pragma parameter pn_nes_enable "Enable NES Raw Palette Mode" 0 0 1 1
#pragma parameter pn_nes_phase_mod "NES Battletoads / Battletoads Double Dragon Phase Cycle" 0 0 1 1
#pragma parameter pn_nes_real_capture "NES color fix: Hue-skew | Real video capture LUT (unfinished)" 0 0 1 1
#pragma parameter pn_nes_hue_skew "NES hue-skew PPU version: 2C02G | 2C02E" 0 0 1 1

#pragma parameter pn_comment_genesis_jailbar "=== Genesis Settings ===" 0 0 0 1
#pragma parameter pn_genesis_palette "Genesis Plus GX color fix (not for BlastEm or other consoles)" 0 0 1 1
#pragma parameter pn_genesis_jailbar_enable "Enable Genesis/MegaDrive jailbars on solid backgrounds" 0 0 1 1
#pragma parameter pn_genesis_jailbar_offset "Genesis Jailbars Offset" 0 0 1 0.0625
#pragma parameter pn_genesis_jailbar_amplitude "Genesis Jailbars Severity" 1.0 0.1 3.0 0.1

#pragma parameter pn_comment_color_carrier "=== Color carrier settings ===" 0 0 0 1
#pragma parameter pn_scanline_dur "Scanline Duration (uSec)" 47.6 1.0 300.0 0.1
#pragma parameter pn_color_amplitude "Color Carrier Amplitude" 1.0 0.025 1.5 0.025 
#pragma parameter pn_color_freq "Color Carrier Frequency (MHz)" 3.5795454 3.47954 3.67954 0.00001
#pragma parameter pn_color_init_offset "Color Carrier Initial Offset" 0.1 0 1 0.02
#pragma parameter pn_color_line_offset "Color Carrier Per-Line Offset" 0 0 1 0.02
#pragma parameter pn_color_screen_offset "Color Carrier Per-Frame Offset" 0 0 1 0.02

#pragma parameter pn_comment_modulator_std "=== Console video standard (Most are Rec. 601) ===" 0 0 0 1
#pragma parameter pn_modulator_std "Modulator standard: Rec. 601 | Rec. 709" 0 0 1 1

#pragma parameter pn_comment_mod_luma_lowpass "=== (Not NES) Console's filtering luma/chroma before adding ===" 0 0 0 1
#pragma parameter pn_modulator_luma_filter_type "Mod. Luma Lowpass Type" 0 -1 3 1
#pragma parameter pn_modulator_luma_filter_width "Mod. Luma Lowpass (0) Sinc Half-Width" 9 0 30 0.25
#pragma parameter pn_modulator_luma_filter_level "Mod. Luma Lowpass (0) Sinc Cutoff Frequency (MHz)" 3.05 0.5 40.0 0.025
#pragma parameter pn_modulator_luma_radius "Mod. Luma Lowpass (1) Gaussian Blur Radius" 3.0 0.1 15.0 0.1
#pragma parameter pn_modulator_luma_sigma "Mod. Luma Lowpass (1) Gaussian Blur Sigma" 1.5 0.1 15.0 0.01
#pragma parameter pn_modulator_luma_res "Mod. Luma Lowpass (2) GTU Signal Res Y" 180 10 800 2
#pragma parameter pn_modulator_luma_eq_f_lo "Mod. Luma 3 band eq (3) Low freq (MHz)" 1.5 0.025 5.5 0.025
#pragma parameter pn_modulator_luma_eq_f_hi "Mod. Luma 3 band eq (3) Hi freq (MHz)" 3.0 0.025 5.5 0.025
#pragma parameter pn_modulator_luma_eq_g_lo "Mod. Luma 3 band eq (3) Low gain" 1.0 0.025 1.0 0.025
#pragma parameter pn_modulator_luma_eq_g_mid "Mod. Luma 3 band eq (3) Mid gain" 0.125 0.025 1.0 0.025
#pragma parameter pn_modulator_luma_eq_g_hi "Mod. Luma 3 band eq (3) High gain" 0.15 0.025 1.0 0.025
#pragma parameter pn_modulator_luma_eq_off "Mod. Luma 3 band eq (3) offset (pixels)" 0.5 0 4 0.0125
#pragma parameter pn_modulator_luma_eq_dist "Mod. Luma 3 band eq (3) max distance (% screen)" 20 5 40.0 0.25

#pragma parameter pn_modulator_chroma_filter_type "Mod. Chroma Bandpass Type" 0 -1 1 1
#pragma parameter pn_modulator_chroma_filter_width "Mod. Chroma Bandpass (0) Half-Width" 5 0 30 0.25
#pragma parameter pn_modulator_chroma_filter_level "Mod. Chroma Bandpass (0) Low Frequency (MHz)" 3.55 0.5 6.0 0.025
#pragma parameter pn_modulator_chroma_filter_level_diff "Mod. Chroma Bandpass (0) High Frequency (MHz)" 3.6 0.5 6.0 0.025
#pragma parameter pn_modulator_chroma_eq_f_lo "Mod. Chroma 3 band eq (1) Low freq (MHz)" 3.2 0.025 5.5 0.025
#pragma parameter pn_modulator_chroma_eq_f_hi "Mod. Chroma 3 band eq (1) Hi freq (MHz)" 4.5 0.025 5.5 0.025
#pragma parameter pn_modulator_chroma_eq_g_lo "Mod. Chroma 3 band eq (1) Low gain" 0.1 0.025 1.0 0.025
#pragma parameter pn_modulator_chroma_eq_g_mid "Mod. Chroma 3 band eq (1) Mid gain" 1.0 0.025 1.0 0.025
#pragma parameter pn_modulator_chroma_eq_g_hi "Mod. Chroma 3 band eq (1) High gain" 0.1 0.025 1.0 0.025
#pragma parameter pn_modulator_chroma_eq_off "Mod. Chroma 3 band eq (3) offset (pixels)" 0.5 0 4 0.0125
#pragma parameter pn_modulator_chroma_eq_dist "Mod. Chroma 3 band eq (1) max distance (% screen)" 20 5 40.0 0.25

#pragma parameter pn_comment_demod_filter "=== CRT Chroma/Luma Separation (a.k.a. comb filter) ===" 0 0 0 1
#pragma parameter pn_demodulator_luma_filter_type "Demodulator Luma Lowpass Type" 0 -1 4 1
#pragma parameter pn_demodulator_luma_filter_width "Demod. Luma Lowpass (0) Sinc Half-Width" 5 0 30 0.25
#pragma parameter pn_demodulator_luma_filter_level "Demod. Luma Lowpass (0) Sinc Cutoff Frequency (MHz)" 2.35 0.5 4.0 0.025
#pragma parameter pn_demodulator_luma_radius "Demod. Luma Lowpass (1) Gaussian Blur Radius" 4.5 0.1 15.0 0.1
#pragma parameter pn_demodulator_luma_sigma "Demod. Luma Lowpass (1) Gaussian Blur Sigma" 1.9 0.1 15.0 0.01
#pragma parameter pn_demodulator_luma_res "Demod. Luma Lowpass (2) GTU Signal Res Y" 180 10 800 2
#pragma parameter pn_demodulator_luma_eq_f_lo "Demod. Luma 3 band eq (3) Low freq (MHz)" 1.5 0.025 5.5 0.025
#pragma parameter pn_demodulator_luma_eq_f_hi "Demod. Luma 3 band eq (3) Hi freq (MHz)" 3.0 0.025 5.5 0.025
#pragma parameter pn_demodulator_luma_eq_g_lo "Demod. Luma 3 band eq (3) Low gain" 1.0 0.025 1.0 0.025
#pragma parameter pn_demodulator_luma_eq_g_mid "Demod. Luma 3 band eq (3) Mid gain" 0.125 0.025 1.0 0.025
#pragma parameter pn_demodulator_luma_eq_g_hi "Demod. Luma 3 band eq (3) High gain" 0.15 0.025 1.0 0.025
#pragma parameter pn_demodulator_luma_eq_off "Demod. Luma 3 band eq (3) offset (pixels)" 0.5 0 4 0.0125
#pragma parameter pn_demodulator_luma_eq_dist "Demod. Luma 3 band eq (3) max distance (% screen)" 20 5 40.0 0.25

#pragma parameter pn_demodulator_chroma_filter_type "Demod. Chroma Bandpass Type" 0 -1 2 1
#pragma parameter pn_demodulator_chroma_filter_width "Demod. Chroma Bandpass (0) Half-Width" 5 0 30 0.25
#pragma parameter pn_demodulator_chroma_filter_level "Demod. Chroma Bandpass (0) Low Frequency (MHz)" 3.55 0.5 6.0 0.025
#pragma parameter pn_demodulator_chroma_filter_level_diff "Demod. Chroma Bandpass (0) High Frequency (MHz)" 3.6 0.5 6.0 0.025
#pragma parameter pn_demodulator_chroma_eq_f_lo "Demod. Chroma 3 band eq (1) Low freq (MHz)" 3.2 0.025 5.5 0.025
#pragma parameter pn_demodulator_chroma_eq_f_hi "Demod. Chroma 3 band eq (1) Hi freq (MHz)" 4.5 0.025 5.5 0.025
#pragma parameter pn_demodulator_chroma_eq_g_lo "Demod. Chroma 3 band eq (1) Low gain" 0.1 0.025 1.0 0.025
#pragma parameter pn_demodulator_chroma_eq_g_mid "Demod. Chroma 3 band eq (1) Mid gain" 1.0 0.025 1.0 0.025
#pragma parameter pn_demodulator_chroma_eq_g_hi "Demod. Chroma 3 band eq (1) High gain" 0.1 0.025 1.0 0.025
#pragma parameter pn_demodulator_chroma_eq_off "Demod. Chroma 3 band eq (3) offset (pixels)" 0.5 0 4 0.0125
#pragma parameter pn_demodulator_chroma_eq_dist "Demod. Chroma 3 band eq (1) max distance (% screen)" 20 5 40.0 0.25

//#pragma parameter pn_comment_uv_filter "=== CRT U and V lowpass - Little need to change this ===" 0 0 0 1
//#pragma parameter pn_demodulator_uv_filter_width "Demodulator U and V Lowpass Half-Width" 6 0 30 0.25
//#pragma parameter pn_demodulator_uv_filter_level "Demodulator U and V Lowpass Cutoff Frequency (MHz)" 4 0.5 40.0 0.025

#pragma parameter pn_comment_demod_std "=== CRT Jungle Chip: US are reverse chrono order thru 1990s ===" 0 0 0 1
#pragma parameter pn_demodulator_std "Demodulator: Rec. 601, Rec. 709, 2*JP, 5*US, Custom" 8 0 9 1
#pragma parameter pn_demodulator_r_off "Custom R-Y offset" 112 90 130 1
#pragma parameter pn_demodulator_r_amp "Custom R-Y gain" 0.84 0.0 1.00 0.01
#pragma parameter pn_demodulator_g_off "Custom G-Y offset" 235 200 300 1
#pragma parameter pn_demodulator_g_amp "Custom G-Y gain" 0.33 0.0 1.00 0.01

#pragma parameter pn_comment_knobs "=== CRT End User Color Knobs ===" 0 0 0 1
#pragma parameter pn_knob_contrast "CRT Contrast (Picture)" 0.8 0 2 0.025
#pragma parameter pn_knob_brightness "CRT Brightness (Black Level)" 0 -0.5 0.5 0.01
#pragma parameter pn_knob_saturation "CRT Color (Saturation)" 1.0 0 5 0.025
#pragma parameter pn_knob_tint "CRT Tint (Hue Rotation)" 0 -45 45 0.5

#pragma parameter pn_comment_smearing "=== Red (and some blue) smearing to the right ===" 0 0 0 1
#pragma parameter pn_rgb_smear_enable "Enable Smearing (Should be off unless your CRT is wearing out)" 0 0 1 1
#pragma parameter pn_rgb_smear_clamp "RGB Clamp Level (any value above this becomes equal to this)" 1.5 1.0 3.0 0.05
#pragma parameter pn_rgb_smear_rate "RGB Smear Level (after clamping, anything above this smears)" 1.0 1.0 3.0 0.05
#pragma parameter pn_rgb_smear_limit "Max Smear Detection Distance (% of screen)" 30 0 100 0.25
#pragma parameter pn_rgb_smear_res "Smear Resolution (Higher is more intense but more accurate)" 1 1 3 1

#pragma parameter pn_comment_phosphor "=== CRT Gamma and Phosphor Gamut ===" 0 0 0 1
#pragma parameter pn_gamma_type "Gamma: BT.1886 + Grade black lift fix | BT.1886 | Power | sRGB" 1 0 3 1
#pragma parameter pn_g_CRT_l        "Black lift fix approximate gamma"                  2.50   2.30  2.60 0.01
#pragma parameter pn_power_gamma "Power gamma" 2.4 2.2 3.0 0.01

#endif // __patchy_ntsc_inc_params_inc__

