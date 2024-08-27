
/*
Patchy NTSC
Copyright (C) 2024 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

#ifndef __patchy_ntsc_inc_filters_inc__
#define __patchy_ntsc_inc_filters_inc__


#include "patchy-ntsc-inc-params.inc"

///////////////////////
// General functions //
///////////////////////

vec2 realPixelCoord() {
    vec2 pixelCoord = vTexCoord * params.OutputSize.xy / vec2(SIGNAL_RES, 1) + (vec2(global.pn_width_uncropped, global.pn_height_uncropped) - params.OutputSize.xy / vec2(SIGNAL_RES, 1)) / 2;
    pixelCoord.y = floor(pixelCoord.y);
    return pixelCoord;
}

int getPhaseIntNES() {
    vec2 pixelCoord = realPixelCoord();
    return int(0.1 + 8 * pixelCoord.x + 4 * pixelCoord.y + 4 * (int(params.FrameCount + 0.1) % int(2.1 + global.pn_nes_phase_mod)));;
}

float getPhase() {
    if(global.pn_nes_enable > 0.5) {
        int p = getPhaseIntNES();
        return 2 * pi * (p + 3) / 12.0;
    } else {
        vec2 pixelCoord = realPixelCoord();
        float realOffX = pixelCoord.x / global.pn_width_uncropped;
        return 2 * pi * (realOffX * global.pn_scanline_dur * global.pn_color_freq + global.pn_color_init_offset + global.pn_color_line_offset * pixelCoord.y + params.FrameCount * global.pn_color_screen_offset);
    }
}

float getFreqFactor() {
    if(global.pn_nes_enable > 0.5) {
        // https://www.nesdev.org/wiki/NTSC_video as of August 15, 2024
        // Each NES pixel is 186 nanoseconds.
        return 0.186 / 8.0 * 2 * pi;
    } else {
        return global.pn_scanline_dur / global.pn_width_uncropped / SIGNAL_RES * 2 * pi;
    }
}

float getBurstRate() {
    if(global.pn_nes_enable > 0.5) {
        return 2 * pi / 12.0;
    } else {
        return 2 * pi / SIGNAL_RES / global.pn_width_uncropped * global.pn_scanline_dur * global.pn_color_freq;
    }
}

//////////////////////////////////
// Common functions for filters //
//////////////////////////////////

float sinc(float x) {
    if(x == 0.0)
        return 1.0;
    else
        return sin(x) / x;
}

// Hann window, or a Hamming window with a0 = 0.5
// https://en.wikipedia.org/wiki/Window_function
float hamming(int samplePos, int width) {
    return pow(cos(pi * samplePos / width / 2), 2);
}

/////////////////////////////////
// Three band equalizer filter //
/////////////////////////////////

// Three band equalizer filter, directly ported from NTSC-CRT by EMMIR.
// It worked well in NTSC-CRT because that was written in plain C,
// but it is terrible in a shader.
/* f_lo_mhz - low cutoff frequency (MHz)
 * f_hi_mhz - high cutoff frequency (MHz)
 * g_lo, g_mid, g_hi - gains
 */
