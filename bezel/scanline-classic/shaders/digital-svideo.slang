#version 450

// Filename: digital-svideo.slang
//
// Copyright (C) 2026 W. M. Martinez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// Digital composite modulation: YCbCr → composite baseband (digital)
// -------------------------------------------------------------------
// Input: YCbCr video (Y in R, Cb in G, Cr in B)
// Output: YC (Y in R, modulated C in G)
//
// Performs digital color subcarrier modulation using explicit phase
// accumulation per pixel. Supports NTSC (227.5 cycles/line) and
// PAL (283.75 cycles/line) standards.
//
// Simplified: no timebase struct, no encoder setup pedestal. PAL
// alternation inferred from subcarrier frequency (PAL if > 4 MHz).

#include "common.inc"
#include "digital.inc"
#include "modulation.inc"

#include "menus/parameters/digital-component.inc"
#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/sys-encode.inc"

#pragma name DigitalCompositeMod
#pragma format A2B10G10R10_UNORM_PACK32

#pragma parameter DIGITAL_COMPOSITE_MOD_BYPASS "Bypass digital composite mod" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameSize;
    float OriginalFPS;
    uint FrameCount;
    float DIGITAL_COMPOSITE_MOD_BYPASS;
    float WORKING_BITS;
    float SC_FREQ_MODE;
    float SC_FREQ;
    float PIXEL_CLOCK_MODE;
    float PIXEL_CLOCK;
    float H_FREQ_MODE;
    float H_FREQ;
    float V_FREQ_MODE;
    float V_FREQ;
    float H_BLANK_FUZZ;
    float SHORTEN_ODD_FIELD_TIME;
    float PAL;
} config;

#define DIGITAL_COMPOSITE_MOD_BYPASS config.DIGITAL_COMPOSITE_MOD_BYPASS
#define WORKING_BITS config.WORKING_BITS
#define SC_FREQ_MODE config.SC_FREQ_MODE
#define SC_FREQ config.SC_FREQ
#define PIXEL_CLOCK_MODE config.PIXEL_CLOCK_MODE
#define PIXEL_CLOCK config.PIXEL_CLOCK
#define H_FREQ_MODE config.H_FREQ_MODE
#define H_FREQ config.H_FREQ
#define V_FREQ_MODE config.V_FREQ_MODE
#define V_FREQ config.V_FREQ
#define H_BLANK_FUZZ config.H_BLANK_FUZZ
#define SHORTEN_ODD_FIELD_TIME config.SHORTEN_ODD_FIELD_TIME
#define PAL config.PAL

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float base_cycles;
layout(location = 2) out float cycles_per_pixel;
layout(location = 3) out float cycles_per_line;
layout(location = 4) out float field_phase_offset;
layout(location = 5) out float pixels_per_line;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    // Use shared timebase to derive carrier phase parameters consistently
    TimebaseConfig tb_full = compute_timebase(
        config.FrameCount,
        TexCoord,
        config.OriginalSize.xy,
        config.OutputSize.xy,
        config.FrameSize.xy,
        config.OriginalFPS,
        SC_FREQ_MODE,
        SC_FREQ,
        PIXEL_CLOCK,
        PIXEL_CLOCK_MODE,
        H_FREQ_MODE,
        H_FREQ,
        V_FREQ_MODE,
        V_FREQ,
        H_BLANK_FUZZ,
        SHORTEN_ODD_FIELD_TIME);

    CarrierPhaseConfig tb = extract_carrier_phase(tb_full);

    // Derive within-field time (matching display-svideo decoder)
    // Do not include field progression; that's handled via field_phase
    float field_time = tb_full.v_lines_per_field / tb.h_freq_hz;
    float t00 = 0.5 * tb.pixel_time_px;

    // Precompute fractional cycle at top-left pixel center within field
    base_cycles = 0.0;
    cycles_per_pixel = tb.sc_freq_hz * tb.pixel_time_px;
    cycles_per_line = tb.sc_freq_hz / tb.h_freq_hz;

    field_phase_offset = tb.field_phase;
    pixels_per_line = tb.pixels_per_line;
}

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float base_cycles;
layout(location = 2) in float cycles_per_pixel;
layout(location = 3) in float cycles_per_line;
layout(location = 4) in float field_phase_offset;
layout(location = 5) in float pixels_per_line;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    if (DIGITAL_COMPOSITE_MOD_BYPASS > 0.5) {
        FragColor = texture(Source, vTexCoord);
        return;
    }

    // Pixel and line positions
    vec2 UV = vTexCoord * config.OutputSize.xy;
    float pixel_x = floor(UV.x) + 0.5;  // Use pixel center for phase alignment with decoder
    float line = floor(UV.y) / pixels_per_line;

    // Sample input YCbCr using scaled pixel coordinate
    vec3 ycbcr = texture(Source, vTexCoord).rgb;

    // Restore full-range YCbCr from limited range
    ycbcr = unlimit_ycbcr(ycbcr, int(WORKING_BITS));

    // Phase via discrete carrier helper using within-field t00 plus field_phase offset
    float phase = compute_carrier_phase_discrete(
        base_cycles,
        cycles_per_pixel,
        cycles_per_line,
        pixel_x,
        line,
        field_phase_offset);

    // Carrier and PAL V-axis alternation
    vec2 carrier = sincos_phase_raw(phase);
    float pal_sign = 1.0 - 2.0 * floor(mod(line, 2.0)) * PAL;

    // Modulate Cb/Cr onto subcarrier (Cb→sin, Cr→cos with PAL alternation)
    float chroma = ycbcr.g * carrier.x + pal_sign * ycbcr.b * carrier.y;

    // Scale for worst-case peak (sqrt(2) * 0.5 ≈ 0.707) and offset to UNORM [0, 1]
    // Peak occurs when Cb and Cr are both ±0.5 and aligned with carrier phase
    const float INV_SQRT2 = 0.70710678;
    chroma = chroma * INV_SQRT2 + 0.5;

    // Quantize to working bit depth
    int bits = int(WORKING_BITS + 0.5);

    // Quantize to working bit depth (6, 8, or 10 bits)
    float luma = ycbcr.r;
    if (bits == 6) {
        luma = quantize_6bit(luma);
        chroma = quantize_6bit(chroma);
    } else if (bits == 8) {
        luma = quantize_8bit(luma);
        chroma = quantize_8bit(chroma);
    } else if (bits == 10) {
        luma = quantize_10bit(luma);
        chroma = quantize_10bit(chroma);
    } else {
        luma = quantize(luma, bits);
        chroma = quantize(chroma, bits);
    }

    FragColor = vec4(luma, chroma, 0.0, 1.0);
}