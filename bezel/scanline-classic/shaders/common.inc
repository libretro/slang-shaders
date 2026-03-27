/* Filename: common.inc

   Copyright (C) 2023-2025 W. M. Martinez

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>. */

const float EPS = 1.19209289551e-7;
const float PI = 3.14159265359;
const float FILTER_THRESHOLD = 1.0 / 255.0;  // 8-bit LSB threshold for early loop exit
const vec3 BLACK = vec3(0.0, 0.0, 0.0);
const vec3 WHITE = vec3(1.0, 1.0, 1.0);
const vec3 RED = vec3(1.0, 0.0, 0.0);
const vec3 YELLOW = vec3(1.0, 1.0, 0.0);
const vec3 GREEN = vec3(0.0, 1.0, 0.0);
const vec3 BLUE = vec3(0.0, 1.0, 1.0);
const vec3 INDIGO = vec3(0.0, 0.0, 1.0);
const vec3 VIOLET = vec3(1.0, 0.0, 1.0);

const float VOLTAGE_100 = 0.7143;      // Voltage at 100 IRE
const float VOLTAGE_133 = 0.950019;    // Voltage at 133 IRE

float sq(const float x)
{
    return x * x;
}

float cb(const float x)
{
    return x * x * x;
}

float gaussian(float x, float sigma)
{
    // Dirac-like impulse when sigma collapses: centered on [-0.5, 0.5)
    if (sigma <= 0.0)
        return (x >= -0.5 && x < 0.5) ? 1.0 : 0.0;

    // Normal Gaussian: exp(-x^2 / (2 σ^2))
    // Use EPS to avoid division by zero for tiny σ.
    float s = max(sigma, EPS);
    return exp(-sq(x) / (2.0 * sq(s)));
}

vec3 gaussian3(float x, vec3 sigma)
{
    // Component-wise Dirac handling when any channel’s sigma <= 0.
    float inSpan = (x >= -0.5 && x < 0.5) ? 1.0 : 0.0;

    vec3 impulseMask = vec3(
        sigma.r <= 0.0 ? 1.0 : 0.0,
        sigma.g <= 0.0 ? 1.0 : 0.0,
        sigma.b <= 0.0 ? 1.0 : 0.0
    );
    vec3 impulseVal = impulseMask * inSpan;

    // Gaussian for non-impulse channels
    vec3 s = max(sigma, vec3(EPS));
    vec3 k = -0.5 / (s * s);
    vec3 gaussVal = exp(k * x * x);

    // Use impulse where sigma <= 0, Gaussian otherwise
    return impulseVal + (vec3(1.0) - impulseMask) * gaussVal;
}

// Map normalized limited-range video signal to voltage
// IRE = Input * 100.0
// Voltage = IRE / 100.0 * 0.7143 V
// Output = Input * 0.7143 V
vec3 normlimit_to_voltage(const vec3 norm)
{
    return norm * VOLTAGE_100;
}

vec3 voltage_to_normlimit(const vec3 voltage)
{
    return voltage / VOLTAGE_100;
}

// Map normalized limited-range video signal to normalized full-range
// video level
//
// Voltage = Input * 0.7143 V
// Minimum voltage = 0.0 / 100.0 * 0.7143 = 0.0 V
// Maximum voltage = 133.0 / 100.0 * 0.7143 = 0.950019 V
// Voltage range = Maximum - Minimum = 0.950019 V
// Output = (Input * 0.7143 - Minimum) / Voltage range
//
// This is needed for shaders that expect full-range input, such as the
// scanline rasterizer.
vec3 normlimit_to_normfull(const vec3 norm)
{
    return norm * VOLTAGE_100 / VOLTAGE_133;
}

vec3 voltage_to_normfull(const vec3 voltage)
{
    return voltage / VOLTAGE_133;
}

// Map normalized full-range video signal to voltage
// Voltage = Input * Voltage range + Minimum voltage
vec3 normfull_to_voltage(const vec3 norm)
{
   return norm * VOLTAGE_133;
}