vec4 filterEQF(float f_lo_mhz, float f_hi_mhz,
                float g_lo, float g_mid, float g_hi,
                int rgbIndex, float maxDistFailsafe, float overallOffset) {

// https://www.nesdev.org/wiki/NTSC_video as of August 15, 2024
// Each NES pixel is 186 nanoseconds.
#define L_FREQ (global.pn_nes_enable > 0.5 ? 8 / 0.186 : SIGNAL_RES * global.pn_width_uncropped / global.pn_scanline_dur)
#define CRT_HRES (global.pn_width_uncropped * SIGNAL_RES)
#define MHz2L(MHz) (CRT_HRES * ((MHz)) / L_FREQ)

#define HISTLEN     7
#define HISTOLD     (HISTLEN - 1) /* oldest entry */
#define HISTNEW     0             /* newest entry */
    
    // struct EQF
    float lf, hf; /* fractions */
    float g[3]; /* gains */
    float fL[4];
    float fH[4];
    float h[HISTLEN]; /* history */
    
//  init_eq(struct EQF *f,
//          int f_lo, int f_hi, int rate,
//          int g_lo, int g_mid, int g_hi)

    float rate = CRT_HRES;
    float f_lo = MHz2L(f_lo_mhz);
    float f_hi = MHz2L(f_hi_mhz);
    
    g[0] = g_lo;
    g[1] = g_mid;
    g[2] = g_hi;
    
    lf = 2 * sin(pi * f_lo / rate);
    hf = 2 * sin(pi * f_hi / rate);
    
    // reset_eq(struct EQF *f)
    
    for(int i = 0; i < HISTLEN; i++)
        h[i] = 0;
    for(int i = 0; i < 4; i++)
        fL[i] = fH[i] = 0;
    
    float r[3];
    
    int maxDistI = int(0.5 + maxDistFailsafe / 100.0 * SIGNAL_RES * global.pn_width_uncropped);
    
    overallOffset /= SIGNAL_RES;
    
    for(int offset = -maxDistI; offset <= 0; offset++) {
        float s = texture(Source, vTexCoord + vec2((offset - overallOffset) * params.OutputSize.z, 0))[rgbIndex];
        
        // eqf(struct EQF *f, int s)
        fL[0] += lf * (s - fL[0]);
        fH[0] += lf * (s - fH[0]);
        
        for(int i = 1; i < 4; i++) {
            fL[i] += lf * (fL[i - 1] - fL[i]);
            fH[i] += lf * (fH[i - 1] - fH[i]);
        }
        
        r[0] = fL[3];
        r[1] = fH[3] - fL[3];
        r[2] = h[HISTOLD] - fH[3];
        
        for(int i = 0; i < 3; i++) {
            r[i] = r[i] * g[i];
        }
        
        for(int i = HISTOLD; i > 0; i--) {
            h[i] = h[i - 1];
        }
        
        h[HISTNEW] = s;
    }
    
    return vec4(r[0] + r[1] + r[2]);

#undef L_FREQ
#undef CRT_HRES
#undef kHz2L

#undef HISTLEN
#undef HISTOLD
#undef HISTNEW
}

///////////////////////
// Lowpass functions //
///////////////////////

// https://www.mathworks.com/help/signal/ug/fir-filter-design.html as of August 9, 2024
// Lowpass using the "Windowing Method" as described on that website.
// I took this idea from artifact-colors, which has a similar lowpass.
vec4 lowpass(float halfWidth, float level) {
    float freqFactor = getFreqFactor();
    float levelFixed = level * freqFactor;
    int halfWidthInt = int(floor(halfWidth * SIGNAL_RES + 0.5)); // Round to nearest integer.
    
    float totalMax = 0.;
    vec4 lowPassed = vec4(0);
    for(int i = -halfWidthInt; i <= halfWidthInt; i++) {
        vec4 samp = texture(Source, vTexCoord + vec2(i * params.OutputSize.z, 0));
        float factor = levelFixed * sinc(levelFixed * i) * hamming(i, halfWidthInt);
        totalMax += factor;
        lowPassed += factor * samp;
    }
    
    return lowPassed / totalMax;
}

vec4 lowpassGaussian(float sigma, float radius) {
    // Copied and pasted from Guest.r's gaussian blur shader
    
    float SIGMA_H = sigma * SIGNAL_RES;
    float SIZEH = radius * SIGNAL_RES; // 2.6 standard deviations = 99%
    float invsqrsigma = 1.0/(2.0*SIGMA_H*SIGMA_H);
    
    float f = fract(params.OutputSize.x * vTexCoord.x);
    f = 0.5 - f;
    vec2 tex = floor(params.OutputSize.xy * vTexCoord)*params.OutputSize.zw + 0.5*params.OutputSize.zw;
    vec4 color = vec4(0.0);
    vec2 dx  = vec2(params.OutputSize.z, 0.0);
    vec4 baseTex = texture(Source, tex);    

    float w;
    float wsum = 0.0;
    vec4 pixel;
    float n = -SIZEH;

    do
    {
	    pixel  = texture(Source, tex + n*dx);
	    w      = exp(-pow(n+f, 2)*invsqrsigma);
	    color  = color + w * pixel;
	    wsum   = wsum + w;
	    n = n + 1.0;
	    
    } while (n <= SIZEH);

    color = color / wsum;
    
    return color;
}

float d(float x, float b)
{
    return (pi*b*min(abs(x)+0.5,1.0/b));
}

