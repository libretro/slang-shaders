#version 450
#include "config.inc"

#define NTSC_FILTER_WIDTH_MAX 25
#define NTSC_FILTER_MIDDLE NTSC_FILTER_WIDTH/2

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 1) out vec3 vTemperature_rgb;
layout(location = 0) out vec2 vTexCoord;
layout(location = 2) out float vNTSC_FILTER_FC;
layout(location = 3) out float vNTSC_FILTER_SCF;
layout(location = 4) out float vNTSC_weights[NTSC_FILTER_WIDTH_MAX];


#include "includes/functions.include.slang"


vec3 kelvin2rgb(float k) {
   //Convert kelvin temperature to rgb factors
   k = clamp(k,1000,40000);
   k=k/100.0;
   float tmpCalc;
    vec3 pixel_out;
   if (k<=66) {
      pixel_out.r = 255;
      pixel_out.g = 99.47080258612 * log(k) - 161.11956816610;
   } else {
      pixel_out.r = 329.6987274461 * pow(k - 60 ,-0.13320475922);
      pixel_out.g = 288.12216952833 * pow(k-60, -0.07551484921);
   }

   if (k >= 66)
      pixel_out.b = 255;
   else if (k<=19)
      pixel_out.b = 0;
   else
      pixel_out.b = 138.51773122311 * log(k - 10) - 305.04479273072;

   return pixel_out/255.0;
}

/* hann() sinc() functions by xot:
 * copyright (c) 2017-2018, John Leffingwell
 * license CC BY-SA Attribution-ShareAlike
 * ntscdec() function, same license and attribution,
 * slightly modified by me.
 * https://www.shadertoy.com/view/Mdffz7
 */

float hann(float n, float N) {
    return 0.5 * (1.0 - cos((TAU*n)/(N-1.0))) ;
}

float sinc(float x) {
   //if (x == 0.0) return 1.0;
   x = x + eps;
   return sin(pi*x) / (pi*x);
}


void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;

   if (DO_NTSC_ARTIFACTS > 0.0) {
      vNTSC_FILTER_FC = NTSC_FILTER_FC * 0.1;
      vNTSC_FILTER_SCF = NTSC_FILTER_SCF * 0.1;
      float sum = 0.0;
      int N = int(NTSC_FILTER_WIDTH);
      //  Compute sampling weights
      for (int n = 0; n < N; n++) {
         vNTSC_weights[n] = hann(float(n), float(N)) * sinc(vNTSC_FILTER_FC * float(n-NTSC_FILTER_MIDDLE));
         sum += vNTSC_weights[n];
      }
      //  Normalize sampling weights
      for (int n = 0; n < N; n++) {
         vNTSC_weights[n] /= sum;
      }
   }
   if (TEMPERATURE != 6500)
      vTemperature_rgb = kelvin2rgb(TEMPERATURE);
}


#pragma stage fragment

#include "includes/functions.include.slang"

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec3 vTemperature_rgb;
layout(location = 2) in float vNTSC_FILTER_FC;
layout(location = 3) in float vNTSC_FILTER_SCF;
layout(location = 4) in float vNTSC_weights[NTSC_FILTER_WIDTH_MAX];


layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


//	Colorspace conversion matrix for YIQ-to-RGB
const mat3 YIQ2RGB = mat3(1.000, 1.000, 1.000,
                          0.956,-0.272,-1.106,
                          0.621,-0.647, 1.703);

const mat3 RGB2YIQ = mat3(
         0.2989, 0.5959, 0.2115,
         0.5870, -0.2744, -0.5229,
         0.1140, -0.3216, 0.3114);



#define eps10 1.0e-10
vec3 rgb2hsv(vec3 c){
   vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
   vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
   vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

   float d = q.x - min(q.w, q.y);
   return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + eps10)), d / (q.x + eps10), q.x);
}

