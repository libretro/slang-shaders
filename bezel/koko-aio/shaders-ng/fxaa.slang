#version 450

#include "config.inc"
#include "includes/functions.include.slang"

#define AA_MODE_FXAA                 // 110 fps  // on fastest preset (good for 2x upscale)
#define AA_MODE_DDTXBRLV1            // 108.4 // a bit blurry, parameters do help, yes, done.
#define AA_MODE_2xBRZ

#ifndef D3D_WORKAROUND
   #define FPS_ESTIMATE_PASS halo_pre_gamma_passFeedback
#else
   #define FPS_ESTIMATE_PASS Original
#endif


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) noperspective out vec2 vTexCoord;

layout(location = 3) noperspective out vec2 vDynamicSeed_noise;

layout(location = 5) noperspective out vec4 vpt1;
layout(location = 6) noperspective out vec4 vpt2;

layout(location = 7) noperspective out vec4 vhqt1;
layout(location = 8) noperspective out vec4 vhqt2;
layout(location = 9) noperspective out vec4 vhqt3;
layout(location = 10) noperspective out vec4 vhqt4;

layout(location = 11) noperspective out vec4 vxt1;

layout(location = 12) flat out float vDo_flickering;
layout(location = 13) noperspective out vec2  vFlickerCoords;





void main() {

   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;

   //noise
   vDynamicSeed_noise = vTexCoord;
   if (RF_NOISE_STRENGTH > 0.0) vDynamicSeed_noise *= mod(params.FrameCount, 120.0001) ;

   //flickering helper
   vDo_flickering  = float ( scanline_have_to_flicker(is_interlaced()) ) ;
   #ifdef FLICKER_IN_MOTION
      vDo_flickering = 1.0;
   #endif
   if (vDo_flickering == 1.0) {
      //Flicker one over 3 frames:
         float ModFlicker = params.FrameCount % 3;

      //Compute y flicker offset:
         float FlickerOffset = 0.0;
         float line_tick = is_interlaced() ? 1 : 2 ;
         if (ModFlicker == 1.0 )
            FlickerOffset = params.OriginalSize.w/line_tick;
         else if (ModFlicker == 2.0)
            FlickerOffset = -params.OriginalSize.w/line_tick;
      //Export flicker coords for Fragment shader here:
         vFlickerCoords =  vec2(TexCoord.x, TexCoord.y + FlickerOffset);
   }


   #ifdef AA_MODE_DDTXBRLV1
      vec2 xd = params.SourceSize.zw;
      vxt1.xy = vec2( xd.x,  0); // F
      vxt1.zw = vec2(  0, xd.y); // H
   #endif
}

#pragma stage fragment
layout(location = 0) noperspective in vec2 vTexCoord;

layout(location = 3) noperspective in vec2 vDynamicSeed_noise;

layout(location = 5) noperspective in vec4 vpt1;
layout(location = 6) noperspective in vec4 vpt2;

layout(location = 7) noperspective in vec4 vhqt1;
layout(location = 8) noperspective in vec4 vhqt2;
layout(location = 9) noperspective in vec4 vhqt3;
layout(location = 10) noperspective in vec4 vhqt4;

layout(location = 11) noperspective in vec4 vxt1;

layout(location = 12) flat in float vDo_flickering;
layout(location = 13) noperspective in vec2  vFlickerCoords;


layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 4) uniform sampler2D colortools_and_ntsc_pass;
layout(set = 0, binding = 5) uniform sampler2D colortools_and_ntsc_passFeedback;
layout(set = 0, binding = 6) uniform sampler2D FPS_ESTIMATE_PASS;



vec4 texture_ovr_nearest( sampler2D tex, vec2 co) {
   //return texture(tex, co);
   vec4 c = texture_NEAREST(tex, co, params.SourceSize);
   return c;
}


vec4 textureLod_ovr(sampler2D tex, vec2 co, float lod) {
   vec4 c = textureLod(tex, co, lod);
   return c;
}

vec4 texture_ovr_nearest_lod0( sampler2D tex, vec2 co) {
   //return texture(tex, co);
   vec4 c = texture_NEAREST_lod(tex, co, params.SourceSize, 0.0);
   return c;
}



#ifdef AA_MODE_2xBRZ

/*
   Following credits to Hyllian's xbrz code,
   I've just optimized some bits for speed.


   Hyllian's xBR-vertex code and texel mapping

   Copyright (C) 2011/2016 Hyllian - sergiogdb@gmail.com

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

*/

// This shader also uses code and/or concepts from xBRZ as it appears
// in the Desmume source code. The license for which is as follows:

