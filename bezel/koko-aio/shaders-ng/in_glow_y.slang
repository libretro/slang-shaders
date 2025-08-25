#version 450
#include "config.inc"
#include "includes/functions.include.slang"  

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float glow_h_inside_interval;
layout(location = 2) out float vDoInGlowBias;
layout(location = 3) out float vGlow_Gain;
layout(location = 4) out float vSharp_sub;
layout(location = 5) out float vDo_wtfl;
layout(location = 6) out float vIn_glow_h_adapted;
layout(location = 7) out float vDeltaRenderOk;
layout(location = 8) out float vWarpedglow;
layout(location = 9) out float vDynamicSeed;
layout(location = 10) out float vIn_glow_edge_sharpness;
layout(location = 11) out float vIn_glow_edge_defocus_strength;
layout(location = 12) out vec2 vWarpedglow_vtexcoord_offsets_plus;
layout(location = 13) out vec2 vWarpedglow_vtexcoord_offsets_minus;

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord ;  
   
   // If * at least one sharpness is lower than the max
   //    * we dont want just blur
   //    * we don't want to show ntsc artifact masks if we're doing ntsc artifacts
   // Then do in glow bias
   vDoInGlowBias = float (  IN_GLOW_BIAS < IN_GLOW_BIAS_MAX && 
                            (abs(IN_GLOW_W) < GLOW_SHARP_MAX || IN_GLOW_H < GLOW_SHARP_MAX) &&
                            (DO_NTSC_ARTIFACTS + NTSC_SHOW_ARTF_MASK < 1.5)   );
   
   bool bDo_wtfl = (DO_WTFL > 0.9 && WTFL_SHARPNESS_Y < 3.0);
   bool bDo_defocus = (DO_SHIFT_RGB > 0.5 && EDGE_DEFOCUS_DO_BLUR > 0.0);
   
   vDo_wtfl = float(bDo_wtfl);
   
   //The following conditions are used to skip blur-x code.
   bool bGlow_h_inside_interval = true;
   if (IN_GLOW_H >= GLOW_SHARP_MAX) bGlow_h_inside_interval = false;             // radius falls in the allowed interval
   if (DO_IN_GLOW < 0.5) bGlow_h_inside_interval = false;                       // Disabled if not user enabled
   if (bDo_wtfl) bGlow_h_inside_interval = true;    //always active if need to blur the waterfalls.
   if (bDo_defocus) bGlow_h_inside_interval = true; //always active if need to do defocusing.

   glow_h_inside_interval = float( bGlow_h_inside_interval);

   vGlow_Gain = mix(1.0, IN_GLOW_POWER, DO_CCORRECTION);
   
  // if (IN_GLOW_H < 0.0) {
      //Compute subtractive sharpening via blur sharpness strength:
      //For sharpness 0.45, no unsharp mask
      //For sharpness 0.8, 0.65 unsharp mask
      //float sharp_sub = (1.857 * abs(IN_GLOW_W) - 0.836);
      float in_glow_h = abs(IN_GLOW_H);
      in_glow_h = max(in_glow_h, MIN_IN_GLOW_SHARP);
      float sharp_sub = 0.8125 * in_glow_h;
      vSharp_sub = clamp(sharp_sub, 0.0,1.0);
      vSharp_sub = -2*vSharp_sub+1;
   //}
      
   bool bIs_Interlaced = is_interlaced();
   vDeltaRenderOk = is_deltarender_allowed(bIs_Interlaced); //carries DR mandatory conditions, including forced refreshed frames

   float warpedglow_scale = 1.0;
   if (DO_PIXELGRID > 0.0 && DO_PIXELGRID_H > 0.0)
      warpedglow_scale = PIXELGRID_MAX_H;
   
   float IN_GLOW_WARPSHARP_TATED = IN_GLOW_WARPSHARP_Y;
   if (need_tate(is_rotated()) == 1.0)
      IN_GLOW_WARPSHARP_TATED = IN_GLOW_WARPSHARP_X;

   vWarpedglow = (IN_GLOW_WARPSHARP_TATED * warpedglow_scale) * 0.6 / 1400.0 * 3.0;   //*3.0 needed because we scale to 0->1 to use pow in the fragment.

   float warpedglow_delta = params.OriginalSize.w * 0.5;
   vWarpedglow_vtexcoord_offsets_minus = vTexCoord - vec2(0.0, warpedglow_delta);
   vWarpedglow_vtexcoord_offsets_plus =  vTexCoord + vec2(0.0, warpedglow_delta); 
   
   
   //Generate a seed that changes over time for temporal random noise
   vDynamicSeed = mod(params.FrameCount, 120.0001);
   
   if (EDGE_DEFOCUS_DO_BLUR*DO_SHIFT_RGB > 0.001) {
      vIn_glow_edge_defocus_strength = EDGE_DEFOCUS_DO_BLUR;
      //defocusing produces double scanlines, which is not the intended effect.
      //so lower the effect when we use strong scanlines.
         vIn_glow_edge_defocus_strength = mix(vIn_glow_edge_defocus_strength, 0.0, DO_PIXELGRID_H);
         vIn_glow_edge_defocus_strength = max(0.0, vIn_glow_edge_defocus_strength);
      //for legibility here, if pixelgrid is totally disabled (no scalnlines) use full defocus.
         if (DO_PIXELGRID == 0.0) vIn_glow_edge_defocus_strength = EDGE_DEFOCUS_DO_BLUR;
      //again, for legibility, if using HQ_DECON we can blur
         #ifdef HQ_DECON
            vIn_glow_edge_defocus_strength = EDGE_DEFOCUS_DO_BLUR;
         #endif
   } else {
      vIn_glow_edge_defocus_strength = 0.0;
   }
   vIn_glow_edge_sharpness = mix(abs(in_glow_h), 0.3, vIn_glow_edge_defocus_strength);
   //vIn_glow_edge_sharpness = max(vIn_glow_edge_sharpness, MIN_IN_GLOW_SHARP);
   
   vIn_glow_h_adapted = abs(IN_GLOW_H);
   
   
  
   //when not using glow/blur, set it to 7.0 if needed by fake transparency blurring
   if (vDo_wtfl == 1.0  && DO_IN_GLOW == 0.0) 
      vIn_glow_h_adapted = 7.0;
   //..same goes for defocus
   if (vIn_glow_edge_defocus_strength > 0.0 && DO_IN_GLOW == 0.0)
      vIn_glow_h_adapted = 7.0;
 
}


