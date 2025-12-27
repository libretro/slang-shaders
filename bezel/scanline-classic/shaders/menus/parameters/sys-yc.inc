#pragma parameter SYS_YC_HEADER " —— System: Y/C Processing —— " 0.0 0.0 0.0 0.0

#pragma parameter LUMA_LOWPASS_CUTOFF "Y lowpass cutoff (MHz)" 6.75 0.1 10.0 0.1
#pragma parameter LUMA_LOWPASS_ATTEN "Y lowpass attenuation (dB)" 0.0 0.0 24.0 0.1

#pragma parameter LUMA_NOTCH_ENABLE "Y notch filter (off, on)" 0.0 0.0 1.0 1.0
#pragma parameter LUMA_NOTCH_WIDTH "Y notch filter width (MHz)" 0.6 0.1 4.0 0.1
#pragma parameter LUMA_NOTCH_ATTEN_DB "Y notch filter attenuation (dB)" 6.0 0.0 30.0 0.1

#pragma parameter CHROMA_BANDPASS_WIDTH "Chroma bandpass width (MHz)" 1.3 0.1 6.0 0.1
#pragma parameter CHROMA_EDGE_ATTEN_DB "Chroma edge attenuation (dB)" 2.0 0.0 24.0 0.1