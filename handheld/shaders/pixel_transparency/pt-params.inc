/*
  ____  _          _
 |  _ \(_)_  _____| |
 | |_) | \ \/ / _ \ |
 |  __/| |>  <  __/ |
 |_|___|_/_/\_\___|_|
 |_   _| __ __ _ _ __  ___ _ __   __ _ _ __ ___ _ __   ___ _   _
   | || '__/ _` | '_ \/ __| '_ \ / _` | '__/ _ \ '_ \ / __| | | |
   | || | | (_| | | | \__ \ |_) | (_| | | |  __/ | | | (__| |_| |
   |_||_|  \__,_|_| |_|___/ .__/ \__,_|_|  \___|_| |_|\___|\__, |
                          |_|      TRANSPARENCY PARAMETERS  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Shared Pixel Transparency controls used by the cache and compositor stages.
    Preserves parameter identifiers, ordering, defaults and ranges.

*/

#pragma parameter PT_ENABLE 			"=== Pixel Transparency v3.0 === (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_HIDE_CONTENT 		" *  More grid styles in presets/pixel_transparency/" 0.0 0.0 2.0 1.0
#pragma parameter PT_DEFER_DITHER 		" *  Turn ON Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0
#pragma parameter NOTE3 				" *  Motion enabled on latest RetroArch nightly build." 0.0 0.0 1.0 1.0
#pragma parameter SECTION1 				"== COLOR ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PALETTE 			"      ↳ Backing tint (0=OFF, 1/2=Warm, 3/4=Neutral)" 3.0 0.0 4.0 1.0
#pragma parameter PT_PALETTE_INTENSITY 	"          ↳ Intensity" 1.0 0.0 2.0 0.05
#pragma parameter PT_BACKING_BRIGHTNESS "          ↳ Brightness" 0.48 0.20 0.65 0.01
#pragma parameter PT_POLARIZER 			"      ↳ Front polarizer tint (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_POLARIZER_TINT 	"          ↳ Intensity" 1.0 0.0 2.0 0.05
#pragma parameter PT_SATURATION 		"      ↳ Color saturation" 1.0 0.5 1.5 0.05
#pragma parameter PT_HIGHLIGHTS 		"      ↳ Pixel brightness (0=OFF, -Dim / +Bright)" 0.05 -1.0 1.0 0.01
#pragma parameter SECTION2 				"== TRANSPARENCY ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PIXEL_MODE 		"      ↳ Transparent pixels (0=White only, 1=Bright, 2=All)" 1.0 0.0 2.0 1.0
#pragma parameter PT_BASE_ALPHA 		"          ↳ Transparency amount" 0.20 0.0 1.0 0.01
#pragma parameter PT_THRESHOLD 			"      ↳ White pixel detection threshold" 0.90 0.0 1.0 0.01
#pragma parameter PT_WHITE_BOOST 		"      ↳ Boost white pixel transparency (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_WHITE_TRANSPARENCY "          ↳ Boost amount" 0.50 0.0 1.0 0.01
#pragma parameter PT_BRIGHTNESS_MODE 	"      ↳ Brightness mode (Simple / Natural)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_ENABLE 		"== SHADOWS == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_EDGE_ENABLE "      ↳ Screen edge shadow (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MOTION 		"      ↳ Motion (OFF/ON) " 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MAX_OFFSET	"          ↳ Max offset" 2.0 0.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_X 	"          ↳ Neutral X" 2.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_Y 	"          ↳ Neutral Y" 2.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OFFSET_X 	"      ↳ X offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OFFSET_Y 	"      ↳ Y offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OPACITY 	"      ↳ Opacity" 0.50 0.0 1.0 0.01
#pragma parameter PT_SHADOW_BLUR 		"      ↳ Blur" 2.0 0.0 5.0 0.1
#pragma parameter PT_ACCEL_ENABLE 		"== MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_ACCEL_SENSITIVITY 	"      ↳ Tilt sensitivity" 1.0 0.1 5.0 0.05
#pragma parameter SECTION_PERF 			"== PERFORMANCE ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PAPER_NOISE_FAST 	"      ↳ Background texture (0=Fast, 1=Full)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_FAST_BLUR 	"      ↳ Shadow blur (Fast / Smooth)" 1.0 0.0 1.0 1.0
