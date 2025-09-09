#version 450


layout(push_constant) uniform Push
{
  float ph_mode;
  float mini_hue1, mini_hue2, h_deg, v_deg, rf_audio, d_crawl;
} params;

#pragma parameter ph_mode "-1:Custom,0:blend,1:PCE,2:MD,3:NES/SNES,4:CGA/AppleII" 3.0 -1.0 4.0 1.0
#pragma parameter h_deg "Custom Phase Horiz. Degrees" 120.0 0.0 180.0 0.5
#pragma parameter v_deg "Custom Phase Vert. Degrees" 120.0 0.0 360.0 2.5
#pragma parameter d_crawl "Dot Crawl" 1.0 0.0 1.0 1.0
#pragma parameter rf_audio "RF Audio Interference" 0.0 0.0 0.2 0.02
#pragma parameter mini_hue1 "Hue Shift I" 0.1 -6.0 6.0 0.05
#pragma parameter mini_hue2 "Hue Shift Q" -0.1 -6.0 6.0 0.05


#define mini_hue1 params.mini_hue1
#define mini_hue2 params.mini_hue2
#define ph_mode params.ph_mode
#define h_deg params.h_deg
#define v_deg params.v_deg
#define rf_audio params.rf_audio
#define d_crawl params.d_crawl

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


#define iTimer (float(FrameCount) / 60.0)

#define onedeg 0.017453
#define PI   3.14159265358979323846

mat3 RGBYUV = mat3(0.299, 0.587, 0.114,
                        -0.299, -0.587, 0.886, 
                         0.701, -0.587, -0.114);

float noise(vec2 co)
{
return fract(sin(iTimer * dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}


void main() {

vec3 res = vec3(0.0);

// snes loosely based on internet videos and blargg

float h_ph = 0.0;
float v_ph = 0.0; 

if      (ph_mode == 0.0) {h_ph =  90.0*onedeg; v_ph = PI;        }
else if (ph_mode == 1.0) {h_ph = 120.0*onedeg; v_ph = PI;        }
else if (ph_mode == 2.0) {h_ph = 96.0*onedeg; v_ph = 0.0;        }
else if (ph_mode == 3.0) {h_ph = 120.0*onedeg; v_ph = PI*0.6667; }
else if (ph_mode == 4.0) {h_ph =  90.0*onedeg; v_ph = 0.0; }
else                     {h_ph =  h_deg*onedeg; v_ph = v_deg*onedeg; }

float phase = (vTexCoord.x*SourceSize.x)*h_ph + (vTexCoord.y*SourceSize.y)*v_ph + noise(vTexCoord)*rf_audio*PI + d_crawl *(mod(float(FrameCount),2.0))*h_ph;

res = texture(Source,vTexCoord).rgb*RGBYUV;
res.gb *= 0.5*vec2(cos(phase + mini_hue1), sin(phase + mini_hue2));

float signal = dot(vec3(1.0),res);

FragColor.rgb = vec3(signal);
}