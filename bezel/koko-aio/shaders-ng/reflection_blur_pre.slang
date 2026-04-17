#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) noperspective out vec2 vTexCoord;
layout(location = 1) noperspective out vec2 vCoordsAdapted;
layout(location = 2) noperspective out vec2 vCoords_shade;
layout(location = 3) noperspective out vec2 vCoordsBackdrop;
layout(location = 5) flat out float vIn_Aspect;

#include "includes/functions.include.slang"


void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   vIn_Aspect = get_in_aspect();
   vCoordsAdapted = vTexCoord;
   //override aspect?
   if (DO_GAME_GEOM_OVERRIDE > 0.5)
      vCoordsAdapted = content_geom_override_zoom(vCoordsAdapted, GAME_GEOM_ASPECT, get_in_aspect(), GAME_GEOM_VSHIFT, GAME_GEOM_HSHIFT, GAME_GEOM_ZOOM);

   vCoordsAdapted = zoomout_coords( vCoordsAdapted, BEZEL_RFL_ZOOM*0.1);

   vCoords_shade = zoom(vTexCoord,1.05);
   
   
   vCoordsBackdrop = vCoordsAdapted;
   if (DO_BACKDROP * BACKDROP_JUST_TUBE  > 0.0) 
      vCoordsBackdrop = overlay_image_coords(vCoordsAdapted);
   
}

#pragma stage fragment
layout(location = 0) noperspective in vec2 vTexCoord;
layout(location = 1) noperspective in vec2 vCoordsAdapted;
layout(location = 2) noperspective in vec2 vCoords_shade;
layout(location = 3) noperspective in vec2 vCoordsBackdrop;
layout(location = 5) flat in float vIn_Aspect;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D shift_and_bleed_pass;
layout(set = 0, binding = 2) uniform sampler2D avglum_pass;
layout(set = 0, binding = 3) uniform sampler2D backdrop;
#include "includes/functions.include.slang"
#include "includes/blooms.include.slang"

float borders_gradient(vec2 co, float smoothness) {
   vec2 gradients = 1-smoothstep_fast( vec2(0.5-smoothness), vec2(0.5), abs(co-0.5));
   return  (gradients.x * gradients.y * 2.5 - 0.5 ); 
   
   
   /*vec2 hv = smoothstep_fast( vec2(0.0), vec2(smoothness), co) * 
             (1-smoothstep_fast( vec2(1-smoothness), vec2(1.0), co));
   return  min(hv.x, hv.y)*4.0-1;
   */
   
   //Draws a square with smooth borders:   
   /*vec4 rect = vec4(smoothness, smoothness, 1 - smoothness, 1 - smoothness);
   vec2 hv = smoothstep(rect.xy - smoothness, rect.xy, co) * smoothstep(co - smoothness, co, rect.zw);
   return  hv.x * hv.y;*/
}

void main() {
   
   #ifndef D3D_WORKAROUND
      if (fps_halver_is_skipped_frame())
         return;
   #endif
   
   if (DO_BEZEL == 0.0) return;
   
   #define skip_border BEZEL_REFL_SKIP_SIZE
   if (vTexCoord.x > skip_border && vTexCoord.x < 1.0 - skip_border &&
       vTexCoord.y > skip_border && vTexCoord.y < 1.0 - skip_border ) {
      return;
   }
   
   vec2 coords = vCoordsAdapted;

   if (DO_DYNZOOM > 0.0)
      coords = zoom(coords, get_dyn_zoom(avglum_pass));

   if (AUTOCROP_MAX > 0.0)
      coords = zoom(coords, get_autocrop_zoom(avglum_pass));
   
   //eventually return black pixel when both content and overlay/backdrop do not need reflection
   #define tol 0.001
   #define RECT01 vec4( vec2(0.0-tol), vec2(1.0+tol) )
   if (is_first_outside_rect(coords, RECT01)) {
      if ( is_first_outside_rect(vCoordsBackdrop, RECT01) ) {
         FragColor = vec4(0.0);
         return;
      }
   }

   
  //Create a gradient near borders to modulate between blurred and sharp refection.
      #define smoothness 0.15
      
      float shade_sharp_blur = borders_gradient(vCoords_shade, smoothness);
      shade_sharp_blur =  shade_sharp_blur - BEZEL_RFL_BLR_SHD;
      
      shade_sharp_blur=clamp(shade_sharp_blur, 0.0,1.0);
      float blur_radius=(shade_sharp_blur) * 2.0;
      vec2 blur_radius_adpt = radius_blur_adapt_ext_inaspect(blur_radius, vIn_Aspect);
      
      
      
      vec3 pixel_out = bloom(shift_and_bleed_pass, coords, global.FinalViewportSize, blur_radius_adpt, 1.0, 0.0, 1.0) ;
      
      //pixel_out.rgb = pow(pixel_out.rgb, vec3(0.5)); //seems to improve reflections (counteracted by the next pass)
      
      
      if (DO_BACKDROP * BACKDROP_JUST_TUBE  > 0.0) {
         vec4 backdrop_img = texture(backdrop, vCoordsBackdrop);
         vec3 blended = (pixel_out.rgb + DO_BACKDROP) * backdrop_img.rgb;
         pixel_out.rgb = mix( pixel_out.rgb, blended, backdrop_img.a );
      }
      
   FragColor = vec4(pixel_out,shade_sharp_blur );
//FragColor = vec4(shade_sharp_blur );
   
}
 
 
  
