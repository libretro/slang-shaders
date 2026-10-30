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
                          |_|          SUNLIGHT PARAMETERS  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Shared Sunlight Shimmer controls for the lighting cache and compositor.
    Preserves parameter identifiers, ordering, defaults and ranges.

*/

#pragma parameter PT_SUNLIGHT_ENABLE 	"== SUNLIGHT SHIMMER == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GLARE_ENABLE 		"      ↳ Glare (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GLARE_INTENSITY 	"          ↳ Strength" 0.15 0.0 1.0 0.05
#pragma parameter PT_GLARE_SIZE			"          ↳ Spread" 0.25 0.05 1.0 0.05
#pragma parameter PT_RAINBOW_ENABLE 	"      ↳ Rainbow shimmer (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_RAINBOW_INTENSITY 	"          ↳ Intensity" 0.15 0.0 1.0 0.01
#pragma parameter PT_FILM_TUNING 		"          ↳ Color shift" 1.0 0.5 2.0 0.05
#pragma parameter PT_LIGHT_SPREAD 		"          ↳ Band density" 1.8 0.5 4.0 0.1
#pragma parameter PT_FILM_NOISE 		"          ↳ Film splotchiness" 0.5 0.0 1.0 0.05
#pragma parameter PT_FILM_SCALE 		"          ↳ Splotch size" 0.6 0.1 3.0 0.05
#pragma parameter PT_RAINBOW_COLORS 	"          ↳ Colors (3=Fast, 7=Full)" 7.0 3.0 7.0 2.0
#pragma parameter PT_REFLECT_ENABLE     "      ↳ Reflection (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_REFLECT_INTENSITY  "          ↳ Strength" 0.08 0.0 0.5 0.01
#pragma parameter PT_REFLECT_SPREAD     "          ↳ Spread (lower = sharper)" 0.6 0.1 1.0 0.05
#pragma parameter PT_REFLECT_BIAS       "          ↳ Ambient floor" 0.02 0.0 0.2 0.005
#pragma parameter PT_REFLECT_WARM       "          ↳ Warm tint" 0.3 0.0 1.0 0.05
#pragma parameter PT_LIGHT_HEIGHT 		"      ↳ Light source distance (0=Flat, 1=Far)" 0.0 0.0 1.0 0.05
#pragma parameter PT_LIGHT_RANGE 		"          ↳ Tilt range" 0.6 0.0 2.0 0.05
#pragma parameter PT_LIGHT_X 			"          ↳ X" 0.5 -1.0 2.0 0.01
#pragma parameter PT_LIGHT_Y 			"          ↳ Y" 0.5 -1.0 2.0 0.01