#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float glow_h_inside_interval;
layout(location = 2) in float vDoInGlowBias;
layout(location = 3) in float vGlow_Gain;
layout(location = 4) in float vSharp_sub;
layout(location = 5) in float vDo_wtfl;
layout(location = 6) in float vIn_glow_h_adapted;
layout(location = 7) in float vDeltaRenderOk;
layout(location = 8) in float vWarpedglow;
layout(location = 9) in float vDynamicSeed;
layout(location = 10) in float vIn_glow_edge_sharpness;
layout(location = 11) in float vIn_glow_edge_defocus_strength;
layout(location = 12) in vec2 vWarpedglow_vtexcoord_offsets_plus;
layout(location = 13) in vec2 vWarpedglow_vtexcoord_offsets_minus;

layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 4) uniform sampler2D upscale_pass;
layout(set = 0, binding = 5) uniform sampler2D shift_and_bleed_pass;
layout(set = 0, binding = 6) uniform sampler2D Source;
layout(set = 0, binding = 8) uniform sampler2D colortools_and_ntsc_passFeedback;
layout(set = 0, binding = 9) uniform sampler2D colortools_and_ntsc_pass;

vec3 glow_blur_bias(sampler2D source_tex, vec2 co, vec3 pixel_glowed, float bias){
   vec3 pixel_source = texture(source_tex, co).rgb;
   //good with sx,sy=1.3; light gain 2.7, light sharpness 1.1
   vec3 glow_light = pixel_glowed - pixel_source;
   glow_light = clamp(glow_light * IN_GLOW_SPREAD, 0.0, 1.0);
   glow_light = pow(glow_light, vec3(IN_GLOW_SPREAD_SHARPNESS));
   vec3 proper_glow = glow_light  + pixel_source;  
   return mix(proper_glow, pixel_glowed, max(0.0, bias));            
}

vec3 blur_select_wrap(sampler2D texture_in, vec2 co, vec4 sourcesize, float sharpness, bool use_gauss, float sharp_sub) {
   if (use_gauss)
      return blur9_y(texture_in, co, sourcesize.xy, sharpness);
         else
      return blur9_y_box(texture_in, co, sourcesize.xy, sharpness, sharp_sub);      
}


vec3 apply_noise_to(vec3 c) {
   if (bdelta_render_enabled())
      return c;
   
   c.rgb = pow(c.rgb, vec3(1/IN_GLOW_GAMMA));
      c += get_rf_noise(vTexCoord * vDynamicSeed);
      c = max(c, vec3(0.0));
   c.rgb = pow(c.rgb, vec3(IN_GLOW_GAMMA));
   return c;
}


