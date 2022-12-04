#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;


void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D first_pass;
layout(set = 0, binding = 2) uniform sampler2D isrotated_passFeedback;

#define SourceTexture first_pass
#define SourceTextureSize global.first_passSize

#include "includes/functions.include.slang"

#define c_tolerance 0.051

#define b_offset_x -0.05
#define Pi2 6.28318530717959

vec3 blur(float Quality, float Directions, float Size, vec2 co,float lod) {
    vec4 iResolution = SourceTextureSize;
    vec2 Radius = Size/iResolution.xy ;

    vec3 color  = vec3(0.0,0.0,0.0);
    vec3 lookup = vec3(0.0,0.0,0.0);
    float steps=0.0;
    for( float d=0.0; d<Pi2; d+=Pi2/Directions) {
        for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality) {
            lookup = textureLod( SourceTexture, co + vec2(cos(d)  + b_offset_x , sin(d))*Radius*i  ,lod).rgb ;
            color +=lookup.rgb;
            steps+=1.0;
        }
    }
    color /= steps;
    
    if ( steps > 4.0) return vec3(1.0);
    
    return color;
}

void main() {
   if (DO_BEZEL == 0.0) return;
   
   vec2 coords_curved = vTexCoord;
   if (DO_CURVATURE == 1.0) {
      if ((GEOM_WARP_X > 0.0) || (GEOM_WARP_Y > 0.0))
            coords_curved = Warp(coords_curved,GEOM_WARP_X,GEOM_WARP_Y);
   }
   //coords_curved = zoomout_coords(coords_curved, -BEZEL_INNER_ZOOM , 1.0);
   coords_curved = zoomout_coords(coords_curved, BEZEL_REFLECTION_AREA_SIZE , 1.0);
   
   bool is_rotated = texture(isrotated_passFeedback,vec2(0.5,0.5)).r > 0.5;

   
   /* Calculate the internal area (the one which is not mirrored)
      so that we can skip blurring it:
   */
   /*       vec2 ar_box;
            if (!is_rotated) {
               //Width of the aspect corrected box zoomed as requested by the bezel settings:                                  
               ar_box.x = global.FinalViewportSize.z*global.FinalViewportSize.y*get_in_aspect() * (1+BEZEL_INNER_ZOOM-c_tolerance) ; 
               //Height zoomed as requested by bezel settings:
               ar_box.y = 1+BEZEL_INNER_ZOOM-c_tolerance;
                  } else {
               ar_box.y = global.FinalViewportSize.z*global.FinalViewportSize.y/get_in_aspect() * (1+BEZEL_INNER_ZOOM-c_tolerance) ; 
               ar_box.x= 1+BEZEL_INNER_ZOOM-c_tolerance;
            }
      
            //start_point is the middle of the screen minut half the content width
            vec2 start_point = vec2(0.5 - (ar_box.x*0.5), 0.5 - (ar_box.y*0.5));
            vec2 end_point =   vec2(0.5 + (ar_box.x*0.5), 0.5 + (ar_box.y*0.5));


         //Now we can skip the internal area or the black one as already marked by main_pass:
         //bool skip_condition =(vTexCoord.x > start_point.x  && vTexCoord.x < end_point.x &&
   //                           vTexCoord.y > start_point.y && vTexCoord.y < end_point.y) ||
   //                           is_outer_frame(texture(main_pass,vTexCoord));

   */

   //FIXME (CHECKME) is the rotation state still important?

   bool skip_condition = (coords_curved.x < 1.0 - c_tolerance && coords_curved.x > c_tolerance && 
                        coords_curved.y < 1.0 - c_tolerance && coords_curved.y > c_tolerance ) ;

   if (skip_condition) {
      FragColor = mark_useless(vec3(0.0));
      return;
   }
      
   vec2 res = vec2(global.first_passSize.x, global.first_passSize.y);
   vec2 dir = vec2(1.0,0.0);
   ///Quality, Directions, Size, coords, lod
   vec3 pixel_blur = blur(1,4,2,coords_curved, 2.0);
   
   FragColor = vec4(apply_fuzzy_main_pass(pixel_blur),1.0);

}
 
 
  
