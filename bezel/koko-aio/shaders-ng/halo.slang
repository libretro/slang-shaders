#version 450
#include "config.inc"
#include "includes/functions.include.slang"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vHALO_SHARPNESS;
layout(location = 2) out float vHALO_POWER;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    //Shift texel coord to optimize blurring.
    //inverted the previous pass shift.
        float m = map_range(HALO_SHARPNESS, 0.0, GLOW_SHARP_MAX, 0.0, 1.0);
        vTexCoord += mix( params.SourceSize.zw*0.5, vec2(0.0), m);
        
    //Adapt to the old params range
        vHALO_SHARPNESS = vec2(GLOW_SHARP_MAX - HALO_SHARPNESS);
        vHALO_SHARPNESS = vHALO_SHARPNESS/7.5;

            
            
    //Correct aspect
        vHALO_SHARPNESS = radius_blur_adapt(vHALO_SHARPNESS);

   if (HALO_POWER >= 0.0)
      vHALO_POWER = HALO_POWER;
         else
      vHALO_POWER = -HALO_POWER/10.0;
    
    bool bIs_Interlaced = is_interlaced();

}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vHALO_SHARPNESS;
layout(location = 2) in float vHALO_POWER;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 4) uniform sampler2D Source;
layout(set = 0, binding = 5) uniform sampler2D in_glow_pass;


void main() {
    
   #ifndef D3D_WORKAROUND
      if (is_skipped_frame())
         return;
   #endif
    
    if (DO_HALO == 0.0 ) return;
    
    //Pass the right texture unchanged for tighter blurs:
    if (HALO_SHARPNESS >= GLOW_SHARP_MAX) {
        FragColor.rgb = pow(texture(Source, vTexCoord).rgb * vHALO_POWER,  vec3(HALO_GAMMA_OUT));
        return;
    }
    
    //pixel_haloed = blur5_x(Source, vTexCoord, params.SourceSize.xy, vHALO_SHARPNESS, 0.0);
    vec3 pixel_haloed = blur_px(Source, vTexCoord, vHALO_SHARPNESS) * vHALO_POWER;
    pixel_haloed =  pow(pixel_haloed, vec3(HALO_GAMMA_OUT));

    
    FragColor.rgb = pixel_haloed;



}
