#pragma parameter RF_INPUT_HEADER " —— Factory: RF Input —— " 0.0 0.0 0.0 0.0

#pragma parameter IQ_DEMOD_Q_WEIGHT "Vestigial weight" -0.27 -2.0 2.0 0.01

#pragma parameter RF_MODULATOR_HEADER " —— System: RF Modulator —— " 0.0 0.0 0.0 0.0

#pragma parameter USB_BANDWIDTH "Video channel bandwidth (MHz)" 4.2 1.5 12.0 0.1
#pragma parameter LSB_BANDWIDTH "Vestigial bandwidth (MHz)" 0.75 0.25 3.0 0.01
#pragma parameter USB_ROLL_OFF "Video channel roll-off (MHz)" 0.55 0.05 3.0 0.05
#pragma parameter LSB_ROLL_OFF "Vestigial roll-off (MHz)" 0.50 0.05 3.0 0.05

#pragma parameter NOISE_MODE "Noise mode (fast, advanced)" 1.0 0.0 1.0 1.0
#pragma parameter NOISE_AWGN_DB "AWGN level (dB)" -35.0 -96.0 48.0 1.0
#pragma parameter NOISE_PHASE_JITTER_DEG "Phase jitter (° RMS)" 0.10 0.0 5.0 0.01
#pragma parameter NOISE_GHOST1_DB "Ghost1 level (dB)" -40.0 -80.0 0.0 1.0
#pragma parameter NOISE_GHOST1_PIX "Ghost1 delay (px)" 12.0 0.0 120.0 1.0
#pragma parameter NOISE_IMPULSE_RATE "Impulse rate (ppm)" 5.0 0.0 200.0 1.0
#pragma parameter NOISE_IMPULSE_DB "Impulse level (dB)" -10.0 -40.0 0.0 1.0