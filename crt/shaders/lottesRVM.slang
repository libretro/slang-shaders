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
//                 ported to slang by hunterk
//
//
//==============================================================
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________
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
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________
//
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
// Inspired by vintage arcade CRTs
//--------------------------------------------------------------
// TODO
// ====
// - This is an initial prototype
// - Currently only tested for RVM_32BIT and RVM_GLSL
// - HLSL and 16BIT paths might have bugs
// - Put in approximations
//==============================================================
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 FinalViewportSize;
	vec4 OutputSize;
	uint FrameCount;
	float MODE_param, WARP_param, DARK_param, SCAN_DIV_param,
	   SCAN_MAX_param, INPUT_BLUR_param, MASK_MODE_param;
} params;

//_____________________________/\_______________________________
//==============================================================
//                      SETUP FOR RVM
//--------------------------------------------------------------
//==============================================================
// Modes {0:=BVM/PVM 240p-like,1:=Wega TV 480p-like,2:=arcade}
#pragma parameter MODE_param "Res Mode (low, high, mid)" 2.0 0.0 2.0 1.0
int RVM_MODE = int(params.MODE_param);
// Select portability paths
#define RVM_GLSL 1
// #define RVM_HLSL 1
// Select 32-bit or packed 16-bit source path
#define RVM_32BIT 1
// Debug pixels
// TODO: Actually RVM_ZOOM is currently broken (sorry)
//#define RVM_ZOOM 1
// Toggle on/off warping of screen
#pragma parameter WARP_param "RVM Warp Toggle" 1.0 0.0 1.0 1.0
float RVM_WARP = params.WARP_param;
//#define RVM_WARP 1
// Debug split line position (comment out to remove)
//#define RVM_SPLIT 200

// add independent mask control
#pragma parameter MASK_MODE_param "Mask (0=auto, 1=aperture, 2=slot)" 0.0 0.0 2.0 1.0
float MASK_MODE = (int(params.MASK_MODE_param) == 0) ? RVM_MODE : int(params.MASK_MODE_param);

////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________
//==============================================================
//                        FILTER CONTROL
//==============================================================
//#define RVM_DARK (7.0/8.0)
#pragma parameter DARK_param "RVM Dark" 7.0 1.0 16.0 1.0
float RVM_DARK = params.DARK_param / 8.0;
//#define RVM_SCAN_DIV 3.0
#pragma parameter SCAN_DIV_param "RVM Scanline Division" 3.0 1.0 8.0 0.1
float RVM_SCAN_DIV = params.SCAN_DIV_param;
//#define RVM_SCAN_MAX (8.0/15.0)
#pragma parameter SCAN_MAX_param "RVM Scanline Max" 8.0 1.0 25.0 0.25
float RVM_SCAN_MAX = params.SCAN_MAX_param / 15.0;
#define RVM_SCAN_MIN (RVM_SCAN_DIV*RVM_SCAN_MAX)
#define RVM_SCAN_SIZ (RVM_SCAN_MAX-RVM_SCAN_MIN)
#pragma parameter INPUT_BLUR_param "RVM Input Blur" 0.25 0.01 1.0 0.01
float INPUT_BLUR = 1.0 - params.INPUT_BLUR_param;
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________

// Output pixels per input pixel (can be fractional)
// Enables consistent output regardless of viewport size
#define INPUT_DOT (params.OutputSize.y * params.SourceSize.w)
#define INPUT_DOT_X (params.OutputSize.x * params.SourceSize.z)
//_____________________________/\_______________________________

vec2 iResolution = params.OutputSize.xy;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

