#pragma parameter FAMICOM_HEADER " —— System: Famicom/NES Settings —— " 0.0 0.0 0.0 0.0
#pragma parameter PAL "Phase alternating line (off, on)" 0.0 0.0 1.0 1.0

#pragma parameter FILTER_BANDWIDTH "Filter bandwidth (MHz)" 7.0 0.0 150.0 0.01
#pragma parameter FILTER_CUTOFF_ATTEN "Filter cutoff attenuation (dB)" 20.0 0.0 30.0 1.0

// DPD defaults target an approximate 2C02E-like strength.
// At NTSC subcarrier (~3.58 MHz), 1 ns delay ~= 1.29 degrees phase lag.
// 2C02E estimate: ~7.5 degrees low->high differential (~6 ns)
// 2C02G estimate: ~15 degrees low->high differential (~12 ns)
// Suggested 2C02G tuning: FILTER_DPD_AMOUNT_NS = 12.0, FILTER_DPD_CURVE = 1.1
// Guidance:
// - Increase FILTER_DPD_AMOUNT_NS for stronger hue rotation at brighter levels.
// - Increase FILTER_DPD_CURVE to concentrate distortion into highlights.
// - FILTER_DPD_IN_MIN / MAX define the voltage window mapped to 0..1 DPD drive.
#pragma parameter FILTER_DPD_AMOUNT_NS "Filter DPD amount (ns)" 6.0 0.0 30.0 0.1
#pragma parameter FILTER_DPD_CURVE "Filter DPD curve" 1.0 0.1 4.0 0.1
#pragma parameter FILTER_DPD_IN_MIN "Filter DPD input min" 0.0 -0.5 1.1 0.01
#pragma parameter FILTER_DPD_IN_MAX "Filter DPD input max" 1.1 -0.5 1.1 0.01
