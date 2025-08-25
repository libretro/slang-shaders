#version 450
#include "config.inc"

#include "includes/functions.include.slang" 

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 2) out float glow_w_inside_interval;
layout(location = 3) out float vSharp_sub;
layout(location = 4) out float vDo_wtfl;
layout(location = 12) out float vWarpedglow_scale_tated;
layout(location = 14) out float vIn_glow_edge_sharpness;
layout(location = 15) out float vIn_glow_edge_defocus_strength;
layout(location = 16) out vec2 vWarpedglow_vtexcoord_offsets_plus;
layout(location = 17) out vec2 vWarpedglow_vtexcoord_offsets_minus;

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord ;  
   
   bool bDo_wtfl = (DO_WTFL > 0.9 && WTFL_SHARPNESS_X < 3.0);
   bool bDo_defocus = (DO_SHIFT_RGB > 0.5 && EDGE_DEFOCUS_DO_BLUR > 0.0);
   
   vDo_wtfl = float(bDo_wtfl);
   
   //The following conditions are used to skip blur-x code.
   bool bGlow_w_inside_interval = true;
   if (IN_GLOW_W >= GLOW_SHARP_MAX) bGlow_w_inside_interval = false;             // radius falls in the allowed interval
   if (DO_IN_GLOW < 0.5) bGlow_w_inside_interval = false;                       // Disabled if not user enabled
   if (bDo_wtfl) bGlow_w_inside_interval = true;    //always active if need to blur the waterfalls.
   if (bDo_defocus) bGlow_w_inside_interval = true; //always active if need to do defocusing.
   
   glow_w_inside_interval = float( bGlow_w_inside_interval);


   //if (IN_GLOW_W < 0.0) {
      //Compute subtractive sharpening via blur sharpness strength:
      //For sharpness 0.45, no unsharp mask
      //For sharpness 0.8, 0.65 unsharp mask
      //float sharp_sub = (1.857 * abs(IN_GLOW_W) - 0.836);
      float in_glow_w = abs(IN_GLOW_W);
      in_glow_w = max(in_glow_w, MIN_IN_GLOW_SHARP);
      vSharp_sub = 0.8125 * in_glow_w;
      vSharp_sub = clamp(vSharp_sub, 0.0,1.0);
      vSharp_sub = -2*vSharp_sub+1;
   //}
      
   
   float warpedglow_delta = params.OriginalSize.z * 0.5;
      
   vWarpedglow_vtexcoord_offsets_plus = vTexCoord  + vec2(warpedglow_delta, 0.0); 
   vWarpedglow_vtexcoord_offsets_minus = vTexCoord - vec2(warpedglow_delta, 0.0); 
   
   vWarpedglow_scale_tated = IN_GLOW_WARPSHARP_X;
   if (need_tate(is_rotated()) == 1.0)
      vWarpedglow_scale_tated = IN_GLOW_WARPSHARP_Y;
   
   vWarpedglow_scale_tated = vWarpedglow_scale_tated * 0.6 / 1400.0 * 3.0;

   vWarpedglow_scale_tated /= get_in_aspect() ; //correct aspect
   
   if (EDGE_DEFOCUS_DO_BLUR*DO_SHIFT_RGB > 0.001) {
      vIn_glow_edge_defocus_strength = EDGE_DEFOCUS_DO_BLUR;
   } else {
      vIn_glow_edge_defocus_strength = 0.0;
   }
   vIn_glow_edge_sharpness = mix(abs(in_glow_w), 0.3, vIn_glow_edge_defocus_strength);
   //vIn_glow_edge_sharpness = max(vIn_glow_edge_sharpness, MIN_IN_GLOW_SHARP);
}


#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 2) in float glow_w_inside_interval;
layout(location = 3) in float vSharp_sub;
layout(location = 4) in float vDo_wtfl;
layout(location = 12) in float vWarpedglow_scale_tated;

layout(location = 14) in float vIn_glow_edge_sharpness;
layout(location = 15) in float vIn_glow_edge_defocus_strength;
layout(location = 16) in vec2 vWarpedglow_vtexcoord_offsets_plus;
layout(location = 17) in vec2 vWarpedglow_vtexcoord_offsets_minus;


layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 5) uniform sampler2D colortools_and_ntsc_pass;
layout(set = 0, binding = 6) uniform sampler2D colortools_and_ntsc_passFeedback;
layout(set = 0, binding = 7) uniform sampler2D shift_and_bleed_pass;