#define pi10 pi*10
#define PHASE_SHIFT_FOR_BLUR_K pi/3
vec4 ntscdec(vec2 uv) {
   vec2 size = params.SourceSize.xy;
   //	Sample composite signal and decode to YIQ
      vec3 YIQ_processed = vec3(0.0);
      vec3 YIQ_processed_shifted = vec3(0.0);
      //by doing another ntsc filtering with this histed phase, we're able to better identify
      //artifacts that will drive the blur modulation.
         float phase_shift_for_blur;
         
      int N = int(NTSC_FILTER_WIDTH);
      for (int n=0; n < N; n++) {
         vec2 pos = uv + vec2(float(n-NTSC_FILTER_MIDDLE) / size.x, 0.0);
         float phase =  TAU * (vNTSC_FILTER_SCF * size.x * pos.x);
         float phase_shift_for_blur = phase  + PHASE_SHIFT_FOR_BLUR_K;
         
         phase += ( pos.y * -pi10 ) * (NTSC_PHASE_SHIFT);
         
         //float phase =  TAU * (vNTSC_FILTER_SCF * size.x * pos.x) + ( pos.y * -pi10 * NTSC_PHASE_SHIFT)
         // ( pos.y * - 31.4);
         //Just sample luminance via yiq:
            vec3 smp = vec3((texture(Source, pos).rgb * RGB2YIQ).x);
            YIQ_processed += vec3(1.0, cos(phase), sin(phase)) * smp * vNTSC_weights[n];
            YIQ_processed_shifted += vec3(1.0, cos(phase_shift_for_blur), sin(phase_shift_for_blur)) * smp * vNTSC_weights[n];
      }

   vec3 RGB_ori = texture(Source, uv).rgb;
   vec3 YIQ_ori = RGB_ori * RGB2YIQ;

   vec3 YIQ_result = vec3(YIQ_ori.x, YIQ_ori.yz + YIQ_processed.yz * NTSC_MIX);
   
   float artifacts_mask = abs(YIQ_processed.y)         + abs(YIQ_processed.z) + 
                          abs(YIQ_processed_shifted.y) + abs(YIQ_processed_shifted.z);
   
   return vec4(YIQ_result * YIQ2RGB, artifacts_mask);
}

#define W vec3(0.2125, 0.7154, 0.0721)

vec3 color_tools(vec3 pixel_out) {
//Apply color corrections to input signal.

   //Push luminance without clipping
   pixel_out = pixel_push_luminance(pixel_out,LUMINANCE);

   //Modify saturation
   if (!(SATURATION == 1.0)) {
      vec3 intensity = vec3(dot(pixel_out.rgb, W));
      pixel_out.rgb = mix(intensity, pixel_out.rgb, SATURATION);
   }

   //Modify contrast and brightness
   if (CONTRAST != 0.0 || BRIGHTNESS != 0.0)
      pixel_out.rgb = scale_to_range_vec3(pixel_out.rgb, -CONTRAST, 1+CONTRAST) + BRIGHTNESS;

   //Modify color temperature
   if (TEMPERATURE != 6500.0) pixel_out.rgb = pixel_out.rgb * vTemperature_rgb;
   return pixel_out;
}


vec3 debug() {
   vec3 pixel_debug;
   float blink_time = 120;
   vec2 center = vTexCoord - vec2(0.5,0.5);
   float radius = 0.1;
   pixel_debug = vec3(1 - step(radius, length(center)));
   pixel_debug *= float((mod(params.FrameCount,blink_time*2) < blink_time));
   return pixel_debug;
}

void main() {

   //FragColor = vec4(debug(), 1.0); return;


   //This will go into alpha channel to make glow aware of it and blur more.
   //It could be configurable.
   float artifacts = 0.0;

   vec3 pixel_out;
   if (DO_NTSC_ARTIFACTS > 0.5) {
      vec3 pixel_source = texture(Source, vTexCoord).rgb;
      vec4 pixel_out_vec4 = ntscdec(vTexCoord);
      pixel_out = pixel_out_vec4.rgb;

      artifacts = pixel_out_vec4.a;

/*
      //artifacts = pow(artifacts, IN_GLOW_NTSC_ARTF_TRSH * 8.0);
      artifacts = artifacts * IN_GLOW_NTSC_ARTF_MULT;
      artifacts = smoothstep(IN_GLOW_NTSC_ARTF_TRSH, 1.0, artifacts);
      //artifacts = min(artifacts, 1.0); //<- useless since clamp happens if not uising float framebuffer.
*/
      
   } else {
      pixel_out = texture(Source, vTexCoord).rgb;
   }

   if (DO_CCORRECTION == 1.0)
      pixel_out = color_tools(pixel_out);

   FragColor = vec4(pixel_out, artifacts);



  // FragColor = vec4(artifacts);


}


