// LCD1x – Parameters

#pragma parameter PT_GRID				"== GRID - LCD1x == (0=Soft, 1=Accurate)" 0.0 0.0 1.0 1.0
#pragma parameter BRIGHTEN_SCANLINES	"      ↳ Brighten scanlines" 16.0 1.0 32.0 0.5
#pragma parameter BRIGHTEN_LCD			"      ↳ Brighten LCD" 4.0 1.0 12.0 0.1
#pragma parameter PT_GRID_BRIGHTNESS	"      ↳ Line brightness (0=Dark, 1=Light)" 0.0 0.0 1.0 0.05

#define PT_LCD_UNIFORMS \
    float PT_GRID; \
    float BRIGHTEN_SCANLINES; \
    float BRIGHTEN_LCD; \
    float PT_GRID_BRIGHTNESS;
#include "../../pt-grid-parameters.inc"
