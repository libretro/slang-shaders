#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 4) out vec3 temperature_rgb;

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


void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   if (TEMPERATURE != 6500)
      temperature_rgb = kelvin2rgb(TEMPERATURE);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 4) in vec3 temperature_rgb;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

#include "includes/functions.include.slang"

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
   vec3 pixel_out = texture(Source,coord).rgb;
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
      //pixel_debug=vec3(abs(sin(params.FrameCount/3.14/8.0))); //white fade
      //pixel_debug=vec3(abs(sin(params.FrameCount/3.14/20)),0.0,0.0); //red fade
      //pixel_debug=vec3(1.0);
      //pixel_debug=vec3(0.0,1.0,0.0);
      //pixel_debug=vec3(0.38,0.0,1.0)*vTexCoord.x;
      pixel_debug=vec3(vTexCoord.x); //H bw gradient
      //pixel_debug=vec3(floor(vTexCoord.x*16)/16); //H bw gradient 16gray
      //pixel_debug=vec3(floor(vTexCoord.x*64)/64); //H bw gradient 64gray
      //pixel_debug=vec3(floor(vTexCoord.x*128)/128); //H bw gradient 128gray
      //pixel_debug=vec3(1,0,0,0)*floor(vTexCoord.x*64)/64; //H red gradient 64
      //if  (mod(params.FrameCount,100) < 50) pixel_debug=vec3(0.0) ; else pixel_debug=vec3(1.0);  
      //FragColor = vec4(color_tools(pixel_debug).rgb,1.0);
      FragColor = vec4(pixel_debug,1.0);
}


void main() {
   
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
 
  