void main() { 
   
   #ifndef D3D_WORKAROUND
      if (is_skipped_frame())
         return;
   #endif

   //Delta render?
   float DR_changed = 1.0;
   if (delta_render_enabled() == 1.0) {
     if (vDeltaRenderOk == 1.0) {
         DR_changed = delta_render_changed(colortools_and_ntsc_passFeedback, colortools_and_ntsc_pass,
                                                      vTexCoord, delta_render_get_check_area() );

     }
   }
   
   //Warped Glow Y
   //The result will be stored in the alpha channel to be consumed by final pass.
   float warpedglow_y = eps; //see down note: (**)
   #ifndef SKIP_WARPEDGLOW_Y
      if (DO_IN_GLOW == 1.0) {
         float max_inLum = max( 1.0, DO_CCORRECTION * apply_contrast_brightness(1.0, CONTRAST, BRIGHTNESS));
         vec3 gy = texture(Source, vWarpedglow_vtexcoord_offsets_plus).rgb
                 - texture(Source, vWarpedglow_vtexcoord_offsets_minus).rgb;
               
         gy /=max_inLum;
               
         warpedglow_y = (gy.x+gy.y+gy.z) / 3.0;
                                 
         warpedglow_y = pow( abs(warpedglow_y), IN_GLOW_WARPSHARP_GAMMA) * sign(warpedglow_y);
         
         warpedglow_y = warpedglow_y *  vWarpedglow + (eps * delta_render_enabled()); 
                                 
         // (**) This eps is needed because we multiplex deltarender and warpedglow and we NEED to have dr = 0.0 (and not a positive number)
         //To reuse old pixels, only that way (using 0.0 to reuse pixels) multiplexing is possible.
      }
   #endif


   float warpedglow_or_DR = warpedglow_y;
   if (DR_changed == 0.0) {
      warpedglow_or_DR = DR_changed;
   }
   
   //Passthrough
   if (glow_h_inside_interval == 0.0) {
      vec3 glowed_passthrough = texture(Source, vTexCoord).rgb;
      glowed_passthrough*=vGlow_Gain;
      glowed_passthrough = clip_to_white_maybe(glowed_passthrough.rgb);      
      if (DO_RF_NOISE < -0.5)
         glowed_passthrough = apply_noise_to(glowed_passthrough);
      
      FragColor = vec4(glowed_passthrough, warpedglow_or_DR);
   }
   
   
   if (DO_IN_GLOW == 0.0 && WTFL_SHARPNESS_Y == 3.0 ) {
      vec3 glowed = texture(shift_and_bleed_pass, vTexCoord).rgb * vGlow_Gain;
      glowed = clip_to_white_maybe(glowed.rgb);      
      FragColor = vec4(glowed, warpedglow_or_DR);
      
      if (DO_RF_NOISE < -0.5)
          FragColor.rgb = apply_noise_to(FragColor.rgb);
      
      return;
   }

   float in_glow_h_adapted = vIn_glow_h_adapted;
   
   vec3 pixel_glowed;
   
   float sharp_sub_adapted = vSharp_sub;
   
   //Override Megadrive fake transparencies (like Sonic waterfalls)
      if (vDo_wtfl == 1.0) {
         float waterfall = texture_NEAREST_lod(colortools_and_ntsc_pass, vTexCoord, params.OriginalSize,0.0).a;
         waterfall = unpack_21(waterfall, 1.2).y;
         //FragColor = vec4(vec3(waterfall),0.0);return;
         in_glow_h_adapted = mix(in_glow_h_adapted, WTFL_SHARPNESS_Y, waterfall);
         //cancel sharp sub when doing fake transparencies blur.
         sharp_sub_adapted = mix(sharp_sub_adapted, 1.0, waterfall );
      }
   
   // Edge defocus:
      float dist_from_edge = 1.0;
      if (vIn_glow_edge_defocus_strength > 0.0) {
         dist_from_edge = distance_from_edge_linear(vTexCoord, EDGE_DEFOCUS_AREA_INV);
         
         //never decrease blur:
            float new_in_glow_h_adapted = mix(vIn_glow_edge_sharpness, in_glow_h_adapted,  dist_from_edge );
            in_glow_h_adapted = min(new_in_glow_h_adapted, in_glow_h_adapted);
            
         //cancel sharp sub when doing defocus blur.
         sharp_sub_adapted = mix(sharp_sub_adapted, 1.0, (1-dist_from_edge)*vIn_glow_edge_defocus_strength);
         //FragColor = vec4(vec3(dist_from_edge), 0.0); return;
      }
   
   //Make it resolution independent.
      in_glow_h_adapted = in_glow_h_adapted / NEW_SCALEMOD_Y;

   //Also, a little hacky adaption for when upscale_pass does not scale to 2X
      if (params.OutputSize.xy == params.OriginalSize.xy)
         in_glow_h_adapted*=1.5;
      
   //If over the max sharp, then just passthrough, else do the blur.
      if (glow_h_inside_interval == 1.0) {
         pixel_glowed = blur_select_wrap(Source, vTexCoord, global.upscale_passSize, in_glow_h_adapted, (IN_GLOW_H >= 0.0), sharp_sub_adapted );
      } else {
         pixel_glowed = texture(Source, vTexCoord).rgb;
      }
   
   

   
   //Series of conditions to do in glow bias done in vertex shader:
      if (vDoInGlowBias == 1.0) {
         //edge defocus: the more near edge, the more the blur
         float in_glow_bias_faded = mix(IN_GLOW_BIAS, 1.0,  (1-dist_from_edge) *  (DO_SHIFT_RGB * EDGE_DEFOCUS_DO_BLUR ) );
         //FragColor = vec4(vec3(in_glow_bias_faded), 0.0);
         //return;
         pixel_glowed = glow_blur_bias(shift_and_bleed_pass, vTexCoord, pixel_glowed, in_glow_bias_faded);
      }
   
   pixel_glowed = pixel_glowed * vGlow_Gain;
   pixel_glowed = clip_to_white_maybe(pixel_glowed);
   FragColor = vec4(pixel_glowed, warpedglow_or_DR);
   
   if (DO_RF_NOISE < -0.5)
       FragColor.rgb = apply_noise_to(FragColor.rgb);
}

