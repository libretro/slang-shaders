#ifndef RVM_SCANLINES_FUNC
#define RVM_SCANLINES_FUNC

// NOTE: THIS SCANLINE CODE NEEDS LINEAR GAMMA. SEE BELOW FOR INPUTS.
// YOU MUST ALSO PROVIDE THESE VALUES THROUGH A PARAMETER:
// float RVM_SCAN_DIV, float RVM_SCAN_MAX;
// OR UNCOMMENT THE NEXT LINE:
//#define STATIC_SCANLINES

//_____________________________.._______________________________
//==============================================================
//
//
//    [RVM] RETRO VIDEO MONITOR [scanline header] - v20210519
//                         _
//                     by  |imothy Lottes
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
#ifndef RVM_PORTABILITY
#define RVM_PORTABILITY
////////////////////////////////////////////////////////////////
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
#endif
#endif
//==============================================================

////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________
//==============================================================
//                        FILTER CONTROL
//==============================================================
#ifdef STATIC_SCANLINES
 #define RVM_DARK (7.0/8.0)
 #define RVM_SCAN_DIV 3.0
 #define RVM_SCAN_MAX (8.0/15.0)
#endif
#define RVM_SCAN_MIN (RVM_SCAN_DIV*RVM_SCAN_MAX)
#define RVM_SCAN_SIZ (RVM_SCAN_MAX-RVM_SCAN_MIN)
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//_____________________________.._______________________________
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
 RvmF3 energy_conservation_scanlines(
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
  RvmF2 pos, vin2 = RvmF2(0.0);
  RvmF1 vin = RvmF1(0.0);
//  #ifdef RVM_WARP
if(RVM_WARP){
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
  // Get to center for first gather 4
  //  W Z W Z
  //  X Y X Y
  RvmF2 g, gp = RvmF2(0.0);
//  #if RVM_MODE==0
if(RVM_MODE == 0){
   g=floor(pos+RvmF2(-1.5,-0.5))+RvmF2_(1.0);
   gp=g*rcpInputSize;
   g.y-=RvmF1(0.5);
}else{
//  #endif
//--------------------------------------------------------------
  // Get to center for first gather 4
  //  W Z
  //  X Y
  //  W Z
  //  X Y
   g=floor(pos+RvmF2(-0.5,-1.5))+RvmF2_(1.0);
   gp=g*rcpInputSize;
   g.x-=RvmF1(0.5);
}
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
   RvmF4 colRS, colGS, colBS, colRT, colGT, colBT = RvmF4(0.0);
//  #if RVM_MODE==0
if(RVM_MODE == 0){
   colRS=RvmR4F(gp);
   colGS=RvmG4F(gp);
   colBS=RvmB4F(gp);
   gp.x+=RvmF1(2.0*rcpInputSize.x);
   colRT=RvmR4F(gp);
   colGT=RvmG4F(gp);
   colBT=RvmB4F(gp);
//  #endif
}else{
//--------------------------------------------------------------
  // 2x4 sampled footprint
  //  W Z |s
  //  X Y |s
  //  W Z :t
  //  X Y :t
//  #if RVM_MODE!=0
   colRS=RvmR4F(gp);
   colGS=RvmG4F(gp);
   colBS=RvmB4F(gp);
   gp.y+=RvmF1(2.0*rcpInputSize.y);
   colRT=RvmR4F(gp);
   colGT=RvmG4F(gp);
   colBT=RvmB4F(gp);
//  #endif
}
//--------------------------------------------------------------
  // Debug view without effect
  #ifdef RVM_SPLIT
   if(ipos.x<RvmF1(RVM_SPLIT)){
    return RvmF3(colRS.z,colGS.z,colBS.z);}
  #endif
//--------------------------------------------------------------
  // Horizontal kernel is simple gaussian filter approximation
   RvmF1 offB = RvmF1(0.0);
   RvmF2 offS, offT, horS, horT = RvmF2(0.0);
//  #if RVM_MODE==0
if(RVM_MODE == 0){
   offB=RvmF1(pos.x-g.x);
   offS=RvmF2(offB,offB)*RvmF2_(blur)+blur4.xy;
   offT=RvmF2(offB,offB)*RvmF2_(blur)+blur4.zw;
   horS=RvmPolyF2(offS);
   horT=RvmPolyF2(offT);
//  #endif
}else{
//--------------------------------------------------------------
  // Vertical
//  #if RVM_MODE!=0
   offB=RvmF1(pos.y-g.y);
   offS=RvmF2(offB,offB)*RvmF2_(blur)+blur4.xy;
   offT=RvmF2(offB,offB)*RvmF2_(blur)+blur4.zw;
   horS=RvmPolyF2(offS);
   horT=RvmPolyF2(offT);
//  #endif
}
//--------------------------------------------------------------
  // Get kernel totals and then rcp
  RvmF2 hor0=horS+horT;
  RvmF1 horD=RvmRcpF1(hor0.x+hor0.y);
//--------------------------------------------------------------
  // Get rid of off-screen pixels on edge
//  #ifdef RVM_WARP
if(RVM_WARP){
   horD*=RvmF1(vin);
//  #endif
}
//--------------------------------------------------------------
  // Apply horizontal filter, up and down sums
   RvmF2 colRU2, colGU2, colBU2, colRD2, colGD2, colBD2, colRL, colGL, colBL = RvmF2(0.0);
//  #if RVM_MODE==0
if(RVM_MODE == 0){
   colRU2=colRS.wz*horS+colRT.wz*horT;
   colGU2=colGS.wz*horS+colGT.wz*horT;
   colBU2=colBS.wz*horS+colBT.wz*horT;
   colRD2=colRS.xy*horS+colRT.xy*horT;
   colGD2=colGS.xy*horS+colGT.xy*horT;
   colBD2=colBS.xy*horS+colBT.xy*horT;
//--------------------------------------------------------------
   // Pair total so that {x:=up, y:=down}
   // Expensive transpose from pairs of taps, to pairs of lines
   colRL=RvmF2(colRU2.x+colRU2.y,colRD2.x+colRD2.y);
   colGL=RvmF2(colGU2.x+colGU2.y,colGD2.x+colGD2.y);
   colBL=RvmF2(colBU2.x+colBU2.y,colBD2.x+colBD2.y);
//  #endif
}else{
//--------------------------------------------------------------
  // Apply vertical filter
//  #if RVM_MODE!=0
   colRL=colRS.wz*horS.xx+colRS.xy*horS.yy+
               colRT.wz*horT.xx+colRT.xy*horT.yy;  
   colGL=colGS.wz*horS.xx+colGS.xy*horS.yy+
               colGT.wz*horT.xx+colGT.xy*horT.yy;  
   colBL=colBS.wz*horS.xx+colBS.xy*horS.yy+
               colBT.wz*horT.xx+colBT.xy*horT.yy;  
//  #endif
}
//--------------------------------------------------------------
  // Normalize by kernel total
  colRL*=RvmF2_(horD);
  colGL*=RvmF2_(horD);
  colBL*=RvmF2_(horD);
//--------------------------------------------------------------
   RvmF2 colML, scnL, nrmL = RvmF2(0.0);
   RvmF1 offX, offY = RvmF1(0.0);
//  #if RVM_MODE==0
if(RVM_MODE == 0){
   // Get channel maximums and shape
   colML=RvmMax3F2(colRL,colGL,colBL);
   // TODO: Approximation...
   colML=sqrt(colML);
//--------------------------------------------------------------
   // Convert shaped channel maximums into scan width
   scnL=colML*RvmF2_(RVM_SCAN_SIZ)+RvmF2_(RVM_SCAN_MIN);
   offY=RvmF1(pos.y-g.y);
   scnL.x=( offY)*scnL.x;  
   scnL.y=(-offY)*scnL.y+scnL.y;  
   scnL=min(RvmF2_(0.5),scnL);
   scnL=RvmNCosF2(scnL);
   scnL=scnL*RvmF2_(0.5)+RvmF2_(0.5);
//--------------------------------------------------------------
   // Normalize for reduction in scan width
   nrmL=RvmF2_(1.0)-colML;
   nrmL=nrmL*RvmF2_(RVM_SCAN_MIN/RVM_SCAN_MAX-1.0)+RvmF2_(1.0);
   scnL*=nrmL;
//  #endif
}else{
//--------------------------------------------------------------
//  #if RVM_MODE!=0
   offX=RvmF1(pos.x-g.x);
   scnL=RvmF2(RvmF1(1.0)-offX,offX);
//  #endif
}
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

  return col;}
#endif
////////////////////////////////////////////////////////////////
#endif
