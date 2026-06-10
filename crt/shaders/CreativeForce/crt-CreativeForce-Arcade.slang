#version 450

/*
Author: djayjp aka CreativeForce (2026)
Modified: sharpening removed; gamma controls replaced by GBA Mode Gamma toggle.

This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

// Gamma mode: 0 = default 2.20 source gamma, 1 = GBA-style 2.70 source gamma.
#pragma parameter GBA_MODE_GAMMA     "GBA Mode Gamma"                       0.00 0.00 1.00 1.00

// Vertical controls
#pragma parameter V_BLACKS_PER       "Vertical Lines"                       2.00 0.00 5.00 1.00
#pragma parameter V_STRENGTH         "Vertical Lines Strength"              1.00 0.00 1.00 0.01
#pragma parameter V_PHASE            "Vertical Phase"                       0.00 -256.00 256.00 1.00

// Auto-phase (placed last)
#pragma parameter AUTO_PHASE         "Auto-Phase (lock to active content)"   1.00 0.00 1.00 1.00

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;

    float GBA_MODE_GAMMA;

    float V_BLACKS_PER;
    float V_STRENGTH;
    float V_PHASE;

    float AUTO_PHASE;
} pc;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

// ===== Vertex =====
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord   = TexCoord;
}

// ===== Fragment =====
#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Utils
vec3 to_linear(vec3 c, float g){ return pow(max(c, vec3(0.0)), vec3(g)); }
vec3 to_gamma (vec3 c, float g){ return pow(max(c, vec3(0.0)), vec3(1.0/g)); }

int ifloor(float x){ return int(floor(x)); }

float line_mask_int(float axis_px, float phase_px, int period_i, int thick_i, float strength){
    if (period_i < 1) period_i = 1;
    if (thick_i < 0) thick_i = 0;
    if (thick_i > period_i) thick_i = period_i;
    int idx = int(floor(axis_px)) + int(floor(phase_px + 0.5));
    int j = idx % period_i; if (j < 0) j += period_i;
    float in_dark = (j < thick_i) ? 1.0 : 0.0; // dark-first parity inside mask core
    float k = clamp(strength, 0.0, 1.0);
    return mix(1.0, 1.0 - k, in_dark);
}

void main(){
    vec3 col = texture(Source, vTexCoord).rgb;

    // Blacks-per-period -> (period, thickness)
    int v_blacks = int(floor(pc.V_BLACKS_PER + 0.5));
    v_blacks = clamp(v_blacks, 0, 17);
    int v_period = v_blacks + 1;
    int v_thick  = v_blacks;

    // Fixed gamma pipeline.
    // Default assumes source gamma 2.20. GBA Mode uses source gamma 2.70.
    // Output is encoded for a fixed 2.20 monitor/output gamma.
    float g_src = (pc.GBA_MODE_GAMMA >= 0.5) ? 2.70 : 2.20;
    const float g_out = 2.20;
    vec3 col_lin = to_linear(col, g_src);

    // Phase (integer-aligned)
    int v_phase_i = int(floor(pc.V_PHASE + 0.5));

    // Auto-phase to active content (axis-specific integer scales) with hardcoded LIT-FIRST bias (+1)
    if (pc.AUTO_PHASE >= 0.5) {
        int Sx = ifloor(pc.OutputSize.x / pc.OriginalSize.x + 1e-6);
        if (Sx < 1) Sx = 1;
        int active_w = int(pc.OriginalSize.x) * Sx;
        int left_border = (int(pc.OutputSize.x) - active_w) / 2;
        if (v_thick > 0 && v_period > 0) {
            int lbm = left_border % v_period; if (lbm < 0) lbm += v_period;
            v_phase_i += -lbm + 1; // lit-first parity
        }
    }

    // Vertical mask
    float mask_val = 1.0;
    if (v_thick > 0) {
        float axis_px = gl_FragCoord.x - 0.5;
        mask_val *= line_mask_int(axis_px, float(v_phase_i), v_period, v_thick, pc.V_STRENGTH);
    }

    // Apply mask
    vec3 masked_lin = col_lin * vec3(mask_val);

    vec3 out_col = to_gamma(masked_lin, g_out);
    FragColor = vec4(out_col, 1.0);
}
