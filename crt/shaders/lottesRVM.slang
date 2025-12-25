#version 450

////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________
//==============================================================
//
//
//             [RVM] RETRO VIDEO MONITOR - v20210519
//                         _
//                     by  |imothy Lottes
//
//
//==============================================================
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________
//==============================================================
//
//                           ABOUT
//
//--------------------------------------------------------------
// RVM is a CRT stylized up-sampler with three modes
// RVM requires linear color inputs {0.0 to 1.0} ranged
// Non-integer scaling works best
// Using RVM_WARP also improves output
//--------------------------------------------------------------
// RVM_MODE 0
// ==========
// Designed for '240p' and similar input resolutions
// Meaning 4x or more scaling on a dimension
// So a 1080p output needs to have <= 270 pix height input
// Inspired by Sony PVM and BVM display output
// No grille, instead focusing on scanlines
// Scanline thickness is variable to simulate phosphor bloom
// Scanline thickness is highest at color peak
// Output intensity increases to normalize out scan thining
// Thus there is only a slight reduction in peak brightness
//--------------------------------------------------------------
// RVM_MODE 1
// ==========
// Designed for '480p' and similar input resolutions
// No visible scanlines, instead this focuses on grille
// Inspired by Sony Wega TV display output
// Filters mostly vertical since grille masks the horizontal
// Using similar normalization tick to maintain peak brightness 
//--------------------------------------------------------------
// RVM_MODE 2
// ==========
// Same as mode 1 except this has a slot mask instead of grille
// Inspired by vintage arcade CRTs [disabled because it looked exactly like 1]
//--------------------------------------------------------------
// TODO
// ====
// - This is an initial prototype
// - Currently only tested for RVM_32BIT and RVM_GLSL
// - HLSL and 16BIT paths might have bugs [removed from slang]
// - Put in approximations
//==============================================================
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________
//==============================================================
//
//          LICENSE = UNLICENSE (aka PUBLIC DOMAIN)
//
//--------------------------------------------------------------
// This is free and unencumbered software released into the 
// public domain.
//--------------------------------------------------------------
// Anyone is free to copy, modify, publish, use, compile, sell, 
// or distribute this software, either in source code form or as
// a compiled binary, for any purpose, commercial or 
// non-commercial, and by any means.
//--------------------------------------------------------------
// In jurisdictions that recognize copyright laws, the author or
// authors of this software dedicate any and all copyright 
// interest in the software to the public domain. We make this
// dedication for the benefit of the public at large and to the
// detriment of our heirs and successors. We intend this 
// dedication to be an overt act of relinquishment in perpetuity
// of all present and future rights to this software under 
// copyright law.
//--------------------------------------------------------------
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
// KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE 
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
// PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
// AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
// DEALINGS IN THE SOFTWARE.
//--------------------------------------------------------------
// For more information, please refer to 
// <http://unlicense.org/>
//==============================================================
////////////////////////////////////////////////////////////////

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float RVM_MODE_param, RVM_WARP_param, INPUT_BLUR_param, RVM_DARK_param,
	   RVM_SCAN_DIV_param, RVM_SCAN_MAX_param, RVM_linear_in, RVM_linear_out,
	   RVM_mask_mode_param;
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
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define iChannel0 Source
#define iResolution params.OutputSize.xy
#define iFrame params.FrameCount
#define fragCoord (params.OutputSize.xy * vTexCoord.xy)

//_____________________________/\_______________________________
//==============================================================
//                      SETUP FOR RVM
//--------------------------------------------------------------
// Example of integrating
// What to do before including header (below)
//==============================================================
// Modes {0:=BVM/PVM 240p-like,1:=Wega TV 480p-like,2:=arcade}
//#define RVM_MODE 2
#pragma parameter RVM_MODE_param "Scanline Mode (240p, 480p)" 0.0 0.0 1.0 1.0
int RVM_MODE = int(params.RVM_MODE_param);
#pragma parameter RVM_mask_mode_param "Mask Mode (None, Aperture, Slot)" 2.0 0.0 2.0 1.0
int RVM_MASK = int(params.RVM_mask_mode_param);
// Select portability paths
#define RVM_GLSL 1
// #define RVM_HLSL 1
// Select 32-bit or packed 16-bit source path
#define RVM_32BIT 1
// Debug pixels
// TODO: Actually RVM_ZOOM is currently broken (sorry)
//#define RVM_ZOOM 1
// Toggle on/off warping of screen
//#define RVM_WARP 1
#pragma parameter RVM_WARP_param "RVM Warp (Screen Curvature)" 1.0 0.0 1.0 1.0
bool RVM_WARP = bool(params.RVM_WARP_param);

#pragma parameter RVM_DARK_param "RVM Brightness" 0.875 0.005 1.505 0.01
float RVM_DARK = params.RVM_DARK_param;

#pragma parameter RVM_SCAN_DIV_param "RVM Scan Gap" 3.0 0.01 5.0 0.1
float RVM_SCAN_DIV = params.RVM_SCAN_DIV_param;

#pragma parameter RVM_SCAN_MAX_param "RVM Scan Max" 0.53 0.01 1.0 0.01
float RVM_SCAN_MAX = params.RVM_SCAN_MAX_param;
// Debug split line position (comment out to remove)
//#define RVM_SPLIT 960
//_____________________________/\_______________________________
//==============================================================
//      SPECIFIC TO SHADERTOY EXAMPLE [modified for slang]
//==============================================================
// Horizonal scan blur
//  0.50 := blurry
//  0.75 := default
//  1.00 := blocky
//#define INPUT_BLUR 0.75
#pragma parameter INPUT_BLUR_param "RVM Input Blur" 0.75 0.5 1.0 0.01
float INPUT_BLUR = params.INPUT_BLUR_param;
//--------------------------------------------------------------
// Since shadertoy doesn't have sRGB textures
// And we need linear input into shader
// Don't do this in your code [we'll provide the option at runtime]
#pragma parameter RVM_linear_in "Input Is Linearized?" 0.0 0.0 1.0 1.0
bool RVM_input_is_linear = bool(params.RVM_linear_in);