// ****************************************************************************
// * This file is part of the HqMAME project. It is distributed under         *
// * GNU General Public License: http://www.gnu.org/licenses/gpl-3.0          *
// * Copyright (C) Zenju (zenju AT gmx DOT de) - All Rights Reserved          *
// *                                                                          *
// * Additionally and as a special exception, the author gives permission     *
// * to link the code of this program with the MAME library (or with modified *
// * versions of MAME that use the same license as MAME), and distribute      *
// * linked combinations including the two. You must obey the GNU General     *
// * Public License in all respects for all of the code used other than MAME. *
// * If you modify this file, you may extend this exception to your version   *
// * of the file, but you are not obligated to do so. If you do not wish to   *
// * do so, delete this exception statement from your version.                *
// ****************************************************************************


   #define BLEND_NONE 0
   #define BLEND_NORMAL 1
   #define BLEND_DOMINANT 2
   #define LUMINANCE_WEIGHT 1.0
   #define EQUAL_COLOR_TOLERANCE 30.0/255.0
   #define STEEP_DIRECTION_THRESHOLD 2.2
   #define DOMINANT_DIRECTION_THRESHOLD 3.6
   #define M_PI 3.1415926535897932384626433832795

	const float  one_sixth = 1.0 / 6.0;
	const float  two_sixth = 2.0 / 6.0;
	const float four_sixth = 4.0 / 6.0;
	const float five_sixth = 5.0 / 6.0;

	float reduce(const vec3 color) {
		return dot(color, vec3(65536.0, 256.0, 1.0));
	}

	float color_diff(const vec3 a, const vec3 b) {
      //koko: use a faster compare:
      vec3 d = a-b;
      return dot(d,d);
	}

	bool IsPixEqual(const vec3 pixA, const vec3 pixB) {
		return (color_diff(pixA, pixB) < EQUAL_COLOR_TOLERANCE);
	}

	bool IsBlendingNeeded(const ivec4 blend) {
		return any(notEqual(blend, ivec4(BLEND_NONE)));
	}

      void ScalePixel(const ivec4 blend, const vec3 k[9],
                     float v0, float v4, float v5, float v7, float v8,
                     inout vec3 dst[4])
      {
         float dist_01_04 = color_diff(k[1], k[4]);
         float dist_03_08 = color_diff(k[3], k[8]);
         bool haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v0 != v4) && (v5 != v4);
         bool haveSteepLine   = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v0 != v8) && (v7 != v8);
         bool needBlend = (blend[2] != BLEND_NONE);
         bool doLineBlend = (  blend[2] >= BLEND_DOMINANT ||
                           !((blend[1] != BLEND_NONE && !IsPixEqual(k[0], k[4])) ||
                              (blend[3] != BLEND_NONE && !IsPixEqual(k[0], k[8])) ||
                              (IsPixEqual(k[4], k[3]) && IsPixEqual(k[3], k[2]) && IsPixEqual(k[2], k[1]) && IsPixEqual(k[1], k[8]) && !IsPixEqual(k[0], k[2])) ) );

         vec3 blendPix = ( color_diff(k[0], k[1]) <= color_diff(k[0], k[3]) ) ? k[1] : k[3];
         dst[1] = mix(dst[1], blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.25 : 0.00);
         dst[2] = mix(dst[2], blendPix, (needBlend) ? ((doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 5.0/6.0 : 0.75) : ((haveSteepLine) ? 0.75 : 0.50)) : 1.0 - (M_PI/4.0)) : 0.00);
         dst[3] = mix(dst[3], blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.25 : 0.00);
      }



   vec3 aa_2xbrz(sampler2D smp, vec2 co) {


      //---------------------------------------
      // Input Pixel Mapping:  20|21|22|23|24
      //                       19|06|07|08|09
      //                       18|05|00|01|10
      //                       17|04|03|02|11
      //                       16|15|14|13|12


   // Snap delle coordinate: sostituisce il calcolo interno a texture_ovr_nearest_lod0
      vec2 sz  = params.SourceSize.xy;
      vec2 isz = params.SourceSize.zw;

      // snap coords to get NN filtering
      float sx_l = (floor(co.x * sz.x - 1.0) + 0.5) * isz.x; // -dx
      float sx_c = (floor(co.x * sz.x      ) + 0.5) * isz.x; // 0
      float sx_r = (floor(co.x * sz.x + 1.0) + 0.5) * isz.x; // +dx
      float sx_ll= (floor(co.x * sz.x - 2.0) + 0.5) * isz.x; // -2dx (t6)
      float sx_rr= (floor(co.x * sz.x + 2.0) + 0.5) * isz.x; // +2dx (t7)
      float sy_t2 = (floor(co.y * sz.y - 2.0) + 0.5) * isz.y; // t1
      float sy_t1 = (floor(co.y * sz.y - 1.0) + 0.5) * isz.y; // t2
      float sy_m  = (floor(co.y * sz.y      ) + 0.5) * isz.y; // t3
      float sy_b1 = (floor(co.y * sz.y + 1.0) + 0.5) * isz.y; // t4
      float sy_b2 = (floor(co.y * sz.y + 2.0) + 0.5) * isz.y; // t5

      vec3 src[25];

         src[21] = textureLod(smp, vec2(sx_l,  sy_t2), 0.0).rgb;
         src[22] = textureLod(smp, vec2(sx_c,  sy_t2), 0.0).rgb;
         src[23] = textureLod(smp, vec2(sx_r,  sy_t2), 0.0).rgb;
         src[ 6] = textureLod(smp, vec2(sx_l,  sy_t1), 0.0).rgb;
         src[ 7] = textureLod(smp, vec2(sx_c,  sy_t1), 0.0).rgb;
         src[ 8] = textureLod(smp, vec2(sx_r,  sy_t1), 0.0).rgb;
         src[ 5] = textureLod(smp, vec2(sx_l,  sy_m ), 0.0).rgb;
         src[ 0] = textureLod(smp, vec2(sx_c,  sy_m ), 0.0).rgb;
         src[ 1] = textureLod(smp, vec2(sx_r,  sy_m ), 0.0).rgb;
         src[ 4] = textureLod(smp, vec2(sx_l,  sy_b1), 0.0).rgb;
         src[ 3] = textureLod(smp, vec2(sx_c,  sy_b1), 0.0).rgb;
         src[ 2] = textureLod(smp, vec2(sx_r,  sy_b1), 0.0).rgb;
         src[15] = textureLod(smp, vec2(sx_l,  sy_b2), 0.0).rgb;
         src[14] = textureLod(smp, vec2(sx_c,  sy_b2), 0.0).rgb;
         src[13] = textureLod(smp, vec2(sx_r,  sy_b2), 0.0).rgb;
         src[19] = textureLod(smp, vec2(sx_ll, sy_t1), 0.0).rgb;
         src[18] = textureLod(smp, vec2(sx_ll, sy_m ), 0.0).rgb;
         src[17] = textureLod(smp, vec2(sx_ll, sy_b1), 0.0).rgb;
         src[ 9] = textureLod(smp, vec2(sx_rr, sy_t1), 0.0).rgb;
         src[10] = textureLod(smp, vec2(sx_rr, sy_m ), 0.0).rgb;
         src[11] = textureLod(smp, vec2(sx_rr, sy_b1), 0.0).rgb;

         float v[9];
         v[0] = reduce(src[0]);
         v[1] = reduce(src[1]);
         v[2] = reduce(src[2]);
         v[3] = reduce(src[3]);
         v[4] = reduce(src[4]);
         v[5] = reduce(src[5]);
         v[6] = reduce(src[6]);
         v[7] = reduce(src[7]);
         v[8] = reduce(src[8]);

         ivec4 blendResult = ivec4(BLEND_NONE);

         // Preprocess corners

         // Pixel Tap Mapping: --|--|--|--|--
         //                    --|--|07|08|--
         //                    --|05|00|01|10
         //                    --|04|03|02|11
         //                    --|--|14|13|--
         // Corner (1, 1)
         if ( ((v[0] == v[1] && v[3] == v[2]) || (v[0] == v[3] && v[1] == v[2])) == false)
         {
            float dist_03_01 = color_diff(src[ 4], src[ 0]) + color_diff(src[ 0], src[ 8]) + color_diff(src[14], src[ 2]) + color_diff(src[ 2], src[10]) + (4.0 * color_diff(src[ 3], src[ 1]));
            float dist_00_02 = color_diff(src[ 5], src[ 3]) + color_diff(src[ 3], src[13]) + color_diff(src[ 7], src[ 1]) + color_diff(src[ 1], src[11]) + (4.0 * color_diff(src[ 0], src[ 2]));
            bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_03_01) < dist_00_02;
            blendResult[2] = ((dist_03_01 < dist_00_02) && (v[0] != v[1]) && (v[0] != v[3])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
         }

         // Pixel Tap Mapping: --|--|--|--|--
         //                    --|06|07|--|--
         //                    18|05|00|01|--
         //                    17|04|03|02|--
         //                    --|15|14|--|--
         // Corner (0, 1)
         if ( ((v[5] == v[0] && v[4] == v[3]) || (v[5] == v[4] && v[0] == v[3])) == false)
         {
            float dist_04_00 = color_diff(src[17], src[ 5]) + color_diff(src[ 5], src[ 7]) + color_diff(src[15], src[ 3]) + color_diff(src[ 3], src[ 1]) + (4.0 * color_diff(src[ 4], src[ 0]));
            float dist_05_03 = color_diff(src[18], src[ 4]) + color_diff(src[ 4], src[14]) + color_diff(src[ 6], src[ 0]) + color_diff(src[ 0], src[ 2]) + (4.0 * color_diff(src[ 5], src[ 3]));
            bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_05_03) < dist_04_00;
            blendResult[3] = ((dist_04_00 > dist_05_03) && (v[0] != v[5]) && (v[0] != v[3])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
         }

         // Pixel Tap Mapping: --|--|22|23|--
         //                    --|06|07|08|09
         //                    --|05|00|01|10
         //                    --|--|03|02|--
         //                    --|--|--|--|--
         // Corner (1, 0)
         if ( ((v[7] == v[8] && v[0] == v[1]) || (v[7] == v[0] && v[8] == v[1])) == false)
         {
            float dist_00_08 = color_diff(src[ 5], src[ 7]) + color_diff(src[ 7], src[23]) + color_diff(src[ 3], src[ 1]) + color_diff(src[ 1], src[ 9]) + (4.0 * color_diff(src[ 0], src[ 8]));
            float dist_07_01 = color_diff(src[ 6], src[ 0]) + color_diff(src[ 0], src[ 2]) + color_diff(src[22], src[ 8]) + color_diff(src[ 8], src[10]) + (4.0 * color_diff(src[ 7], src[ 1]));
            bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_07_01) < dist_00_08;
            blendResult[1] = ((dist_00_08 > dist_07_01) && (v[0] != v[7]) && (v[0] != v[1])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
         }

         // Pixel Tap Mapping: --|21|22|--|--
         //                    19|06|07|08|--
         //                    18|05|00|01|--
         //                    --|04|03|--|--
         //                    --|--|--|--|--
         // Corner (0, 0)
         if ( ((v[6] == v[7] && v[5] == v[0]) || (v[6] == v[5] && v[7] == v[0])) == false)
         {
            float dist_05_07 = color_diff(src[18], src[ 6]) + color_diff(src[ 6], src[22]) + color_diff(src[ 4], src[ 0]) + color_diff(src[ 0], src[ 8]) + (4.0 * color_diff(src[ 5], src[ 7]));
            float dist_06_00 = color_diff(src[19], src[ 5]) + color_diff(src[ 5], src[ 3]) + color_diff(src[21], src[ 7]) + color_diff(src[ 7], src[ 1]) + (4.0 * color_diff(src[ 6], src[ 0]));
            bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_05_07) < dist_06_00;
            blendResult[0] = ((dist_05_07 < dist_06_00) && (v[0] != v[5]) && (v[0] != v[7])) ? ((dominantGradient) ? BLEND_DOMINANT : BLEND_NORMAL) : BLEND_NONE;
         }

         vec3 dst[4];
         dst[ 0] = src[0];
         dst[ 1] = src[0];
         dst[ 2] = src[0];
         dst[ 3] = src[0];

         // Scale pixel
         if (IsBlendingNeeded(blendResult) == true) {

            vec3 k[9];
            vec3 tempDst3;

            k[0] = src[0];
            k[1] = src[1];
            k[2] = src[2];
            k[3] = src[3];
            k[4] = src[4];
            k[5] = src[5];
            k[6] = src[6];
            k[7] = src[7];
            k[8] = src[8];
            ScalePixel(blendResult.xyzw, k, v[0], v[4], v[5], v[7], v[8], dst);

            k[1] = src[7];
            k[2] = src[8];
            k[3] = src[1];
            k[4] = src[2];
            k[5] = src[3];
            k[6] = src[4];
            k[7] = src[5];
            k[8] = src[6];
            tempDst3 = dst[3];
            dst[3] = dst[2];
            dst[2] = dst[1];
            dst[1] = dst[0];
            dst[0] = tempDst3;
            ScalePixel(blendResult.wxyz, k, v[0], v[2], v[3], v[5], v[6], dst);

            k[1] = src[5];
            k[2] = src[6];
            k[3] = src[7];
            k[4] = src[8];
            k[5] = src[1];
            k[6] = src[2];
            k[7] = src[3];
            k[8] = src[4];
            tempDst3 = dst[3];
            dst[3] = dst[2];
            dst[2] = dst[1];
            dst[1] = dst[0];
            dst[0] = tempDst3;
            ScalePixel(blendResult.zwxy, k, v[0], v[8], v[1], v[3], v[4], dst);

            k[1] = src[3];
            k[2] = src[4];
            k[3] = src[5];
            k[4] = src[6];
            k[5] = src[7];
            k[6] = src[8];
            k[7] = src[1];
            k[8] = src[2];
            tempDst3 = dst[3];
            dst[3] = dst[2];
            dst[2] = dst[1];
            dst[1] = dst[0];
            dst[0] = tempDst3;
            ScalePixel(blendResult.yzwx, k, v[0], v[6], v[7], v[1], v[2], dst);

            // Rotate the destination pixels back to 0 degrees.
            tempDst3 = dst[3];
            dst[3] = dst[2];
            dst[2] = dst[1];
            dst[1] = dst[0];
            dst[0] = tempDst3;
         }

      vec2 f = step(0.5, fract(co*params.SourceSize.xy));
      vec3 res = mix( mix(dst[0], dst[1], f.x),
                              mix(dst[3], dst[2], f.x), f.y );
      return res;
   }