float e(float x, float b)
{
    return (pi*b*min(max(abs(x)-0.5,-1.0/b),1.0/b));
}

vec4 lowpassGTU(float signalRes) {
    // Taken from GTU-Famicom by aliaspider
    
    float   offset  = fract((vTexCoord.x * params.OutputSize.x) - 0.5);
    float range = ceil(0.5 + global.pn_width_uncropped * SIGNAL_RES / signalRes);
    float   Y = signalRes / global.pn_width_uncropped / SIGNAL_RES; // Remember to compensate for cropped overscan. The user might or might not be cropping it.
    float X;
    vec4 c;
    vec4 combined = vec4(0);

    float i;
//  for (i=-range;i<range+2.0;i++){
    for (i = 1.0 - range; i < range + 1.0; i += 1)
    {
        X = offset - i;
        c = texture(Source, vec2(vTexCoord.x - X * params.OutputSize.z, vTexCoord.y));
        c *= ((d(X, Y) + sin(d(X, Y)) - e(X, Y) - sin(e(X, Y))) / (2.0 * pi));
        combined += c;
    }
    
    return combined;
}

vec4 twoPointCombLuma() {
    float halfPhase;
    if(global.pn_nes_enable > 0.5) {
        halfPhase = 6 * params.OutputSize.z;
    } else {
        halfPhase = params.OutputSize.z * 0.5 / (global.pn_scanline_dur * global.pn_color_freq / global.pn_width_uncropped / SIGNAL_RES);
    }
//    vec2 coord = vTexCoord + vec2(floor(halfPhase / params.OutputSize.z / 2) * params.OutputSize.z, 0); // Make sure we step by a multiple of an input pixel. Stepping by a fraction doesn't filter as good.
//    return (texture(Source, coord) + texture(Source, coord - vec2(halfPhase, 0))) / 2;
//    return vec4(0);
    return (texture(Source, vTexCoord) + texture(Source, vTexCoord - vec2(halfPhase, 0))) / 2;
}

vec4 lowpassPickable(float type,
                     float halfWidth, float level, // artifact-colors sinc window
                     float gaussSigma, float gaussRadius, // guest(r) gaussian blur
                     float signalRes, // aliaspider gtu
                     float f_lo, float f_hi,
                     float g_lo, float g_mid, float g_hi,
                     float maxDistFailsafe, float overallOffset) // EMMIR NTSC-CRT
{
    if(type < -0.5) {
        return texture(Source, vTexCoord); // No low pass
    } else if(type < 0.5) {
        return lowpass(halfWidth, level); // sinc window
    } else if(type < 1.5) {
        return lowpassGaussian(gaussSigma, gaussRadius);
    } else if (type < 2.5) {
        return lowpassGTU(signalRes);
    } else if (type < 3.5) {
        return filterEQF(f_lo, f_hi, g_lo, g_mid, g_hi, 0, maxDistFailsafe, overallOffset);
    } else {
        // This filter is only for the demodulator, so it's at the end.
        // The lowpass filter selection for the modulator only goes up to 3 to prevent
        // this one from being picked for that.
        return twoPointCombLuma();
    }
}

////////////////////////
// Bandpass functions //
////////////////////////

// https://www.mathworks.com/help/signal/ug/fir-filter-design.html as of August 9, 2024
// This method of bandpassing is also taken from artifact-colors. Uses the "Windowing Method".
vec4 bandpass(float halfWidth, float levelLo, float levelHi) {
    float freqFactor = getFreqFactor();
    float levelFixedLo = (levelLo) * freqFactor;
    float levelFixedHi = (levelHi) * freqFactor;
    int halfWidthInt = int(floor(halfWidth * SIGNAL_RES + 0.5)); // Round to nearest integer.
    
    float burstRate = getBurstRate();
    
    vec4 bandPassed = vec4(0);
    float maxSum = 0.0;
    for(int i = -halfWidthInt; i <= halfWidthInt; i++) {
        vec4 samp = texture(Source, vTexCoord + vec2(i * params.OutputSize.z, 0));
        float window = hamming(i, halfWidthInt);
        float factorLo = levelFixedLo * sinc(levelFixedLo * i);
        float factorHi = levelFixedHi * sinc(levelFixedHi * i);
        float factor = factorHi - factorLo;
        bandPassed += window * factor * samp;
        maxSum += window * factor * cos(burstRate * i);
    }
    
    return bandPassed / maxSum;
}