//_____________________________.._______________________________
//==============================================================
//                         PORTABILITY
//==============================================================
#define RVM_2PI 6.28318530718
//--------------------------------------------------------------
#ifdef RVM_GLSL
 #define RvmF1 float
 #define RvmF2 vec2
 #define RvmF2_(x) vec2((x),(x))
 #define RvmF3 vec3
 #define RvmF3_(x) vec3((x),(x),(x))
 #define RvmF4 vec4
 #define RvmU1 uint
 #define RvmFractF1 fract
 // As close to the V_COS_F32 as possible without intrinsic
 #define RvmNCosF2(x) cos((x)*RvmF2_(RVM_2PI))
 #define RvmRcpF1(x) (1.0/(x))
 #define RvmRcpF2(x) (RvmF2_(1.0)/(x))
 #define RvmRcpF3(x) (RvmF3_(1.0)/(x))
 #define RvmSatF1(x) clamp((x),0.0,1.0)
 #define RvmSatF2(x) clamp((x),0.0,1.0)
//--------------------------------------------------------------
 RvmF1 RvmMax3F1(RvmF1 a,RvmF1 b,RvmF1 c){
  return max(a,max(b,c));}
//--------------------------------------------------------------
 RvmF2 RvmMax3F2(RvmF2 a,RvmF2 b,RvmF2 c){
  return max(a,max(b,c));}
//--------------------------------------------------------------
 #ifdef RVM_16BIT
  #define RvmH1 float16_t
  #define RvmH2 f16vec2
  #define RvmH2_(x) f16vec2((x),(x))
  #define RvmH3 f16vec3
  #define RvmH3_(x) f16vec3((x),(x),(x))
  #define RvmH4 f16vec4
  #define RvmFractH1 fract
  #define RvmNCosH2(x) cos((x)*RvmH2_(RVM_2PI))
  #define RvmRcpH1(x) (RvmH1(1.0)/(x))
  #define RvmRcpH2(x) (RvmH2_(1.0)/(x))
  #define RvmRcpH3(x) (RvmH3_(1.0)/(x))
  #define RvmSatH1(x) clamp((x),RvmH1(0.0),RvmH1(1.0))
  #define RvmSatH2(x) clamp((x),RvmH2(0.0,0.0),RvmH2(1.0,1.0))
//--------------------------------------------------------------
  RvmH1 RvmMax3H1(RvmH1 a,RvmH1 b,RvmH1 c){
   return max(a,max(b,c));}
//--------------------------------------------------------------
  RvmH2 RvmMax3H2(RvmH2 a,RvmH2 b,RvmH2 c){
   return max(a,max(b,c));}
//--------------------------------------------------------------
 #endif
#endif

// leaving the HLSL compat part off

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

//--------------------------------------------------------------
// Setup the function which returns gather4 results
// Have to emulate gather4 as ShaderToy doesn't support it
// Gather 4 ordering
//  W Z
//  X Y
vec4 RvmR4F(vec2 uv){
 // For shadertoy, scale to get native texels in the image
 uv*=iResolution.xy/vec2(INPUT_DOT_X,INPUT_DOT);
 vec2 px=params.SourceSize.zw;//vec2(1.0,1.0)/iChannelResolution[0].xy;
 uv*=px;
 px*=0.5;
 vec4 o;
 /*
 o.w=FromSrgb1(textureLod(iChannel0,uv.xy+vec2(-px.x,-px.y),0.0).r);
 o.z=FromSrgb1(textureLod(iChannel0,uv.xy+vec2( px.x,-px.y),0.0).r);
 o.x=FromSrgb1(textureLod(iChannel0,uv.xy+vec2(-px.x, px.y),0.0).r);
 o.y=FromSrgb1(textureLod(iChannel0,uv.xy+vec2( px.x, px.y),0.0).r);
 */
 o.w=textureLod(Source,uv.xy+vec2(-px.x,-px.y),0.0).r;
 o.z=textureLod(Source,uv.xy+vec2( px.x,-px.y),0.0).r;
 o.x=textureLod(Source,uv.xy+vec2(-px.x, px.y),0.0).r;
 o.y=textureLod(Source,uv.xy+vec2( px.x, px.y),0.0).r;
 return o;}
