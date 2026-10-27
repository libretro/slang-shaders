// LCD Grid v2 – Parameters

#pragma parameter PT_GRID				"== GRID - LCD Grid v2 == (0=Soft, 1=Accurate)" 0.0 0.0 1.0 1.0
#pragma parameter RSUBPIX_R				"      ↳ Red subpixel color: R" 1.0 0.0 1.0 0.01
#pragma parameter RSUBPIX_G				"          ↳ G" 0.0 0.0 1.0 0.01
#pragma parameter RSUBPIX_B				"          ↳ B" 0.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_R				"      ↳ Green subpixel color: R" 0.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_G				"          ↳ G" 1.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_B				"          ↳ B" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_R				"      ↳ Blue subpixel color: R" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_G				"          ↳ G" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_B				"          ↳ B" 1.0 0.0 1.0 0.01
#pragma parameter gain					"      ↳ Gain"                    1.0 0.5 2.0 0.05
#pragma parameter gamma					"      ↳ LCD gamma"               3.0 0.5 5.0 0.1
#pragma parameter blacklevel			"      ↳ Black level"            0.05 0.0 0.5 0.01
#pragma parameter ambient				"      ↳ Ambient"                 0.0 0.0 0.5 0.01
#pragma parameter BGR					"      ↳ BGR subpixel order (OFF/ON)"                     0 0 1 1
#pragma parameter PT_GRID_BRIGHTNESS	"      ↳ Line brightness (0=Dark, 1=Light)" 0.0 0.0 1.0 0.05

#define PT_LCD_UNIFORMS \
    float PT_GRID; \
    float RSUBPIX_R; \
    float RSUBPIX_G; \
    float RSUBPIX_B; \
    float GSUBPIX_R; \
    float GSUBPIX_G; \
    float GSUBPIX_B; \
    float BSUBPIX_R; \
    float BSUBPIX_G; \
    float BSUBPIX_B; \
    float gain; \
    float gamma; \
    float blacklevel; \
    float ambient; \
    float BGR; \
    float PT_GRID_BRIGHTNESS;
#include "../../pt-grid-parameters.inc"
