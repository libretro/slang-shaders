/* Filename: window.inc

   Shared windowed-sinc utilities for IQ modulation/demodulation.
   Contains Blackman-Harris 4-term window and windowed-sinc coefficient helpers.
*/

// Blackman-Harris 4-term window
// Stopband: ~92 dB, mainlobe width = 8π/N
// Superior phase linearity and stopband rejection compared to Kaiser
float blackman_harris_4term(float n, float N)
{
    const float a0 = 0.35875;
    const float a1 = 0.48829;
    const float a2 = 0.14128;
    const float a3 = 0.01168;

    float Ne = max(N - 1.0, 1.0);
    float k = n + 0.5 * Ne;        // center at (N-1)/2
    float x = 2.0 * PI * k / Ne;   // use N-1 denominator

    return a0 - a1 * cos(x) + a2 * cos(2.0 * x) - a3 * cos(3.0 * x);
}

// Hamming window
// Stopband: ~43 dB, mainlobe width = 4π/N
// Efficient window for baseband IQ filtering with minimal ringing (~1.5% overshoot)
float hamming(float n, float N)
{
    const float a0 = 0.54;
    const float a1 = 0.46;

    float Ne = max(N - 1.0, 1.0);
    float k = n + 0.5 * Ne;        // center at (N-1)/2
    float x = 2.0 * PI * k / Ne;   // use N-1 denominator

    return a0 - a1 * cos(x);
}

// Windowed-sinc lowpass coefficient (normalized cutoff fc in cycles/sample)
// Uses Blackman-Harris 4-term window for ~92 dB stopband rejection
float sinc_lowpass_bh4(float n, float fc_norm, float N)
{
    float sinc;
    if (abs(n) < EPS) {
        sinc = 2.0 * fc_norm;  // integral of ideal LP at n=0
    } else {
        float x = 2.0 * PI * fc_norm * n;
        sinc = sin(x) / (PI * n);
    }
    float w = blackman_harris_4term(n, N);
    return sinc * w;
}

// Overload returning coefficient and window weight via out parameter (Blackman-Harris)
float sinc_lowpass_bh4(float n, float fc_norm, float N, out float w)
{
    float sinc;
    if (abs(n) < EPS) {
        sinc = 2.0 * fc_norm;  // integral of ideal LP at n=0
    } else {
        float x = 2.0 * PI * fc_norm * n;
        sinc = sin(x) / (PI * n);
    }
    w = blackman_harris_4term(n, N);
    return sinc * w;
}

// Windowed-sinc lowpass coefficient (normalized cutoff fc in cycles/sample)
// Uses Hamming window for ~43 dB stopband rejection with minimal ringing
float sinc_lowpass_hamming(float n, float fc_norm, float N)
{
    float sinc;
    if (abs(n) < EPS) {
        sinc = 2.0 * fc_norm;  // integral of ideal LP at n=0
    } else {
        float x = 2.0 * PI * fc_norm * n;
        sinc = sin(x) / (PI * n);
    }
    float w = hamming(n, N);
    return sinc * w;
}

// Overload returning coefficient and window weight via out parameter (Hamming)
float sinc_lowpass_hamming(float n, float fc_norm, float N, out float w)
{
    float sinc;
    if (abs(n) < EPS) {
        sinc = 2.0 * fc_norm;  // integral of ideal LP at n=0
    } else {
        float x = 2.0 * PI * fc_norm * n;
        sinc = sin(x) / (PI * n);
    }
    w = hamming(n, N);
    return sinc * w;
}

// Windowed-sinc bandpass coefficient using difference of two lowpass sincs
// Uses Blackman-Harris 4-term window for ~92 dB stopband rejection
float sinc_bandpass_bh4(float n, float fc_upper, float fc_lower, float N)
{
    float sinc_upper, sinc_lower;
    if (abs(n) < EPS) {
        sinc_upper = 2.0 * fc_upper;
        sinc_lower = 2.0 * fc_lower;
    } else {
        float x_upper = 2.0 * PI * fc_upper * n;
        float x_lower = 2.0 * PI * fc_lower * n;
        sinc_upper = sin(x_upper) / (PI * n);
        sinc_lower = sin(x_lower) / (PI * n);
    }
    float bandpass_sinc = sinc_upper - sinc_lower;
    float window = blackman_harris_4term(n, N);
    return bandpass_sinc * window;
}

// Windowed-sinc bandpass coefficient using difference of two lowpass sincs
// Uses Hamming window for ~43 dB stopband rejection with minimal ringing
float sinc_bandpass_hamming(float n, float fc_upper, float fc_lower, float N)
{
    float sinc_upper, sinc_lower;
    if (abs(n) < EPS) {
        sinc_upper = 2.0 * fc_upper;
        sinc_lower = 2.0 * fc_lower;
    } else {
        float x_upper = 2.0 * PI * fc_upper * n;
        float x_lower = 2.0 * PI * fc_lower * n;
        sinc_upper = sin(x_upper) / (PI * n);
        sinc_lower = sin(x_lower) / (PI * n);
    }
    float bandpass_sinc = sinc_upper - sinc_lower;
    float window = hamming(n, N);
    return bandpass_sinc * window;
}

