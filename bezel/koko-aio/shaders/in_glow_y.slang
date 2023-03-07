#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float vIN_GLOW_H;

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord ;  

   float IN_GLOW_H_ADAPTED = IN_GLOW_H;

   //Auto calc glow sharpness via IN_GLOW_SPREAD
   if (IN_GLOW_H <= 0.00001)
      IN_GLOW_H_ADAPTED = IN_GLOW_SPREAD * IN_GLOW_SHARPNESS_SPREAD_RATIO_H;

   //don't allow lower values that look bad:
   IN_GLOW_H_ADAPTED = max(IN_GLOW_H_ADAPTED, MIN_IN_GLOW_SHARP);
   
   vIN_GLOW_H = IN_GLOW_H_ADAPTED / NEW_SCALEMOD_Y; //Make it resolution independent.
}


#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vIN_GLOW_H;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 5) uniform sampler2D shift_and_bleed_pass;
layout(set = 0, binding = 6) uniform sampler2D Source;



#include "includes/functions.include.slang" 

vec3 glow_blur_bias(sampler2D source_tex, vec2 co, vec3 pixel_glowed, float bias){
   vec3 pixel_source = texture(source_tex, co).rgb;
   // Since I moved from one pass blur for glow to 2 passes (x,y), I've had to
   // move the pow to IN_GLOW_GAMMA in the previous pass, so pow-ering it
   // again here, is not needed.
   //       pixel_source  = pow(pixel_source,vec3(IN_GLOW_GAMMA)) * IN_GLOW_POWER;
   pixel_source  = pixel_source * IN_GLOW_POWER;
   
   vec3 glow_light = pixel_glowed - pixel_source;
   
   glow_light = clamp(glow_light * IN_GLOW_SPREAD, 0.0, 1.0);

   /* powering glow_light is fine when not dealing with scanline minimum thickness,
    * but when the scanline shape gets smaller, it kinda produces a visive
    * pow(x,2) by its own; in that case powering glow_light make things worse.
    * It makes sense, because we are emulating the light spread twice.
    * FIXME: How to deal with this?
    */
   
   //glow_light = pow(glow_light, vec3(2.0));
   
   
   
   vec3 proper_glow = glow_light * glow_light + pixel_source;  
   return mix(proper_glow, pixel_glowed, max(0.0, bias));   

}

/*
vec3 antialias_blur_bias(sampler2D source_tex, vec2 co, vec3 pixel_glowed, float bias){
   //Create a dilated and an eroded image, then mix between them via the blurred color.
   
   vec3 pixel_source = texture(source_tex, co).rgb;
   pixel_source  = pixel_source * IN_GLOW_POWER;
   
   vec3 glow_light = clamp((pixel_glowed - pixel_source) * IN_GLOW_SPREAD, 0.0, 1.0);

   vec3 pixel_glowed_inv = 1 - clamp(pixel_glowed, 0.0, 1.0);
   vec3 pixel_source_inv = 1 - clamp(pixel_source, 0.0, 1.0);
   
   vec3 pixel_dark = clamp((pixel_glowed_inv - pixel_source_inv) * IN_GLOW_SPREAD, 0.0, 1.0) ;

   vec3 pixel_dilated = pixel_source + glow_light ;
   vec3 pixel_eroded  = pixel_source - pixel_dark ;


   //Dilate or erode depending on blurred brightness:
      vec3 pixel_dilated_eroded =  mix(pixel_eroded, pixel_dilated, pixel_glowed);
   
   //Unsharp mask:
      float sharpamt = 0.5;
      pixel_dilated_eroded =  pixel_dilated_eroded + ((1 - pixel_glowed)*sharpamt);
      pixel_dilated_eroded = (pixel_dilated_eroded - sharpamt) * (1 + 2*sharpamt);

   
   return mix(pixel_dilated_eroded, pixel_glowed, max(0.0, bias));   
   //return mix(pixel_out, pixel_glowed, max(0.0, bias));   

}
*/

void main() { 
   if (DO_IN_GLOW == 0.0) return;

   vec3 pixel_glowed;
   //apply just gamma and power for tighter blurs and exit:
   if (IN_GLOW_W >= GLOW_SHARP_MAX && IN_GLOW_H >= GLOW_SHARP_MAX) {
       pixel_glowed = texture(shift_and_bleed_pass,vTexCoord).rgb * IN_GLOW_POWER; //(Source, IN_GLOW_POWER, IN_GLOW_GAMMA, vTexCoord) ;
   } else {
      pixel_glowed = blur9_y(Source, vTexCoord, params.SourceSize.xy, vIN_GLOW_H) * IN_GLOW_POWER;
      if (IN_GLOW_BIAS < IN_GLOW_BIAS_MAX && (IN_GLOW_W < GLOW_SHARP_MAX || IN_GLOW_H < GLOW_SHARP_MAX) ) {
           pixel_glowed = glow_blur_bias(shift_and_bleed_pass, vTexCoord, pixel_glowed, IN_GLOW_BIAS);
           //pixel_glowed = antialias_blur_bias(shift_and_bleed_pass, vTexCoord, pixel_glowed, IN_GLOW_BIAS);
      }
   }

   
   FragColor = vec4(pixel_glowed,1.0);
   
}