#pragma parameter RVM_linear_out "Output Should Be Linear?" 0.0 0.0 1.0 1.0
bool RVM_output_is_linear = bool(params.RVM_linear_out);

float FromSrgb1(float c){
 return (RVM_input_is_linear) ? c : (c<=0.04045)?c*(1.0/12.92):
  pow(c*(1.0/1.055)+(0.055/1.055),2.4);}
//--------------------------------------------------------------
vec3 FromSrgb(vec3 c){
 return (RVM_input_is_linear) ? c : vec3(
 FromSrgb1(c.r),FromSrgb1(c.g),FromSrgb1(c.b));}
//--------------------------------------------------------------
// [add a 4-component version, since we can gather]
vec4 FromSrgb4(vec4 c){
 return (RVM_input_is_linear) ? c : vec4(
 FromSrgb1(c.x),FromSrgb1(c.y),FromSrgb1(c.z),FromSrgb1(c.w));}
//--------------------------------------------------------------
// Output pixels per input pixel (can be fractional)
// Enables consistent output regardless of viewport size
//#if RVM_MODE==0
// #define INPUT_DOT 4.8
//#else
// #define INPUT_DOT 2.8
//#endif
// [scale image to fit the screen]
float INPUT_DOT_X = params.OutputSize.x * params.SourceSize.z;
float INPUT_DOT_Y = params.OutputSize.y * params.SourceSize.w;
//--------------------------------------------------------------
// Setup the function which returns gather4 results
// Have to emulate gather4 as ShaderToy doesn't support it [but slang does!]
// Gather 4 ordering
//  W Z
//  X Y
vec4 RvmR4F(vec2 uv){
 // For shadertoy, scale to get native texels in the image
 uv*=iResolution.xy/vec2(INPUT_DOT_X,INPUT_DOT_Y);
 vec2 px=vec2(1.0,1.0)/params.SourceSize.xy;//iChannelResolution[0].xy;
 uv*=px;
 px*=0.5;
 vec4 o;
 o = FromSrgb4(textureGather(iChannel0,uv,0));
 return o;}
//
vec4 RvmG4F(vec2 uv){
 // For shadertoy, scale to get native texels in the image
 uv*=iResolution.xy/vec2(INPUT_DOT_X,INPUT_DOT_Y);
 vec2 px=vec2(1.0,1.0)/params.SourceSize.xy;//iChannelResolution[0].xy;
 uv*=px;
 px*=0.5;
 vec4 o;
 o = FromSrgb4(textureGather(iChannel0,uv,1));
 return o;}
//
vec4 RvmB4F(vec2 uv){
 // For shadertoy, scale to get native texels in the image
 uv*=iResolution.xy/vec2(INPUT_DOT_X,INPUT_DOT_Y);
 vec2 px=vec2(1.0,1.0)/params.SourceSize.xy;//iChannelResolution[0].xy;
 uv*=px;
 px*=0.5;
 vec4 o;
 o = FromSrgb4(textureGather(iChannel0,uv,2));
 return o;}

//_______________________BEGIN_HEADER___________________________

#include "../crt-effects/shaders/energy_conservation_scanlines.h"
#include "../crt-effects/shaders/energy_conservation_mask.h"

//________________________END_HEADER____________________________


//_____________________________/\_______________________________
//==============================================================
//                    USE HEADER IN SHADER
//--------------------------------------------------------------
// Example of integrating
// What to do after including header
//==============================================================
// Convert from linear to sRGB
// Since shader toy output is not linear [optional in slang]
float ToSrgb1(float c){
 return(c<0.0031308?c*12.92:1.055*pow(c,0.41666)-0.055);}
//--------------------------------------------------------------
vec3 ToSrgb(vec3 c){
 return (RVM_output_is_linear) ? c : vec3(
 ToSrgb1(c.r),ToSrgb1(c.g),ToSrgb1(c.b));}
//--------------------------------------------------------------

vec2 ratios(){
//  #if RVM_MODE==0
if(RVM_MODE == 0) return vec2(1.0/256.0,1.0/24.0);
//  #endif
//  #if RVM_MODE==1
if(RVM_MODE == 1) return vec2(1.0/4096.0,1.0/24.0);
//  #endif
//  #if RVM_MODE==2
if(RVM_MODE == 2) return vec2(1.0/48.0,1.0/24.0);
//  #endif
}

vec4 RVM(vec2 coord){
 vec2 res=iResolution.xy/vec2(INPUT_DOT_X,INPUT_DOT_Y);
 vec4 fragColor = vec4(0.0);
 fragColor.rgb=energy_conservation_scanlines(
  coord.xy,           // ipos
  res/iResolution.xy, // inputSizeDivOutputSize
  res*vec2(0.5,0.5),  // halfInputSize
  1.0/res,            // rcpInputSize
  2.0/iResolution.xy, // twoDivOutputSize
  res.y,
  ratios(),
  INPUT_BLUR,
  RvmF4(0.5*INPUT_BLUR,-0.5*INPUT_BLUR,-1.5*INPUT_BLUR,-2.5*INPUT_BLUR));
  fragColor.rgb = energy_conservation_mask(fragColor.rgb, coord.xy);
 // Shadertoy outputs non-linear color [slang may or may not]
 return vec4(ToSrgb(fragColor.rgb), 1.0);}

void main()
{
   FragColor = RVM(vTexCoord.xy*params.OutputSize.xy);
}
