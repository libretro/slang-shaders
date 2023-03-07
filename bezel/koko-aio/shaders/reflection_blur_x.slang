#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 1) out vec2 vWarp_vexp;
layout(location = 2) out vec2 vWarp_arg2;
layout(location = 0) out vec2 vTexCoord;

#include "includes/functions.include.slang"

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
  //Precalc some Curvature/Warp values:
      vWarp_vexp = 1.0/ (1 + (vec2(GEOM_WARP_X, GEOM_WARP_Y) * 0.2)) ;
      vWarp_arg2 = 1.0 - pow(vec2(0.29289321881345247559915563789515), vWarp_vexp );
      
   if (DO_BEZEL > 0.5)
      vTexCoord = zoom(TexCoord, BEZEL_REFL_ZOOM);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vWarp_vexp;
layout(location = 2) in vec2 vWarp_arg2;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D first_pass;
layout(set = 0, binding = 2) uniform sampler2D avglum_pass;

#define SourceTexture first_pass
#define SourceTextureSize global.first_passSize

#include "includes/functions.include.slang"

#define c_tolerance 0.051

vec3 texture_clamp_to_border(sampler2D tex, vec2 coords, float lod) {
   //This emulates clamp to border:
   if (coords.x < 0.0 || coords.x > 1.0 || coords.y < 0.0 || coords.y > 1.0)
      return vec3(0.0);
   else
      return textureLod( tex, coords, lod).rgb ;
}


vec3 blur_unroll_clamp_to_border(float Size, vec2 co, float lod, float coords_crop_point) {
   //Blur the image along x axis and emulate a clamp_to_border when outside the [0..1] range
   //FIXME: coords_crop_point are not taken into account? CHECKME if you ever use this.
   Size = Size * NEW_SCALEMOD_X; //<- so that blur size doesn't depend on output resolution
   vec3 color;
   vec2 d = SourceTextureSize.zw * Size;
      color =  texture_clamp_to_border( SourceTexture, co + d * vec2(-1.0,  1.0 )  ,lod).rgb;
      color += texture_clamp_to_border( SourceTexture, co + d * vec2( 1.0,  1.0 )  ,lod).rgb;
      color += texture_clamp_to_border( SourceTexture, co + d * vec2(-1.0,  -1.0 ) ,lod).rgb;
      color += texture_clamp_to_border( SourceTexture, co + d * vec2( 1.0,  -1.0 ) ,lod).rgb;
   return color / 4.0;
}

vec3 blur_unroll(float Size, vec2 co, float lod) {
   //Blurs the image along x axis
   Size = Size * NEW_SCALEMOD_X; //<- so that blur size doesn't depend on output resolution
   vec3 color;
   vec2 d = SourceTextureSize.zw * Size;
      color =  textureLod( SourceTexture, co + d * vec2(-1.0,  1.0 )  ,lod).rgb;
      color += textureLod( SourceTexture, co + d * vec2( 1.0,  1.0 )  ,lod).rgb;
      color += textureLod( SourceTexture, co + d * vec2(-1.0,  -1.0 ) ,lod).rgb;
      color += textureLod( SourceTexture, co + d * vec2( 1.0,  -1.0 ) ,lod).rgb;
   return color / 4.0;
}

vec2 mirrored_repeat(vec2 co, float crop) {
   //Do a coords mirrored repeat with the mirror axis
   //shifted by a "crop" amount.
   //Don't try to unbranch me, it is a matter of 1/1000.
   float cmin = 0.0 + crop ;
   float cmax = 1.0 - crop ; 
   if (co.x < cmin )
      co.x = 2*cmin - co.x;
   if (co.y < cmin)
      co.y = 2*cmin - co.y;
   if (co.x > cmax )
      co.x = 2*cmax - co.x;
   if (co.y > cmax )
      co.y = 2*cmax - co.y;
   return co;
}

float circle_smooth(vec2 coords, vec2 middle, float f_radius, float FALLOFF) {
   //Draw a circle with smoothed borders:
   float fdistance=distance(middle, vec2(coords.x, coords.y));
   float circle = (1-smoothstep(f_radius-FALLOFF, f_radius+FALLOFF, fdistance));
   return circle;
}

float square_smooth(vec2 co, vec2 corner, float size, float smoothshade) {
   //Draws a square with smooth borders:
   vec4 rect = vec4(corner.x, corner.y, corner.x+size, corner.y+size);
   vec2 hv = smoothstep(rect.xy - smoothshade, rect.xy, co) * smoothstep(co - smoothshade, co, rect.zw);
   return  hv.x * hv.y;
}

float corners_shade(vec2 co, float size, float smoothsize){
   //Draws 4 smooth squares or circles in the corners.
   //They are intended to modulate the blur radius and the strength of the reflection.
   
   /*
      vec4 circles;
      float circle_radius = size; //0.13?
      float circle_falloff = smoothsize; //0.05?
      float circle_power =2.0;
      circles.x = circle_smooth(co, vec2(0.0,0.0), circle_radius, circle_falloff) * circle_power;
      circles.y = circle_smooth(co, vec2(0.0,1.0), circle_radius, circle_falloff) * circle_power;
      circles.z = circle_smooth(co, vec2(1.0,0.0), circle_radius, circle_falloff) * circle_power;
      circles.w = circle_smooth(co, vec2(1.0,1.0), circle_radius, circle_falloff) * circle_power;
               
      float circle = max(max(max(circles.x, circles.y), circles.z), circles.w);
      circle = min(circle, 1.0);
      circle = 1-circle;
      
      return circle;
   */      
   vec4 squares;
   float squaresize = size;
   float squarefade = smoothsize;
   //(vec2 co, vec2 corner, float size, float smoothshade) {
   squares.x = square_smooth(co, vec2(0.0,0.0), squaresize, squarefade);
   squares.y = square_smooth(co, vec2(1.0 - squaresize, 0.0), squaresize, squarefade);
   squares.z = square_smooth(co, vec2(0.0, 1-squaresize), squaresize, squarefade);
   squares.w = square_smooth(co, vec2(1-squaresize, 1-squaresize), squaresize, squarefade);
   return max(max(max(squares.x, squares.y), squares.z), squares.w);
}

