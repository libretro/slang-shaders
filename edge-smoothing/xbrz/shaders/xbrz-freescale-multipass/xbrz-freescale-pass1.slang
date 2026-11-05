#version 450
// xBRZ freescale, multipass: xBRZ at any scale factor, in three passes.
//
// Two optional rules, both off by default (plain xBRZ); the xbrz-crisp preset turns them on:
// - XBRZ_MINC (crisp: 20) leaves a corner square when its two colors differ by less than this
//   (x/255, YCbCr distance), so soft shading and textures keep their pixels.
// - XBRZ_DIAG (crisp: 100) leaves a corner square when the two colors its cut would join differ
//   by more than this, so a junction of three colors is not pulled into a fake diagonal (an idea
//   from torcado's cleanEdge, MIT license). Antialiasing ramps use 92, shallow and steep lines are
//   only blocked when they would cut a pixel with a lighter color, a blocked corner is still cut
//   when a neighbour on the same diagonal is cut or at the tip of a 1-pixel diagonal stripe, a cut
//   between two close inner tones runs up to a darker outline, a corner whose blend color runs
//   straight on stays square, two dark strokes meeting in an L around a light gap (an eye) are
//   not joined, and where 1-pixel stripes end flush (gauges, health bars) the end corners stay
//   square.
//   The shallow and steep line tests also weigh hue a little more than lightness (1.2x).
//   A pixel closed in a row between two near-black outline pixels is not pulled out of it.
//   A corner left square by XBRZ_MINC on a long straight line between two stripes is still cut,
//   the notch where a near-black shadow runs under an object is closed, and a blocked corner
//   between 1-pixel tiles in a row between two walls stays square.
//
// The first pass makes every blend decision once per input pixel (blend type, line type, blend
// color and the minimum contrast) and the resolve pass, also once per input pixel, settles the
// ones that depend on the neighbours' decisions, so the output pass, which runs once per output
// pixel, only reads two textures where no corner is cut. Blend color ties and the order of the
// four corners follow the reference C++ xBRZ, and the output pass reads the image from the pass
// before xBRZ, so it also works after other shaders in a preset.
// Defaults: equal color tolerance 15, dominant direction 3.8, steep/shallow line 3.2
// (reference xBRZ: 30, 3.6 and 2.2).
/*
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

// Pass 1 of xbrz-freescale-multipass (Vulkan / slang)

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 xbrz_fs_refpassSize;
	vec4 OutputSize;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
#define FRAG_OUT FragColor
layout(set = 0, binding = 2) uniform sampler2D Source;
// the input of the first pass (the preset's reference pass), which is the original image unless
// other shaders run before xBRZ
layout(set = 0, binding = 3) uniform sampler2D xbrz_fs_refpass;
#define ORIG_SIZE params.xbrz_fs_refpassSize
#define P(x,y) texture(xbrz_fs_refpass, coord + ORIG_SIZE.zw * vec2(x, y)).rgb
#define OUT_SIZE params.OutputSize
#define ORIG_INPUT_SIZE ORIG_SIZE
#define INFO(uv) texture(Source, uv)
#define INFO_STEP ORIG_SIZE.zw

float distYCbCr(vec3 pixA, vec3 pixB)
{
  const vec3 w = vec3(0.2627, 0.6780, 0.0593);
  vec3 diff = pixA - pixB;
  float Y = dot(diff, w);
  float Cb = 0.5 / (1.0 - 0.0593) * (diff.b - Y);
  float Cr = 0.5 / (1.0 - 0.2627) * (diff.r - Y);
  return sqrt(Y * Y + Cb * Cb + Cr * Cr);
}

float get_left_ratio(vec2 center, vec2 origin, vec2 direction, vec2 scale)
{
  vec2 P0 = center - origin;
  vec2 proj = direction * (dot(P0, direction) / dot(direction, direction));
  vec2 distv = P0 - proj;
  vec2 orth = vec2(-direction.y, direction.x);
  float side = sign(dot(P0, orth));
  float v = side * length(distv * scale);
  return smoothstep(-sqrt(2.0)/2.0, sqrt(2.0)/2.0, v);
}

// the first pass's decisions for the four corners of the pixel at (x, y) from E; see the decision
// word in pass 0 (BLEND is the blend type, FLAG(r, f) one of its flags)
#define INFO_AT(x, y) floor(INFO(coord + vec2(x, y) * INFO_STEP) * 255.0 + 0.5)
#define BLEND(r) mod(r, 4.0)
#define FLAG(r, f) mod(floor((r) / (f)), 2.0)

void main()
{
  //---------------------------------------
  // Input Pixel Mapping: -|B|-
  //                      D|E|F
  //                      -|H|-

  vec2 scale = OUT_SIZE.xy / ORIG_INPUT_SIZE.xy;
  vec2 pos = fract(vTexCoord * ORIG_SIZE.xy) - vec2(0.5, 0.5);
  vec2 coord = vTexCoord - pos * ORIG_SIZE.zw;

  vec4 info = INFO_AT(0.0, 0.0);
  vec3 E = P( 0., 0.);
  vec3 res = E;

  // info Mapping: x|y|
  //               w|z|
  vec4 blendResult = BLEND(info);

  // the decisions are final: the resolve pass applied the parts of rules 1, 2 and 9 that need the neighbours

  // most output pixels have no corner to blend, and only need these two reads
  if (blendResult.x + blendResult.y + blendResult.z + blendResult.w <= 0.0)
  {
    FRAG_OUT = vec4(res, 1.0);
    return;
  }

  vec4 doLineBlend = FLAG(info, 4.0);
  vec4 secondPix = FLAG(info, 8.0);
  vec4 haveShallowLine = FLAG(info, 16.0);
  vec4 haveSteepLine = FLAG(info, 64.0);

  // ============================================================================================
  // xBRZ: drawing the corners
  // ============================================================================================
  // Corners are applied in the same order as the original xBRZ (0, 90, 180, 270 degrees). The first
  // pass picked each blend colour ("dist(e,f) <= dist(e,h) ? f : h").

  // Pixel Tap Mapping: -|-|-
  //                    -|E|F
  //                    -|H|-
  if(blendResult.z > 0.0)
  {
    vec2 origin = vec2(0.0, 1.0 / sqrt(2.0));
    vec2 direction = vec2(1.0, -1.0);
    if(doLineBlend.z > 0.0)
    {
      origin = haveShallowLine.z > 0.0? vec2(0.0, 0.25) : vec2(0.0, 0.5);
      direction.x += haveShallowLine.z;
      direction.y -= haveSteepLine.z;
    }
    vec3 blendPix = (secondPix.z > 0.0) ? P( 0., 1.) : P( 1., 0.);
    res = mix(res, blendPix, get_left_ratio(pos, origin, direction, scale));
  }

  // Pixel Tap Mapping: -|B|-
  //                    -|E|F
  //                    -|-|-
  if(blendResult.y > 0.0)
  {
    vec2 origin = vec2(1.0 / sqrt(2.0), 0.0);
    vec2 direction = vec2(-1.0, -1.0);
    if(doLineBlend.y > 0.0)
    {
      origin = haveShallowLine.y > 0.0? vec2(0.25, 0.0) : vec2(0.5, 0.0);
      direction.y -= haveShallowLine.y;
      direction.x -= haveSteepLine.y;
    }
    vec3 blendPix = (secondPix.y > 0.0) ? P( 1., 0.) : P( 0.,-1.);
    res = mix(res, blendPix, get_left_ratio(pos, origin, direction, scale));
  }

  // Pixel Tap Mapping: -|B|-
  //                    D|E|-
  //                    -|-|-
  if(blendResult.x > 0.0)
  {
    vec2 origin = vec2(0.0, -1.0 / sqrt(2.0));
    vec2 direction = vec2(-1.0, 1.0);
    if(doLineBlend.x > 0.0)
    {
      origin = haveShallowLine.x > 0.0? vec2(0.0, -0.25) : vec2(0.0, -0.5);
      direction.x -= haveShallowLine.x;
      direction.y += haveSteepLine.x;
    }
    vec3 blendPix = (secondPix.x > 0.0) ? P( 0.,-1.) : P(-1., 0.);
    res = mix(res, blendPix, get_left_ratio(pos, origin, direction, scale));
  }

  // Pixel Tap Mapping: -|-|-
  //                    D|E|-
  //                    -|H|-
  if(blendResult.w > 0.0)
  {
    vec2 origin = vec2(-1.0 / sqrt(2.0), 0.0);
    vec2 direction = vec2(1.0, 1.0);
    if(doLineBlend.w > 0.0)
    {
      origin = haveShallowLine.w > 0.0? vec2(-0.25, 0.0) : vec2(-0.5, 0.0);
      direction.y += haveShallowLine.w;
      direction.x += haveSteepLine.w;
    }
    vec3 blendPix = (secondPix.w > 0.0) ? P(-1., 0.) : P( 0., 1.);
    res = mix(res, blendPix, get_left_ratio(pos, origin, direction, scale));
  }

  FRAG_OUT = vec4(res, 1.0);
}