vec4 twoPointCombChroma() {
    float halfPhase;
    if(global.pn_nes_enable < 0.5) {
        halfPhase = params.OutputSize.z * SIGNAL_RES / 2 / (global.pn_scanline_dur * global.pn_color_freq / global.pn_width_uncropped);
    } else {
        halfPhase = params.OutputSize.z * 6;
    }
    return (texture(Source, vTexCoord + vec2(halfPhase / 2, 0)) - texture(Source, vTexCoord - vec2(halfPhase / 2, 0))) / 2;
}

vec4 bandpassPickable(float type,
                      float halfWidth, float level, float levelDiff,
                      float f_lo, float f_hi,
                      float g_lo, float g_mid, float g_hi, float maxDistFailsafe, float overallOffset, int index)
{
    if(type < -0.5) {
        return texture(Source, vTexCoord);
    } else if(type < 0.5) {
        return bandpass(halfWidth, level, levelDiff);
    } else if(type < 1.5) {
        return filterEQF(f_lo, f_hi, g_lo, g_mid, g_hi, index, maxDistFailsafe, overallOffset) * 2;
    } else {
        return twoPointCombChroma();
    }
}

/////////////////////////
// Chroma demodulation //
/////////////////////////



mat3x2 yuvAxisPoints() {
   float r_off, r_max, g_off, g_max, b_off, b_max;
   
   const float Uupscale = 2.03206187221989;
   const float angFix = -123.0 / 180.0 * 3.14159265359;

   if(global.pn_demodulator_std < 0.5) {
      // Standard BT.470 matrix, used for NTSC and PAL SDTV.
      r_off = (123 - 90) / 180.0 * pi; // 33 deg
      r_max = 1.13983;
      g_off = -1.979; // -113 deg
      g_max = 0.70203;
      b_off = 123 / 180.0 * pi; // 123 deg
      b_max = 2.03211;
  } else if(global.pn_demodulator_std < 1.5) {
      // Later standard BT.709 matrix, used for NTSC and PAL HDTV.
      r_off = (123 - 90) / 180.0 * 3.14159265359;
      r_max = 1.28033;
      g_off = -2.085;
      g_max = 0.43703;
      b_off = 123 / 180.0 * 3.14159265359;
      b_max = 2.12798;
   } else if(global.pn_demodulator_std < 2.5) {
      // Sony CXA2025AS (JP axis) from official documentation, assuming blue is 33 degrees
      r_off = (123 - 95) / 180.0 * 3.14159265359;
      r_max = 0.78;
      g_off = (123 - 240) / 180.0 * 3.14159265359;
      g_max = 0.3;
      b_off = 123 / 180.0 * 3.14159265359;
      b_max = 1;
   } else if(global.pn_demodulator_std < 3.5) {
      // CXA1464AS (JP) from official data sheet
      r_off = (123 - 98) / 180.0 * 3.14159265359;
      r_max = 0.78;
      g_off = (123 - 243) / 180.0 * 3.14159265359;
      g_max = 0.31;
      b_off = 123 / 180.0 * 3.14159265359;
      b_max = 1;
   } else if(global.pn_demodulator_std < 4.5) {
      // Panasonic AN5367FB
      r_off = (123 - 104) / 180.0 * 3.14159265359;
      r_max = 0.96;
      g_off = (123 - 235) / 180.0 * 3.14159265359;
      g_max = 0.36;
      b_off = 123 / 180.0 * 3.14159265359;
      b_max = 1;
   } else if(global.pn_demodulator_std < 5.5) {
      // Toshiba TA8867BN, from official data sheet
      r_off = (123 - 104) / 180.0 * 3.14159265359;
      r_max = 0.91;
      g_off = (123 - 240) / 180.0 * 3.14159265359;
      g_max = 0.31;
      b_off = 123 / 180.0 * 3.14159265359;
      b_max = 1;
   } else if(global.pn_demodulator_std < 6.5) {
      // Toshiba TA8867AN, taken from the official data sheet
      r_off = (123 - 112) / 180.0 * 3.14159265359;
      r_max = 0.84;
      g_off = (123 - 237) / 180.0 * 3.14159265359;
      g_max = 0.33;
      b_off = 123 / 180.0 * 3.14159265359;
      b_max = 1;
   } else if(global.pn_demodulator_std < 7.5) {
      // Sony CXA2025AS (US axis mode) from the official data sheet
      r_off = (123 - 112) / 180.0 * 3.14159265359; // 112 deg or 11 deg
      r_max = 0.83;
      g_off = (123 - 252) / 180.0 * 3.14159265359; // 252 deg or -129 deg
      g_max = 0.3;
      b_off = 123 / 180.0 * 3.14159265359; // 0 deg or 123.5 deg
      b_max = 1.0;
   } else if(global.pn_demodulator_std < 8.5) {
      // Sony CXA1465AS from the official data sheet
      r_off = (123 - 114) / 180.0 * 3.14159265359;
      r_max = 0.78;
      g_off = (123 - 255) / 180.0 * 3.14159265359;
      g_max = 0.31;
      b_off = 123 / 180.0 * 3.14159265359;
      b_max = 1;
   } else if(global.pn_demodulator_std < 9.5) {
      // Custom from the user, in the same format as in a data sheet.
      r_off = (123 - global.pn_demodulator_r_off) / 180.0 * pi;
      g_off = (123 - global.pn_demodulator_g_off) / 180.0 * pi;
      b_off = 123.0 / 180.0 * pi;
      r_max = global.pn_demodulator_r_amp * Uupscale;
      g_max = global.pn_demodulator_g_amp * Uupscale;
      b_max = Uupscale;
   }
   
   // PAL matrix from TA8867AN and -BN. Notice that green is more saturated.
   // I'm now assuming that the oversaturated green is a mistake in the data sheet that doesn't appear in real hardware.
   //   r_off = (123 - 90) / 180.0 * 3.14159265359;
   //   r_max = 0.56 * 1.4;
   //   g_off = (123 - 235) / 180.0 * 3.14159265359;
   //   g_max = 0.38 * 1.4;
   //   b_off = 123 / 180.0 * 3.14159265359;
   //   b_max = 1 * 1.4;
   
   r_max *= Uupscale / b_max; // This can be hard-coded into the presets easily.
   g_max *= Uupscale / b_max;
   b_max *= Uupscale / b_max;
   
   r_off += angFix; // This can also be hard-coded into the presets easily.
   g_off += angFix;
   b_off += angFix;
   r_off *= -1;
   g_off *= -1;
   b_off *= -1;
   
   return mat3x2(r_off, r_max,
                 g_off, g_max,
                 b_off, b_max);
}