#endif



#ifdef AA_MODE_DDTXBRLV1

   /*
   Hyllian's DDT-xBR-lv1 Shader

   Copyright (C) 2011-2022 Hyllian/Jararaca - sergiogdb@gmail.com

   Sharpness control - Copyright (c) 2022 Filippo Scognamiglio

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.
   */


   //    // set to 1.0 to use dynamic sharpening
   //    #pragma parameter USE_DYNAMIC_SHARPNESS "Dynamic Sharpness [ 0FF | ON ]" 1.0 0.0 1.0 1.0
   //
   //    // Set to 1.0 to bias the interpolation towards sharpening
   //    #pragma parameter USE_SHARPENING_BIAS "Sharpness Bias [ 0FF | ON ]" 1.0 0.0 1.0 1.0
   //
   //    // Minimum amount of sharpening in range [0.0, 1.0]
   //    #pragma parameter DYNAMIC_SHARPNESS_MIN "Dynamic Sharpness Min" 0.0 0.0 1.0 0.1
   //
   //    // Maximum amount of sharpening in range [0.0, 1.0]
   //    #pragma parameter DYNAMIC_SHARPNESS_MAX "Dynamic Sharpness Max" 0.3 0.0 1.0 0.1
   //
   //    // If USE_DYNAMIC_SHARPNESS is 0 apply this static sharpness
   //    #pragma parameter STATIC_SHARPNESS "Static Sharpness" 0.5 0.0 1.0 0.1
   //
   //    #pragma parameter DDT_THRESHOLD "DDT Diagonal Threshold" 2.6 1.0 6.0 0.2
   //
   //    #define USE_DYNAMIC_SHARPNESS  params.USE_DYNAMIC_SHARPNESS
   //    #define USE_SHARPENING_BIAS    params.USE_SHARPENING_BIAS
   //    #define DYNAMIC_SHARPNESS_MIN  (params.DYNAMIC_SHARPNESS_MIN * 0.5)
   //    #define DYNAMIC_SHARPNESS_MAX  (params.DYNAMIC_SHARPNESS_MAX * 0.5)
   //    #define STATIC_SHARPNESS       (params.STATIC_SHARPNESS * 0.5)
   //    #define DDT_THRESHOLD params.DDT_THRESHOLD
   //

   #define WP1  4.0
   #define WP2  1.0
   #define WP3 -1.0

   #define USE_DYNAMIC_SHARPNESS  1.0
      #define USE_SHARPENING_BIAS    1.0
      #define DYNAMIC_SHARPNESS_MIN  0.1  // default: (0.0 * 0.5)
      #define DYNAMIC_SHARPNESS_MAX  0.25 // default: (0.3 * 0.5)

   #define STATIC_SHARPNESS       (0.5 * 0.5)
   #define DDT_THRESHOLD 2.6

   const vec3 Y = vec3( 0.299,  0.587,  0.114);

   float luma(vec3 color) {
   return dot(color, Y);
   }

   float linearStep(float edge0, float edge1, float t) {
      return clamp((t - edge0) / (edge1 - edge0), 0.0, 1.0);
   }

   float sharpSmooth(float t, float sharpness) {
      return linearStep(sharpness, 1.0 - sharpness, t);
   }

   vec3 quadBilinear(vec3 a, vec3 b, vec3 c, vec3 d, vec2 p, float sharpness){
      float x = sharpSmooth(p.x, sharpness);
      float y = sharpSmooth(p.y, sharpness);
      return mix(mix(a, b, x), mix(c, d, x), y);
   }

   // Fast computation of barycentric coordinates only in the sub-triangle 1 2 4
   vec3 fastBarycentric(vec2 p, float sharpness) {
      float l0 = sharpSmooth(1.0 - p.x - p.y, sharpness);
      float l1 = sharpSmooth(p.x, sharpness);
      return vec3(l0, l1, 1.0 - l0 - l1);
   }

   vec3 triangleInterpolate(vec3 t1, vec3 t2, vec3 t3, vec3 t4, vec2 c, float sharpness) {
      // Alter colors and coordinates to compute the other triangle.
      bool altTriangle = 1.0 - c.x < c.y;
      vec3 cornerColor = altTriangle ? t3 : t1;
      //vec2 triangleCoords = altTriangle ? vec2(1.0 - c.y, 1.0 - c.x) : c;
      vec2 triangleCoords;
      if (altTriangle) {
         triangleCoords = vec2(1.0 - c.y, 1.0 - c.x);
      } else {
         triangleCoords = c;
      }
      vec3 weights = fastBarycentric(triangleCoords, sharpness);
      return weights.x * cornerColor + weights.y * t2 + weights.z * t4;
   }

   vec3 aa_ddtxbrlv1(sampler2D tex, vec2 co, vec4 pt1) {

      vec2 pos = fract(co*params.SourceSize.xy)-vec2(0.5); // pos = pixel position
      vec2 dir = sign(pos); // dir = pixel direction
      float lmax, lmin, contrast;
      float sharpness = STATIC_SHARPNESS;

      vec2 g1 = dir*pt1.xy;
      vec2 g2 = dir*pt1.zw;

      vec3 A = texture_ovr_nearest_lod0(tex, vTexCoord       ).xyz;
      vec3 B = texture_ovr_nearest_lod0(tex, vTexCoord +g1   ).xyz;
      vec3 C = texture_ovr_nearest_lod0(tex, vTexCoord    +g2).xyz;
      vec3 D = texture_ovr_nearest_lod0(tex, vTexCoord +g1+g2).xyz;

      vec3 A1 = texture_ovr_nearest_lod0(tex, vTexCoord    -g2).xyz;
      vec3 B1 = texture_ovr_nearest_lod0(tex, vTexCoord +g1-g2).xyz;
      vec3 A0 = texture_ovr_nearest_lod0(tex, vTexCoord -g1   ).xyz;
      vec3 C0 = texture_ovr_nearest_lod0(tex, vTexCoord -g1+g2).xyz;

      vec3 B2 = texture_ovr_nearest_lod0(tex, vTexCoord +2*g1     ).xyz;
      vec3 D2 = texture_ovr_nearest_lod0(tex, vTexCoord +2*g1+  g2).xyz;
      vec3 C3 = texture_ovr_nearest_lod0(tex, vTexCoord      +2*g2).xyz;
      vec3 D3 = texture_ovr_nearest_lod0(tex, vTexCoord   +g1+2*g2).xyz;

      float a = luma(A);
      float b = luma(B);
      float c = luma(C);
      float d = luma(D);

      if (USE_DYNAMIC_SHARPNESS == 1.0) {
         lmax = max(max(a, b), max(c, d));
         lmin = min(min(a, b), min(c, d));
         contrast = (lmax - lmin) / (lmax + lmin + 0.05);

         if (USE_SHARPENING_BIAS == 1.0)
            contrast = sqrt(contrast);

         sharpness = mix(DYNAMIC_SHARPNESS_MIN, DYNAMIC_SHARPNESS_MAX, contrast);
      }

      float a1 = luma(A1);
      float b1 = luma(B1);
      float a0 = luma(A0);
      float c0 = luma(C0);

      float b2 = luma(B2);
      float d2 = luma(D2);
      float c3 = luma(C3);
      float d3 = luma(D3);

      float p = abs(pos.x);
      float q = abs(pos.y);

      //    A1 B1
      // A0 A  B  B2
      // C0 C  D  D2
      //    C3 D3

      float wd1 = (WP1*abs(a-d) + WP2*(abs(b-a1) + abs(b-d2) + abs(c-a0) + abs(c-d3)) + WP3*(abs(a1-d2) + abs(a0-d3)));
      float wd2 = (WP1*abs(b-c) + WP2*(abs(a-b1) + abs(a-c0) + abs(d-b2) + abs(d-c3)) + WP3*(abs(b1-c0) + abs(b2-c3)));

      float irlv1 = (abs(a-b)+abs(a-c)+abs(d-c)+abs(d-b));

      vec3 color;

      if ( ((wd1+0.1*DDT_THRESHOLD)*DDT_THRESHOLD < wd2) && (irlv1 > 0.0) )
      {
            color = triangleInterpolate(B, D, C, A, vec2(q, 1-p), sharpness);
      }
      else if ( (wd1 > (wd2+0.1*DDT_THRESHOLD)*DDT_THRESHOLD) && (irlv1 > 0.0))
      {
            color = triangleInterpolate(A, B, D, C, vec2(p, q), sharpness);
      }
      else
         color = quadBilinear(A, B, C, D, vec2(p, q), sharpness);

      return color;
   }

