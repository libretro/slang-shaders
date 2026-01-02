#pragma parameter SYS_YC_HEADER " —— System: Y/C Processing —— " 0.0 0.0 0.0 0.0

#pragma parameter YC_MODEL "System color space (YIQ, YPbPr, YUV, YDbDr, YCbCr)" 1.0 0.0 4.0 1.0

#pragma parameter SYS_BIAS_Y "Offset Y (IRE)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_BIAS_U "Offset U (IRE)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_BIAS_V "Offset V (IRE)" 0.0 -30.0 30.0 0.1

#pragma parameter SYS_GAIN_Y "Gain Y (dB)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_GAIN_U "Gain U (dB)" 0.0 -30.0 30.0 0.1
#pragma parameter SYS_GAIN_V "Gain V (dB)" 0.0 -30.0 30.0 0.1

#pragma parameter LUMA_LOWPASS_CUTOFF "Y lowpass cutoff (MHz)" 6.75 0.1 14.0 0.1
#pragma parameter LUMA_LOWPASS_ATTEN "Y lowpass attenuation (dB)" 0.0 0.0 24.0 0.1

#pragma parameter LUMA_NOTCH_ENABLE "Y notch filter (off, on)" 0.0 0.0 1.0 1.0
#pragma parameter LUMA_NOTCH_WIDTH "Y notch filter width (MHz)" 0.6 0.3 3.0 0.1
#pragma parameter LUMA_NOTCH_ATTEN_DB "Y notch filter attenuation (dB)" 3.0 0.0 30.0 0.1

#pragma parameter CHROMA_BANDPASS_WIDTH "Chroma bandpass width (MHz)" 1.3 0.3 3.0 0.1
#pragma parameter CHROMA_EDGE_ATTEN_DB "Chroma edge attenuation (dB)" 2.0 0.0 24.0 0.1