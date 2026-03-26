#version 450

// Filename: famicom-special.slang
//
// Copyright (C) 2026 W. M. Martinez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// Outputs a Famicom video output waveform

#pragma name FamicomSpecial
#pragma format R16_SFLOAT

#include "common.inc"
#include "modulation.inc"

#include "menus/parameters/sys-timing.inc"
#include "menus/parameters/famicom.inc"

layout(push_constant) uniform Push
{
    vec4 OriginalSize;
    vec4 OutputSize;
    vec4 FrameHSize;
    float OriginalFPS;
    uint FrameCount;
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

#define PAL config.PAL

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float h_scale;
layout(location = 2) out CarrierPhaseConfig carrier;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    TimebaseConfig tb = compute_timebase(
        config.FrameCount,
        TexCoord,
        config.OriginalSize.xy,
        config.OutputSize.xy,
        config.FrameHSize.x,
        config.OriginalFPS,
        config.SC_FREQ_MODE,
        config.SC_FREQ,
        config.PIXEL_CLOCK,
        config.PIXEL_CLOCK_MODE,
        config.H_FREQ_MODE,
        config.H_FREQ,
        config.V_FREQ_MODE,
        config.V_FREQ,
        config.H_BLANK_FUZZ,
        config.SHORTEN_ODD_FIELD_TIME);
    carrier = extract_carrier_phase(tb);

    compute_scale_factors(
        config.FrameHSize.x,
        config.OutputSize.x,
        config.OutputSize.y,
        tb.h_pixels,
        tb.v_lines_per_field,
        h_scale);
}

#pragma stage fragment

// IRE table
struct FamicomIRE {
    float sync;
    float burst_low;
    float burst_high;
    float x0d;
    float x1d;
    float x2d;
    float x3d;
    float x00;
    float x10;
    float x20;
    float x30;
    float x0d_emph;
    float x1d_emph;
    float x2d_emph;
    float x3d_emph;
    float x00_emph;
    float x10_emph;
    float x20_emph;
    float x30_emph;
};

const FamicomIRE IRE_TABLE = FamicomIRE(
    -37.0, // sync
    -23.0, // burst low
    30.0,  // burst high
    -12.0, // x0d
    0.0,   // x1d
    34.0,  // x2d
    80.0,  // x3d
    43.0,  // x00
    74.0,  // x10
    110.0, // x20
    110.0, // x30
    -17.0, // x0d emph
    -8.0,  // x1d emph
    19.0,  // x2d emph
    56.0,  // x3d emph
    26.0,  // x00 emph
    51.0,  // x10 emph
    82.0,  // x20 emph
    82.0   // x30 emph
);

const vec4 IRE_LOW_TABLE[] = vec4[](
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x1d, IRE_TABLE.x1d, IRE_TABLE.x1d, IRE_TABLE.x1d),
    vec4(IRE_TABLE.x1d, IRE_TABLE.x1d, IRE_TABLE.x1d, IRE_TABLE.x1d)
);

const vec4 IRE_HIGH_TABLE[] = vec4[](
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x00, IRE_TABLE.x10, IRE_TABLE.x20, IRE_TABLE.x30),
    vec4(IRE_TABLE.x0d, IRE_TABLE.x1d, IRE_TABLE.x2d, IRE_TABLE.x3d),
    vec4(IRE_TABLE.x1d, IRE_TABLE.x1d, IRE_TABLE.x1d, IRE_TABLE.x1d),
    vec4(IRE_TABLE.x1d, IRE_TABLE.x1d, IRE_TABLE.x1d, IRE_TABLE.x1d)
);

const vec4 IRE_LOW_TABLE_EMPH[] = vec4[](
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph),
    vec4(IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph)
);

const vec4 IRE_HIGH_TABLE_EMPH[] = vec4[](
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x00_emph, IRE_TABLE.x10_emph, IRE_TABLE.x20_emph, IRE_TABLE.x30_emph),
    vec4(IRE_TABLE.x0d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x2d_emph, IRE_TABLE.x3d_emph),
    vec4(IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph),
    vec4(IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph, IRE_TABLE.x1d_emph)
);

const float FAMICOM_PHASE_OFFSET_CYCLES_NTSC = -60.0 / 360.0;
const float FAMICOM_PHASE_OFFSET_CYCLES_PAL = -75.0 / 360.0;