#endif


vec3 pixel_flickering(vec3 pixel_cur) {
/* Simulates the flickering effect of the interlaced screens.
 * As I remember, it was visible when a line and the next had high
 * luminosity differences.
 * So we need to sample the current line and the previous one
 * (eventually applying color corrections to both).
 *
 * Repeating the following:
 * On frame 0, return the "clean" pixel
 * On frame 1, mix the upper pixel with the current one
 * On frame 2, mix the lower pixel with the current one
 *
 * The effect of the mix is the flickering itself, and we modulate
 * the mix according to the luminance difference between the current
 * pixel and the mixed one.
 *
 * We choose to alternate on a period of 3,
 * (thus considering the upper pixel and the lower one)
 * or else the high pixel persistance of lcd displays wont allow
 * to see the effect (the lcd panel would just mix the pixels by itself (meh).
 */

   vec3 flickline = texture(colortools_and_ntsc_pass,vFlickerCoords).rgb;

   //float lumdiff = abs( flickline.r + flickline.g + flickline.b - pixel_cur.r - pixel_cur.g - pixel_cur.b);
   //float lumdiff = abs( (flickline.r + flickline.g) + (flickline.b - pixel_cur.r) - (pixel_cur.g + pixel_cur.b) ); //1687 1754 2946   ASM PROOF: FASTER
   float lumdiff = abs( dot(flickline.rgb, vec3(1.0)) - dot(pixel_cur.rgb, vec3(1.0)));// 1685 1750 2948 //ASM PROOF: Faster on SIMD8 and SIMD16, slower on SIMD32


   // disable flickering on 25 and 30fps content:
   if (low_fps(FPS_ESTIMATE_PASS)) lumdiff = 0.0;

   lumdiff = min(lumdiff * PIXELGRID_INTR_FLICK_POWR, 1.0);


   #ifdef FLICKER_IN_MOTION
      lumdiff = 0.4;
      vec3 prev_frame = texture(colortools_and_ntsc_passFeedback, vTexCoord).rgb;
      vec3 cur_frame = texture(colortools_and_ntsc_pass, vTexCoord).rgb;
      float is_moving = float(prev_frame != cur_frame);
      lumdiff *= is_moving;
   #endif

   return mix(pixel_cur.rgb,flickline.rgb,lumdiff);

}