float crt_linear(const float x)
{
    return pow(x, 2.4);
}

vec3 crt_linear(const vec3 x)
{
    return pow(x, vec3(2.4));
}

float crt_gamma(const float x)
{
    return pow(x, 1.0 / 2.4);
}

vec3 crt_gamma(const vec3 x)
{
    return pow(x, vec3(1.0 / 2.4));
}

vec3 bt1886_linear(const vec3 x, const float a, const float b)
{
    return pow(a * max(x + b, vec3(0.0)), vec3(2.4));
}

float sdr_linear(const float x)
{
    return x < 0.018 ? x / 4.5 : pow((x + 0.099) / 1.099, 1.0 / 0.45);
}

vec3 sdr_linear(const vec3 x)
{
    return vec3(lessThanEqual(x, vec3(0.018))) * (x / 4.5)
        + vec3(greaterThan(x, vec3(0.018))) * pow((x + 0.099) / 1.099, vec3(1.0 / 0.45));
}

float sdr_gamma(const float x)
{
    return x < 0.018 ? 4.5 * x : 1.099 * pow(x, 0.45) - 0.099;
}

vec3 sdr_gamma(const vec3 x)
{
    return vec3(lessThanEqual(x, vec3(0.018))) * (4.5 * x)
        + vec3(greaterThan(x, vec3(0.018))) * (1.099 * pow(x, vec3(0.45)) - 0.099);
}

// DCI-P3 also uses sRGB's gamma functions.
float srgb_linear(const float x)
{
    return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4);
}

vec3 srgb_linear(const vec3 x)
{
    return vec3(lessThanEqual(x, vec3(0.04045))) * (x / 12.92)
        + vec3(greaterThan(x, vec3(0.04045))) * pow((x + 0.055) / 1.055, vec3(2.4));
}

float srgb_gamma(const float x)
{
    return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1.0 / 2.4) - 0.055;
}

vec3 srgb_gamma(const vec3 x)
{
    return vec3(lessThanEqual(x, vec3(0.0031308))) * (12.92 * x)
        + vec3(greaterThan(x, vec3(0.0031308))) * (1.055 * pow(x, vec3(1.0 / 2.4)) - 0.055);
}

float adobe_linear(const float x)
{
    return pow(x, 563.0 / 256.0);
}

vec3 adobe_linear(const vec3 x)
{
    return pow(x, vec3(563.0 / 256.0));
}

float adobe_gamma(const float x)
{
    return pow(x, 256.0 / 563.0);
}

vec3 adobe_gamma(const vec3 x)
{
    return pow(x, vec3(256.0 / 563.0));
}

// Hash helpers (integer-based to avoid trig cost)
uint hash_u32(uint x)
{
    x ^= x >> 17; x *= 0xED5AD4BBu;
    x ^= x >> 11; x *= 0xAC4C1B51u;
    x ^= x >> 15; x *= 0x31848BABu;
    x ^= x >> 14; return x;
}

float hash_float(uvec2 v)
{
    return float(hash_u32(v.x * 0x9E3779B9u ^ v.y)) * (1.0 / 4294967295.0);
}

// Box-Muller from two uniforms
vec2 box_muller(vec2 u)
{
    u = max(u, vec2(1e-6));
    float r = sqrt(-2.0 * log(u.x));
    float th = 6.28318530718 * u.y; // 2π
    return vec2(r * cos(th), r * sin(th));
}

// Triangular PDF dither noise in [-0.5, 0.5], seeded by integer pixel and frame.
// This reduces residual patterning versus single-uniform noise at equivalent LSB amplitude.
float tpdf_noise(vec2 coord, uint frame)
{
    uvec2 p = uvec2(ivec2(floor(coord)));
    uint t = hash_u32(frame ^ 0x6D2B79F5u);

    // Two uncorrelated hashes for the same pixel and frame
    uint h1 = hash_u32((p.x * 0x9E3779B9u) ^ (p.y * 0x85EBCA6Bu) ^ t ^ 0xA511E9B3u);
    uint h2 = hash_u32((p.x * 0xC2B2AE35u) ^ (p.y * 0x27D4EB2Fu) ^ t ^ 0x165667B1u);

    float u1 = float(h1) * (1.0 / 4294967295.0);
    float u2 = float(h2) * (1.0 / 4294967295.0);
    return 0.5 * (u1 - u2);
}

