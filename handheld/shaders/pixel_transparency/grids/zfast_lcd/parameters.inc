// zfast LCD – Parameters

#pragma parameter PT_GRID				"== GRID - zfast LCD == (0=Soft, 1=Accurate)" 0.0 0.0 1.0 1.0
#pragma parameter BORDERMULT			"      ↳ Border multiplier" 14.0 -40.0 40.0 1.0
#pragma parameter GBAGAMMA				"      ↳ GBA gamma hack (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GRID_BRIGHTNESS	"      ↳ Line brightness (0=Dark, 1=Light)" 0.0 0.0 1.0 0.05

#define PT_LCD_UNIFORMS \
    float PT_GRID; \
    float BORDERMULT; \
    float GBAGAMMA; \
    float PT_GRID_BRIGHTNESS;
#include "../../pt-grid-parameters.inc"