#ifndef FXAA_PRESET
    #define FXAA_PRESET 2
#endif

#if (FXAA_PRESET == 1)  //Dumb preset, looks like others for 2x scaling, but skip search.
    #define FXAA_EDGE_THRESHOLD      (1.0/8.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
    #define FXAA_SEARCH_STEPS        0
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (3.0/4.0)
    #define FXAA_SUBPIX_TRIM         (1.0/8.0)
#endif

#if (FXAA_PRESET == 2) // Limited search, rounder
    #define FXAA_EDGE_THRESHOLD      (1.0/8.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
    #define FXAA_SEARCH_STEPS        4
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #undef  FXAA_SUBPIX_TRIM                     //koko: brighter edges
    #define FXAA_SUBPIX_CAP          (3.0/4.0)   //koko: unused when FXAA_SUBPIX_TRIM is not defined
#endif

#if (FXAA_PRESET == 3)
    #define FXAA_EDGE_THRESHOLD      (1.0/8.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/16.0)
    #define FXAA_SEARCH_STEPS        16
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (3.0/4.0)
    #define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif
#if (FXAA_PRESET == 4)
    #define FXAA_EDGE_THRESHOLD      (1.0/8.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
    #define FXAA_SEARCH_STEPS        24
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (3.0/4.0)
    #define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif
#if (FXAA_PRESET == 5)
    #define FXAA_EDGE_THRESHOLD      (1.0/8.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
    #define FXAA_SEARCH_STEPS        32
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (3.0/4.0)
    #define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif

#ifdef FXAA_SUBPIX_TRIM
   #define FXAA_SUBPIX_TRIM_SCALE (1.0/(1.0 - FXAA_SUBPIX_TRIM))
#endif

// Return the luma, the estimation of luminance from rgb inputs.
// This approximates luma using one FMA instruction,
// skipping normalization and tossing out blue.
// FxaaLuma() will range 0.0 to 2.963210702.
float FxaaLuma(vec3 rgb) {
    //return rgb.y * (0.587/0.299) + rgb.x;
    return fma( rgb.y, (0.587/0.299), rgb.x ); //ASM_PROOF: SAME
}

vec3 FxaaLerp3(vec3 a, vec3 b, float amountOfA) {
    return (vec3(-amountOfA) * b) + ((a * vec3(amountOfA)) + b);
}

vec4 FxaaTexOff(sampler2D tex, vec2 pos, ivec2 off, vec4 sourcesize, vec4 outputsize) {
   float x = pos.x + float(off.x) * sourcesize.z;
   float y = pos.y + float(off.y) * sourcesize.w;

   vec2 fragmentShift = off * outputsize.zw;
   vec2 shiftedUV = pos + fragmentShift;
   vec2 nearestUV = floor(shiftedUV * sourcesize.xy) * sourcesize.zw + sourcesize.zw * 0.5;

   return textureLod_ovr(tex, nearestUV, 0.0);
}