//
vec4 RvmG4F(vec2 uv){
 // For shadertoy, scale to get native texels in the image
 uv*=iResolution.xy/vec2(INPUT_DOT_X,INPUT_DOT);
 vec2 px=params.SourceSize.zw;//vec2(1.0,1.0)/iChannelResolution[0].xy;
 uv*=px;
 px*=0.5;
 vec4 o;
 /*
 o.w=FromSrgb1(textureLod(iChannel0,uv.xy+vec2(-px.x,-px.y),0.0).g);
 o.z=FromSrgb1(textureLod(iChannel0,uv.xy+vec2( px.x,-px.y),0.0).g);
 o.x=FromSrgb1(textureLod(iChannel0,uv.xy+vec2(-px.x, px.y),0.0).g);
 o.y=FromSrgb1(textureLod(iChannel0,uv.xy+vec2( px.x, px.y),0.0).g);
 */
 o.w=textureLod(Source,uv.xy+vec2(-px.x,-px.y),0.0).g;
 o.z=textureLod(Source,uv.xy+vec2( px.x,-px.y),0.0).g;
 o.x=textureLod(Source,uv.xy+vec2(-px.x, px.y),0.0).g;
 o.y=textureLod(Source,uv.xy+vec2( px.x, px.y),0.0).g;
 return o;}
//
vec4 RvmB4F(vec2 uv){
 // For shadertoy, scale to get native texels in the image
 uv*=iResolution.xy/vec2(INPUT_DOT_X,INPUT_DOT);
 vec2 px=params.SourceSize.zw;//vec2(1.0,1.0)/iChannelResolution[0].xy;
 uv*=px;
 px*=0.5;
 vec4 o;
 /*
 o.w=FromSrgb1(textureLod(iChannel0,uv.xy+vec2(-px.x,-px.y),0.0).b);
 o.z=FromSrgb1(textureLod(iChannel0,uv.xy+vec2( px.x,-px.y),0.0).b);
 o.x=FromSrgb1(textureLod(iChannel0,uv.xy+vec2(-px.x, px.y),0.0).b);
 o.y=FromSrgb1(textureLod(iChannel0,uv.xy+vec2( px.x, px.y),0.0).b);
 */
 o.w=textureLod(Source,uv.xy+vec2(-px.x,-px.y),0.0).b;
 o.z=textureLod(Source,uv.xy+vec2( px.x,-px.y),0.0).b;
 o.x=textureLod(Source,uv.xy+vec2(-px.x, px.y),0.0).b;
 o.y=textureLod(Source,uv.xy+vec2( px.x, px.y),0.0).b;
 return o;}

//==============================================================
//                     FILTER ENTRY F32
//--------------------------------------------------------------
// Input must be linear {0.0 to 1.0}
// Output color is linear
//==============================================================
#ifdef RVM_32BIT
 // Paired gaussian approximation
 RvmF2 RvmPolyF2(RvmF2 x){
  x=RvmSatF2(-x*x+RvmF2(1.0,1.0));return x*x;}
