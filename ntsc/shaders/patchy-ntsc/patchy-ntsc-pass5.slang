#version 450

/*
Patchy NTSC
Copyright (C) 2024 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

// This pass performs two steps: (Optionally) smear over the bright colors, then linearize the final RGB to prepare for a gamut fix.
// This pass optionally makes bright colors smear over because they aren't being clamped low enough.
// I'm no expert, but my assumption is that this happens when a CRT has weakened after being used for a very long time.
// CRTs that are working properly don't have this problem. Even my 1989 RCA Colortrak doesn't have this problem at all.

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

// Includes sRGB_to_linear
#include "../../../../shaders_slang/include/colorspace-tools.h"

// CRT EOTF Function
// Taken from Grade
//----------------------------------------------------------------------

#define CRT_l           -(100000.*log((72981.-500000./(3.*max(2.3,global.pn_g_CRT_l)))/9058.))/945461.

float EOTF_1886a(float color, float bl, float brightness, float contrast) {

    // Defaults:
    //  Black Level = 0.1
    //  Brightness  = 0
    //  Contrast    = 100

    const float wl = 100.0;
          float b  = pow(bl, 1./2.4);
          float a  = pow(wl, 1./2.4)-b;
//                b  = (brightness-50.) / 250. + b/a;                   // -0.20 to +0.20
                b  = (brightness * 100.) / 250. + b/a;                   // -0.20 to +0.20
                //a  = contrast!=50. ? pow(2.,(contrast-50.)/50.) : 1.; //  0.50 to +2.00
                a = contrast;

    const float Vc = 0.35;                           // Offset
          float Lw = wl/100. * a;                    // White level
          float Lb = min( b  * a,Vc);                // Black level
    const float a1 = 2.6;                            // Shoulder gamma
    const float a2 = 3.0;                            // Knee gamma
          float k  = Lw /pow(1. + Lb,    a1);
          float sl = k * pow(Vc + Lb, a1-a2);        // Slope for knee gamma

    color = color >= Vc ? k * pow(color + Lb, a1 ) : sl * pow(color + Lb, a2 );

    // Black lift compensation
    float bc = 0.00446395*pow(bl,1.23486);
    color    = min(max(color-bc,0.0)*(1.0/(1.0-bc)), 1.0);  // Undo Lift
    color    = pow(color,1.0-0.00843283*pow(bl,1.22744));   // Restore Gamma from 'Undo Lift'

    return color;
 }

vec3 EOTF_1886a_f3( vec3 color, float BlackLevel, float brightness, float contrast) {

    color.r = EOTF_1886a( color.r, BlackLevel, brightness, contrast);
    color.g = EOTF_1886a( color.g, BlackLevel, brightness, contrast);
    color.b = EOTF_1886a( color.b, BlackLevel, brightness, contrast);
    return color.rgb;
}

float EOTF_1886a_default(float color, float brightness, float contrast) {
    // From Rec. ITU-R BT.1886
    float Vc = 0.35, // Vc, a1, and a2 are directly from the paper
          a1 = 2.6,
          a2 = 3.0,
          Lw = contrast;
    
    float V = color,
          b = brightness, // The paper recommends about either 0 or 0.1.
          k = Lw / pow(1.0 + b, a1);
    
    if(V < Vc) {
        return k * pow(Vc + b, a1 - a2) * pow(V + b, a2);
    } else {
        return k * pow(V + b, a1);
    }
}
 
vec3 EOTF_1886a_default_f3(vec3 color, float brightness, float contrast) {
    color.r = EOTF_1886a_default(color.r, brightness, contrast);
    color.g = EOTF_1886a_default(color.g, brightness, contrast);
    color.b = EOTF_1886a_default(color.b, brightness, contrast);
    return color;
}

void main()
{
    vec3 rgb;
    // Before this pass, all RGB values are clamped under global.pn_rgb_smear_rate.
    // If that value is 1.0, then there will be no smearing, so this entire pass can be skipped.
    if(global.pn_rgb_smear_enable < 0.5) {
        rgb = texture(Source, vTexCoord).rgb;
    } else {
        vec3 col = vec3(0);
        vec3 maxes = vec3(global.pn_rgb_smear_rate); // If a value goes over this, it'll smear.
        
        float i = max(0.0, vTexCoord.x - floor(params.OutputSize.x * global.pn_rgb_smear_limit / 100.0) * params.OutputSize.z);
        while(i < vTexCoord.x - 0.5 * params.OutputSize.z) {
            col = max(col + texture(Source, vec2(i, vTexCoord.y)).rgb - maxes, vec3(0));
            i += max(params.OutputSize.z * SIGNAL_RES / pow(2, global.pn_rgb_smear_res), params.OutputSize.z);
        }
        
        col += texture(Source, vTexCoord).rgb;
        col = min(col, maxes);
        
        rgb = min(col, 1);
    }
    
    rgb /= global.pn_knob_contrast;
    
    if(global.pn_gamma_type < 0.5) {
        FragColor = vec4(EOTF_1886a_f3(rgb, CRT_l, global.pn_knob_brightness, global.pn_knob_contrast), 1.0);
    } else if(global.pn_gamma_type < 1.5) {
        FragColor = vec4(clamp(EOTF_1886a_default_f3(rgb, global.pn_knob_brightness, global.pn_knob_contrast), 0, 1), 1.0);
    } else if(global.pn_gamma_type < 2.5) {
        rgb = max(rgb * (1.0 - global.pn_knob_brightness) + global.pn_knob_brightness, 0);
        rgb *= pow(global.pn_knob_contrast, 1.0 / global.pn_power_gamma);
        FragColor = vec4(pow(min(rgb, vec3(1)), vec3(global.pn_power_gamma)), 1.0);
    } else {
        // The different values 2.2 and 2.4 are not a mistake.
        rgb = max(rgb * (1.0 - global.pn_knob_brightness) + global.pn_knob_brightness, 0);
        rgb *= global.pn_knob_contrast <= 1.0 ? linear_to_sRGB(vec3(global.pn_knob_contrast), 2.4).r : pow(global.pn_knob_contrast, 1.0 / 2.2);
        FragColor = vec4(sRGB_to_linear(rgb, 2.4), 1.0);
    }
}