// pos is the output of FxaaVertexShader interpolated across screen.
// xy -> actual texture position {0.0 to 1.0}
// sourcesize.zw should be a uniform equal to  {1.0/frameWidth, 1.0/frameHeight}
vec3 FxaaPixelShader(vec2 pos, sampler2D tex, vec4 sourcesize, vec4 outputsize) {

   vec3 rgbN = FxaaTexOff(tex, pos.xy, ivec2( 0,-1), sourcesize, outputsize).xyz;
   vec3 rgbW = FxaaTexOff(tex, pos.xy, ivec2(-1, 0), sourcesize, outputsize).xyz;
   vec3 rgbM = FxaaTexOff(tex, pos.xy, ivec2( 0, 0), sourcesize, outputsize).xyz;
   vec3 rgbE = FxaaTexOff(tex, pos.xy, ivec2( 1, 0), sourcesize, outputsize).xyz;
   vec3 rgbS = FxaaTexOff(tex, pos.xy, ivec2( 0, 1), sourcesize, outputsize).xyz;

   float lumaN = FxaaLuma(rgbN);
   float lumaW = FxaaLuma(rgbW);
   float lumaM = FxaaLuma(rgbM);
   float lumaE = FxaaLuma(rgbE);
   float lumaS = FxaaLuma(rgbS);

   float rangeMin = min(lumaM, min(min(lumaN, lumaW), min(lumaS, lumaE)));
   float rangeMax = max(lumaM, max(max(lumaN, lumaW), max(lumaS, lumaE)));

   float range = rangeMax - rangeMin;
   if(range < max(FXAA_EDGE_THRESHOLD_MIN, rangeMax * FXAA_EDGE_THRESHOLD)) {
      return rgbM;
   }

   vec3 rgbL = rgbN + rgbW + rgbM + rgbE + rgbS; //ASM_PROOF: USELESS parenthesis

   float lumaL = (lumaN + lumaW + lumaE + lumaS) * 0.25;
   float rangeL = abs(lumaL - lumaM);

   #ifdef FXAA_SUBPIX_TRIM
      float blendL = max(0.0, (rangeL / range) - FXAA_SUBPIX_TRIM) * FXAA_SUBPIX_TRIM_SCALE;
      blendL = min(FXAA_SUBPIX_CAP, blendL);
   #else
      float blendL = 0.0;
   #endif

   vec3 rgbNW = FxaaTexOff(tex, pos.xy, ivec2(-1,-1), sourcesize, outputsize).xyz;
   vec3 rgbNE = FxaaTexOff(tex, pos.xy, ivec2( 1,-1), sourcesize, outputsize).xyz;
   vec3 rgbSW = FxaaTexOff(tex, pos.xy, ivec2(-1, 1), sourcesize, outputsize).xyz;
   vec3 rgbSE = FxaaTexOff(tex, pos.xy, ivec2( 1, 1), sourcesize, outputsize).xyz;

   rgbL += (rgbNW + rgbNE + rgbSW + rgbSE);

   rgbL *= vec3(1.0/9.0);

   float lumaNW = FxaaLuma(rgbNW);
   float lumaNE = FxaaLuma(rgbNE);
   float lumaSW = FxaaLuma(rgbSW);
   float lumaSE = FxaaLuma(rgbSE);

   float edgeVert =
      abs((0.25 * lumaNW) + (-0.5 * lumaN) + (0.25 * lumaNE)) +
      abs((0.50 * lumaW ) + (-1.0 * lumaM) + (0.50 * lumaE )) +
      abs((0.25 * lumaSW) + (-0.5 * lumaS) + (0.25 * lumaSE));
   float edgeHorz =
      abs((0.25 * lumaNW) + (-0.5 * lumaW) + (0.25 * lumaSW)) +
      abs((0.50 * lumaN ) + (-1.0 * lumaM) + (0.50 * lumaS )) +
      abs((0.25 * lumaNE) + (-0.5 * lumaE) + (0.25 * lumaSE));

   bool horzSpan = edgeHorz >= edgeVert;

   vec2 texel_size_scaled = sourcesize.zw * 0.5; //<-- KOKO, hack.

   float lengthSign = horzSpan ? -texel_size_scaled.y : -texel_size_scaled.x;

   if (!horzSpan) {
      lumaN = lumaW;
      lumaS = lumaE;
   }

   float gradientN = abs(lumaN - lumaM);
   float gradientS = abs(lumaS - lumaM);
   lumaN = (lumaN + lumaM) * 0.5;
   lumaS = (lumaS + lumaM) * 0.5;

   if (gradientN < gradientS) {
      lumaN = lumaS;
      lumaN = lumaS;
      gradientN = gradientS;
      lengthSign *= -1.0;
   }

   vec2 posN;
   posN.x = pos.x + (horzSpan ? 0.0 : lengthSign * 0.5);
   posN.y = pos.y + (horzSpan ? lengthSign * 0.5 : 0.0);

   gradientN *= FXAA_SEARCH_THRESHOLD;

   vec2 posP = posN;
   vec2 offNP = horzSpan ? vec2(texel_size_scaled.x, 0.0) : vec2(0.0, texel_size_scaled.y);
   float lumaEndN = lumaN;
   float lumaEndP = lumaN;
   bool doneN = false;
   bool doneP = false;

   posN += offNP * vec2(-1.0, -1.0);
   posP += offNP * vec2( 1.0,  1.0);

   for(int i = 0; i < FXAA_SEARCH_STEPS; i++) {
      vec2 posN_adjusted;
      vec2 posP_adjusted;

      if (horzSpan) {
         posN_adjusted.x = coords_NEAREST(posN, params.SourceSize).x;
         posN_adjusted.y = posN.y;

         posP_adjusted.x = coords_NEAREST(posP, params.SourceSize).x;
         posP_adjusted.y = posP.y;

      } else {

         posN_adjusted.x = posN.x;
         posN_adjusted.y = coords_NEAREST(posN, params.SourceSize).y;

         posP_adjusted.x = posP.x;
         posP_adjusted.y = coords_NEAREST(posP, params.SourceSize).y;
      }


      if(!doneN) {
         lumaEndN = FxaaLuma(textureLod_ovr(tex, posN_adjusted.xy,0.0).xyz);
      }
      if(!doneP) {
         lumaEndP = FxaaLuma(textureLod_ovr(tex, posP_adjusted.xy,0.0).xyz);
      }

      doneN = doneN || (abs(lumaEndN - lumaN) >= gradientN);
      doneP = doneP || (abs(lumaEndP - lumaN) >= gradientN);

      if (doneN && doneP) {
         break;
      }

      if (!doneN) {
         posN -= offNP;
      }
      if (!doneP) {
         posP += offNP;
      }
   }

   float dstN = horzSpan ? pos.x - posN.x : pos.y - posN.y;
   float dstP = horzSpan ? posP.x - pos.x : posP.y - pos.y;
   bool directionN = dstN < dstP;
   lumaEndN = directionN ? lumaEndN : lumaEndP;

   if ( ((lumaM - lumaN) < 0.0) == ((lumaEndN - lumaN) < 0.0) ) {
      lengthSign = 0.0;
   }

   float spanLength = (dstP + dstN);
   dstN = directionN ? dstN : dstP;
   float subPixelOffset = (0.5 + (dstN * (-1.0/spanLength))) * lengthSign;


   subPixelOffset *= 2.0; //<-- KOKO, hack.

   vec2 smpco;

   if (horzSpan) {
      smpco.x = pos.x + 0.0;
      smpco.y = coords_NEAREST( pos, params.SourceSize ).y + subPixelOffset;
   } else {
      smpco.x = coords_NEAREST( pos, params.SourceSize ).x + subPixelOffset;
      smpco.y = pos.y + 0.0;
   }

   vec3 rgbF = textureLod_ovr(tex, smpco, 0.0).rgb;
   return FxaaLerp3(rgbL, rgbF, blendL);
}

