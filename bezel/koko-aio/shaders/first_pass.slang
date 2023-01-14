#version 450
#include "config.inc"

#define NTSC_FILTER_WIDTH_MAX 25
#define NTSC_FILTER_MIDDLE NTSC_FILTER_WIDTH/2

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec3 temperature_rgb;
layout(location = 2) out float vNTSC_FILTER_FC;
layout(location = 3) out float vNTSC_FILTER_SCF;
layout(location = 4) out float vNTSC_weights[NTSC_FILTER_WIDTH_MAX];

#include "includes/functions.include.slang"


/* hann() sinc() functions by xot:
 * copyright (c) 2017-2018, John Leffingwell
 * license CC BY-SA Attribution-ShareAlike
 * ntscdec() function, same license and attribution,
 * slightly modified by me.
 * https://www.shadertoy.com/view/Mdffz7
 */


//	Hann windowing function
float hann(float n, float N) {
    return 0.5 * (1.0 - cos((TAU*n)/(N-1.0)));
}

//	Sinc function
float sinc(float x) {
    if (x == 0.0) return 1.0;
	return sin(pi*x) / (pi*x);
}

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


void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   if (TEMPERATURE != 6500)
      temperature_rgb = kelvin2rgb(TEMPERATURE);

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

}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec3 temperature_rgb;
layout(location = 2) in float vNTSC_FILTER_FC;
layout(location = 3) in float vNTSC_FILTER_SCF;
layout(location = 4) in float vNTSC_weights[NTSC_FILTER_WIDTH_MAX];
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

#include "includes/functions.include.slang"



//	Colorspace conversion matrix for YIQ-to-RGB
const mat3 YIQ2RGB = mat3(1.000, 1.000, 1.000,
                          0.956,-0.272,-1.106,
                          0.621,-0.647, 1.703);

const mat3 RGB2YIQ = mat3(
         0.2989, 0.5959, 0.2115,
         0.5870, -0.2744, -0.5229,
         0.1140, -0.3216, 0.3114);


//	Hann windowing function
float hann(float n, float N) {
    return 0.5 * (1.0 - cos((TAU*n)/(N-1.0)));
}

//	Sinc function
float sinc(float x) {
    if (x == 0.0) return 1.0;
	return sin(pi*x) / (pi*x);
}

#define pi10 pi*10


vec3 ntscdec(vec2 uv ){
   vec2 size = params.SourceSize.xy;
   //	Sample composite signal and decode to YIQ
      vec3 YIQ_processed = vec3(0.0);
      int N = int(NTSC_FILTER_WIDTH);
      for (int n=0; n < N; n++) {
         vec2 pos = uv + vec2(float(n-NTSC_FILTER_MIDDLE) / size.x, 0.0);
         float phase =  TAU * (vNTSC_FILTER_SCF * size.x * pos.x);
         //phase += ( pos.x * 3.14 * 20) ; // rainbow width
         if (NTSC_PHASE_SHIFT > 0.5) phase += ( pos.y * -pi10 ) ; // 45 degree
         //if (NTSC_DOT_CRAWL > 0.5)  phase += (params.FrameCount % 3140) /2.0 ;
         //float phase =  TAU * (vNTSC_FILTER_SCF * size.x * pos.x) + ( pos.y * -pi10 * NTSC_PHASE_SHIFT) 
         // ( pos.y * - 31.4);
         //Just sample luminance via yiq:
            vec3 smp = vec3((texture(Source, pos).rgb * RGB2YIQ).x);
            YIQ_processed += vec3(1.0, cos(phase), sin(phase)) * smp * vNTSC_weights[n];
      }

   vec3 RGB_ori = texture(Source, uv).rgb;
   vec3 YIQ_ori = RGB_ori * RGB2YIQ;

   //ADD artifacted Y and Q.
   vec3 YIQ_result = vec3(YIQ_ori.x, YIQ_ori.yz + YIQ_processed.yz * NTSC_MIX);


  /* se li vogliamo aggiungere come complemento ad 1?
   * tutto il
   * tipo ho y1 = 0.5 -> aggiungo y2 al max fino a 0.5, quindi come una sorta di clamp.
   * oppure partendo dall'opposto. e aggiungendo l'orinale all'ntsc.
   */

// YIQ_result.y = YIQ_ori.y + clamp(YIQ_processed.y, 0.0, (1-YIQ_ori.y)) * NTSC_MIX;
//  YIQ_result.z = YIQ_ori.z + clamp(YIQ_processed.z, 0.0, (1-YIQ_ori.z)) * NTSC_MIX;

//return YIQ_processed * YIQ2RGB;

  return YIQ_result * YIQ2RGB;
}


