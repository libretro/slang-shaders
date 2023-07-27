#version 450


layout(push_constant) uniform Push
{
  float MASK;
  float COMPOSITE_LOWPASS;
  float COL_BLEED;
  float NTSC_COL;

} params;


#pragma parameter MASK "Color Subcarrier Artifacts"  0.08 0.0 1.0 0.01
#pragma parameter COMPOSITE_LOWPASS "Composite Lowpass"  0.8 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed"  1.4 0.0 2.0 0.05
#pragma parameter NTSC_COL "NTSC Colors "  0.0 0.0 1.0 1.0

#define MASK params.MASK
#define COMPOSITE_LOWPASS params.COMPOSITE_LOWPASS
#define COL_BLEED params.COL_BLEED
#define NTSC_COL params.NTSC_COL
#define PI 3.141592

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



mat3 RGBtoYIQ = mat3(
        0.2989, 0.5870, 0.1140,
        0.5959, -0.2744, -0.3216,
        0.2115, -0.5229, 0.3114);

mat3 YIQtoRGB = mat3(
        1.0, 0.956, 0.6210,
        1.0, -0.2720, -0.6474,
        1.0, -1.1060, 1.7046);

const mat3 NTSC = mat3(
    1.8088923,   -0.6480268,  -0.0833558,
   0.4062922 ,  0.6175271,   -0.0038849,
  -0.0025872,  -0.103848 ,  1.182318);

#define Time sin(float(FrameCount))

float phase = OriginalSize.x<300.0 ? 4.0*PI/15.0 : PI/3.0;
#define SC MASK*sin(vTexCoord.x*SourceSize.x*phase)+1.0-MASK

void main()
{
    
    vec2 cent = floor(vTexCoord*SourceSize.xy)+0.5;
    vec2 coords = cent*SourceSize.zw;
    coords = vec2(mix(vTexCoord.x,coords.x,0.2),coords.y);

    vec3 res = texture(Source,coords).rgb; res *= RGBtoYIQ;
    float onetexel = SourceSize.z*COMPOSITE_LOWPASS;
    float bleed = SourceSize.z*COL_BLEED;
    vec3 resr = texture(Source,coords-(vec2(2.0*bleed,0.0))).rgb; resr *= RGBtoYIQ;
    vec3 resru = texture(Source,coords-(vec2(onetexel,0.0))).rgb; resru *= RGBtoYIQ;
    vec3 resrr = texture(Source,coords-(vec2(3.0*bleed,0.0))).rgb; resrr *= RGBtoYIQ;
    
    vec3 resl = texture(Source,coords+(vec2(2.0*bleed,0.0))).rgb; resl *= RGBtoYIQ;
    vec3 reslu = texture(Source,coords+(vec2(bleed,0.0))).rgb; reslu *= RGBtoYIQ;
    vec3 resll = texture(Source,coords+(vec2(3.0*bleed,0.0))).rgb; resll *= RGBtoYIQ;
    
    //color bleed
    res.gb += (resr.gb+resl.gb+resrr.gb+resll.gb+reslu.gb+resru.gb); res.gb /= 7.0;
    //overall bluriness
    res.r = (res.r + resru.r)/2.0; 
        
    vec3 checker = texture(Source,vTexCoord - vec2(0.25/OriginalSize.x,0.0)).rgb;  checker *= RGBtoYIQ;  
    vec3 checkerl = texture(Source,vTexCoord + vec2(0.1/OriginalSize.x,0.0)).rgb;  checkerl *= RGBtoYIQ;  

    float diff = res.g-checker.g;
    float diffl = res.g-checkerl.g;
    float ydiff = res.r-checker.r;
    float ydiffl = res.r-checkerl.r;

    float x = mod(floor(vTexCoord.x*SourceSize.x),2.0);
    float y = mod(floor(vTexCoord.y*SourceSize.y),2.0);


//Color subcarrier pattern
    if (y == 0.0 && x == 0.0 && Time < 0.0 && diff > 0.0 || y == 0.0 && x == 1.0 && Time > 0.0 && diff > 0.0)
    
        res.b *= SC; // ok
    
    else if (y == 1.0 && x == 1.0 && Time < 0.0 && diff > 0.0 || y == 1.0 && x == 0.0 && Time > 0.0 && diff > 0.0)
    
        res.b *= SC; // ok
 
    else if (y == 0.0 && x == 0.0 && Time < 0.0 && ydiff < 0.0 || y == 0.0 && x == 1.0 && Time > 0.0 && ydiff < 0.0)
    
        res.r *= SC; // ok
    
    else if (y == 1.0 && x == 1.0 && Time < 0.0 && ydiff < 0.0 || y == 1.0 && x == 0.0 && Time > 0.0 && ydiff < 0.0)
        res.r *= SC; // ok
   
    else if (y == 0.0 && x == 0.0 && Time < 0.0 && ydiffl < 0.0 || y == 0.0 && x == 1.0 && Time > 0.0 && ydiffl < 0.0)
    
        res.r *= SC;
    
    else if (y == 1.0 && x == 1.0 && Time < 0.0 && ydiffl < 0.0 || y == 1.0 && x == 0.0 && Time > 0.0 && ydiffl < 0.0)
        res.r *= SC; 

//for testing
//if (ydiffl < 0.0) res = vec3(0.0);

///
    res *= YIQtoRGB;
    if (NTSC_COL == 1.0)res *= NTSC;
    FragColor = vec4(res,1.0);
}
