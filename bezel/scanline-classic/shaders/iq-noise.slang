#version 450

// Filename: iq-noise.slang
//
// Noise post-processing pass for IQ baseband.
// Consumes filtered analytic IQ (R=I, G=Q) and injects noise effects.
// Modes:
//  - Fast: lightweight AWGN (Gaussian) per pixel.
//  - Advanced: band-limited AWGN + optional ghost, impulse, phase jitter.
// Output: R16G16_SFLOAT (no alpha usage).

#include "common.inc"
#include "window.inc"

#include "menus/parameters/rf.inc"

#pragma name IQNoise
#pragma format R16G16_SFLOAT

#pragma parameter BYPASS_NOISE "Bypass noise (off,on)" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OriginalFPS;
    float BYPASS_NOISE;
    float NOISE_MODE;
    float NOISE_AWGN_DB;
    float NOISE_PHASE_JITTER_DEG;
    float NOISE_GHOST1_DB;
    float NOISE_GHOST1_PIX;
    float NOISE_IMPULSE_RATE;
    float NOISE_IMPULSE_DB;
} config;

#define BYPASS_NOISE            config.BYPASS_NOISE
#define NOISE_MODE              config.NOISE_MODE
#define NOISE_AWGN_DB           config.NOISE_AWGN_DB
#define NOISE_PHASE_JITTER_DEG  config.NOISE_PHASE_JITTER_DEG
#define NOISE_GHOST1_DB         config.NOISE_GHOST1_DB
#define NOISE_GHOST1_PIX        config.NOISE_GHOST1_PIX
#define NOISE_IMPULSE_RATE      config.NOISE_IMPULSE_RATE
#define NOISE_IMPULSE_DB        config.NOISE_IMPULSE_DB

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

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

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source; // Input IQ

void main()
{
    vec2 iq = texture(Source, vTexCoord).rg;
    if (BYPASS_NOISE > 0.5) {
        FragColor = vec4(iq, 0.0, 1.0);
        return;
    }

    // Base AWGN amplitude (linear)
    float awgn_amp = exp(NOISE_AWGN_DB * 0.1151292546); // ln(10)/20

    // Coordinate hashing
    ivec2 icoord = ivec2(floor(vTexCoord * config.OutputSize.xy));
    uint frame = config.FrameCount;
    vec2 u1 = vec2(hash_float(uvec2(icoord.x ^ frame, icoord.y)), hash_float(uvec2(icoord.x + 13u ^ frame, icoord.y + 7u)));
    vec2 gauss = box_muller(u1);

    vec2 noise_fast = gauss * awgn_amp; // Fast mode direct AWGN

    // Advanced mode components
    vec2 noise_adv = noise_fast;
    if (NOISE_MODE > 0.5) {
        // Simple horizontal band-limit (3-tap smoothing)
        vec2 off = vec2(config.OutputSize.z, 0.0);
        vec2 iq_l = texture(Source, vTexCoord - off).rg;
        vec2 iq_r = texture(Source, vTexCoord + off).rg;
        // Re-hash neighbors for decorrelated AWGN
        vec2 uL = vec2(hash_float(uvec2((icoord.x-1) ^ frame, icoord.y)), hash_float(uvec2((icoord.x-1) + 23u ^ frame, icoord.y + 3u)));
        vec2 uR = vec2(hash_float(uvec2((icoord.x+1) ^ frame, icoord.y)), hash_float(uvec2((icoord.x+1) + 29u ^ frame, icoord.y + 11u)));
        vec2 gL = box_muller(uL) * awgn_amp;
        vec2 gR = box_muller(uR) * awgn_amp;
        noise_adv = (noise_fast * 0.5 + (gL + gR) * 0.25); // mild smoothing

        // Ghost (single delayed replica)
        float ghost_amp = exp(NOISE_GHOST1_DB * 0.1151292546); // linear
        if (ghost_amp > 0.0 && NOISE_GHOST1_PIX > 0.5) {
            float delay_px = NOISE_GHOST1_PIX;
            vec2 ghost_coord = vTexCoord - vec2(delay_px * config.OutputSize.z, 0.0);
            vec2 ghost_iq = texture(Source, ghost_coord).rg;
            iq += ghost_iq * ghost_amp; // additive ghost path
        }

        // Impulse noise (sparse spikes)
        float impulse_prob = NOISE_IMPULSE_RATE * 1e-6; // ppm to probability
        float hImpulse = hash_float(uvec2(icoord.x * 57u ^ frame, icoord.y * 131u));
        if (hImpulse > 1.0 - impulse_prob) {
            float impulse_amp = exp(NOISE_IMPULSE_DB * 0.1151292546);
            float signv = (hash_float(uvec2(icoord.x * 911u, icoord.y * 353u)) < 0.5) ? -1.0 : 1.0;
            iq += vec2(signv * impulse_amp, signv * impulse_amp * 0.7); // slightly less on Q
        }

        // Phase jitter: rotate IQ by small angle (Gaussian per line)
        float lineSeed = hash_float(uvec2(frame, uint(icoord.y)));
        float jitter_deg = NOISE_PHASE_JITTER_DEG * (lineSeed - 0.5) * 2.0; // approx uniform -> pseudo RMS
        float jitter_rad = jitter_deg * 0.01745329252; // deg to rad
        float c = cos(jitter_rad);
        float s = sin(jitter_rad);
        iq = vec2(c * iq.x - s * iq.y, s * iq.x + c * iq.y);
    }

    // Apply AWGN (fast or advanced built)
    iq += (NOISE_MODE > 0.5 ? noise_adv : noise_fast);

    FragColor = vec4(iq, 0.0, 1.0);
}
