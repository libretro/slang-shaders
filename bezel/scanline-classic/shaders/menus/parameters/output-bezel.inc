#pragma parameter BEZEL_HEADER " —— Output: Bezel —— " 0.0 0.0 0.0 0.0

#pragma parameter VIEWPORT_H_POS "Viewport horizontal position" 0.5 0.0 1.0 0.001
#pragma parameter VIEWPORT_V_POS "Viewport vertical position" 0.5 0.0 1.0 0.001

#pragma parameter BEZEL_GAIN "Bezel gain (dB)" -3.0 -48.0 48.0 1.0
#pragma parameter BEZEL_BIAS "Bezel bias (IRE)" 0.0 -100.0 100.0 0.5

#pragma parameter GLOW_HEADER " —— Output: Glow —— " 0.0 0.0 0.0 0.0

#pragma parameter GLOW_WEIGHT "Glow weight" 1.0 0.0 1.0 0.01
#pragma parameter GLOW_TEMPERATURE "Glow color temperature" 0.20 -0.5 0.5 0.01
#pragma parameter GLOW_RADIUS "Glow radius" 0.06 0.0 0.1 0.01
#pragma parameter GLOW_DIFFUSION "Glow diffusion" 3.0 1.0 10.0 1.0
#pragma parameter GLOW_COMPRESSION "Glow compression" 0.5 0.0 1.0 0.01
#pragma parameter GLOW_FALLOFF "Glow radial falloff" 1.0 0.5 10.0 0.1
#pragma parameter GLOW_JITTER "Glow jitter" 0.3 0.0 1.0 0.01
#pragma parameter GLOW_VERTICAL_BIAS "Glow vertical bias" 2.0 1.0 5.0 0.1