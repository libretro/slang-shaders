#version 450

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
                          |_|                               |___/
    v2.1 by mattakins
    Copyright (C) 2025 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.

    With no backlight, the original devices didn't render white pixels. Light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.

    Just append to your favorite LCD shader as the last pass to reduce eye strain and maximize nostalgia.

*/

#pragma parameter PT_ENABLE 			"=== Pixel Transparency v2.1 === (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_HIDE_CONTENT 		" *  Append to any LCD shader as last pass. Try with GBC & GBA." 0.0 0.0 2.0 1.0
#pragma parameter NOTE2 				" *  Turn ON Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0

#pragma parameter SECTION1 				"== COLOR ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PALETTE 			"--- 1. Backing tint (0=OFF, 1/2=Warm, 3/4=Neutral)" 3.0 0.0 4.0 1.0
#pragma parameter PT_PALETTE_INTENSITY 	"      ↳ Intensity" 1.0 0.0 2.0 0.05
#pragma parameter PT_BACKING_BRIGHTNESS "      ↳ Brightness" 0.48 0.20 0.65 0.01

#pragma parameter PT_POLARIZER 			"--- 2. Front polarizer tint (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_POLARIZER_TINT 	"      ↳ Intensity" 1.0 0.0 1.0 0.05

#pragma parameter PT_SATURATION 		"--- 3. Color saturation" 1.0 0.5 1.5 0.05

#pragma parameter PT_HIGHLIGHTS 		"--- 4. Pixel brightness (0=OFF, -Dim / +Bright)" 0.05 -1.0 1.0 0.01

#pragma parameter SECTION2 				"== TRANSPARENCY ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PIXEL_MODE 		"--- 5. Transparent pixels (0=White only, 1=Bright, 2=All)" 1.0 0.0 2.0 1.0
#pragma parameter PT_BASE_ALPHA 		"      ↳ Transparency amount" 0.20 0.0 1.0 0.01

#pragma parameter PT_THRESHOLD 			"--- 6. White pixel detection threshold" 0.90 0.0 1.0 0.01

#pragma parameter PT_WHITE_BOOST 		"--- 7. Boost white pixel transparency (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_WHITE_TRANSPARENCY "      ↳ Boost amount" 0.50 0.0 1.0 0.01

#pragma parameter PT_BRIGHTNESS_MODE 	"--- 8. Brightness mode (0=Simple, 1=Natural)" 1.0 0.0 1.0 1.0

#pragma parameter PT_BRIGHTNESS_GRID 	"--- 9. Gridline intensity (0=Less, 1=More)" 0.0 0.0 1.0 0.05

#pragma parameter PT_SHADOW_ENABLE 		"== 10. SHADOWS == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MOTION 		"       Shadow motion (OFF/ON) " 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MAX_OFFSET	"          ↳ Max offset" 2.50 0.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_X 	"          ↳ Neutral X" 0.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_Y 	"          ↳ Neutral Y" 2.0 -30.0 30.0 0.5

#pragma parameter PT_SHADOW_OFFSET_X 	"      ↳ X offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OFFSET_Y 	"      ↳ Y offset" 3.0 -30.0 30.0 0.5

#pragma parameter PT_SHADOW_OPACITY 	"      ↳ Opacity" 0.50 0.0 1.0 0.01
#pragma parameter PT_SHADOW_BLUR 		"      ↳ Blur amount" 1.0 0.0 5.0 0.1

#pragma parameter PT_ACCEL_ENABLE 		"== 11. MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter NOTE3 				" *  Motion enabled on latest RetroArch nightly build." 0.0 0.0 1.0 1.0
#pragma parameter PT_ACCEL_RELATIVE 	"      ↳ Tilt neutral (0=Device flat, 1=From hold)" 0.0 0.0 1.0 1.0
#pragma parameter PT_ACCEL_SENSITIVITY 	"      ↳ Tilt sensitivity" 1.0 0.1 5.0 0.05

#pragma parameter SECTION_PERF 			"== PERFORMANCE ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_FAST_BLUR 	"      ↳ Shadow quality (0=Low, 1=High)" 1.0 0.0 1.0 1.0

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    // Vertex-stage parameters
    float PT_ACCEL_ENABLE;
    float PT_ACCEL_RELATIVE;
    float PT_ACCEL_SENSITIVITY;
    float PT_SHADOW_MOTION;
    float PT_SHADOW_MAX_OFFSET;
    float PT_SHADOW_MOTION_X;
    float PT_SHADOW_MOTION_Y;
    float PT_SHADOW_OFFSET_X;
    float PT_SHADOW_OFFSET_Y;
    // Hot fragment-stage parameters
    float PT_ENABLE;
    float PT_BRIGHTNESS_MODE;
    float PT_SHADOW_ENABLE;
    float PT_SHADOW_BLUR;
    float PT_SHADOW_OPACITY;
    float PT_THRESHOLD;
    float PT_SHADOW_FAST_BLUR;
    float PT_PIXEL_MODE;
    float PT_BASE_ALPHA;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
    float PT_HIDE_CONTENT;
    float PT_PALETTE;
    float PT_PALETTE_INTENSITY;
    float PT_BACKING_BRIGHTNESS;
    float PT_POLARIZER;
    float PT_POLARIZER_TINT;
    float PT_SATURATION;
    float PT_HIGHLIGHTS;
    float PT_WHITE_BOOST;
    float PT_WHITE_TRANSPARENCY;
    float PT_BRIGHTNESS_GRID;
} global;

#include "pt_base.inc"

    FragColor = output_color;
}