bool phase_gate_high(const int color_phase, const int phase_index)
{
    return int(mod(float(color_phase + phase_index), 12.0)) < 6;
}

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float h_scale;
layout(location = 2) in CarrierPhaseConfig carrier;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Skip padding: output pixel must fall within centered active area.
    // Active width = OriginalSize.x * h_scale = 256 * 8 = 2048 pixels.
    // Centering is dynamic from OutputSize.x:
    //   active_left  = (OutputSize.x - active_width) / 2
    //   active_right = active_left + active_width
    // Examples:
    //   OutputSize.x = 2728 -> [340, 2388)
    //   OutputSize.x = 3410 -> [425, 2473)
    float output_x = vTexCoord.x * config.OutputSize.x;
    float active_width = config.OriginalSize.x * h_scale;
    float active_left = (config.OutputSize.x - active_width) * 0.5;
    float active_right = active_left + active_width;
    if (output_x < active_left || output_x >= active_right) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3 rgb = texture(Source, vTexCoord).rgb;

    // Extract the chroma, level, and emphasis from the normalized RGB triplet
    int color = int(floor((rgb.r * 15.0) + 0.5));
    int level = int(floor((rgb.g * 3.0) + 0.5));
    int emphasis = int(floor((rgb.b * 7.0) + 0.5));

    // Reconstruct the raw video waveform from the color, level, and emphasis values
    // Get voltage high and voltage low for the current color
    int color_index = clamp(color, 0, 15);
    int level_index = clamp(level, 0, 3);
    float voltage_low = IRE_LOW_TABLE[color_index][level_index] / 100.0;
    float voltage_high = IRE_HIGH_TABLE[color_index][level_index] / 100.0;
    float voltage_low_emph = IRE_LOW_TABLE_EMPH[color_index][level_index] / 100.0;
    float voltage_high_emph = IRE_HIGH_TABLE_EMPH[color_index][level_index] / 100.0;

    vec2 UV = vTexCoord * config.OutputSize.xy;
    float line = floor(UV.y);
    float base_center = floor(UV.x) + 0.5;

    // Build phase in fractional-cycle domain to avoid precision drift from sc_freq * t0.
    float cycles_per_pixel = fract(carrier.sc_freq_hz * carrier.pixel_time_px);
    float cycles_per_line = fract(carrier.sc_freq_hz / carrier.h_freq_hz);
    float field_cycles = fract(carrier.field_phase / (2.0 * PI));
    float phase_offset_cycles = mix(FAMICOM_PHASE_OFFSET_CYCLES_NTSC, FAMICOM_PHASE_OFFSET_CYCLES_PAL, PAL);
    float base_phase_cycles = fract(
        base_center * cycles_per_pixel
        + line * cycles_per_line
        + field_cycles
        + phase_offset_cycles);
    float pal_v_sign = 1.0 - 2.0 * floor(mod(line, 2.0)) * PAL;
    float phase_cycles = fract(base_phase_cycles * pal_v_sign);
    int phase_index = int(mod(floor(12.0 * phase_cycles + 1e-4), 12.0));
    int wave_phase = int(mod(float(color + phase_index), 12.0));

    // NES emphasis bits gate one shared attenuator by carrier phase:
    // bit0 -> phase C, bit1 -> phase 4, bit2 -> phase 8.
    // Colors E/F are not affected.
    bool emph_active = false;
    if (color < 14) {
        emph_active =
            (((emphasis & 0x1) != 0) && phase_gate_high(0xC, phase_index)) ||
            (((emphasis & 0x2) != 0) && phase_gate_high(0x4, phase_index)) ||
            (((emphasis & 0x4) != 0) && phase_gate_high(0x8, phase_index));
    }

    if (emph_active) {
        voltage_low = voltage_low_emph;
        voltage_high = voltage_high_emph;
    }

    // NES color gate: high when (color phase + sample phase) wraps into first half-cycle
    float voltage = (wave_phase < 6) ? voltage_high : voltage_low;

    // Shift voltage amount to match real-world contrast better
    //voltage = (voltage - 0.075) / 0.925;

    FragColor = vec4(voltage, 0.0, 0.0, 1.0);
}
