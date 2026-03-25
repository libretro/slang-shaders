#version 450

// NTSC-Adaptive Pass3
// based on Themaister's NTSC shader


layout(push_constant) uniform Push
{
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   uint FrameCount;
   float ntsc_phase;
   float auto_res;
   float ntsc_sharp;
   float ntsc_fonts;
   float ntsc_charp;
   float ntsc_charp3;
   float ntsc_shape;
   float ntsc_gamma;
   float ntsc_rainbow1;
   float speedup;
   float RFNOISE;
   float RFNOISE1;
   float RFNOISE2;   
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter auto_res "          SNES/Amiga Hi-Res Auto Mode" 0.0 0.0 1.0 1.0
#pragma parameter speedup  "          Speedup w. higher Internal Res." 1.0 1.0 4.0 1.0
float auto_rez = mix(1.0, 0.5, clamp(params.auto_res * round(params.OriginalSize.x/300.0)-1.0, 0.0, 1.0));
#define speedup params.speedup

#pragma parameter ntsc_phase    "NTSC Phase: Auto | 2 phase | 3 phase | Mixed | PCE" 1.0 1.0 5.0 1.0
#pragma parameter ntsc_rainbow1 "NTSC Coloring/Rainbow Effect (2-phase)"  0.0 0.0 3.0 1.0
#pragma parameter ntsc_sharp  "NTSC Sharpness (Adaptive)" 0.0 -10.0 10.0 0.50
#pragma parameter ntsc_fonts  "NTSC Sharpness - Preserve Fonts (0.35 is a Good Spot)" 0.25 0.25 1.0 0.01
#pragma parameter ntsc_shape  "NTSC Sharpness Shape" 0.80 0.5 1.0 0.025
#pragma parameter ntsc_charp  "NTSC Preserve 'Edge' Colors 2-phase" 0.0 0.0 10.0 0.50
#pragma parameter ntsc_charp3 "NTSC Preserve 'Edge' Colors 3-phase" 0.0 0.0 10.0 0.50
#pragma parameter ntsc_gamma  "NTSC Filtering Gamma Correction" 1.0 0.25 2.5 0.025
#pragma parameter ntsc-row5 "------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter RFNOISE     "NTSC RF Noise Frequency  " 0.30 0.0 1.0 0.01
#pragma parameter RFNOISE1    "NTSC RF Noise Luma+      " 0.00 0.0 0.7 0.01
#pragma parameter RFNOISE2    "NTSC RF Noise Chroma+    " 0.00 0.0 0.7 0.01
#pragma parameter ntsc-row6 "------------------------------------------------" 0.0 0.0 0.0 1.0

float RFNOISE = params.RFNOISE*params.RFNOISE + 0.00001;
#define RFNOISE1  params.RFNOISE1
#define RFNOISE2  params.RFNOISE2

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vTexCoord0;
layout(location = 2) out vec2 vTexCoord1;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord0 = TexCoord / vec2(speedup, 1.0);
   vTexCoord1 = (floor(vTexCoord0*params.OriginalSize.xy)+0.5)*params.OriginalSize.zw;   
   vTexCoord  = (TexCoord + vec2(0.5 * (params.OriginalSize.z/auto_rez)/4.0, 0.0)); // Compensate for decimate-by-2.
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vTexCoord0;
layout(location = 2) in vec2 vTexCoord1;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D NPass1;
layout(set = 0, binding = 4) uniform sampler2D PrePass0;


float smothstep (float e0, float e1, float x)
{
   return clamp((x - e0) / (e1 - e0), 0.0, 1.0);
}

vec2 psrnd(vec2 TexCoord, float FrameCount) {
    vec3 p = vec3(TexCoord * 16758.5453, FrameCount);
    float x = fract(sin(dot(p, vec3(12.9898, 78.233, 3.183))) * 43758.5453);
    float y = fract(sin(dot(p, vec3(25.9796, 14.113, 11.271))) * 96321.9124);
    return vec2(x, y);
}

vec3 Noise(vec2 TexCoord, float FrameCount) {
    TexCoord = psrnd(TexCoord, FrameCount);
    vec3 p = vec3(TexCoord * 758.5453, FrameCount);
    float res1 = fract(sin(dot(p, vec3(12.989835, 78.23341, 0.16453))) * 43758.54531);
    float res2 = fract(sin(dot(p, vec3(39.34679, 11.13523, 83.15573))) * 39459.32423);
    float res3 = fract(sin(dot(p, vec3(73.15691, 52.23504, 09.15197))) * 60493.84731);
    float lns = float(abs(res1-0.5) < 0.2*RFNOISE);
    float cny = float(abs(res2-0.5) < 0.5*RFNOISE);
    float cnz = float(abs(res3-0.5) < 0.5*RFNOISE);
    lns = lns*smothstep(0.5-0.2*RFNOISE, 0.5+0.2*RFNOISE, res1) * 0.66 - 0.33*lns;
    cny = cny*smothstep(0.5-0.5*RFNOISE, 0.5+0.5*RFNOISE, res2)  - 0.5*cny;
    cnz = cnz*smothstep(0.5-0.5*RFNOISE, 0.5+0.5*RFNOISE, res3)  - 0.5*cnz;	
    return vec3(lns, cny, cnz);
}  

const mat3 yiq2rgb_mat = mat3(
   1.0, 0.956, 0.6210,
   1.0, -0.2720, -0.6474,
   1.0, -1.1060, 1.7046);

vec3 yiq2rgb(vec3 yiq)
{
   return yiq * yiq2rgb_mat;
}

const mat3 yiq_mat = mat3(
      0.2989, 0.5870, 0.1140,
      0.5959, -0.2744, -0.3216,
      0.2115, -0.5229, 0.3114
);

vec3 rgb2yiq(vec3 col)
{
   return col * yiq_mat;
}


void main()
{

if (speedup > 1.25 && ((params.OriginalSize.y > 500.0 && params.SourceSize.y > 820.0) || params.SourceSize.y > 820.0))
{
   vec3 signal = texture(Source, vTexCoord0).xyz;
   signal.x = pow(signal.x, 1.0/params.ntsc_gamma);   
   FragColor = vec4(clamp(yiq2rgb(signal), 0.0, 1.0), 1.0);
}
else
{

   vec2 xx = vec2(0.5000 * params.OriginalSize.z/auto_rez/speedup, 0.0);
   vec2 dx = vec2(0.0625 * params.OriginalSize.z/auto_rez/speedup, 0.0);
   
   vec2 texcoord0 = (floor(params.OriginalSize.xy * vTexCoord) + 0.5)*params.OriginalSize.zw;
   vec2 texcoord  = vTexCoord - 2.0*dx;
   vec2 vTex = vTexCoord;
   
   if (speedup > 1.25) { texcoord0 = vTexCoord1; texcoord = vTexCoord0; vTex = vTexCoord0; }
   
   vec3 l1  = texture(Source, texcoord + xx).xyz;
   vec3 l2  = texture(Source, texcoord - xx).xyz;

   float dy = 0.0;
   vec2 yy = vec2(0.0, params.OriginalSize.w);
   xx = vec2(params.OriginalSize.z/auto_rez/speedup, 0.0);

   float phase = (params.ntsc_phase < 1.5) ? ((params.OriginalSize.x * auto_rez > 300.0) ? 2.0 : 3.0) : ((params.ntsc_phase > 2.5) ? 3.0 : 2.0);
   if (params.ntsc_phase > 3.5) phase = 3.0;

   float th = (phase < 2.5) ? 0.025 : 0.0075;

   float ca = texture(NPass1, texcoord0 - xx - xx).a;
   float c0 = texture(NPass1, texcoord0 - xx).a;
   float c1 = texture(NPass1, texcoord0     ).a;
   float c2 = texture(NPass1, texcoord0 + xx).a;
   float cb = texture(NPass1, texcoord0 + xx + xx).a;

   float line0  = smothstep(th, 0.0, min(abs(c1-c0),abs(c2-c1)));
   float line1  = max(smothstep(th, 0.0, min(abs(ca-c0),abs(c2-cb))), line0);
   float line2  = max(smothstep(th, 0.0, min(abs(ca-c2),abs(c0-cb))), line1);
   float diffboost = 0.0;

if (params.ntsc_fonts > 0.255)
{    
   float b1 = texture(NPass1, texcoord0 - yy).a;
   float d1 = texture(NPass1, texcoord0 + yy).a;
   float d2 = texture(NPass1, texcoord0 + xx + yy).a;
   float maxdif = float(0.5*((abs(c0-c1)+abs(c1-c2))) > (1.0-params.ntsc_fonts));
   
   float linecb  = smothstep(0.1, 0.0, max(abs(c1-b1),abs(c1-d1))); // checkerboard check
   linecb = linecb * float (abs(c1-b1)<0.05 || abs(c2-d2)<0.05);
   
   float xdif1 = 0.0;
   float xdif2 = 0.0;
   float th = 0.215;
   
   for (float i = 0.5; i < 10.5; i++)
   {  
      float j = i + 1.0;   
      ca = texture(Source, texcoord -  i*xx).x;
      c0 = texture(Source, texcoord -  j*xx).x;
      c2 = texture(Source, texcoord +  i*xx).x;
	  cb = texture(Source, texcoord +  j*xx).x;
      xdif1 = max(abs(ca-c0)-th, xdif1);
	  xdif2 = max(abs(cb-c2)-th, xdif2);
   }   
   float linex = smothstep(0.0, 0.125, min(xdif1,xdif2));
   
   diffboost = min(linex*linecb*maxdif, 0.625);
}
   
   vec3 ref = texture(Source, texcoord).xyz;
   vec2 orig = ref.yz;
   
   if (params.ntsc_rainbow1 > 0.5 && (phase < 2.5 || params.ntsc_phase == 5.0))
   {
      float ybool = 1.0;
      if ((params.ntsc_rainbow1 < 1.5) && bool(line0)) ybool = 0.0; else
      if ((params.ntsc_rainbow1 < 2.5) && bool(line2)) ybool = 0.0; 
      float line_no  = floor(mod(params.OriginalSize.y*vTexCoord.y, 2.0));
      float frame_no = floor(mod(float(params.FrameCount),2.0));
      float ii = abs(line_no-frame_no);
      dy = ii * params.OriginalSize.w*ybool;
      vec2 ref1 = texture(Source, texcoord - vec2(0.0, dy)).yz;
      vec2 ref2 = texture(Source, texcoord + vec2(0.0, dy)).yz;
      vec2 rdf1 = abs(orig-ref1); vec2 rdf2 = abs(orig-ref2);
      rdf1 = rdf1/max(rdf1+rdf2,0.0000001);
      ref.yz = mix(ref1,ref2,rdf1);
   }
   
   float lum1 = min(texture(NPass1, vTex - dx).a, texture(NPass1, vTex + dx).a);
   float lum2 = ref.x;
   vec3 l3 = abs(l1-l2);
   
   float dif = max(max(max(l3.x, l3.y), max(l3.z, abs(l1.x*l1.x-l2.x*l2.x))),diffboost);
   float dff = pow(dif, 0.125);
   
   float lc = smothstep(0.20, 0.10, abs(lum2-lum1))*dff;

   float tmp = smothstep(0.05-0.03*lc, 0.425 - 0.375*lc, dif);
   float tmp1 = pow((tmp+0.1)/1.1, 0.25);
   float sweight = mix(tmp, tmp1, line0);
   float sweighr = mix(tmp, tmp1, line2);
   
   vec3 signal = ref;

   float ntsc_sharp = abs(params.ntsc_sharp);
   
   if (ntsc_sharp > 0.25)
   {
      float mixer = sweight;
      if (params.ntsc_sharp > 0.25) mixer = sweighr; mixer*=0.1*ntsc_sharp;
      float lummix = mix(lum2, lum1, mixer);
      float lm1 =  mix(lum2*lum2, lum1*lum1,mixer); lm1 = sqrt(lm1);
      float lm2 =  mix(sqrt(lum2), sqrt(lum1),mixer); lm2 = lm2*lm2;
  
      float k1 = abs(lummix - lm1) + 0.00001;
      float k2 = abs(lummix - lm2) + 0.00001;
	  
      signal.x = min((k2*lm1 + k1*lm2)/(k1+k2), 1.0);
      signal.x = min(signal.x, max(params.ntsc_shape*signal.x, lum2));
   }   

   if ((params.ntsc_charp + params.ntsc_charp3) > 0.25)
   {
      dx.x = 0.0625 * params.OriginalSize.z/auto_rez;
      float texcoordx = params.OriginalSize.x * (vTexCoord.x+dx.x) - 0.5;   
      float fpx = fract(texcoordx);
      texcoordx = (floor(texcoordx ) + 0.5) * params.OriginalSize.z;
      float mixer = sweight;
      if (params.ntsc_sharp > 0.25) mixer = sweighr;
      mixer = mix(smothstep(0.075,0.125,max(l3.y,l3.z)), smothstep(0.015,0.0275,dif), line2)*mixer; 
      mixer*=0.1*((phase < 2.5) ? params.ntsc_charp : params.ntsc_charp3);
      texcoord = vec2(texcoordx,texcoord.y);
      vec3 orig_ch = rgb2yiq(mix(texture(PrePass0, texcoord).rgb , texture(PrePass0, texcoord+16.0*dx).rgb, clamp(1.5*fpx-0.25,0.0,1.0)));
      signal.yz = mix(signal.yz, orig_ch.yz, mixer);
   }

   // ADD RF Noise
   if ((RFNOISE1+ RFNOISE2) > 0.005) {
      vec3 ns = Noise(vTexCoord, float(params.FrameCount));
      float Y = mix(0.375, 1.0, pow(signal.x, 0.2));
      signal.x = clamp(signal.x +   RFNOISE1*ns.x,  0.00, 1.00);  
      signal.y = clamp(signal.y + Y*RFNOISE2*(0.325 + 1.325*abs(signal.y))*ns.y, -0.60, 0.60);
      signal.z = clamp(signal.z + Y*RFNOISE2*(0.325 + 1.325*abs(signal.z))*ns.z, -0.53, 0.53);
   }   

   signal.x = pow(signal.x, 1.0/params.ntsc_gamma);
   signal = clamp(yiq2rgb(signal), 0.0, 1.0);
   sweighr = (phase == 2.0 || params.ntsc_phase > 3.5) ? sweighr : 1.0;
   
   FragColor = vec4(signal, sweighr);
}
}  