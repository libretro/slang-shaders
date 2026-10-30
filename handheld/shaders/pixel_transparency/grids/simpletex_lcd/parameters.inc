// Simpletex LCD – Parameters

#pragma parameter PT_GRID				"== GRID - Simpletex LCD == (0=Soft, 1=Accurate)" 0.0 0.0 1.0 1.0
#pragma parameter GRID_INTENSITY		"      ↳ Intensity" 1.0 0.0 1.0 0.05
#pragma parameter GRID_WIDTH			"      ↳ Width" 1.0 0.0 1.0 0.05
#pragma parameter GRID_BIAS				"      ↳ Bias" 0.0 0.0 1.0 0.05
#pragma parameter DARKEN_GRID			"      ↳ Line shade (0=Light, 1=Dark)" 0.0 0.0 1.0 0.05
#pragma parameter DARKEN_COLOUR			"      ↳ Darken colors" 0.0 0.0 2.0 0.05
#pragma parameter BACKGROUND_INTENSITY	"      ↳ Background intensity" 1.0 0.0 1.0 0.05

#define PT_LCD_UNIFORMS \
    float PT_GRID; \
    float GRID_INTENSITY; \
    float GRID_WIDTH; \
    float GRID_BIAS; \
    float DARKEN_GRID; \
    float DARKEN_COLOUR; \
    float BACKGROUND_INTENSITY;
#include "../../pt-grid-parameters.inc"
