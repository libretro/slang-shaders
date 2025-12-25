#ifndef RVM_MASK_FUNC
#define RVM_MASK_FUNC

// NOTE: THIS MASK CODE NEEDS LINEAR GAMMA AND A VEC3 INPUT.
// YOU MUST ALSO PROVIDE THESE VALUES THROUGH A PARAMETER:
// float RVM_DARK, int RVM_MASK;
// OR UNCOMMENT THE NEXT LINE:
//#define STATIC_MASK

//_____________________________.._______________________________
//==============================================================
//
//
//     [RVM] RETRO VIDEO MONITOR [mask header] - v20210519
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
#ifdef STATIC_MASK
 #define RVM_DARK (7.0/8.0)
 #define RVM_MASK 2
#endif
////////////////////////////////////////////////////////////////

RvmF3 energy_conservation_mask(vec3 col, vec2 ipos){
   RvmF1 lim = RvmF1(0.0);
   RvmF3 colD, amp = RvmF3(0.0);
  // Aperture Grille
 if(RVM_MASK == 1){
   lim=RvmF1(1.0/((1.0/3.0)+(2.0/3.0)*RVM_DARK));
   colD=col*col;
   colD*=RVM_DARK;
   amp=RvmRcpF3(
    RvmF3_(lim*1.0/3.0)+RvmF3_(lim*2.0/3.0)*col);
   ipos.x=RvmFractF1(ipos.x*RvmF1(1.0/3.0));
   col*=amp;colD*=amp;
   if(     ipos.x<RvmF1(1.0/3.0)){colD.r=col.r;}
   else if(ipos.x<RvmF1(2.0/3.0)){colD.g=col.g;}
   else                          {colD.b=col.b;}
   return colD;
 }
//--------------------------------------------------------------
  // Slot mask
 if(RVM_MASK == 2){
   lim=RvmF1(1.0/((3.0/12.0)+(9.0/12.0)*RVM_DARK));
   if(RvmFractF1(ipos.x*RvmF1(1.0/6.0))>RvmF1(0.5))
    ipos.y+=RvmF1(2.0);
   ipos.y=RvmFractF1(ipos.y*RvmF1(1.0/4.0));
   colD=col*col;
   colD*=RVM_DARK;
   amp=RvmRcpF3(
    RvmF3_(lim*3.0/12.0)+RvmF3_(lim*9.0/12.0)*col);
   ipos.x=RvmFractF1(ipos.x*RvmF1(1.0/3.0));
   col*=amp;colD*=amp;
   if(ipos.y>RvmF1(1.0/4.0)){
    if(     ipos.x<RvmF1(1.0/3.0)){colD.r=col.r;}
    else if(ipos.x<RvmF1(2.0/3.0)){colD.g=col.g;}
    else                          {colD.b=col.b;}}
   return colD;
 }
 return col;
}
#endif
