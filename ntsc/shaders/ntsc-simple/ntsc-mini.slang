#version 450


layout(push_constant) uniform Push
{
  float ntsc_sat,lpass,comb_filter;
} params;

#pragma parameter comb_filter "Chroma Comb. Filter Strength" 0.6 0.0 1.0 0.05
#pragma parameter lpass "Luma Low Pass" 0.2 0.0 1.0 0.01
#pragma parameter ntsc_sat "Saturation" 3.0 0.0 6.0 0.05


#define comb_filter params.comb_filter
#define lpass params.lpass
#define ntsc_sat params.ntsc_sat

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

const mat3 RGBYUV = mat3(0.299, 0.587, 0.114,
                        -0.299, -0.587, 0.886, 
                         0.701, -0.587, -0.114);

const mat3 YUV2RGB = mat3(1.0, 0.0, 1.13983,
                          1.0, -0.39465, -0.58060,
                          1.0, 2.03211, 0.0);
vec2 dx,dy;
float compo0 ( float p, vec3 phase)
{
vec3 yiq = texture(Source,vTexCoord+p*dx).rgb*RGBYUV;
return dot(vec3(1.0),yiq*phase);
}

float compo1 ( float p, vec3 phase)
{
vec3 yiq = texture(Source,vTexCoord+p*dx-dy).rgb*RGBYUV;
return dot(vec3(1.0),yiq*phase);
}

void main() {
dx = vec2(SourceSize.z*0.5,0.0);
dy = vec2(0.0,SourceSize.w*0.25);
vec3 final = vec3(0.0);
float sum = 0.0;

for (int n=-3; n<4; n++)
{
float p = float(n);   
float w = exp(-lpass*p*p);
float carrier    =  (vTexCoord.x * SourceSize.x / (170.667 / OriginalSize.x) + p)*PI*0.5;
float carrier_up =  (vTexCoord.x * SourceSize.x / (170.667 / OriginalSize.x) + p)*PI*0.5 + PI;
vec3 phase    = vec3(1.0,0.5*cos(carrier)   ,0.5*sin(carrier));
vec3 phase_up = vec3(1.0,0.5*cos(carrier_up),0.5*sin(carrier_up));
vec3 phasefinal  = vec3(1.0,ntsc_sat*cos(carrier)   ,ntsc_sat*sin(carrier));

float line_cur = compo0(p,phase)*w;
float line_up  = compo1(p,phase_up)*w;

vec3 rgb = vec3(0.0);
// luma
rgb.r = (line_up+line_cur)/2.0;
// chroma
rgb.gb = vec2(line_cur-(line_up+line_cur)/2.0*comb_filter);
final += rgb*phasefinal;
sum += w;
}
final.r /= sum;
final.gb /= 7.0;
FragColor.rgb = final*YUV2RGB;
}