// Blue-noise-like TPDF dither in [-0.5, 0.5], seeded by integer pixel and frame.
// Uses a simple XY+time high-pass filter against left, upper, and previous-frame
// neighbors, with clamped borders to avoid unsigned wraparound at image/frame edges.
// This is a lightweight approximation, not a true optimized blue-noise sequence.
float tpdf_blue_noise(vec2 coord, uint frame)
{
    uvec2 p = uvec2(ivec2(floor(coord)));
    uvec2 pL = uvec2((p.x > 0u) ? (p.x - 1u) : 0u, p.y); // Left pixel (clamped)
    uvec2 pU = uvec2(p.x, (p.y > 0u) ? (p.y - 1u) : 0u); // Upper pixel (clamped)

    uint f0 = frame;
    uint f1 = (frame > 0u) ? (frame - 1u) : 0u; // Previous frame (clamped)
    uint t0 = hash_u32(f0 ^ 0x6D2B79F5u);
    uint t1 = hash_u32(f1 ^ 0x6D2B79F5u);

    // Correlated hashes for XY+time high-pass noise.
    uint h  = hash_u32((p.x  * 0x9E3779B9u) ^ (p.y  * 0x85EBCA6Bu) ^ t0 ^ 0xA511E9B3u);
    uint hL = hash_u32((pL.x * 0x9E3779B9u) ^ (pL.y * 0x85EBCA6Bu) ^ t0 ^ 0xA511E9B3u);
    uint hU = hash_u32((pU.x * 0x9E3779B9u) ^ (pU.y * 0x85EBCA6Bu) ^ t0 ^ 0xA511E9B3u);
    uint hT = hash_u32((p.x  * 0x9E3779B9u) ^ (p.y  * 0x85EBCA6Bu) ^ t1 ^ 0xA511E9B3u);

    float u  = float(h)  * (1.0 / 4294967295.0);
    float uL = float(hL) * (1.0 / 4294967295.0);
    float uU = float(hU) * (1.0 / 4294967295.0);
    float uT = float(hT) * (1.0 / 4294967295.0);

    // High-pass against spatial+temporal neighborhood with 3D parity (x+y+frame).
    float d = u - (uL + uU + uT) * (1.0 / 3.0);
    bool even = (((p.x + p.y + f0) & 1u) == 0u);
    return 0.5 * (even ? d : -d);
}

// Blue-noise-like TPDF dither in [-0.5, 0.5], seeded by integer pixel and frame.
// Uses a simple 1D high-pass filter against the left neighbor only, with a clamped
// left border to avoid unsigned wraparound at the image edge.
float tpdf_blue_noise_1x(vec2 coord, uint frame)
{
    uvec2 p = uvec2(ivec2(floor(coord)));
    uvec2 pL = uvec2((p.x > 0u) ? (p.x - 1u) : 0u, p.y); // Left pixel (clamped)
    uint t = hash_u32(frame ^ 0x6D2B79F5u);

    uint h  = hash_u32((p.x  * 0x9E3779B9u) ^ (p.y  * 0x85EBCA6Bu) ^ t ^ 0xA511E9B3u);
    uint hL = hash_u32((pL.x * 0x9E3779B9u) ^ (pL.y * 0x85EBCA6Bu) ^ t ^ 0xA511E9B3u);

    float u  = float(h)  * (1.0 / 4294967295.0);
    float uL = float(hL) * (1.0 / 4294967295.0);

    float d = u - uL;
    bool even = ((p.x & 1u) == 0u);
    return 0.5 * (even ? d : -d);
}