// Modified Bessel function I0(x) approximation
// Accurate to ~1e-7 for practical range |x| <= 20
// Uses polynomial approximation for efficient GPU computation
float kaiser_i0(float x)
{
    float ax = abs(x);
    if (ax < 3.75) {
        // Polynomial approximation for small arguments
        float y = sq(x / 3.75);
        return 1.0 + y * (3.5156229 + y * (3.0899424 + y * (1.2067492
            + y * (0.2659732 + y * (0.0360768 + y * 0.0045813)))));
    } else {
        // Asymptotic approximation for large arguments
        float y = 3.75 / ax;
        return (exp(ax) / sqrt(ax)) * (0.39894228 + y * (0.01328592
            + y * (0.00225319 + y * (-0.00157565 + y * (0.00916281
            + y * (-0.02057706 + y * (0.02635537 + y * (-0.01647633
            + y * 0.00392377))))))));
    }
}

// Kaiser window with tunable ripple parameter
// beta: ripple control parameter (higher = more stopband rejection)
// Common values:
//   beta ≈ 5.0  → ~50 dB stopband, 0.3 dB passband ripple
//   beta ≈ 5.87 → ~62 dB stopband, 0.2 dB passband ripple
//   beta ≈ 8.6  → ~70 dB stopband
//   beta ≈ 10.6 → ~92 dB stopband
float kaiser(float n, float N, float beta)
{
    float Ne = max(N - 1.0, 1.0);
    float k = n + 0.5 * Ne;        // center at (N-1)/2
    float alpha = 2.0 * k / Ne - 1.0;
    
    // Normalized argument for I0: β√(1 - α²)
    float arg = beta * sqrt(max(1.0 - sq(alpha), 0.0));
    return kaiser_i0(arg) / kaiser_i0(beta);
}

// Windowed-sinc lowpass coefficient using Kaiser window
// beta parameter controls stopband rejection:
//   5.87 → ~62 dB stopband (recommended for upsampling)
float sinc_lowpass_kaiser(float n, float fc_norm, float N, float beta)
{
    float sinc;
    if (abs(n) < EPS) {
        sinc = 2.0 * fc_norm;  // integral of ideal LP at n=0
    } else {
        float x = 2.0 * PI * fc_norm * n;
        sinc = sin(x) / (PI * n);
    }
    float w = kaiser(n, N, beta);
    return sinc * w;
}

// Overload returning coefficient and window weight via out parameter (Kaiser)
float sinc_lowpass_kaiser(float n, float fc_norm, float N, float beta, out float w)
{
    float sinc;
    if (abs(n) < EPS) {
        sinc = 2.0 * fc_norm;  // integral of ideal LP at n=0
    } else {
        float x = 2.0 * PI * fc_norm * n;
        sinc = sin(x) / (PI * n);
    }
    w = kaiser(n, N, beta);
    return sinc * w;
}

// Kaiser beta from desired attenuation (dB)
float kaiser_beta_from_atten(float A)
{
    if (A <= 21.0) return 0.0;
    if (A < 50.0) return 0.5842 * pow(A - 21.0, 0.4) + 0.07886 * (A - 21.0);
    return 0.1102 * (A - 8.7);
}

// Windowed-sinc bandpass coefficient using Kaiser window
float sinc_bandpass_kaiser(float n, float fc_upper, float fc_lower, float N, float beta)
{
    float sinc_upper, sinc_lower;
    if (abs(n) < EPS) {
        sinc_upper = 2.0 * fc_upper;
        sinc_lower = 2.0 * fc_lower;
    } else {
        float x_upper = 2.0 * PI * fc_upper * n;
        float x_lower = 2.0 * PI * fc_lower * n;
        sinc_upper = sin(x_upper) / (PI * n);
        sinc_lower = sin(x_lower) / (PI * n);
    }
    float bandpass_sinc = sinc_upper - sinc_lower;
    float window = kaiser(n, N, beta);
    return bandpass_sinc * window;
}

// Modulated-kernel bandpass: baseband lowpass modulated to subcarrier
// Simpler and more direct for filtering modulated chroma signals
float sinc_bandpass_modulated_kaiser(float n, float fc_center, float bandwidth, float N, float beta)
{
    // Design baseband lowpass at the desired chroma bandwidth
    float sinc_lp;
    if (abs(n) < EPS) {
        sinc_lp = 2.0 * bandwidth;
    } else {
        float x = 2.0 * PI * bandwidth * n;
        sinc_lp = sin(x) / (PI * n);
    }
    
    // Apply Kaiser window
    float window = kaiser(n, N, beta);
    
    // Modulate to subcarrier (factor of 2 for real-valued signal)
    return 2.0 * sinc_lp * window * cos(2.0 * PI * fc_center * n);
}