vec3 blur_select_wrap(sampler2D texture_in, vec2 co, vec4 sourcesize, float sharpness, float sharp_sub, bool use_gauss) {
   if (use_gauss)
      return blur9_x(texture_in, co, sourcesize.xy, sharpness);
         else
      return blur9_x_box(texture_in, co, sourcesize.xy, sharpness, sharp_sub);
}



void main() { 
   
   #ifndef D3D_WORKAROUND
      if (is_skipped_frame())
         return;
   #endif
   
   //Warped Glow X
   //The result will be stored in the alpha channel to be consumed by final pass.
   float warpedglow_x = 0.0;
   #ifndef SKIP_WARPEDGLOW_X
      if (DO_IN_GLOW == 1.0) {
         float max_inLum = max( 1.0, DO_CCORRECTION * apply_contrast_brightness(1.0, CONTRAST, BRIGHTNESS));
         vec3 gx = texture(shift_and_bleed_pass, vWarpedglow_vtexcoord_offsets_plus).rgb
                 - texture(shift_and_bleed_pass, vWarpedglow_vtexcoord_offsets_minus).rgb;
               
         gx /=max_inLum;

         
         warpedglow_x = (gx.x+gx.y+gx.z) / 3.0 ;
         warpedglow_x = pow( abs(warpedglow_x), IN_GLOW_WARPSHARP_GAMMA) * sign(warpedglow_x);
      
         warpedglow_x =  warpedglow_x * vWarpedglow_scale_tated;
      }
   #endif      
   
   //Don't do anything if IN_GLOW_H is are over the upper limit
   //and IN_GLOW_W is outside the allowed interval;
      if ( glow_w_inside_interval == 0.0) {
         //passthrough
         FragColor =vec4(texture(shift_and_bleed_pass, vTexCoord).rgb, warpedglow_x);
         return;
      }
      
   float in_glow_w_adapted = abs(IN_GLOW_W);
   float sharp_sub_adapted = vSharp_sub;
   
   float waterfall = 0.0;
   //Override Megadrive fake transparencies (like Sonic waterfalls)
      if (vDo_wtfl == 1.0) {
         waterfall = texture(colortools_and_ntsc_pass, vTexCoord).a; //somehow there is no need to use texture_nearest here.
         waterfall = unpack_21(waterfall, 1.2).x; //FragColor = vec4(vec3(waterfall),0.0);return;
      
         if (DO_IN_GLOW == 0.0)
            in_glow_w_adapted = 7.0;
         in_glow_w_adapted = mix(in_glow_w_adapted, WTFL_SHARPNESS_X, waterfall);
         //cancel sharp sub when doing fake transparencies blur.
         sharp_sub_adapted = mix(sharp_sub_adapted, 1.0, waterfall );
      }
   
   //Scale it for box
      if (IN_GLOW_W < 0.0)
         in_glow_w_adapted = in_glow_w_adapted/1.2;
      
   // Edge defocus:
      float dist_from_edge = 1.0;
      if (vIn_glow_edge_defocus_strength > 0.0) {
         dist_from_edge = distance_from_edge_linear(vTexCoord, EDGE_DEFOCUS_AREA_INV);
         
         //never decrease blur:
            float new_in_glow_w_adapted = mix(vIn_glow_edge_sharpness, in_glow_w_adapted,  dist_from_edge );
            in_glow_w_adapted = min(new_in_glow_w_adapted, in_glow_w_adapted);

         //cancel sharp sub when doing defocus blur
         sharp_sub_adapted = mix(sharp_sub_adapted, 1.0, (1-dist_from_edge)*vIn_glow_edge_defocus_strength);
         //FragColor = vec4(vec3(dist_from_edge), 0.0); return;
      }
   //Make it resolution independent.
      in_glow_w_adapted = in_glow_w_adapted / NEW_SCALEMOD_X;
      

   //Also, a little hacky adaption for when upscale_pass does not scale to 2X
      if (params.OutputSize.xy == params.OriginalSize.xy)
         in_glow_w_adapted*=1.5;
         
   
   FragColor = vec4(blur_select_wrap(shift_and_bleed_pass, vTexCoord, global.upscale_passSize, in_glow_w_adapted, sharp_sub_adapted, (IN_GLOW_W >= 0.0)), warpedglow_x);

}