vec3 color_tools(vec3 pixel_out) {
//Apply color corrections to input signal.

   //Push luminance without clipping
   pixel_out = pixel_push_luminance(pixel_out,LUMINANCE);

   //Modify saturation
   if (!(SATURATION == 1.0)) {
      const vec3 W = vec3(0.2125, 0.7154, 0.0721);
      vec3 intensity = vec3(dot(pixel_out.rgb, W));
      pixel_out.rgb = mix(intensity, pixel_out.rgb, SATURATION);
   }

   //Modify contrast and brightness
   if (CONTRAST != 0.0 || BRIGHTNESS != 0.0)
      pixel_out.rgb = scale_to_range_vec3(pixel_out.rgb, -CONTRAST, 1+CONTRAST) + BRIGHTNESS;

   //Modify color temperature
   if (TEMPERATURE != 6500.0) pixel_out.rgb = pixel_out.rgb * temperature_rgb;
   return pixel_out;
}


vec3 pixel_no_flicker(vec2 coord){
   vec3 pixel_out;
   if (DO_NTSC_ARTIFACTS > 0.0)
      pixel_out = ntscdec(coord);
         else
      pixel_out = texture(Source,coord).rgb;

   if (DO_CCORRECTION == 1.0)
      pixel_out = color_tools(pixel_out);
   return pixel_out.rgb;
}

vec3 pixel_flickering() {
/* Simulates the flickering effect of the interlaced screens.
 * As I remember, it was visible when a line and the next had high
 * luminosity differences.
 * So we need sample the current line and the previous one
 * (eventually applying color corrections to both).
 *
 * Repeating the following:
 * On frame 0, return the "clean" pixel
 * On frame 1, mix the upper pixel with the current one
 * On frame 2, mix the lower pixel with the current one
 *
 * The effect of the mix is the flickering itself, and we modulate
 * the mix according to the luminance difference between the current
 * pixel and the mixed one.
 *
 * We choose to alternate on a period of 3,
 * (thus considering the upper pixel and the lower one)
 * or else the high pixel persistance of lcd displays wont allow
 * to see the effect (the lcd panel would just mix the pixels by itself (meh).
 */

   vec3 pixel_cur = pixel_no_flicker(vTexCoord);
   float mymod = params.FrameCount % 3;

   if (mymod == 0.0) return pixel_cur;
   float line_tick = (params.OriginalSize.y > MIN_LINES_INTERLACED ) ? 1 : 2 ;

   vec3 flickline;
   if (mymod == 1.0 )
      flickline = pixel_no_flicker(vTexCoord + vec2(0.0,params.OriginalSize.w/line_tick));
   else if (mymod == 2.0)
      flickline = pixel_no_flicker(vTexCoord - vec2(0.0,params.OriginalSize.w/line_tick));

   float lumdiff = (flickline.r+flickline.g+flickline.b)/3.0 -
                   (pixel_cur.r+pixel_cur.g+pixel_cur.b)/3.0;

   if (lumdiff > 0.0) {
      lumdiff = scale_to_range(lumdiff,0.0,SCANLINE_FLICKERING_POWER);
      return mix(pixel_cur,flickline,lumdiff);
   } else {
      return pixel_cur;
   }
}


void debug() {
//Just test patterns here
   vec3 pixel_debug;
   //Use one of the following to debug:
      pixel_debug=vec3(abs(sin(params.FrameCount/3.14/8.0))); //white fade
      //pixel_debug=vec3(abs(sin(params.FrameCount/3.14/20)),0.0,0.0); //red fade
      //pixel_debug=vec3(1.0);
      //pixel_debug=vec3(0.0,1.0,0.0);
      //pixel_debug=vec3(0.38,0.0,1.0)*vTexCoord.x;
      //pixel_debug=vec3(vTexCoord.x); //H bw gradient
      //pixel_debug=vec3(floor(vTexCoord.x*16)/16); //H bw gradient 16gray
      //pixel_debug=vec3(floor(vTexCoord.x*64)/64); //H bw gradient 64gray
      //pixel_debug=vec3(floor(vTexCoord.x*128)/128); //H bw gradient 128gray
      //pixel_debug=vec3(1,0,0,0)*floor(vTexCoord.x*64)/64; //H red gradient 64
      //if  (mod(params.FrameCount,100) < 50) pixel_debug=vec3(0.0) ; else pixel_debug=vec3(1.0);
      //FragColor = vec4(color_tools(pixel_debug).rgb,1.0);
      FragColor = vec4(pixel_debug,1.0);
}


void main() {
   //FragColor = vec4(ntscdec(vTexCoord),1.0); return;
   //debug(); return;

   /* since flickering code needs
      luminosity difference between 2 vertical lines
      both have to be processed through color corrections and rgb pixel offsets.
      before flickering code can operate. (pixel_no_flicker)
      Therefore we call pixel_no_flicker inside it when we want flickering scanlines
      and outside id when we dont.
   */

   if (DO_SCANLINES == 0.0) {
      FragColor= vec4(pixel_no_flicker(vTexCoord),1.0);
      return;
   }

   //Implicit else: DO_SCANLINES == 1.0
   if (scanline_have_to_flicker(is_interlaced())) {
      FragColor = vec4(pixel_flickering(),1.0);
      return;
   }

   //Implicit else: DO_SCANLINES == 1.0 but no flickering needed.
   FragColor = vec4(pixel_no_flicker(vTexCoord),1.0);
}