mat3x2 yuvAxisPointsSynced() {

    // Do not automatically sync the SMPTE-C and Rec. 709 matrices. Just return the default.
    // Automatic syncing had to be done for jungle chips because their defaults are not listed in their data sheets.

   mat3x2 yuvAxisPts = yuvAxisPoints();
   
   if(global.pn_demodulator_std < 1.5) {
      return yuvAxisPts;
   }
   
//   if(global.eztvcol3_cmp_console < 1.5) {
//       // This code is made using the mathematical formulas outlined by Chthon at https://forums.libretro.com/t/dogways-grading-shader-slang/27148/561
//       // The result is an RGB to RGB matrix.
//
//       float xr, yr, xg, yg, xb, yb;
//       xr = yuvAxisPts[0][1] * cos(yuvAxisPts[0][0]);
//       yr = yuvAxisPts[0][1] * sin(yuvAxisPts[0][0]);
//       xg = yuvAxisPts[1][1] * cos(yuvAxisPts[1][0]);
//       yg = yuvAxisPts[1][1] * sin(yuvAxisPts[1][0]);
//       xb = yuvAxisPts[2][1] * cos(yuvAxisPts[2][0]);
//       yb = yuvAxisPts[2][1] * sin(yuvAxisPts[2][0]);
//       
//       float wr = 0.298911657927057;
//       float wg = 0.586610718748869;
//       float wb = 0.114477623324074;
//       
//       float ud = 0.492111;
//       float vd = 0.877283;
//       float uu = 2.03206187221989;
//       float vu = 1.13988302520395;
//       
//       mat2 matB = mat2(
//          (1-wr)/vu, -wg/vu,
//          -wr/uu, -wg/uu
//       );
//       
//       vec2 cr = matB * vec2(yr, xr);
//       vec2 cg = matB * vec2(yg, xg);
//       vec2 cb = matB * vec2(yb, xb);
//       
//       return mat3(
//          cr.r + wr, cg.r + wr, cb.r + wr,
//          cr.g + wg, cg.g + wg, cb.g + wg,
//          1 - (cr.r + wr + cr.g + wg), 1 - (cg.r + wr + cg.g + wg), 1 - (cb.r + wr + cb.g + wg)
//       );
//   } else {

    // This simpler code generates a YUV to RGB matrix.
    float xr, yr, xg, yg, xb, yb;
    xr = yuvAxisPts[0][1] * cos(yuvAxisPts[0][0]);
    yr = yuvAxisPts[0][1] * sin(yuvAxisPts[0][0]);
    xg = yuvAxisPts[1][1] * cos(yuvAxisPts[1][0]);
    yg = yuvAxisPts[1][1] * sin(yuvAxisPts[1][0]);
    xb = yuvAxisPts[2][1] * cos(yuvAxisPts[2][0]);
    yb = yuvAxisPts[2][1] * sin(yuvAxisPts[2][0]);

    mat3 toRgb = mat3(1,  1,  1,
                      xr, xg, xb,
                      yr, yg, yb);
    
    mat3 fromRgb = inverse(toRgb);
    mat3 fromRgbStd;
    
//    if(global.pn_modulator_std < 0.5) {
        // Rec. 601 YUV matrix
        // This is used in the Genesis/MegaDrive and SNES/SFC
        fromRgbStd = mat3x3(
                    0.299, -0.14713, 0.615,
                    0.587, -0.28886, -0.51499,
                    0.114, 0.436, -0.10001
                 );
//    } else {
//        // Rec. 709 YUV matrix
//        // Don't know any specific consoles using this, but I assume this *eventually* became common.
//        fromRgbStd = mat3(0.2126, -0.09991, 0.615,
//                      0.7152, -0.33609, -0.55861,
//                      0.0722, 0.436, -0.05639);
//    }
                           
    // Basic linear regression to match the hue rotation (tint) to standard color bars.
    // Simply average up the offsets, and that's the ideal hue rotation.
    // On US CRTs, many people probably rotated this further to get greener greens, but then, some green would become very cyan, and some reds and pinks would become very orange.
    // Other people on US CRTs, especially on the NES, probably rotated a little in the opposite direction to get browner browns.
    // A problem with this method is that this is not a perceptually uniform color space. I will address that sometime else.
    
    float residSum = 0;
    for(int i = 1; i <= 6; i++) {
        vec3 colorBar = vec3(i & 1, (i >> 1) & 1, i >> 2);
        vec3 yuvJungle = fromRgb * colorBar;
        vec3 yuvStd = fromRgbStd * colorBar;
        float resid = atan(yuvJungle.b, yuvJungle.g) - atan(yuvStd.b, yuvStd.g);
        while(resid > pi)
            resid -= 2 * pi;
        while(resid < -pi)
            resid += 2 * pi;
        residSum += resid;
    }
    
    float hueOff = -residSum / 6;
    
    for(int i = 0; i < 3; i++)
        yuvAxisPts[i][0] += hueOff;
    
    
    xr = yuvAxisPts[0][1] * cos(yuvAxisPts[0][0]);
    yr = yuvAxisPts[0][1] * sin(yuvAxisPts[0][0]);
    xg = yuvAxisPts[1][1] * cos(yuvAxisPts[1][0]);
    yg = yuvAxisPts[1][1] * sin(yuvAxisPts[1][0]);
    xb = yuvAxisPts[2][1] * cos(yuvAxisPts[2][0]);
    yb = yuvAxisPts[2][1] * sin(yuvAxisPts[2][0]);

    toRgb = mat3(1,  1,  1,
                 xr, xg, xb,
                 yr, yg, yb);
    
    fromRgb = inverse(toRgb);

    // Old least-squares linear regression to match the saturation to the color bars.
    // We have an equation R = Summation for each of 6 bars: ((This Bar's Saturation in Jungle Chip) * (Saturation Factor) - (This Bar's Standard Saturation))^2
    // Meaning, R is the sum of squared differences in saturations. It's a subtraction, not a ratio.
    // Leaving (Saturation Factor) as a variable and simplifying down, the equation is in the format R = A(Saturation Factor)^2 + B(Saturation Factor) + C.
    // The value of (Saturation Factor) that minimizes R is in the center of the parabola, or -B/(2*A). The value C is never used, so we don't calculate it.
    
//    float Aval = 0;
//    float Bval = 0;
//    for(int i = 1; i <= 6; i++) {
//        vec3 colorBar = vec3(i & 1, (i >> 1) & 1, i >> 2);
//        vec3 yuvJungle = fromRgb * colorBar;
//        vec3 yuvStd = fromRgbStd * colorBar;
//        Aval += pow(yuvJungle.g, 2) + pow(yuvJungle.b, 2);
//        Bval += 2 * sqrt(pow(yuvJungle.g, 2) + pow(yuvJungle.b, 2)) * -sqrt(pow(yuvStd.g, 2) + pow(yuvStd.b, 2));
//    }
//    
//    float satFix = -Bval / (2 * Aval);
    
//    toRgb[0] *= 1; // Have to add this line here because some GPU drivers force you to multiply all 3 columns together.
//    toRgb[1] /= satFix;
//    toRgb[2] /= satFix;

    // New geometric mean to match the saturation to the color bars.
    // Take the proportion of the change on each color bar.
    // Then, take the geometric mean of those six proportions.
    // This has a better result than the linear regression above because saturation is not linear.
    // A problem with this method is that this is not a perceptually uniform color space. I will address that sometime else.
    
    float prop = 1.0;
    for(int i = 1; i <= 6; i++) {
        vec3 colorBar = vec3(i & 1, (i >> 1) & 1, i >> 2);
        vec3 yuvJungle = fromRgb * colorBar;
        vec3 yuvStd = fromRgbStd * colorBar;
        float satJungle = sqrt(pow(yuvJungle.g, 2) + pow(yuvJungle.b, 2));
        float satStd = sqrt(pow(yuvStd.g, 2) + pow(yuvStd.b, 2));
        prop *= satJungle / satStd; // What saturation do we set to make this bar match in saturation?
    }
    
    prop = pow(prop, 1.0/6.0); // Geometric mean of those proportional errors.
    
    for(int i = 0; i < 3; i++)
        yuvAxisPts[i][1] *= prop;
    
    return yuvAxisPts;
//   }
}