//==============================================================
 RvmF3 RvmF(
//--------------------------------------------------------------
 // SV_POSITION, fragCoord.xy, etc
 RvmF2 ipos,
//--------------------------------------------------------------
 // inputSize / outputSize (in pixels)
 RvmF2 inputSizeDivOutputSize,     
//--------------------------------------------------------------
 // 0.5 * inputSize (in pixels)
 RvmF2 halfInputSize,
//--------------------------------------------------------------
 // 1.0 / inputSize (in pixels)
 RvmF2 rcpInputSize,
//--------------------------------------------------------------
 // 2.0 / outputSize (in pixels)
 RvmF2 twoDivOutputSize,   
//--------------------------------------------------------------
 // inputSize.y
 RvmF1 inputHeight,
//--------------------------------------------------------------
 // Warp scanlines
 //  0.0 = no warp
 //  1.0/64.0 = light warping
 //  1.0/32.0 = more warping
 // Want x and y warping to be different (based on aspect)
 RvmF2 warp,
//--------------------------------------------------------------
 // Control horizontal blur
 //  0.50 := blurry
 //  0.75 := default
 //  1.00 := blocky
 RvmF1 blur,
 // Derived constant {0.5*blur,-0.5*blur,-1.5*blur,-2.5*blur}
 RvmF4 blur4){
//--------------------------------------------------------------
  #ifdef RVM_ZOOM
   ipos=floor(ipos*RvmF2(0.5));
  #endif
//--------------------------------------------------------------
  // Optional apply warp
  RvmF2 pos;
  // initialize these to zero
  RvmF2 vin2 = RvmF2(0.0);
  RvmF1 vin  = RvmF1(0.0);
  if( bool(RVM_WARP)){
   // Convert to {-1 to 1} range
   pos=ipos*twoDivOutputSize-RvmF2_(1.0);
   // Distort pushes image outside {-1 to 1} range
   pos*=RvmF2_(1.0)+pos.yx*pos.yx*warp;
   // Vignette to kill off-image content
   vin2=RvmSatF2(pos*pos);  
   // 1-((1-x)*(1-y)) -> (1-x)*y+x
   vin=(RvmF1(1.0)-vin2.x)*vin2.y+vin2.x;
   vin=RvmSatF1((-vin)*inputHeight+inputHeight);   
   // Leave in {0 to inputSize}
   pos=pos*halfInputSize+halfInputSize;     
  }else{
   pos=ipos*inputSizeDivOutputSize;
  }
//--------------------------------------------------------------
  // initialize these to zero
  RvmF2 g, gp = RvmF2(0.0);
  // Get to center for first gather 4
  //  W Z W Z
  //  X Y X Y
  //#if RVM_MODE==0
  if(RVM_MODE == 0){
   g=floor(pos+RvmF2(-1.5,-0.5))+RvmF2_(1.0);
   gp=g*rcpInputSize;
   g.y-=RvmF1(0.5);
  }
  //#endif
//--------------------------------------------------------------
  // Get to center for first gather 4
  //  W Z
  //  X Y
  //  W Z
  //  X Y
  //#if RVM_MODE!=0
  else{
   g=floor(pos+RvmF2(-0.5,-1.5))+RvmF2_(1.0);
   gp=g*rcpInputSize;
   g.x-=RvmF1(0.5);
  }
  //#endif
//--------------------------------------------------------------
  // Using gather4 to keep in SoA form for packed 16-bit
  // Both 32-bit and 16-bit paths use same logic
  // Gather 4 ordering
  //  W Z
  //  X Y
  // 4x2 sampled footprint
  //  _S_ _T_
  //  W Z W Z
  //  X Y X Y
  // initialize these to zero
  RvmF4 colRS, colGS, colBS, colRT, colGT, colBT = RvmF4(0.0);
  //#if RVM_MODE==0
  if(RVM_MODE == 0){
   colRS=RvmR4F(gp);
   colGS=RvmG4F(gp);
   colBS=RvmB4F(gp);
   gp.x+=RvmF1(2.0*rcpInputSize.x);
   colRT=RvmR4F(gp);
   colGT=RvmG4F(gp);
   colBT=RvmB4F(gp);
  }
  //#endif
//--------------------------------------------------------------
  // 2x4 sampled footprint
  //  W Z |s
  //  X Y |s
  //  W Z :t
  //  X Y :t
  //#if RVM_MODE!=0
  else{
   colRS=RvmR4F(gp);
   colGS=RvmG4F(gp);
   colBS=RvmB4F(gp);
   gp.y+=RvmF1(2.0*rcpInputSize.y);
   colRT=RvmR4F(gp);
   colGT=RvmG4F(gp);
   colBT=RvmB4F(gp);
  }
  //#endif
//--------------------------------------------------------------
  // Debug view without effect
  #ifdef RVM_SPLIT
   if(ipos.x<RvmF1(RVM_SPLIT)){
    return RvmF3(colRS.z,colGS.z,colBS.z);}
  #endif
//--------------------------------------------------------------
  // Horizontal kernel is simple gaussian filter approximation
  // initialize these to zero
  RvmF1 offB = RvmF1(0.0);
  RvmF2 offS, offT, horS, horT = RvmF2(0.0);
  //#if RVM_MODE==0
  if(RVM_MODE == 0){
   offB=RvmF1(pos.x-g.x);
   offS=RvmF2(offB,offB)*RvmF2_(blur)+blur4.xy;
   offT=RvmF2(offB,offB)*RvmF2_(blur)+blur4.zw;
   horS=RvmPolyF2(offS);
   horT=RvmPolyF2(offT);
  }
  //#endif
//--------------------------------------------------------------
  // Vertical
  //#if RVM_MODE!=0
  else{
   offB=RvmF1(pos.y-g.y);
   offS=RvmF2(offB,offB)*RvmF2_(blur)+blur4.xy;
   offT=RvmF2(offB,offB)*RvmF2_(blur)+blur4.zw;
   horS=RvmPolyF2(offS);
   horT=RvmPolyF2(offT);
  }
  //#endif
//--------------------------------------------------------------
  // Get kernel totals and then rcp
  RvmF2 hor0=horS+horT;
  RvmF1 horD=RvmRcpF1(hor0.x+hor0.y);
//--------------------------------------------------------------
  // Get rid of off-screen pixels on edge
  //#ifdef RVM_WARP
  if(bool(RVM_WARP)){
   horD*=RvmF1(vin);
  }
  //#endif
//--------------------------------------------------------------
  // Apply horizontal filter, up and down sums
  // initialize these to zero
  RvmF2 colRL, colGL, colBL = RvmF2(0.0);
  //#if RVM_MODE==0
  if(RVM_MODE == 0){
   RvmF2 colRU2=colRS.wz*horS+colRT.wz*horT;
   RvmF2 colGU2=colGS.wz*horS+colGT.wz*horT;
   RvmF2 colBU2=colBS.wz*horS+colBT.wz*horT;
   RvmF2 colRD2=colRS.xy*horS+colRT.xy*horT;
   RvmF2 colGD2=colGS.xy*horS+colGT.xy*horT;
   RvmF2 colBD2=colBS.xy*horS+colBT.xy*horT;
//--------------------------------------------------------------
   // Pair total so that {x:=up, y:=down}
   // Expensive transpose from pairs of taps, to pairs of lines
   colRL=RvmF2(colRU2.x+colRU2.y,colRD2.x+colRD2.y);
   colGL=RvmF2(colGU2.x+colGU2.y,colGD2.x+colGD2.y);
   colBL=RvmF2(colBU2.x+colBU2.y,colBD2.x+colBD2.y);
  }
  //#endif
//--------------------------------------------------------------
  // Apply vertical filter
  //#if RVM_MODE!=0
  else{
   colRL=colRS.wz*horS.xx+colRS.xy*horS.yy+
               colRT.wz*horT.xx+colRT.xy*horT.yy;  
   colGL=colGS.wz*horS.xx+colGS.xy*horS.yy+
               colGT.wz*horT.xx+colGT.xy*horT.yy;  
   colBL=colBS.wz*horS.xx+colBS.xy*horS.yy+
               colBT.wz*horT.xx+colBT.xy*horT.yy;
  }
  //#endif
//--------------------------------------------------------------
  // Normalize by kernel total
  colRL*=RvmF2_(horD);
  colGL*=RvmF2_(horD);
  colBL*=RvmF2_(horD);
//--------------------------------------------------------------
  // initialize these to zero
  RvmF2 scnL, colML = RvmF2(0.0);
  //#if RVM_MODE==0
  if(RVM_MODE == 0){
   // Get channel maximums and shape
   colML=RvmMax3F2(colRL,colGL,colBL);
   // TODO: Approximation...
   colML=sqrt(colML);
//--------------------------------------------------------------
   // Convert shaped channel maximums into scan width
   scnL=colML*RvmF2_(RVM_SCAN_SIZ)+RvmF2_(RVM_SCAN_MIN);
   RvmF1 offY=RvmF1(pos.y-g.y);
   scnL.x=( offY)*scnL.x;  
   scnL.y=(-offY)*scnL.y+scnL.y;  
   scnL=min(RvmF2_(0.5),scnL);
   scnL=RvmNCosF2(scnL);
   scnL=scnL*RvmF2_(0.5)+RvmF2_(0.5);
//--------------------------------------------------------------
   // Normalize for reduction in scan width
   RvmF2 nrmL=RvmF2_(1.0)-colML;
   nrmL=nrmL*RvmF2_(RVM_SCAN_MIN/RVM_SCAN_MAX-1.0)+RvmF2_(1.0);
   scnL*=nrmL;
  }
  //#endif
//--------------------------------------------------------------
  //#if RVM_MODE!=0
  else{
   RvmF1 offX=RvmF1(pos.x-g.x);
   scnL=RvmF2(RvmF1(1.0)-offX,offX);
  }
  //#endif
//--------------------------------------------------------------
  // Apply scan
  colRL*=scnL; 
  colGL*=scnL;   
  colBL*=scnL;
//--------------------------------------------------------------
  // Merge contribution from both nearest lines
  RvmF3 col;
  col.r=colRL.x+colRL.y;
  col.g=colGL.x+colGL.y;
  col.b=colBL.x+colBL.y;
//--------------------------------------------------------------
  // Grille
  //#if RVM_MODE==1
  if(MASK_MODE == 1){
   RvmF1 lim=RvmF1(1.0/((1.0/3.0)+(2.0/3.0)*RVM_DARK));
   RvmF3 colD=col*col;
   colD*=RVM_DARK;
   RvmF3 amp=RvmRcpF3(
    RvmF3_(lim*1.0/3.0)+RvmF3_(lim*2.0/3.0)*col);
   ipos.x=RvmFractF1(ipos.x*RvmF1(1.0/3.0));
   col*=amp;colD*=amp;
   if(     ipos.x<RvmF1(1.0/3.0)){colD.r=col.r;}
   else if(ipos.x<RvmF1(2.0/3.0)){colD.g=col.g;}
   else                          {colD.b=col.b;}
   return colD;
  }
  //#endif
//--------------------------------------------------------------
  // Slot mask
  //#if RVM_MODE==2
  if(MASK_MODE == 2){
   RvmF1 lim=RvmF1(1.0/((3.0/12.0)+(9.0/12.0)*RVM_DARK));
   if(RvmFractF1(ipos.x*RvmF1(1.0/6.0))>RvmF1(0.5))
    ipos.y+=RvmF1(2.0);
   ipos.y=RvmFractF1(ipos.y*RvmF1(1.0/4.0));
   RvmF3 colD=col*col;
   colD*=RVM_DARK;
   RvmF3 amp=RvmRcpF3(
    RvmF3_(lim*3.0/12.0)+RvmF3_(lim*9.0/12.0)*col);
   ipos.x=RvmFractF1(ipos.x*RvmF1(1.0/3.0));
   col*=amp;colD*=amp;
   if(ipos.y>RvmF1(1.0/4.0)){
    if(     ipos.x<RvmF1(1.0/3.0)){colD.r=col.r;}
    else if(ipos.x<RvmF1(2.0/3.0)){colD.g=col.g;}
    else                          {colD.b=col.b;}}
   return colD;
  }
  //#endif
//--------------------------------------------------------------
  return col;}
#endif
void main()
{
 vec2 res=iResolution.xy/vec2(INPUT_DOT_X,INPUT_DOT);
 vec2 scanWarp = (RVM_MODE == 0) ? vec2(1.0/256.0,1.0/24.0) : (RVM_MODE == 1) ? 
   vec2(1.0/4096.0,1.0/24.0) : vec2(1.0/48.0,1.0/24.0);
 FragColor.rgb=RvmF(
  floor(vTexCoord.xy * params.OutputSize.xy), //fragCoord.xy,       // ipos
  res/iResolution.xy, // inputSizeDivOutputSize
  res*vec2(0.5,0.5),  // halfInputSize
  1.0/res,            // rcpInputSize
  2.0/iResolution.xy, // twoDivOutputSize
  res.y,
  scanWarp,
  //#endif
  INPUT_BLUR,
  RvmF4(0.5*INPUT_BLUR,-0.5*INPUT_BLUR,-1.5*INPUT_BLUR,-2.5*INPUT_BLUR));
  FragColor.rgb = pow(FragColor.rgb, vec3(1.0/2.2));
}
