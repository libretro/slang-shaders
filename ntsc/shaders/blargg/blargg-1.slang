#version 450

// NewRisingSun and blargg's NTSC filter
// simplified and ported to glsl by metallic77
// no license given, but I would expect it to inherit the LGPL license from the C version

#include "blargg_params.inc"

#define PI 3.1415926
#define fringing_mid 0.8
#define fringing_max 1.6
#define artifacts_mid 0.4
#define artifacts_max 0.6
#define onedeg 0.017453

// Colorspace conversion matrix for YIQ-to-RGB
const mat3 YIQ2RGB = mat3(
   1.0, 0.956, 0.6210,
   1.0, -0.2720, -0.6474,
   1.0, -1.1060, 1.7046);

float blackman (float x)
{
   float b = 0.42 - 0.5 * cos(x) + 0.08 * cos( x * 2.0 );
   return b;
}

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

void main()
{
vec2 size = params.SourceSize.xy;
vec2 uv = vTexCoord;
int i = int(kernel_half);
float cutoff_factor = -0.03125;
float cutoff = ntsc_bleed;       
    if ( cutoff < 0.0 )
        {
    // keep extreme value accessible only near upper end of scale (1.0)
    cutoff *= cutoff;
    cutoff *= cutoff;
    cutoff *= cutoff;
    cutoff *= -30.0 / 0.65;    
        }
    cutoff = cutoff_factor - 0.65 * cutoff_factor * cutoff;
    
    // Sample composite signal and decode to YUV
    vec3 YUV = vec3(0);
    float sum = 0.0;
    float to_angle = ntsc_res + 1.0;
    float  rolloff = 1.0 + ntsc_sharp * 0.032;
    float  maxh = kernel_half*2.0;
    float  pow_a_n = pow( rolloff, maxh );
    to_angle = PI / maxh * LUMA_CUTOFF * (to_angle * to_angle + 1.0);

for (int n=0; n<i*2+1; n++) { // 2*maxh + 1
        // blargg-ntsc
        // generate luma (y) filter using sinc kernel 
        float a = PI * 2.0 / (kernel_half * 2.0) * float(n);
        float w = blackman(a);
        vec2 pos = uv - vec2(kernel_half/size.x,0.0) + vec2(float(n) / size.x, 0.0);
        
        float x = float(n) - kernel_half; // maxh/2
        
        float angle = x * to_angle;
        float kernel = 0.0;
 
float fringing = 0.0; 
if (fract(float(n+2)/4.0) == 0.0)
{
    if(fring >0.0)
    fringing = -fring*(fringing_max-fringing_mid);
}

            //instability occurs at center point with rolloff very close to 1.0 
            if ( x > 1.056  || pow_a_n > 1.056 || pow_a_n < 0.981 )
            {
                float rolloff_cos_a = rolloff * cos( angle );
                float num = 1.0 - rolloff_cos_a -
                        pow_a_n * cos( maxh * angle ) +
                        pow_a_n * rolloff * cos( (maxh - 1.0) * angle );
                float den = 1.0 - rolloff_cos_a - rolloff_cos_a + rolloff * rolloff;
                float dsf = num / den;
                kernel = dsf - 0.5; 
            }
           
        YUV.x += texture(Source, pos).r*w*kernel*(1.0+fringing);

        sum += w*kernel;
        }
        YUV.x /= sum;
    float sumc = 0.0;

// blargg ntsc-chroma
// generate chroma (iq) filter using gaussian kernel

for (int n=-i; n<i; n++) {
    vec2 pos = uv + vec2(float(n) / size.x, 0.0);
    float modulo = 3.0; if (global.OriginalSize.x > 300.0) modulo = 2.0;

    float phase = (floor(vTexCoord.x*params.SourceSize.x)+float(n))*pi_mod*onedeg + mod(floor(vTexCoord.y*params.SourceSize.y),modulo)*PI*vert_scal; 
    if (stat_ph == 1.0) phase += sin(mod(float(params.FrameCount/2),2.0))*PI;

    float r = exp(cutoff*float(n)*float(n));

float artifacts = 0.0; 
if (fract(float(n+i+2)/4.0) == 0.0)
{
    if(afacts>0.0)
    artifacts= -afacts*(artifacts_max-artifacts_mid);
}

    vec2 carrier = ntsc_sat*vec2(cos(phase), sin(phase));
        YUV.yz += r*texture(Source, pos).gb * carrier*(1.0+artifacts);
        sumc += r;
        }
    YUV.yz /= sumc;

    //  Convert signal to RGB
    YUV = YUV*YIQ2RGB;
    FragColor = vec4(YUV, 1.0);
}