void main() {

   #ifndef D3D_WORKAROUND
      if (is_skipped_frame())
         return;
   #endif

   vec4 pixel_out;
   pixel_out.rgb = texture_NEAREST(colortools_and_ntsc_pass, vTexCoord, params.SourceSize).rgb;

   pixel_out.a = texture(colortools_and_ntsc_pass, vTexCoord).a;//, params.SourceSize).a;

   // If we need to smooth waterfalls, it is good to smooth
   // their detection mask too, maybe using an higher lod ist good tho,
   // but we still require linear sampling.
   pixel_out.a = 0.0;
   if (DO_WTFL > 0.5) {
      pixel_out.a = texture(colortools_and_ntsc_pass, vTexCoord).a;
   }


/*   if (DO_FXAA == 1.0) {
      //pixel_out.rgb = FxaaPixelShader(vTexCoord, Source, params.SourceSize, params.OutputSize); // yes linearization
      pixel_out.rgb = aa_ddtxbrlv1(Source, vTexCoord, vxt1); // yes linearization
      //pixel_out.rgb = aa_2xscalehq(Source, vTexCoord , vhqt1, vhqt2, vhqt3, vhqt4); //no linearization
      //pixel_out.rgb = aa_scale2xplus(Source, vTexCoord, vpt1, vpt2); // no linearization
      //pixel_out.rgb = aa_super2x_sai(Source, vTexCoord); §// ?? linearization
	}
*/

   float border = 0.0;
   if (DO_FXAA > 0.0) {
      vec3 pix = texture(colortools_and_ntsc_pass,vTexCoord).rgb;
      border = dot(fwidth(pix).rgb,vec3(1.0));
      border = clamp(border, 0,3.0);
   }

   #define TRESHOLD_AA 0.05 //speedup by skipping uniform zones.

   if (border >= TRESHOLD_AA) {
      if (DO_FXAA == 1.0) {
         pixel_out.rgb = FxaaPixelShader(vTexCoord, colortools_and_ntsc_pass, params.SourceSize, params.OutputSize);
      } else
      if (DO_FXAA == 2.0) {
         pixel_out.rgb = aa_ddtxbrlv1(colortools_and_ntsc_pass, vTexCoord, vxt1);
      } else
      if (DO_FXAA == 3.0) {
         pixel_out.rgb = aa_2xbrz(colortools_and_ntsc_pass, vTexCoord);
      }
   } 

/*
   if (DO_FXAA == 1.0) {
      pixel_out.rgb = FxaaPixelShader(vTexCoord, colortools_and_ntsc_pass, params.SourceSize, params.OutputSize);
   } else
   if (DO_FXAA == 2.0) {
      pixel_out.rgb = aa_ddtxbrlv1(colortools_and_ntsc_pass, vTexCoord, vxt1);
   } else
   if (DO_FXAA == 3.0) {
      pixel_out.rgb =  aa_2xscalehq(colortools_and_ntsc_pass, vTexCoord , vhqt1, vhqt2, vhqt3, vhqt4);
   } else
   if (DO_FXAA == 4.0) {
      pixel_out.rgb = aa_scale2xplus(colortools_and_ntsc_pass, vTexCoord, vpt1, vpt2);
   } else
   if (DO_FXAA == 5.0) {
      pixel_out.rgb = aa_super2x_sai(colortools_and_ntsc_pass, vTexCoord);
   }

*/

   if ( !bdelta_render_enabled() ) {
      if (vDo_flickering==1.0)
         pixel_out.rgb = pixel_flickering(pixel_out.rgb).rgb;


      if (DO_RF_NOISE > 0.01 ) {
         //Unfortunately we need to clamp to min 0.0 again after applying noise
         //to avoid glitches on amd (and probably nvidia too).
         //It should be possible to change the noise function to just emit positive
         //numbers and pre-lowering the brightness of pixel_out in the very first pass tho.

            float rfnoise = get_rf_noise(vDynamicSeed_noise);
            pixel_out.rgb += rfnoise;
            pixel_out.rgb = max(pixel_out.rgb, vec3(0.0));
      }
   }

    //pixel_out.rgb = max(vec3(0.0), pixel_out.rgb);

   FragColor = pixel_out;

}