float borders_gradient(vec2 co, float foffset) {
   // Create a b/w shade near the borders that will be used to 
   // Modulate from sharp reflections to blur reflections.
   vec4 shades;
   shades.x = abs(     co.x - foffset );
   shades.y = abs( 1 - co.x - foffset );
   shades.z = abs(     co.y - foffset );
   shades.w = abs( 1 - co.y - foffset );
   return min(min(min(shades.x, shades.y), shades.z), shades.w);
}



void main() {
   if (DO_BEZEL == 0.0) return;
   
   //Zoom out the image coordinates by the bezel border size to make room for reflections:
      vec2 coords = zoomout_coords(vTexCoord, BEZEL_BORDER_SIZE, 1.0);
      vec2 coords_zoomedout = coords;
   
   //This skip condition will be used to spped-up processing by discarding unuseful pixels.
   //the c_tolerance parameter is a safe measure /FIXME: for what?
      bool skip_condition = (coords.x < 1.0 - c_tolerance && coords.x > c_tolerance && 
                           coords.y < 1.0 - c_tolerance && coords.y > c_tolerance ) ;

   
   //Mark the pixel as not useful, so that the next pass will be aware of it and skip rendering too:
      if (skip_condition) {
         FragColor = mark_useless(vec3(0.0));
         return;
      }

   //If coords needs to be curved, do it now:
      if (DO_CURVATURE == 1.0 && ( GEOM_WARP_X > 0.0 || GEOM_WARP_Y > 0.0)  ) {
            coords = Warp_fast(coords, vWarp_vexp, vWarp_arg2); //coords_curved = Warp(coords_curved,GEOM_WARP_X,GEOM_WARP_Y);
      }
   
   
   //Since we will use a mirrored_repeat trick to simulate reflections, we need to know
   //where the mirror axis is.
   //The mirror axis position may depend on the dynamic zoom level
   //(the feature that zooms the image in when it is bright)
      float coords_crop_point = 0.0;
      if (DO_DYNZOOM == 1.0) {
         //Crop coordinates to move the mirror axes
         float dyn_zoom = get_dyn_zoom(avglum_pass);
         coords_crop_point = (dyn_zoom - 1.0) * 0.5;
         //Zoom image coords to align it
         coords = zoom(coords, dyn_zoom);
      }
      coords_crop_point += BEZEL_RFL_OFFSET; // <- Adding the user offset
   
   //Mirror repeat the image by taking the crop point (mirror axis offset) into account:
      coords = mirrored_repeat(coords, coords_crop_point);
  
      
   //Create gradients in the corners to fadeout reflections and to blur more near them:
      float fcorners_shade = corners_shade(vTexCoord, BEZEL_REFL_CORNER_BLANK_SIZE, BEZEL_REFL_CORNER_BLANK_SHADE);
   
      
   //Create a gradient near borders to modulate between blurrend and sharp refection.
   //This also goes into output alpha channel to make the next pass aware of it.
      float shade_sharp_blur = borders_gradient(coords, coords_crop_point);
      shade_sharp_blur = shade_sharp_blur * 1/(BEZEL_BORDER_SIZE * 0.3) ;
      shade_sharp_blur = shade_sharp_blur - BEZEL_RFL_BLR_SHD; //Modulates between sharp and blur via user parameter
      
      
   //Also modulate in the corners via fcorners_shade (fcorners_shade 
      shade_sharp_blur = max(fcorners_shade, shade_sharp_blur);
      
      
   //Clamp to min 0.01 because anything lower will cause the next pass to think the pixel is useless.
      shade_sharp_blur = max(shade_sharp_blur, 0.01);     
      //shade_sharp_blur = clamp(shade_sharp_blur, 0.01, 1.0);     

      
   //blur the reflection along x axis:
      vec3 pixel_out = blur_unroll(BEZEL_REFL_BLUR_MAX * shade_sharp_blur, coords, 2.0);   
         // I tried, instead of simple blur_unroll() to take a black border into account ( blur_unroll_clamp_to_border() )
         // to emulate the reflection of black border into the main content
         // when it is smaller than the bezel, but due to the low resolution of this pass, the results are bad:
         // vec3 pixel_out = blur_unroll_clamp_to_border(BEZEL_REFL_BLUR_MAX * shade_sharp_blur, coords, 2.0, coords_crop_point);   
      
      
   //multiply the blurred image by the corner shade so that reflections will not be visible in the corners.
      pixel_out = pixel_out * (1 - fcorners_shade);
   
               
   // Finally, output the blurred image and put the sharp to blurred gradient in the alpha channel
   // to be used by the next blur-y pass too to modulate the blur radius.
      FragColor = vec4(apply_fuzzy_main_pass(pixel_out), shade_sharp_blur);
   
}
 
 
  
