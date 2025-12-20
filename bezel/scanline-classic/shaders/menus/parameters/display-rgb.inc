// Field service calibration settings for the RGB electron guns
//
// This is the the final stage in the voltage domain

#pragma parameter DISPLAY_RGB_HEADER " —— Service: RGB —— " 0.0 0.0 0.0 0.0

#pragma parameter DISPLAY_BIAS_R "Bias R (IRE)" 0.0 -30.0 30.0 0.5
#pragma parameter DISPLAY_BIAS_G "Bias G (IRE)" 0.0 -30.0 30.0 0.5
#pragma parameter DISPLAY_BIAS_B "Bias B (IRE)" 0.0 -30.0 30.0 0.5

#pragma parameter DISPLAY_GAIN_R "Drive R (dB)" 0.0 -30.0 30.0 0.1
#pragma parameter DISPLAY_GAIN_G "Drive G (dB)" 0.0 -30.0 30.0 0.1
#pragma parameter DISPLAY_GAIN_B "Drive B (dB)" 0.0 -30.0 30.0 0.1

#pragma parameter DISPLAY_BANDLIMIT_R "Bandwidth R (MHz)" 5.4 0.0 75.0 0.01
#pragma parameter DISPLAY_BANDLIMIT_G "Bandwidth G (MHz)" 5.4 0.0 75.0 0.01
#pragma parameter DISPLAY_BANDLIMIT_B "Bandwidth B (MHz)" 5.4 0.0 75.0 0.01

#pragma parameter DISPLAY_CUTOFF_ATTEN_R "Cutoff attenuation R (dB)" 12.5 0.0 30.0 1.0
#pragma parameter DISPLAY_CUTOFF_ATTEN_G "Cutoff attenuation G (dB)" 12.5 0.0 30.0 1.0
#pragma parameter DISPLAY_CUTOFF_ATTEN_B "Cutoff attenuation B (dB)" 12.5 0.0 30.0 1.0