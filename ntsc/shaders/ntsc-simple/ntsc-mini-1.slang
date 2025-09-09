#version 450


layout(push_constant) uniform Push
{
  float comb_filter,mini_hue1,mini_hue2,ph_mode,h_deg,v_deg,rf_audio,d_crawl,
  mini_sat,Fl,mini_sharp,lpass;
} params;

#pragma parameter ph_mode "-1:Custom,0:blend,1:PCE,2:MD,3:NES/SNES,4:CGA/AppleII" 3.0 -1.0 4.0 1.0
#pragma parameter h_deg "Custom Phase Horiz. Degrees" 120.0 0.0 180.0 0.5
#pragma parameter v_deg "Custom Phase Vert. Degrees" 120.0 0.0 360.0 2.5
#pragma parameter mini_sharp "Resolution" 0.75 0.1 2.0 0.05
#pragma parameter Fl "Freq. Cutoff" 0.2 0.01 1.0 0.01
#pragma parameter lpass "Chroma Low Pass" 0.05 0.0 1.0 0.01
#pragma parameter d_crawl "Dot Crawl" 1.0 0.0 1.0 1.0
#pragma parameter rf_audio "RF Audio Interference" 0.0 0.0 0.2 0.02
#pragma parameter mini_hue1 "Hue Shift I" 0.1 -6.0 6.0 0.05
#pragma parameter mini_hue2 "Hue Shift Q" -0.1 -6.0 6.0 0.05
#pragma parameter mini_sat "Saturation" 2.0 0.0 4.0 0.05

#define mini_hue1 params.mini_hue1
#define mini_hue2 params.mini_hue2
#define ph_mode   params.ph_mode
#define h_deg     params.h_deg
#define v_deg     params.v_deg
#define rf_audio  params.rf_audio
#define d_crawl   params.d_crawl
#define Fl        params.Fl
#define mini_sharp params.mini_sharp
#define lpass     params.lpass
#define mini_sat  params.mini_sat


layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   uint FrameCount;

} global;


#define OutputSize global.OutputSize
#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
#define FrameCount global.FrameCount



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
layout(set = 0, binding = 2) uniform sampler2D Source;


#define PI   3.14159265358979323846
#define s 1.0
#define onedeg 0.017453

const mat3 YUV2RGB = mat3(1.0, 0.0, 1.13983,
                          1.0, -0.39465, -0.58060,
                          1.0, 2.03211, 0.0);

float kaizer (float N, float p)
{
    // Compute sinc filter.
    float k = sin(2.0 * Fl / s * (N - (p - 1.0) / 2.0));
    return k;
}

void main() {

vec3 yuv = vec3(0.0);
vec2 ps = vec2(SourceSize.z,0.0);
float sum = 0.0; float sumc = 0.0;

// luma
for (int i=-1; i<=1; i++)
{
float p = float (i);
vec2 pos = vTexCoord + ps*p/mini_sharp -ps;
// Window
float w = kaizer(3.0,p);
yuv.r += texture(Source,pos).r*w;
sum += w;
}
yuv.r /= sum;

vec3 line = vec3(0.0);

//chroma
for (int i=-4; i<4; i++)
{
float p = float (i);
// Low-pass 
float w = exp(-lpass*p*p);

// snes loosely based on internet videos and blargg

float h_ph, v_ph;
if      (ph_mode == 0.0) {h_ph =  90.0*onedeg; v_ph = PI;        }
else if (ph_mode == 1.0) {h_ph = 120.0*onedeg; v_ph = PI;        }
else if (ph_mode == 2.0) {h_ph = 96.0*onedeg; v_ph = 0.0;        }
else if (ph_mode == 3.0) {h_ph = 120.0*onedeg; v_ph = PI*0.6667; }
else if (ph_mode == 4.0) {h_ph =  90.0*onedeg; v_ph = 0.0; }
else                     {h_ph =  h_deg*onedeg; v_ph = v_deg*onedeg;}

float phase = (vTexCoord.x*SourceSize.x + p)*h_ph + 
              (vTexCoord.y*SourceSize.y)*v_ph + 
              d_crawl *(mod(float(FrameCount),2.0))*h_ph;

vec2 qam = mini_sat*vec2(cos(phase),sin(phase));

line.gb = texture(Source,vTexCoord + ps*p).gb*qam*w;

yuv.gb += line.gb;
sumc += w;
}
yuv.gb /= sumc;

FragColor.rgb = yuv*YUV2RGB;
}