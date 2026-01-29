#pragma parameter DIGITAL_COMPONENT_HEADER " —— System: Digital Video —— " 0.0 0.0 0.0 0.0

#pragma parameter WORKING_BITS "Working bit depth" 10.0 1.0 10.0 1.0
#pragma parameter YCBCR_MODEL "System color space (601, 709)" 0.0 0.0 2.0 1.0
#pragma parameter DIGITAL_Y_FILTER_DECIMATION "Y bandwidth decimation" 1.0 1.0 16.0 1.0
#pragma parameter DIGITAL_Cb_FILTER_DECIMATION "Cb bandwidth decimation" 5.0 1.0 16.0 1.0
#pragma parameter DIGITAL_Cr_FILTER_DECIMATION "Cr bandwidth decimation" 5.0 1.0 16.0 1.0

#pragma DAC_HEADER " —— System: Digital to Analog Converter —— " 0.0 0.0 0.0 0.0

#pragma parameter DAC_BITS "Output bit depth" 8.0 1.0 10.0 1.0
#pragma parameter DITHER "Dithering (off, on)" 1.0 0.0 1.0 1.0
#pragma parameter VIDEO_MODE "Output mode (Composite, S-Video, Component)" 0.0 0.0 2.0 1.0

#pragma parameter SYS_BIAS_Y "Offset Y (IRE)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_BIAS_U "Offset C/Pb (IRE)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_BIAS_V "Offset Pr (IRE)" 0.0 -30.0 30.0 0.1

#pragma parameter SYS_GAIN_Y "Gain Y (dB)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_GAIN_U "Gain C/Pb (dB)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_GAIN_V "Gain Pr (dB)" 0.0 -30.0 30.0 0.1