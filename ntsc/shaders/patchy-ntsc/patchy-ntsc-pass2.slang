#version 450

/*
Patchy NTSC
Copyright (C) 2024 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

// This pass filters the luma signal and adds the chroma signal to get the composite signal.

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    vec4 FinalViewportSize;
} params;

// Includes constants, global, and all parameters
#include "patchy-ntsc-inc-params.inc"

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
layout(set = 0, binding = 2) uniform sampler2D Source;

// Includes lowpass and bandpass functions
#include "patchy-ntsc-inc-filters.inc"

void main()
{
    if(global.pn_nes_enable > 0.5) {
        FragColor = texture(Source, vTexCoord);
    } else {
        float composite = 0.0;
        
        // Filter luma before combining with chroma.
        composite += lowpassPickable(global.pn_modulator_luma_filter_type,
            global.pn_modulator_luma_filter_width, global.pn_modulator_luma_filter_level,
            global.pn_modulator_luma_sigma, global.pn_modulator_luma_radius,
            global.pn_modulator_luma_res,
        global.pn_modulator_luma_eq_f_lo, global.pn_modulator_luma_eq_f_hi,
        global.pn_modulator_luma_eq_g_lo, global.pn_modulator_luma_eq_g_mid, global.pn_modulator_luma_eq_g_hi,
            global.pn_modulator_luma_eq_dist, global.pn_modulator_luma_eq_off).r;
        
        composite += bandpassPickable(global.pn_modulator_chroma_filter_type,
            global.pn_modulator_chroma_filter_width, global.pn_modulator_chroma_filter_level, global.pn_modulator_chroma_filter_level_diff,
            global.pn_modulator_chroma_eq_f_lo, global.pn_modulator_chroma_eq_f_hi,
            global.pn_modulator_chroma_eq_g_lo, global.pn_modulator_chroma_eq_g_mid, global.pn_modulator_chroma_eq_g_hi,
            global.pn_modulator_chroma_eq_dist, global.pn_modulator_chroma_eq_off, 1 // 1 means chroma is in the G channel of the vector
        ).g;
        
        if(global.pn_genesis_jailbar_enable > 0.5) {
            // Compensate for cropped overscan, assuming equal crop on both sides.
            // Current position in pixels, both x and y being decimal numbers.
            vec2 pixelCoord = realPixelCoord();
            
            // This is not to be confused with the rainbow banding effect seen elsewhere on the Genesis, such as in the waterfall in Sonic 1.
            // I don't even know what actually is causing the jailbars on the Model 1 Genesis, but this looks about right.
            // From what I've read, these jailbars are largely missing on the Genesis model 1 VA6 revision onward, and it can be fixed on earlier model 1s by adjusting the capacitors.
            // 0.0075 matched by eye, not precise.
            composite += 0.0075 * global.pn_genesis_jailbar_amplitude * -cos(pi * pixelCoord.x + 2 * pi * global.pn_genesis_jailbar_offset);
        }
        
        FragColor = vec4(composite, 0, 0, 1);
    }
}

