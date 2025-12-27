// Parameters related to system video output timing

#pragma parameter TIMING_HEADER " —— System: Timing —— " 0.0 0.0 0.0 0.0

#pragma parameter SC_FREQ_MODE "Subcarrier frequency mode (auto, NTSC, PAL, PAL-M, custom)" 0.0 0.0 4.0 1.0
#pragma parameter SC_FREQ "Custom subcarrier frequency (MHz)" 3.579545 0.0 10.0 0.01
#pragma parameter PIXEL_CLOCK_MODE "Pixel clock mode (fixed, multiple of subcarrier)" 0.0 0.0 1.0 1.0
#pragma parameter PIXEL_CLOCK "Pixel clock frequency (MHz) / multiplier" 13.5 0.0 500.0 0.01
#pragma parameter H_FREQ_MODE "Horizontal frequency mode (standard, PC divisor, custom)" 0.0 0.0 2.0 1.0
#pragma parameter H_FREQ "Custom horizontal frequency (kHz) / divisor" 15.734 0.0 2000.0 0.01
#pragma parameter V_FREQ_MODE "Vertical sync mode (auto, NTSC, PAL, H freq divisor, custom)" 0.0 0.0 4.0 1.0
#pragma parameter V_FREQ "Custom vertical sync rate (Hz) / divisor" 59.94 0.0 600.0 0.01
#pragma parameter H_BLANK_FUZZ "Horizontal blanking fuzz factor (%)" 82.8 0.0 100.0 0.1
#pragma parameter FIELD_ORDER "Field order (even first, odd first)" 0.0 0.0 2.0 1.0
#pragma parameter SHORTEN_ODD_FIELD_TIME "NES/SNES field time adjust (off, on)" 0.0 0.0 1.0 1.0