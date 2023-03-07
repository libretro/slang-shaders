#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

#include "includes/functions.include.slang"


void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

#include "includes/functions.include.slang"

vec3 pixel_flickering() {
/* Simulates the flickering effect of the interlaced screens.
 * As I remember, it was visible when a line and the next had high
 * luminosity differences.
 * So we need to sample the current line and the previous one
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

   vec3 pixel_cur = texture(Source,vTexCoord).rgb;   
   float mymod = params.FrameCount % 3;

   if (mymod == 0.0) return pixel_cur;
   float line_tick = (params.OriginalSize.y > MIN_LINES_INTERLACED ) ? 1 : 2 ;

   vec3 flickline;
   if (mymod == 1.0 )
      flickline = texture(Source, vTexCoord + vec2(0.0,params.OriginalSize.w/line_tick)).rgb;
   else if (mymod == 2.0)
      flickline = texture(Source, vTexCoord - vec2(0.0,params.OriginalSize.w/line_tick)).rgb;

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
      //pixel_debug=vec3(abs(sin(params.FrameCount/3.14/5.0))); //white fade
      //pixel_debug=vec3(abs(sin(params.FrameCount/3.14/20)),0.0,0.0); //red fade
      //pixel_debug=vec3(0.9);
      //pixel_debug=vec3(0.0,1.0,0.0);
      //pixel_debug=vec3(0.38,0.0,1.0)*vTexCoord.x;
      //pixel_debug=vec3(vTexCoord.x); //H bw gradient
      pixel_debug=vec3(floor(vTexCoord.x*16)/16); //H bw gradient 16gray
      //pixel_debug=vec3(floor(vTexCoord.x*64)/64); //H bw gradient 64gray
      //pixel_debug=vec3(floor(vTexCoord.x*128)/128); //H bw gradient 128gray
      //pixel_debug=vec3(floor(vTexCoord.x*256)/256); //H bw gradient 256gray
      //pixel_debug=vec3(1,0,0,0)*floor(vTexCoord.x*64)/64; //H red gradient 64
      //   float blink_time = 20;
      //      if  (mod(params.FrameCount,blink_time*2) < blink_time) pixel_debug=vec3(0.2) ; else pixel_debug=vec3(1.0);
      //FragColor = vec4(color_tools(pixel_debug).rgb,1.0);
      //White circle, blinking
      /*   float blink_time = 20;
         vec2 center = vTexCoord - vec2(0.5,0.5);
         float radius = 0.1;
         pixel_debug = vec3(1 - step(radius, length(center)));
         pixel_debug *= float((mod(params.FrameCount,blink_time*2) < blink_time));
      */
      
      
      FragColor = vec4(pixel_debug,1.0);
}


void main() {
   
      /*vec4 pixel_debug=texture(Source,vTexCoord);
      float mymod = int(mod(vTexCoord.y * params.OutputSize.y , 2.0 )) ;
      pixel_debug.a *= float(   (mymod != 0.0)   ) ;
      FragColor = pixel_debug;
      return;
      */
   
   
   //debug(); return;

   /* since flickering code needs
      luminosity difference between 2 vertical lines
      both have to be processed through color corrections and rgb pixel offsets.
      before flickering code can operate. (pixel_no_flicker)
      Therefore we call pixel_no_flicker inside it when we want flickering scanlines
      and outside id when we dont.
   */

   
   
   vec3 pixel_out;
   if (DO_SCANLINES == 0.0)
      pixel_out = texture(Source, vTexCoord).rgb;
   
   else if (scanline_have_to_flicker(is_interlaced()))
      pixel_out = pixel_flickering();
   else
   //Implicit else: DO_SCANLINES == 1.0 but no flickering needed.
   pixel_out = texture(Source, vTexCoord).rgb;

   
   if (DO_RF_NOISE > 0.0) {
      vec3 noise = vec3(random(RF_NOISE_STRENGTH, vTexCoord * params.FrameCount));
      pixel_out += noise;
   }
   
   //Here lies the blur modifier from ntsc pass to glow.
   //I'm not expecting any performance hit, since the lookup should have been cached alreadyl
      float pixel_alpha = texture(Source, vTexCoord).a;
   
   FragColor = vec4(pixel_out, pixel_alpha);
}


