// Authentic GBC – Parameters

// Controls for the integrated Authentic GBC grid. The Authentic GBC controls
// keep upstream's names, defaults and ranges; only their labels are restyled.
#pragma parameter PT_GRID						"== GRID - Authentic GBC == (0=Soft, 1=Accurate)" 0.0 0.0 1.0 1.0
#pragma parameter AUTH_GBC_BRIG					"      ↳ Add brightness" 0.6 0.0 1.0 0.05
#pragma parameter AUTH_GBC_BLUR					"      ↳ Anti-banding smoothing" 0.3 0.0 1.0 0.05
#pragma parameter AUTH_GBC_SUBPX				"      ↳ Subpixel rendering (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter AUTH_GBC_SUBPX_ORIENTATION	"          ↳ Layout (0=RGB, 1=RGB vert., 2=BGR, 3=BGR vert.)" 0.0 0.0 3.0 1.0
#pragma parameter PT_GRID_STRENGTH				"      ↳ Strength" 1.0 0.0 1.0 0.05
#pragma parameter PT_GRID_BRIGHTNESS			"      ↳ Line brightness (0=Dark, 1=Light)" 0.0 0.0 1.0 0.05

#define PT_LCD_UNIFORMS \
    uint Rotation; \
    float AUTH_GBC_BRIG; \
    float AUTH_GBC_BLUR; \
    float AUTH_GBC_SUBPX; \
    float AUTH_GBC_SUBPX_ORIENTATION; \
    float PT_GRID; \
    float PT_GRID_STRENGTH; \
    float PT_GRID_BRIGHTNESS;
#include "../../pt-grid-parameters.inc"
