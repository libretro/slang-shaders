// Parameters related to system RGB video output, i.e. the system RGB
// DAC+filter+amplifier stage

#pragma parameter SYS_RGB_HEADER " —— System: RGB —— " 0.0 0.0 0.0 0.0

#pragma parameter SYS_BIAS_R "Offset R (IRE)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_BIAS_G "Offset G (IRE)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_BIAS_B "Offset B (IRE)" 0.0 -30.0 30.0 0.1

#pragma parameter SYS_GAIN_R "Gain R (dB)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_GAIN_G "Gain G (dB)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_GAIN_B "Gain B (dB)" 0.0 -30.0 30.0 0.1

#pragma parameter SYS_BANDWIDTH_R "Bandwidth R (MHz)" 5.4 0.0 150.0 0.01
#pragma parameter SYS_BANDWIDTH_G "Bandwidth G (MHz)" 5.4 0.0 150.0 0.01
#pragma parameter SYS_BANDWIDTH_B "Bandwidth B (MHz)" 5.4 0.0 150.0 0.01

#pragma parameter SYS_CUTOFF_ATTEN_R "Cutoff attenuation R (dB)" 12.5 0.0 30.0 1.0
#pragma parameter SYS_CUTOFF_ATTEN_G "Cutoff attenuation G (dB)" 12.5 0.0 30.0 1.0
#pragma parameter SYS_CUTOFF_ATTEN_B "Cutoff attenuation B (dB)" 12.5 0.0 30.0 1.0