mat3 YBmyRmyToRGBMatrix() {
    mat3x2 yuvAxisPts = yuvAxisPointsSynced();
    
    float xr, yr, xg, yg, xb, yb;
    xr = yuvAxisPts[0][1] * cos(yuvAxisPts[0][0]);
    yr = yuvAxisPts[0][1] * sin(yuvAxisPts[0][0]);
    xg = yuvAxisPts[1][1] * cos(yuvAxisPts[1][0]);
    yg = yuvAxisPts[1][1] * sin(yuvAxisPts[1][0]);
    xb = yuvAxisPts[2][1] * cos(yuvAxisPts[2][0]);
    yb = yuvAxisPts[2][1] * sin(yuvAxisPts[2][0]);
    
    // YUV to RGB matrix
    mat3 toRgb = mat3(1,  1,  1,
                      xr, xg, xb,
                      yr, yg, yb);
    
    // YUV to Y B-Y R-Y matrix
    mat3 toYBmyRmy = mat3(1, 0, 0,
                          0, xb, xr,
                          0, yb, yr);
    
    // Y B-Y R-Y to YUV to RGB matrix
    return toRgb * inverse(toYBmyRmy);
}

vec2 uvDemodPickable(float type, float chroma, float phase, float tint) {
    mat3x2 axes = yuvAxisPointsSynced();
    if(type < -0.5) {
        return 2 * chroma * vec2(axes[2][1] * sin(phase + axes[2][0] + tint), axes[0][1] * sin(phase + axes[0][0] + tint));
    } else if(type < 1.5) { // either 0 or 1
        return 2 * chroma * vec2(axes[2][1] * sin(phase + axes[2][0] + tint), axes[0][1] * sin(phase + axes[0][0] + tint));
    } else {
        return 2 * chroma * vec2(axes[2][1] * sin(phase + pi / 2 + axes[2][0] + tint), axes[0][1] * sin(phase + pi / 2 + axes[0][0] + tint));
    }
}


#endif // __patchy_ntsc_inc_filters_inc__

